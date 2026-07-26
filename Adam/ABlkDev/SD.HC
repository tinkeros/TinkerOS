public Bool SdMkPrt(I64 size_mb=256,I64 num_prts=1)
{//Write a fresh DOS(MBR) partition table w/ up to 4 FAT32 partitions to the SD card.
  CMasterBoot *mbr;
  I64 i,start_sect=2048,size_sects=size_mb<<(20-BLK_SIZE_BITS); //1MiB-aligned start
  Bool res;
  if (!sdhci_drv || !fp_sdhci_blkdev_write)
  {
    "SdMkPrt: No SD card, call SdhciInit first!\n";
    return FALSE;
  }
  if (num_prts<1) num_prts=1;
  if (num_prts>4) num_prts=4;
  if (size_mb<=0 || start_sect+num_prts*size_sects>sdhci_drv->sectors)
  {
    "SdMkPrt: SD card too small for %d x %dMB partition(s)!\n",num_prts,size_mb;
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
  res=fp_sdhci_blkdev_write(mbr,0,1);
  Free(mbr);
  return res;
}

