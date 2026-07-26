// Convert an input file for use with this player using ffmpeg.
//
// Low quality (smallest, 8-bit mono 22050Hz):
//   ffmpeg -i input.wav -ac 1 -ar 22050 -c:a pcm_u8 output.wav
//
// High quality (16-bit stereo at the mixer rate, no resampling):
//   ffmpeg -i input.wav -ac 2 -ar 48000 -c:a pcm_s16le output.wav

#help_index "Snd/Wav"

#define WAVK_PCM	1
#define WAVK_FLOAT	3
#define WAVK_EXTENSIBLE	0xFFFE

F64 wav_gain=1.0,
    wav_fade_mS=6.0;

class CWavHdr
{
  I64 channels,bits,fmt,rate,pcm_off,pcm_len;
};

class CWav
{
  U8 *file_buf,*pcm;
  I64 pcm_len,channels,bits,fmt,bytes_per_samp,frame_count;
  F64 src_rate,step,pos,fade_frames;
  Bool playing;
} wav;
MemSet(&wav,0,sizeof(CWav));

I64 wav_mixer_idx=-1;

I64 WavU16(U8 *p)
{
  return p[0]|p[1]<<8;
}

I64 WavU32(U8 *p)
{
  return p[0]|p[1]<<8|p[2]<<16|p[3]<<24;
}

Bool WavParseHeader(U8 *buf,I64 size,CWavHdr *h)
{
  I64 pos,cksize;
  U8 *id;
  MemSet(h,0,sizeof(CWavHdr));
  h->pcm_off=-1;
  if (size<12 || MemCmp(buf,"RIFF",4) || MemCmp(buf+8,"WAVE",4)) {
    "Wav: not a RIFF/WAVE file.\n";
    return FALSE;
  }
  pos=12;
  while (pos+8<=size) {
    id=buf+pos;
    cksize=WavU32(buf+pos+4);
    if (!MemCmp(id,"fmt ",4)) {
      if (cksize<16) {
	"Wav: fmt chunk too small.\n";
	return FALSE;
      }
      h->fmt     =WavU16(buf+pos+8);
      h->channels=WavU16(buf+pos+10);
      h->rate    =WavU32(buf+pos+12);
      h->bits    =WavU16(buf+pos+22);
      if (h->fmt==WAVK_EXTENSIBLE && cksize>=40)
	h->fmt=WavU16(buf+pos+8+24);
    } else if (!MemCmp(id,"data",4)) {
      h->pcm_off=pos+8;
      h->pcm_len=cksize;
      if (h->pcm_off+h->pcm_len>size)
	h->pcm_len=size-h->pcm_off;
    }
    pos+=8+cksize+(cksize&1);
  }
  if (!h->channels || !h->rate || !h->bits || h->pcm_off<0) {
    "Wav: missing fmt or data chunk.\n";
    return FALSE;
  }
  if (h->bits!=8 && h->bits!=16 && h->bits!=24 && h->bits!=32) {
    "Wav: unsupported bit depth %d.\n",h->bits;
    return FALSE;
  }
  if (h->fmt==WAVK_FLOAT && h->bits!=32) {
    "Wav: float PCM must be 32-bit.\n";
    return FALSE;
  }
  if (h->fmt!=WAVK_PCM && h->fmt!=WAVK_FLOAT) {
    "Wav: unsupported format tag %d (only PCM or IEEE float).\n",h->fmt;
    return FALSE;
  }
  return TRUE;
}

F64 WavF32Decode(I64 bits)
{
  I64 sign,exp,mant;
  F64 v;
  sign=bits>>31&1;
  exp=bits>>23&0xFF;
  mant=bits&0x7FFFFF;
  if (!exp) {
    if (!mant)
      return 0.0;
    v=mant/8388608.0*Pow(2.0,-126.0);
  } else if (exp==255)
    v=1.0;
  else
    v=(1.0+mant/8388608.0)*Pow(2.0,exp-127.0);
  if (sign)
    v=-v;
  return v;
}

F64 WavSample(I64 frame,I64 ch)
{
  I64 off,v;
  U8 *p;
  if (frame<0 || frame>=wav.frame_count)
    return 0.0;
  off=(frame*wav.channels+ch)*wav.bytes_per_samp;
  p=wav.pcm+off;
  switch (wav.bits) {
    case 8:
      return (p[0]-128)/128.0;
    case 16:
      v=p[0]|p[1]<<8;
      if (v&0x8000)
	v-=0x10000;
      return v/32768.0;
    case 24:
      v=p[0]|p[1]<<8|p[2]<<16;
      if (v&0x800000)
	v-=0x1000000;
      return v/8388608.0;
    case 32:
      v=p[0]|p[1]<<8|p[2]<<16|p[3]<<24;
      if (wav.fmt==WAVK_FLOAT)
	return WavF32Decode(v);
      if (v&0x80000000)
	v-=0x100000000;
      return v/2147483648.0;
  }
  return 0.0;
}

U0 WavFillBuf(SND_OUT_CONTAINER *buf,I64)
{
  I64 j,l,c,f0,t,samp;
  F64 frac,v,g,remain;
  MemSet(buf,0,SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
  if (!wav.playing)
    return;
  j=0;
  while (j<SND_BUF_LEN) {
    if (wav.pos>=wav.frame_count) {
      wav.playing=FALSE;
      break;
    }
    f0=ToI64(Floor(wav.pos));
    frac=wav.pos-f0;
    remain=wav.frame_count-wav.pos;
    g=1.0;
    if (remain<wav.fade_frames)
      g=remain/wav.fade_frames;
    for (l=0;l<SND_OCHANNELS;l++) {
      c=l;
      if (wav.channels==1)
	c=0;
      v=WavSample(f0,c)*(1.0-frac)+WavSample(f0+1,c)*frac;
      samp=ToI64(Clamp(v*g*snd_vol*wav_gain,-1.0,1.0)*I32_MAX)&~0xFF;
      t=buf[j]+samp;
      if (t>I32_MAX)
	t=I32_MAX;
      if (t<I32_MIN)
	t=I32_MIN;
      buf[j]=t;
      j++;
    }
    wav.pos+=wav.step;
  }
}

public Bool WavBusy()
{
  return wav.playing;
}

public U0 WavWait()
{
  while (wav.playing)
    Sleep(20);
}

public U0 WavStop()
{
  wav.playing=FALSE;
  Sleep(3*SND_BUF_TIME_mS);
  Free(wav.file_buf);
  wav.file_buf=NULL;
}

public Bool WavPlayMem(U8 *data,I64 size)
{
  CWavHdr h;
  if (wav_mixer_idx<0) {
    "Wav: not installed -- bring up HD Audio and HDMixer first.\n";
    return FALSE;
  }
  if (!WavParseHeader(data,size,&h))
    return FALSE;
  WavWait;
  Sleep(3*SND_BUF_TIME_mS);
  Free(wav.file_buf);
  wav.file_buf=AMAlloc(size);
  MemCpy(wav.file_buf,data,size);
  wav.pcm=wav.file_buf+h.pcm_off;
  wav.pcm_len=h.pcm_len;
  wav.channels=h.channels;
  wav.bits=h.bits;
  wav.fmt=h.fmt;
  wav.bytes_per_samp=h.bits/8;
  wav.frame_count=wav.pcm_len/(wav.channels*wav.bytes_per_samp);
  wav.src_rate=h.rate;
  wav.step=h.rate/ToF64(SND_SAMPLE_RATE);
  wav.fade_frames=wav_fade_mS/1000.0*h.rate;
  wav.pos=0.0;
  wav.playing=TRUE;
  return TRUE;
}

public Bool WavPlay(U8 *filename,Bool bkg=TRUE)
{
  U8 *data;
  I64 size;
  Bool res;
  data=FileRead(filename,&size);
  if (!data) {
    "Wav: can't read \"%s\".\n",filename;
    return FALSE;
  }
  res=WavPlayMem(data,size);
  Free(data);
  if (res && !bkg)
    WavWait;
  return res;
}

public U0 WavInfo(U8 *filename)
{
  U8 *data,*kind;
  I64 size;
  CWavHdr h;
  data=FileRead(filename,&size);
  if (!data) {
    "Wav: can't read \"%s\".\n",filename;
    return;
  }
  if (WavParseHeader(data,size,&h)) {
    kind="int";
    if (h.fmt==WAVK_FLOAT)
      kind="float";
    "%s: %d ch, %d-bit %s, %dHz, %dmS\n",filename,h.channels,h.bits,
	  kind,h.rate,
	  ToI64(1000.0*h.pcm_len/(h.channels*(h.bits/8))/h.rate);
  }
  Free(data);
}

U0 WavInstall()
{
  wav_mixer_idx=MixerRegister("Wav",&WavFillBuf);
}

if (snd_dev==SD_HD_AUDIO) {
  WavInstall;
  "Wav module loaded.\n";
} else
  "Wav: needs HD Audio + Mixer.\n";

#help_index ""
