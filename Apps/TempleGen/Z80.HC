extern U32 read_memory(U32 address);
extern U0 write_memory(U32 address, U32 value);
extern U0 YMWrite(I64 port, I64 v);
extern I64 YMReadStatus();
extern U0 PSGWrite(I64 v);

#define ZB	0
#define ZC	1
#define ZD	2
#define ZE	3
#define ZH	4
#define ZL	5
#define ZF	6
#define ZA	7

#define ZFL_C	0x01
#define ZFL_N	0x02
#define ZFL_PV	0x04
#define ZFL_X	0x08
#define ZFL_H	0x10
#define ZFL_Y	0x20
#define ZFL_Z	0x40
#define ZFL_S	0x80

class CZ80
{
	U8 rg[8];
	U8 rg2[8];
	U16 ix,iy,sp,pc;
	U8 i,r;
	I64 iff1,iff2,im;
	I64 halted;
	I64 int_line;
	I64 idx;
	I64 ea;
	I64 bank;
	I64 cyc;
};
CZ80 z80;

I64 z80_bus_ack=0;
I64 z80_reset=0;

U8 z80_parity[256];
Bool z80_tabs_done=FALSE;

U8 z80_cyc[256]={
	 4,10, 7, 6, 4, 4, 7, 4, 4,11, 7, 6, 4, 4, 7, 4,
	 8,10, 7, 6, 4, 4, 7, 4,12,11, 7, 6, 4, 4, 7, 4,
	 7,10,16, 6, 4, 4, 7, 4, 7,11,16, 6, 4, 4, 7, 4,
	 7,10,13, 6,11,11,10, 4, 7,11,13, 6, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 7, 7, 7, 7, 7, 7, 4, 7, 4, 4, 4, 4, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
	 5,10,10,10,10,11, 7,11, 5,10,10, 8,10,17, 7,11,
	 5,10,10,11,10,11, 7,11, 5, 4,10,11,10, 8, 7,11,
	 5,10,10,19,10,11, 7,11, 5, 4,10, 4,10, 8, 7,11,
	 5,10,10, 4,10,11, 7,11, 5, 6,10, 4,10, 8, 7,11};

U0 Z80TablesInit()
{
	I64 i,j,n;
	if (z80_tabs_done)
		return;
	z80_tabs_done=TRUE;
	for (i=0; i<256; i++) {
		n=0;
		for (j=0; j<8; j++)
			if (i&(1<<j))
				n++;
		if (n&1)
			z80_parity[i]=0;
		else
			z80_parity[i]=ZFL_PV;
	}
}

U8 Z80Rd(I64 a)
{
	a&=0xFFFF;
	if (a<0x4000)
		return ZRAM[a&0x1FFF];
	if (a<0x6000)
		return YMReadStatus;
	if (a<0x8000)
		return 0xFF;
	return read_memory(((z80.bank<<15)+(a&0x7FFF))&0xFFFFFF);
}

U0 Z80Wr(I64 a, U8 v)
{
	a&=0xFFFF;
	if (a<0x4000) {
		ZRAM[a&0x1FFF]=v;
		return;
	}
	if (a<0x6000) {
		YMWrite(a&3,v);
		return;
	}
	if (a<0x6100) {
		z80.bank=((z80.bank>>1)|((v&1)<<8))&0x1FF;
		return;
	}
	if (a<0x7F00)
		return;
	if (a<0x8000) {
		if (0x10<=(a&0x1F)<0x18)
			PSGWrite(v);
		return;
	}
	write_memory(((z80.bank<<15)+(a&0x7FFF))&0xFFFFFF,v);
}

U8 Z80Fetch()
{
	I64 v=Z80Rd(z80.pc);
	z80.pc=(z80.pc+1)&0xFFFF;
	return v;
}

I64 Z80Fetch16()
{
	I64 lo=Z80Fetch;
	return lo|(Z80Fetch<<8);
}

I64 Z80FetchDisp()
{
	I64 d=Z80Fetch;
	if (d>127)
		d-=256;
	return d;
}

U0 Z80Push(I64 v)
{
	z80.sp=(z80.sp-1)&0xFFFF;
	Z80Wr(z80.sp,(v>>8)&0xFF);
	z80.sp=(z80.sp-1)&0xFFFF;
	Z80Wr(z80.sp,v&0xFF);
}

I64 Z80Pop()
{
	I64 v=Z80Rd(z80.sp);
	z80.sp=(z80.sp+1)&0xFFFF;
	v|=Z80Rd(z80.sp)<<8;
	z80.sp=(z80.sp+1)&0xFFFF;
	return v;
}

I64 Z80HL()
{
	if (z80.idx==1)
		return z80.ix;
	if (z80.idx==2)
		return z80.iy;
	return (z80.rg[ZH]<<8)|z80.rg[ZL];
}

U0 Z80SetHL(I64 v)
{
	v&=0xFFFF;
	if (z80.idx==1) {
		z80.ix=v;
		return;
	}
	if (z80.idx==2) {
		z80.iy=v;
		return;
	}
	z80.rg[ZH]=v>>8;
	z80.rg[ZL]=v&0xFF;
}

U0 Z80CalcEA()
{
	if (z80.idx)
		z80.ea=(Z80HL+Z80FetchDisp)&0xFFFF;
	else
		z80.ea=Z80HL;
}

U8 Z80RdR(I64 i)
{
	if (i==6)
		return Z80Rd(z80.ea);
	if (z80.idx && i==ZH)
		return Z80HL>>8;
	if (z80.idx && i==ZL)
		return Z80HL&0xFF;
	return z80.rg[i];
}

U0 Z80WrR(I64 i, U8 v)
{
	if (i==6) {
		Z80Wr(z80.ea,v);
		return;
	}
	if (z80.idx && i==ZH) {
		Z80SetHL((Z80HL&0x00FF)|(v<<8));
		return;
	}
	if (z80.idx && i==ZL) {
		Z80SetHL((Z80HL&0xFF00)|v);
		return;
	}
	z80.rg[i]=v;
}

I64 Z80RdPair(I64 p)
{
	switch (p) {
	case 0:	return (z80.rg[ZB]<<8)|z80.rg[ZC];
	case 1:	return (z80.rg[ZD]<<8)|z80.rg[ZE];
	case 2:	return Z80HL;
	}
	return z80.sp;
}

U0 Z80WrPair(I64 p, I64 v)
{
	v&=0xFFFF;
	switch (p) {
	case 0:	z80.rg[ZB]=v>>8; z80.rg[ZC]=v&0xFF; break;
	case 1:	z80.rg[ZD]=v>>8; z80.rg[ZE]=v&0xFF; break;
	case 2:	Z80SetHL(v); break;
	case 3:	z80.sp=v; break;
	}
}

I64 Z80RdPair2(I64 p)
{
	if (p==3)
		return (z80.rg[ZA]<<8)|z80.rg[ZF];
	return Z80RdPair(p);
}

U0 Z80WrPair2(I64 p, I64 v)
{
	if (p==3) {
		z80.rg[ZA]=(v>>8)&0xFF;
		z80.rg[ZF]=v&0xFF;
		return;
	}
	Z80WrPair(p,v);
}

Bool Z80Cond(I64 c)
{
	I64 f=z80.rg[ZF];
	switch (c) {
	case 0:	return !(f&ZFL_Z);
	case 1:	return (f&ZFL_Z)!=0;
	case 2:	return !(f&ZFL_C);
	case 3:	return (f&ZFL_C)!=0;
	case 4:	return !(f&ZFL_PV);
	case 5:	return (f&ZFL_PV)!=0;
	case 6:	return !(f&ZFL_S);
	}
	return (f&ZFL_S)!=0;
}

U8 Z80SzFlags(U8 v)
{
	I64 f=v&(ZFL_S|ZFL_X|ZFL_Y);
	if (!v)
		f|=ZFL_Z;
	return f;
}

U0 Z80Add(U8 v, I64 carry)
{
	I64 a=z80.rg[ZA],r=a+v+carry,h=(a&0xF)+(v&0xF)+carry;
	I64 f=Z80SzFlags(r&0xFF);
	if (r>0xFF)
		f|=ZFL_C;
	if (h>0xF)
		f|=ZFL_H;
	if (((a^v)&0x80)==0 && ((a^r)&0x80))
		f|=ZFL_PV;
	z80.rg[ZA]=r&0xFF;
	z80.rg[ZF]=f;
}

U0 Z80Sub(U8 v, I64 carry, Bool cp_only)
{
	I64 a=z80.rg[ZA],r=a-v-carry,h=(a&0xF)-(v&0xF)-carry;
	I64 f=Z80SzFlags(r&0xFF)|ZFL_N;
	if (r<0)
		f|=ZFL_C;
	if (h<0)
		f|=ZFL_H;
	if (((a^v)&0x80) && ((a^r)&0x80))
		f|=ZFL_PV;
	if (cp_only) {
		z80.rg[ZF]=(f&~(ZFL_X|ZFL_Y))|(v&(ZFL_X|ZFL_Y));
		return;
	}
	z80.rg[ZA]=r&0xFF;
	z80.rg[ZF]=f;
}

U0 Z80And(U8 v)
{
	z80.rg[ZA]&=v;
	z80.rg[ZF]=Z80SzFlags(z80.rg[ZA])|ZFL_H|z80_parity[z80.rg[ZA]];
}

U0 Z80Xor(U8 v)
{
	z80.rg[ZA]^=v;
	z80.rg[ZF]=Z80SzFlags(z80.rg[ZA])|z80_parity[z80.rg[ZA]];
}

U0 Z80Or(U8 v)
{
	z80.rg[ZA]|=v;
	z80.rg[ZF]=Z80SzFlags(z80.rg[ZA])|z80_parity[z80.rg[ZA]];
}

U0 Z80Alu(I64 op, U8 v)
{
	I64 c=0;
	if (z80.rg[ZF]&ZFL_C)
		c=1;
	switch (op) {
	case 0:	Z80Add(v,0); break;
	case 1:	Z80Add(v,c); break;
	case 2:	Z80Sub(v,0,FALSE); break;
	case 3:	Z80Sub(v,c,FALSE); break;
	case 4:	Z80And(v); break;
	case 5:	Z80Xor(v); break;
	case 6:	Z80Or(v); break;
	case 7:	Z80Sub(v,0,TRUE); break;
	}
}

U8 Z80Inc(U8 v)
{
	I64 r=(v+1)&0xFF,f=(z80.rg[ZF]&ZFL_C)|Z80SzFlags(r);
	if (!(r&0xF))
		f|=ZFL_H;
	if (r==0x80)
		f|=ZFL_PV;
	z80.rg[ZF]=f;
	return r;
}

U8 Z80Dec(U8 v)
{
	I64 r=(v-1)&0xFF,f=(z80.rg[ZF]&ZFL_C)|Z80SzFlags(r)|ZFL_N;
	if ((r&0xF)==0xF)
		f|=ZFL_H;
	if (r==0x7F)
		f|=ZFL_PV;
	z80.rg[ZF]=f;
	return r;
}

U0 Z80AddHL(I64 v)
{
	I64 hl=Z80HL,r=hl+v;
	I64 f=z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV);
	if (r>0xFFFF)
		f|=ZFL_C;
	if (((hl&0xFFF)+(v&0xFFF))>0xFFF)
		f|=ZFL_H;
	f|=(r>>8)&(ZFL_X|ZFL_Y);
	z80.rg[ZF]=f;
	Z80SetHL(r);
}

U0 Z80AdcHL(I64 v)
{
	I64 hl=Z80HL,c=0,r;
	I64 f;
	if (z80.rg[ZF]&ZFL_C)
		c=1;
	r=hl+v+c;
	f=((r>>8)&(ZFL_S|ZFL_X|ZFL_Y));
	if (!(r&0xFFFF))
		f|=ZFL_Z;
	if (r>0xFFFF)
		f|=ZFL_C;
	if (((hl&0xFFF)+(v&0xFFF)+c)>0xFFF)
		f|=ZFL_H;
	if (((hl^v)&0x8000)==0 && ((hl^r)&0x8000))
		f|=ZFL_PV;
	z80.rg[ZF]=f;
	Z80SetHL(r);
}

U0 Z80SbcHL(I64 v)
{
	I64 hl=Z80HL,c=0,r;
	I64 f;
	if (z80.rg[ZF]&ZFL_C)
		c=1;
	r=hl-v-c;
	f=((r>>8)&(ZFL_S|ZFL_X|ZFL_Y))|ZFL_N;
	if (!(r&0xFFFF))
		f|=ZFL_Z;
	if (r<0)
		f|=ZFL_C;
	if (((hl&0xFFF)-(v&0xFFF)-c)<0)
		f|=ZFL_H;
	if (((hl^v)&0x8000) && ((hl^r)&0x8000))
		f|=ZFL_PV;
	z80.rg[ZF]=f;
	Z80SetHL(r);
}

U0 Z80Daa()
{
	I64 a=z80.rg[ZA],corr=0,f=z80.rg[ZF],c=0,nf=f&ZFL_N,hf=0;
	if (f&ZFL_C)
		c=ZFL_C;
	if ((f&ZFL_H) || (a&0xF)>9)
		corr|=0x06;
	if (c || a>0x99)
		corr|=0x60;
	if (a>0x99)
		c=ZFL_C;
	if (nf) {
		if ((f&ZFL_H) && (a&0xF)<6)
			hf=ZFL_H;
		a=(a-corr)&0xFF;
	} else {
		if ((a&0xF)>9)
			hf=ZFL_H;
		a=(a+corr)&0xFF;
	}
	z80.rg[ZA]=a;
	z80.rg[ZF]=nf|c|hf|Z80SzFlags(a)|z80_parity[a];
}

U8 Z80Rot(I64 op, U8 v)
{
	I64 c=0,r=0,oc=0;
	if (z80.rg[ZF]&ZFL_C)
		oc=1;
	switch (op) {
	case 0:	c=(v>>7)&1; r=((v<<1)|c)&0xFF; break;
	case 1:	c=v&1; r=((v>>1)|(c<<7))&0xFF; break;
	case 2:	c=(v>>7)&1; r=((v<<1)|oc)&0xFF; break;
	case 3:	c=v&1; r=((v>>1)|(oc<<7))&0xFF; break;
	case 4:	c=(v>>7)&1; r=(v<<1)&0xFF; break;
	case 5:	c=v&1; r=((v>>1)|(v&0x80))&0xFF; break;
	case 6:	c=(v>>7)&1; r=((v<<1)|1)&0xFF; break;
	case 7:	c=v&1; r=(v>>1)&0xFF; break;
	}
	z80.rg[ZF]=Z80SzFlags(r)|z80_parity[r];
	if (c)
		z80.rg[ZF]|=ZFL_C;
	return r;
}

U0 Z80Bit(I64 b, U8 v)
{
	I64 f=(z80.rg[ZF]&ZFL_C)|ZFL_H;
	if (!(v&(1<<b)))
		f|=ZFL_Z|ZFL_PV;
	if (b==7 && (v&0x80))
		f|=ZFL_S;
	f|=v&(ZFL_X|ZFL_Y);
	z80.rg[ZF]=f;
}

I64 Z80OpCB()
{
	I64 op,x,y,z,cyc;
	I64 v;
	if (z80.idx)
		z80.ea=(Z80HL+Z80FetchDisp)&0xFFFF;
	else
		z80.ea=Z80HL;
	op=Z80Fetch;
	x=(op>>6)&3;
	y=(op>>3)&7;
	z=op&7;
	cyc=8;
	if (z==6 || z80.idx)
		cyc=15;
	if (z80.idx || z==6)
		v=Z80Rd(z80.ea);
	else
		v=z80.rg[z];
	if (x==0)
		v=Z80Rot(y,v);
	else if (x==1) {
		Z80Bit(y,v);
		return cyc;
	} else if (x==2)
		v&=~(1<<y);
	else
		v|=1<<y;
	if (z80.idx) {
		Z80Wr(z80.ea,v);
		if (z!=6)
			z80.rg[z]=v;
	} else if (z==6)
		Z80Wr(z80.ea,v);
	else
		z80.rg[z]=v;
	return cyc;
}

I64 Z80OpED()
{
	I64 op,x,y,z,p,q,n,a,v,hl,de,bc,step;
	op=Z80Fetch;
	x=(op>>6)&3;
	y=(op>>3)&7;
	z=op&7;
	p=y>>1;
	q=y&1;
	if (x==1) {
		switch (z) {
		case 0:
			v=0xFF;
			if (y!=6)
				z80.rg[y]=v;
			z80.rg[ZF]=(z80.rg[ZF]&ZFL_C)|Z80SzFlags(v)|
			        z80_parity[v];
			return 12;
		case 1:
			return 12;
		case 2:
			if (q)
				Z80AdcHL(Z80RdPair(p));
			else
				Z80SbcHL(Z80RdPair(p));
			return 15;
		case 3:
			n=Z80Fetch16;
			if (q)
				Z80WrPair(p,Z80Rd(n)|(Z80Rd((n+1)&0xFFFF)<<8));
			else {
				v=Z80RdPair(p);
				Z80Wr(n,v&0xFF);
				Z80Wr((n+1)&0xFFFF,(v>>8)&0xFF);
			}
			return 20;
		case 4:
			v=z80.rg[ZA];
			z80.rg[ZA]=0;
			Z80Sub(v,0,FALSE);
			return 8;
		case 5:
			z80.iff1=z80.iff2;
			z80.pc=Z80Pop;
			return 14;
		case 6:
			if (y==2 || y==6)
				z80.im=1;
			else if (y==3 || y==7)
				z80.im=2;
			else
				z80.im=0;
			return 8;
		case 7:
			switch (y) {
			case 0:	z80.i=z80.rg[ZA]; return 9;
			case 1:	z80.r=z80.rg[ZA]; return 9;
			case 2:
			case 3:
				if (y==2)
					z80.rg[ZA]=z80.i;
				else
					z80.rg[ZA]=z80.r;
				z80.rg[ZF]=(z80.rg[ZF]&ZFL_C)|
				        Z80SzFlags(z80.rg[ZA]);
				if (z80.iff2)
					z80.rg[ZF]|=ZFL_PV;
				return 9;
			case 4:
				a=Z80HL;
				v=Z80Rd(a);
				Z80Wr(a,((v>>4)|(z80.rg[ZA]<<4))&0xFF);
				z80.rg[ZA]=(z80.rg[ZA]&0xF0)|(v&0x0F);
				z80.rg[ZF]=(z80.rg[ZF]&ZFL_C)|
				        Z80SzFlags(z80.rg[ZA])|
				        z80_parity[z80.rg[ZA]];
				return 18;
			case 5:
				a=Z80HL;
				v=Z80Rd(a);
				Z80Wr(a,((v<<4)|(z80.rg[ZA]&0x0F))&0xFF);
				z80.rg[ZA]=(z80.rg[ZA]&0xF0)|((v>>4)&0x0F);
				z80.rg[ZF]=(z80.rg[ZF]&ZFL_C)|
				        Z80SzFlags(z80.rg[ZA])|
				        z80_parity[z80.rg[ZA]];
				return 18;
			}
			return 8;
		}
		return 8;
	}
	if (x==2 && z<=3 && y>=4) {
		hl=(z80.rg[ZH]<<8)|z80.rg[ZL];
		de=(z80.rg[ZD]<<8)|z80.rg[ZE];
		bc=(z80.rg[ZB]<<8)|z80.rg[ZC];
		step=1;
		if (y&1)
			step=-1;
		if (z==0) {
			Z80Wr(de,Z80Rd(hl));
			hl=(hl+step)&0xFFFF;
			de=(de+step)&0xFFFF;
			bc=(bc-1)&0xFFFF;
			z80.rg[ZH]=hl>>8; z80.rg[ZL]=hl&0xFF;
			z80.rg[ZD]=de>>8; z80.rg[ZE]=de&0xFF;
			z80.rg[ZB]=bc>>8; z80.rg[ZC]=bc&0xFF;
			z80.rg[ZF]&=ZFL_S|ZFL_Z|ZFL_C;
			if (bc)
				z80.rg[ZF]|=ZFL_PV;
			if (y>=6 && bc) {
				z80.pc=(z80.pc-2)&0xFFFF;
				return 21;
			}
			return 16;
		}
		if (z==1) {
			v=Z80Rd(hl);
			a=z80.rg[ZA];
			n=a-v;
			hl=(hl+step)&0xFFFF;
			bc=(bc-1)&0xFFFF;
			z80.rg[ZH]=hl>>8; z80.rg[ZL]=hl&0xFF;
			z80.rg[ZB]=bc>>8; z80.rg[ZC]=bc&0xFF;
			z80.rg[ZF]=(z80.rg[ZF]&ZFL_C)|ZFL_N|Z80SzFlags(n&0xFF);
			if (((a&0xF)-(v&0xF))<0)
				z80.rg[ZF]|=ZFL_H;
			if (bc)
				z80.rg[ZF]|=ZFL_PV;
			if (y>=6 && bc && (n&0xFF)) {
				z80.pc=(z80.pc-2)&0xFFFF;
				return 21;
			}
			return 16;
		}
		hl=(hl+step)&0xFFFF;
		z80.rg[ZB]=(z80.rg[ZB]-1)&0xFF;
		z80.rg[ZH]=hl>>8;
		z80.rg[ZL]=hl&0xFF;
		z80.rg[ZF]|=ZFL_N;
		if (!z80.rg[ZB])
			z80.rg[ZF]|=ZFL_Z;
		if (y>=6 && z80.rg[ZB]) {
			z80.pc=(z80.pc-2)&0xFFFF;
			return 21;
		}
		return 16;
	}
	return 8;
}

I64 Z80Exec1(U8 op)
{
	I64 x=(op>>6)&3,y=(op>>3)&7,z=op&7,p=y>>1,q=y&1;
	I64 cyc=z80_cyc[op],n,v,t;
	switch (x) {
	case 0:
		switch (z) {
		case 0:
			if (y==0)
				return cyc;
			if (y==1) {
				t=z80.rg[ZA];
				z80.rg[ZA]=z80.rg2[ZA];
				z80.rg2[ZA]=t;
				t=z80.rg[ZF];
				z80.rg[ZF]=z80.rg2[ZF];
				z80.rg2[ZF]=t;
				return cyc;
			}
			if (y==2) {
				n=Z80FetchDisp;
				z80.rg[ZB]=(z80.rg[ZB]-1)&0xFF;
				if (z80.rg[ZB]) {
					z80.pc=(z80.pc+n)&0xFFFF;
					return 13;
				}
				return 8;
			}
			n=Z80FetchDisp;
			if (y==3 || Z80Cond(y-4)) {
				z80.pc=(z80.pc+n)&0xFFFF;
				return 12;
			}
			return 7;
		case 1:
			if (q) {
				Z80AddHL(Z80RdPair(p));
				return 11;
			}
			Z80WrPair(p,Z80Fetch16);
			return cyc;
		case 2:
			if (!q) {
				switch (p) {
				case 0:	Z80Wr((z80.rg[ZB]<<8)|z80.rg[ZC],
					        z80.rg[ZA]);
					break;
				case 1:	Z80Wr((z80.rg[ZD]<<8)|z80.rg[ZE],
					        z80.rg[ZA]);
					break;
				case 2:	n=Z80Fetch16;
					v=Z80HL;
					Z80Wr(n,v&0xFF);
					Z80Wr((n+1)&0xFFFF,(v>>8)&0xFF);
					break;
				case 3:	Z80Wr(Z80Fetch16,z80.rg[ZA]); break;
				}
				return cyc;
			}
			switch (p) {
			case 0:	z80.rg[ZA]=Z80Rd((z80.rg[ZB]<<8)|z80.rg[ZC]);
				break;
			case 1:	z80.rg[ZA]=Z80Rd((z80.rg[ZD]<<8)|z80.rg[ZE]);
				break;
			case 2:	n=Z80Fetch16;
				Z80SetHL(Z80Rd(n)|(Z80Rd((n+1)&0xFFFF)<<8));
				break;
			case 3:	z80.rg[ZA]=Z80Rd(Z80Fetch16); break;
			}
			return cyc;
		case 3:
			if (q)
				Z80WrPair(p,Z80RdPair(p)-1);
			else
				Z80WrPair(p,Z80RdPair(p)+1);
			return cyc;
		case 4:
			if (y==6) {
				Z80CalcEA;
				Z80Wr(z80.ea,Z80Inc(Z80Rd(z80.ea)));
				return 11;
			}
			Z80WrR(y,Z80Inc(Z80RdR(y)));
			return cyc;
		case 5:
			if (y==6) {
				Z80CalcEA;
				Z80Wr(z80.ea,Z80Dec(Z80Rd(z80.ea)));
				return 11;
			}
			Z80WrR(y,Z80Dec(Z80RdR(y)));
			return cyc;
		case 6:
			if (y==6) {
				Z80CalcEA;
				Z80Wr(z80.ea,Z80Fetch);
				return 10;
			}
			Z80WrR(y,Z80Fetch);
			return cyc;
		}
		switch (y) {
		case 0:
			v=z80.rg[ZA];
			z80.rg[ZA]=((v<<1)|((v>>7)&1))&0xFF;
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV))|
			        ((v>>7)&1)|(z80.rg[ZA]&(ZFL_X|ZFL_Y));
			break;
		case 1:
			v=z80.rg[ZA];
			z80.rg[ZA]=((v>>1)|((v&1)<<7))&0xFF;
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV))|
			        (v&1)|(z80.rg[ZA]&(ZFL_X|ZFL_Y));
			break;
		case 2:
			v=z80.rg[ZA];
			t=0;
			if (z80.rg[ZF]&ZFL_C)
				t=1;
			z80.rg[ZA]=((v<<1)|t)&0xFF;
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV))|
			        ((v>>7)&1)|(z80.rg[ZA]&(ZFL_X|ZFL_Y));
			break;
		case 3:
			v=z80.rg[ZA];
			t=0;
			if (z80.rg[ZF]&ZFL_C)
				t=1;
			z80.rg[ZA]=((v>>1)|(t<<7))&0xFF;
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV))|
			        (v&1)|(z80.rg[ZA]&(ZFL_X|ZFL_Y));
			break;
		case 4:	Z80Daa; break;
		case 5:
			z80.rg[ZA]^=0xFF;
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV|ZFL_C))|
			        ZFL_H|ZFL_N|(z80.rg[ZA]&(ZFL_X|ZFL_Y));
			break;
		case 6:
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV))|ZFL_C|
			        (z80.rg[ZA]&(ZFL_X|ZFL_Y));
			break;
		case 7:
			v=z80.rg[ZF]&ZFL_C;
			z80.rg[ZF]=(z80.rg[ZF]&(ZFL_S|ZFL_Z|ZFL_PV))|
			        (z80.rg[ZA]&(ZFL_X|ZFL_Y));
			if (v)
				z80.rg[ZF]|=ZFL_H;
			else
				z80.rg[ZF]|=ZFL_C;
			break;
		}
		return cyc;

	case 1:
		if (y==6 && z==6) {
			z80.halted=1;
			return cyc;
		}
		if (z==6) {
			Z80CalcEA;
			z80.rg[y]=Z80Rd(z80.ea);
			return 7;
		}
		if (y==6) {
			Z80CalcEA;
			Z80Wr(z80.ea,z80.rg[z]);
			return 7;
		}
		Z80WrR(y,Z80RdR(z));
		return cyc;

	case 2:
		if (z==6) {
			Z80CalcEA;
			Z80Alu(y,Z80Rd(z80.ea));
			return 7;
		}
		Z80Alu(y,Z80RdR(z));
		return cyc;
	}

	switch (z) {
	case 0:
		if (Z80Cond(y)) {
			z80.pc=Z80Pop;
			return 11;
		}
		return 5;
	case 1:
		if (!q) {
			Z80WrPair2(p,Z80Pop);
			return cyc;
		}
		switch (p) {
		case 0:	z80.pc=Z80Pop; break;
		case 1:
			for (n=0; n<6; n++) {
				t=z80.rg[n];
				z80.rg[n]=z80.rg2[n];
				z80.rg2[n]=t;
			}
			break;
		case 2:	z80.pc=Z80HL; break;
		case 3:	z80.sp=Z80HL; break;
		}
		return cyc;
	case 2:
		n=Z80Fetch16;
		if (Z80Cond(y))
			z80.pc=n;
		return cyc;
	case 3:
		switch (y) {
		case 0:	z80.pc=Z80Fetch16; return 10;
		case 1:	return Z80OpCB;
		case 2:	Z80Fetch; return 11;
		case 3:	Z80Fetch; z80.rg[ZA]=0xFF; return 11;
		case 4:
			n=Z80Rd(z80.sp)|(Z80Rd((z80.sp+1)&0xFFFF)<<8);
			v=Z80HL;
			Z80Wr(z80.sp,v&0xFF);
			Z80Wr((z80.sp+1)&0xFFFF,(v>>8)&0xFF);
			Z80SetHL(n);
			return 19;
		case 5:
			t=z80.rg[ZD]; z80.rg[ZD]=z80.rg[ZH]; z80.rg[ZH]=t;
			t=z80.rg[ZE]; z80.rg[ZE]=z80.rg[ZL]; z80.rg[ZL]=t;
			return 4;
		case 6:	z80.iff1=0; z80.iff2=0; return 4;
		case 7:	z80.iff1=1; z80.iff2=1; return 4;
		}
		return cyc;
	case 4:
		n=Z80Fetch16;
		if (Z80Cond(y)) {
			Z80Push(z80.pc);
			z80.pc=n;
			return 17;
		}
		return 10;
	case 5:
		if (!q) {
			Z80Push(Z80RdPair2(p));
			return cyc;
		}
		if (p==0) {
			n=Z80Fetch16;
			Z80Push(z80.pc);
			z80.pc=n;
			return 17;
		}
		return cyc;
	case 6:
		Z80Alu(y,Z80Fetch);
		return cyc;
	}
	Z80Push(z80.pc);
	z80.pc=y*8;
	return 11;
}

I64 Z80Step()
{
	I64 op;
	I64 cyc=0;
	z80.idx=0;
	while (TRUE) {
		op=Z80Fetch;
		z80.r=(z80.r&0x80)|((z80.r+1)&0x7F);
		if (op==0xDD) {
			z80.idx=1;
			cyc+=4;
		} else if (op==0xFD) {
			z80.idx=2;
			cyc+=4;
		} else if (op==0xED) {
			z80.idx=0;
			return cyc+Z80OpED;
		} else
			return cyc+Z80Exec1(op);
	}
	return cyc;
}

U0 Z80Reset()
{
	I64 i;
	Z80TablesInit;
	for (i=0; i<8; i++) {
		z80.rg[i]=0xFF;
		z80.rg2[i]=0xFF;
	}
	z80.ix=0xFFFF;
	z80.iy=0xFFFF;
	z80.sp=0xFFFF;
	z80.pc=0;
	z80.i=0;
	z80.r=0;
	z80.iff1=0;
	z80.iff2=0;
	z80.im=0;
	z80.halted=0;
	z80.int_line=0;
	z80.idx=0;
	z80.ea=0;
	z80.bank=0;
	z80.cyc=0;
}

U0 Z80SetIrq(I64 on)
{
	z80.int_line=on;
}

Bool Z80Running()
{
	return z80_reset && !z80_bus_ack;
}

U0 Z80Run(I64 mcycles)
{
	I64 c;
	if (!Z80Running) {
		z80.cyc=0;
		return;
	}
	z80.cyc+=mcycles/15;
	while (z80.cyc>0) {
		if (z80.int_line && z80.iff1) {
			z80.iff1=0;
			z80.iff2=0;
			z80.halted=0;
			Z80Push(z80.pc);
			if (z80.im==2) {
				c=((z80.i<<8)|0xFF)&0xFFFF;
				z80.pc=Z80Rd(c)|(Z80Rd((c+1)&0xFFFF)<<8);
			} else
				z80.pc=0x38;
			z80.cyc-=13;
		}
		if (z80.halted) {
			z80.cyc=0;
			return;
		}
		z80.cyc-=Z80Step;
	}
}

U0 z80_ctrl_write(U32 address, U32 value)
{
	if (address == 0x1100)
		z80_bus_ack = !!value;
	else if (address == 0x1200) {
		if (!value)
			Z80Reset;
		z80_reset = !!value;
	}
}

U32 z80_ctrl_read(U32 address)
{
	if (address == 0x1100)
		return !(z80_reset && z80_bus_ack);
	return 0;
}
