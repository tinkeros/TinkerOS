#help_index "Install;File/Cmd Line (Typically);Cmd Line (Typically);"
public U0 Unmount(U8 drv_let=0)
{//Unmount drive(s).
  BlkDevDel(Let2BlkDev(drv_let));
}

public U8 MountFileC(U8 *filename)
{//Mount ISO.C file.
  U8 *filename2=ExtDft(filename,"ISO.C"),*filename3=FileNameAbs(filename2);
  CDrv *dv=DrvMakeFreeSlot(DrvNextFreeLet('M')); //First $LK,"BDT_ISO_FILE_READ",A="MN:BDT_ISO_FILE_READ"$
  CBlkDev *bd=BlkDevNextFreeSlot(dv->drv_let,BDT_ISO_FILE_READ);
  bd->drv_offset=19<<2+(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE;
  bd->file_dsk_name=AStrNew(filename3);
  bd->RAM_dsk=0;
  BlkDevAdd(bd,,TRUE,TRUE);
  Free(filename3);
  Free(filename2);
  return dv->drv_let;
}

public U8 MountFileB(U8 *buffer, I64 size)
{//Mount ISO.C file from buffer in memory.
  CDrv *dv=DrvMakeFreeSlot(DrvNextFreeLet('M')); //First $LK,"BDT_ISO_FILE_READ",A="MN:BDT_ISO_FILE_READ"$
  CBlkDev *bd=BlkDevNextFreeSlot(dv->drv_let,BDT_ISO_FILE_READ);
  bd->max_blk=size>>BLK_SIZE_BITS-1;
  bd->drv_offset=19<<2+(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE;
  bd->RAM_dsk=buffer;
  bd->file_dsk_name=0;
  BlkDevAdd(bd,,TRUE,TRUE);
  return dv->drv_let;
}

public U8 MountFileZ(U8 *filename)
{//Mount compressed ISO or non-contiguous file by expanding to buffer in memory.
  U8 *buf,*filename2=FileNameAbs(filename);
  I64 sz;
  buf=FileRead(filename2,&sz);
  if (!buf || !sz)
  {
    Free(filename2);
    return NULL;
  }
  CDrv *dv=DrvMakeFreeSlot(DrvNextFreeLet('M')); //First $LK,"BDT_ISO_FILE_READ",A="MN:BDT_ISO_FILE_READ"$
  CBlkDev *bd=BlkDevNextFreeSlot(dv->drv_let,BDT_ISO_FILE_READ);
  bd->file_dsk_name=AStrNew(filename2);
  bd->max_blk=sz>>BLK_SIZE_BITS-1;
  bd->drv_offset=19<<2+(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE;
  bd->RAM_dsk=buf;
  BlkDevAdd(bd,,TRUE,TRUE);
  Free(filename2);
  return dv->drv_let;
}

public U8 MountFile(U8 *filename)
{//Mount ISO/ISO.C/ISO.Z as appropriate
  U8 *filename2=ExtDft(filename,"ISO.C"),*filename3=FileNameAbs(filename2);

  if (IsDotC(filename3) && IsFile(filename3)) {
    Free(filename3);
    Free(filename2);
    return MountFileC(filename);
  }

  Free(filename3);
  Free(filename2);

  if (IsFile(filename)) {
    return MountFileZ(filename);
  }
  return NULL;
}
