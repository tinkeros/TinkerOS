
#help_index "Snd/HDAudio"

#define SD_PC_SPEAKER		0
#define SD_HD_AUDIO		1

#define SND_SAMPLE_RATE		48000
#define SND_SAMPLE_BITS		32
#define SND_OCHANNELS		2
#define SND_ICHANNELS		2
#define SND_OUT_CONTAINER	I32
#define SND_IN_CONTAINER	I16
#define SND_BUF_LEN		0x800
#define SND_BUF_TIME_mS		(SND_BUF_LEN/SND_OCHANNELS*1000.0/\
				SND_SAMPLE_RATE)

F64 snd_freq=0;
I64 snd_dev=SD_PC_SPEAKER;
Bool snd_record=FALSE;
F64 snd_vol=1.0;
U0 (*fp_snd)(F64 freq,I64 waveform,F64 amp)=NULL;
U0 (*fp_snd_record)(F64 freq,I64 waveform,F64 amp)=NULL;
U0 (*fp_snd_fill_buf)(SND_OUT_CONTAINER *buf,I64 buf_num)=NULL;
U0 (*fp_snd_copy_buf)(SND_IN_CONTAINER *buf,I64 buf_num)=NULL;

I64 snd_obuf_num,snd_ibuf_num;

#define Sf_FILLING_OUT		0
I64 snd_flags;

#define HD_1_CHAN	0
#define HD_2_CHAN	1
#define HD_3_CHAN	2
#define HD_4_CHAN	3

#define HD_8_BIT	0
#define HD_16_BIT	1
#define HD_20_BIT	2
#define HD_24_BIT	3
#define HD_32_BIT	4

#define HD_48kHz	0

#define HD_DFT_OUT_FMT	(HD_2_CHAN+(HD_32_BIT<<4)+(HD_48kHz<<8))
#define HD_DFT_IN_FMT	(HD_2_CHAN+(HD_16_BIT<<4)+(HD_48kHz<<8))

#define HD_CORB_ENTRIES	256
#define HD_RIRB_ENTRIES	256
#define HD_BDL_ENTRIES	256

#define HD_GCAP		0x00
#define HD_GCTL		0x08
#define HD_STATESTS	0x0E
#define HD_GSTS		0x10
#define HD_CORBLBASE	0x40
#define HD_CORBUBASE	0x44
#define HD_CORBWP	0x48
#define HD_CORBRP	0x4A
#define HD_CORBCTL	0x4C
#define HD_CORBST	0x4D
#define HD_CORBSIZE	0x4E
#define HD_RIRBLBASE	0x50
#define HD_RIRBUBASE	0x54
#define HD_RIRBWP	0x58
#define HD_RINTCNT	0x5A
#define HD_RIRBCTL	0x5C
#define HD_RIRBSTS	0x5D
#define HD_RIRBSIZE	0x5E
#define HD_DPLBASE	0x70
#define HD_DPUBASE	0x74

#define HD_PCI_TCSEL	0x44
#define HD_PCI_DEVC	0x78
#define HD_DEVC_NOSNOOP	0x0800

#define STRCTL		0x00
#define STRSTS		0x03
#define STRLPIB		0x04
#define STRCBL		0x08
#define STRLVI		0x0C
#define STRFIFOW	0x0E
#define STRFIFOS	0x10
#define STRFMT		0x12
#define STRBDPL		0x18
#define STRBDPU		0x1C

#define HD_STR_BASE	0x080
#define HD_STR_SIZE	0x020

#define HD_DFT_ISS	4
#define HD_DFT_OSS	4

#define VERB_GET_PARAM		0xF0000
#define VERB_CONNECT_SEL_GET	0xF0100
#define VERB_CONNECT_SEL_SET	0x70100
#define VERB_GET_CONNECT_LST	0xF0200
#define VERB_PROCESS_STATE_GET	0xF0300
#define VERB_PROCESS_STATE_SET	0x70300
#define VERB_COEFF_IDX_GET	0xD0000
#define VERB_COEFF_IDX_SET	0x50000
#define VERB_PROCESS_COEFF_GET	0xC0000
#define VERB_PROCESS_COEFF_SET	0x40000
#define VERB_AMPLIFIER_GAIN_GET	0xB0000
#define VERB_AMPLIFIER_GAIN_SET	0x30000
#define VERB_STREAM_FMT_GET	0xA0000
#define VERB_STREAM_FMT_SET	0x20000
#define VERB_DIGIT_CONVERT1_GET	0xF0D00
#define VERB_DIGIT_CONVERT1_SET	0x70D00
#define VERB_DIGIT_CONVERT2_GET	0xF0D00
#define VERB_DIGIT_CONVERT2_SET	0x70E00
#define VERB_POWER_STATE_GET	0xF0500
#define VERB_POWER_STATE_SET	0x70500
#define VERB_CHAN_STREAM_ID_GET	0xF0600
#define VERB_CHAN_STREAM_ID_SET	0x70600
#define VERB_SDI_SEL_GET	0xF0400
#define VERB_SDI_SEL_SET	0x70400
#define VERB_PIN_WIDGET_CTL_GET	0xF0700
#define VERB_PIN_WIDGET_CTL_SET	0x70700
#define VERB_UNSOL_ENABLE_GET	0xF0800
#define VERB_UNSOL_ENABLE_SET	0x70800
#define VERB_PIN_SENSE_GET	0xF0900
#define VERB_PIN_SENSE_SET	0x70900
#define VERB_EAPDBTL_ENABLE_GET 0xF0C00
#define VERB_EAPDBTL_ENABLE_SET 0x70C00
#define VERB_BEEP_CTL_GET	0xF0A00
#define VERB_BEEP_CTL_SET	0x70A00
#define VERB_GPI_CTRL0_GET	0xF1000
#define VERB_GPI_CTRL0_SET	0x71000
#define VERB_GPI_CTRL1_GET	0xF1100
#define VERB_GPI_CTRL1_SET	0x71100
#define VERB_GPI_CTRL2_GET	0xF1200
#define VERB_GPI_CTRL2_SET	0x71200
#define VERB_GPI_CTRL3_GET	0xF1300
#define VERB_GPI_CTRL3_SET	0x71300
#define VERB_GPI_CTRL4_GET	0xF1400
#define VERB_GPI_CTRL4_SET	0x71400
#define VERB_GPI_CTRL5_GET	0xF1500
#define VERB_GPI_CTRL5_SET	0x71500
#define VERB_GPI_CTRL6_GET	0xF1600
#define VERB_GPI_CTRL6_SET	0x71600
#define VERB_GPI_CTRL7_GET	0xF1700
#define VERB_GPI_CTRL7_SET	0x71700
#define VERB_GPI_CTRL8_GET	0xF1800
#define VERB_GPI_CTRL8_SET	0x71800
#define VERB_GPI_CTRL9_GET	0xF1900
#define VERB_GPI_CTRL9_SET	0x71900
#define VERB_GPI_CTRLA_GET	0xF1A00
#define VERB_GPI_CTRLA_SET	0x71A00
#define VERB_VOL_CTL_GET	0xF0F00
#define VERB_VOL_CTL_SET	0x70F00
#define VERB_SUB_SYS_ID0_GET	0xF2000
#define VERB_SUB_SYS_ID0_SET	0x72000
#define VERB_SUB_SYS_ID1_GET	0xF2000
#define VERB_SUB_SYS_ID1_SET	0x72100
#define VERB_SUB_SYS_ID2_GET	0xF2000
#define VERB_SUB_SYS_ID2_SET	0x72200
#define VERB_SUB_SYS_ID3_GET	0xF2000
#define VERB_SUB_SYS_ID3_SET	0x72300
#define VERB_CFG_DFT0_GET	0xF1C00
#define VERB_CFG_DFT0_SET	0x71C00
#define VERB_CFG_DFT1_GET	0xF1C00
#define VERB_CFG_DFT1_SET	0x71D00
#define VERB_CFG_DFT2_GET	0xF1C00
#define VERB_CFG_DFT2_SET	0x71E00
#define VERB_CFG_DFT3_GET	0xF1C00
#define VERB_CFG_DFT3_SET	0x71F00
#define VERB_STRIPE_CTL_GET	0xF2400
#define VERB_STRIPE_CTL_SET	0x72400
#define VERB_RST		0x7FF00

#define P_VENDOR_ID		0x00
#define P_REVISION_ID		0x02
#define P_SUBNODE_CNT		0x04
#define P_FUN_GRP_TYPE		0x05
#define P_AUDIO_FUN_CAP		0x08
#define P_AUDIO_WIDGET_CAP	0x09
#define P_SAMPLE_SIZE_RATE_CAP	0x0A
#define P_STREAM_FMTS		0x0B
#define P_PIN_CAP		0x0C
#define P_INPUT_AMP_CAP		0x0D
#define P_OUTPUT_AMP_CAP	0x12
#define P_CONNECT_LST_LEN	0x0E
#define P_POWER_STATES		0x0F
#define P_PROCESSING_CAP	0x10
#define P_GPIO_CNT		0x11
#define P_VOL_KNOB_CAP	0x13

#define FGT_AUDIO		1
#define FGT_VENDOR_MODEM	2

#define PCM_RATE_8kHz		0
#define PCM_RATE_11kHz		1
#define PCM_RATE_16kHz		2
#define PCM_RATE_22kHz		3
#define PCM_RATE_32kHz		4
#define PCM_RATE_44kHz		5
#define PCM_RATE_48kHz		6
#define PCM_RATE_88kHz		7
#define PCM_RATE_96kHz		8
#define PCM_RATE_176kHz		9
#define PCM_RATE_192kHz		10
#define PCM_RATE_384kHz		11

#define PCM_SIZE_8_BIT		16
#define PCM_SIZE_16_BIT		17
#define PCM_SIZE_20_BIT		18
#define PCM_SIZE_24_BIT		19
#define PCM_SIZE_32_BIT		20

#define AWT_OUTPUT		0x0
#define AWT_INPUT		0x1
#define AWT_MIXER		0x2
#define AWT_SELECTOR		0x3
#define AWT_PIN_COMPLEX		0x4
#define AWT_POWER_WIDGET	0x5
#define AWT_VOL_KNOB_WIDGET	0x6
#define AWT_BEEP_GEN_WIDGET	0x7
#define AWT_VENDOR		0xF
#define AWT_NODE		0x10
DefineLstLoad("ST_AUDIO_WIDGET_TYPES",
"Output\0Input\0Mixer\0Sellector\0Pin Complex\0"
"Power Widget\0Vol Knob\0Beep Gen\0\0\0\0\0\0\0\0Vendor\0Node\0");

#define PIN_CFG_SEQUENCE(cfg)		((cfg)&0xF)
#define PIN_CFG_ASSOCIATION(cfg)	((cfg)>>4&0xF)
#define PIN_CFG_MISC(cfg)		((cfg)>>8&0xF)
#define PIN_CFG_COLOR(cfg)		((cfg)>>12&0xF)
#define PIN_CFG_CONN_TYPE(cfg)		((cfg)>>16&0xF)
#define PIN_CFG_DEVICE(cfg)		((cfg)>>20&0xF)
#define PIN_CFG_LOCATION(cfg)		((cfg)>>24&0x3F)
#define PIN_CFG_PORT_CONN(cfg)		((cfg)>>30&0x3)

DefineLstLoad("ST_PIN_PORT_CONN",
"Jack\0No Physical Connector\0Fixed Function Device\0"
"Jack And Internal Device\0");

DefineLstLoad("ST_PIN_DEVICE",
"Line Out\0Speaker\0HP Out\0CD\0SPDIF Out\0Digital Other Out\0"
"Modem Line Side\0Modem Handset Side\0Line In\0Aux\0Mic In\0"
"Telephony\0SPDIF In\0Digital Other In\0Reserved\0Other\0");

DefineLstLoad("ST_PIN_CONN_TYPE",
"Unknown\0.125in Stereo/Mono\0.25in Stereo/Mono\0ATAPI Internal\0"
"RCA\0Optical\0Other Digital\0Other Analog\0Multichannel Analog(DIN)\0"
"XLR/Professional\0RJ-11(Modem)\0Combination\0Reserved\0Reserved\0"
"Reserved\0Other\0");

DefineLstLoad("ST_PIN_COLOR",
"Unknown\0Black\0Gray\0Blue\0Green\0Red\0Orange\0Yellow\0Purple\0Pink\0"
"Reserved\0Reserved\0Reserved\0Reserved\0White\0Other\0");

DefineLstLoad("ST_PIN_LOCATION",
"N/A\0Rear\0Front\0Left\0Right\0Top\0Bottom\0Rear Panel\0"
"Drive Bay\0Reserved\0Reserved\0Reserved\0Reserved\0Reserved\0"
"Reserved\0Reserved\0"
"Internal N/A\0Internal Rear\0Internal Front\0Internal Left\0"
"Internal Right\0Internal Top\0Internal Bottom\0Internal Riser\0"
"Internal HDMI\0Internal ATAPI\0Internal Mobile-Lid-In\0"
"Internal Mobile-Lid-Out\0Reserved\0Reserved\0Reserved\0"
"Reserved\0"
"Separate-Chassis N/A\0Separate-Chassis Rear\0"
"Separate-Chassis Front\0Separate-Chassis Left\0"
"Separate-Chassis Right\0Separate-Chassis Top\0"
"Separate-Chassis Bottom\0Separate-Chassis Rear Panel\0"
"Separate-Chassis Drive Bay\0Reserved\0Reserved\0Reserved\0"
"Reserved\0Reserved\0Reserved\0Reserved\0"
"Other N/A\0Other Rear\0Other Front\0Other Left\0Other Right\0"
"Other Top\0Other Bottom\0Reserved\0Reserved\0Reserved\0"
"Reserved\0Reserved\0Reserved\0Reserved\0Reserved\0Reserved\0");

#define AWCAP_IN_AMP		1
#define AWCAP_OUT_AMP		2
#define AWCAP_AMP_OVRD		3
#define AWCAP_FORMAT_OVRD	4
#define AWCAP_CONN_LST		8
#define AWCAP_POWER		10

#define PINCAP_IMPEDANCE_SENSE	0
#define PINCAP_TRIGGER_REQD	1
#define PINCAP_PRESENCE_DETECT	2
#define PINCAP_HEADPHONE	3
#define PINCAP_OUTPUT		4
#define PINCAP_INPUT		5
#define PINCAP_BALANCED		6
#define PINCAP_VREF_HIZ		8
#define PINCAP_VREF_50		9
#define PINCAP_VREF_GND		10
#define PINCAP_VREF_80		12
#define PINCAP_VREF_100		13
#define PINCAP_EAPD		16

#define PWC_VREF_HIZ	0
#define PWC_VREF_50	1
#define PWC_VREF_GND	2
#define PWC_VREF_80	4
#define PWC_VREF_100	5
#define PWC_IN_EN	0x20
#define PWC_OUT_EN	0x40
#define PWC_HP_EN	0x80

class CHDBufDesc
{
  I32 *buf;
  U32 len;
  U32 ctrl;
};

#define HD_TONES	8

class CHDAudioCtrl
{
  U8 *bar;
  I64 cad;
  U32 *corb;
  I64 *rirb;
  CHDBufDesc *ostr0_bdl,*istr0_bdl;
  SND_OUT_CONTAINER *ostr0_buf[2],*o_tmp_buf;
  SND_IN_CONTAINER  *istr0_buf[2];
  CTask *task;
  I64 waveform;
  F64 freq,amp;
  CSndWaveCtrl *tone_swcs[HD_TONES];
  I64 rirb_rp,corb_wp;
  I64 corb_mask,rirb_mask;
  I64 iss,oss,bss;
  I64 istr_idx,ostr_idx;
  I64 istr,ostr;
  U32 *posbuf;
  U32 *opos,*ipos;
  I64 out_fmt,in_fmt;
  Bool out_fmt_chosen;
  Bool audio_task_started,in_running,out_running;
} hda;
MemSet(&hda,0,sizeof(CHDAudioCtrl));

U0 HDSyncCORB()
{
  U16 *wp,*rp;
  wp =hda.bar+HD_CORBWP;
  *wp=hda.corb_wp;
  rp =hda.bar+HD_CORBRP;
  while ((*rp&hda.corb_mask)!=hda.corb_wp)
    Yield;
}

U0 HDWriteCORB(I64 cad,I64 nid,U32 val)
{
  val|=(cad<<28)+(nid<<20);
#ifdef HD_DBG_LOG_VERBS
  "CORB cad=%d nid=%02X val=%06X\n",cad,nid,val&0xFFFFF;
#endif
  hda.corb_wp=(hda.corb_wp+1)&hda.corb_mask;
  hda.corb[hda.corb_wp]=val;
}

I64 HDSyncRIRB()
{
  U16 *_w;
  U8 *_b;
  I64 wp,res=0;
  _w=hda.bar+HD_RIRBWP;
  wp=*_w&hda.rirb_mask;
  while (hda.rirb_rp!=wp) {
    hda.rirb_rp=(hda.rirb_rp+1)&hda.rirb_mask;
    res=hda.rirb[hda.rirb_rp];
  }
  _b=hda.bar+HD_RIRBSTS;
  *_b=0x05;
  return res;
}

I64 HDReadRIRB()
{
  U16 *_w;
  U8 *_b;
  I64 wp,res=0;
  _w=hda.bar+HD_RIRBWP;
  do {
    Yield;
    wp=*_w&hda.rirb_mask;
  } while (wp==hda.rirb_rp);
  hda.rirb_rp=(hda.rirb_rp+1)&hda.rirb_mask;
  res=hda.rirb[hda.rirb_rp];
  _b=hda.bar+HD_RIRBSTS;
  *_b=0x05;
  return res;
}

I64 HDWriteCORBSync(I64 cad,I64 nid,U32 val)
{
  HDSyncCORB;
  HDSyncRIRB;
  HDWriteCORB(cad,nid,val);
  HDSyncCORB;
  return HDReadRIRB;
}

Bool HDTestCORBSync(I64 cad,I64 nid,U32 val)
{
  U16 *_w;
  I64 wp;

  HDSyncCORB;
  HDSyncRIRB;
  HDWriteCORB(cad,nid,val);
  HDSyncCORB;

  Sleep(1);
  _w=hda.bar+HD_RIRBWP;
  wp=*_w&hda.rirb_mask;
  if (wp==hda.rirb_rp)
    return FALSE;
  HDReadRIRB;
  return TRUE;
}

I64 HDRateCapBit(I64 rate)
{
  I64 res=-1;
  if (rate==8000)
    res=PCM_RATE_8kHz;
  else if (rate==11025)
    res=PCM_RATE_11kHz;
  else if (rate==16000)
    res=PCM_RATE_16kHz;
  else if (rate==22050)
    res=PCM_RATE_22kHz;
  else if (rate==32000)
    res=PCM_RATE_32kHz;
  else if (rate==44100)
    res=PCM_RATE_44kHz;
  else if (rate==48000)
    res=PCM_RATE_48kHz;
  else if (rate==88200)
    res=PCM_RATE_88kHz;
  else if (rate==96000)
    res=PCM_RATE_96kHz;
  else if (rate==176400)
    res=PCM_RATE_176kHz;
  else if (rate==192000)
    res=PCM_RATE_192kHz;
  else if (rate==384000)
    res=PCM_RATE_384kHz;
  return res;
}

I64 HDSizeCapBit(I64 bits)
{//Same for a container size.
  I64 res=-1;
  if (bits==8)
    res=PCM_SIZE_8_BIT;
  else if (bits==16)
    res=PCM_SIZE_16_BIT;
  else if (bits==20)
    res=PCM_SIZE_20_BIT;
  else if (bits==24)
    res=PCM_SIZE_24_BIT;
  else if (bits==32)
    res=PCM_SIZE_32_BIT;
  return res;
}

I64 HDAmpMaxGain(U32 cap)
{
  I64 res;
  if (!cap)
    res=0x7F;
  else
    res=(cap>>8)&0x7F;
  return res;
}

I64 HDPickOutFmtBits(U32 cap)
{
  I64 res=HD_32_BIT;
  U32 cap_bits=cap;
  if (cap) {
    if (Bt(&cap_bits,PCM_SIZE_32_BIT))
      res=HD_32_BIT;
    else if (Bt(&cap_bits,PCM_SIZE_24_BIT))
      res=HD_24_BIT;
    else if (Bt(&cap_bits,PCM_SIZE_20_BIT))
      res=HD_20_BIT;
  }
  return res;
}

I64 HDFmtBits2Size(I64 code)
{//Sample size in bits for an HD_*_BIT stream-format code.
  I64 res=32;
  if (code==HD_8_BIT)
    res=8;
  else if (code==HD_16_BIT)
    res=16;
  else if (code==HD_20_BIT)
    res=20;
  else if (code==HD_24_BIT)
    res=24;
  return res;
}

Bool hd_warned_out_fmt=FALSE,hd_warned_in_fmt=FALSE;

U0 HDChkFmtCap(I64 nid,U32 cap,I64 rate,I64 bits,U8 *dir,Bool *warned)
{
  I64 rate_bit,size_bit;
  U32 cap_bits=cap;

  if (*warned)
    return;
  if (!cap) {
    *warned=TRUE;
    "HD Audio: node 0x%02X (%s) reports no PCM size/rate capabilities "
	  "at all -- proceeding with %dHz/%d-bit unchecked.\n",
	  nid,dir,rate,bits;
    return;
  }
  rate_bit=HDRateCapBit(rate);
  size_bit=HDSizeCapBit(bits);
  if (rate_bit<0 || !Bt(&cap_bits,rate_bit)) {
    *warned=TRUE;
    "HD Audio: node 0x%02X (%s) does not advertise %dHz "
	  "(P_SAMPLE_SIZE_RATE_CAP=0x%08X) -- using it anyway.\n",
	  nid,dir,rate,cap;
  }
  if (size_bit<0 || !Bt(&cap_bits,size_bit)) {
    *warned=TRUE;
    "HD Audio: node 0x%02X (%s) does not advertise %d-bit samples "
	  "(P_SAMPLE_SIZE_RATE_CAP=0x%08X) -- using it anyway.\n",
	  nid,dir,bits,cap;
  }
}

U32 hd_afg_pcm_cap=0;
U32 hd_afg_in_amp=0,hd_afg_out_amp=0;

U0 HDPowerUp(I64 cad,I64 nid,Bool wait=FALSE)
{
  I64 i,st=0;
  HDWriteCORBSync(cad,nid,VERB_POWER_STATE_SET+0x00);
  if (!wait)
    return;
  for (i=0;i<100;i++) {
    st=HDWriteCORBSync(cad,nid,VERB_POWER_STATE_GET);
    if (!(st&0x0F))
      return;
    Sleep(1);
  }
  "HD Audio: node 0x%02X never reported D0 (power state 0x%02X).\n",
	nid,st&0xFF;
}

U0 HDTraverse(I64 cad,I64 nid)
{
  I64 i,len,aud_cap,type,g,fmt_bits,fmt;
  U32 pcm_cap=0,outer_pcm_cap=0,pin_cap=0;
  U32 in_amp=0,out_amp=0,outer_in_amp=0,outer_out_amp=0;
  I64 pin_ctl;
  aud_cap=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_SUBNODE_CNT);
  if (aud_cap.u16[0]) {
    if (nid)
      HDPowerUp(cad,nid,TRUE);
    HDWriteCORBSync(cad,nid,VERB_PROCESS_STATE_SET+0x02);
    outer_pcm_cap=hd_afg_pcm_cap;
    outer_in_amp =hd_afg_in_amp;
    outer_out_amp=hd_afg_out_amp;
    if (nid) {
      hd_afg_pcm_cap=
	    HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_SAMPLE_SIZE_RATE_CAP);
      hd_afg_in_amp =HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_INPUT_AMP_CAP);
      hd_afg_out_amp=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_OUTPUT_AMP_CAP);
    }
    for (i=aud_cap.u16[1];i<aud_cap.u16[1]+aud_cap.u16[0];i++)
      HDTraverse(cad,i);
    hd_afg_pcm_cap=outer_pcm_cap;
    hd_afg_in_amp =outer_in_amp;
    hd_afg_out_amp=outer_out_amp;
  } else {
    aud_cap=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_AUDIO_WIDGET_CAP);
    type=(aud_cap>>20)&15;
    if (Bt(&aud_cap,AWCAP_POWER))
      HDPowerUp(cad,nid);
    HDWriteCORBSync(cad,nid,VERB_PROCESS_STATE_SET+0x02);
    HDWriteCORBSync(cad,nid,VERB_CONNECT_SEL_SET+0x00);
    if (Bt(&aud_cap,AWCAP_CONN_LST))
      len=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_CONNECT_LST_LEN)&127;
    else
      len=0;

    in_amp =0;
    out_amp=0;
    if (Bt(&aud_cap,AWCAP_IN_AMP) || Bt(&aud_cap,AWCAP_OUT_AMP)) {
      if (Bt(&aud_cap,AWCAP_AMP_OVRD)) {
	in_amp =HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_INPUT_AMP_CAP);
	out_amp=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_OUTPUT_AMP_CAP);
      } else {
	in_amp =hd_afg_in_amp;
	out_amp=hd_afg_out_amp;
      }
    }
    if (Bt(&aud_cap,AWCAP_OUT_AMP)) {
      g=HDAmpMaxGain(out_amp);
      HDWriteCORBSync(cad,nid,VERB_AMPLIFIER_GAIN_SET+(0xB000|g));
    }
    if (Bt(&aud_cap,AWCAP_IN_AMP)) {
      g=HDAmpMaxGain(in_amp);
      HDWriteCORBSync(cad,nid,VERB_AMPLIFIER_GAIN_SET+(0x7000|g));
      for (i=1;i<len;i++)
	HDWriteCORBSync(cad,nid,VERB_AMPLIFIER_GAIN_SET+(0x7080|(i<<8)));
    }

    if (type==AWT_OUTPUT || type==AWT_INPUT) {
      pcm_cap=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_SAMPLE_SIZE_RATE_CAP);
      if (!Bt(&aud_cap,AWCAP_FORMAT_OVRD) && hd_afg_pcm_cap)
	pcm_cap=hd_afg_pcm_cap;
    }
    switch (type) {
      case AWT_OUTPUT:
	if (!hda.out_fmt_chosen) {
	  fmt_bits=HDPickOutFmtBits(pcm_cap);
	  hda.out_fmt=HD_2_CHAN+(fmt_bits<<4)+(HD_48kHz<<8);
	  hda.out_fmt_chosen=TRUE;
	}
	fmt=hda.out_fmt;
	HDWriteCORBSync(cad,nid,VERB_CHAN_STREAM_ID_SET+0x10);
	HDWriteCORBSync(cad,nid,VERB_STREAM_FMT_SET+fmt);
	HDWriteCORBSync(cad,nid,VERB_PROCESS_STATE_SET+0x01);
	HDChkFmtCap(nid,pcm_cap,SND_SAMPLE_RATE,
	      HDFmtBits2Size((fmt>>4)&7),"output",&hd_warned_out_fmt);
	break;
      case AWT_INPUT:
	HDWriteCORBSync(cad,nid,VERB_CHAN_STREAM_ID_SET+0x00);
	HDWriteCORBSync(cad,nid,VERB_STREAM_FMT_SET+hda.in_fmt);
	HDWriteCORBSync(cad,nid,VERB_PROCESS_STATE_SET+0x01);
	HDChkFmtCap(nid,pcm_cap,SND_SAMPLE_RATE,
	      sizeof(SND_IN_CONTAINER)*8,"input",&hd_warned_in_fmt);
	break;
      case AWT_PIN_COMPLEX:
	pin_cap=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_PIN_CAP);
	pin_ctl=0;
	if (Bt(&pin_cap,PINCAP_OUTPUT)) {
	  pin_ctl=PWC_OUT_EN;
	  if (Bt(&pin_cap,PINCAP_HEADPHONE))
	    pin_ctl=pin_ctl|PWC_HP_EN;
	} else if (Bt(&pin_cap,PINCAP_INPUT))
	  pin_ctl=PWC_IN_EN;
	HDWriteCORBSync(cad,nid,VERB_PIN_WIDGET_CTL_SET+pin_ctl);
	if (Bt(&pin_cap,PINCAP_EAPD))
	  HDWriteCORBSync(cad,nid,VERB_EAPDBTL_ENABLE_SET+0x02);
	break;
    }
  }
}

U0 HDStreamRst(I64 str)
{
  U8 *_b;
  U32 *_d;
  I64 i;
  _d=hda.bar+str+STRCTL;
  *_d=0;
  _b=hda.bar+str+STRSTS;
  *_b=0x1C;

  *_d=0x01;
  for (i=0;i<100;i++) {
    if (*_d&0x01)
      goto rst_entered;
    Sleep(1);
  }
  "HD Audio: stream at 0x%03X would not enter reset.\n",str;
rst_entered:
  *_d=0;
  for (i=0;i<100;i++) {
    if (!(*_d&0x01))
      return;
    Sleep(1);
  }
  "HD Audio: stream at 0x%03X would not leave reset.\n",str;
}

U0 HDRun(Bool in,Bool out)
{
  U32 *_d;
  if (hda.bar) {
    if (out) {
      _d=hda.bar+hda.ostr+STRCTL;
      *_d=0x100002;
      hda.out_running=TRUE;
    }
    if (in) {
      _d=hda.bar+hda.istr+STRCTL;
      *_d=0x200002;
      hda.in_running=TRUE;
    }
  }
}

U0 HDStop(Bool in,Bool out)
{
  U32 *_d;
  if (hda.bar) {
    if (out) {
      _d=hda.bar+hda.ostr+STRCTL;
      *_d=0;
      hda.out_running=FALSE;
    }
    if (in) {
      _d=hda.bar+hda.istr+STRCTL;
      *_d=0;
      hda.in_running=FALSE;
    }
  }
}

U0 HDSnd(F64 freq,I64 waveform=WF_SQUARE,F64 amp=1.0)
{
  hda.waveform=waveform;
  hda.amp=amp;
  hda.freq=freq;
}

U0 HDAltSndDev(I64 ona)
{
  HDSnd(Ona2Freq(ona));
}

#ifdef HD_DBG_LR_TEST
I64 hd_dbg_l_ph=0,hd_dbg_r_ph=0;
#endif

U0 HDFillBuf(SND_OUT_CONTAINER *buf,I64)
{
  I64 i,size=SND_BUF_LEN*sizeof(SND_OUT_CONTAINER);
#ifdef HD_DBG_LR_TEST
  I64 j,l_period=SND_SAMPLE_RATE/440,r_period=SND_SAMPLE_RATE/880;
  I32 l_val,r_val;
  for (j=0;j<SND_BUF_LEN;j+=SND_OCHANNELS) {
    hd_dbg_l_ph++;
    if (hd_dbg_l_ph>=l_period)
      hd_dbg_l_ph=0;
    if (hd_dbg_l_ph<l_period/2)
      l_val=0x40000000;
    else
      l_val=-0x40000000;
    hd_dbg_r_ph++;
    if (hd_dbg_r_ph>=r_period)
      hd_dbg_r_ph=0;
    if (hd_dbg_r_ph<r_period/2)
      r_val=0x40000000;
    else
      r_val=-0x40000000;
    buf[j]=l_val;
    buf[j+1]=r_val;
  }
  return;
#endif
  if (!hda.o_tmp_buf)
    hda.o_tmp_buf=AMAlloc(size);
  MemSet(hda.o_tmp_buf,0,size);
  for (i=0;i<HD_TONES;i++)
    SndWaveAddBuf(hda.tone_swcs[i],hda.o_tmp_buf,
	  SND_BUF_LEN/SND_OCHANNELS,hda.freq,
	  hda.waveform,snd_vol*hda.amp);
  MemCpy(buf,hda.o_tmp_buf,size);
}

U0 HDAudioTaskEndCB()
{
  I64 i;
  HDStop(FALSE,TRUE);
  fp_snd=NULL;
  for (i=0;i<HD_TONES;i++) {
    SndWaveCtrlDel(hda.tone_swcs[i]);
    hda.tone_swcs[i]=NULL;
  }
  Exit;
}

public U0 HDTonesInit()
{
  I64 i;
  if (hda.bar) {
    for (i=0;i<HD_TONES;i++) {
      hda.tone_swcs[i]->freq_multiplier=1.0;
      hda.tone_swcs[i]->amp_multiplier=0;
    }
    hda.tone_swcs[0]->amp_multiplier=1.0;
  }
}

U0 HDValidatePosBuf()
{
  U32 *lpib;
  I64 p0,p1,l0,l1,i;
  if (!hda.opos)
    return;
  lpib=hda.bar+hda.ostr+STRLPIB;
  p0=*hda.opos;
  l0=*lpib;
  p1=p0;
  l1=l0;
  for (i=0;i<50;i++) {
    Sleep(1);
    p1=*hda.opos;
    l1=*lpib;
    if (p1!=p0)
      return;
  }
  if (l1!=l0) {
    "HD Audio: DMA position buffer is not counting, falling back to LPIB.\n";
    hda.opos=NULL;
    hda.ipos=NULL;
  }
}

I64 HDOutPos()
{
  U32 *_d;
  I64 res;
  if (hda.opos)
    res=*hda.opos;
  else {
    _d=hda.bar+hda.ostr+STRLPIB;
    res=*_d;
  }
  return res;
}

I64 HDInPos()
{
  U32 *_d;
  I64 res;
  if (hda.ipos)
    res=*hda.ipos;
  else {
    _d=hda.bar+hda.istr+STRLPIB;
    res=*_d;
  }
  return res;
}

U0 HDAudioTask(I64)
{
  I64 i,ob,last_ob=0,ib,last_ib=0;
  Fs->task_end_cb=&HDAudioTaskEndCB;
  for (i=0;i<HD_TONES;i++)
    hda.tone_swcs[i]=SndWaveCtrlNew(SND_SAMPLE_RATE,SND_SAMPLE_BITS,
	  SND_OCHANNELS);
  HDTonesInit;
  hda.freq=0;
  Snd;
  fp_snd=&HDSnd;
  fp_snd_fill_buf=&HDFillBuf;
  fp_snd_copy_buf=NULL;
  snd_obuf_num=1;
  snd_ibuf_num=1;
  HDRun(FALSE,TRUE);
  HDValidatePosBuf;
  hda.audio_task_started=TRUE;
  while (TRUE) {
    ob=HDOutPos/(SND_BUF_LEN*sizeof(SND_OUT_CONTAINER))&1;
    if (ob!=last_ob) {
      last_ob=ob;
      i=ob^1;
      if (fp_snd_fill_buf) {
	LBts(&snd_flags,Sf_FILLING_OUT);
	(*fp_snd_fill_buf)(hda.ostr0_buf[i],snd_obuf_num);
	if (IsMute)
	  MemSet(hda.ostr0_buf[i],0,
		SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
	LBtr(&snd_flags,Sf_FILLING_OUT);
      }
      snd_obuf_num++;
    }
    ib=HDInPos/(SND_BUF_LEN*sizeof(SND_IN_CONTAINER))&1;
    if (ib!=last_ib) {
      last_ib=ib;
      if (fp_snd_copy_buf)
	(*fp_snd_copy_buf)(hda.istr0_buf[ib^1],snd_ibuf_num);
      snd_ibuf_num++;
    }
    Sleep(1);
  }
}

U0 HDRst()
{
  U32 d,*_d;
  U16 *_w;
  HDStop(TRUE,TRUE);
  _w=hda.bar+HD_STATESTS;
  *_w=0x7FFF;
  _d=hda.bar+HD_GCTL;
  *_d=0;
  do {
    Sleep(1);
    d=*_d;
  } while (d & 1);
  *_d=1;
  do {
    Sleep(1);
    d=*_d;
  } while (!(d & 1));
  Sleep(1);
}

public U0 HDAudioEnd(Bool rst=TRUE)
{
  U32 *_d;
  snd_dev=SD_PC_SPEAKER;
  if (hda.bar) {
    if (snd.fp_alt_snd_dev==&HDAltSndDev)
      snd.fp_alt_snd_dev=NULL;
    while (TaskValidate(hda.task))
      if (!Kill(hda.task))
        Yield;
    hda.task=NULL;
    if (rst)
      HDRst;
    _d=hda.bar+HD_DPLBASE;
    *_d=0;
    _d=hda.bar+HD_DPUBASE;
    *_d=0;
    hda.opos=NULL;
    hda.ipos=NULL;
    Free(hda.posbuf);
    hda.posbuf=NULL;
    Free(hda.corb);
    Free(hda.rirb);
    Free(hda.o_tmp_buf);
    Free(hda.ostr0_buf[0]);
    Free(hda.ostr0_buf[1]);
    Free(hda.istr0_buf[0]);
    Free(hda.istr0_buf[1]);
    Free(hda.ostr0_bdl);
    Free(hda.istr0_bdl);
    hda.corb=NULL;
    hda.rirb=NULL;
    hda.o_tmp_buf=NULL;
    hda.ostr0_buf[0]=NULL;
    hda.ostr0_buf[1]=NULL;
    hda.istr0_buf[0]=NULL;
    hda.istr0_buf[1]=NULL;
    hda.ostr0_bdl=NULL;
    hda.istr0_bdl=NULL;
    hda.bar=NULL;
  }
}

U0 HDPCIUpdate(I64 bus,I64 dev,I64 fun,I64 rg,I64 mask,I64 val)
{
  I64 dw_rg,shift,dw;
  dw_rg=rg&~3;
  shift=(rg&3)*8;
  dw=PCIReadU32(bus,dev,fun,dw_rg);
  dw=dw&~(mask<<shift);
  dw=dw|((val&mask)<<shift);
  PCIWriteU32(bus,dev,fun,dw_rg,dw);
}

U0 HDInitPCI(I64 hd_bus,I64 hd_dev,I64 hd_fun,I64 vendor)
{
  HDPCIUpdate(hd_bus,hd_dev,hd_fun,0x04,0x0406,0x0406);

  HDPCIUpdate(hd_bus,hd_dev,hd_fun,HD_PCI_TCSEL,0x07,0x00);

  if (vendor==0x8086)
    HDPCIUpdate(hd_bus,hd_dev,hd_fun,HD_PCI_DEVC,HD_DEVC_NOSNOOP,0);
  else if (vendor==0x1002 || vendor==0x1022)
    HDPCIUpdate(hd_bus,hd_dev,hd_fun,0x42,0x07,0x02);
  else if (vendor==0x10DE) {
    HDPCIUpdate(hd_bus,hd_dev,hd_fun,0x4E,0x0F,0x0F);
    HDPCIUpdate(hd_bus,hd_dev,hd_fun,0x4D,0x01,0x01);
    HDPCIUpdate(hd_bus,hd_dev,hd_fun,0x4C,0x01,0x01);
  }
}

U0 HDInitStreamLayout()
{//Work out where the stream descriptors actually are, from GCAP.
  U16 *_w;
  I64 gcap;
  _w=hda.bar+HD_GCAP;
  gcap=*_w;
  hda.iss=(gcap>>8)&0x0F;
  hda.oss=(gcap>>12)&0x0F;
  hda.bss=(gcap>>3)&0x1F;
  if (!hda.iss && !hda.oss) {
    hda.iss=HD_DFT_ISS;
    hda.oss=HD_DFT_OSS;
  }
  hda.istr_idx=0;
  hda.ostr_idx=hda.iss;
  hda.istr=HD_STR_BASE+hda.istr_idx*HD_STR_SIZE;
  hda.ostr=HD_STR_BASE+hda.ostr_idx*HD_STR_SIZE;
}

I64 HDRingSize(U8 *sz_reg,I64 *_mask)
{
  I64 cap,ents;
  cap=(*sz_reg>>4)&0x0F;
  if (cap&0x04) {
    *sz_reg=(*sz_reg&~0x03)|0x02;
    ents=256;
  } else if (cap&0x02) {
    *sz_reg=(*sz_reg&~0x03)|0x01;
    ents=16;
  } else if (cap&0x01) {
    *sz_reg=*sz_reg&~0x03;
    ents=2;
  } else {
    cap=*sz_reg&0x03;
    if (cap==2)
      ents=256;
    else if (cap==1)
      ents=16;
    else
      ents=2;
  }
  *_mask=ents-1;
  return ents;
}

public Bool HDAudioInit(I64 hd_bus,I64 hd_dev,I64 hd_fun)
{
  I64 i,vendor,bar_lo,bar_hi,pos_sz;
  U32 *_d;
  U16 w,*_w;
  U8 *_b;
  if (hda.bar) {
    if (TaskValidate(hda.task))
      HDAudioEnd;
    else
      MemSet(&hda,0,sizeof(CHDAudioCtrl));
  }
  vendor=PCIReadU16(hd_bus,hd_dev,hd_fun,0);
  bar_lo=PCIReadU32(hd_bus,hd_dev,hd_fun,0x10);
  hda.bar=bar_lo&~0xF;
  if ((bar_lo&0x06)==0x04) {
    bar_hi=PCIReadU32(hd_bus,hd_dev,hd_fun,0x14);
    hda.bar=hda.bar+(bar_hi<<32);
  }
  if (hda.bar) {
    HDInitPCI(hd_bus,hd_dev,hd_fun,vendor);

    *MemPageTable(hda.bar)=*MemPageTable(hda.bar)&~0x18 |0x11;
    *MemPageTable(hda.bar+mem_page_size)=
	  *MemPageTable(hda.bar+mem_page_size)&~0x18 |0x11;
    InvlPg(hda.bar);
    InvlPg(hda.bar+mem_page_size);

    HDInitStreamLayout;
    hda.in_fmt =HD_DFT_IN_FMT;
    hda.out_fmt=HD_DFT_OUT_FMT;
    hda.out_fmt_chosen=FALSE;

    HDRst;

    hda.corb=CAllocAligned(HD_CORB_ENTRIES*sizeof(U32),128,sys_dma_heap);
    _d=hda.bar+HD_CORBLBASE;
    *_d=hda.corb(I64).u32[0];
    _d=hda.bar+HD_CORBUBASE;
    *_d=hda.corb(I64).u32[1];
    _b=hda.bar+HD_CORBSIZE;
    HDRingSize(_b,&hda.corb_mask);

    hda.rirb=CAllocAligned(HD_RIRB_ENTRIES*sizeof(I64),128,sys_dma_heap);
    _d=hda.bar+HD_RIRBLBASE;
    *_d=hda.rirb(I64).u32[0];
    _d=hda.bar+HD_RIRBUBASE;
    *_d=hda.rirb(I64).u32[1];
    _b=hda.bar+HD_RIRBSIZE;
    HDRingSize(_b,&hda.rirb_mask);

    _w=hda.bar+HD_CORBRP;
    *_w=0x8000;
    do {
      Yield;
      w=*_w;
    } while (!(w&0x8000));
    *_w=0x0000;
    do {
      Yield;
      w=*_w;
    } while (w&0x8000);

    _w=hda.bar+HD_RIRBWP;
    *_w=0x8000;

    _w=hda.bar+HD_RINTCNT;
    *_w=0xFF;

    _b=hda.bar+HD_CORBCTL;
    *_b=0x02;
    _b=hda.bar+HD_RIRBCTL;
    *_b=0x03;

    _w=hda.bar+HD_CORBWP;
    hda.corb_wp=*_w&hda.corb_mask;
    _w=hda.bar+HD_RIRBWP;
    hda.rirb_rp=*_w&hda.rirb_mask;

    pos_sz=8*(hda.iss+hda.oss+hda.bss);
    if (pos_sz<8)
      pos_sz=8;
    hda.posbuf=CAllocAligned(pos_sz,128,sys_dma_heap);
    _d=hda.bar+HD_DPUBASE;
    *_d=hda.posbuf(I64).u32[1];
    _d=hda.bar+HD_DPLBASE;
    *_d=hda.posbuf(I64).u32[0]|1;
    hda.opos=&hda.posbuf[2*hda.ostr_idx];
    hda.ipos=&hda.posbuf[2*hda.istr_idx];

    HDStreamRst(hda.ostr);
    hda.ostr0_bdl =CAllocAligned(
	  HD_BDL_ENTRIES*sizeof(CHDBufDesc),128,sys_dma_heap);
    _d=hda.bar+hda.ostr+STRBDPL;
    *_d=hda.ostr0_bdl(I64).u32[0];
    _d=hda.bar+hda.ostr+STRBDPU;
    *_d=hda.ostr0_bdl(I64).u32[1];
    for (i=0;i<2;i++) {
      hda.ostr0_bdl[i].buf=hda.ostr0_buf[i]=
	    CAllocAligned(
	    SND_BUF_LEN*sizeof(SND_OUT_CONTAINER),128,sys_dma_heap);
      hda.ostr0_bdl[i].len=SND_BUF_LEN*sizeof(SND_OUT_CONTAINER);
      hda.ostr0_bdl[i].ctrl=1;
    }

    HDStreamRst(hda.istr);
    hda.istr0_bdl =CAllocAligned(
	  HD_BDL_ENTRIES*sizeof(CHDBufDesc),128,sys_dma_heap);
    _d=hda.bar+hda.istr+STRBDPL;
    *_d=hda.istr0_bdl(I64).u32[0];
    _d=hda.bar+hda.istr+STRBDPU;
    *_d=hda.istr0_bdl(I64).u32[1];
    for (i=0;i<2;i++) {
      hda.istr0_bdl[i].buf=hda.istr0_buf[i]=CAllocAligned(
	    SND_BUF_LEN*sizeof(SND_IN_CONTAINER),128,sys_dma_heap);
      hda.istr0_bdl[i].len=SND_BUF_LEN*sizeof(SND_IN_CONTAINER);
      hda.istr0_bdl[i].ctrl=1;
    }

    _w=hda.bar+HD_STATESTS;
    w=*_w;
    while (w) {
      hda.cad=Bsf(w);
      if (HDTestCORBSync(hda.cad,0,VERB_GET_PARAM+P_SUBNODE_CNT)) {
	hd_warned_out_fmt=FALSE;
	hd_warned_in_fmt=FALSE;
	hd_afg_pcm_cap=0;
	hd_afg_in_amp=0;
	hd_afg_out_amp=0;
	hda.out_fmt_chosen=FALSE;
	HDTraverse(hda.cad,0);
	"HD Audio: %04X:%04X bus %d dev %d fun %d, %d in/%d out streams, "
	      "codec %d, out fmt 0x%04X (%d-bit).\n",
	      vendor,PCIReadU16(hd_bus,hd_dev,hd_fun,2),hd_bus,hd_dev,hd_fun,
	      hda.iss,hda.oss,hda.cad,hda.out_fmt,
	      HDFmtBits2Size((hda.out_fmt>>4)&7);

	_d=hda.bar+hda.ostr+STRLPIB;
	*_d=0;
	_d=hda.bar+hda.ostr+STRCBL;
	*_d=2*SND_BUF_LEN*sizeof(SND_OUT_CONTAINER);
	_w=hda.bar+hda.ostr+STRLVI;
	*_w=1;
	_w=hda.bar+hda.ostr+STRFMT;
	*_w=hda.out_fmt;
	_w=hda.bar+hda.ostr+STRFIFOS;
	if (!*_w)
	  "HD Audio: output stream did not accept format 0x%04X "
		"(SDnFIFOS still 0).\n",hda.out_fmt;

	_d=hda.bar+hda.istr+STRLPIB;
	*_d=0;
	_d=hda.bar+hda.istr+STRCBL;
	*_d=2*SND_BUF_LEN*sizeof(SND_IN_CONTAINER);
	_w=hda.bar+hda.istr+STRLVI;
	*_w=1;
	_w=hda.bar+hda.istr+STRFMT;
	*_w=hda.in_fmt;

	LBts(&sys_semas[SEMA_SND],0);
	LBtr(&snd_flags,Sf_FILLING_OUT);
	hda.audio_task_started=FALSE;
	if (mp_cnt>3)
	  hda.task=Spawn(&HDAudioTask,NULL,"HD Audio",3);
	else if (mp_cnt>1)
	  hda.task=Spawn(&HDAudioTask,NULL,"HD Audio",1);
	else
	  hda.task=Spawn(&HDAudioTask,NULL,"HD Audio");
	while (!hda.audio_task_started)
	  Yield;
	snd_dev=SD_HD_AUDIO;
	snd.fp_alt_snd_dev=&HDAltSndDev;
	return TRUE;
      }
      Btr(&w,hda.cad);
    }
    HDAudioEnd(FALSE);
  } else
    hda.bar=NULL;
  return FALSE;
}

Bool HDAudioScan()
{
  I64 i,j,pass;
  Bool scanning;
  for (pass=0;pass<2;pass++) {
    i=-1;
    scanning=TRUE;
    while (scanning) {
      j=PCIClassFind(0x040300,++i);
      if (j<0)
	scanning=FALSE;
      else if (HDAudioInit(j.u8[2],j.u8[1],j.u8[0])) {
	if (pass || hda.iss)
	  return TRUE;
	HDAudioEnd;
      }
    }
  }
  return FALSE;
}

HDAudioScan;

#help_index ""
