
#help_index "Snd/HDMixer"

#define MIXER_MAX_SRC	8
#define MIXER_NAME_LEN	24
#define MIXER_VOL_MAX	2.0

class CMixerSrc
{
  Bool active;
  U8 name[MIXER_NAME_LEN];
  F64 vol;
  U0 (*fp_fill)(SND_OUT_CONTAINER *buf,I64 buf_num);
  I64 in_fill;
  CTask *owner;
};
CMixerSrc mixer_srcs[MIXER_MAX_SRC];
MemSet(mixer_srcs,0,sizeof(CMixerSrc)*MIXER_MAX_SRC);

SND_OUT_CONTAINER *mixer_src_buf=NULL;
F64 *mixer_mix_buf=NULL;

#define MIXER_REV_NCOMB		4
#define MIXER_REV_NAP		3
#define MIXER_REV_COMBS		(SND_OCHANNELS*MIXER_REV_NCOMB)
#define MIXER_REV_APS		(SND_OCHANNELS*MIXER_REV_NAP)
#define MIXER_REV_SPREAD	23
#define MIXER_REV_FB		0.84
#define MIXER_REV_DAMP		0.25
#define MIXER_REV_AP_FB		0.5
#define MIXER_REV_IN_GAIN	0.25
#define MIXER_REV_WET		0.9
#define MIXER_REV_DRY_CUT	0.3

I64 mixer_rev_comb_len[MIXER_REV_NCOMB]={1214,1293,1390,1476};
I64 mixer_rev_ap_len[MIXER_REV_NAP]={605,480,371};

class CMixerRevLine
{
  F64 *buf;
  I64 len,pos;
  F64 filt;
};

CMixerRevLine mixer_rev_comb[MIXER_REV_COMBS];
CMixerRevLine mixer_rev_ap[MIXER_REV_APS];
F64 mixer_reverb=0.0;
Bool mixer_rev_ready=FALSE,mixer_rev_wet=FALSE;

U0 MixerRevAlloc()
{
  I64 ch,i,n;
  CMixerRevLine *l;
  for (ch=0;ch<SND_OCHANNELS;ch++) {
    for (i=0;i<MIXER_REV_NCOMB;i++) {
      l=&mixer_rev_comb[ch*MIXER_REV_NCOMB+i];
      n=mixer_rev_comb_len[i]+ch*MIXER_REV_SPREAD;
      l->buf=AMAlloc(n*sizeof(F64));
      l->len=n;
      l->pos=0;
      l->filt=0.0;
      MemSet(l->buf,0,n*sizeof(F64));
    }
    for (i=0;i<MIXER_REV_NAP;i++) {
      l=&mixer_rev_ap[ch*MIXER_REV_NAP+i];
      n=mixer_rev_ap_len[i]+ch*MIXER_REV_SPREAD;
      l->buf=AMAlloc(n*sizeof(F64));
      l->len=n;
      l->pos=0;
      l->filt=0.0;
      MemSet(l->buf,0,n*sizeof(F64));
    }
  }
  mixer_rev_ready=TRUE;
}

U0 MixerRevClear()
{//Drop any stale tail so re-enabling starts silent.
  I64 i;
  for (i=0;i<MIXER_REV_COMBS;i++) {
    MemSet(mixer_rev_comb[i].buf,0,mixer_rev_comb[i].len*sizeof(F64));
    mixer_rev_comb[i].pos=0;
    mixer_rev_comb[i].filt=0.0;
  }
  for (i=0;i<MIXER_REV_APS;i++) {
    MemSet(mixer_rev_ap[i].buf,0,mixer_rev_ap[i].len*sizeof(F64));
    mixer_rev_ap[i].pos=0;
  }
}

U0 MixerRevApply(F64 *mix,I64 len,F64 amt)
{//In-place wet/dry blend over the interleaved mix buf.
  I64 ch,i,j;
  F64 in,out,y,damp1=MIXER_REV_DAMP,damp2=1.0-MIXER_REV_DAMP,
      wet=MIXER_REV_WET*amt,dry=1.0-MIXER_REV_DRY_CUT*amt;
  CMixerRevLine *l;
  for (j=0;j+SND_OCHANNELS<=len;j+=SND_OCHANNELS)
    for (ch=0;ch<SND_OCHANNELS;ch++) {
      in=mix[j+ch]*MIXER_REV_IN_GAIN;
      out=0.0;
      for (i=0;i<MIXER_REV_NCOMB;i++) {
	l=&mixer_rev_comb[ch*MIXER_REV_NCOMB+i];
	y=l->buf[l->pos];
	l->filt=y*damp2+l->filt*damp1;
	l->buf[l->pos]=in+l->filt*MIXER_REV_FB;
	l->pos++;
	if (l->pos>=l->len)
	  l->pos=0;
	out+=y;
      }
      for (i=0;i<MIXER_REV_NAP;i++) {
	l=&mixer_rev_ap[ch*MIXER_REV_NAP+i];
	y=l->buf[l->pos];
	l->buf[l->pos]=out+y*MIXER_REV_AP_FB;
	out=y-out;
	l->pos++;
	if (l->pos>=l->len)
	  l->pos=0;
      }
      mix[j+ch]=mix[j+ch]*dry+out*wet;
    }
}

public U0 MixerSetReverb(F64 amt)
{
  mixer_reverb=Clamp(amt,0.0,1.0);
}

public F64 MixerGetReverb()
{
  return mixer_reverb;
}

I64 MixerFindByName(U8 *name)
{
  I64 i;
  for (i=0;i<MIXER_MAX_SRC;i++)
    if (mixer_srcs[i].active && !StrCmp(mixer_srcs[i].name,name))
      return i;
  return -1;
}

U0 MixerSlotClear(I64 i)
{
  while (LBts(&mixer_srcs[i].in_fill,0))
    Yield;
  mixer_srcs[i].fp_fill=NULL;
  mixer_srcs[i].owner=NULL;
  mixer_srcs[i].name[0]=0;
  LBtr(&mixer_srcs[i].in_fill,0);
}

public I64 MixerRegister(U8 *name,
	U0 (*fp_fill)(SND_OUT_CONTAINER *buf,I64 buf_num),F64 init_vol=1.0,
	CTask *owner=NULL)
{
  I64 i;
  if (!owner)
    owner=Fs;
  if (owner==adam_task)
    owner=NULL;
  if ((i=MixerFindByName(name))>=0) {
    mixer_srcs[i].owner=owner;
    mixer_srcs[i].fp_fill=fp_fill;
    return i;
  }
  for (i=0;i<MIXER_MAX_SRC;i++)
    if (!mixer_srcs[i].active) {
      StrCpy(mixer_srcs[i].name,name);
      mixer_srcs[i].vol=init_vol;
      mixer_srcs[i].owner=owner;
      mixer_srcs[i].fp_fill=fp_fill;
      mixer_srcs[i].active=TRUE;
      return i;
    }
  "Mixer: no free source slots for \"%s\" (max %d) -- raise "
	"MIXER_MAX_SRC.\n",name,MIXER_MAX_SRC;
  return -1;
}

public U0 MixerUnregister(I64 idx)
{
  if (0<=idx<MIXER_MAX_SRC) {
    mixer_srcs[idx].active=FALSE;
    MixerSlotClear(idx);
  }
}

public U0 MixerSetVol(I64 idx,F64 vol)
{
  if (0<=idx<MIXER_MAX_SRC)
    mixer_srcs[idx].vol=Clamp(vol,0.0,MIXER_VOL_MAX);
}

public F64 MixerGetVol(I64 idx)
{
  if (0<=idx<MIXER_MAX_SRC)
    return mixer_srcs[idx].vol;
  return 0.0;
}

U0 MixerFillBuf(SND_OUT_CONTAINER *buf,I64 buf_num)
{
  I64 i,j;
  F64 v,amt;
  if (!mixer_src_buf)
    mixer_src_buf=AMAlloc(SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
  if (!mixer_mix_buf)
    mixer_mix_buf=AMAlloc(SND_BUF_LEN*sizeof(F64));
  MemSet(mixer_mix_buf,0,SND_BUF_LEN*sizeof(F64));
  for (i=0;i<MIXER_MAX_SRC;i++) {
    if (mixer_srcs[i].active && mixer_srcs[i].owner &&
	  !TaskValidate(mixer_srcs[i].owner)) {
      mixer_srcs[i].active=FALSE;
      MixerSlotClear(i);
    }
    if (mixer_srcs[i].active && mixer_srcs[i].fp_fill &&
	  !LBts(&mixer_srcs[i].in_fill,0)) {
      if (mixer_srcs[i].active && mixer_srcs[i].fp_fill) {
        (*mixer_srcs[i].fp_fill)(mixer_src_buf,buf_num);
        v=mixer_srcs[i].vol;
        if (v>0.0)
          for (j=0;j<SND_BUF_LEN;j++)
            mixer_mix_buf[j]+=mixer_src_buf[j]*v;
      }
      LBtr(&mixer_srcs[i].in_fill,0);
    }
  }
  if (!mixer_rev_ready)
    MixerRevAlloc;
  amt=Clamp(mixer_reverb,0.0,1.0);
  if (amt>0.0) {
    if (!mixer_rev_wet) {
      MixerRevClear;
      mixer_rev_wet=TRUE;
    }
    MixerRevApply(mixer_mix_buf,SND_BUF_LEN,amt);
  } else
    mixer_rev_wet=FALSE;
  for (j=0;j<SND_BUF_LEN;j++)
    buf[j]=ToI64(Clamp(mixer_mix_buf[j]/I32_MAX,-1.0,1.0)*I32_MAX)&0xFFFFFF00;
}

U0 MixerInstall()
{
  if (!mixer_rev_ready)
    MixerRevAlloc;
  if (fp_snd_fill_buf!=&MixerFillBuf) {
    if (fp_snd_fill_buf)
      MixerRegister("Tones",fp_snd_fill_buf);
    fp_snd_fill_buf=&MixerFillBuf;
  }
}

if (snd_dev==SD_HD_AUDIO) {
  MixerInstall;
  "Mixer loaded.\n";
} else
  "Mixer: needs HD Audio.\n";

U0 MixerGuiCtrlAltM(I64 sc)
{
  no_warn sc;
  User("#include \"/Demo/Snd/HDMixerGui\";\n");
}

CtrlAltCBSet('M',&MixerGuiCtrlAltM,"Cmd/Sound Mixer","");

#help_index ""
