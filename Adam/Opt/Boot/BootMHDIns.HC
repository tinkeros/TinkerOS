//See $LK,"Install Documentation",A="FI:::/Doc/Install.DD"$.
//Study my account examples: $LK,"Cfg Strs",A="FL:::/Demo/AcctExample/TOS/TOSCfg.HC,1"$, $LK,"Update Funs",A="FL:::/Demo/AcctExample/TOS/TOSDistro.HC,1"$

#ifndef BMHD_START
#include "BootMHD"
#include "BootMHD2"
#endif

#help_index "Install"

#define BOOT_DIR	"/0000Boot"
//Stage 2 of master boot loader
#define BOOT_DIR_BOOTMHD2_BIN_C	BOOT_DIR "/BootMHD2.BIN.C"
//Old/Other master boot record
#define BOOT_DIR_OLDMBR_BIN_C	BOOT_DIR "/OldMBR.BIN.C"
#define BOOT_DIR_OTHERMBR_BIN_C	BOOT_DIR "/OtherMBR.BIN.C"
#define BOOT_DIR_RESCUEMBR_BIN_C	BOOT_DIR "/RescueMBR.BIN.C"

U0 BootMHDOldRead(U8 src_drv,U8 dst_drv)
{
  //Reads MBR from disk drive containing src partition.
//Writes a single blk file to dst BOOT_DIR.
  CBlkDev *bd=Let2BlkDev(src_drv);
  CDrv *dv;
  CMasterBoot mbr;
  Drv(dst_drv);
  dv=Fs->cur_dv;
  if (dv->fs_type!=FSt_REDSEA && dv->fs_type!=FSt_FAT32)
    PrintErr("File System Not Supported\n");
  else
  {
//Bypass partition bounds-checking
    BlkDevLock(bd);
    if (AHCIMode)
        AHCIAtaBlksRead(bd, &mbr, 0, 1);
    else
      ATAReadBlks(bd,&mbr,0,1);
    BlkDevUnlock(bd);
    Drv(dst_drv);
    DirMk(BOOT_DIR);
    FileWrite(BOOT_DIR_OLDMBR_BIN_C,&mbr,BLK_SIZE);
  }
}

U0 BootMHDOldWrite(U8 src_drv,U8 dst_drv)
{
  //Reads OldMBR from src drive BOOT_DIR.
//writes it to the MBR of the drive with dst partition.
  CBlkDev *bd=Let2BlkDev(dst_drv);
  CMasterBoot *mbr;
  Drv(src_drv);
  if (mbr=FileRead(BOOT_DIR_OLDMBR_BIN_C))
  {
//Bypass partition bounds-checking
    BlkDevLock(bd);
    if (AHCIMode)
        AHCIAtaBlksWrite(bd, mbr, 0, 1);
        else
    ATAWriteBlks(bd,mbr,0,1);
    BlkDevUnlock(bd);
  }
  Free(mbr);
}

public U0 BootMHDZero(U8 dst_drv)
{// Zero MBRof disk
  //Set MBR of disk with dst partition to zero.
  //This is dangerous!!
  //The TempleOS partitioner doesn't play well
  //with other operating systems at this time and you need
  //to do this on a drive partitioned by TempleOS
  //if you wish to partition with another operating system.
  CBlkDev *bd=Let2BlkDev(dst_drv);
  CMasterBoot mbr;
  MemSet(&mbr,0,BLK_SIZE);
//Bypass partition bounds-checking
  BlkDevLock(bd);
    if (AHCIMode)
        AHCIAtaBlksWrite(bd, mbr, 0, 1);
        else
  ATAWriteBlks(bd,&mbr,0,1);
  BlkDevUnlock(bd);
}

public Bool BootMHDIns(U8 drv_let,U8 *drv_lst=NULL)
{//Install new master boot record
  //Create new MBR on the disk that has drv_let as a partition.
//Puts stage 2 in BOOT_DIR of drv_let.
  CBlkDev *bd,*bd1;
  CDrv *dv,*p1;
  CMasterBoot mbr;
  CDirEntry de;
  I64 i,j,h,w,size,*_q;
  U8 *menu_ptr,*ptr,*tmp,ch,buf[STR_LEN];
  Bool res=FALSE;
  try
  {
    if (drv_lst)
    {
      StrCpy(buf,drv_lst);
      StrUtil(buf,SUF_TO_UPPER);
    }
    else
    {
      j=0;
      for (i='A'; i<='Z'; i++)
        buf[j++]=i;
      buf[j++]=0;
    }
    Drv(drv_let);
    dv=Fs->cur_dv;
    if (dv->fs_type!=FSt_REDSEA && dv->fs_type!=FSt_FAT32)
      PrintErr("File System Not Supported\n");
    else
    {
      bd=dv->bd;
      if (!bd) bd=Let2BlkDev(drv_let);
      if (!FileFind(BOOT_DIR_OLDMBR_BIN_C,,FUF_JUST_FILES))
        BootMHDOldRead(drv_let,drv_let);
      _q=BMHD2_BLK_ARRAY;
      MemSet(_q,0,sizeof(I64)*8);
      menu_ptr=BMHD2_BOOT_MSG;
      StrPrint(menu_ptr,"\n\r\n\rTinkerOS Boot Loader\n\r\n\r");
      j=0;
      if (FileFind(BOOT_DIR_OLDMBR_BIN_C,&de,FUF_JUST_FILES))
      {
        Free(de.full_name);
        *_q++=Clus2Blk(dv,de.clus);
        CatPrint(menu_ptr,"%d. Old MBR\n\r",j++);
      }
      if (FileFind(BOOT_DIR_OTHERMBR_BIN_C,&de,FUF_JUST_FILES))
      {
        Free(de.full_name);
        *_q++=Clus2Blk(dv,de.clus);
        CatPrint(menu_ptr,"%d. Other MBR\n\r",j++);
      }
      ptr=buf;
      while (ch=*ptr++)
      {
        p1=Let2Drv(ch,FALSE);
        if (p1 && !p1->bd) p1->bd=Let2BlkDev(ch);
        if (p1 && (bd1=p1->bd) && bd1==bd)
        {
          *_q=p1->drv_offset;
          "Drive %C:%16X\n"
          ,Drv2Let(p1),*_q;
          if (IsFile(tmp=MStrPrint("%C:/Kernel/KCfg.HH",Drv2Let(p1)))) {
            w=ExePrint2("#include \"%C:/Kernel/KCfg.HH\"\n\nGR_WIDTH;\n",Drv2Let(p1));
            h=ExePrint2("#include \"%C:/Kernel/KCfg.HH\"\n\nGR_HEIGHT;\n",Drv2Let(p1));
            CatPrint(menu_ptr,"%d. Drive %C TinkerOS (%dx%d)\n\r",j++,Drv2Let(p1),w,h);
          }
          else
            CatPrint(menu_ptr,"%d. Drive %C TempleOS\n\r",j++,Drv2Let(p1),w,h);
          _q++;
        }
      }
      CatPrint(menu_ptr,"\n\rSelection:");
      size=BMHD2_END-BMHD2_START;
      FileWrite(BOOT_DIR_BOOTMHD2_BIN_C,BMHD2_START,size);
      if (!FileFind(BOOT_DIR_BOOTMHD2_BIN_C,&de,FUF_JUST_FILES))
        "No Boot Loader Image\n";
      else
      {
        Free(de.full_name);
        *BMHD_BLK_CNT(U16 *)=(size+BLK_SIZE-1)>>BLK_SIZE_BITS;
        *BMHD_DAP_BLK(I64 *)=Clus2Blk(dv,de.clus);
//Bypass partition bounds-checking
        BlkDevLock(bd);
        if (bd->type==BDT_SDHCI)
          fp_sdhci_blkdev_read(&mbr, 0, 1);
        else if (AHCIMode)
          AHCIAtaBlksRead(bd, &mbr, 0, 1);
        else
          ATAReadBlks(bd,&mbr,0,1);
        for (i=0; i<BMHD_END-BMHD_CODE; i++)
          mbr.code[i]=BMHD_CODE(U8 *)[i];
#assert sizeof(CMasterBoot.code)>=BMHD_END-BMHD_CODE
        for (; i<sizeof(CMasterBoot.code); i++)
          mbr.code[i]=0;
        if (!mbr.media_id)
          mbr.media_id=RandU32;
        mbr.zero=0;
        mbr.signature=0xAA55;
        if (bd->type==BDT_SDHCI)
          fp_sdhci_blkdev_write(&mbr, 0, 1);
        else if (AHCIMode)
          AHCIAtaBlksWrite(bd, &mbr, 0, 1);
        else
          ATAWriteBlks(bd,&mbr,0,1);
        BlkDevUnlock(bd);
        res=TRUE;
      }
    }
  }
  catch
    PutExcept;
  return res;
}
