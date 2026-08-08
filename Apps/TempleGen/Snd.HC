#define GEN_SND_RATE		24000
#define GEN_SND_FRAME_SAMPS	(GEN_SND_RATE/60)
#define GEN_SND_LEAD		2048
#define GEN_SND_FIFO_SIZE	16384

CFifoI64 *gen_snd_fifo=NULL;
I64 gen_snd_mixer_idx=-1;
I64 gen_snd_last=0;

#define EG_ATTACK	0
#define EG_DECAY	1
#define EG_SUSTAIN	2
#define EG_RELEASE	3
#define EG_OFF		4

class CYMOp
{
  I64 phase;
  I64 inc;
  I64 att;
  I64 state;
  I64 key;
  I64 dt,mul,tl,ks,ar,d1r,d2r,rr,sl_att,am;
  I64 r_row[4],r_shift[4];
  I64 out,out_prev;
};

class CYMCh
{
  CYMOp ops[4];
  I64 fnum,block,kc;
  I64 fb,algo;
  I64 pan_l,pan_r,ams;
  I64 fnum_latch;
};

class CYM2612
{
  CYMCh chs[6];
  I64 addr[2];
  I64 lfo_en,lfo_rate,lfo_phase,lfo_acc;
  I64 ch3_mode;
  I64 ch3_fnum[3],ch3_block[3],ch3_kc[3],ch3_latch;
  I64 dac_en,dac_val;
  I64 timer_a,timer_b;
  I64 timer_a_cnt,timer_b_cnt;
  I64 timer_ctrl,status;
  I64 native_acc;
  I64 eg_acc,eg_cnt;
};
CYM2612 ym;

class CPSG
{
  I64 latch_ch,latch_type;
  I64 tone[4];
  I64 vol[4];
  I64 cnt[4];
  I64 out[4];
  I64 nflip;
  I64 noise_lfsr;
};
CPSG psg;

I64 ym_slot_map[4]={0,2,1,3};
I64 ym_ch3_map[3]={2,0,1};

I64 ym_dt_tab[128]=
{
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,1,1,1,1,1,1,1,1,1,1,2,2,
  2,2,2,2,2,3,3,3,4,4,4,5,5,6,6,7,
  1,1,1,1,2,2,2,2,2,2,2,3,3,3,4,4,
  4,5,5,6,6,7,8,8,9,10,11,12,13,14,16,16,
  2,2,2,2,2,3,3,3,4,4,4,5,5,6,6,7,
  8,8,9,10,11,12,13,14,16,17,19,20,22,24,26,28
};

I64 ym_sl_tab[16]={0,32,64,96,128,160,192,224,
        256,288,320,352,384,416,448,1023
    };

I64 ym_eg_inc[19][8]=
{
  {0,1,0,1,0,1,0,1},{0,1,0,1,1,1,0,1},
  {0,1,1,1,0,1,1,1},{0,1,1,1,1,1,1,1},
  {1,1,1,1,1,1,1,1},{1,1,1,2,1,1,1,2},
  {1,2,1,2,1,2,1,2},{1,2,2,2,1,2,2,2},
  {2,2,2,2,2,2,2,2},{2,2,2,4,2,2,2,4},
  {2,4,2,4,2,4,2,4},{2,4,4,4,2,4,4,4},
  {4,4,4,4,4,4,4,4},{4,4,4,8,4,4,4,8},
  {4,8,4,8,4,8,4,8},{4,8,8,8,4,8,8,8},
  {8,8,8,8,8,8,8,8},{16,16,16,16,16,16,16,16},
  {0,0,0,0,0,0,0,0}
};

I64 ym_ams_depth[4]={0,15,63,126};

F64 ym_lfo_hz[8]={3.98,5.56,6.02,6.37,6.88,9.63,48.1,72.2};

Bool gen_snd_tables_init=FALSE;
I64 ym_sin[1024];
I64 ym_pow[1024];
I64 ym_native_ratio;
I64 ym_eg_ratio;
I64 ym_lfo_inc[8];
I64 psg_step;
I64 psg_vol_tab[16];

U0 GenSndTablesInit()
{
  I64 i;
  if (gen_snd_tables_init)
    return;
  gen_snd_tables_init=TRUE;
  for (i=0; i<1024; i++)
    ym_sin[i]=ToI64(Sin(6.28318530717959*i/1024)*8192.0);
  for (i=0; i<1024; i++)
    ym_pow[i]=ToI64(8191.0*Pow(2.0,-i/64.0));
  for (i=0; i<15; i++)
    psg_vol_tab[i]=ToI64(3000.0*Pow(10.0,-i*0.1));
  psg_vol_tab[15]=0;
  ym_native_ratio=ToI64(53693175.0/7/144/GEN_SND_RATE*65536.0);
  ym_eg_ratio=ToI64(53693175.0/7/144/3/GEN_SND_RATE*65536.0);
  psg_step=ToI64(3579545.0/16.0/GEN_SND_RATE*65536.0);
  for (i=0; i<8; i++)
    ym_lfo_inc[i]=ToI64(ym_lfo_hz[i]*128.0/GEN_SND_RATE*65536.0);
}

U0 YMRateSelect(I64 r, I64 *_row, I64 *_shift)
{
  if (r>63)
    r=63;
  if (r<2)
  {
    *_row=18;
    *_shift=0;
  }
  else if (r<48)
  {
    *_row=r&3;
    *_shift=11-(r>>2);
  }
  else
  {
    *_shift=0;
    if (r<52)
      *_row=4+(r&3);
    else if (r<56)
      *_row=8+(r&3);
    else if (r<60)
      *_row=12+(r&3);
    else if (r<62)
      *_row=16;
    else
      *_row=17;
  }
}

I64 YMKeyCode(I64 fnum, I64 block)
{
  I64 f11=(fnum>>10)&1;
  I64 lo=(fnum>>7)&7;
  I64 n3;
  if (f11)
    n3=(lo!=0);
  else
    n3=(lo==7);
  return (block<<2)|((f11<<1)+n3);
}

U0 YMOpRates(CYMOp *op, I64 kc)
{
  I64 rks=kc>>(3-op->ks);
  I64 r;
  r=op->ar;
  if (r)
    r=(2*r)+rks;
  YMRateSelect(r,&op->r_row[0],&op->r_shift[0]);
  r=op->d1r;
  if (r)
    r=(2*r)+rks;
  YMRateSelect(r,&op->r_row[1],&op->r_shift[1]);
  r=op->d2r;
  if (r)
    r=(2*r)+rks;
  YMRateSelect(r,&op->r_row[2],&op->r_shift[2]);
  r=(2*((op->rr<<1)+1))+rks;
  YMRateSelect(r,&op->r_row[3],&op->r_shift[3]);
}

U0 YMOpInc(CYMOp *op, I64 fnum, I64 block, I64 kc)
{
  I64 base=(fnum<<block)>>1;
  I64 d=ym_dt_tab[((op->dt&3)<<5)+kc];
  if (op->dt&4)
    base-=d;
  else
    base+=d;
  if (base<0)
    base=0;
  if (op->mul)
    base*=op->mul;
  else
    base>>=1;
  op->inc=(base*ym_native_ratio)>>16;
  YMOpRates(op,kc);
}

U0 YMChIncs(I64 chn)
{
  CYMCh *ch=&ym.chs[chn];
  I64 i;
  if (chn==2 && ym.ch3_mode)
  {
    for (i=0; i<3; i++)
      YMOpInc(&ch->ops[i],ym.ch3_fnum[i],ym.ch3_block[i],
          ym.ch3_kc[i]);
    YMOpInc(&ch->ops[3],ch->fnum,ch->block,ch->kc);
  }
  else
    for (i=0; i<4; i++)
      YMOpInc(&ch->ops[i],ch->fnum,ch->block,ch->kc);
}

U0 YMKeyOn(CYMOp *op)
{
  if (op->key)
    return;
  op->key=1;
  op->phase=0;
  if (op->r_row[0]==17 || op->att==0)
  {
    op->att=0;
    op->state=EG_DECAY;
  }
  else
    op->state=EG_ATTACK;
}

U0 YMKeyOff(CYMOp *op)
{
  if (!op->key)
    return;
  op->key=0;
  if (op->state!=EG_OFF)
    op->state=EG_RELEASE;
}

U0 YMEnvStep(CYMOp *op)
{
  I64 row,shift,inc,st=op->state;
  if (st>=EG_OFF)
    return;
  row=op->r_row[st];
  if (row==18)
    return;
  shift=op->r_shift[st];
  if (ym.eg_cnt&((1<<shift)-1))
    return;
  inc=ym_eg_inc[row][(ym.eg_cnt>>shift)&7];
  if (!inc)
    return;
  switch (st)
  {
  case EG_ATTACK:
    op->att+=((~op->att)*inc)>>4;
    if (op->att<=0)
    {
      op->att=0;
      op->state=EG_DECAY;
    }
    break;
  case EG_DECAY:
    op->att+=inc;
    if (op->att>=op->sl_att)
    {
      op->att=op->sl_att;
      op->state=EG_SUSTAIN;
    }
    break;
  case EG_SUSTAIN:
  case EG_RELEASE:
    op->att+=inc;
    if (op->att>=1023)
    {
      op->att=1023;
      if (st==EG_RELEASE)
        op->state=EG_OFF;
    }
    break;
  }
}

I64 YMOpOut(CYMOp *op, I64 mod, I64 am)
{
  I64 idx=((op->phase>>10)+(mod>>1))&1023;
  I64 a=op->att+(op->tl<<3);
  if (op->am)
    a+=am;
  if (a>1023)
    a=1023;
  op->phase+=op->inc;
  return (ym_sin[idx]*ym_pow[a])>>13;
}

I64 YMChOut(CYMCh *ch, I64 am)
{
  CYMOp *o1=&ch->ops[0],*o2=&ch->ops[1],*o3=&ch->ops[2],
         *o4=&ch->ops[3];
  I64 m1,out1,out;
  if (ch->fb)
    m1=(o1->out+o1->out_prev)>>(10-ch->fb);
  else
    m1=0;
  out1=YMOpOut(o1,m1,am);
  o1->out_prev=o1->out;
  o1->out=out1;
  switch (ch->algo)
  {
  case 0:
    out=YMOpOut(o4,YMOpOut(o3,YMOpOut(o2,out1,am),am),am);
    break;
  case 1:
    out=YMOpOut(o4,YMOpOut(o3,YMOpOut(o2,0,am)+out1,am),am);
    break;
  case 2:
    out=YMOpOut(o4,YMOpOut(o3,YMOpOut(o2,0,am),am)+out1,am);
    break;
  case 3:
    out=YMOpOut(o4,YMOpOut(o2,out1,am)+YMOpOut(o3,0,am),am);
    break;
  case 4:
    out=YMOpOut(o2,out1,am)+YMOpOut(o4,YMOpOut(o3,0,am),am);
    break;
  case 5:
    out=YMOpOut(o2,out1,am)+YMOpOut(o3,out1,am)+
        YMOpOut(o4,out1,am);
    break;
  case 6:
    out=YMOpOut(o2,out1,am)+YMOpOut(o3,0,am)+YMOpOut(o4,0,am);
    break;
  default:
    out=out1+YMOpOut(o2,0,am)+YMOpOut(o3,0,am)+YMOpOut(o4,0,am);
    break;
  }
  return out;
}

U0 PSGWrite(I64 v)
{
  I64 ch;
  v&=0xFF;
  if (v&0x80)
  {
    ch=(v>>5)&3;
    psg.latch_ch=ch;
    psg.latch_type=(v>>4)&1;
    if (psg.latch_type)
      psg.vol[ch]=v&15;
    else if (ch==3)
    {
      psg.tone[3]=v&7;
      psg.noise_lfsr=0x8000;
    }
    else
      psg.tone[ch]=(psg.tone[ch]&0x3F0)|(v&15);
  }
  else
  {
    ch=psg.latch_ch;
    if (psg.latch_type)
      psg.vol[ch]=v&15;
    else if (ch==3)
    {
      psg.tone[3]=v&7;
      psg.noise_lfsr=0x8000;
    }
    else
      psg.tone[ch]=(psg.tone[ch]&15)|((v&0x3F)<<4);
  }
}

I64 PSGSample()
{
  I64 i,fb,nper,out=0;
  for (i=0; i<3; i++)
  {
    if (psg.tone[i]>1)
    {
      psg.cnt[i]-=psg_step;
      while (psg.cnt[i]<=0)
      {
        psg.cnt[i]+=psg.tone[i]<<16;
        psg.out[i]^=1;
      }
    }
    else
      psg.out[i]=1;
    if (psg.out[i])
      out+=psg_vol_tab[psg.vol[i]];
    else
      out-=psg_vol_tab[psg.vol[i]];
  }
  switch (psg.tone[3]&3)
  {
  case 0:
    nper=0x10;
    break;
  case 1:
    nper=0x20;
    break;
  case 2:
    nper=0x40;
    break;
  default:
    nper=psg.tone[2];
    if (nper<1)
      nper=1;
  }
  psg.cnt[3]-=psg_step;
  while (psg.cnt[3]<=0)
  {
    psg.cnt[3]+=nper<<16;
    psg.nflip^=1;
    if (psg.nflip)
    {
      if (psg.tone[3]&4)
        fb=(psg.noise_lfsr&1)^((psg.noise_lfsr>>3)&1);
      else
        fb=psg.noise_lfsr&1;
      psg.noise_lfsr=(psg.noise_lfsr>>1)|(fb<<15);
    }
  }
  if (psg.noise_lfsr&1)
    out+=psg_vol_tab[psg.vol[3]];
  else
    out-=psg_vol_tab[psg.vol[3]];
  return out;
}

U0 YMWriteReg(I64 part, I64 r, I64 v)
{
  I64 chn,i;
  CYMCh *ch;
  CYMOp *op;
  if (r<0x30)
  {
    if (part)
      return;
    switch (r)
    {
    case 0x22:
      ym.lfo_en=(v>>3)&1;
      ym.lfo_rate=v&7;
      break;
    case 0x24:
      ym.timer_a=(ym.timer_a&3)|((v&0xFF)<<2);
      break;
    case 0x25:
      ym.timer_a=(ym.timer_a&0x3FC)|(v&3);
      break;
    case 0x26:
      ym.timer_b=v&0xFF;
      break;
    case 0x27:
      ym.ch3_mode=(v>>6)&3;
      if ((v&1) && !(ym.timer_ctrl&1))
        ym.timer_a_cnt=1024-ym.timer_a;
      if ((v&2) && !(ym.timer_ctrl&2))
        ym.timer_b_cnt=(256-ym.timer_b)<<4;
      ym.timer_ctrl=v&0xF;
      if (v&0x10)
        ym.status&=~1;
      if (v&0x20)
        ym.status&=~2;
      YMChIncs(2);
      break;
    case 0x28:
      chn=v&7;
      if ((chn&3)==3)
        break;
      chn=((chn>>2)*3)+(chn&3);
      ch=&ym.chs[chn];
      for (i=0; i<4; i++)
        if (v&(0x10<<i))
          YMKeyOn(&ch->ops[i]);
        else
          YMKeyOff(&ch->ops[i]);
      break;
    case 0x2A:
      ym.dac_val=v&0xFF;
      break;
    case 0x2B:
      ym.dac_en=(v>>7)&1;
      break;
    }
    return;
  }
  chn=r&3;
  if (r<0xA0)
  {
    if (chn==3)
      return;
    chn+=part*3;
    op=&ym.chs[chn].ops[ym_slot_map[(r>>2)&3]];
    switch (r&0xF0)
    {
    case 0x30:
      op->dt=(v>>4)&7;
      op->mul=v&15;
      YMChIncs(chn);
      break;
    case 0x40:
      op->tl=v&0x7F;
      break;
    case 0x50:
      op->ks=(v>>6)&3;
      op->ar=v&31;
      YMChIncs(chn);
      break;
    case 0x60:
      op->am=(v>>7)&1;
      op->d1r=v&31;
      YMChIncs(chn);
      break;
    case 0x70:
      op->d2r=v&31;
      YMChIncs(chn);
      break;
    case 0x80:
      op->sl_att=ym_sl_tab[(v>>4)&15];
      op->rr=v&15;
      YMChIncs(chn);
      break;
    }
    return;
  }
  switch (r&0xFC)
  {
  case 0xA0:
    if (chn==3)
      break;
    chn+=part*3;
    ch=&ym.chs[chn];
    ch->fnum=((ch->fnum_latch&7)<<8)|(v&0xFF);
    ch->block=(ch->fnum_latch>>3)&7;
    ch->kc=YMKeyCode(ch->fnum,ch->block);
    YMChIncs(chn);
    break;
  case 0xA4:
    if (chn==3)
      break;
    chn+=part*3;
    ym.chs[chn].fnum_latch=v&0x3F;
    break;
  case 0xA8:
    if (part || chn==3)
      break;
    i=ym_ch3_map[chn];
    ym.ch3_fnum[i]=((ym.ch3_latch&7)<<8)|(v&0xFF);
    ym.ch3_block[i]=(ym.ch3_latch>>3)&7;
    ym.ch3_kc[i]=YMKeyCode(ym.ch3_fnum[i],ym.ch3_block[i]);
    YMChIncs(2);
    break;
  case 0xAC:
    if (part || chn==3)
      break;
    ym.ch3_latch=v&0x3F;
    break;
  case 0xB0:
    if (chn==3)
      break;
    chn+=part*3;
    ch=&ym.chs[chn];
    ch->fb=(v>>3)&7;
    ch->algo=v&7;
    break;
  case 0xB4:
    if (chn==3)
      break;
    chn+=part*3;
    ch=&ym.chs[chn];
    ch->pan_l=(v>>7)&1;
    ch->pan_r=(v>>6)&1;
    ch->ams=(v>>4)&3;
    break;
  }
}

U0 YMWrite(I64 port, I64 v)
{
  v&=0xFF;
  switch (port&3)
  {
  case 0:
    ym.addr[0]=v;
    break;
  case 1:
    YMWriteReg(0,ym.addr[0],v);
    break;
  case 2:
    ym.addr[1]=v;
    break;
  case 3:
    YMWriteReg(1,ym.addr[1],v);
    break;
  }
}

I64 YMReadStatus()
{
  return ym.status;
}

U0 YMTimerStep(I64 t)
{
  if (ym.timer_ctrl&1)
  {
    ym.timer_a_cnt-=t;
    while (ym.timer_a_cnt<=0)
    {
      ym.timer_a_cnt+=1024-ym.timer_a;
      if (ym.timer_ctrl&4)
        ym.status|=1;
    }
  }
  if (ym.timer_ctrl&2)
  {
    ym.timer_b_cnt-=t;
    while (ym.timer_b_cnt<=0)
    {
      ym.timer_b_cnt+=(256-ym.timer_b)<<4;
      if (ym.timer_ctrl&8)
        ym.status|=2;
    }
  }
}

I64 GenSndSample()
{
  I64 i,t,am,lam,ch_out,l=0,r=0,samp=0;
  CYMCh *ch;
  if (ym.lfo_en)
  {
    ym.lfo_acc+=ym_lfo_inc[ym.lfo_rate];
    ym.lfo_phase=(ym.lfo_phase+(ym.lfo_acc>>16))&127;
    ym.lfo_acc&=0xFFFF;
  }
  lam=ym.lfo_phase;
  if (lam>=64)
    lam=127-lam;
  lam<<=1;
  ym.eg_acc+=ym_eg_ratio;
  t=ym.eg_acc>>16;
  ym.eg_acc&=0xFFFF;
  while (t--)
  {
    ym.eg_cnt++;
    for (i=0; i<6; i++)
    {
      ch=&ym.chs[i];
      YMEnvStep(&ch->ops[0]);
      YMEnvStep(&ch->ops[1]);
      YMEnvStep(&ch->ops[2]);
      YMEnvStep(&ch->ops[3]);
    }
  }
  ym.native_acc+=ym_native_ratio;
  t=ym.native_acc>>16;
  ym.native_acc&=0xFFFF;
  YMTimerStep(t);
  for (i=0; i<6; i++)
  {
    ch=&ym.chs[i];
    am=(lam*ym_ams_depth[ch->ams])>>7;
    if (i==5 && ym.dac_en)
      ch_out=(ym.dac_val-0x80)<<6;
    else
      ch_out=YMChOut(ch,am);
    if (ch_out>8191)
      ch_out=8191;
    else if (ch_out<-8192)
      ch_out=-8192;
    if (ch->pan_l)
      l+=ch_out;
    if (ch->pan_r)
      r+=ch_out;
  }
  t=PSGSample;
  l+=t;
  r+=t;
  if (l>32767)
    l=32767;
  else if (l<-32768)
    l=-32768;
  if (r>32767)
    r=32767;
  else if (r<-32768)
    r=-32768;
  samp.i16[0]=l;
  samp.i16[1]=r;
  return samp;
}

U0 GenSndFrame()
{
  I64 i;
  if (!gen_snd_fifo)
  {
    YMTimerStep((ym_native_ratio*GEN_SND_FRAME_SAMPS)>>16);
    return;
  }
  for (i=0; i<GEN_SND_FRAME_SAMPS; i++)
    FifoI64Ins(gen_snd_fifo,GenSndSample);
}

U0 GenSndThrottle()
{
  I64 timeout=200;
  if (gen_snd_fifo && gen_snd_mixer_idx>=0)
    while (FifoI64Cnt(gen_snd_fifo)>GEN_SND_LEAD && timeout-->0)
      Sleep(1);
}

U0 GenSndReset()
{
  I64 i,j;
  CYMOp *op;
  GenSndTablesInit;
  ZeroClass(&ym);
  for (i=0; i<6; i++)
    for (j=0; j<4; j++)
    {
      op=&ym.chs[i].ops[j];
      op->state=EG_OFF;
      op->att=1023;
      op->sl_att=ym_sl_tab[0];
      YMOpRates(op,0);
    }
  ZeroClass(&psg);
  for (i=0; i<4; i++)
    psg.vol[i]=15;
  psg.noise_lfsr=0x8000;
}

#ifdef MIXER_MAX_SRC

U0 GenSndFillBuf(SND_OUT_CONTAINER *buf, I64 buf_num)
{
  I64 j=0,prev;
  no_warn buf_num;
  if (!gen_snd_fifo) {
    MemSet(buf,0,SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
    return;
  }
  while (j<SND_BUF_LEN)
  {
    prev=gen_snd_last;
    FifoI64Rem(gen_snd_fifo,&gen_snd_last);
    buf[j++]=ToI64(Clamp((prev.i16[0]+gen_snd_last.i16[0])/
                80000.0*snd_vol,-1.0,1.0)*I32_MAX)&~0xFF;
    buf[j++]=ToI64(Clamp((prev.i16[1]+gen_snd_last.i16[1])/
                80000.0*snd_vol,-1.0,1.0)*I32_MAX)&~0xFF;
    buf[j++]=ToI64(Clamp(gen_snd_last.i16[0]/
                40000.0*snd_vol,-1.0,1.0)*I32_MAX)&~0xFF;
    buf[j++]=ToI64(Clamp(gen_snd_last.i16[1]/
                40000.0*snd_vol,-1.0,1.0)*I32_MAX)&~0xFF;
  }
}

U0 GenSndInstall()
{
  if (!gen_snd_fifo)
    gen_snd_fifo=FifoI64New(GEN_SND_FIFO_SIZE);
  gen_snd_mixer_idx=MixerRegister("GEN",&GenSndFillBuf);
}

#endif

U0 GenSndUninstall()
{
#ifdef MIXER_MAX_SRC
  if (gen_snd_mixer_idx>=0) {
    MixerUnregister(gen_snd_mixer_idx);
    gen_snd_mixer_idx=-1;
  }
#endif
  if (gen_snd_fifo)
    FifoI64Flush(gen_snd_fifo);
  gen_snd_last=0;
}

#ifdef MIXER_MAX_SRC

if (snd_dev==SD_HD_AUDIO)
{
  GenSndInstall;
	"TempleGen: YM2612+PSG registered with the mixer as \"GEN\".\n";
}
else
  "TempleGen: HD Audio inactive -- running silent. Bring up "
		"Demo/Snd/HDAudio.HC and Demo/Snd/HDMixer.HC first.\n";

#else

"TempleGen: Demo/Snd/HDMixer.HC not loaded -- running silent. Load "
"Demo/Snd/HDAudio.HC and Demo/Snd/HDMixer.HC before TempleGen.HC "
	"for sound.\n";

#endif
