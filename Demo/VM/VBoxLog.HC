U0 VBLog(U8 *str)
{// Write to VB log
  while (*str)
  {
    PortNop;
    OutU8(0x504,*str++);
  }
}

U0 VBDumpAdam()
{// Dump error logging in Adam to VB log
  U8 *tmp=DocDumpToStr(adam_task->put_doc);
  VBLog(tmp);
  Free(tmp);
}
