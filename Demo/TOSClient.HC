I64 tests_run=0,tests_passed=0;

U0 TOSCheck(Bool cond, U8 *name)
{//Records and prints the pass/fail result of a single check
  tests_run++;
  if (cond)
  {
    tests_passed++;
    "$FG,2$PASS$FG$ %s\n",name;
  }
  else
    "$FG,4$FAIL$FG$ %s\n",name;
}

U0 TestConnection()
{//Checks that the client can find and connect to tos_server.py
  try
  {
    TOSCheck(InitTOSClient,"InitTOSClient");
    TOSCheck(TOSServerCheck,"TOSServerCheck");
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestConnection (exception)");
  }
}

U0 TestDirMks()
{//Creates a nested local directory tree and checks it exists
  try
  {
    DirMks("TOSClientTestTmp/DirMksCheck/Nested");
    TOSCheck(IsDir("TOSClientTestTmp/DirMksCheck/Nested"),"DirMks");
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestDirMks (exception)");
  }
}

U0 TestFileRoundTrip()
{//Uploads a file, downloads it back and checks the content matches
  I64 len1,len2;
  U8 *content="TOSClient unit test file contents\n";
  U8 *data1=NULL,*data2=NULL;
  try
  {
    FileWrite("TOSClientTestTmp/FileRoundTripIn.txt",content,StrLen(content));
    TOSCheck(Fput("TOSClientTestTmp/FileRoundTripIn.txt","unit_tests/FileRoundTrip.txt")>0,"Fput");
    TOSCheck(Fget("unit_tests/FileRoundTrip.txt","TOSClientTestTmp/FileRoundTripOut.txt")>0,"Fget");
    data1=FileRead("TOSClientTestTmp/FileRoundTripIn.txt",&len1);
    data2=FileRead("TOSClientTestTmp/FileRoundTripOut.txt",&len2);
    TOSCheck(data1 && data2 && len1==len2 && !MemCmp(data1,data2,len1),"Fput/Fget content match");
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestFileRoundTrip (exception)");
  }
  Free(data1);
  Free(data2);
}

U0 TestDirRoundTrip()
{//Uploads a small dir tree, downloads it back and checks the round trip matches
  I64 up_cnt,down_len,la,lb;
  U8 *a="dir round trip file A\n",*b="dir round trip file B\n";
  U8 *da=NULL,*db=NULL;
  try
  {
    DirMks("TOSClientTestTmp/DirRoundTripSrc/Sub");
    FileWrite("TOSClientTestTmp/DirRoundTripSrc/A.txt",a,StrLen(a));
    FileWrite("TOSClientTestTmp/DirRoundTripSrc/Sub/B.txt",b,StrLen(b));
    up_cnt=Dput("TOSClientTestTmp/DirRoundTripSrc","unit_tests/DirRoundTrip");
    TOSCheck(up_cnt==2,"Dput file count");
    TOSCheck(Hdir("unit_tests")>0,"Hdir");
    down_len=Dget("unit_tests/DirRoundTrip");
    TOSCheck(down_len>0,"Dget");
    da=FileRead("unit_tests/DirRoundTrip/A.txt",&la);
    db=FileRead("unit_tests/DirRoundTrip/Sub/B.txt",&lb);
    TOSCheck(da && la==StrLen(a) && !MemCmp(da,a,la),"Dget content A");
    TOSCheck(db && lb==StrLen(b) && !MemCmp(db,b,lb),"Dget content B");
    TOSCheck(Dsync("TOSClientTestTmp/DirRoundTripSrc","unit_tests/DirRoundTrip")==2,"Dsync unchanged files");
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestDirRoundTrip (exception)");
  }
  Free(da);
  Free(db);
}

U0 TestClipboardRoundTrip()
{//Round-trips a known string through the host clipboard
  U8 *orig,*readback;
  U8 *probe="TOSClient clipboard unit test value";
  orig=ClipGetStr;
  try
  {
    ClipPutStr(probe);
    readback=ClipGetStr;
    TOSCheck(readback && !StrCmp(readback,probe),"ClipPutStr/ClipGetStr round trip");
    Free(readback);
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestClipboardRoundTrip (exception)");
  }
  if (orig)
  {
    ClipPutStr(orig);
    Free(orig);
  }
}

U0 TestHostExec()
{//Runs a shell command on the host and checks its output
  U8 *marker="TOSClient_Unit_Test_OK",*cmd,*res=NULL;
  try
  {
    cmd=MStrPrint("echo %s",marker);
    res=HExecToStr(cmd);
    Free(cmd);
    TOSCheck(res && StrMatch(marker,res),"HExecToStr");
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestHostExec (exception)");
  }
  Free(res);
}

U0 TestHostOS()
{//Gets the host OS and, if it's Linux, confirms we can exec a command there
  U8 *os_name=NULL,*res=NULL;
  try
  {
    os_name=HGetOSStr;
    TOSCheck(os_name && StrLen(os_name)>0,"HGetOSStr");
    if (os_name && StrMatch("Linux",os_name))
    {
      res=HExecToStr("echo Linux");
      TOSCheck(res && StrMatch("Linux",res),"HExecToStr echo Linux on Linux host");
    }
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestHostOS (exception)");
  }
  Free(os_name);
  Free(res);
}

U0 TestURLFetch()
{//Fetches a URL raw and HTML-stripped through the host
  I64 raw_len;
  U8 *text=NULL;
  try
  {
    raw_len=URLGet("http://example.com","TOSClientTestTmp/URLGetOut.html");
    TOSCheck(raw_len>0,"URLGet");
    text=URLGetTextStr("http://example.com");
    TOSCheck(text && StrLen(text)>0,"URLGetTextStr");
  }
  catch
  {
    Fs->catch_except=TRUE;
    TOSCheck(FALSE,"TestURLFetch (exception)");
  }
  Free(text);
}

U0 TOSClientUnitTests()
{//Runs every TOSClient test against unit_tests on the server and prints a summary
  tests_run=0;
  tests_passed=0;
  DirMks("TOSClientTestTmp");
  TestConnection;
  TestDirMks;
  TestFileRoundTrip;
  TestDirRoundTrip;
  TestClipboardRoundTrip;
  TestHostExec;
  TestHostOS;
  TestURLFetch;
  try
  {
    Del("TOSClientTestTmp",,TRUE);
    Del("unit_tests",,TRUE);
  }
  catch
    Fs->catch_except=TRUE;
  "\n%d/%d tests passed.\n",tests_passed,tests_run;
}

TOSClientUnitTests;
