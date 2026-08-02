#define T_VRAM	0
#define T_CRAM	1
#define T_VSRAM	2

I64 line;

U8 VRAM[0x10000];
U16 CRAM[0x40];
U16 VSRAM[0x40];
U8 vdp_reg[0x20];

I64 control_code=0;
U32 control_address=0;
I64 control_pending=0;
U32 vdp_status=0x3400;

I64 screen_width=320;
I64 screen_height=224;

I64 dma_length;
U32 dma_source;
I64 dma_fill=0;

U64 gen_cram_dirty=0;

Bool gen_window_bug=TRUE;

U8 gen_pal_map[512];
U16 gen_pal_err[512];

U8 gen_cram_map[64];

I64 gen_extra_idx[GEN_PAL_EXTRA_CNT];

U8 VRAMRd(I64 addr)
{
	return VRAM[addr&0xFFFF];
}

I64 VDPSprAddr(I64 sprite_index)
{
	return ((vdp_reg[5]&0x7F)<<9)+(sprite_index*8);
}

I64 GenCramIdx(I64 v)
{
	return ((v>>1)&7)|(((v>>5)&7)<<3)|(((v>>9)&7)<<6);
}

U0 GenCramRGB(I64 idx, CBGR48 *c)
{
	c->r.u8[1]=((idx&7)*255)/7;
	c->g.u8[1]=(((idx>>3)&7)*255)/7;
	c->b.u8[1]=(((idx>>6)&7)*255)/7;
}

U0 GenInitPalette()
{
	I64 i;
	CBGR48 c=0;
	CBGR48 m;
	for (i=0; i<512; i++) {
		GenCramRGB(i,&c);
		gen_pal_map[i]=GetNearestColorNum(c.r.u8[1],c.g.u8[1],
		        c.b.u8[1]);
		m=GrPaletteColorGet(gen_pal_map[i]);
		gen_pal_err[i]=AbsI64(c.r.u8[1]-m.r.u8[1])+
		        AbsI64(c.g.u8[1]-m.g.u8[1])+
		        AbsI64(c.b.u8[1]-m.b.u8[1]);
	}
	for (i=0; i<GEN_PAL_EXTRA_CNT; i++)
		gen_extra_idx[i]=-1;
	gen_cram_dirty=~0;
}

U0 GenSavePalette()
{
	I64 i;
	GrPaletteGet(gen_sys_palette);
	for (i=0; i<GEN_PAL_EXTRA_CNT; i++)
		gen_sys_extra[i]=GrPaletteColorGet(GEN_PAL_EXTRA_BASE+i);
}

U0 GenRestorePalette()
{
	I64 i;
	GrPaletteSet(gen_sys_palette);
	for (i=0; i<GEN_PAL_EXTRA_CNT; i++)
		GrPaletteColorSet(GEN_PAL_EXTRA_BASE+i,gen_sys_extra[i]);
}

U0 GenSyncPalette()
{
	I64 i,k,slot,worst,idx[64],err[64];
	CBGR48 c=0;
	if (!gen_cram_dirty)
		return;
	gen_cram_dirty=0;
	for (i=0; i<64; i++) {
		idx[i]=GenCramIdx(CRAM[i]);
		gen_cram_map[i]=gen_pal_map[idx[i]];
		err[i]=gen_pal_err[idx[i]];
	}
	for (slot=0; slot<GEN_PAL_EXTRA_CNT; slot++) {
		worst=0;
		k=-1;
		for (i=0; i<64; i++)
			if (err[i]>worst) {
				worst=err[i];
				k=i;
			}
		if (k<0)
			break;
		if (gen_extra_idx[slot]!=idx[k]) {
			gen_extra_idx[slot]=idx[k];
			GenCramRGB(idx[k],&c);
			GrPaletteColorSet(GEN_PAL_EXTRA_BASE+slot,c);
		}
		for (i=0; i<64; i++)
			if (idx[i]==idx[k]) {
				gen_cram_map[i]=GEN_PAL_EXTRA_BASE+slot;
				err[i]=0;
			}
	}
}

U0 set_pixel(I64 x, I64 y, I64 index)
{
	gameCanvas->body[(((240-screen_height)/2+y)*
	        gameCanvas->width_internal)+x+((320-screen_width)/2)]=
	        gen_cram_map[index&0x3F];
}

U0 GenSwapCanvas()
{
	CDC *done=gameCanvas;
	gameCanvas=gameCanvas2;
	gameCanvas2=done;
	gen_shown_canvas=done;
}

U0 VDPClearCanvas()
{
	MemSet(gameCanvas->body,gen_cram_map[vdp_reg[7]&0x3F],
	        gameCanvas->width_internal*240);
}

U0 draw_cell_pixel(U32 cell, I64 cell_x, I64 cell_y, I64 x, I64 y)
{
	U8 *pattern=&VRAM[0x20*(cell&0x7FF)];
	I64 pattern_index;
	I64 color_index;
	if (cell&0x1000)
		pattern_index=(7-(cell_y&7))<<2;
	else
		pattern_index=(cell_y&7)<<2;
	if (cell&0x800)
		pattern_index+=(7-(cell_x&7))>>1;
	else
		pattern_index+=(cell_x&7)>>1;
	color_index=pattern[pattern_index];
	if ((cell_x&1)^((cell>>11)&1))
		color_index&=0xF;
	else
		color_index>>=4;
	if (color_index) {
		color_index+=(cell&0x6000)>>9;
		set_pixel(x,y,color_index);
	}
}

U0 vdp_render_bg(I64 line, I64 priority)
{
	I64 h_cells=32,v_cells=32;
	I64 hscroll_type,scroll_i,column;
	I64 e_line,cell_line,e_column,cell_column;
	U32 hscroll_mask,cell;
	U16 vscroll_mask;
	I16 hscroll,vscroll;
	I64 hscroll_base,scroll_base,ci,hi;
	I64 win_base,win_stride,win_x0,win_x1,wi,whp,wvp;
	I64 bug_x1=0,plane_p;
	Bool h40;

	switch (vdp_reg[16]&3) {
	case 0:	h_cells=32; break;
	case 1:	h_cells=64; break;
	case 3:	h_cells=128; break;
	}
	switch ((vdp_reg[16]>>4)&3) {
	case 0:	v_cells=32; break;
	case 1:	v_cells=64; break;
	case 3:	v_cells=128; break;
	}
	hscroll_type=vdp_reg[11]&3;
	hscroll_base=(vdp_reg[13]&0x3F)<<10;
	switch (hscroll_type) {
	case 0:	hscroll_mask=0x0000; break;
	case 1:	hscroll_mask=0x0007; break;
	case 2:	hscroll_mask=0xFFF8; break;
	case 3:	hscroll_mask=0xFFFF; break;
	}
	if (vdp_reg[11]&4)
		vscroll_mask=0xFFF0;
	else
		vscroll_mask=0x0000;

	h40=screen_width>=320;
	if (h40) {
		win_base=(vdp_reg[3]&0x3C)<<10;
		win_stride=64;
	} else {
		win_base=(vdp_reg[3]&0x3E)<<10;
		win_stride=32;
	}
	wvp=vdp_reg[18]&0x1F;
	whp=(vdp_reg[17]&0x1F)*2;
	win_x0=0;
	win_x1=0;
	if (T(vdp_reg[18]&0x80,(line>>3)>=wvp,(line>>3)<wvp)) {
		win_x0=0;
		win_x1=screen_width;
	} else if (vdp_reg[17]&0x80) {
		win_x0=whp*8;
		win_x1=screen_width;
	} else {
		win_x0=0;
		win_x1=whp*8;
	}
	if (win_x1>screen_width)
		win_x1=screen_width;
	if (win_x0<0)
		win_x0=0;

	for (scroll_i=0; scroll_i<2; scroll_i++) {
		if (scroll_i==0)
			scroll_base=(vdp_reg[4]&0x07)<<13;
		else
			scroll_base=(vdp_reg[2]&0x38)<<10;
		hi=(hscroll_base+((line&hscroll_mask)*4)+
		        ((scroll_i^1)*2))&0xFFFF;
		hscroll=(VRAM[hi]<<8)|VRAMRd(hi+1);

		bug_x1=0;
		if (gen_window_bug && scroll_i==1 && !win_x0 &&
		        0<win_x1<screen_width)
			bug_x1=win_x1+((hscroll-win_x1)&15);

		for (column=0; column<screen_width; column++) {
			if (scroll_i==1 && win_x0<=column<win_x1) {
				wi=(win_base+((((line>>3)*win_stride)+
				        (column>>3))*2))&0xFFFF;
				cell=(VRAM[wi]<<8)|VRAMRd(wi+1);
				if (((cell&0x8000) && priority) ||
				        ((cell&0x8000)==0 && priority==0))
					draw_cell_pixel(cell,column,line,column,line);
			} else {
				vscroll=VSRAM[((column&vscroll_mask)/8)+
				        (scroll_i^1)]&0x3FF;
				e_line=(line+vscroll)&((v_cells*8)-1);
				cell_line=e_line>>3;
				plane_p=column-hscroll;
				if (column<bug_x1)
					plane_p+=16;
				e_column=plane_p&((h_cells*8)-1);
				cell_column=e_column>>3;
				ci=(scroll_base+(((cell_line*h_cells)+
				        cell_column)*2))&0xFFFF;
				cell=(VRAM[ci]<<8)|VRAMRd(ci+1);
				if (((cell&0x8000) && priority) ||
				        ((cell&0x8000)==0 && priority==0))
					draw_cell_pixel(cell,e_column,e_line,column,
					        line);
			}
		}
	}
}

U0 vdp_render_sprite(I64 sprite_index, I64 line)
{
	I64 sa=VDPSprAddr(sprite_index);
	U16 y_pos=((VRAMRd(sa)<<8)|VRAMRd(sa+1))&0x3FF;
	I64 h_size=((VRAMRd(sa+2)>>2)&0x3)+1;
	I64 v_size=(VRAMRd(sa+2)&0x3)+1;
	U32 cell=(VRAMRd(sa+4)<<8)|VRAMRd(sa+5);
	U16 x_pos=((VRAMRd(sa+6)<<8)|VRAMRd(sa+7))&0x1FF;
	I64 y=(128-y_pos+line)&7;
	I64 cell_y=(128-y_pos+line)>>3;
	I64 cell_x,e_x,e_cell,x,tile_off;

	for (cell_x=0; cell_x<h_size; cell_x++) {
		if (cell&0x1000)
			tile_off=v_size-cell_y-1;
		else
			tile_off=cell_y;
		if (cell&0x800)
			tile_off+=(h_size-cell_x-1)*v_size;
		else
			tile_off+=cell_x*v_size;
		e_cell=(cell&0xF800)|(((cell&0x7FF)+tile_off)&0x7FF);
		for (x=0; x<8; x++) {
			e_x=(cell_x*8)+x+x_pos-128;
			if (e_x>=0 && e_x<screen_width)
				draw_cell_pixel(e_cell,x,y,e_x,line);
		}
	}
}

U0 vdp_render_sprites(I64 line, I64 priority)
{
	I64 sprite_queue[80];
	I64 i=0,scanned=0,on_line=0,cur_sprite=0,sa;
	I64 v_size,y_min,y_max;
	U16 y_pos,x_pos;
	U32 cell;

	while (TRUE) {
		sa=VDPSprAddr(cur_sprite);
		y_pos=((VRAMRd(sa)<<8)|VRAMRd(sa+1))&0x3FF;
		v_size=(VRAMRd(sa+2)&0x3)+1;
		cell=(VRAMRd(sa+4)<<8)|VRAMRd(sa+5);
		y_min=y_pos-128;
		y_max=((v_size-1)*8)+7+y_min;
		if (line>=y_min && line<=y_max) {
			x_pos=((VRAMRd(sa+6)<<8)|VRAMRd(sa+7))&0x1FF;
			if (!x_pos && on_line)
				break;
			on_line++;
			if ((cell>>15)==priority)
				sprite_queue[i++]=cur_sprite;
		}
		cur_sprite=VRAMRd(sa+3);
		if (!cur_sprite)
			break;
		if (i>=80)
			break;
		if (++scanned>=80)
			break;
	}
	while (i>0)
		vdp_render_sprite(sprite_queue[--i],line);
}

U0 vdp_render_line(I64 line)
{
	I64 i,base=(((240-screen_height)/2+line)*
	        gameCanvas->width_internal)+((320-screen_width)/2);
	no_warn i;
	MemSet(gameCanvas->body+base,gen_cram_map[vdp_reg[7]&0x3F],
	        screen_width);
	if (!(vdp_reg[1]&0x40))
		return;
	vdp_render_bg(line,0);
	vdp_render_sprites(line,0);
	vdp_render_bg(line,1);
	vdp_render_sprites(line,1);
}

U0 vdp_data_write(U32 value, I64 type, I64 dma)
{
	I64 i;
	no_warn dma;
	if (type==T_VRAM) {
		VRAM[control_address&0xFFFF]=(value>>8)&0xFF;
		VRAM[(control_address+1)&0xFFFF]=value&0xFF;
	} else if (type==T_CRAM) {
		i=(control_address&0x7F)>>1;
		CRAM[i]=value;
		gen_cram_dirty|=1<<i;
	} else if (type==T_VSRAM)
		VSRAM[(control_address&0x7F)>>1]=value;
}

U0 vdp_data_port_write(U32 value)
{
	I64 type;
	if (control_code&1) {
		if ((control_code&0xE)==0)
			type=T_VRAM;
		else if ((control_code&0xE)==2)
			type=T_CRAM;
		else if ((control_code&0xE)==4)
			type=T_VSRAM;
		else
			type=T_VRAM;
		vdp_data_write(value,type,0);
	}
	control_address=(control_address+vdp_reg[15])&0xFFFF;
	control_pending=0;
	if (dma_fill) {
		dma_fill=0;
		dma_length=vdp_reg[19]|(vdp_reg[20]<<8);
		if (!dma_length)
			dma_length=0x10000;
		while (dma_length--) {
			VRAM[control_address&0xFFFF]=value>>8;
			control_address+=vdp_reg[15];
			control_address&=0xFFFF;
		}
	}
}

U0 vdp_set_reg(I64 _reg, U8 value)
{
	if (vdp_reg[1]&4 || _reg<=10)
		vdp_reg[_reg]=value;
	control_code=0;
}

U0 vdp_control_write(U32 value)
{
	I64 _reg,type;
	U32 word;
	if (!control_pending) {
		if ((value&0xC000)==0x8000) {
			_reg=(value>>8)&0x1F;
			vdp_set_reg(_reg,value&0xFF);
		} else {
			control_code=(control_code&0x3C)|((value>>14)&3);
			control_address=(control_address&0xC000)|
			        (value&0x3FFF);
			control_pending=1;
		}
	} else {
		control_code=(control_code&3)|((value>>2)&0x3C);
		control_address=(control_address&0x3FFF)|((value&3)<<14);
		control_pending=0;
		if ((control_code&0x20) && (vdp_reg[1]&0x10)) {
			if ((vdp_reg[23]>>6)==2 && (control_code&7)==1) {
				dma_fill=1;
			} else if ((vdp_reg[23]>>6)==3) {
				dma_length=vdp_reg[19]|(vdp_reg[20]<<8);
				if (!dma_length)
					dma_length=0x10000;
				dma_source=vdp_reg[21]|(vdp_reg[22]<<8);
				while (dma_length--) {
					VRAM[control_address&0xFFFF]=
					        VRAM[dma_source&0xFFFF];
					dma_source=(dma_source+1)&0xFFFF;
					control_address=(control_address+
					        vdp_reg[15])&0xFFFF;
				}
			} else {
				dma_length=vdp_reg[19]|(vdp_reg[20]<<8);
				if (!dma_length)
					dma_length=0x10000;
				dma_source=((vdp_reg[21]<<1)|(vdp_reg[22]<<9)|
				        ((vdp_reg[23]&0x7F)<<17))&0xFFFFFF;
				if ((control_code&0x7)==1)
					type=T_VRAM;
				else if ((control_code&0x7)==3)
					type=T_CRAM;
				else if ((control_code&0x7)==5)
					type=T_VSRAM;
				else
					type=T_VRAM;
				while (dma_length--) {
					word=m68k_read_memory_16(dma_source);
					dma_source=(dma_source+2)&0xFFFFFF;
					vdp_data_write(word,type,1);
					control_address+=vdp_reg[15];
					control_address&=0xFFFF;
				}
			}
		}
	}
}

U0 vdp_write(U32 address, U32 value)
{
	address&=0x1F;
	if (address<0x04)
		vdp_data_port_write(value);
	else if (address>=0x04 && address<0x08)
		vdp_control_write(value);
	else if (address>=0x10 && address<0x18)
		PSGWrite(value&0xFF);
}

U32 vdp_data_port_read()
{
	U32 v;
	I64 code=control_code&0xF;
	if (code==8)
		v=CRAM[(control_address&0x7F)>>1]&0x0EEE;
	else if (code==4)
		v=VSRAM[(control_address&0x7F)>>1]&0x07FF;
	else
		v=(VRAM[control_address&0xFFFE]<<8)|
		        VRAM[(control_address&0xFFFE)+1];
	control_address=(control_address+vdp_reg[15])&0xFFFF;
	control_pending=0;
	return v;
}

U32 vdp_status_read()
{
	U32 v=vdp_status|0x200;
	vdp_status&=~0x80;
	control_pending=0;
	return v;
}

U32 vdp_read(U32 address)
{
	I64 vcounter,hcounter;
	address&=0x1F;
	if (address<0x04)
		return vdp_data_port_read;
	else if (address<0x08)
		return vdp_status_read;
	else if (address<0x10) {
		vcounter=cycle_counter/MCYCLES_PER_LINE-1;
		if (vcounter>T(vdp_reg[1]&0x08,262,234))
			vcounter-=lines_per_frame;
		if (vdp_reg[12]&0x01)
			hcounter=0;
		else {
			hcounter=((cycle_counter+10)%MCYCLES_PER_LINE)/20;
			if (hcounter>=12)
				hcounter+=0x56;
			hcounter+=0x85;
		}
		return ((vcounter&0xFF)<<8)|(hcounter&0xFF);
	}
	return 0;
}

U32 vdp_read_byte(U32 address)
{
	U32 v=vdp_read(address&(~1));
	if (address&1)
		return v&0xFF;
	return (v>>8)&0xFF;
}

U0 vdp_set_hblank()	{ vdp_status|=4; }
U0 vdp_clear_hblank()	{ vdp_status&=~4; }
U0 vdp_set_vblank()	{ vdp_status|=8; }
U0 vdp_clear_vblank()	{ vdp_status&=~8; }

U0 VDPReset()
{
	MemSet(VRAM,0,0x10000);
	MemSet(CRAM,0,0x40*sizeof(U16));
	MemSet(VSRAM,0,0x40*sizeof(U16));
	MemSet(vdp_reg,0,0x20);
	control_code=0;
	control_address=0;
	control_pending=0;
	vdp_status=0x3400;
	dma_length=0;
	dma_source=0;
	dma_fill=0;
	screen_width=320;
	screen_height=224;
	line=0;
	gen_cram_dirty=~0;
}
