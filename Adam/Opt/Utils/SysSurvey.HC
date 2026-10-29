#help_index "OtherTinkerOSFuncs"

public U0 GetBootDrvPortInfo()
{
  CDrv *dv;
  CBlkDev *bd;
  I64 boot_let=blkdev.boot_drv_let;
  if (DrvMounted(boot_let))
  if ('C'<=boot_let<'F')
  {
    dv=Let2Drv(boot_let);
    if (dv && dv->bd)
    {
      bd=dv->bd;
      if(bd->base0)
      {
        "Boot drive %C IO port info:\n\n",boot_let;
        "Base 0: 0x%04x\n",bd->base0;
        "Base 1: 0x%04x\n",bd->base1;
        "Unit  : %d\n\n",bd->unit;
      }
    }
  }
}

public I64 YNorU(I64 enter_default=0)
{//Wait for user to answer Y or N.
  I64 ch;
  if (ToLower(enter_default)=='y'
      || ToLower(enter_default)=='n'
      || ToLower(enter_default)=='u')
    "(y or n, default: %c)? ",ToLower(enter_default);
  else
    "(y,n or u)? ";
  while (TRUE)
  {
    ch=ToUpper(GetChar(,FALSE));
    if (enter_default && ch=='\n')
      ch=ToUpper(enter_default);
    if (ch=='Y')
    {
      "$$PT$$YES$$FG$$\n";
      return TRUE;
    }
    else if (ch=='N')
    {
      "$$PT$$NO$$FG$$\n";
      return FALSE;
    }
    else if (ch=='U')
    {
      "$$PT$$UNKNOWN$$FG$$\n";
      return 2;
    }
  }
}
#help_index ""

#define SVY_NO		0
#define SVY_YES		1
#define SVY_UNKNOWN	2

I64 SvyAsk(U8 *q,I64 enter_default)
{//Ask q, returning SVY_NO, SVY_YES or SVY_UNKNOWN.
  I64 res;
  "%s ",q;
  res=YNorU(enter_default);
  "\n";
  return res;
}

I64 SvyUsbCnt(I64 kind,I64 kind2=-1)
{//How many USB devices of kind (or kind2) are plugged in.
  I64 k,n=0,t;
  for (k=0; k<16; k++)
  {
    t=UsbDevKind(k);
    if (t>0 && (t==kind || t==kind2))
      n++;
  }
  return n;
}

Bool SvyUsbBoot()
{//TRUE if we booted off a USB drive (TinkerOS's own USB driver).
  CDrv *dv;
  I64 let=blkdev.boot_drv_let;
  if (USB_FIRST_DRV_LET<=let<=USB_LAST_DRV_LET)
    return TRUE;
  if (!DrvMounted(let)) return FALSE;
  dv=Let2Drv(let);
  if (!dv || !dv->bd) return FALSE;
  return dv->bd->type==BDT_USB;
}

public U0 RunSysSurvey()
{
  U8 *notes=NULL,*survey_file;
  Bool usb_boot,usb_works,sysrep,is_laptop;
  I64 usb_kbd,usb_ms,usb_cam,r_installed,def_installed='u',
      r_usb_kbd,r_usb_ms,r_ps2_kbd,r_ps2_ms,r_usb_cam=SVY_UNKNOWN,
      r_lt_kbd=SVY_UNKNOWN,r_lt_ms=SVY_UNKNOWN;

  DocClear;
  WinMax;
  DocMax;
  AutoComplete(0);
  DefineLstLoad("ST_SYS_SURVEY","No\0Yes\0Unknown\0NA\0");

  usb_boot=SvyUsbBoot;
  usb_kbd =SvyUsbCnt(USB_KIND_KBD);
  usb_ms  =SvyUsbCnt(USB_KIND_MOUSE,USB_KIND_TABLET);
  usb_cam =SvyUsbCnt(USB_KIND_VIDEO);

  //Booting off a USB drive proves the USB stack works.
  usb_works=usb_boot;

  "Detected: %d USB keyboard(s), %d USB mouse/pointer(s), %d USB webcam(s)\n",
    usb_kbd,usb_ms,usb_cam;
  if (usb_boot)
    "Booted from USB drive %C, so USB works.\n",blkdev.boot_drv_let;
  "\n";

  //A detected webcam says nothing about whether Apps/WebCam drives it, so
  //this is asked before anything else: answering unknown hands out the
  //directions and quits, with no other answers to lose.
  if (usb_cam)
  {
    r_usb_cam=SvyAsk("Does the USB webcam work in Apps/WebCam",'u');
    if (r_usb_cam==SVY_UNKNOWN)
    {
      "$$PT$$Enter this to try the webcam:$$FG$$\n\n";
      "  #include \"::/Apps/WebCam/WebCam\";WebCam;\n\n";
      "Space takes a picture, Esc quits, and\n";
      "::/Apps/WebCam/Help.DD has the rest.\n\n";
      "Then run SysSurvey again and answer the webcam\n";
      "question.\n\n";
      AutoComplete(1);
      return;
    }
  }

  "For all questions you may answer u for unknown.\n\n";

  //Booting a hard drive partition means it got installed there.
  if ('C'<=blkdev.boot_drv_let<='F')
    def_installed='y';
  r_installed=SvyAsk("Can you install and run TinkerOS bare metal",def_installed);

  "Is your system a laptop ";
  is_laptop=YorN('n');
  "\n";

  if (is_laptop)
  {
    r_lt_kbd=SvyAsk("Does the built-in laptop keyboard work in TinkerOS",'u');
    r_lt_ms=SvyAsk("Does the built-in laptop trackpad or mouse work in TinkerOS",'u');
  }

  if (usb_kbd)
  {
    r_usb_kbd=SvyAsk("Does the USB keyboard work in TinkerOS",'y');
    //You needed a working keyboard to get here, but with a USB keyboard
    //plugged in we cannot tell which one you typed on.
    r_ps2_kbd=SvyAsk("Does a PS/2 keyboard work in TinkerOS",'u');
  }
  else
  {
    r_usb_kbd=SVY_UNKNOWN;
    r_ps2_kbd=SVY_YES;
  }

  if (usb_ms)
    r_usb_ms=SvyAsk("Does the USB mouse work in TinkerOS",'y');
  else
    r_usb_ms=SVY_UNKNOWN;

  r_ps2_ms=SvyAsk("Does a PS/2 mouse or trackpad work in TinkerOS",'u');

  if (r_usb_kbd==SVY_YES || r_usb_ms==SVY_YES || r_usb_cam==SVY_YES)
    usb_works=TRUE;

  "You are able to automatically include important useful\n";
  "information on your hardware (serial numbers and other\n";
  "identifying personal information is excluded) and you\n";
  "can always review and delete anything from the output\n";
  "before sending it.\n\n";

  "Can I gather this hardware information to include ";
  sysrep=YorN('y');

  "\n";
  "Any extra notes you would like to share ";
  if (YorN('n'))
    notes=PopUpGetStr("Please enter extra notes, then press ESC\n");

  DocClear;

  "Survey and System Results:\n\n";

#ifdef SCREEN_SAVER_TIMEOUT
  "OS: TinkerOS V%5.3f\t%D %T\n\n",sys_os_version,sys_compile_time,sys_compile_time;
#else
  "OS: TempleOS V%5.3f\t%D %T\n\n",sys_os_version,sys_compile_time,sys_compile_time;
#endif

  "Current graphics mode: %d x %d (%d by %d framebuffer)\n\n",
    GR_WIDTH,GR_HEIGHT,FB_WIDTH,FB_HEIGHT;
  "Current disk mode: ";
  if (AHCIMode) "AHCI\n\n";
  else "IDE/Legacy\n\n";
  "Current boot drive: %C\n\n",blkdev.boot_drv_let;
  if (blkdev.boot_drv_let!='B')
    "Booted from USB: %s\n\n",DefineSub(usb_boot,"ST_SYS_SURVEY");
  else
    "Booted from USB: MemDisk to RAM disk\n\n";
  "USB keyboards: %d, USB mice/pointers: %d, USB webcams: %d\n\n",
    usb_kbd,usb_ms,usb_cam;

  if (usb_works) "USB works\n\n";

  "Can you install and run TinkerOS bare metal: %s\n\n",
    DefineSub(r_installed,"ST_SYS_SURVEY");
  "Laptop: %s\n\n",DefineSub(is_laptop,"ST_SYS_SURVEY");
  if (is_laptop)
  {
    "Does the built-in laptop keyboard work in TinkerOS: %s\n\n",
      DefineSub(r_lt_kbd,"ST_SYS_SURVEY");
    "Does the built-in laptop trackpad or mouse work in TinkerOS: %s\n\n",
      DefineSub(r_lt_ms,"ST_SYS_SURVEY");
  }
  "Does the USB keyboard work in TinkerOS: %s\n\n",
    DefineSub(r_usb_kbd,"ST_SYS_SURVEY");
  "Does the USB mouse work in TinkerOS: %s\n\n",
    DefineSub(r_usb_ms,"ST_SYS_SURVEY");
  "Does a PS/2 keyboard work in TinkerOS: %s\n\n",
    DefineSub(r_ps2_kbd,"ST_SYS_SURVEY");
  "Does a PS/2 mouse or trackpad work in TinkerOS: %s\n\n",
    DefineSub(r_ps2_ms,"ST_SYS_SURVEY");
  if (usb_cam)
    "Does the USB webcam work in Apps/WebCam: %s\n\n",
      DefineSub(r_usb_cam,"ST_SYS_SURVEY");

  if (!AHCIMode)
    GetBootDrvPortInfo;

  if (notes) "Extra notes: \n\n%s\n\n",notes;

  "USB devices:\n";
  UsbRep;
  "\n";

  if (sysrep)
  {
    "Results from SysRepSurvey:\n\n";
    SysRepSurvey;
    "\nHypervisor present: %d\n\n",IsHypervisorPresent;
    VidModes;
    "\n";
  }

  if (blkdev.boot_drv_let!='B' && blkdev.boot_drv_let!='T')
    survey_file=MStrPrint("%C:/Home/Survey.DD",blkdev.boot_drv_let);
  else
  {
    DirMk("B:/Home");
    survey_file=MStrPrint("B:/Home/Survey.DD");
  }

  StrCpy(Fs->put_doc->filename.name,survey_file);
  DocWrite(Fs->put_doc);

  "\nWrote %s, please copy it to a USB drive and transfer it\n",survey_file;
  "to an internet connected PC, rename it appropriately and\n";
  "make a github pull request to add your system! This will\n";
  "help others know what systems are TOS compatible!\n\n";

  Free(survey_file);
  Free(notes);
  AutoComplete(1);
}

#help_index "SysInfo"
public U0 SysSurvey()
{//Run system survey
  User("RunSysSurvey;\n");
}
#help_index ""
