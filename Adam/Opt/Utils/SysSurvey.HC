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

I64 AskQuestion(U8 *q)
{
  I64 def=q[StrLen(q)+1];
  "%s ",q;
  return YNorU(def);
}

#define NUM_INS_SURVEY_QUESTIONS 3

static U8 *ins_questions[NUM_INS_SURVEY_QUESTIONS]=
{
  "Did the automatic installer work\0u",
  "Did you manually partition and format the drive\0u",
  "Did you manually have to enter IO port numbers\0u",
};

#define NUM_STD_SURVEY_QUESTIONS 10

static U8 *std_questions[NUM_STD_SURVEY_QUESTIONS]=
{
  "Is AHCI mode supported in BIOS\0u",
  "Is Legacy/IDE mode supported in BIOS\0u",
  "Does PS/2 emulation of USB both keyboard and mouse work in TinkerOS\0u",
  "Does your system have a PS/2 mouse or combo port\0u",
  "Does your system have a serial port\0u",
  "Does your system have a parallel port\0u",
  "Can you install and run TinkerOS bare metal\0u",
  "Can you install and run TempleOS bare metal\0u",
  "Does PS/2 emulation of USB both keyboard and mouse work in TempleOS\0u",
  "Is this a custom built PC / motherboard you installed\0u",
};


U0 SetDefaultResp(U8 *q, I64 resp)
{
  q[StrLen(q)+1]=resp;
}


public U0 RunSysSurvey()
{
  CDrv *dv;
  U8 *notes=NULL, *survey_file;
  Bool is_laptop,extra_notes,installed,sysrep,clonezilla;
  I64 have_kbd_ms,have_expresscard,have_dock,i,resp[NUM_STD_SURVEY_QUESTIONS], resp_ins[NUM_INS_SURVEY_QUESTIONS];

  DocClear;
  WinMax;
  DocMax;
  AutoComplete(0);

  if (blkdev.boot_drv_let != 'B' && blkdev.boot_drv_let !='T') installed=TRUE;

  if (AHCIMode) SetDefaultResp(std_questions[0],'y');
  else SetDefaultResp(std_questions[0],'n');

  if (!AHCIMode) SetDefaultResp(std_questions[1],'y');

  DefineLstLoad("ST_SYS_SURVEY","No\0Yes\0Unknown\0NA\0");
  for (i=0; i<NUM_STD_SURVEY_QUESTIONS; i++)
  {
    resp[i]=AskQuestion(std_questions[i]);
    if ((i==1||i==6) && resp[i]==0)
    {
      SetDefaultResp(std_questions[7],'n');
      SetDefaultResp(std_questions[8],'n');
    }
    if (i==2 && resp[i]==0)
      SetDefaultResp(std_questions[8],'n');
    "\n";
  }

  "Is your system a laptop ";
  is_laptop=YorN('n');
  "\n";

  if (is_laptop)
  {
    "Do the laptop keyboard and trackpad both work ";
    have_kbd_ms=YNorU('u');
    "\n";
    "Do you have a dock with useful ports (ps/2,serial,parallel) ";
    have_dock=YNorU('u');
    "\n";
    "Does your laptop have an expresscard slot ";
    have_expresscard=YNorU('u');
    "\n";
  }

  if (installed)
  {
    for (i=0; i<NUM_INS_SURVEY_QUESTIONS; i++)
    {
      resp_ins[i]=AskQuestion(ins_questions[i]);
      "\n";
    }
  }

  "\n";
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
  {
    notes=PopUpGetStr("Please enter extra notes, then press ESC\n");
  }

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


  "Laptop: %s\n\n",DefineSub(is_laptop,"ST_SYS_SURVEY");
  if (is_laptop)
    "Dock with useful ports available: %s\n\n",DefineSub(have_dock,"ST_SYS_SURVEY");
  if (is_laptop)
    "Expresscard slot available: %s\n\n",DefineSub(have_expresscard,"ST_SYS_SURVEY");
  if (is_laptop)
    "Do laptop keyboard and trackpad both work: %s\n\n",DefineSub(have_kbd_ms,"ST_SYS_SURVEY");

  for (i=0; i<NUM_STD_SURVEY_QUESTIONS; i++)
  {
    "%s: %s\n\n",std_questions[i],DefineSub(resp[i],"ST_SYS_SURVEY");
  }

  if (installed)
  {
    for (i=0; i<NUM_INS_SURVEY_QUESTIONS; i++)
    {
      "%s: %s\n\n",ins_questions[i],DefineSub(resp_ins[i],"ST_SYS_SURVEY");
    }
  }

  if (!AHCIMode)
    GetBootDrvPortInfo;

  if (extra_notes) "Extra notes: \n\n%s\n\n",notes;

  if (sysrep)
  {
    "Results from SysRepSurvey:\n\n";
    SysRepSurvey;
  }


  "\nHypervisor present: %d\n\n",IsHypervisorPresent;

  VidModes;
  "\n";

  if (DrvMounted('C')||DrvMounted('D')||DrvMounted('E')||DrvMounted('F'))
  {
    clonezilla=TRUE;
    for (i=0;i<4;i++)
    {
      if (DrvMounted('C'+i))
      {
        dv=Let2BlkDev('C'+i);
        if (!dv || dv->size != 0x256534442) clonezilla=FALSE;
      }
    }
  }
  else clonezilla=FALSE;

  if (clonezilla) "It appears clonezilla was used to partition the drive.\n";

  if (installed && blkdev.boot_drv_let != 'T')
    survey_file=MStrPrint("%C:/Home/Survey.DD",blkdev.boot_drv_let);
  else
  {
    DirMk("B:/Home");
    survey_file=MStrPrint("B:/Home/Survey.DD");
  }

  StrCpy(Fs->put_doc->filename.name,survey_file);
  DocWrite(Fs->put_doc);

  "\nWrote %s, please transfer to an internet connected PC\n",survey_file;
  "and rename it appropriately and make a github pull\n";
  "request to add your system! This will help others\n";
  "know what systems are TOS compatible!\n\n";

  if (SNAIL_COM>0)
  {
    "Attempt to automatically send survey to TOS server over serial port ";
    if (YorN('y'))
      Fput(survey_file,"Survey.DD");
  }

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
