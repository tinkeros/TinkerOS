class InstallOptions
{
  Bool extras;
  U8 *res[4];
  I64 num;
};

class TempleOSCfg
{
  I64 gr_width,
      gr_height,
      fps,
      gfx_mode;
  Bool no_hpet,text_mode;
};

TempleOSCfg tos_orig={640,480,30,0x12,FALSE,FALSE};
TempleOSCfg tos_cfg[4]={
{640,480,30,0x12,FALSE,FALSE},
{640,480,30,0x12,FALSE,FALSE},
{640,480,30,0x12,FALSE,FALSE},
{640,480,30,0x12,FALSE,FALSE}
};

U0 InstallDrv(U8 drv_let,Bool extras=FALSE,Bool templeos=FALSE)
{
  U8 *st,*st2;
  I64 src_let;
  TempleOSCfg *drv_tos_cfg=&tos_cfg['C'-drv_let];
  Sleep(100);
  while (!DrvChk(blkdev.let_to_drv[drv_let - 'A'], FALSE))
    Sleep(5);
  if (drv_let == 'C')
    Sleep(1000);
  src_let=':';
  if (templeos) {
    if (!DrvMounted('M'))
      MountFile("::/Extras/TempleOS.ISO");
    src_let='M';
  }
  ExePrint("Copy(\"%C:/*.BIN.C\",\"%C:/\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/0000Boot\",\"%C:/0000Boot\");",src_let,drv_let);
  ExePrint("Copy(\"%C:/*.DD.Z\",\"%C:/\");",src_let,drv_let);
  ExePrint("Copy(\"%C:/*.HC.Z\",\"%C:/\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Adam\",\"%C:/Adam\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Apps\",\"%C:/Apps\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Doc\",\"%C:/Doc\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Demo\",\"%C:/Demo\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Downloads\",\"%C:/Downloads\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Compiler\",\"%C:/Compiler\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Kernel\",\"%C:/Kernel\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Misc\",\"%C:/Misc\");",src_let,drv_let);
  if (extras)
  {
    ExePrint("CopyTree(\"::/Extras\",\"%C:/Extras\");",drv_let);
  }
  ExePrint("DirMk(\"%C:/Tmp\");",drv_let);
  ExePrint("DirMk(\"%C:/Tmp/ScrnShots\");",drv_let);
  ExePrint("DirMk(\"%C:/Home\");",drv_let);
  st=MStrPrint("%C:/Home/DoDistro.HC.Z",drv_let);
  if (!FileFind(st)) {
    st2=MStrPrint("%C:/Misc/DoDistro.HC.Z",src_let);
    Copy(st2,st);
    Free(st2);
  }
  Free(st);
  st=MStrPrint("%C:/Home/MakeHome.HC.Z",drv_let);
  if (!FileFind(st)) {
    st2=MStrPrint("%C:/MakeHome.HC.Z",src_let);
    Copy(st2,st);
    Free(st2);
  }
  Free(st);
  if (drv_tos_cfg->no_hpet) {
    ExePrint("CopyTree(\"::/Misc/TempleOS/NoHPET\",\"%C:/Kernel\");",drv_let);
  }
  if (drv_tos_cfg->text_mode) {
    ExePrint("CopyTree(\"::/Misc/TempleOS/TextMode\",\"%C:/Kernel\");",drv_let);
  }
  if (drv_tos_cfg->fps!=tos_orig.fps) {
    st=MStrPrint("%C:/Kernel/KernelA.HH.Z",drv_let);
    "Patching file %s\n",st;
    st2=MStrPrint("#define WINMGR_FPS      (%d000.0/1001)\n",drv_tos_cfg->fps);
    DocAppendLine(st,st2);
    Free(st2);
    st2=MStrPrint("#define WINMGR_PERIOD   (1001/%d000.0)\n",drv_tos_cfg->fps);
    DocAppendLine(st,st2);
    Free(st2);
    Free(st);
  }
}

Bool VMPrtDsk(CTask *task,CATARep *ata_drv, I64 num)
{
  if (ata_drv)
  {
    if (num==1)
    {
      XTalkWait(task,"DskPrt(,1.0);\nC\np%d\nY",ata_drv->num);
    }
    else if (num==2)
    {
      XTalkWait(task,"DskPrt(,0.5,0.5);\nC\np%d\nY",ata_drv->num);
    }
    else if (num==3)
    {
      XTalkWait(task,"DskPrt(,0.32,0.32,0.32,-1.0);\nC\np%d\nY\n",ata_drv->num);
    }
    else if (num==4)
    {
      XTalkWait(task,"DskPrt(,0.25,0.25,0.25,0.25);\nC\np%d\nY",ata_drv->num);
    }
    return TRUE;
  }
  else
    return FALSE;
}

Bool VMPrtDskAHCI(CTask *task,I64 port, I64 num)
{
  if (num==1)
  {
    XTalkWait(task,"DskPrt(,1.0);\nC\n%d\nY",port);
  }
  else if (num==2)
  {
    XTalkWait(task,"DskPrt(,0.5,0.5);\nC\n%d\nY",port);
  }
  else if (num==3)
  {
    XTalkWait(task,"DskPrt(,0.32,0.32,0.32,-1.0);\nC\n%d\nY\n",port);
  }
  else if (num==4)
  {
    XTalkWait(task,"DskPrt(,0.25,0.25,0.25,0.25);\nC\n%d\nY",port);
  }
  return TRUE;
}

U0 VMInstallDrv(CTask *task,U8 drv_let,
                CATARep *ata_drv,CATARep *atapi_drv,U8 *res, Bool extras=FALSE)
{
  Bool templeos=FALSE;
  if (StrLen(res)<3)
    templeos=TRUE;
  InstallDrv(drv_let, extras, templeos);
  if (AHCIMode)
  {
    XTalkWait(task,"BootHDIns('%C');\n\nB\n0x20000\n",drv_let);
    if (ata_drv)
      XTalkWait(task,"C\n%d\n",ata_drv->num);
    if (atapi_drv)
      XTalkWait(task,"T");
    XTalkWait(task,"\n\n"); //Exit Drives,Dsk Cache
    if (res)
      XTalkWait(task,"%s",res); //Options
    XTalkWait(task,"\n"); //Exit Options
  }
  else
  {
    XTalkWait(task,"BootHDIns('%C');\n\nB\n0x20000\n",drv_let);
    if (ata_drv)
      XTalkWait(task,"C\np%d\n",ata_drv->num);
    if (atapi_drv)
      XTalkWait(task,"Tp%d\n",atapi_drv->num);
    XTalkWait(task,"\n\n"); //Exit Drives,Dsk Cache
    if (res)
      XTalkWait(task,"%s",res); //Options
    XTalkWait(task,"\n"); //Exit Options
  }
}

U0 DispResOptions()
{
  "Select graphics mode (TinkerOS):\n\n";
  "0: 640x480 (4:3)\n"
  "1: 800x600 (4:3)\n"
  "2: 1024x768 (4:3)*\n"
  "3: 640x480 via 768x480 (letterboxed)*\n"
  "4: 800x600 via 960x600 (letterboxed)*\n"
  "5: 1024x768 via 1280x768 (letterboxed)*\n"
  "6: 1024x768 via 1366x768 (letterboxed)*\n"
  "7: 640x340 via 1280x1024 (2/3 scaling)\n"
  "8: 640x360 via 1280x720 (2/2 scaling)\n"
  "9: 640x400 via 1280x800 (2/2 scaling)\n"
  "10: 1280x1024 (5:4)\n"
  "11: 1360x768 via 1366x768 (approx 16:9)\n"
  "12: 1280x720 (HD 720p)\n"
  "13: 1920x1080 (HD 1080p)\n"
  "14: 960x540 via 1920x1080 (2x scaling)\n"
  "15: 1920x1200\n"
  "16: 960x600 via 1920x1200 (2x scaling)\n"
  "17: Text mode 80x60 columns, no graphics\n";
  "18: Enter custom width and height\n";
if (!AHCIMode) {
  "19: TempleOS standard no patches\n";
  "20: TempleOS custom FPS, no HPET\n";
  "21: TempleOS text mode, no HPET\n\n";
}
else "\n";
}

U8* ResPrompt(U8 drive)
{
  I64 res,width,height;
  U8 *cfg=NULL, *pmpt;
  TempleOSCfg *drv_tos_cfg=&tos_cfg['C'-drive];
  pmpt=MStrPrint("Select graphics mode for drive %c: ",drive);
  if (AHCIMode)
	  res=GetI64(pmpt,0,0,18);
  else
	  res=GetI64(pmpt,0,0,21);
  Free(pmpt);
  if (res==20) {
    pmpt=MStrPrint("Enter target FPS (1-60): ");
    drv_tos_cfg->fps=GetI64(pmpt,30,1,60);
    Free(pmpt);
    drv_tos_cfg->no_hpet=TRUE;
  }
  if (res==21) {
    drv_tos_cfg->text_mode=TRUE;
    drv_tos_cfg->no_hpet=TRUE;
  }
  if (res==0)
  {
    cfg=MStrPrint("Resolution\n640\n480\nN\n");
  }
  else if (res==1)
  {
    cfg=MStrPrint("Resolution\n800\n600\nN\n");
  }
  else if (res==2)
  {
    cfg=MStrPrint("Resolution\n1024\n768\nN\n");
  }
  else if (res==3)
  {
    cfg=MStrPrint("Resolution\n768\n480\nYY\n");
  }
  else if (res==4)
  {
    cfg=MStrPrint("Resolution\n960\n600\nYY\n");
  }
  else if (res==5)
  {
    cfg=MStrPrint("Resolution\n1280\n768\nYY\n");
  }
  else if (res==6)
  {
    cfg=MStrPrint("Resolution\n1366\n768\nY1024\n\n");
  }
  else if (res==7)
  {
    cfg=MStrPrint("Resolution\n1280\n1024\nYY2\n3\n\n");
  }
  else if (res==8)
  {
    cfg=MStrPrint("Resolution\n1280\n720\nYY2\n2\n\n");
  }
  else if (res==9)
  {
    cfg=MStrPrint("Resolution\n1280\n800\nYY2\n2\n\n");
  }
  else if (res==10)
  {
    cfg=MStrPrint("Resolution\n1280\n1024\nN\n");
  }
  else if (res==11)
  {
    cfg=MStrPrint("Resolution\n1366\n768\nY1360\n\n");
  }
  else if (res==12)
  {
    cfg=MStrPrint("Resolution\n1280\n720\nN\n");
  }
  else if (res==13)
  {
    cfg=MStrPrint("Resolution\n1920\n1080\nN\n");
  }
  else if (res==14)
  {
    cfg=MStrPrint("Resolution\n1920\n1080\nYY2\n2\n\n");
  }
  else if (res==15)
  {
    cfg=MStrPrint("Resolution\n1920\n1200\nN\n");
  }
  else if (res==16)
  {
    cfg=MStrPrint("Resolution\n1920\n1200\nYY2\n2\n\n");
  }
  else if (res==17)
  {
    cfg=MStrPrint("TextMode\n\n");
  }
  else if (res==18)
  {
    width=GetI64("Enter width (min=320, max=2560): ",640,320,2560);
    height=GetI64("Enter height (min=200, max=1600): ",480,200,1600);
    if (width % 8 == 0)
    {
      cfg=MStrPrint("Resolution\n%d\n%d\nN\n\n",width,height);
    }
    else
    {
      "\n\nNote the width entered was not a multiple of 8.\n";
      "It will be rounded down to %d and letterboxed\n"
      ,width-width%8;
      cfg=MStrPrint("Resolution\n%d\n%d\nY\n\n",width,height);
    }
  }
  else if (res>=19)
  {
    cfg=MStrPrint("\n");
  }
  return cfg;
}


U0 VMInstallSetup(InstallOptions *cfg)
{
  I64 i;
  "\nYou may automatically install up to 4\n";
  if (AHCIMode)
    "copies of TinkerOS on your drive.\n\n";
  else
    "copies of Temple/TinkerOS on your drive.\n\n";
  "Unless otherwise specified 2 is default\n\n";
  cfg->num=GetI64("How many would you like to install :",2,1,4);
  for (i=0; i<cfg->num; i++)
  {
    "\n";
    DispResOptions;
    cfg->res[i]=ResPrompt('C'+i);
  }
  "\nWould you like to also install extra supplemental ISO files in /Extras ";
  cfg->extras=YorN('n');
}

U0 VMInstall(Bool just_std_ide=TRUE, InstallOptions *cfg)
{
  CATARep *head=NULL,*ata_drv=NULL,*atapi_drv=NULL;
  CATARep hd,cd;
  CTask *task;
  I64			 i, atapi_port = -1, ata_port = -1, first_hd=-1;
  CAHCIPort	*port;
  "\nReady to do install, it's normal for this to freeze for a moment or two.\n";
  PressAKey;
  task=User;
  TaskWait(task);
  task->border_src=BDS_CONST;
  task->border_attr=LTGRAY<<4+DrvTextAttrGet(':')&15;
  task->text_attr  =LTGRAY<<4+BLUE;
  task->win_inhibit=WIG_TASK_DFT-WIF_SELF_BORDER;
  WinHorz(Fs->win_left,Fs->win_right,task);
  WinVert(Fs->win_top,(Fs->win_top+Fs->win_bottom)>>2-1,task);
  WinVert(task->win_bottom+3,Fs->win_bottom);
  WinToTop(Fs);
  if (AHCIMode)
  {
    SATARep(,&first_hd);
    ata_port=hd.num=first_hd;
    for (i = 0; i < AHCI_MAX_PORTS; i++)
    {
      if (Bt(&blkdev.ahci_hba->ports_implemented, i))
      {
        port = &blkdev.ahci_hba->ports[i];
        if (port->signature == AHCI_PxSIG_ATAPI)
        {
          atapi_port = i;
          cd.num=i;
          break;
        }
      }
    }
    if (ata_port<0||(blkdev.boot_drv_let!='B'&&atapi_port<0))
    {
      "Failed to detect necessary drives to do install in AHCI mode!\n";
      WinVert(task->win_top,Fs->win_bottom);
      Kill(task);
      return;
    }
    ata_drv=&hd;
    atapi_drv=&cd;
  }
  else
  {
    ATARep(FALSE,just_std_ide,&head);
    ATAIDDrvs(head,&ata_drv,&atapi_drv);
  }
  if ((AHCIMode && VMPrtDskAHCI(task,ata_drv->num,cfg->num)) || VMPrtDsk(task,ata_drv,cfg->num))
  {
    for (i=0; i<cfg->num; i++)
    {
      VMInstallDrv(task,'C'+i,ata_drv,atapi_drv,cfg->res[i],cfg->extras);
      Free(cfg->res[i]);
    }
    BootMHDIns('C');
  }
  if (!AHCIMode)
  {
    LinkedLstDel(head);
  }
  WinVert(task->win_top,Fs->win_bottom);
  Kill(task);
}

U0 RegularInstallWiz()
{
  I64 unit,drv_let;
  U8 *st,*base0,*base1,*res;
  CATARep *head=NULL,*tmpha;
  I64 ch,num_hints=0;
  CTask *task;
  CBlkDev *tmpbd;
  Bool probe, just_ide, extras=FALSE, templeos=FALSE;
  task=User;
  TaskWait(task);
  task->border_src=BDS_CONST;
  task->border_attr=LTGRAY<<4+DrvTextAttrGet(':')&15;
  task->text_attr  =LTGRAY<<4+BLUE;
  task->win_inhibit=WIG_TASK_DFT-WIF_SELF_BORDER;
  WinHorz(Fs->win_left,Fs->win_right,task);
  WinVert(Fs->win_top,(Fs->win_top+Fs->win_bottom)>>2-1,task);
  WinVert(task->win_bottom+3,Fs->win_bottom);
  WinToTop(Fs);
  if (!DrvMounted('C'))
  {
    XTalk(task,"Mount;\nC\n");
    "\nThis wizard can probe for I/O ports to\n"
    "try to locate your hard drive.  This\n"
    "may cause issues on some hardware. If\n"
    "you are installing in a VM or do not\n"
    "know them already choose yes.\n\n"
    "Probe for I/O port numbers ";
    probe=YorN('y');
    "\nDo a limited probe \n";
    just_ide=YorN('n');
    if (probe)
    {
      "\nIt's normal for this to freeze for a moment or two.\n";
      if (!just_ide) {
        "\nIf your system hangs reboot you can try rebooting and\n";
        "performing a limited probe.\n";
      }
      PressAKey;
      XTalk(task,"p");
      Yield;
      num_hints=ATARep(FALSE,just_ide,&head);
    }
    else
    {
      XTalk(task,"s");
    }
    "\nInclude '$$PURPLE$$0x$$FG$$' for hexidecimal numbers.\n\n";
    while (TRUE)
    {
      base0=GetStr("Hard Drive I/O Port Base0: ");
      if (0<Str2I64(base0)<=0xFFFF)
        break;
      Free(base0);
    }
    if (num_hints && 1<=Str2I64(base0)<=num_hints)
    {
      tmpha=ATARepFind(&head,Str2I64(base0));
      Free(base0);
      base0=MStrPrint("0x%X",tmpha->base0);
      base1=MStrPrint("0x%X",tmpha->base1);
      st	 =MStrPrint("0x%X",tmpha->unit);
      unit=Str2I64(st);
      Free(st);
    }
    else
    {
      while (TRUE)
      {
        base1=GetStr("Hard Drive I/O Port Base1: ");
        if (0<Str2I64(base1)<=0xFFFF)
          break;
        Free(base1);
      }
      do
      {
        st =GetStr("Unit--$$PURPLE$$0$$FG$$=Master or $$PURPLE$$1$$FG$$=Slave: ","0");
        unit=Str2I64(st);
        Free(st);
      }
      while (!(0<=unit<=1));
    }
    LinkedLstDel(head);
    XTalkWait(task,"%s\n%s\n%C\n",base0,base1,'0'+unit);
  }
  else
  {
    "It appears you already have drive(s)\n"
    "and parition(s) mounted, we'll skip\n"
    "probing and mounting.\n\n";
    base0=NULL;
    base1=NULL;
  }
  DrvRep;
  do
  {
    st=GetStr("\nDestination Partition Letter: ");
    if (*st)
      drv_let=Let2Let(*st);
    else
      drv_let=0;
    Free(st);
  }
  while (!('A'<=drv_let<='Z'));
  '\n';
  "$$RED$$Format %C Partition?$$FG$$\n"
  ,drv_let;
  if (YorN('y'))
  {
    '\n';
    do
    {
      "$$PURPLE$$1$$FG$$) Use FAT32\n"
      "$$PURPLE$$2$$FG$$) Use RedSea\n"
      "\nFile System Type: ";
      ch=GetChar;
      '\n';
    }
    while (!('1'<=ch<='2'));
    if (ch=='1')
      Fmt(drv_let,,FALSE,FSt_FAT32);
    else
      Fmt(drv_let,,FALSE,FSt_REDSEA);
  }
 
  "\nWould you like to also install extra supplemental ISO files in /Extras ";
  extras=YorN('n');
  DispResOptions;
  res=ResPrompt(drv_let);
  if (StrLen(res)<3)
    templeos=TRUE; 
  InstallDrv(drv_let,extras,templeos);
  if (!base0)
  {
    tmpbd=Let2BlkDev('C');
    base0=MStrPrint("0x%x",tmpbd->base0);
    base1=MStrPrint("0x%x",tmpbd->base1);
    unit=tmpbd->unit;
  }
  XTalkWait(task,"BootHDIns('%C');\n\nB\n0x20000\n"
            "C\ns%s\n%s\n%C\n\n%s\n", //Exit Drives,Dsk Cache,Options
            drv_let,base0,base1,'0'+unit,res);
  Free(base0);
  Free(base1);
  WinVert(task->win_top,Fs->win_bottom);
  Kill(task);
}

U0 RegularInstallWizAHCI()
{
  I64		 drv_let;
  U8		*st, *port_st, *res;
  I64		 ch;
  Bool           extras=FALSE;
  CTask	*task;
  task = User;
  TaskWait(task);
  task->border_src	= BDS_CONST;
  task->border_attr	= LTGRAY << 4 + DrvTextAttrGet(':') & 15;
  task->text_attr		= LTGRAY << 4 + BLUE;
  task->win_inhibit=WIG_TASK_DFT-WIF_SELF_BORDER;
  WinHorz(Fs->win_left, Fs->win_right, task);
  WinVert(Fs->win_top,  (Fs->win_top + Fs->win_bottom) >> 2 - 1, task);
  WinVert(task->win_bottom + 3, Fs->win_bottom);
  WinToTop(Fs);
  XTalk(task, "Mount;\nC\n");
  "\nSelect the port of the ATA drive to install on listed in the window above.\n";
  "Hard Drive Port: ";
  while (TRUE)
  {
    port_st = GetStr;
    if ((0 <= Str2I64(port_st) < AHCI_MAX_PORTS) &&
        ((&blkdev.ahci_hba->ports[Str2I64(port_st)])->signature == AHCI_PxSIG_ATA))
    {
      break;
    }
    Free(port_st);
  }
  XTalkWait(task, "%s\n\n", port_st);
  DrvRep;
  do
  {
    st = GetStr("\nDestination Partition Letter: ");
    if (*st)
      drv_let = Let2Let(*st);
    else
      drv_let = 0;
    Free(st);
  }
  while (!('A' <= drv_let <= 'Z'));
  '\n';
  "$$RED$$Format %C Partition?$$FG$$\n"
  , drv_let;
  if (YorN('y'))
  {
    '\n';
    do
    {
      "$$PURPLE$$1$$FG$$) Use FAT32\n"
      "$$PURPLE$$2$$FG$$) Use RedSea\n"
      "\nFile System Type: ";
      ch = GetChar;
      '\n';
    }
    while (!('1' <= ch <= '2'));
    if (ch == '1')
      Fmt(drv_let,, FALSE, FSt_FAT32);
    else
      Fmt(drv_let,, FALSE, FSt_REDSEA);
  }
  "\nWould you like to also install extra supplemental ISO files in /Extras ";
  extras=YorN('n');
  InstallDrv(drv_let,extras);
  DispResOptions;
  res=ResPrompt(drv_let);
  XTalkWait(task,"BootHDIns('%C');\n\nB\n0x20000\n"
            "C\n%s\n\n\n%s\n", //Exit Drives,Dsk Cache,Options
            drv_let,port_st,res);
  WinVert(task->win_top, Fs->win_bottom);
  Kill(task);
}


U0 DoInstructions()
{
  CTask *task;
  AutoComplete;
  task=Fs->next_task;
  while (task!=Fs)
  {
    if (task!=adam_task && task!=sys_winmgr_task && task!=ac.task)
    {
      XTalk(task,"Ed(\"::/Doc/Install.DD.Z\");\n");
      break;
    }
    task=task->next_task;
  }
}

Bool DoInstall(Bool pmt_reboot)
{
  I64 res=FALSE,vm_install;
  InstallOptions *cfg;
  if(DrvMounted('C'))
  {
    "\n\nIt appears drive C is already mounted.\n"
    "I will assume you have pre-mounted the\n"
    "partitions/drives you want to install to.\n"
    "\nContinue with manual install wizard ";
    if (YorN('y'))
      vm_install=FALSE;
    else
      return FALSE;
  }
  else
  {
    "\n\n";
    "$$BK, 1$$$$RED$$WARNING WARNING WARNING WARNING WARNING$$FG$$$$BK, 0$$\n\n"
    "Note this option will repartition your drive and overwrite any existing data!\n\n"
    "$$BK, 1$$$$RED$$WARNING WARNING WARNING WARNING WARNING$$FG$$$$BK, 0$$\n\n";
    "\nPerform automated partitioning and install ";
    vm_install=YorN('y');
  }
  DocBottom;
  if (vm_install)
  {
    install_just_ide=TRUE;
    cfg=CAlloc(sizeof(InstallOptions));
    VMInstallSetup(cfg);
    VMInstall(TRUE,cfg);
    res=DrvMounted('C');
    if (!res)
    {
      "Looks like standard IDE ports did not\n"
      "work for installing!\n\n"
      "I'll try again probing more ports to\n"
      "find a hard drive...\n\n";
      install_just_ide=FALSE;
      VMInstall(FALSE,cfg);
      res=DrvMounted('C');
      install_just_ide=TRUE;
      if (!res)
      {
        "\nIt looks like for whatever reason\n"
        "TinkerOS was not able to automatically\n"
        "install on your hard drive.  You still\n"
        "may be able to install TinkerOS if it\n"
        "can detect your hard drive when you\n"
        "manually supply I/O ports.  These can\n"
        "be found using lscpi in Linux or might\n"
        "even be found using the Mount command\n"
        "within TinkerOS once the drive has\n"
        "been paritioned.\n\n";
        "Please manually parition the drive\n"
        "with a msdos (not gpt) partition\n"
        "table and create a primary FAT32\n"
        "partition to install TinkerOS on.\n"
        "Then come back instead of choosing\n"
        "the automatic installer, manually\n"
        "install to the partition you created\n"
        "and if possible do not probe, but\n"
        "manually enter the I/O ports if you\n"
        "know them.\n\n";
      }
    }
    Free(cfg);
  }
  else
  {
    "\n\nThis wizard works if you have a partition ready."
    "You can partition the drive or BootHDIns() "
    "with more options if you do it by hand, not using this wizard.\n\n"
    "$$BK, 1$$$$RED$$WARNING WARNING WARNING WARNING WARNING$$FG$$$$BK, 0$$\n"
    "Continue at your own risk, may cause loss of data!\n"
    "$$BK, 1$$$$RED$$WARNING WARNING WARNING WARNING WARNING$$FG$$$$BK, 0$$\n\n"
    "Continue Install Wizard ";
    if (YorN('y'))
    {
      do
      {
        if (AHCIMode)
        {
          RegularInstallWizAHCI();
        }
        else
        {
          RegularInstallWiz();
        }
        res=TRUE;
        "\nWould you like to run the wizard again to install to another drive ";
      }
      while (YorN('n'));
      "$$RED$$Install Master Boot loader?$$FG$$";
      if (YorN('y'))
      {
        '\n';
        BootMHDIns('C');
      }
    }
    else
      pmt_reboot=FALSE;
  }
  if (pmt_reboot)
  {
    "Reboot Now ";
    if (YorN('n'))
      Reboot;
  }
  return res;
}

Bool OSInstall(Bool pmt_reboot=TRUE)
{
  DoInstructions;
  return DoInstall(pmt_reboot);
}

#if __CMD_LINE__
OSInstall(TRUE);
#endif
