
#help_index "Snd/HDMixerGui"

#define MIXSLD_WIDTH	56
#define MIXSLD_GAP	20
#define MIXSLD_TRAVEL	160
#define MIXSLD_BORDER	2
#define MIXSLD_TOP	(FONT_HEIGHT+6)

class CMixerSliderState
{
  F64 *val;
  F64 vmin,vmax;
  U8 name[MIXER_NAME_LEN];
};

U0 DrawCtrlMixerSlider(CDC *dc,CCtrl *c)
{
  CMixerSliderState *s=c->state;
  I64 knob_y,pct,track_top=c->top+MIXSLD_TOP;
  F64 frac;
  dc->color=LTBLUE;
  GrRect(dc,c->left,c->top,MIXSLD_WIDTH,
	MIXSLD_TOP+MIXSLD_TRAVEL+FONT_HEIGHT+8);
  dc->color=BLUE;
  GrRect(dc,c->left+MIXSLD_BORDER,track_top,
	MIXSLD_WIDTH-2*MIXSLD_BORDER,MIXSLD_TRAVEL);
  dc->color=WHITE;
  GrPrint(dc,c->left+(MIXSLD_WIDTH-StrLen(s->name)*FONT_WIDTH)/2,
	c->top+3,"%s",s->name);
  frac=Clamp((*s->val-s->vmin)/(s->vmax-s->vmin),0.0,1.0);
  knob_y=track_top+MIXSLD_TRAVEL-1-ToI64(frac*(MIXSLD_TRAVEL-1));
  dc->color=BLACK;
  GrLine(dc,c->left+MIXSLD_WIDTH/2,track_top,
	c->left+MIXSLD_WIDTH/2,track_top+MIXSLD_TRAVEL-1);
  dc->color=YELLOW;
  GrRect(dc,c->left+4,knob_y-3,MIXSLD_WIDTH-8,7);
  pct=ToI64(frac*100);
  dc->color=WHITE;
  GrPrint(dc,c->left+(MIXSLD_WIDTH-4*FONT_WIDTH)/2,
	track_top+MIXSLD_TRAVEL+4,"%3d%%",pct);
}

U0 LeftClickMixerSlider(CCtrl *c,I64,I64 y,Bool)
{
  CMixerSliderState *s=c->state;
  F64 frac=1.0-ToF64(y-(c->top+MIXSLD_TOP))/(MIXSLD_TRAVEL-1);
  *s->val=s->vmin+Clamp(frac,0.0,1.0)*(s->vmax-s->vmin);
}

U0 UpdateDerivedCtrlMixerSlider(CCtrl *c)
{
  CMixerSliderState *s=c->state;
  *s->val=Clamp(*s->val,s->vmin,s->vmax);
}

CCtrl *MixerSliderNew(I64 x,I64 y,F64 *val,F64 vmin,F64 vmax,U8 *name)
{
  CCtrl *c=CAlloc(sizeof(CCtrl));
  CMixerSliderState *s=CAlloc(sizeof(CMixerSliderState));
  s->val=val;
  s->vmin=vmin;
  s->vmax=vmax;
  StrCpy(s->name,name);
  c->win_task=Fs;
  c->flags=CTRLF_SHOW|CTRLF_CAPTURE_LEFT_MS;
  c->type=CTRLT_GENERIC;
  c->state=s;
  c->draw_it=&DrawCtrlMixerSlider;
  c->left_click=&LeftClickMixerSlider;
  c->update_derived_vals=&UpdateDerivedCtrlMixerSlider;
  c->left=x;
  c->top=y;
  c->right=x+MIXSLD_WIDTH-1;
  c->bottom=y+MIXSLD_TOP+MIXSLD_TRAVEL+FONT_HEIGHT+8-1;
  QueIns(c,Fs->last_ctrl);
  TaskDerivedValsUpdate;
  return c;
}

U0 MixerSliderDel(CCtrl *c)
{
  QueRem(c);
  Free(c->state);
  Free(c);
}

#define MIXHSLD_TOP	(FONT_HEIGHT+4)
#define MIXHSLD_TRACK	14
#define MIXHSLD_KNOB	6
#define MIXHSLD_TRAVEL	(MIXSLD_WIDTH-2*MIXSLD_BORDER)
#define MIXHSLD_HEIGHT	(MIXHSLD_TOP+MIXHSLD_TRACK+FONT_HEIGHT+6)

U0 DrawCtrlMixerHSlider(CDC *dc,CCtrl *c)
{
  CMixerSliderState *s=c->state;
  I64 knob_x,pct,track_left=c->left+MIXSLD_BORDER,
      track_top=c->top+MIXHSLD_TOP;
  F64 frac;
  dc->color=LTBLUE;
  GrRect(dc,c->left,c->top,MIXSLD_WIDTH,MIXHSLD_HEIGHT);
  dc->color=BLUE;
  GrRect(dc,track_left,track_top,MIXHSLD_TRAVEL,MIXHSLD_TRACK);
  dc->color=WHITE;
  GrPrint(dc,c->left+(MIXSLD_WIDTH-StrLen(s->name)*FONT_WIDTH)/2,
	c->top+3,"%s",s->name);
  frac=Clamp((*s->val-s->vmin)/(s->vmax-s->vmin),0.0,1.0);
  knob_x=track_left+ToI64(frac*(MIXHSLD_TRAVEL-MIXHSLD_KNOB));
  dc->color=BLACK;
  GrLine(dc,track_left,track_top+MIXHSLD_TRACK/2,
	track_left+MIXHSLD_TRAVEL-1,track_top+MIXHSLD_TRACK/2);
  dc->color=YELLOW;
  GrRect(dc,knob_x,track_top+2,MIXHSLD_KNOB,MIXHSLD_TRACK-4);
  pct=ToI64(frac*100);
  dc->color=WHITE;
  GrPrint(dc,c->left+(MIXSLD_WIDTH-4*FONT_WIDTH)/2,
	track_top+MIXHSLD_TRACK+3,"%3d%%",pct);
}

U0 LeftClickMixerHSlider(CCtrl *c,I64 x,I64,Bool)
{
  CMixerSliderState *s=c->state;
  F64 frac=ToF64(x-(c->left+MIXSLD_BORDER+MIXHSLD_KNOB/2))/
	(MIXHSLD_TRAVEL-MIXHSLD_KNOB);
  *s->val=s->vmin+Clamp(frac,0.0,1.0)*(s->vmax-s->vmin);
}

CCtrl *MixerHSliderNew(I64 x,I64 y,F64 *val,F64 vmin,F64 vmax,U8 *name)
{
  CCtrl *c=CAlloc(sizeof(CCtrl));
  CMixerSliderState *s=CAlloc(sizeof(CMixerSliderState));
  s->val=val;
  s->vmin=vmin;
  s->vmax=vmax;
  StrCpy(s->name,name);
  c->win_task=Fs;
  c->flags=CTRLF_SHOW|CTRLF_CAPTURE_LEFT_MS;
  c->type=CTRLT_GENERIC;
  c->state=s;
  c->draw_it=&DrawCtrlMixerHSlider;
  c->left_click=&LeftClickMixerHSlider;
  c->update_derived_vals=&UpdateDerivedCtrlMixerSlider;
  c->left=x;
  c->top=y;
  c->right=x+MIXSLD_WIDTH-1;
  c->bottom=y+MIXHSLD_HEIGHT-1;
  QueIns(c,Fs->last_ctrl);
  TaskDerivedValsUpdate;
  return c;
}

#define MIXLINK_HEIGHT	(FONT_HEIGHT+4)
#define MIXER_GUI_CMD_PICKINST	1
#define MIXER_GUI_CMD_BEEP	2
#define MIXER_GUI_CMD_HELLO	3
#define MIXER_GUI_CMD_LRTEST	4
#define MIXER_GUI_CMD_MISSION	5
#define MIXER_GUI_CMD_WORK4GOD	6
#define MIXER_GUI_CMD_RISEN	7
#define MIXER_GUI_CMD_RESET	8

class CMixerLinkState
{
  I64 cmd;
  U8 text[16];
};

U0 DrawCtrlMixerLink(CDC *dc,CCtrl *c)
{
  CMixerLinkState *s=c->state;
  dc->color=RED;
  GrPrint(dc,c->left,c->top+2,"%s",s->text);
  GrLine(dc,c->left,c->top+2+FONT_HEIGHT,
	c->right,c->top+2+FONT_HEIGHT);
}

U0 LeftClickMixerLink(CCtrl *c,I64,I64,Bool down)
{
  CMixerLinkState *s=c->state;
  if (!down)
    PostMsg(c->win_task,MSG_CMD,s->cmd,0);
}

CCtrl *MixerLinkNew(I64 x,I64 y,U8 *text,I64 cmd)
{
  CCtrl *c=CAlloc(sizeof(CCtrl));
  CMixerLinkState *s=CAlloc(sizeof(CMixerLinkState));
  s->cmd=cmd;
  StrCpy(s->text,text);
  c->win_task=Fs;
  c->flags=CTRLF_SHOW|CTRLF_CAPTURE_LEFT_MS;
  c->type=CTRLT_GENERIC;
  c->state=s;
  c->draw_it=&DrawCtrlMixerLink;
  c->left_click=&LeftClickMixerLink;
  c->left=x;
  c->top=y;
  c->right=x+StrLen(text)*FONT_WIDTH-1;
  c->bottom=y+MIXLINK_HEIGHT-1;
  QueIns(c,Fs->last_ctrl);
  TaskDerivedValsUpdate;
  return c;
}

U0 MixerLinkDel(CCtrl *c)
{
  QueRem(c);
  Free(c->state);
  Free(c);
}

CTask *mixer_gui_risen_task=NULL;

#if defined(GetInstNum) && defined(SetInstNum) && defined(GetInstName)
#define MIXER_GUI_OPL_INST 1
#endif

U0 MixerGuiRisenTask(I64)
{//Plays the Risen tune once, no graphics.  See /Demo/TOSTheme.HC.
  Fs->task_end_cb=&SndTaskEndCB;
#ifdef MIXER_GUI_OPL_INST
  I64 inst;
  inst=GetInstNum;
#endif
  MusicSettingsRst;
#ifdef MIXER_GUI_OPL_INST
  SetInstNum(inst);
#endif
  music.tempo= 2.85;
  music.stacatto_factor= 0.902;
  Play("5eDEqFFetEEFqDeCDDEetCGF");
  Play("5eDEqFFetEEFqDeCDDEetCGF");
  Play("5eDCqDE4eAA5etEEFEDG4B5DCqF");
  Play("5eDCqDE4eAA5etEEFEDG4B5DCqF");
  Snd;
  mixer_gui_risen_task=NULL;
}

U0 MixerGuiRisenKill()
{
  if (TaskValidate(mixer_gui_risen_task))
    Kill(mixer_gui_risen_task);
  mixer_gui_risen_task=NULL;
}

U0 MixerGuiRisenStart()
{//Restart from the top if it's still playing.
  MixerGuiRisenKill;
  mixer_gui_risen_task=Spawn(&MixerGuiRisenTask,NULL,"Risen",,Fs);
}

#define MIXER_GUI_ROW_Y	(3*FONT_HEIGHT)

U8 *mixer_gui_hdr_msg="Sound Mixer -- drag faders; "
	"R to rescan sources; ESC to close";
U8 *mixer_gui_empty_msg="(no other sound sources registered yet -- "
	"play a Wav/MP3/etc, then press R)";

#define MIXER_GUI_FIXED_SLIDERS	2

CCtrl *mixer_gui_sliders[MIXER_MAX_SRC+MIXER_GUI_FIXED_SLIDERS];
I64 mixer_gui_slider_cnt=0;
CCtrl *mixer_gui_links[4*(MIXER_MAX_SRC+1)];
I64 mixer_gui_link_cnt=0;

I64 mixer_gui_inst_x=-1,mixer_gui_inst_y=0;

U0 MixerGuiFreeSliders()
{
  I64 i;
  for (i=0;i<mixer_gui_slider_cnt;i++)
    MixerSliderDel(mixer_gui_sliders[i]);
  mixer_gui_slider_cnt=0;
  for (i=0;i<mixer_gui_link_cnt;i++)
    MixerLinkDel(mixer_gui_links[i]);
  mixer_gui_link_cnt=0;
}

U0 MixerGuiFitWin(I64 need_w,I64 need_h)
{//Size the win to the sliders+labels, clamped to the screen.
  I64 cols=(need_w+FONT_WIDTH-1)/FONT_WIDTH,
      rows=(need_h+FONT_HEIGHT-1)/FONT_HEIGHT,
      left=Fs->win_left,top=Fs->win_top;
  if (cols>TEXT_COLS-2) cols=TEXT_COLS-2;
  if (rows>TEXT_ROWS-3) rows=TEXT_ROWS-3;
  if (left<1) left=1;
  if (left+cols-1>TEXT_COLS-2) left=TEXT_COLS-1-cols;
  if (top<2) top=2;
  if (top+rows-1>TEXT_ROWS-2) top=TEXT_ROWS-1-rows;
  WinHorz(left,left+cols-1);
  WinVert(top,top+rows-1);
}

U0 MixerGuiBuildSliders()
{
  I64 i,x=MIXSLD_GAP,pick_y,need_w,need_h=0;
  Bool opl2_on=MixerFindByName("OPL2")>=0;
  pick_y=MIXER_GUI_ROW_Y+MIXSLD_TOP+MIXSLD_TRAVEL+FONT_HEIGHT+8+3;
  mixer_gui_inst_x=-1;
  mixer_gui_sliders[mixer_gui_slider_cnt++]=
	MixerSliderNew(x,MIXER_GUI_ROW_Y,&snd_vol,0.0,1.0,"Master");
  mixer_gui_sliders[mixer_gui_slider_cnt++]=MixerHSliderNew(
	x,pick_y,&mixer_reverb,0.0,1.0,"Reverb");
  x+=MIXSLD_WIDTH+MIXSLD_GAP;
  for (i=0;i<MIXER_MAX_SRC;i++)
    if (mixer_srcs[i].active &&
	  !(opl2_on && !StrCmp(mixer_srcs[i].name,"Tones"))) {
      mixer_gui_sliders[mixer_gui_slider_cnt++]=MixerSliderNew(
	    x,MIXER_GUI_ROW_Y,&mixer_srcs[i].vol,0.0,1.0,mixer_srcs[i].name);
      if (!StrCmp(mixer_srcs[i].name,"OPL2")) {
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-8*FONT_WIDTH)/2,pick_y,
	      "PickInst",MIXER_GUI_CMD_PICKINST);
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-4*FONT_WIDTH)/2,pick_y+MIXLINK_HEIGHT+2,
	      "Beep",MIXER_GUI_CMD_BEEP);
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,pick_y+2*(MIXLINK_HEIGHT+2),
	      "Reset",MIXER_GUI_CMD_RESET);
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,pick_y+3*(MIXLINK_HEIGHT+2),
	      "Risen",MIXER_GUI_CMD_RISEN);
#ifdef MIXER_GUI_OPL_INST
	mixer_gui_inst_x=x;
	mixer_gui_inst_y=pick_y+5*(MIXLINK_HEIGHT+2);
#endif
      }
      if (!StrCmp(mixer_srcs[i].name,"Tones")) {
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-4*FONT_WIDTH)/2,pick_y,
	      "Beep",MIXER_GUI_CMD_BEEP);
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,pick_y+MIXLINK_HEIGHT+2,
	      "Reset",MIXER_GUI_CMD_RESET);
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,pick_y+2*(MIXLINK_HEIGHT+2),
	      "Risen",MIXER_GUI_CMD_RISEN);
      }
      if (!StrCmp(mixer_srcs[i].name,"TMS5220"))
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,pick_y,
	      "Hello",MIXER_GUI_CMD_HELLO);
      if (!StrCmp(mixer_srcs[i].name,"Wav"))
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-6*FONT_WIDTH)/2,pick_y,
	      "LRTest",MIXER_GUI_CMD_LRTEST);
      if (!StrCmp(mixer_srcs[i].name,"MP3")) {
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-7*FONT_WIDTH)/2,pick_y,
	      "Mission",MIXER_GUI_CMD_MISSION);
	mixer_gui_links[mixer_gui_link_cnt++]=MixerLinkNew(
	      x+(MIXSLD_WIDTH-8*FONT_WIDTH)/2,pick_y+MIXLINK_HEIGHT+2,
	      "Work4God",MIXER_GUI_CMD_WORK4GOD);
      }
      x+=MIXSLD_WIDTH+MIXSLD_GAP;
    }
  need_w=x-MIXSLD_GAP+2*MIXSLD_BORDER;
  i=MIXSLD_GAP+StrLen(mixer_gui_hdr_msg)*FONT_WIDTH+2*MIXSLD_BORDER;
  if (i>need_w) need_w=i;
  if (mixer_gui_slider_cnt<=MIXER_GUI_FIXED_SLIDERS) {
    i=MIXSLD_GAP+StrLen(mixer_gui_empty_msg)*FONT_WIDTH+2*MIXSLD_BORDER;
    if (i>need_w) need_w=i;
  }
  for (i=0;i<mixer_gui_slider_cnt;i++)
    if (mixer_gui_sliders[i]->bottom+1>need_h)
      need_h=mixer_gui_sliders[i]->bottom+1;
  for (i=0;i<mixer_gui_link_cnt;i++)
    if (mixer_gui_links[i]->bottom+1>need_h)
      need_h=mixer_gui_links[i]->bottom+1;
  if (mixer_gui_inst_x>=0) {
    i=mixer_gui_inst_y+MIXLINK_HEIGHT+2+FONT_HEIGHT;
    if (i>need_h) need_h=i;
  }
  MixerGuiFitWin(need_w,need_h+FONT_HEIGHT/2);
}

U0 MixerGuiDrawBg(CTask *,CDC *dc)
{
#ifdef MIXER_GUI_OPL_INST
  U8 *inst;
#endif
  dc->color=BLACK;
  GrPrint(dc,MIXSLD_GAP,FONT_HEIGHT/2,"%s",mixer_gui_hdr_msg);
  if (mixer_gui_slider_cnt<=MIXER_GUI_FIXED_SLIDERS)
    GrPrint(dc,MIXSLD_GAP,MIXER_GUI_ROW_Y+MIXSLD_TOP+MIXSLD_TRAVEL/2,
	  "%s",mixer_gui_empty_msg);
#ifdef MIXER_GUI_OPL_INST
  if (mixer_gui_inst_x>=0) {
    inst=GetInstName;
    GrPrint(dc,mixer_gui_inst_x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,
	  mixer_gui_inst_y,"Instrument:");
    GrPrint(dc,mixer_gui_inst_x+(MIXSLD_WIDTH-5*FONT_WIDTH)/2,
	  mixer_gui_inst_y+MIXLINK_HEIGHT+2,"%s",inst);
  }
#endif
}

public U0 MixerGui()
{
  I64 arg1,arg2;
  if (snd_dev!=SD_HD_AUDIO || fp_snd_fill_buf!=&MixerFillBuf) {
    "MixerGui: HD Audio mixer not active -- bring up HDAudio.HC and "
	  "HDMixer.HC first.\n";
    return;
  }
  SettingsPush;
  MenuPush(
	"File {"
	"  Exit(,CH_ESC);"
	"}"
	"Edit {"
	"  Rescan(,'r');"
	"}"
	);
  DocClear;
  Fs->draw_it=&MixerGuiDrawBg;
  MixerGuiBuildSliders;
  try {
    while (TRUE) {
      switch (GetMsg(&arg1,&arg2,1<<MSG_KEY_DOWN|1<<MSG_CMD)) {
	case MSG_KEY_DOWN:
	  switch (arg1) {
	    case 'r':
	    case 'R':
	      MixerGuiFreeSliders;
	      MixerGuiBuildSliders;
	      break;
	    case CH_ESC:
	    case CH_SHIFT_ESC:
	      throw;
	  }
	  break;
	case MSG_CMD:
	  if (arg1==MIXER_GUI_CMD_PICKINST && MixerFindByName("OPL2")>=0)
	    ExePrint("PickInst;");
	  else if (arg1==MIXER_GUI_CMD_BEEP)
	    Beep;
	  else if (arg1==MIXER_GUI_CMD_HELLO &&
		MixerFindByName("TMS5220")>=0)
	    ExePrint("Speak(\"Hello from Tinker O ESS\");");
	  else if (arg1==MIXER_GUI_CMD_LRTEST && MixerFindByName("Wav")>=0)
	    ExePrint("WavPlay(\"/Demo/Snd/LRTest.wav\");");
	  else if (arg1==MIXER_GUI_CMD_MISSION &&
		MixerFindByName("MP3")>=0)
	    ExePrint("MP3Play(\"/Demo/Snd/Mission.mp3\",TRUE,FALSE);");
	  else if (arg1==MIXER_GUI_CMD_WORK4GOD &&
		MixerFindByName("MP3")>=0)
	    ExePrint("MP3Play(\"/Demo/Snd/Work4God.mp3\",TRUE,FALSE);");
	  else if (arg1==MIXER_GUI_CMD_RESET)
	    MusicSettingsRst;
	  else if (arg1==MIXER_GUI_CMD_RISEN)
	    MixerGuiRisenStart;
	  break;
      }
      Refresh;
    }
  } catch
    Fs->catch_except=TRUE;
  MixerGuiRisenKill;
  MixerGuiFreeSliders;
  Fs->draw_it=NULL;
  MenuPop;
  SettingsPop;
}

try {
  MixerGui;
}
catch {
  Fs->catch_except=TRUE;
}
Exit;

#help_index ""
