CTask *net_log_task = NULL;
static Bool log_log=FALSE;
static Bool log_warn=FALSE;

U0 NetLogTask(I64)
{
}

U0 NetLogSave()
{
}

U0 NetLog(U8 *fmt,...)
{// Output text to NetLogTask as Log.
  U8 *buf;
  if (log_log)
  {
    buf = StrPrintJoin(NULL, fmt, argc, argv);
    AdamLog(net_log_task->put_doc, "%s\n", buf);
    Free(buf);
  }
}

U0 NetWarn(U8 *fmt,...)
{// Output text to NetLogTask as Warning.
  if (log_warn)
  {
    U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
    AdamLog("$$BG,BROWN$$$$WHITE$$%s$$BG$$$$FG$$\n", buf);
    Free(buf);
  }
}

U0 NetErr(U8 *fmt,...)
{// Output text to NetLogTask as Error.
  U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
  AdamErr("$$BG,RED$$$$WHITE$$%s$$BG$$$$FG$$\n", buf);
  Free(buf);
}

U0 NetDbg(U8 *fmt,...)
{// Output text to NetLogTask as Dbg.
  U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
  AdamErr("$$BG,YELLOW$$$$DKGRAY$$%s$$BG$$$$FG$$\n", buf);
  Free(buf);
}
