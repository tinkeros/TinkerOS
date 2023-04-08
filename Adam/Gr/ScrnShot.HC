// These functions are only meant to be used with the original 16 TempleOS colors

/*
 * I apologize in advance for %04d causing a 4 digit year
 * limitation. If you using this in a year > 9999 and time
 * travel has been invented, please come rescue me or at least
 * give me some winning lotto numbers.
 */

U0 ScrnShotClip(U8 *filename)
{// Captures a mouse seleted screen clip
  I64 x=0, y=0, x2=0, y2=0, msg_code, old_inhibit=Fs->win_inhibit;
  CDC *dc,*dc2,*dc3;
  ms.show=FALSE;
  Yield;
  Fs->win_inhibit=WIG_TASK_DFT;
  dc=DCScrnCapture;
  dc2=DCCopy(dc);
  ms.show=TRUE;
  LBts(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
  Yield;
  gr_alt_scrn=dc2;
  Yield;
  do
  {
    msg_code=GetMsg(&x,&y,1<<MSG_MS_L_UP+1<<MSG_MS_MOVE);
    Yield;
  }
  while (msg_code!=MSG_MS_L_UP);
  x=ms.pos.x;
  y=ms.pos.y;
  do
  {
    msg_code=GetMsg(&x2,&y2,1<<MSG_MS_L_DOWN+1<<MSG_MS_MOVE);
    x2=ms.pos.x;
    y2=ms.pos.y;
    GrBlot(dc2,0,0,dc);
    GrBorder(dc2,MinI64(x,x2),MinI64(y,y2),MaxI64(x,x2),MaxI64(y,y2));
    Yield;
  }
  while (msg_code!=MSG_MS_L_DOWN);
  dc3=DCExt(dc,MinI64(x,x2)+1,MinI64(y,y2)+1,MaxI64(x,x2)-1,MaxI64(y,y2)-1);
  LBts(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
  Yield;
  gr_alt_scrn=NULL;
  VGAFlush;
  LBtr(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
  GRWrite(filename,dc3,DCSF_COMPRESSED|DCSF_PALETTE_GET);
  Fs->win_inhibit=old_inhibit;
  DCDel(dc);
  DCDel(dc2);
  DCDel(dc3);
}

U0 ScrnShot(Bool no_mouse=TRUE,Bool clip=FALSE)
{// Captures GR screenshot or screen clip saved to Home/ScrnShot if possible, otherwise RAM drive B:/ScrnShot
  Bool prev_mouse=ms.show,old_silent=IsSilent;
  U8 *prefix,*filename,*dircur;
  Silent;
  dircur=DirCur;
  if (no_mouse) ms.show=FALSE;
  Yield;
  CDateStruct ds;
  Date2Struct(&ds,Now+local_time_offset);
  try
  {
    Cdd("~/ScrnShot",1);
    prefix=MStrPrint("~/ScrnShot");
  }
  catch
  {
    Cdd("B:/ScrnShot",1);
    prefix=MStrPrint("B:/ScrnShot");
    Fs->catch_except=TRUE;
  }
  filename=MStrPrint("%s/%04d%02d%02d%02d%02d%02d",prefix,ds.year,ds.mon,ds.day_of_mon,ds.hour,ds.min,ds.sec);
  try
  {
    if (clip)
    {
      ScrnShotClip(filename);
    }
    else
    {
      GRScrnCaptureWrite(filename);
    }
  }
  catch
  {
    // Nothing
    Fs->catch_except=TRUE;
  }
  Free(filename);
  Cd(dircur);
  Free(dircur);
  Silent(old_silent);
  if (no_mouse) ms.show=prev_mouse;
}

U0 GrView(U8 *filename)
{// Views GR file full screen, ESC to exit
  I64 x=0,y=0;
  CDC *dc,*dc2;
  CTask *tmp;
  dc=DCCopy(gr.dc);
  dc2=GRRead(filename);
  if (dc2)
  {
    if (gr.dc->width_internal==dc2->width_internal
        &&gr.dc->height==dc2->height)
    {
      LBts(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
      tmp=User("InUntilChar(CH_ESC,CH_SHIFT_ESC,CH_SPACE);Exit;\n");
      Yield;
      SetAltScrn(dc2);
      Yield;
      DeathWait(tmp);
      SetAltScrn;
      VGAFlush;
      LBtr(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
    }
    else
    {
      if (dc2->width<dc->width&&dc2->height<dc->height)
      {
        x=(dc->width-dc2->width)/2;
        y=(dc->height-dc2->height)/2;
      }
      DCFill(dc,WHITE);
      GrBlot(dc,x,y,dc2);
      LBts(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
      tmp=User("InUntilChar(CH_ESC,CH_SHIFT_ESC,CH_SPACE);Exit;\n");
      Yield;
      SetAltScrn(dc);
      Yield;
      DeathWait(tmp);
      SetAltScrn;
      VGAFlush;
      LBtr(&sys_semas[SEMA_REFRESH_IN_PROGRESS],0);
    }
  }
  else
  {
    "Could not load %s\n",filename;
  }
  DCDel(dc);
  DCDel(dc2);
}

