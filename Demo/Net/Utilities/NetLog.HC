CTask *net_log_task = NULL;

static Bool log_warn=FALSE;

U0 NetLogTask(I64)
{
  while (TRUE)
  {
    Refresh;
  }
}

U0 NetLogSave()
{
  StrCpy(net_log_task->put_doc->filename.name, "::/Home/Net/Log.DD");
  DocWrite(net_log_task->put_doc);
}

U0 NetLogInit()
{
  net_log_task = Spawn(&SrvCmdLine, NULL, "Network Log");
  TaskWait(net_log_task);
  net_log_task->border_src  = BDS_CONST;
  net_log_task->border_attr = DKGRAY << 4 + LTGRAY;
  net_log_task->text_attr       = WHITE  << 4 + LTGRAY;
  DocClear(net_log_task->border_doc, TRUE);
  WinHorz(TEXT_COLS / 2 + 1, TEXT_COLS - 2, net_log_task);
  WinVert(1, TEXT_ROWS - 2, net_log_task);
  WinFocus(net_log_task);
  DocPrint(net_log_task->put_doc, "$$WW+H,1$$");
  //Bts(&net_log_task->win_inhibit, WIf_SELF_FOCUS);
  LBts(sys_ctrl_alt_flags,CTRL_ALT_TAB);
}

U0 NetLog(U8 *fmt,...)
{// Output text to NetLogTask as Log.
  U8 *buf;
  if (log_warn)
  {
    buf = StrPrintJoin(NULL, fmt, argc, argv);
    DocBottom(net_log_task->put_doc);
    DocPrint(net_log_task->put_doc, "%s\n", buf);
    Free(buf);
  }
}

U0 NetWarn(U8 *fmt,...)
{// Output text to NetLogTask as Warning.
  U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
  DocBottom(net_log_task->put_doc);
  DocPrint(net_log_task->put_doc, "$$BG,BROWN$$$$WHITE$$%s$$BG$$$$FG$$\n", buf);
  Free(buf);
}

U0 NetErr(U8 *fmt,...)
{// Output text to NetLogTask as Error.
  U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
  DocBottom(net_log_task->put_doc);
  DocPrint(net_log_task->put_doc, "$$BG,RED$$$$WHITE$$%s$$BG$$$$FG$$\n", buf);
  Free(buf);
}

U0 NetDbg(U8 *fmt,...)
{// Output text to NetLogTask as Dbg.
  U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
  DocBottom(net_log_task->put_doc);
  DocPrint(net_log_task->put_doc, "$$BG,YELLOW$$$$DKGRAY$$%s$$BG$$$$FG$$\n", buf);
  Free(buf);
}

NetLogInit;

