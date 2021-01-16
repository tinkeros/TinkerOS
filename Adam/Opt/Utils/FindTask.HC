public CTask *TaskFindTitle(CTask *task,U8 *needle)
{
  CTask *task1, *res;
  task1=task->next_child_task;
  while (task1!=(&task->next_child_task)(U8 *)
         -offset(CTask.next_sibling_task))
  {
    if (StrMatch(needle,task1->task_title))
      if (task1!=Fs)
        return task1;
    if (res = TaskFindTitle(task1,needle))
      return res;
    task1=task1->next_sibling_task;
  }
  return NULL;
}

public CTask *TaskCoreFindTitle(I64 core, U8 *needle)
{// tasks on a single core.
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
  res=TaskFindTitle(c->seth_task,needle);
  POPFD
  return res;
}

public CTask *FindTaskByTitle(U8* needle)
{//Report current tasks on all cores.
  I64 i;
  CTask *res;
  for (i=0; i<mp_cnt; i++)
    if (res=TaskCoreFindTitle(i,needle))
      return res;
  return NULL;
}


