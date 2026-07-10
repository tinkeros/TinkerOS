public Bool SdMkPrt(I64 size_mb=256)
{//Write a fresh DOS(MBR) partition table w/ one FAT32 partition to the SD card.
  CMasterBoot *mbr;
  I64 start_sect=2048,size_sects=size_mb<<(20-BLK_SIZE_BITS); //1MiB-aligned start
  Bool res;
  if (!sdhci_drv || !fp_sdhci_blkdev_write)
  {
    "SdMkPrt: No SD card, call SdhciInit first!\n";
    return FALSE;
  }
  if (size_mb<=0 || start_sect+size_sects>sdhci_drv->sectors)
  {
    "SdMkPrt: SD card too small for a %dMB partition!\n",size_mb;
    return FALSE;
  }
  mbr=CAlloc(BLK_SIZE);
  mbr->signature=0xAA55;
  mbr->p[0].active    =0x80;
  mbr->p[0].type      =MBR_PT_FAT32a;
  mbr->p[0].start_head=0;
  mbr->p[0].start_cyl =0x101;
  mbr->p[0].end_head  =0xFE;
  mbr->p[0].end_cyl   =0xFFFF;
  mbr->p[0].offset    =start_sect;
  mbr->p[0].size      =size_sects;
  res=fp_sdhci_blkdev_write(mbr,0,1);
  Free(mbr);
  return res;
}

