#help_index "Snd/HDCfgNew"

#ifdef SD_HD_AUDIO

#define CONNECTS_NUM	32

#define HD_MENU_AUTO		-1
#define HD_MENU_ADVANCED	-2
#define HD_MENU_SAVE		-3
#define HD_MENU_CANCEL		-4
#define HD_MENU_TEST		-5

class CHDWidget
{
  U8 nid,type,num_connects,cur_connect;
  Bool valid,disabled;
  U32 audio_widget_capabilities;
  U8 connect_lst[CONNECTS_NUM];
  U8 gain_lst[CONNECTS_NUM];
  U32 pin_capabilities,pin_sense,pcm_size_rates,
	in_amp_cap,out_amp_cap,cfg_default;
  U8 pin_widget_ctl;
};

CHDWidget hd_widgets[256];
MemSet(hd_widgets,0,sizeof(CHDWidget)*256);
I64 hd_order[256];
I64 hd_count=0;
U32 hd_afg_in_amp_cap=0;
U32 hd_afg_out_amp_cap=0;

Bool HDWIsOutputDevice(I64 dev)
{//Line Out/Speaker/HP Out/SPDIF Out/Digital Other Out.
  Bool res;
  if (dev==0 || dev==1 || dev==2 || dev==4 || dev==5)
    res=TRUE;
  else
    res=FALSE;
  return res;
}

Bool HDWIsInputDevice(I64 dev)
{//CD/Line In/Aux/Mic In/Telephony/SPDIF In/Digital Other In.
  Bool res;
  if (dev==3 || dev==8 || dev==9 || dev==0xA || dev==0xB ||
	dev==0xC || dev==0xD)
    res=TRUE;
  else
    res=FALSE;
  return res;
}

U0 HDCfgReset()
{
  MemSet(hd_widgets,0,sizeof(CHDWidget)*256);
  hd_count=0;
  hd_afg_in_amp_cap=0;
  hd_afg_out_amp_cap=0;
}

U0 HDCfgAddConnect(CHDWidget *w,I64 nid)
{
  if (w->num_connects<CONNECTS_NUM && nid>0 && nid<=255) {
    w->connect_lst[w->num_connects]=nid;
    w->num_connects++;
  }
}

U0 HDCfgConnectLst(CHDWidget *w,I64 cad,I64 nid)
{
  I64 i,j,parm,len,shift,num_elems,mask,val,n,prev;
  Bool range;

  parm=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_CONNECT_LST_LEN);
  len=parm&127;
  if (!len)
    return;
  if (parm&128) {
    shift=16;
    num_elems=2;
  }
  else {
    shift=8;
    num_elems=4;
  }
  mask=(1<<(shift-1))-1;

  if (len==1) {
    j=HDWriteCORBSync(cad,nid,VERB_GET_CONNECT_LST+0);
    HDCfgAddConnect(w,j&mask);
    return;
  }

  j=0;
  prev=0;
  for (i=0;i<len;i++) {
    if (!(i%num_elems))
      j=HDWriteCORBSync(cad,nid,VERB_GET_CONNECT_LST+i)&0xFFFFFFFF;
    range=FALSE;
    if (j&(1<<(shift-1)))
      range=TRUE;
    val=j&mask;
    j=j>>shift;
    if (range) {
      if (prev && prev<val)
	for (n=prev+1;n<=val;n++)
	  HDCfgAddConnect(w,n);
    }
    else
      HDCfgAddConnect(w,val);
    prev=val;
  }
}

U0 HDCfgTraverse(I64 cad,I64 nid,I64 depth=0)
{
  I64 i,j;
  U32 outer_in_cap,outer_out_cap;
  CHDWidget *w;

  if (depth<=8 && nid>=0 && nid<=255 && hd_count<256) {
    w=&hd_widgets[nid];
    w->nid=nid;
    w->valid=TRUE;
    hd_order[hd_count++]=nid;

    j=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_SUBNODE_CNT);
    if (j.u16[0]) {
      w->type=AWT_NODE;
      outer_in_cap =hd_afg_in_amp_cap;
      outer_out_cap=hd_afg_out_amp_cap;
      if (nid) {
	w->in_amp_cap=
	      HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_INPUT_AMP_CAP);
	w->out_amp_cap=
	      HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_OUTPUT_AMP_CAP);
	hd_afg_in_amp_cap =w->in_amp_cap;
	hd_afg_out_amp_cap=w->out_amp_cap;
      }
      for (i=j.u16[1];i<j.u16[1]+j.u16[0];i++)
	HDCfgTraverse(cad,i,depth+1);
      hd_afg_in_amp_cap =outer_in_cap;
      hd_afg_out_amp_cap=outer_out_cap;
    }
    else {
      w->audio_widget_capabilities=
	    HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_AUDIO_WIDGET_CAP);
      w->pcm_size_rates=
	    HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_SAMPLE_SIZE_RATE_CAP);
      w->in_amp_cap=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_INPUT_AMP_CAP);
      w->out_amp_cap=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_OUTPUT_AMP_CAP);
      if (!Bt(&w->audio_widget_capabilities,3)) {
	if (hd_afg_in_amp_cap)
	  w->in_amp_cap=hd_afg_in_amp_cap;
	if (hd_afg_out_amp_cap)
	  w->out_amp_cap=hd_afg_out_amp_cap;
      }
      w->type=(w->audio_widget_capabilities>>20)&15;
      if (w->type==AWT_PIN_COMPLEX) {
	w->pin_widget_ctl=HDWriteCORBSync(cad,nid,VERB_PIN_WIDGET_CTL_GET);
	w->pin_capabilities=HDWriteCORBSync(cad,nid,VERB_GET_PARAM+P_PIN_CAP);
	w->cfg_default=HDWriteCORBSync(cad,nid,VERB_CFG_DFT0_GET+0x00);
	if (Bt(&w->pin_capabilities,PINCAP_IMPEDANCE_SENSE) ||
	      Bt(&w->pin_capabilities,PINCAP_PRESENCE_DETECT))
	  w->pin_sense=HDWriteCORBSync(cad,nid,VERB_PIN_SENSE_GET);
	w->disabled=TRUE;
      }
      else if (w->type==AWT_INPUT)
	w->disabled=TRUE;
      else if (w->type==AWT_OUTPUT)
	w->disabled=FALSE;
      if (Bt(&w->audio_widget_capabilities,8))
	HDCfgConnectLst(w,cad,nid);
      if (w->num_connects) {
	j=HDWriteCORBSync(cad,nid,VERB_CONNECT_SEL_GET);
	w->cur_connect=j&0xFF;
	if (w->cur_connect>=w->num_connects)
	  w->cur_connect=0;
      }
    }
  }
}

Bool HDReachesOutput(I64 nid,I64 depth=0)
{
  CHDWidget *w;
  I64 i;
  Bool res;

  res=FALSE;
  if (nid>=0 && nid<=255 && depth<=8) {
    w=&hd_widgets[nid];
    if (w->valid) {
      if (w->type==AWT_OUTPUT)
	res=TRUE;
      else if (w->type==AWT_MIXER || w->type==AWT_SELECTOR)
	for (i=0;i<w->num_connects;i++)
	  if (HDReachesOutput(w->connect_lst[i],depth+1))
	    res=TRUE;
    }
  }
  return res;
}

U0 HDAutoRouteOut(I64 nid,I64 depth=0)
{
  CHDWidget *w;
  I64 i,g;
  Bool picked;

  if (nid>=0 && nid<=255 && depth<=8) {
    w=&hd_widgets[nid];
    if (w->valid && w->type!=AWT_OUTPUT) {
      picked=FALSE;
      for (i=0;i<w->num_connects;i++) {
	if (!picked && HDReachesOutput(w->connect_lst[i],depth+1)) {
	  if (w->type==AWT_MIXER) {
	    g=HDAmpMaxGain(w->in_amp_cap);
	    w->gain_lst[i]=g;
	  }
	  else
	    w->cur_connect=i;
	  picked=TRUE;
	  HDAutoRouteOut(w->connect_lst[i],depth+1);
	}
	else if (w->type==AWT_MIXER)
	  w->gain_lst[i]=0x80;
      }
    }
  }
}

U0 HDPickRouteOut(CHDWidget *w)
{
  I64 i;
  Bool found;
  found=FALSE;
  for (i=0;i<w->num_connects;i++)
    if (!found && HDReachesOutput(w->connect_lst[i])) {
      w->cur_connect=i;
      HDAutoRouteOut(w->connect_lst[i]);
      found=TRUE;
    }
}

U0 HDAutoWirePin(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  I64 dev,conn;

  conn=w->cfg_default>>30&0x3;
  dev=w->cfg_default>>20&0xF;
  if (conn==1) {
    w->disabled=TRUE;
    w->pin_widget_ctl=0;
  }
  else if (HDWIsOutputDevice(dev) && Bt(&w->pin_capabilities,PINCAP_OUTPUT)) {
    w->pin_widget_ctl=PWC_OUT_EN;
    if (Bt(&w->pin_capabilities,PINCAP_HEADPHONE))
      w->pin_widget_ctl=w->pin_widget_ctl|PWC_HP_EN;
    w->disabled=FALSE;
    if (w->num_connects) {
      HDPickRouteOut(w);
      if (!HDReachesOutput(w->connect_lst[w->cur_connect]))
	w->disabled=TRUE;
    }
  }
  else if (HDWIsInputDevice(dev) && Bt(&w->pin_capabilities,PINCAP_INPUT)) {
    w->pin_widget_ctl=PWC_IN_EN;
    if (Bt(&w->pin_capabilities,PINCAP_VREF_80))
      w->pin_widget_ctl=(w->pin_widget_ctl&~7)|PWC_VREF_80;
    else if (Bt(&w->pin_capabilities,PINCAP_VREF_50))
      w->pin_widget_ctl=(w->pin_widget_ctl&~7)|PWC_VREF_50;
    else if (Bt(&w->pin_capabilities,PINCAP_VREF_GND))
      w->pin_widget_ctl=(w->pin_widget_ctl&~7)|PWC_VREF_GND;
    w->disabled=FALSE;
  }
  else {
    w->disabled=TRUE;
    w->pin_widget_ctl=0;
  }
}

U0 HDApplyPin(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  HDWriteCORBSync(hda.cad,nid,VERB_PIN_WIDGET_CTL_SET+w->pin_widget_ctl);
  if (Bt(&w->pin_capabilities,PINCAP_EAPD)) {
    if (w->disabled)
      HDWriteCORBSync(hda.cad,nid,VERB_EAPDBTL_ENABLE_SET+0x00);
    else
      HDWriteCORBSync(hda.cad,nid,VERB_EAPDBTL_ENABLE_SET+0x02);
  }
  if (w->num_connects>1)
    HDWriteCORBSync(hda.cad,nid,VERB_CONNECT_SEL_SET+w->cur_connect);
}

U0 HDApplyOutput(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  I64 g;
  if (w->disabled)
    HDWriteCORBSync(hda.cad,nid,VERB_CHAN_STREAM_ID_SET+0x00);
  else {
    HDWriteCORBSync(hda.cad,nid,VERB_CHAN_STREAM_ID_SET+0x10);
    g=HDAmpMaxGain(w->out_amp_cap);
    HDWriteCORBSync(hda.cad,nid,VERB_AMPLIFIER_GAIN_SET+(0xB000|g));
  }
}

U0 HDApplyInput(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  I64 g;
  if (w->disabled)
    HDWriteCORBSync(hda.cad,nid,VERB_CHAN_STREAM_ID_SET+0x00);
  else {
    HDWriteCORBSync(hda.cad,nid,VERB_CHAN_STREAM_ID_SET+0x20);
    g=HDAmpMaxGain(w->in_amp_cap);
    HDWriteCORBSync(hda.cad,nid,VERB_AMPLIFIER_GAIN_SET+(0x7000|g));
    if (w->cur_connect)
      HDWriteCORBSync(hda.cad,nid,
	    VERB_AMPLIFIER_GAIN_SET+(0x7000|g|(w->cur_connect<<8)));
  }
  if (w->num_connects>1)
    HDWriteCORBSync(hda.cad,nid,VERB_CONNECT_SEL_SET+w->cur_connect);
}

U0 HDApplyMixer(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  I64 i;
  for (i=0;i<w->num_connects;i++)
    HDWriteCORBSync(hda.cad,nid,
	  VERB_AMPLIFIER_GAIN_SET+(0x7000|w->gain_lst[i]|(i<<8)));
}

U0 HDApplySelector(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  if (w->num_connects>1)
    HDWriteCORBSync(hda.cad,nid,VERB_CONNECT_SEL_SET+w->cur_connect);
}

U0 HDApplyWidget(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  if (w->type==AWT_PIN_COMPLEX)
    HDApplyPin(nid);
  else if (w->type==AWT_OUTPUT)
    HDApplyOutput(nid);
  else if (w->type==AWT_INPUT)
    HDApplyInput(nid);
  else if (w->type==AWT_MIXER)
    HDApplyMixer(nid);
  else if (w->type==AWT_SELECTOR || w->type==AWT_VENDOR)
    HDApplySelector(nid);
}

U0 HDApplyAll()
{
  I64 idx;
  for (idx=0;idx<hd_count;idx++)
    HDApplyWidget(hd_order[idx]);
}

U0 HDCfgAutoWire()
{
  I64 idx,nid;
  CHDWidget *w;

  for (idx=0;idx<hd_count;idx++) {
    nid=hd_order[idx];
    w=&hd_widgets[nid];
    if (w->type==AWT_PIN_COMPLEX)
      HDAutoWirePin(nid);
  }
  HDApplyAll;
}

U0 HDCfgProbe()
{
  HDCfgReset;
  HDCfgTraverse(hda.cad,0);
}

U0 HDPinLabel(I64 nid,U8 *buf)
{
  CHDWidget *w=&hd_widgets[nid];
  I64 dev,conn,loc;
  U8 *status;

  dev=w->cfg_default>>20&0xF;
  conn=w->cfg_default>>30&0x3;
  loc=w->cfg_default>>24&0x3F;
  if (w->disabled)
    status="off";
  else
    status="ON";
  StrPrint(buf,"0x%02X %Z (%Z, %Z) [%s]",
	nid,dev,"ST_PIN_DEVICE",
	conn,"ST_PIN_PORT_CONN",
	loc,"ST_PIN_LOCATION",status);
}

I64 HDCfgPickConnection(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  CDoc *doc;
  I64 i,res;

  doc=DocNew;
  DocPrint(doc,"$$FG,BROWN$$Pick source for 0x%02X$$FG$$\n\n",nid);
  for (i=0;i<w->num_connects;i++) {
    if (i==w->cur_connect)
      DocPrint(doc,"$$MU,\"0x%02X (current)\",LE=%d$$\n",w->connect_lst[i],i);
    else
      DocPrint(doc,"$$MU,\"0x%02X\",LE=%d$$\n",w->connect_lst[i],i);
  }
  DocPrint(doc,"\n$$MU,\"Cancel\",LE=-1$$\n");
  res=PopUpMenu(doc);
  DocDel(doc);
  return res;
}

U0 HDCfgCycleVref(CHDWidget *w)
{
  I64 opts[5],n,i,cur,next_i;

  n=0;
  opts[n]=PWC_VREF_HIZ;
  n++;
  if (Bt(&w->pin_capabilities,PINCAP_VREF_50)) {
    opts[n]=PWC_VREF_50;
    n++;
  }
  if (Bt(&w->pin_capabilities,PINCAP_VREF_GND)) {
    opts[n]=PWC_VREF_GND;
    n++;
  }
  if (Bt(&w->pin_capabilities,PINCAP_VREF_80)) {
    opts[n]=PWC_VREF_80;
    n++;
  }
  if (Bt(&w->pin_capabilities,PINCAP_VREF_100)) {
    opts[n]=PWC_VREF_100;
    n++;
  }
  cur=w->pin_widget_ctl&7;
  next_i=0;
  for (i=0;i<n;i++)
    if (opts[i]==cur)
      next_i=i+1;
  if (next_i>=n)
    next_i=0;
  w->pin_widget_ctl=(w->pin_widget_ctl&~7)|opts[next_i];
}

U0 HDCfgPinEditMenu(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  CDoc *doc;
  I64 res,i;
  U8 label[128];
  Bool looping;

  looping=TRUE;
  while (looping) {
    doc=DocNew;
    HDPinLabel(nid,label);
    DocPrint(doc,"$$FG,BROWN$$%s$$FG$$\n\n",label);
    if (w->disabled)
      DocPrint(doc,"$$MU,\"Enable\",LE=1$$\n");
    else
      DocPrint(doc,"$$MU,\"Disable\",LE=1$$\n");
    if (w->num_connects>1)
      DocPrint(doc,"$$MU,\"Change Source (currently 0x%02X)\",LE=2$$\n",
	    w->connect_lst[w->cur_connect]);
    if (Bt(&w->pin_capabilities,PINCAP_INPUT))
      DocPrint(doc,"$$MU,\"Cycle Mic Bias/Vref\",LE=3$$\n");
    if (Bt(&w->pin_capabilities,PINCAP_HEADPHONE))
      DocPrint(doc,"$$MU,\"Toggle Headphone Amp Bit\",LE=4$$\n");
    DocPrint(doc,"\n$$MU,\"Back\",LE=0$$\n");
    res=PopUpMenu(doc);
    DocDel(doc);
    if (res==1) {
      if (w->disabled) {
	if (Bt(&w->pin_capabilities,PINCAP_OUTPUT)) {
	  w->pin_widget_ctl=PWC_OUT_EN;
	  if (Bt(&w->pin_capabilities,PINCAP_HEADPHONE))
	    w->pin_widget_ctl=w->pin_widget_ctl|PWC_HP_EN;
	  if (w->num_connects)
	    HDPickRouteOut(w);
	}
	else if (Bt(&w->pin_capabilities,PINCAP_INPUT))
	  w->pin_widget_ctl=PWC_IN_EN;
	w->disabled=FALSE;
      }
      else {
	w->disabled=TRUE;
	w->pin_widget_ctl=0;
      }
      HDApplyWidget(nid);
    }
    else if (res==2) {
      i=HDCfgPickConnection(nid);
      if (i>=0) {
	w->cur_connect=i;
	HDApplyWidget(nid);
      }
    }
    else if (res==3) {
      HDCfgCycleVref(w);
      HDApplyWidget(nid);
    }
    else if (res==4) {
      w->pin_widget_ctl=w->pin_widget_ctl^PWC_HP_EN;
      HDApplyWidget(nid);
    }
    else
      looping=FALSE;
  }
}

U0 HDCfgAdvancedInfo(I64 nid)
{
  CHDWidget *w=&hd_widgets[nid];
  CDoc *doc;
  I64 i,res;

  doc=DocNew;
  DocPrint(doc,"$$FG,RED$$NID:$$FG$$0x%02X $$FG,RED$$Type:$$FG$$%Z\n",
	nid,w->type,"ST_AUDIO_WIDGET_TYPES");
  if (w->num_connects) {
    DocPrint(doc,"\n$$FG,RED$$Connections:$$FG$$\n");
    for (i=0;i<w->num_connects;i++) {
      if (i==w->cur_connect)
	DocPrint(doc,"*0x%02X ",w->connect_lst[i]);
      else
	DocPrint(doc,"0x%02X ",w->connect_lst[i]);
    }
    DocPrint(doc,"\n");
  }
  if (w->type==AWT_OUTPUT) {
    if (w->disabled)
      DocPrint(doc,"\n$$MU,\"Enable Output\",LE=1$$\n");
    else
      DocPrint(doc,"\n$$MU,\"Disable Output\",LE=1$$\n");
  }
  else if (w->type==AWT_INPUT) {
    if (w->disabled)
      DocPrint(doc,"\n$$MU,\"Enable Capture\",LE=1$$\n");
    else
      DocPrint(doc,"\n$$MU,\"Disable Capture\",LE=1$$\n");
  }
  else if (w->num_connects>1)
    DocPrint(doc,"\n$$MU,\"Change Source (currently 0x%02X)\",LE=2$$\n",
	  w->connect_lst[w->cur_connect]);
  DocPrint(doc,"\n$$MU,\"Back\",LE=0$$\n");
  res=PopUpMenu(doc);
  DocDel(doc);
  if (res==1) {
    w->disabled=!w->disabled;
    HDApplyWidget(nid);
  }
  else if (res==2) {
    i=HDCfgPickConnection(nid);
    if (i>=0) {
      w->cur_connect=i;
      HDApplyWidget(nid);
    }
  }
}

U0 HDCfgAdvancedMenu()
{
  CDoc *doc;
  I64 idx,nid,res;
  CHDWidget *w;
  Bool looping;

  looping=TRUE;
  while (looping) {
    doc=DocNew;
    DocPrint(doc,"$$FG,BROWN$$Advanced -- raw codec nodes$$FG$$\n\n");
    for (idx=0;idx<hd_count;idx++) {
      nid=hd_order[idx];
      w=&hd_widgets[nid];
      if (w->type!=AWT_PIN_COMPLEX && w->type!=AWT_NODE)
	DocPrint(doc,"$$MU,\"0x%02X %Z\",LE=%d$$\n",
	      nid,w->type,"ST_AUDIO_WIDGET_TYPES",nid);
    }
    DocPrint(doc,"\n$$MU,\"Back\",LE=-1$$\n");
    res=PopUpMenu(doc);
    DocDel(doc);
    if (res>=0)
      HDCfgAdvancedInfo(res);
    else
      looping=FALSE;
  }
}

I64 HDCfgMainMenu()
{
  CDoc *doc;
  I64 idx,nid,res,dev,conn;
  CHDWidget *w;
  U8 label[128];

  doc=DocNew;
  DocPrint(doc,"$$FG,BROWN$$HD Audio Configuration$$FG$$\n"
	"Click a jack below to configure it.\n\n");

  DocPrint(doc,"$$FG,GREEN$$-- Outputs --$$FG$$\n");
  for (idx=0;idx<hd_count;idx++) {
    nid=hd_order[idx];
    w=&hd_widgets[nid];
    if (w->type==AWT_PIN_COMPLEX) {
      dev=w->cfg_default>>20&0xF;
      conn=w->cfg_default>>30&0x3;
      if (conn!=1 && HDWIsOutputDevice(dev)) {
	HDPinLabel(nid,label);
	DocPrint(doc,"$$MU,\"%s\",LE=%d$$\n",label,nid);
      }
    }
  }

  DocPrint(doc,"\n$$FG,GREEN$$-- Inputs --$$FG$$\n");
  for (idx=0;idx<hd_count;idx++) {
    nid=hd_order[idx];
    w=&hd_widgets[nid];
    if (w->type==AWT_PIN_COMPLEX) {
      dev=w->cfg_default>>20&0xF;
      conn=w->cfg_default>>30&0x3;
      if (conn!=1 && HDWIsInputDevice(dev)) {
	HDPinLabel(nid,label);
	DocPrint(doc,"$$MU,\"%s\",LE=%d$$\n",label,nid);
      }
    }
  }

  DocPrint(doc,"\n$$FG,GREEN$$-- Not Connected / Other --$$FG$$\n");
  for (idx=0;idx<hd_count;idx++) {
    nid=hd_order[idx];
    w=&hd_widgets[nid];
    if (w->type==AWT_PIN_COMPLEX) {
      dev=w->cfg_default>>20&0xF;
      conn=w->cfg_default>>30&0x3;
      if (conn==1 || (!HDWIsOutputDevice(dev) && !HDWIsInputDevice(dev))) {
	HDPinLabel(nid,label);
	DocPrint(doc,"$$MU,\"%s\",LE=%d$$\n",label,nid);
      }
    }
  }

  DocPrint(doc,"\n$$FG,GREEN$$-- Actions --$$FG$$\n");
  DocPrint(doc,"$$MU,\"Auto-Config (reset all pins to sensible defaults)\","
	"LE=%d$$\n",HD_MENU_AUTO);
  DocPrint(doc,"$$MU,\"Advanced (raw DAC/ADC/Mixer/Selector nodes)\","
	"LE=%d$$\n",HD_MENU_ADVANCED);
  DocPrint(doc,"$$MU,\"Play Test Tone (440Hz, 1s)\",LE=%d$$\n",HD_MENU_TEST);
  DocPrint(doc,"$$MU,\"Save And Exit\",LE=%d$$\n",HD_MENU_SAVE);
  DocPrint(doc,"$$MU,\"Cancel (discard changes)\",LE=%d$$\n",HD_MENU_CANCEL);

  res=PopUpMenu(doc);
  DocDel(doc);
  return res;
}

U0 HDCfgSave(U8 *filename=NULL)
{//filename=NULL means the default, "~/HDAudioCfg.HC.Z".
  CDoc *doc=DocNew;
  I64 idx,nid,i,dev,conn,loc,g;
  CHDWidget *w;
  U8 *status;

  DocPrint(doc,"//This file was generated by "
	"$$LK,\"::/Demo/Snd/HDCfgNew.HC.Z\","
	"\"FI:::/Demo/Snd/HDCfgNew.HC\"$$\n\n"
	"U0 MyHDCfg()\n{\n");

  for (idx=0;idx<hd_count;idx++) {
    nid=hd_order[idx];
    w=&hd_widgets[nid];

    if (w->type==AWT_PIN_COMPLEX) {
      dev=w->cfg_default>>20&0xF;
      conn=w->cfg_default>>30&0x3;
      loc=w->cfg_default>>24&0x3F;
      if (w->disabled)
	status=" (disabled)";
      else
	status="";
      DocPrint(doc,"  //0x%02X Pin Complex -- %Z, %Z, %Z%s\n",
	    nid,dev,"ST_PIN_DEVICE",conn,"ST_PIN_PORT_CONN",
	    loc,"ST_PIN_LOCATION",status);
    }
    else
      DocPrint(doc,"  //0x%02X %Z\n",nid,w->type,"ST_AUDIO_WIDGET_TYPES");

    if (w->num_connects) {
      DocPrint(doc,"  //Connection Lst:");
      for (i=0;i<w->num_connects;i++) {
	if (i==w->cur_connect)
	  DocPrint(doc,"*");
	DocPrint(doc,"0x%02X ",w->connect_lst[i]);
      }
      DocPrint(doc,"\n");
      if (w->type==AWT_MIXER) {
	DocPrint(doc,"  //Gain Lst:");
	for (i=0;i<w->num_connects;i++)
	  DocPrint(doc,"0x%02X ",w->gain_lst[i]);
	DocPrint(doc,"\n");
      }
    }

    if (w->type==AWT_OUTPUT) {
      g=HDAmpMaxGain(w->out_amp_cap);
      if (w->disabled)
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CHAN_STREAM_ID_SET+0x00);\n",nid);
      else {
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CHAN_STREAM_ID_SET+0x10);\n",nid);
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_AMPLIFIER_GAIN_SET+0x%04X);\n",nid,0xB000|g);
      }
    }
    else if (w->type==AWT_INPUT) {
      g=HDAmpMaxGain(w->in_amp_cap);
      if (w->disabled)
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CHAN_STREAM_ID_SET+0x00);\n",nid);
      else {
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CHAN_STREAM_ID_SET+0x20);\n",nid);
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_AMPLIFIER_GAIN_SET+0x%04X);\n",nid,0x7000|g);
	if (w->cur_connect)
	  DocPrint(doc,
		"  HDWriteCORBSync(hda.cad,0x%02X,"
		"VERB_AMPLIFIER_GAIN_SET+0x%04X);\n",
		nid,0x7000|g|(w->cur_connect<<8));
      }
      if (w->num_connects>1)
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CONNECT_SEL_SET+0x%02X);\n",nid,w->cur_connect);
    }
    else if (w->type==AWT_MIXER) {
      for (i=0;i<w->num_connects;i++)
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_AMPLIFIER_GAIN_SET+0x%04X);\n",
	      nid,0x7000|w->gain_lst[i]|(i<<8));
    }
    else if (w->type==AWT_PIN_COMPLEX) {
      DocPrint(doc,
	    "  HDWriteCORBSync(hda.cad,0x%02X,"
	    "VERB_PIN_WIDGET_CTL_SET+0x%02X);\n",nid,w->pin_widget_ctl);
      if (Bt(&w->pin_capabilities,PINCAP_EAPD)) {
	if (w->disabled)
	  DocPrint(doc,
		"  HDWriteCORBSync(hda.cad,0x%02X,"
		"VERB_EAPDBTL_ENABLE_SET+0x00);\n",nid);
	else
	  DocPrint(doc,
		"  HDWriteCORBSync(hda.cad,0x%02X,"
		"VERB_EAPDBTL_ENABLE_SET+0x02);\n",nid);
      }
      if (w->num_connects>1)
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CONNECT_SEL_SET+0x%02X);\n",nid,w->cur_connect);
    }
    else if (w->type==AWT_SELECTOR || w->type==AWT_VENDOR) {
      if (w->num_connects>1)
	DocPrint(doc,
	      "  HDWriteCORBSync(hda.cad,0x%02X,"
	      "VERB_CONNECT_SEL_SET+0x%02X);\n",nid,w->cur_connect);
    }
    DocPrint(doc,"\n");
  }

  DocPrint(doc,"  LBtr(&sys_semas[SEMA_SND],0);\n"
	"}\n\nif (snd_dev==SD_HD_AUDIO)\n"
	"  MyHDCfg;\n");
  if (filename)
    StrCpy(doc->filename.name,filename);
  else
    StrCpy(doc->filename.name,"~/HDAudioCfg.HC.Z");
  DocWrite(doc);
  DocDel(doc);
}

public U0 HDCfgAuto(U8 *filename=NULL)
{
  I64 idx,nid,n_out,n_in;
  CHDWidget *w;
  U8 *out_name;

  if (snd_dev!=SD_HD_AUDIO) {
    "HD Audio not detected\n";
    return;
  }
  HDCfgProbe;
  HDCfgAutoWire;
  n_out=0;
  n_in=0;
  for (idx=0;idx<hd_count;idx++) {
    nid=hd_order[idx];
    w=&hd_widgets[nid];
    if (w->type==AWT_PIN_COMPLEX && !w->disabled) {
      if (HDWIsOutputDevice(w->cfg_default>>20&0xF))
	n_out++;
      else
	n_in++;
    }
  }
  HDCfgSave(filename);
  if (filename)
    out_name=filename;
  else
    out_name="~/HDAudioCfg.HC.Z";
  "HD Audio config: %d out, %d in -> %s\n",n_out,n_in,out_name;
}

public U0 HDCfgGui(U8 *filename=NULL)
{//filename=NULL means the default, "~/HDAudioCfg.HC.Z".
  I64 res;
  Bool looping;

  if (snd_dev!=SD_HD_AUDIO) {
    "HD Audio not detected\n";
    return;
  }
  HDCfgProbe;
  HDCfgAutoWire;
  HDRun(TRUE,TRUE);
  looping=TRUE;
  try {
    while (looping) {
      res=HDCfgMainMenu;
      if (res==HD_MENU_SAVE) {
	HDCfgSave(filename);
	looping=FALSE;
      }
      else if (res==HD_MENU_CANCEL)
	looping=FALSE;
      else if (res==DOCM_CANCEL)
	looping=FALSE;
      else if (res==HD_MENU_AUTO)
	HDCfgAutoWire;
      else if (res==HD_MENU_ADVANCED)
	HDCfgAdvancedMenu;
      else if (res==HD_MENU_TEST) {
	HDSnd(440);
	Sleep(1000);
	HDSnd(0);
      }
      else if (res>=0)
	HDCfgPinEditMenu(res);
    }
  } catch
    Fs->catch_except=TRUE;
  HDStop(TRUE,FALSE);
  "$$BK,1$$Note: #include \"~/HDAudioCfg\" in your start-up scripts."
	"$$BK,0$$\n";
}

#ifdef hd_cfg_out_file
HDCfgAuto(hd_cfg_out_file);
#else
HDCfgAuto;
#endif

#else

"HDCfgNew: the HD Audio driver isn't loaded, so there's nothing to "
      "configure.\nBring up ::/Demo/Snd/HDAudio.HC first, then run "
      "::/Demo/Snd/HDCfgNew.HC again.\n";

#endif
