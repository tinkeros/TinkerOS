Cd(__DIR__);;
#include "Jpeg"
#include "Uvc"

#define CAM_FPS		15

CDC *cam_show=NULL,*cam_back=NULL;
U8 cam_status[512];
cam_status[0]=0;

U0 CamDrawIt(CTask *task,CDC *dc)
{//The picture, with 2 status lines below it or over its bottom.
  CDC *s=cam_show;
  I64 y;
  if (!s) return;
  GrBlot(dc,0,0,s);
  y=s->height+4;
  if (y+18>task->pix_height)
  {
    y=task->pix_height-18;
    dc->color=WHITE;
    GrRect(dc,0,y-1,task->pix_width,19);
  }
  dc->color=BLACK;
  GrPrint(dc,0,y,"%s",cam_status);
}

U8 *CamNextName(U8 *dir)
{//dir/CamNNN.GR, the first one not taken. NULL if all are.
  I64 i;
  U8 *name;
  for (i=1; i<1000; i++)
  {
    name=MStrPrint("%s/Cam%03d.GR",dir,i);
    if (!FileFind(name,,FUF_Z_OR_NOT_Z))
      return name;
    Free(name);
  }
  return NULL;
}

public U8 *CamSave(CDC *dc,U8 *dir="~/Pictures")
{//Save dc as the next free dir/CamNNN.GR. Returns the name (Free it) or NULL.
  U8 *name,*abs;
  abs=DirNameAbs(dir);
  if (!IsDir(abs))
    DirMk(abs);
  name=CamNextName(abs);
  Free(abs);
  if (name && GRWrite(name,dc)<=0)
  {
    Free(name);
    name=NULL;
  }
  return name;
}

U0 CamShrink(CDC *src,CDC *dst,I64 sc)
{//src at 1/sc size into dst, keeping the dither pattern aligned.
  I64 x,y,sx,sy;
  U8 *s,*d;
  for (y=0; y<dst->height; y++)
  {
    sy=MinI64(y*sc+(y-y*sc)&3,src->height-1);
    s=src->body+sy*src->width_internal;
    d=dst->body+y*dst->width_internal;
    for (x=0; x<dst->width; x++)
    {
      sx=MinI64(x*sc+(x-x*sc)&3,src->width-1);
      d[x]=s[sx];
    }
  }
}

public U0 CamDiag(I64 w=320,I64 h=240,I64 secs=3,I64 type=-1,I64 n=0)
{//Stream for secs seconds without a window, then print UvcRep.
  CUvc *c=UvcOpen(n);
  if (!c)
  {
    "No webcam (UsbRep lists one as \"video\").\n";
    return;
  }
  if (!UvcStart(c,w,h,CAM_FPS,type))
    "The camera did not start.\n";
  else
  {
    Sleep(secs*1000);
    "kernel: %d units %d packets %d errors %d late %d restarts\n",
	  UsbVenIsoStat(c->k,c->gen,0),UsbVenIsoStat(c->k,c->gen,1),
	  UsbVenIsoStat(c->k,c->gen,2),UsbVenIsoStat(c->k,c->gen,3),
	  UsbVenIsoStat(c->k,c->gen,4);
  }
  UvcRep(c);
  UvcClose(c);
}

U0 CamDiagOne(CUvc *c,I64 w,I64 h,I64 fps,I64 type,I64 secs)
{//One line: a setting streamed for secs seconds.
  I64 cnt=0,len,dec=0,dec_bad=0,iw,ih,nshort;
  F64 t0;
  U8 *frm,*rgb,*fmt;
  if (!UvcStart(c,w,h,fps,type))
  {
    "%4dx%-4d %2dfps: did not start\n",w,h,fps;
    return;
  }
  frm=MAlloc(c->fsize);
  t0=tS;
  while (tS-t0<secs)
  {
    if (c->cur->type==UVC_MJPEG && (len=UvcGrab(c,frm,&cnt)))
    {
      if (rgb=JpgDecode(frm,len,&iw,&ih))
      {
	dec++;
	Free(rgb);
      }
      else
	dec_bad++;
    }
    Sleep(5);
    if (c->dead) break;
  }
  if (c->cur->type==UVC_MJPEG)
    fmt="MJPEG";
  else
    fmt="YUY2";
  "%4dx%-4d %-5s %2dfps (got %d.%d):",c->cur->w,c->cur->h,fmt,fps,
	c->frames/secs,c->frames*10/secs%10;
  if (c->cur->type==UVC_YUY2)
  {
    nshort=c->padded;
    " %d exact, %d short",c->frames-nshort,nshort;
    if (nshort)
      " (%d.%d lines missing on average)",c->miss_sum/(nshort*c->cur->w*2),
	    c->miss_sum*10/(nshort*c->cur->w*2)%10;
    if (c->rej_short)
      ", %d much shorter",c->rej_short;
  }
  else
    " %d decoded, %d did not",dec,dec_bad;
  if (!c->frames)
    ", %d packets, %d with data",c->pkts,c->data_pl;
  if (c->in_gaps)
    ", %d ms jumps",c->in_lost;
  if (c->bad_frames-c->rej_short-c->rej_jpg>1)
    ", %d other drops",c->bad_frames-c->rej_short-c->rej_jpg;
  '\n';
  Free(frm);
  UvcStop(c);
}

public U0 CamDiagAll(I64 secs=2,I64 n=0)
{//Each common setting for secs seconds, one line each.
  CUvc *c=UvcOpen(n);
  if (!c)
  {
    "No webcam (UsbRep lists one as \"video\").\n";
    return;
  }
  CamDiagOne(c,320,240,30,UVC_YUY2,secs);
  CamDiagOne(c,320,240,15,UVC_YUY2,secs);
  CamDiagOne(c,640,480,30,UVC_YUY2,secs);
  CamDiagOne(c,640,480,15,UVC_YUY2,secs);
  CamDiagOne(c,352,288,30,UVC_YUY2,secs);
  CamDiagOne(c,640,480,30,UVC_MJPEG,secs);
  CamDiagOne(c,640,480,15,UVC_MJPEG,secs);
  CamDiagOne(c,1280,720,30,UVC_MJPEG,secs);
  UvcClose(c);
}

public U0 CamCap(U8 *file="~/TOSXfr/cap.bin",I64 w=320,I64 h=240,I64 fps=30,
	I64 secs=4,I64 type=UVC_YUY2,I64 n=0)
{//Record every isochronous packet for secs seconds into file.
  CUvc *c=UvcOpen(n);
  if (!c)
  {
    "No webcam.\n";
    return;
  }
  uvc_cap_max=secs*8000+1024;
  uvc_cap=CAlloc(uvc_cap_max*16);
  uvc_cap_n=0;
  if (UvcStart(c,w,h,fps,type))
  {
    Sleep(secs*1000);
    UvcStop(c);
  }
  FileWrite(file,uvc_cap,uvc_cap_n*16);
  "%d packets, %d frames, %d short (%d bytes missing) -> %s\n",
	uvc_cap_n,c->frames,c->padded+c->rej_short,c->miss_sum,file;
  Free(uvc_cap);
  uvc_cap=NULL;
  UvcClose(c);
}

U8 *CamPalStr(I64 pal)
{
  if (pal==UVC_PAL_16)
    return "16 colors";
  return "all colors";
}

public U0 WebCam(I64 w=320,I64 h=240,U8 *dir="~/Pictures",I64 n=0,
	I64 type=-1,I64 pal=UVC_PAL_ALL)
{//Camera n's picture in a window. Space, S, D, P, Esc.
  CUvc *c=UvcOpen(n);
  I64 fw,fh,cnt=0,ch,sc,saved=0,len=0,got,scale=1,bad=0;
  U8 *frm,*name,last[STR_LEN],*fmt;
  CDC *t,*img;
  Bool run=TRUE,frozen=FALSE,dither=TRUE,have=FALSE,conv;
  if (!c)
  {
    "No webcam (UsbRep lists one as \"video\").\n";
    return;
  }
  if (!UvcStart(c,w,h,CAM_FPS,type))
  {
    "The camera did not start.\n";
    UvcRep(c);
    UvcClose(c);
    return;
  }
  fw=c->cur->w;
  fh=c->cur->h;
  if (c->cur->type==UVC_MJPEG)
    fmt="MJPEG";
  else
    fmt="YUY2";
  frm=MAlloc(c->fsize);
  img=DCNew(fw,fh);
  DCFill(img,BLACK);
  last[0]=0;
  SettingsPush;
  AutoComplete(0);
  WinBorder(ON);
  WinMax;
  DocCursor;
  DocClear;
  while (scale<8 && (fw/scale>Fs->pix_width*21/20 || fh/scale>Fs->pix_height-20))
    scale*=2;
  cam_back=DCNew(fw/scale,fh/scale);
  DCFill(cam_back,BLACK);
  cam_show=DCNew(fw/scale,fh/scale);
  DCFill(cam_show,BLACK);
  Fs->draw_it=&CamDrawIt;
  try
  {
    while (run)
    {
      conv=FALSE;
      while (ScanKey(&ch,&sc))
      {
	if (ch==CH_ESC || ch==CH_SHIFT_ESC)
	  run=FALSE;
	else if (ch==CH_SPACE)
	  frozen=!frozen;
	else if (ch=='d' || ch=='D')
	{
	  dither=!dither;
	  conv=have;
	}
	else if (ch=='p' || ch=='P')
	{
	  pal=(pal+1)%UVC_PALS;
	  conv=have;
	}
	else if (have && (ch=='s' || ch=='S' || ch=='\n'))
	{
	  frozen=TRUE;
	  if (name=CamSave(img,dir))
	  {
	    StrCpy(last,name);
	    saved++;
	    Free(name);
	  }
	  else
	    StrCpy(last,"Save failed");
	}
      }
      if (!frozen && (got=UvcGrab(c,frm,&cnt)))
      {
	len=got;
	conv=TRUE;
      }
      if (conv)
      {
	if (UvcFrameToDC(c,frm,len,img,dither,pal))
	{
	  if (scale>1)
	    CamShrink(img,cam_back,scale);
	  else
	    GrBlot(cam_back,0,0,img);
	  t=cam_show;
	  cam_show=cam_back;
	  cam_back=t;
	  have=TRUE;
	}
	else
	  bad++;
      }
      if (c->dead)
	StrPrint(cam_status,"Camera unplugged.  Esc: quit");
      else if (!have)
      {
	StrPrint(cam_status,"%dx%d %s: waiting for the camera... %d bad\n"
	      "%d packets, dropped %d: %d err %d long %d lost %d short %d jpg, last %d of %d",
	      fw,fh,fmt,bad,c->pkts,c->bad_frames,c->rej_err,c->rej_long,c->rej_lost,
	      c->rej_short,c->rej_jpg,c->flen[(c->nlen+UVC_NLEN-1)%UVC_NLEN],c->fsize);
	if (!c->nlen)
	  StrPrint(cam_status,"%dx%d %s: waiting for the camera... %d packets",
		fw,fh,fmt,c->pkts);
      }
      else
      {
	if (frozen)
	  StrPrint(cam_status,"%dx%d %s PICTURE  Spc:live  S:save  ",fw,fh,fmt);
	else
	  StrPrint(cam_status,"%dx%d %s live  Spc:picture  S:save  ",fw,fh,fmt);
	CatPrint(cam_status,"D:dither  P:colors  Esc:quit\n");
	//Line 2 says what is on now.  The keys above name what they toggle, which
	//read as the current mode and had the two palettes looking swapped.
	if (dither)
	  CatPrint(cam_status,"dithered, %s  %s",CamPalStr(pal),last);
	else
	  CatPrint(cam_status,"nearest, %s  %s",CamPalStr(pal),last);
      }
      Sleep(10);
    }
  }
  catch
    Fs->catch_except=TRUE;
  Fs->draw_it=NULL;
  Refresh;
  UvcClose(c);
  DCDel(cam_show);
  DCDel(cam_back);
  cam_show=cam_back=NULL;
  DCDel(img);
  Free(frm);
  SettingsPop;
  if (saved)
    "%d picture(s) saved in %s\n",saved,dir;
}

public U8 *CamSnap(U8 *dir="~/Pictures",I64 w=640,I64 h=480,
	Bool dither=TRUE,I64 n=0,I64 type=-1,I64 pal=UVC_PAL_ALL)
{//Take one picture without the window, saved as dir/CamNNN.GR.
  CUvc *c=UvcOpen(n);
  CDC *dc;
  U8 *frm,*name=NULL;
  I64 cnt=0,len;
  F64 t0;
  if (!c) return NULL;
  if (UvcStart(c,w,h,CAM_FPS,type))
  {
    frm=MAlloc(c->fsize);
    dc=DCNew(c->cur->w,c->cur->h);
    t0=tS;
    while (tS-t0<5.0 && !c->dead)
    {
      if ((len=UvcGrab(c,frm,&cnt)) && tS-t0>1.0 &&
	    UvcFrameToDC(c,frm,len,dc,dither,pal))
      {
	name=CamSave(dc,dir);
	break;
      }
      Sleep(10);
    }
    DCDel(dc);
    Free(frm);
  }
  UvcClose(c);
  return name;
}

CTask *cam_strm_task=NULL;
CUvc *cam_strm_cam=NULL;
CDC *cam_strm_show=NULL,*cam_strm_back=NULL,*cam_strm_img=NULL;
U8 *cam_strm_frm=NULL;
I64 cam_strm_w=320,cam_strm_h=240,cam_strm_n=0,cam_strm_type=-1,
	cam_strm_pal=UVC_PAL_ALL,
	cam_strm_state=0;
Bool cam_strm_dither=TRUE,cam_strm_stop=FALSE;

U0 CamStrmDrawIt(CTask *,CDC *dc)
{
  CDC *s=cam_strm_show;
  if (s)
    GrBlot(dc,0,0,s);
}

U0 CamStrmEnd()
{//The stream task's end, also when it is killed: give the camera back.
  Fs->draw_it=NULL;
  Refresh;
  UvcClose(cam_strm_cam);
  cam_strm_cam=NULL;
  DCDel(cam_strm_show);
  DCDel(cam_strm_back);
  DCDel(cam_strm_img);
  cam_strm_show=cam_strm_back=cam_strm_img=NULL;
  Free(cam_strm_frm);
  cam_strm_frm=NULL;
  cam_strm_task=NULL;
  Exit;
}

U0 CamStrmTask(U8 *)
{
  CUvc *c;
  CDC *t;
  I64 cnt=0,len,fw,fh,sc=2,cols,rows,right,bottom;
  Fs->task_end_cb=&CamStrmEnd;
  if (!(c=cam_strm_cam=UvcOpen(cam_strm_n)))
  {
    cam_strm_state=-1;
    Exit;
  }
  if (!UvcStart(c,cam_strm_w,cam_strm_h,CAM_FPS,cam_strm_type))
  {
    cam_strm_state=-2;
    Exit;
  }
  fw=c->cur->w;
  fh=c->cur->h;
  while (sc<8 && (fw/sc>GR_WIDTH/2 || fh/sc>GR_HEIGHT/2))
    sc*=2;
  cam_strm_frm=MAlloc(c->fsize);
  cam_strm_img=DCNew(fw,fh);
  cam_strm_back=DCNew(fw/sc,fh/sc);
  DCFill(cam_strm_back,BLACK);
  cam_strm_show=DCNew(fw/sc,fh/sc);
  DCFill(cam_strm_show,BLACK);
  cols=(fw/sc+FONT_WIDTH-1)/FONT_WIDTH;
  rows=(fh/sc+FONT_HEIGHT-1)/FONT_HEIGHT;
  right=TEXT_COLS-2;
  bottom=TEXT_ROWS-2;
  DocTermNew;
  DocCursor;
  LBts(&Fs->display_flags,DISPLAYf_SHOW);
  WinHorz(right-cols+1,right);
  WinVert(bottom-rows+1,bottom);
  LBts(&Fs->display_flags,DISPLAYf_WIN_ON_TOP);
  Fs->win_inhibit=WIG_NO_FOCUS_TASK_DFT;
  Fs->draw_it=&CamStrmDrawIt;
  cam_strm_state=1;
  while (!cam_strm_stop && !c->dead)
  {
    if ((len=UvcGrab(c,cam_strm_frm,&cnt)) &&
	  UvcFrameToDC(c,cam_strm_frm,len,cam_strm_img,cam_strm_dither,cam_strm_pal))
    {
      CamShrink(cam_strm_img,cam_strm_back,sc);
      t=cam_strm_show;
      cam_strm_show=cam_strm_back;
      cam_strm_back=t;
    }
    Sleep(10);
  }
  Exit;
}

public U0 CamStreamStop()
{//Close the CamStream window.
  CTask *task=cam_strm_task;
  F64 t0=tS;
  if (!TaskValidate(task))
    return;
  cam_strm_stop=TRUE;
  while (TaskValidate(task) && tS-t0<5.0)
    Sleep(10);
  if (TaskValidate(task))
    Kill(task);
}

public Bool CamStream(I64 w=320,I64 h=240,Bool dither=TRUE,
	I64 pal=UVC_PAL_ALL,I64 n=0,I64 type=-1)
{//Camera n's picture at half size in an always-on-top lower right window.
  F64 t0=tS;
  if (TaskValidate(cam_strm_task))
  {
    CamStreamStop;
    return FALSE;
  }
  cam_strm_w=w;
  cam_strm_h=h;
  cam_strm_dither=dither;
  cam_strm_pal=pal;
  cam_strm_n=n;
  cam_strm_type=type;
  cam_strm_state=0;
  cam_strm_stop=FALSE;
  cam_strm_task=Spawn(&CamStrmTask,NULL,"WebCam");
  while (!cam_strm_state && TaskValidate(cam_strm_task) && tS-t0<10.0)
    Sleep(10);
  if (cam_strm_state==1)
  {
    WinToTop(cam_strm_task);
    "WebCam stream on, %s%s.  CamStreamStop; closes it.\n",
	  CamPalStr(pal),LstSub(dither," nearest\0 dithered\0");
    return TRUE;
  }
  if (cam_strm_state==-1)
    "No webcam (UsbRep lists one as \"video\").\n";
  else
    "The camera did not start.\n";
  t0=tS;
  while (TaskValidate(cam_strm_task) && tS-t0<5.0)
    Sleep(10);
  return FALSE;
}

public Bool CamStream16(I64 w=320,I64 h=240,Bool dither=TRUE,I64 n=0,
	I64 type=-1)
{//CamStream in the 16 standard colors, dithered.
  return CamStream(w,h,dither,UVC_PAL_16,n,type);
}

public U0 CamStreamColors(I64 pal=UVC_PAL_16,Bool dither=TRUE)
{//Change a running CamStream's colors and dithering.
  cam_strm_pal=ClampI64(pal,0,UVC_PALS-1);
  cam_strm_dither=dither;
}

public U0 CamRep(I64 n=0)
{//Camera n's formats, frame sizes and frame rates.
  CUvc *c=UvcOpen(n);
  if (!c)
  {
    "No webcam.\n";
    return;
  }
  UvcRep(c);
  UvcClose(c);
}
