#help_index "Seth"

I64 GetCPUSlice(I64 cpu_num=mp_cnt-1)
{
  // Make this work like python array
  // slices when we have lots of CPUs
  //        so CPU -1 = last core
  //           CPU -2 = second to last
  //           etc
  // When only two everything goes to 1

  if (mp_cnt==2) cpu_num=1;
  else cpu_num = cpu_num % mp_cnt;

  if (cpu_num<0) cpu_num+=mp_cnt;

  return cpu_num;
}

public U0 SethREPL(I64 cpu_num=mp_cnt-1, U8 *first_cmd=NULL, Bool exit_after_first=FALSE)
{//Get a REPL to execute commands on a Seth core.
  if (cpu_num>=mp_cnt || !cpu_num)
  {
    "Not a valid Seth core!\n";
    return;
  }
  cpu_num=GetCPUSlice(cpu_num);
  CTask *repl=Spawn(&SrvCmdLine,NULL,NULL,cpu_num);
  TaskWait(repl);
  repl->title_src=TTS_LOCKED_CONST;
  StrCpy(repl->task_title,"Seth REPL");
  U8 *line,*cwd,*pmpt,cpu_desc[5];
  cwd=MStrPrint("Cd(\"%s\");\n",DirCur);
  TaskExe(repl,Fs,cwd,0);
  TaskWait(repl);
  Free(cwd);
  cpu_desc[0]=0;
  if (cpu_num) CatPrint(cpu_desc,"Seth");
  else CatPrint(cpu_desc,"Adam");
  CJob *tmpc;
  while (1)
  {
    tmpc=TaskExe(repl,Fs,"DirCur;",0);
    TaskWait(repl);
    cwd=StrNew(repl->answer);
    tmpc=TaskExe(repl,Fs,"Free(Fs->answer);",0);
    TaskWait(repl);

    if (!first_cmd)
    {
      if (cwd)
      {
        pmpt=MStrPrint("%s %d %s> ",cpu_desc,cpu_num,cwd);
        Free(cwd);
      }
      else
        pmpt=MStrPrint("%s %d > ",cpu_desc,cpu_num);
      line=GetStr(pmpt);
      Free(pmpt);
      if (!line || StrLen(line)<=6 && (!StrNICmp(line,"exit",4) ||
        !StrNICmp(line,"quit",4)))
        break;
      "\nExecuting, waiting for results...";
      tmpc=TaskExe(repl,Fs,line,0);
    }
    else {
      tmpc=TaskExe(repl,Fs,first_cmd,0);
      first_cmd=NULL;
    }

    TaskWait(repl); // TODO detect core reset
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
        if (exit_after_first) break;
      }
    }
    else
    {
      "%s REPL task died!?\n",cpu_desc;
      break;
    }
  }
  if (TaskValidate(repl)) Kill(repl);
}

U0 SethExec(U8 *include_file, I64 cpu_num=mp_cnt-1)
{
  if (cpu_num>=mp_cnt || !cpu_num)
  {
    "Not a valid Seth core!\n";
    return;
  }
  U8 *first_cmd = MStrPrint("#include \"%s\"\n", include_file);
  SethREPL(cpu_num, first_cmd, TRUE);
  Free(first_cmd);
}

public CTask* SethFile(U8 *include_file, I64 cpu_num=mp_cnt-1)
{//Include file on a Seth core (like AdamFile)
  U8 *cwd,*first_cmd = MStrPrint("#include \"%s\"\n\nExit;\n", include_file);

  if (cpu_num>=mp_cnt)
  {
    "Not a valid Adam or Seth core!\n";
    return NULL;
  }

  // If we only have 1 CPU Adam does it
  if (mp_cnt==1)
  {
    AdamFile(include_file);
    return adam_task;
  }

  cpu_num=GetCPUSlice(cpu_num);

  CTask *repl=Spawn(&SrvCmdLine,NULL,NULL,cpu_num);
  repl->title_src=TTS_LOCKED_CONST;
  cwd=MStrPrint("Cd(\"%s\");\n",DirCur);
  TaskExe(repl,Fs,cwd,0);
  TaskWait(repl);
  Free(cwd);
  StrCpy(repl->task_title,include_file);
  TaskExe(repl,Fs,first_cmd,0);
  return repl;
}
#help_index ""
