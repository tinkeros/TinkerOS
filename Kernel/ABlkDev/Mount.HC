#help_index "Install;File/Cmd Line (Typically);Cmd Line (Typically);"
public U0 Unmount(U8 drv_let=0)
{//Unmount drive(s).
  BlkDevDel(Let2BlkDev(drv_let));
}

public U8 MountFile(U8 *filename)
{//Mount ISO.C file.
  U8 *filename2=ExtDft(filename,"ISO.C"),*filename3=FileNameAbs(filename2);
  CDrv *dv=DrvMakeFreeSlot(DrvNextFreeLet('M')); //First $LK,"BDT_ISO_FILE_READ",A="MN:BDT_ISO_FILE_READ"$
  CBlkDev *bd=BlkDevNextFreeSlot(dv->drv_let,BDT_ISO_FILE_READ);
  bd->drv_offset=19<<2+(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE;
  bd->file_dsk_name=AStrNew(filename3);
  BlkDevAdd(bd,,TRUE,TRUE);
  Free(filename3);
  Free(filename2);
  return dv->drv_let;
}
