#help_index "Info;Task"
U0 TaskRepTask(CTask *task,I64 indent, Bool detailed=FALSE, Bool kill=FALSE)
{
  I64 **ptr;
  CTask *task1;
  U8 **rbp;
  if (task==Fs)
    rbp=GetRBP;
  else
    rbp=task->rbp;
  if (!kill)
  {
    if (IsRaw)
    {
      "%h*c%08X - %d - %s\n",indent,CH_SPACE,task,task->task_num,
      task->task_title;
      "%h*c%08X%04X:%04X:%08X\n"
      ,indent+2,CH_SPACE,TaskMemAlloced(task),
      task->task_flags,task->display_flags,task->win_inhibit;
    }
    else
    {
      "%h*c$$MA,T=\"%08X\",LM=\"Kill(0x%X);\n\",$$ $$BLACK$$#%d$$FG$$ "
      "$$TX,\"%$$Q...\",SCX=16$$\n",indent,CH_SPACE,task,task,task->task_num,
      task->task_title;
      "%h*c%08X%04X:%04X:%08X\n"
      ,indent+2,CH_SPACE,TaskMemAlloced(task),
      task->task_flags,task->display_flags,task->win_inhibit;
    }
    if (detailed)
    {
      while (ChkOnStk(rbp,task))
      {
        ptr=rbp+1;
        "%h*c%08X:%08tX:%P\n"
        ,indent+2,CH_SPACE,ptr,*ptr,*ptr;
        if (rbp>=*rbp)
          break;
        rbp=*rbp;
      }
    }
  }
  task1=task->next_child_task;
  while (task1!=(&task->next_child_task)(U8 *)
         -offset(CTask.next_sibling_task))
  {
    TaskRepTask(task1,indent+2,detailed,kill);
    task1=task1->next_sibling_task;
  }
  if (kill) Kill(task);
}

public U0 TaskCoreRep(I64 core, Bool detailed=FALSE, Bool kill=FALSE)
{//Report current tasks on a single core.
  CCPU *c;
  if (core>=mp_cnt)
  {
    "Core %d does not exist!\n", core;
    return;
  }
  PUSHFD
  CLI
  c=&cpu_structs[core];
  if (!kill)
  {
    if (IsRaw)
    {
      "CPU%02X",core;
    }
    else
    {
      "$$PURPLE$$CPU%02X$$FG$$",core;
    }
    if (detailed)
    {
      " Usage %3tf%% :\n",100.0*(1.0-c->idle_factor);
    }
    else
    {
      ":\n";
    }
  }
  TaskRepTask(c->seth_task,2,detailed, kill);
  POPFD
}

#help_index "Seth"
public U0 KillSeth(I64 core)
{//Used to kill all tasks on a core.
  TaskCoreRep(core, FALSE, TRUE);
}
#help_index "Info;Task"


public U0 TaskRep(Bool detailed=FALSE)
{//Report current tasks on all cores.
  I64 i;
  for (i=0; i<mp_cnt; i++)
    TaskCoreRep(i,detailed);
}

CTask *FindTaskRep(CTask *task, U8 *title, Bool inc_self=FALSE)
{
  CTask *task1, *res;

  if (!task) return NULL;
  if (!TaskValidate(task)) return NULL;

  task1=task->next_child_task;

  if (task1 && TaskValidate(task1) && task1->task_title)
  {
    if (!StrCmp(task1->task_title,title))
    {
      if (inc_self || task1!=Fs)
        return task1;
    }
  }
  while (task1!=(&task->next_child_task)(U8 *)
         -offset(CTask.next_sibling_task))
  {
    res=FindTaskRep(task1,title,inc_self);
    if (res)
      return res;
    task1=task1->next_sibling_task;
    if (task1 && TaskValidate(task1) && task1->task_title)
      if (!StrCmp(task1->task_title,title))
        if (inc_self || task1!=Fs)
          return task1;
  }
  return NULL;
}

public CTask* FindTaskCore(I64 core, U8 *title, Bool inc_self=FALSE)
{
  CCPU *c;
  CTask *res;
  if (core>=mp_cnt)
  {
    "Core %d does not exist!\n", core;
    return NULL;
  }
  PUSHFD
  CLI
  c=&cpu_structs[core];
  res=FindTaskRep(c->seth_task,title,inc_self);
  POPFD
  return res;
}

public CTask* FindTaskByTitle(U8* title, Bool inc_self=FALSE)
{//Report current tasks on all cores.
  I64 i;
  CTask *res;
  for (i=0; i<mp_cnt; i++)
  {
    res=FindTaskCore(i,title,inc_self);
    if (res)
      return res;
  }
  return NULL;
}
