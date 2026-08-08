
#help_index "Snd/TMS5220"

#define TMS_RATE	8000
#define TMS_FRAME_SAMPS	200
#define TMS_UPSAMP	(SND_SAMPLE_RATE/TMS_RATE)

F64 tms5220_energy[16],
    tms5220_pitch[64],
    tms5220_k[168];
I64 tms5220_k_bits[10]={5,5,4,4,4,4,4,3,3,3},
    tms5220_k_offs[10]={0,32,64,80,96,112,128,144,152,160},
    tms5220_k_cnt[10]={32,32,16,16,16,16,16,8,8,8};
F64 tms5220_gain=4.0,
    tms5220_lpf_coef=0.7387;

I64 tms5220_energy_rom[16]={0,1,2,3,4,6,8,11,16,23,33,47,63,85,114,
      0};
I64 tms5220_pitch_rom[64]={0,15,16,17,18,19,20,21,22,23,24,25,26,27,
      28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,46,48,50,52,
      53,56,58,60,62,65,68,70,72,76,78,80,84,86,91,94,98,101,105,
      109,114,118,122,127,132,137,142,148,153,159};
I64 tms5220_k_rom[168]={
      -501,-498,-497,-495,-493,-491,-488,-482,-478,-474,-469,-464,
      -459,-452,-445,-437,-412,-380,-339,-288,-227,-158,-81,-1,
      80,157,226,287,337,379,411,436,
      -328,-303,-274,-244,-211,-175,-138,-99,-59,-18,24,64,
      105,143,180,215,248,278,306,331,354,374,392,408,
      422,435,445,455,463,470,476,506,
      -441,-387,-333,-279,-225,-171,-117,-63,-9,45,98,152,206,260,
      314,368,
      -328,-273,-217,-161,-106,-50,5,61,116,172,228,283,339,394,
      450,506,
      -328,-282,-235,-189,-142,-96,-50,-3,43,90,136,182,229,275,
      322,368,
      -256,-212,-168,-123,-79,-35,10,54,98,143,187,232,276,320,
      365,409,
      -308,-260,-212,-164,-117,-69,-21,27,75,122,170,218,266,314,
      361,409,
      -256,-161,-66,29,124,219,314,409,
      -256,-176,-96,-15,65,146,226,307,
      -205,-132,-59,14,87,160,234,307};

#define TMS_CHIRP_LEN	21
I64 tms5220_chirp[TMS_CHIRP_LEN]={
      0,3,15,40,76,108,113,80,37,38,76,68,26,50,59,19,55,26,37,31,29};

class CTMS5220
{
  U8 *stream;
  I64 stream_len,bit_pos;
  Bool speaking,stopping,voiced;
  I64 frame_samp,pitch_cnt,chirp_idx;
  U16 lfsr;
  F64 cur_energy,tgt_energy,d_energy,
      cur_period,tgt_period,d_period,
      cur_k[10],tgt_k[10],d_k[10],
      lat_b[10],
      lpf,
      s_prev,s_cur;
  I64 up_phase;
} tms;
ZeroClass(&tms);

I64 tms5220_mixer_idx=-1;

U0 TMS5220InitTabs()
{
  I64 i;
  for (i=0;i<16;i++)
    tms5220_energy[i]=tms5220_energy_rom[i]/114.0;
  for (i=0;i<64;i++)
    tms5220_pitch[i]=tms5220_pitch_rom[i];
  for (i=0;i<168;i++)
    tms5220_k[i]=tms5220_k_rom[i]/512.0;
}

public F64 TMS5220KVal(I64 stage,I64 idx)
{
  return tms5220_k[tms5220_k_offs[stage]+idx];
}

public I64 TMS5220QuantK(I64 stage,F64 v)
{
  I64 i,best=0;
  F64 d,best_d=F64_MAX;
  for (i=0;i<tms5220_k_cnt[stage];i++) {
    d=Abs(tms5220_k[tms5220_k_offs[stage]+i]-v);
    if (d<best_d) {
      best_d=d;
      best=i;
    }
  }
  return best;
}

public I64 TMS5220QuantPitch(F64 period)
{
  I64 i,best=1;
  F64 d,best_d=F64_MAX;
  for (i=1;i<64;i++) {
    d=Abs(tms5220_pitch[i]-period);
    if (d<best_d) {
      best_d=d;
      best=i;
    }
  }
  return best;
}

I64 TMS5220GetBits(I64 n)
{
  I64 i,v=0;
  for (i=0;i<n;i++) {
    if (tms.bit_pos>=tms.stream_len*8)
      return -1;
    v=v<<1|tms.stream[tms.bit_pos>>3]>>(tms.bit_pos&7)&1;
    tms.bit_pos++;
  }
  return v;
}

U0 TMS5220FadeFrame()
{
  I64 i;
  tms.tgt_energy=0.0;
  tms.d_energy=(0.0-tms.cur_energy)/TMS_FRAME_SAMPS;
  tms.d_period=0.0;
  for (i=0;i<10;i++) {
    tms.tgt_k[i]=0.0;
    tms.d_k[i]=(0.0-tms.cur_k[i])/TMS_FRAME_SAMPS;
  }
}

U0 TMS5220LoadFrame()
{
  I64 e,r,p,i,idx;
  Bool new_voiced,snap;
  e=TMS5220GetBits(4);
  if (e<0 || e==15) {
    tms.stopping=TRUE;
    TMS5220FadeFrame;
    return;
  }
  if (!e) {
    TMS5220FadeFrame;
    return;
  }
  r=TMS5220GetBits(1);
  p=TMS5220GetBits(6);
  if (r<0 || p<0) {
    tms.stopping=TRUE;
    TMS5220FadeFrame;
    return;
  }
  new_voiced=p>0;
  if (r) {
    if (!new_voiced)
      for (i=4;i<10;i++)
	tms.tgt_k[i]=0.0;
  } else {
    for (i=0;i<4;i++) {
      idx=TMS5220GetBits(tms5220_k_bits[i]);
      if (idx<0) {
	tms.stopping=TRUE;
	TMS5220FadeFrame;
	return;
      }
      tms.tgt_k[i]=TMS5220KVal(i,idx);
    }
    if (new_voiced) {
      for (i=4;i<10;i++) {
	idx=TMS5220GetBits(tms5220_k_bits[i]);
	if (idx<0) {
	  tms.stopping=TRUE;
	  TMS5220FadeFrame;
	  return;
	}
	tms.tgt_k[i]=TMS5220KVal(i,idx);
      }
    } else {
      for (i=4;i<10;i++)
	tms.tgt_k[i]=0.0;
    }
  }
  snap=new_voiced!=tms.voiced || tms.cur_energy<0.005;
  tms.voiced=new_voiced;
  if (new_voiced)
    tms.tgt_period=tms5220_pitch[p];
  tms.tgt_energy=tms5220_energy[e];
  tms.d_energy=(tms.tgt_energy-tms.cur_energy)/TMS_FRAME_SAMPS;
  if (snap) {
    for (i=0;i<10;i++) {
      tms.cur_k[i]=tms.tgt_k[i];
      tms.d_k[i]=0.0;
    }
    tms.cur_period=tms.tgt_period;
    tms.d_period=0.0;
    if (new_voiced)
      tms.pitch_cnt=0;
  } else {
    for (i=0;i<10;i++)
      tms.d_k[i]=(tms.tgt_k[i]-tms.cur_k[i])/TMS_FRAME_SAMPS;
    tms.d_period=(tms.tgt_period-tms.cur_period)/TMS_FRAME_SAMPS;
  }
}

F64 TMS5220Sample8k()
{
  F64 ex,f[11];
  I64 i,e_int,u;
  if (!tms.speaking)
    return 0.0;
  if (tms.frame_samp<=0) {
    if (tms.stopping) {
      tms.speaking=FALSE;
      return 0.0;
    }
    TMS5220LoadFrame;
    tms.frame_samp=TMS_FRAME_SAMPS;
  }
  tms.frame_samp--;
  tms.cur_energy+=tms.d_energy;
  if (tms.cur_energy<0.0)
    tms.cur_energy=0.0;
  tms.cur_period+=tms.d_period;
  for (i=0;i<10;i++)
    tms.cur_k[i]+=tms.d_k[i];
  e_int=ToI64(Floor(tms.cur_energy*114.0));
  if (tms.voiced) {
    if (tms.pitch_cnt<=0) {
      tms.chirp_idx=0;
      tms.pitch_cnt=ToI64(tms.cur_period);
      if (tms.pitch_cnt<2)
	tms.pitch_cnt=2;
    }
    if (tms.chirp_idx<TMS_CHIRP_LEN)
      u=tms5220_chirp[tms.chirp_idx]*e_int/256;
    else
      u=0;
    tms.chirp_idx++;
    tms.pitch_cnt--;
  } else {
    if (tms.lfsr&1)
      tms.lfsr=tms.lfsr>>1^0xB800;
    else
      tms.lfsr>>=1;
    u=64*e_int/256;
    if (!(tms.lfsr&1))
      u=-u;
  }
  ex=u/64.0;
  f[10]=ex;
  for (i=10;i>=1;i--)
    f[i-1]=f[i]-tms.cur_k[i-1]*tms.lat_b[i-1];
  for (i=9;i>=1;i--)
    tms.lat_b[i]=tms.lat_b[i-1]+tms.cur_k[i-1]*f[i-1];
  tms.lat_b[0]=f[0];
  if (tms.tgt_energy==0.0 && tms.cur_energy<0.0005)
    for (i=0;i<10;i++)
      tms.lat_b[i]*=0.9;
  tms.lpf+=tms5220_lpf_coef*(f[0]-tms.lpf);
  return tms.lpf;
}

U0 TMS5220FillBuf(SND_OUT_CONTAINER *buf,I64)
{
  I64 j,l,samp,t;
  F64 s;
  MemSet(buf,0,SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
  if (!tms.speaking)
    return;
  j=0;
  while (j<SND_BUF_LEN) {
    if (tms.up_phase>=TMS_UPSAMP) {
      tms.up_phase=0;
      tms.s_prev=tms.s_cur;
      tms.s_cur=TMS5220Sample8k;
    }
    s=tms.s_prev+(tms.s_cur-tms.s_prev)*tms.up_phase/TMS_UPSAMP;
    tms.up_phase++;
    samp=ToI64(Clamp(s*snd_vol*tms5220_gain,-1.0,1.0)*I32_MAX)&~0xFF;
    for (l=0;l<SND_OCHANNELS;l++) {
      t=buf[j]+samp;
      if (t>I32_MAX)
	t=I32_MAX;
      if (t<I32_MIN)
	t=I32_MIN;
      buf[j]=t;
      j++;
    }
  }
}

public Bool TMS5220Busy()
{
  return tms.speaking;
}

public U0 TMS5220Wait()
{
  while (tms.speaking)
    Sleep(20);
}

public U0 TMS5220Stop()
{
  tms.speaking=FALSE;
  tms.stopping=FALSE;
  Sleep(3*SND_BUF_TIME_mS);
  Free(tms.stream);
  tms.stream=NULL;
}

public Bool TMS5220PlayStream(U8 *data,I64 size,Bool bkg=TRUE)
{
  I64 i;
  U8 *cpy;
  if (tms5220_mixer_idx<0) {
    "TMS5220: not installed -- bring up HD Audio and HDMixer first.\n";
    return FALSE;
  }
  TMS5220Wait;
  Sleep(3*SND_BUF_TIME_mS);
  Free(tms.stream);
  tms.stream=AMAlloc(size);
  cpy=tms.stream;
  MemCpy(cpy,data,size);
  tms.stream_len=size;
  tms.bit_pos=0;
  tms.stopping=FALSE;
  tms.voiced=FALSE;
  tms.frame_samp=0;
  tms.pitch_cnt=0;
  tms.chirp_idx=TMS_CHIRP_LEN;
  tms.lfsr=0x5555;
  tms.cur_energy=0.0;
  tms.tgt_energy=0.0;
  tms.d_energy=0.0;
  tms.cur_period=64.0;
  tms.tgt_period=64.0;
  tms.d_period=0.0;
  for (i=0;i<10;i++) {
    tms.cur_k[i]=0.0;
    tms.tgt_k[i]=0.0;
    tms.d_k[i]=0.0;
    tms.lat_b[i]=0.0;
  }
  tms.lpf=0.0;
  tms.s_prev=0.0;
  tms.s_cur=0.0;
  tms.up_phase=TMS_UPSAMP;
  tms.speaking=TRUE;
  if (!bkg)
    TMS5220Wait;
  return TRUE;
}

U0 TMS5220Install()
{
  TMS5220InitTabs;
  tms5220_mixer_idx=MixerRegister("TMS5220",&TMS5220FillBuf);
}

if (snd_dev==SD_HD_AUDIO) {
  TMS5220Install;
  "TMS5220 module loaded.\n";
} else
  "TMS5220: needs HD Audio + Mixer.\n";

#help_index ""
