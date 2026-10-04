#help_index "File/Cmd Line (Typically);Cmd Line (Typically)"
public U8 *DBlk(I64 blk,Bool write=FALSE)
{//Dump disk block. Optionally, write.
//If you set write to TRUE, the block will
  //be written when you press <ESC>.
  //See $LK,"::/Demo/Dsk/DskRaw.HC"$.
  U8 *buf=MAlloc(BLK_SIZE);
  BlkRead(Fs->cur_dv,buf,blk,1);
  DocD(buf,BLK_SIZE);
  if (write)
  {
    "Edit and press <ESC> to write or <SHIFT-ESC>\n";
    if (View)
    {
      "Write\n";
      BlkWrite(Fs->cur_dv,buf,blk,1);
    }
  }
  return buf;
}

public U8 *DClus(I64 c,Bool write=FALSE,I64 num=0)
{//Dump disk clus. Optionally, write.
//If you set write to TRUE, the clus will
  //be written when you press <ESC>.
  //See $LK,"::/Demo/Dsk/DskRaw.HC"$.
  //Do $LK,"Dir",A="MN:Dir"$("*",TRUE); to get clus numbers of files.
  U8 *buf=MAlloc(Fs->cur_dv->spc<<BLK_SIZE_BITS);
  c=ClusNumNext(Fs->cur_dv,c,num);
  ClusRead(Fs->cur_dv,buf,c,1);
  "Clus:%X\n"
  ,c;
  DocD(buf,Fs->cur_dv->spc<<BLK_SIZE_BITS);
  if (write)
  {
    "Edit and press <ESC> to write or <SHIFT-ESC>\n";
    if (View)
    {
      "Write\n";
      ClusWrite(Fs->cur_dv,buf,c,1);
    }
  }
  return buf;
}

public U8 *Dump(U8 *filename,Bool write=FALSE)
{//Dump file. Optionally, write.
//If you set write to TRUE, the file will
  //be written when you press <ESC>.
  U8 *buf;
  I64 size;
  if (buf=FileRead(filename,&size))
  {
    DocD(buf,size);
    if (write)
    {
      "Edit and press <ESC> to write or <SHIFT-ESC>\n";
      if (View)
      {
        "Write\n";
        FileWrite(filename,buf,size);
      }
    }
  }
  return buf;
}

public Bool AtaMkPrt(U8 drv_let=0,I64 size_mb=0,I64 num_prts=1,Bool just_ide=FALSE)
{//Write a fresh DOS(MBR) partition table w/ up to 4 FAT32 partitions to a plain ATA/SATA hard drive.
  CBlkDev *bd;
  CMasterBoot *mbr;
  I64 i,start_sect=2048,size_sects,avail_sects; //1MiB-aligned start
  Bool res;
  if (drv_let && !Let2BlkDev(drv_let,FALSE))
    drv_let=0;
  if (!drv_let && !(drv_let=MountWholeDrvNoFmt(just_ide)) ||
      !(bd=Let2BlkDev(drv_let,FALSE)))
  {
    "AtaMkPrt: Failed to mount an ATA/SATA hard drive!\n";
    return FALSE;
  }
  if (bd->type!=BDT_ATA && bd->type!=BDT_AHCI_SATA)
  {
    "AtaMkPrt: Drive %C is not a plain ATA/SATA hard drive!\n",drv_let;
    return FALSE;
  }
  if (num_prts<1) num_prts=1;
  if (num_prts>4) num_prts=4;
  avail_sects=bd->max_blk+1-start_sect;
  if (size_mb<=0)
    size_mb=MinI64(2048,(avail_sects/num_prts)>>(20-BLK_SIZE_BITS));
  else if (size_mb<256)
    size_mb=256;
  size_sects=size_mb<<(20-BLK_SIZE_BITS);
  if (size_mb<=0 || start_sect+num_prts*size_sects>bd->max_blk+1)
  {
    "AtaMkPrt: Drive %C too small for %d x %dMB partition(s)!\n",drv_let,num_prts,size_mb;
    return FALSE;
  }
  mbr=CAlloc(BLK_SIZE);
  mbr->signature=0xAA55;
  for (i=0;i<num_prts;i++)
  {
    if (!i) mbr->p[i].active=0x80; //only the 1st partition is marked bootable
    mbr->p[i].type      =MBR_PT_FAT32a;
    mbr->p[i].start_head=0;
    mbr->p[i].start_cyl =0x101;
    mbr->p[i].end_head  =0xFE;
    mbr->p[i].end_cyl   =0xFFFF;
    mbr->p[i].offset    =start_sect+i*size_sects;
    mbr->p[i].size      =size_sects;
  }
  ATAWriteBlks(bd,mbr,0,1);
  bd->flags&=~(BDF_INITIALIZED | BDF_INIT_IN_PROGRESS);
  BlkDevAdd(bd,,FALSE,TRUE);
  for (i=bd->first_drv_let;i<bd->first_drv_let+num_prts;i++)
    Fmt(i,,FALSE);
  res=TRUE;
  Free(mbr);
  return res;
}
