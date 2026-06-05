Bool ConnectSerial()
{
  if (!comm_ports[1].base) CommInit;
  if (SNAIL_COM<0) ProbeComm;
  if (SNAIL_COM<0)
  {
    "No TOS server found over serial to backup to!\n";
    return FALSE;
  }
  return TRUE;
}

Bool SerialBackup(U8 drv='C')
{// Backup drive to folder eg: C:\ -> folder C
  I64 my_cpu=Gs->num;
  U8 *tmp,dst[2];

  if (!ConnectSerial) return FALSE;
  "Running serial backup on CPU %d\n",my_cpu;
  Sleep(500);

  RouteIrq(3,my_cpu);
  RouteIrq(4,my_cpu);

  Free(tmp);
  tmp=MStrPrint("%C:/",drv);
  dst[0]=drv;
  dst[1]=0;
  Dsync(tmp,dst,1,1);
  Free(tmp);

  RouteIrq(3,0);
  RouteIrq(4,0);
  return TRUE;
}

U0 SethBackup(U8 drv='C')
{
  Sleep(1);
  Seth("SerialBackup(\'%C\');\n",drv);
}
