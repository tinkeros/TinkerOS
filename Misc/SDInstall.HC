// Copies the OS files onto SD card partitions.
// When booting from SD, the bootloader lives on a different
// drive, so unlike OSInstall.HC there is no need to ask about
// resolution or install a boot loader here -- this just copies
// the OS tree onto whichever of drive letters W, X, Y, Z (the
// SDHCI partitions) are mounted.

#define SD_DRV_WAIT_TIMEOUT_MS 30000

U0 InstallDrvSD(I64 drv_let)
{
  Bool ready=FALSE;
  U8 *st;
  I64 src_let,timeout=0;
  src_let=':';
  st=MStrPrint("%C:/Ready",drv_let);
  while (!ready && timeout<SD_DRV_WAIT_TIMEOUT_MS)
  {
    try
    {
      DirMk(st);
      Sleep(1);
      if (IsDir(st))
      {
        Sleep(1);
        DelTree(st);
        ready=TRUE;
      }
    }
    catch
    {
      Fs->catch_except=TRUE;
    }
    Sleep(100);
    timeout+=100;
  }
  Free(st);
  if (timeout>SD_DRV_WAIT_TIMEOUT_MS)
  {
    "Failed to write to drive %C, install cannot continue!\n",drv_let;
    return;
  }
  "Copying OS files to drive %C:...\n",drv_let;
  ExePrint("Copy(\"%C:/*.HC.Z\",\"%C:/\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Adam\",\"%C:/Adam\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Apps\",\"%C:/Apps\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Compiler\",\"%C:/Compiler\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Demo\",\"%C:/Demo\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Doc\",\"%C:/Doc\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Home\",\"%C:/Home\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Kernel\",\"%C:/Kernel\");",src_let,drv_let);
  ExePrint("CopyTree(\"%C:/Misc\",\"%C:/Misc\");",src_let,drv_let);
  ExePrint("DirMk(\"%C:/Tmp\");",drv_let);
  ExePrint("DirMk(\"%C:/Tmp/ScrnShots\");",drv_let);
  st=MStrPrint("%C:/Home/DoDistro.HC.Z",drv_let);
  if (!FileFind(st))
    ExePrint("Copy(\"%C:/Misc/DoDistro.HC.Z\",\"%C:/Home/DoDistro.HC.Z\");",src_let,drv_let);
  Free(st);
  st=MStrPrint("%C:/Home/MakeHome.HC.Z",drv_let);
  if (!FileFind(st))
    ExePrint("Copy(\"%C:/MakeHome.HC.Z\",\"%C:/Home/MakeHome.HC.Z\");",src_let,drv_let);
  Free(st);
  "Done copying OS files to drive %C:\n",drv_let;
}

Bool SDInstall()
{
  I64 i, drv_let;
  Bool found=FALSE;
  for (i=0;i<4;i++)
  {
    drv_let='W'+i;
    if (DrvMounted(drv_let))
    {
      InstallDrvSD(drv_let);
      found=TRUE;
    }
  }
  if (!found)
    "No SD partitions found mounted on W-Z!  Run MountSDHCIAuto first.\n";
  return found;
}

#if __CMD_LINE__
SDInstall();
#endif
