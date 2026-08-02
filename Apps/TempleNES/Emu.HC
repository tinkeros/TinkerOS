I64 win_scale=2, win_set_w=0;

Bool nes_quit, nes_paused, nes_emu_idle, nes_task_done;

CTask *nes_emu_task=NULL;
I64 nes_emu_gen=0, nes_emu_beat=0;

#ifdef NES_DIAG
I64 nes_diag_instrs=0, nes_diag_frames=0, nes_diag_next=0;

I64 NESDiagFifoCnt()
{
  if (!nes_snd_fifo)
    return -1;
  return FifoI64Cnt(nes_snd_fifo);
}

I64 nes_diag_canv_nz=0;
I64 NESDiagCanvas()
{
  I64 i,n,h=0;
  U8 *p;
  nes_diag_canv_nz=0;
  if (!gameCanvas)
    return 0;
  p=gameCanvas->body;
  n=gameCanvas->width_internal*gameCanvas->height;
  for (i=0; i<n; i++)
  {
    h=(h<<5)+h+p[i];
    if (p[i])
      nes_diag_canv_nz++;
  }
  return h;
}

U0 NESDiagMirror()
{
  I64 i;
  if (!MMU.RAM)
    return;
  if (nes_dg_ram_mirror && nes_dg_mirror_addr<0)
    for (i=0; i<0x800; i++)
      if (MMU.RAM[i]!=nes_dg_ram_mirror[i])
      {
        nes_dg_mirror_addr=i;
        nes_dg_mirror_want=nes_dg_ram_mirror[i];
        nes_dg_mirror_got=MMU.RAM[i];
        nes_dg_mirror_frame=nes_dg_frame;
        break;
      }
  if (nes_dg_ppureg_addr<0)
    for (i=0; i<8; i++)
      if (MMU.RAM[0x2000+i]!=nes_dg_ppureg_mirror[i])
      {
        nes_dg_ppureg_addr=0x2000+i;
        nes_dg_ppureg_want=nes_dg_ppureg_mirror[i];
        nes_dg_ppureg_got=MMU.RAM[0x2000+i];
        if (nes_dg_mirror_frame<0)
          nes_dg_mirror_frame=nes_dg_frame;
        break;
      }
  if (MMU.OAM && nes_dg_oam_mirror && nes_dg_oamm_addr<0)
    for (i=0; i<0x100; i++)
      if (MMU.OAM[i]!=nes_dg_oam_mirror[i])
      {
        nes_dg_oamm_addr=i;
        nes_dg_oamm_want=nes_dg_oam_mirror[i];
        nes_dg_oamm_got=MMU.OAM[i];
        if (nes_dg_mirror_frame<0)
          nes_dg_mirror_frame=nes_dg_frame;
        break;
      }
}

U0 NESDiagCanary()
{
  I64 i,v;
  if (!MMU.RAM || !MMU.VRAM || nes_dg_canary_frame>=0)
    return;
  for (i=0x4000; i<0x10000; i++)
    if (MMU.VRAM[i])
    {
      nes_dg_canary_frame=nes_dg_frame;
      nes_dg_canary_what=NES_CANARY_VRAM_HIGH;
      nes_dg_canary_now=i;
      nes_dg_canary_want=0;
      return;
    }
  for (i=0x0800; i<0x2000; i++)
    if (MMU.RAM[i])
    {
      nes_dg_canary_frame=nes_dg_frame;
      nes_dg_canary_what=NES_CANARY_RAM_GAP1;
      nes_dg_canary_now=i;
      nes_dg_canary_want=0;
      return;
    }
  for (i=0x2008; i<0x4000; i++)
    if (MMU.RAM[i])
    {
      nes_dg_canary_frame=nes_dg_frame;
      nes_dg_canary_what=NES_CANARY_RAM_GAP2;
      nes_dg_canary_now=i;
      nes_dg_canary_want=0;
      return;
    }
  if (mapper==0 || mapper==3)
  {
    v=NESDiagSum(MMU.RAM+0x8000,0x8000);
    if (v!=nes_dg_prg_sum0)
    {
      nes_dg_canary_frame=nes_dg_frame;
      nes_dg_canary_what=NES_CANARY_PRG;
      nes_dg_canary_now=v;
      nes_dg_canary_want=nes_dg_prg_sum0;
      return;
    }
  }
  if (mapper==0 && numCHRROM)
  {
    v=NESDiagSum(MMU.VRAM,0x2000);
    if (v!=nes_dg_chr_sum0)
    {
      nes_dg_canary_frame=nes_dg_frame;
      nes_dg_canary_what=NES_CANARY_CHR;
      nes_dg_canary_now=v;
      nes_dg_canary_want=nes_dg_chr_sum0;
    }
  }
}

I64 NESDiagPad()
{
  I64 i,res=0;
  for (i=0; i<8; i++)
    if (nes_joypad.button_status[i])
      res|=1<<i;
  return res;
}
#endif

U0 NESDrawWindow(CTask *task, CDC *dc)
{

  I64 x,y;
  U8 *src;
  U16 *d0;
  no_warn task;
#ifdef NES_DIAG
  nes_dg_draw_cnt++;
  nes_dg_draw_core=Gs->num;
  if (nes_dg_render_busy)
    nes_dg_draw_overlap++;
#endif
  if (win_scale==2 && gameCanvas2x)
  {
    for (y=0; y<NES_SCRN_H-2*NES_OVERSCAN; y++)
    {
      src=gameCanvas->body+
          (y+NES_OVERSCAN)*gameCanvas->width_internal;
      d0=gameCanvas2x->body+
          2*y*gameCanvas2x->width_internal;
      for (x=0; x<NES_SCRN_W; x++)
        d0[x]=src[x]*0x0101;
      MemCpy(d0(U8 *)+gameCanvas2x->width_internal,d0,
          NES_SCRN_W*2);
    }
    GrBlot(dc,0,0,gameCanvas2x);
  }
  else
    GrBlot(dc,0,0,gameCanvas);
}

U0 NESSnapWindow()
{

  I64 want_cols,want_rows,snap_left,snap_top;
  if (Fs->pix_width!=win_set_w)
  {

    if (Fs->pix_width>=NES_SCRN_W*3/2)
      win_scale=2;
    else
      win_scale=1;
  }
  want_cols=win_scale*NES_SCRN_W/FONT_WIDTH;
  if (win_scale==2)
    want_rows=2*(NES_SCRN_H-2*NES_OVERSCAN)/FONT_HEIGHT;
  else
    want_rows=NES_SCRN_H/FONT_HEIGHT;
  snap_left=Fs->win_left;
  snap_top=Fs->win_top;
  if (snap_left+want_cols>TEXT_COLS-1)
    snap_left=TEXT_COLS-1-want_cols;
  if (snap_left<1)
    snap_left=1;
  if (snap_top+want_rows>TEXT_ROWS-1)
    snap_top=TEXT_ROWS-1-want_rows;
  if (snap_top<2)
    snap_top=2;
  WinHorz(snap_left,snap_left+want_cols-1);
  WinVert(snap_top,snap_top+want_rows-1);
  win_set_w=win_scale*NES_SCRN_W;
}

U0 NESReset()
{
  reset6502;
  initPPU2C02(&PPU_state);
  JoypadInit(&nes_joypad);
  papu_request_irq=FALSE;
  mapper_request_irq=FALSE;
  cpu_stall_cycles=0;
}

Bool NESIsRomName(U8 *name)
{
  U8 buf[256];
  I64 n;
  StrCpy(buf,name);
  n=StrLen(buf);
  if (n>2 && !StrICmp(buf+n-2,".Z"))
  {
    n-=2;
    buf[n]=0;
  }
  return n>=4 && !StrICmp(buf+n-4,".NES");
}

Bool NESPickRom(U8 *rom_name)
{

  CDirEntry *de_list,*tmpde,**arr;
  I64 i,n=0,sel=0,top=0,rows,sc;
  U8 mask[256];
  Bool picked=FALSE,done=FALSE;
  U0 (*old_draw_it)(CTask *task,CDC *dc);
  old_draw_it=Fs->draw_it;

  Fs->draw_it=NULL;
  StrPrint(mask,"%s/Roms/*",__DIR__);
  de_list=FilesFind(mask,FUF_JUST_FILES);
  tmpde=de_list;
  while (tmpde)
  {
    if (NESIsRomName(tmpde->name))
      n++;
    tmpde=tmpde->next;
  }
  if (!n)
  {
    DocClear;
		"$FG,4$No ROMs found.$FG$\n\n"
    "Put .NES (or .NES.Z) files in\n"
    "\"%s/Roms\".\n\n"
		        "$FG,14$Press any key...$FG$\n",__DIR__;
    GetKey;
    DirTreeDel(de_list);
    DocClear;
    Fs->draw_it=old_draw_it;
    return FALSE;
  }
  arr=MAlloc(n*sizeof(CDirEntry *));
  i=0;
  tmpde=de_list;
  while (tmpde)
  {
    if (NESIsRomName(tmpde->name))
      arr[i++]=tmpde;
    tmpde=tmpde->next;
  }

  rows=Fs->win_bottom-Fs->win_top-3;
  if (rows<1)
    rows=1;
  while (!done)
  {
    if (sel<top)
      top=sel;
    if (sel>=top+rows)
      top=sel-rows+1;
    DocClear;
		"$FG,14$Pick a ROM$FG$ (%d found)\n"
		        "$FG,11$Arrows$FG$ move, $FG,11$Space$FG$/"
		        "$FG,11$Enter$FG$ pick, $FG,11$ESC$FG$ backs out.\n\n",
    n;
    for (i=top; i<n && i<top+rows; i++)
      if (i==sel)
				"$IV,1$%s$IV,0$\n",arr[i]->name;
      else
				"%s\n",arr[i]->name;
    switch (GetKey(&sc))
    {
    case 0:
      switch (sc.u8[0])
      {
      case SC_CURSOR_UP:
        if (sel)
          sel--;
        break;
      case SC_CURSOR_DOWN:
        if (sel<n-1)
          sel++;
        break;
      case SC_PAGE_UP:
        sel-=rows;
        if (sel<0)
          sel=0;
        break;
      case SC_PAGE_DOWN:
        sel+=rows;
        if (sel>n-1)
          sel=n-1;
        break;
      case SC_HOME:
        sel=0;
        break;
      case SC_END:
        sel=n-1;
        break;
      }
      break;
    case ' ':
    case '\n':
      StrCpy(rom_name,arr[sel]->full_name);
      picked=TRUE;
      done=TRUE;
      break;
    case CH_ESC:
    case CH_SHIFT_ESC:
      done=TRUE;
      break;
    }
  }
  Free(arr);
  DirTreeDel(de_list);
  DocClear;
  Fs->draw_it=old_draw_it;
  return picked;
}

Bool NESLoadRom(U8 *rom_filename)
{

  I64 i,size,controlByte2,need;
  U8 *dot;

  cartridgebuffer=FileRead(rom_filename,&size);
  if (!cartridgebuffer)
  {
    PrintErr("iNES ROM file not found.\n");
    return FALSE;
  }
  if (size<16 || cartridgebuffer[0]!='N' || cartridgebuffer[1]!='E' ||
      cartridgebuffer[2]!='S' || cartridgebuffer[3]!=0x1A)
  {
    PrintErr("\"%s\" is not an iNES file.\n",rom_filename);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    return FALSE;
  }

  numPRGROM =cartridgebuffer[4];
  numCHRROM =cartridgebuffer[5];
  controlByte1=cartridgebuffer[6];
  controlByte2=cartridgebuffer[7];
  mapper=(controlByte2&0xF0)|((controlByte1&0xF0)>>4);
  if (controlByte1&1)
    mirroringType=MIRR_VERT;
  else
    mirroringType=MIRR_HORZ;

  if (controlByte1&4)
  {
    PrintErr("\"%s\" has a trainer, which isn't supported.\n",
        rom_filename);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    return FALSE;
  }
  need=0x10+numPRGROM*0x4000+numCHRROM*0x2000;
  if (!numPRGROM || size<need)
  {
    PrintErr("\"%s\" is truncated: got %d bytes, header wants %d "
        "(%d PRG, %d CHR).\n",rom_filename,size,need,numPRGROM,
        numCHRROM);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    return FALSE;
  }

  if (((mapper==0 || mapper==3) && numPRGROM>2) ||
      ((mapper==7) && (numPRGROM<2)))
  {
    PrintErr("\"%s\" declares %d PRG banks, which mapper %d can't "
        "hold.\n",rom_filename,numPRGROM,mapper);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    return FALSE;
  }

  MMUInit;
  switch (mapper)
  {
  case 0:
  case 3:

    MemCpy(MMU.RAM+0x8000,cartridgebuffer+0x10,numPRGROM*0x4000);
    if (numPRGROM==1)
      MemCpy(MMU.RAM+0xC000,cartridgebuffer+0x10,0x4000);

    if (numCHRROM)
      MemCpy(MMU.VRAM,cartridgebuffer+0x10+0x4000*numPRGROM,
          0x2000);
    break;
  case 1:
  case 2:

    MemCpy(MMU.RAM+0x8000,cartridgebuffer+0x10,0x4000);

    MemCpy(MMU.RAM+0xC000,
        cartridgebuffer+0x10+0x4000*(numPRGROM-1),0x4000);

    if (numCHRROM)
      MemCpy(MMU.VRAM,cartridgebuffer+0x10+0x4000*numPRGROM,
          0x2000);
    break;
  case 4:
    MMC3_Init();
    break;
  case 7:
    MemCpy(MMU.RAM+0x8000,cartridgebuffer+0x10,0x8000);
    mirroringType=MIRR_SINGLE;
    break;
  default:
    PrintErr("iNES mapper %d isn't supported "
		        "(0, 1, 2, 3, 4 and 7 are).\n",mapper);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    MMUFree;
    return FALSE;
  }

  StrCpy(nes_state_filename,rom_filename);
  i=StrLen(nes_state_filename);
  if (i>2 && !StrICmp(nes_state_filename+i-2,".Z"))
    nes_state_filename[i-2]=0;
  dot=StrLastOcc(nes_state_filename,".");
  if (dot)
    *dot=0;
  StrCpy(nes_sram_filename,nes_state_filename);
  CatPrint(nes_state_filename,".BIN.Z");
  CatPrint(nes_sram_filename,".SRM");

#ifdef NES_DIAG
  AdamLog("NES load: %s\n"
      "  size=%d mapper=%d prg=%d chr=%d mirror=%d\n"
      "  prgsum=0x%08X chrsum=0x%08X reset_vec=0x%02X%02X\n",
      rom_filename,
      size,mapper,numPRGROM,numCHRROM,mirroringType,
      NESDiagSum(MMU.RAM+0x8000,0x8000),NESDiagSum(MMU.VRAM,0x2000),
      MMU.RAM[0xFFFD],MMU.RAM[0xFFFC]);
  nes_dg_prg_sum0=NESDiagSum(MMU.RAM+0x8000,0x8000);
  nes_dg_chr_sum0=NESDiagSum(MMU.VRAM,0x2000);
  nes_dg_canary_frame=-1;
  nes_dg_canary_what=-1;
#endif
  LoadSRAM;
  return TRUE;
}

Bool NESChangeRom()
{

  U8 new_rom[256];
  if (!NESPickRom(new_rom))
    return TRUE;
  SaveSRAM;
  Free(cartridgebuffer);
  cartridgebuffer=NULL;
  MMUFree;
  while (!NESLoadRom(new_rom))
    if (!NESPickRom(new_rom))
      return FALSE;
  NESReset;
  initPAPU(&PAPU);
  DCFill(gameCanvas,0);
  DCFill(gameCanvas2x,0);
  return TRUE;
}

U0 NESPauseEmu()
{
  I64 timeout=0;
  nes_emu_idle=FALSE;
  nes_paused=TRUE;
  while (!nes_emu_idle)
  {
    if (!TaskValidate(nes_emu_task) || ++timeout>3000)
      break;
    Sleep(1);
  }
}

U0 NESEmuTask(U8 *data)
{
  I64 gen,cycles,loop,base_jiffy,frame_num,next_frame_jiffy;
  U8 frame_finished=0;
  Bool was_paused;
  gen=data(I64);
  was_paused=TRUE;
  base_jiffy=cnts.jiffies;
  frame_num=0;
  next_frame_jiffy=base_jiffy+JIFFY_FREQ/60;
  try
  {
    while (!nes_quit)
    {
      if (gen!=nes_emu_gen)
        break;
      nes_emu_beat++;
#ifdef NES_DIAG
      nes_dg_emu_core=Gs->num;
      nes_dg_emu_iters++;
#endif
      if (nes_paused)
      {
        nes_emu_idle=TRUE;
        was_paused=TRUE;
        Sleep(20);
      }
      else
      {
        nes_emu_idle=FALSE;
        if (was_paused)
        {
          base_jiffy=cnts.jiffies;
          frame_num=0;
          next_frame_jiffy=base_jiffy+JIFFY_FREQ/60;
          was_paused=FALSE;
        }
        if (PPU_state.nmi_pending)
        {
          PPU_state.nmi_pending=0;
#ifdef NES_DIAG
          nes_dg_nmi_fire++;
          if (nes_nmi_trace_cnt<NES_NMI_TRACE)
          {
            NESNmiRec *nr=&nes_nmi_trace[nes_nmi_trace_cnt];
            nr->frame=nes_dg_frame;
            nr->instr=instructions;
            nr->pc=pc;
            nr->scanline=PPU_state.scanline;
            nr->dot=PPU_state.dot;
            nes_nmi_trace_cnt++;
          }
#endif
          nmi6502;
        }
        if (papu_request_irq && !(cpustatus & FLAG_INTERRUPT))
        {
          irq6502;
          papu_request_irq=FALSE;
        }
        if (mapper_request_irq && !(cpustatus & FLAG_INTERRUPT))
        {
          irq6502;
          mapper_request_irq=FALSE;
        }
        exec6502(1);
#ifdef NES_DIAG
        nes_diag_instrs++;
#endif
        cycles=ticktable[opcode]+clockticks6502;
        if (cpu_stall_cycles)
        {
          cycles+=cpu_stall_cycles;
          cpu_stall_cycles=0;
        }
#ifdef NES_DIAG
        if (nes_dg_isample && instructions>=nes_dg_isample_from &&
            (!nes_dg_isample_to || instructions<=nes_dg_isample_to) &&
            !((instructions-nes_dg_isample_from) % nes_dg_isample) &&
            nes_isamp_put-nes_isamp_got<NES_ISAMP_MAX)
        {
          NESISamp *is=&nes_isamp[nes_isamp_put&(NES_ISAMP_MAX-1)];
          is->instr=instructions;
          is->pc=pc;
          is->opcode=opcode;
          is->cycles=cycles;
          is->scanline=PPU_state.scanline;
          is->dot=PPU_state.dot;
          is->a=a;
          is->x=x;
          is->y=y;
          is->sp=sp;
          is->cpustatus=cpustatus;
          nes_isamp_put++;
        }
#endif
        PAPU_clockFrameCounter(&PAPU,cycles);
        loop=cycles*3;
        while (loop)
        {
          frame_finished|=PPUcycle(&PPU_state);
          loop--;
        }
        if (frame_finished)
        {
          frame_finished=0;
#ifdef NES_DIAG
          nes_diag_frames++;
          nes_dg_frame++;
          NESDiagMirror;
          if (!(nes_dg_frame&7))
            NESDiagCanary;
          if (nes_dg_frame<=16 || nes_dg_frame==20 ||
              nes_dg_frame==40 || nes_dg_frame==60 || nes_dg_frame==120)
            if (nes_ckpt_put-nes_ckpt_got<NES_CKPT_MAX)
            {
              NESCkpt *ck=&nes_ckpt[nes_ckpt_put&(NES_CKPT_MAX-1)];
              ck->frame=nes_dg_frame;
              ck->pc=pc;
              ck->a=a;
              ck->x=x;
              ck->y=y;
              ck->sp=sp;
              ck->cpustatus=cpustatus;
              ck->r2000=MMU.RAM[0x2000];
              ck->r2001=MMU.RAM[0x2001];
              ck->pad=NESDiagPad();
              ck->instr=instructions;
              ck->scanline=PPU_state.scanline;
              ck->dot=PPU_state.dot;
              ck->vaddr=MMU.VRAM_address;
              ck->t=MMU.t;
              ck->w=MMU.w;
              ck->nmi_occ=PPU_state.nmi_occurred;
              ck->nmi_out=PPU_state.nmi_output;
              ck->nmi_pend=PPU_state.nmi_pending;
              ck->ramsum=NESDiagSum(MMU.RAM,0x800);
              ck->vramsum=NESDiagSum(MMU.VRAM,0x4000);
              ck->oamsum=NESDiagSum(MMU.OAM,0x100);
              nes_ckpt_put++;
            }
#endif
          NESSndThrottle;
          SleepUntil(next_frame_jiffy);
          frame_num++;
          next_frame_jiffy=base_jiffy+(frame_num+1)*JIFFY_FREQ/60;
          if (next_frame_jiffy<cnts.jiffies)
          {
            base_jiffy=cnts.jiffies;
            frame_num=0;
            next_frame_jiffy=base_jiffy+JIFFY_FREQ/60;
          }
          JoypadScan(&nes_joypad);
        }
      }
    }
  }
  catch
  {
    PutExcept;
    nes_quit=TRUE;
  }
  if (gen==nes_emu_gen)
  {
    nes_emu_idle=TRUE;
    nes_task_done=TRUE;
  }
}

U0 TempleNES(U8 *rom_filename=NULL)
{

  I64 arg1,arg2,wait;
  U8 rom_name[256],help_path[256];

  SettingsPush;
  Fs->text_attr=BLACK<<4+WHITE;
  MenuPush(
      "File {"
      "  Exit(,CH_ESC);"
      "}"
      "Game {"
      "  PickROM(,'P');"
      "  Reset(,'R');"
      "  Pause(,' ');"
      "  SaveState(,'S');"
      "  LoadState(,'L');"
      "}"
      "View {"
      "  Scale1x(,'1');"
      "  Scale2x(,'2');"
	        "}");
  AutoComplete;
  WinBorder(ON);
  DocCursor;
  DocClear;
  win_set_w=Fs->pix_width;
  NESSnapWindow;
  WinFocus;

  StrPrint(help_path,"%s/Help.DD",__DIR__);
  Type(help_path);
  if (rom_filename)
		"\n$FG,14$Press any key to start...$FG$\n";
  else
		"\n$FG,14$Press any key to pick a ROM...$FG$\n";
  GetKey;
  DocClear;

  if (!rom_filename)
  {
    if (!NESPickRom(rom_name))
    {
      MenuPop;
      SettingsPop;
      DocClear;
      return;
    }
    rom_filename=rom_name;
  }
  if (!NESLoadRom(rom_filename))
  {

    MenuPop;
    SettingsPop;
    return;
  }

  gameCanvas=DCNew(NES_SCRN_W,NES_SCRN_H);
  DCFill(gameCanvas,0);

  gameCanvas->flags|=DCF_NO_TRANSPARENTS;
  gameCanvas2x=DCNew(2*NES_SCRN_W,2*(NES_SCRN_H-2*NES_OVERSCAN));
  DCFill(gameCanvas2x,0);
  gameCanvas2x->flags|=DCF_NO_TRANSPARENTS;

#ifdef NES_DIAG
  AdamLog("NES pre-init: ppu=0x%08X papu=0x%08X joy=0x%08X mmu=0x%08X\n"
      "  ui_core=%d mp_cnt=%d\n",
      NESDiagSum(&PPU_state,sizeof(PPU2C02state)),
      NESDiagSum(&PAPU,sizeof(PAPU2A03)),
      NESDiagSum(&nes_joypad,sizeof(CNESJoypad)),
      NESDiagSum(&MMU,sizeof(CNESMMU)),Gs->num,mp_cnt);
  nes_dg_ui_core=Gs->num;
  y=0xFE;
  cpustatus=0x27;
  x=0xCD;
  a=0xAB;
  sp=0x12;
  nes_dg_cast_y=y(U16);
  nes_dg_cast_x=x(U16);
  nes_dg_cast_a=a(U16);
  AdamLog("NES casttest: y(U16)=0x%04X x(U16)=0x%04X a(U16)=0x%04X "
      "(want 0x00FE 0x00CD 0x00AB)\n"
      "  addr sp=0x%08X a=0x%08X x=0x%08X y=0x%08X p=0x%08X\n",
      nes_dg_cast_y,nes_dg_cast_x,nes_dg_cast_a,
      &sp,&a,&x,&y,&cpustatus);
#endif
  NESReset;
  initPAPU(&PAPU);
#ifdef NES_DIAG
  AdamLog("NES post-init: ppu=0x%08X papu=0x%08X joy=0x%08X mmu=0x%08X\n"
      "  pc=0x%04X a=%02X x=%02X y=%02X sp=%02X p=%02X ua=%d pa=%d po=%d\n"
      "  stall=%d papuirq=%d mapirq=%d w=%d t=0x%04X mx=%d my=%d "
      "vaddr=0x%04X ibuf=0x%02X\n"
      "  sl=%d dot=%d nmi_occ=%d nmi_out=%d nmi_pend=%d s0hit=%d odd=%d "
      "nsprites=%d\n",
      NESDiagSum(&PPU_state,sizeof(PPU2C02state)),
      NESDiagSum(&PAPU,sizeof(PAPU2A03)),
      NESDiagSum(&nes_joypad,sizeof(CNESJoypad)),
      NESDiagSum(&MMU,sizeof(CNESMMU)),
      pc,a,x,y,sp,cpustatus,useaccum,penalty_addr,penalty_op,
      cpu_stall_cycles,papu_request_irq,mapper_request_irq,
      MMU.w,MMU.t,MMU.x,MMU.y,MMU.VRAM_address,MMU.internal_buffer,
      PPU_state.scanline,PPU_state.dot,PPU_state.nmi_occurred,
      PPU_state.nmi_output,PPU_state.nmi_pending,
      PPU_state.sprite_zero_hit,PPU_state.odd_frame,PPU_state.num_sprites);
#endif

  GrPaletteGet(&nes_sys_palette);
  PPU_InitPalette;

  Fs->draw_it=&NESDrawWindow;

  nes_quit=FALSE;
  nes_paused=FALSE;
  nes_emu_idle=FALSE;
  nes_task_done=FALSE;
  nes_emu_beat=0;
  nes_emu_gen++;
#ifdef NES_SINGLE_CORE
  nes_emu_task=Spawn(&NESEmuTask,nes_emu_gen,"TempleNES Core",,Fs);
#else
  if (mp_cnt>1)
    nes_emu_task=Spawn(&NESEmuTask,nes_emu_gen,"TempleNES Core",1);
  else
    nes_emu_task=Spawn(&NESEmuTask,nes_emu_gen,"TempleNES Core",,Fs);
#endif
  wait=0;
  while (!nes_emu_beat && wait<150)
  {
    Sleep(10);
    wait++;
  }
  if (!nes_emu_beat)
  {
		"TempleNES: emu task never ran on its core; "
		"falling back to this core.\n";
    nes_emu_gen++;
    Kill(nes_emu_task,FALSE);
    nes_emu_task=Spawn(&NESEmuTask,nes_emu_gen,"TempleNES Core",,Fs);
  }
  try
  {
    while (!nes_quit)
    {
      while (ScanMsg(&arg1,&arg2,1<<MSG_KEY_DOWN))
      {
        switch (arg1)
        {
        case CH_ESC:
        case CH_SHIFT_ESC:
        case 'q':
        case 'Q':
          nes_quit=TRUE;
          break;
        case 'r':
        case 'R':
          NESPauseEmu;
          NESReset;
          nes_paused=FALSE;
          break;
        case 'p':
        case 'P':
          NESPauseEmu;
          if (NESChangeRom())
            nes_paused=FALSE;
          else
            nes_quit=TRUE;
          break;
        case ' ':
          nes_paused=!nes_paused;
          break;
        case 's':
        case 'S':
          NESPauseEmu;
          SaveState;
          nes_paused=FALSE;
          break;
        case 'l':
        case 'L':
          NESPauseEmu;
          LoadState;
          nes_paused=FALSE;
          break;
        case '1':
          win_scale=1;
          break;
        case '2':
          win_scale=2;
          break;
        }
      }
#ifdef NES_DIAG
      if (cnts.jiffies>=nes_diag_next)
      {
        nes_diag_next=cnts.jiffies+JIFFY_FREQ;
        U8 nes_badop_nowbyte=0xFF;
        I64 canvsum;
        if (nes_badop_pc>=0)
          nes_badop_nowbyte=MMU.RAM[nes_badop_pc];
        AdamLog("NES dbgver=%d ips=%d fps=%d pc=0x%04X 0x2000=0x%02X "
            "0x2001=0x%02X sl=%d fifo=%d stall=%d mixer=%d\n"
            "  pal=%02X %02X %02X %02X nt=%02X %02X "
            "vaddr=0x%04X w=%d pad=0x%02X padptr=%d\n",
            NES_DEBUG_VER,nes_diag_instrs,nes_diag_frames,pc,MMU.RAM[0x2000],
            MMU.RAM[0x2001],PPU_state.scanline,NESDiagFifoCnt(),
            nes_snd_stall_cnt,nes_snd_mixer_idx,
            MMU.VRAM[0x3F00],MMU.VRAM[0x3F01],MMU.VRAM[0x3F02],
            MMU.VRAM[0x3F03],MMU.VRAM[0x2000],MMU.VRAM[0x2001],
            MMU.VRAM_address,MMU.w,NESDiagPad(),nes_joypad.pointer);
        AdamLog("  r2002=%d hit=%d nmi_set=%d nmi_clr=%d "
            "nmi_fire=%d w2000=%d w2001=%d r4016=%d\n"
            "  last2000=0x%02X last2001=0x%02X badop=%d "
            "lastop=0x%02X atpc=0x%04X bank=%d bankseq=%d "
            "nowbyte=0x%02X ldseq=%d\n",
            nes_dg_r2002,nes_dg_r2002_hit,
            nes_dg_nmi_set,nes_dg_nmi_clr,nes_dg_nmi_fire,
            nes_dg_w2000,nes_dg_w2001,nes_dg_r4016,
            nes_dg_w2000_val,nes_dg_w2001_val,nes_badop_cnt,
            nes_badop_last,nes_badop_pc,nes_badop_bank,nes_badop_seq,
            nes_badop_nowbyte,nes_ld16_seq);
        AdamLog("  mapw=%d mapdflt=%d seen=%d mapper=%d prg=%d "
            "oamdma_over=%d\n"
            "  uninit_rd=%d first=0x%04X palw=%d palwf=%d\n",
            nes_dg_mapw,nes_dg_mapdflt,nes_dg_mapper_seen,mapper,numPRGROM,
            nes_dg_oamdma_over,
            nes_dg_uninit_rd,nes_dg_uninit_addr,
            nes_dg_palw,nes_dg_palw_frame);
        canvsum=NESDiagCanvas();
        AdamLog("NES draw: canvsum=0x%08X nz=%d\n"
            "NES tasks: mp_cnt=%d ui=%d emu=%d draw=%d fill=%d iters=%d "
            "frame=%d\n"
            "  drawcnt=%d drawovl=%d fillcnt=%d fillovl=%d flushcnt=%d "
            "flushovl=%d\n",
            canvsum,nes_diag_canv_nz,
            mp_cnt,nes_dg_ui_core,nes_dg_emu_core,nes_dg_draw_core,
            nes_dg_fill_core,nes_dg_emu_iters,nes_dg_frame,
            nes_dg_draw_cnt,nes_dg_draw_overlap,
            nes_dg_fill_cnt,nes_dg_fill_overlap,
            nes_dg_flush_cnt,nes_dg_flush_overlap);
        while (nes_ckpt_got<nes_ckpt_put)
        {
          NESCkpt *ck=&nes_ckpt[nes_ckpt_got&(NES_CKPT_MAX-1)];
          AdamLog("NES ckpt f=%d instr=%d pc=0x%04X a=%02X x=%02X y=%02X "
              "sp=%02X p=%02X 2000=%02X 2001=%02X pad=%02X\n"
              "  sl=%d dot=%d vaddr=0x%04X t=0x%04X w=%d occ=%d out=%d "
              "pend=%d\n"
              "  ramsum=0x%08X vramsum=0x%08X oamsum=0x%08X\n",
              ck->frame,ck->instr,ck->pc,ck->a,ck->x,ck->y,ck->sp,
              ck->cpustatus,ck->r2000,ck->r2001,ck->pad,
              ck->scanline,ck->dot,ck->vaddr,ck->t,ck->w,
              ck->nmi_occ,ck->nmi_out,ck->nmi_pend,
              ck->ramsum,ck->vramsum,ck->oamsum);
          nes_ckpt_got++;
        }
        while (nes_isamp_got<nes_isamp_put)
        {
          NESISamp *is=&nes_isamp[nes_isamp_got&(NES_ISAMP_MAX-1)];
          AdamLog("NES isamp instr=%d op=%02X cyc=%d pc=0x%04X sl=%d dot=%d "
              "a=%02X x=%02X y=%02X sp=%02X p=%02X\n",
              is->instr,is->opcode,is->cycles,is->pc,is->scanline,is->dot,
              is->a,is->x,is->y,is->sp,is->cpustatus);
          nes_isamp_got++;
        }
        while (nes_nmi_trace_got<nes_nmi_trace_cnt)
        {
          NESNmiRec *nr=&nes_nmi_trace[nes_nmi_trace_got];
          AdamLog("NES nmi #%d f=%d instr=%d pc=0x%04X sl=%d dot=%d\n",
              nes_nmi_trace_got,nr->frame,nr->instr,nr->pc,
              nr->scanline,nr->dot);
          nes_nmi_trace_got++;
        }
        if (nes_dg_mirror_addr>=0)
          AdamLog("NES MIRROR: RAM[0x%04X] changed with no 6502 write: "
              "cpu_wrote=0x%02X now=0x%02X frame=%d\n",
              nes_dg_mirror_addr,nes_dg_mirror_want,nes_dg_mirror_got,
              nes_dg_mirror_frame);
        while (nes_dg_indy_got<nes_dg_indy_cnt)
        {
          AdamLog("NES indy #%d instr=%d pc=0x%04X eah=0x%04X eah2=0x%04X "
              "lo=0x%02X hi=0x%02X base=0x%04X y=0x%02X ea=0x%04X p=0x%02X\n",
              nes_dg_indy_got,nes_dg_indy_instr[nes_dg_indy_got],
              nes_dg_indy_pc[nes_dg_indy_got],nes_dg_indy_eah[nes_dg_indy_got],
              nes_dg_indy_eah2[nes_dg_indy_got],nes_dg_indy_lo[nes_dg_indy_got],
              nes_dg_indy_hi[nes_dg_indy_got],nes_dg_indy_base[nes_dg_indy_got],
              nes_dg_indy_y[nes_dg_indy_got],nes_dg_indy_ea[nes_dg_indy_got],
              nes_dg_indy_p[nes_dg_indy_got]);
          nes_dg_indy_got++;
        }
        while (nes_dg_pw_got<nes_dg_pw_cnt)
        {
          AdamLog("NES pw #%d instr=%d pc=0x%04X raw=0x%04X val=0x%02X "
              "zp06=0x%02X zp07=0x%02X\n",
              nes_dg_pw_got,nes_dg_pw_instr[nes_dg_pw_got],
              nes_dg_pw_pc[nes_dg_pw_got],nes_dg_pw_addr[nes_dg_pw_got],
              nes_dg_pw_val[nes_dg_pw_got],
              nes_dg_pw_zp6[nes_dg_pw_got],nes_dg_pw_zp7[nes_dg_pw_got]);
          nes_dg_pw_got++;
        }
        if (nes_dg_ppureg_addr>=0)
          AdamLog("NES MIRROR: PPUREG[0x%04X] changed with no 6502 write: "
              "cpu_wrote=0x%02X now=0x%02X frame=%d\n",
              nes_dg_ppureg_addr,nes_dg_ppureg_want,nes_dg_ppureg_got,
              nes_dg_mirror_frame);
        if (nes_dg_oamm_addr>=0)
          AdamLog("NES MIRROR: OAM[0x%02X] changed with no 6502 write: "
              "cpu_wrote=0x%02X now=0x%02X frame=%d\n",
              nes_dg_oamm_addr,nes_dg_oamm_want,nes_dg_oamm_got,
              nes_dg_mirror_frame);
        if (nes_dg_canary_frame>=0)
          AdamLog("NES CANARY: region=%d broke at frame=%d now=0x%08X "
              "want=0x%08X\n",
              nes_dg_canary_what,nes_dg_canary_frame,
              nes_dg_canary_now,nes_dg_canary_want);
        if (nes_dg_inc32_frame>=0 && !nes_dg_inc32_shown)
        {
          nes_dg_inc32_shown=TRUE;
          AdamLog("NES inc32: first 0x2000 write with bit2 set: val=0x%02X "
              "frame=%d\n",nes_dg_inc32_val,nes_dg_inc32_frame);
        }
        nes_dg_r2002=0;
        nes_dg_r2002_hit=0;
        nes_dg_nmi_set=0;
        nes_dg_nmi_clr=0;
        nes_dg_nmi_fire=0;
        nes_dg_w2000=0;
        nes_dg_w2001=0;
        nes_dg_r4016=0;
        nes_diag_instrs=0;
        nes_diag_frames=0;
      }
#endif
      NESSnapWindow;
      Sleep(20);
    }
  }
  catch
    PutExcept;

  nes_quit=TRUE;
  wait=0;
  while (!nes_task_done)
  {
    if (!TaskValidate(nes_emu_task) || ++wait>3000)
    {
      nes_emu_gen++;
      Kill(nes_emu_task,FALSE);
      break;
    }
    Sleep(1);
  }
  nes_emu_task=NULL;

  Fs->draw_it=NULL;
  SaveSRAM;
  PAPU_initBuffers;
  GrPaletteSet(&nes_sys_palette);
  Free(cartridgebuffer);
  cartridgebuffer=NULL;
  MMUFree;
  DCDel(gameCanvas);
  gameCanvas=NULL;
  DCDel(gameCanvas2x);
  gameCanvas2x=NULL;
  MenuPop;
  SettingsPop;
  DocClear;
}
