#help_index "OtherTinkerOSFuncs"
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

#define NUM_STD_SURVEY_QUESTIONS 9

static U8 *std_questions[NUM_STD_SURVEY_QUESTIONS]=
{
  "Is AHCI mode supported in BIOS\0u",
  "Is Legacy/IDE mode supported in BIOS\0u",
  "Does PS/2 emulation of a USB keyboard work\0u",
  "Does PS/2 emulation of a USB mouse work\0u",
  "Does your system have a PS/2 mouse or combo port\0u",
  "Does your system have a serial port\0u",
  "Does your system have a parallel port\0u",
  "Can you install and run TempleOS bare metal\0u",
  "Can you install and run TinkerOS bare metal\0u",
};


U0 SetDefaultResp(U8 *q, I64 resp)
{
  q[StrLen(q)+1]=resp;
}


public U0 RunSysSurvey()
{
  U8 *notes=NULL, *survey_file;
  Bool is_laptop,extra_notes,installed,sysrep;
  I64 have_dock,i,resp[NUM_STD_SURVEY_QUESTIONS], resp_ins[NUM_INS_SURVEY_QUESTIONS];

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
    "\n";
  }

  "Is your system a laptop ";
  is_laptop=YorN('n');
  "\n";

  if (is_laptop)
  {
    "Do you have a dock with useful ports (ps/2,serial,parallel) ";
    have_dock=YNorU('u');
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
  if (is_laptop && have_dock)
    "Dock with useful ports available: %s\n\n",DefineSub(have_dock,"ST_SYS_SURVEY");

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

  if (extra_notes) "Extra notes: \n\n%s\n\n",notes;

  if (sysrep)
  {
    "Results from SysRepSurvey:\n\n";
    SysRepSurvey;
  }


  "\nHypervisor present: %d\n\n",IsHypervisorPresent;

  VidModes;
  "\n";

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
  "and make a github pull request to add your system! This\n";
  "will help others know what systems are TOS compatible!\n\n";

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
