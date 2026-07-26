
#help_index "Snd/OPL2"

#define OPL2EMU_CHANS	9
#define OPL2EMU_OPS	18

// Anti-click de-glitching.  A key-on that lands while the channel is still
// sounding (SndM changing note/freq) slams the envelope back to zero, and a
// key-off on an instrument with a fast release chops the waveform mid-cycle.
// Both are steps in the output -- an audible click.  When opl2_fade_mS is
// non-zero a brief linear gain ramp is run at every key transition: fade the
// old note out, then retrigger, then fade the new note in.  Retriggers are
// held off until the fade-out finishes, so the worst-case note latency is
// one fade time.  A key-off is only ramped when the instrument's release is
// at least as quick as the ramp, so slow release tails survive intact.
// Set to 0.0 for the old instant on/off behavior.
// OPL2.HC's OPL_CLICK_FADE define sets this at load time.
#define OPL2_FADE_mS	4.0
F64 opl2_fade_mS=OPL2_FADE_mS;

class COPL2Op
{
  U8 mult,ksl,tl,ar,dr,sl,rr,ws;
  Bool am,vib,egt,ksr;

  I64 chan;

  F64 phase;
  F64 phase_inc;
  F64 out;

  I64 env_stage;
  F64 env;
  F64 env_target;
  F64 env_coeff;
} opl2_ops[OPL2EMU_OPS];

class COPL2Chan
{
  U16 fnum;
  U8 block;
  Bool key_on;
  U8 feedback;
  Bool connection;
  F64 freq;
  F64 fb_mem[2];

  //Anti-click ramp.  fade_dir is +1 fading in, -1 fading out, 0 idle.
  //key_pend is a key-on waiting for the fade-out to reach silence.
  F64 fade,fade_inc;
  I64 fade_dir;
  Bool key_pend;
} opl2_chans[OPL2EMU_CHANS];

static I64 opl2_chan_op1[OPL2EMU_CHANS]={0,1,2, 6,7,8,  12,13,14};
static I64 opl2_chan_op2[OPL2EMU_CHANS]={3,4,5, 9,10,11,15,16,17};

static F64 opl2_mult_tab[16]=
    {0.5,1,2,3,4,5,6,7,8,9,10,10,12,12,15,15};

Bool opl2_ws_enable=FALSE;
F64 opl2_lfo_phase=0.0;
F64 opl2_am_depth=0.0,opl2_vib_depth=0.0;

I64 opl2emu_mixer_idx=-1;

I64 OPL2EmuReg2Op(I64 offset)
{
  I64 grp=offset/8,sub=offset%8;
  if (sub>5) return -1;
  return grp*6+sub;
}

F64 OPL2EmuCoeffForRate(I64 rate,Bool is_attack)
{
  F64 t;
  if (!rate) return 0.0;
  if (is_attack)
    t=6.0/(1<<(rate-1));
  else
    t=16.0/(1<<(rate-1));
  return 1.0-Exp(-1.0/(t*SND_SAMPLE_RATE));
}

I64 OPL2EmuRateScale(COPL2Op *op)
{
  I64 block=opl2_chans[op->chan].block;
  I64 fnum_msb=opl2_chans[op->chan].fnum>>9&1;
  I64 rof=block<<1|fnum_msb;
  if (!op->ksr) rof>>=2;
  return rof;
}

U0 OPL2EmuEnterRelease(COPL2Op *op)
{
  I64 er=ClampI64(op->rr+(OPL2EmuRateScale(op)>>1),0,15);
  op->env_stage=4;
  op->env_target=0.0;
  op->env_coeff=OPL2EmuCoeffForRate(er,FALSE);
}

U0 OPL2EmuEnterDecay(COPL2Op *op)
{
  I64 er=ClampI64(op->dr+(OPL2EmuRateScale(op)>>1),0,15);
  op->env_stage=2;
  if (op->sl==15)
    op->env_target=0.0;
  else
    op->env_target=Pow(10.0,-(op->sl*3.0)/20.0);
  op->env_coeff=OPL2EmuCoeffForRate(er,FALSE);
}

U0 OPL2EmuEnvStep(COPL2Op *op)
{
  switch (op->env_stage) {
    case 1:
      op->env+=(1.0-op->env)*op->env_coeff;
      if (op->env>=0.999) {
	op->env=1.0;
	OPL2EmuEnterDecay(op);
      }
      break;
    case 2:
      op->env+=(op->env_target-op->env)*op->env_coeff;
      if (Abs(op->env-op->env_target)<0.001) {
	op->env=op->env_target;
	if (op->egt)
	  op->env_stage=3;
	else
	  OPL2EmuEnterRelease(op);
      }
      break;
    case 3:
      break;
    case 4:
      op->env+=(0.0-op->env)*op->env_coeff;
      if (op->env<0.0005) {
	op->env=0.0;
	op->env_stage=0;
      }
      break;
  }
}

U0 OPL2EmuChanFreqUpdate(I64 c)
{
  COPL2Chan *ch=&opl2_chans[c];
  COPL2Op *op;
  I64 i,idx;
  ch->freq=ch->fnum*49716.0/(1<<(20-ch->block));
  for (i=0;i<2;i++) {
    if (i)
      idx=opl2_chan_op2[c];
    else
      idx=opl2_chan_op1[c];
    op=&opl2_ops[idx];
    op->phase_inc=ch->freq*opl2_mult_tab[op->mult]/SND_SAMPLE_RATE;
  }
}

U0 OPL2EmuKeyOn(I64 c)
{
  I64 i,er,ops[2];
  COPL2Op *op;
  ops[0]=opl2_chan_op1[c];
  ops[1]=opl2_chan_op2[c];
  for (i=0;i<2;i++) {
    op=&opl2_ops[ops[i]];
    er=ClampI64(op->ar+(OPL2EmuRateScale(op)>>1),0,15);
    op->phase=0.0;
    op->env=0.0;
    op->env_stage=1;
    op->env_target=1.0;
    op->env_coeff=OPL2EmuCoeffForRate(er,TRUE);
  }
}

U0 OPL2EmuKeyOff(I64 c)
{
  OPL2EmuEnterRelease(&opl2_ops[opl2_chan_op1[c]]);
  OPL2EmuEnterRelease(&opl2_ops[opl2_chan_op2[c]]);
}

F64 OPL2EmuFadeInc()
{//Per-sample step of the anti-click ramp.
  F64 n=opl2_fade_mS*SND_SAMPLE_RATE/1000.0;
  if (n<1.0) n=1.0;
  return 1.0/n;
}

U0 OPL2EmuFadeStart(I64 c,I64 dir)
{//Begin an anti-click gain ramp on a channel.  dir is +1 in, -1 out.
  COPL2Chan *ch=&opl2_chans[c];
  ch->fade_inc=OPL2EmuFadeInc();
  ch->fade_dir=dir;
}

Bool OPL2EmuChanAudible(I64 c)
{//Is this channel putting out anything a key change could step on?
  if (opl2_chans[c].fade<=0.0) return FALSE;
  if (opl2_ops[opl2_chan_op1[c]].env_stage ||
	opl2_ops[opl2_chan_op2[c]].env_stage)
    return TRUE;
  return FALSE;
}

U0 OPL2EmuKeyOnEvent(I64 c)
{//Key-on from a register write.  Retriggers wait out a fade of the old note.
  COPL2Chan *ch=&opl2_chans[c];
  if (opl2_fade_mS<=0.0) {
    ch->fade=1.0;
    ch->fade_dir=0;
    ch->key_pend=FALSE;
    OPL2EmuKeyOn(c);
    return;
  }
  if (OPL2EmuChanAudible(c)) {
    ch->key_pend=TRUE;
    OPL2EmuFadeStart(c,-1);
    return;
  }
  ch->key_pend=FALSE;
  ch->fade=0.0;
  OPL2EmuKeyOn(c);
  OPL2EmuFadeStart(c,1);
}

U0 OPL2EmuKeyOffEvent(I64 c)
{//Key-off from a register write.  The ramp only runs when the instrument's
 //own release is at least as quick as the fade -- a slow release is already
 //a smooth fade and ramping over it would chop the note's tail off.
  COPL2Chan *ch=&opl2_chans[c];
  COPL2Op *car=&opl2_ops[opl2_chan_op2[c]];
  ch->key_pend=FALSE;
  OPL2EmuKeyOff(c);
  if (opl2_fade_mS>0.0 && car->env_coeff>=OPL2EmuFadeInc())
    OPL2EmuFadeStart(c,-1);
}

U0 OPL2EmuOpWrite(I64 op_idx,I64 reg_group,U8 data)
{
  COPL2Op *op=&opl2_ops[op_idx];
  switch (reg_group) {
    case 0x20:
      op->am =Bt(&data,7);
      op->vib=Bt(&data,6);
      op->egt=Bt(&data,5);
      op->ksr=Bt(&data,4);
      op->mult=data&0xF;
      OPL2EmuChanFreqUpdate(op->chan);
      break;
    case 0x40:
      op->ksl=data>>6&3;
      op->tl =data&0x3F;
      break;
    case 0x60:
      op->ar=data>>4&0xF;
      op->dr=data&0xF;
      break;
    case 0x80:
      op->sl=data>>4&0xF;
      op->rr=data&0xF;
      break;
    case 0xE0:
      op->ws=data&3;
      break;
  }
}

U0 OPLEmuWriteReg(I64 r,U8 data)
{
  I64 op_idx,c;
  Bool key;
  if (0x20<=r<=0x35)
    { if ((op_idx=OPL2EmuReg2Op(r-0x20))>=0) OPL2EmuOpWrite(op_idx,0x20,data); }
  else if (0x40<=r<=0x55)
    { if ((op_idx=OPL2EmuReg2Op(r-0x40))>=0) OPL2EmuOpWrite(op_idx,0x40,data); }
  else if (0x60<=r<=0x75)
    { if ((op_idx=OPL2EmuReg2Op(r-0x60))>=0) OPL2EmuOpWrite(op_idx,0x60,data); }
  else if (0x80<=r<=0x95)
    { if ((op_idx=OPL2EmuReg2Op(r-0x80))>=0) OPL2EmuOpWrite(op_idx,0x80,data); }
  else if (0xA0<=r<=0xA8) {
    c=r-0xA0;
    opl2_chans[c].fnum=opl2_chans[c].fnum&0x300|data;
    OPL2EmuChanFreqUpdate(c);
  } else if (0xB0<=r<=0xB8) {
    c=r-0xB0;
    opl2_chans[c].fnum=opl2_chans[c].fnum&0xFF|(data&3)<<8;
    opl2_chans[c].block=data>>2&7;
    key=Bt(&data,5);
    if (key && !opl2_chans[c].key_on)
      OPL2EmuKeyOnEvent(c);
    else if (!key && opl2_chans[c].key_on)
      OPL2EmuKeyOffEvent(c);
    opl2_chans[c].key_on=key;
    OPL2EmuChanFreqUpdate(c);
  } else if (0xC0<=r<=0xC8) {
    c=r-0xC0;
    opl2_chans[c].feedback=data>>1&7;
    opl2_chans[c].connection=Bt(&data,0);
  } else if (0xE0<=r<=0xF5) {
    if ((op_idx=OPL2EmuReg2Op(r-0xE0))>=0) OPL2EmuOpWrite(op_idx,0xE0,data);
  } else if (r==0x01)
    opl2_ws_enable=Bt(&data,5);
  else if (r==0xBD) {
    if (Bt(&data,7))
      opl2_am_depth=1.0;
    else
      opl2_am_depth=0.25;
    if (Bt(&data,6))
      opl2_vib_depth=1.0;
    else
      opl2_vib_depth=0.35;
  }
}

F64 OPL2EmuWave(I64 ws,F64 ph)
{
  F64 frac=ph-ToI64(ph);
  if (frac<0.0) frac+=1.0;
  if (!opl2_ws_enable) ws=0;
  switch (ws) {
    case 1:
      if (frac<0.5)
	return Sin(2*ã*frac);
      return 0.0;
    case 2: return Abs(Sin(2*ã*frac));
    case 3:
      if (frac<0.25)
	return Sin(2*ã*frac);
      if (0.5<=frac<0.75)
	return Sin(2*ã*(frac-0.5));
      return 0.0;
  }
  return Sin(2*ã*frac);
}

F64 OPL2EmuTLAmplitude(COPL2Op *op)
{
  F64 db=op->tl*0.75;
  static F64 ksl_db_per_block[4]={0.0,3.0,1.5,6.0};
  db+=ksl_db_per_block[op->ksl]*opl2_chans[op->chan].block;
  return Pow(10.0,-db/20.0);
}

F64 OPL2EmuOpOutput(COPL2Op *op,F64 mod_in,F64 pitch_mul)
{
  F64 s;
  if (!op->env_stage) {
    op->out=0.0;
    return 0.0;
  }
  OPL2EmuEnvStep(op);
  op->phase+=op->phase_inc*pitch_mul;
  s=OPL2EmuWave(op->ws,op->phase+mod_in);
  op->out=s*op->env*OPL2EmuTLAmplitude(op);
  return op->out;
}

F64 OPL2EmuRenderChan(I64 c,F64 lfo_am,F64 lfo_vib)
{
  COPL2Chan *ch=&opl2_chans[c];
  COPL2Op *op1=&opl2_ops[opl2_chan_op1[c]],*op2=&opl2_ops[opl2_chan_op2[c]];
  F64 mod,car,out,pitch_mul,fb_phase;

  //Advance the anti-click ramp first -- it has to keep running even when the
  //channel has gone quiet, or a pending retrigger would never fire.
  if (ch->fade_dir>0) {
    ch->fade+=ch->fade_inc;
    if (ch->fade>=1.0) {
      ch->fade=1.0;
      ch->fade_dir=0;
    }
  } else if (ch->fade_dir<0) {
    ch->fade-=ch->fade_inc;
    if (ch->fade<=0.0) {
      ch->fade=0.0;
      ch->fade_dir=0;
      if (ch->key_pend) {
	ch->key_pend=FALSE;
	OPL2EmuKeyOn(c);
	OPL2EmuFadeStart(c,1);
      } else {
	//Faded to silence.  Drop the operators so a leftover release tail
	//doesn't keep the channel counted as active forever.
	op1->env_stage=0;
	op1->env=0.0;
	op2->env_stage=0;
	op2->env=0.0;
	ch->fb_mem[0]=0.0;
	ch->fb_mem[1]=0.0;
      }
    }
  }

  if (!op1->env_stage && !op2->env_stage) return 0.0;

  pitch_mul=1.0;
  if (op1->vib||op2->vib)
    pitch_mul+=lfo_vib*opl2_vib_depth;

  fb_phase=0.0;
  if (ch->feedback)
    fb_phase=(ch->fb_mem[0]+ch->fb_mem[1])*(1<<ch->feedback)/32.0;
  mod=OPL2EmuOpOutput(op1,fb_phase,pitch_mul);
  ch->fb_mem[1]=ch->fb_mem[0];
  ch->fb_mem[0]=mod;

  if (ch->connection) {
    car=OPL2EmuOpOutput(op2,0.0,pitch_mul);
    out=(mod+car)*0.5;
  } else {
    car=OPL2EmuOpOutput(op2,mod,pitch_mul);
    out=car;
  }
  if (op1->am || op2->am)
    out*=1.0-lfo_am*opl2_am_depth*0.3;
  if (ch->fade<1.0)
    out*=ch->fade;
  return out;
}

U0 OPL2EmuFillBuf(SND_OUT_CONTAINER *buf,I64)
{
  I64 j,c,l,samp,active;
  F64 mix,lfo_am,lfo_vib;
  j=0;
  while (j<SND_BUF_LEN) {
    opl2_lfo_phase+=1.0/SND_SAMPLE_RATE;
    while (opl2_lfo_phase>=1.0) opl2_lfo_phase-=1.0;
    lfo_am =0.5+0.5*Sin(2*ã*opl2_lfo_phase*3.7);
    lfo_vib=0.01*Sin(2*ã*opl2_lfo_phase*6.1);

    mix=0.0;
    active=0;
    for (c=0;c<OPL2EMU_CHANS;c++) {
      if (opl2_ops[opl2_chan_op1[c]].env_stage ||
	    opl2_ops[opl2_chan_op2[c]].env_stage)
	active++;
      mix+=OPL2EmuRenderChan(c,lfo_am,lfo_vib);
    }
    if (active>3)
      mix*=snd_vol*3.0/active;
    else
      mix*=snd_vol;

    samp=ToI64(Clamp(mix,-1.0,1.0)*I32_MAX)&0xFFFFFF00;
    for (l=0;l<SND_OCHANNELS;l++)
      buf[j++]=samp;
  }
}

U0 OPL2EmuInit()
{
  I64 i;
  MemSet(opl2_ops,0,sizeof(COPL2Op)*OPL2EMU_OPS);
  MemSet(opl2_chans,0,sizeof(COPL2Chan)*OPL2EMU_CHANS);
  for (i=0;i<OPL2EMU_CHANS;i++) {
    opl2_ops[opl2_chan_op1[i]].chan=i;
    opl2_ops[opl2_chan_op2[i]].chan=i;
    opl2_chans[i].fade=1.0;
    opl2_chans[i].fade_dir=0;
    opl2_chans[i].key_pend=FALSE;
  }
  opl2_ws_enable=FALSE;
  opl2_lfo_phase=0.0;
  opl2_am_depth=0.25;
  opl2_vib_depth=0.35;
  opl2emu_mixer_idx=MixerRegister("OPL2",&OPL2EmuFillBuf);
}

#ifndef HaveOPL
#include "/Demo/Snd/OPL2";
#endif

#help_index ""

