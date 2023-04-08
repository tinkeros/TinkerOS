U0 SethREPL(I64 cpu_num=mp_cnt-1)
{
  if (!cpu_num || cpu_num>=mp_cnt)
  {
    "Not a valid Seth core!\n";
    return;
  }
  CTask *repl=Spawn(&SrvCmdLine,NULL,NULL,cpu_num);
  TaskWait(repl);
  repl->title_src=TTS_LOCKED_CONST;
  StrCpy(repl->task_title,"Seth REPL");
  U8 *line,*cwd,*pmpt;
  CJob *tmpc;
  while (1)
  {
//TODO get DirCur result from Seth, not here
    //cwd=DirCur;
    tmpc=TaskExe(repl,Fs,"DirCur;",0);
    TaskWait(repl);
    cwd=StrNew(repl->answer);
    tmpc=TaskExe(repl,Fs,"Free(Fs->answer);",0);
    TaskWait(repl);
    if (cwd)
    {
      pmpt=MStrPrint("Seth %d %s> ",cpu_num,cwd);
      Free(cwd);
    }
    else
      pmpt=MStrPrint("Seth %d > ",cpu_num);
    line=GetStr(pmpt);
    Free(pmpt);
    if (!line || StrLen(line)<=6 && (!StrNICmp(line,"exit",4) || !StrNICmp(line,"quit",4)))
      break;
    "\nWaiting...";
    tmpc=TaskExe(repl,Fs,line,0);
    TaskWait(repl); // TODO how to detect core reset???
    while (TaskValidate(repl) && !JobResScan(tmpc))
    {
      Sleep(1);
      Yield;
    }
    EdLineDel(Fs->put_doc);
    "$FG$$$FG$$$$BG$$";
    if (TaskValidate(repl))
    {
      DocPrint(repl->put_doc,"\n");
      DocDump(repl->put_doc);
      DocClear(repl->put_doc);
      "$FG$$$FG$$$$BG$$";
      if (repl->new_answer)
      {
        if (repl->answer_type&~1!=RT_I0)
        {
          if (repl->answer_type==RT_F64)
            "%8.6fs ansf=%15.7g\n",repl->answer_time,repl->answer;
          else
            "%8.6fs ans=0x%08X=%d\n",repl->answer_time,repl->answer,repl->answer;
        }
        else
        {
          "%8.6fs\n",repl->answer_time;
          repl->answer=0;
        }
        repl->new_answer=FALSE;
      }
    }
    else
    {
      "Seth REPL task died!\n";
      break;
    }
  }
  if (TaskValidate(repl)) Kill(repl);
}
