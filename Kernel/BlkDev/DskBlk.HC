Bool BlkDevFnRw(CBlkDev *bd,U8 *buf,I64 blk,I64 cnt,Bool wr)
{//Driver read/write for the types >= BDT_OTHER. USB passes the bd.
  if (bd->type==BDT_USB)
    return fp_usb_blk_rw && (*fp_usb_blk_rw)(bd,buf,blk,cnt,wr);
  if (wr)
    return bd->write_func && (*bd->write_func)(buf,blk,cnt);
  return bd->read_func && (*bd->read_func)(buf,blk,cnt);
}

#define ZERO_BUF_SIZE	2048
U0 BlkWriteZero(CDrv *dv,I64 blk,I64 cnt)
{//Fill blk cnt with zeros in Drv.
  I64 n;
  U8 *z=CAlloc(ZERO_BUF_SIZE<<BLK_SIZE_BITS);
  Bool show_progress;
  if (cnt>ZERO_BUF_SIZE && dv->bd->type!=BDT_RAM)
  {
    progress1=0;
    progress1_max=cnt;
    StrCpy(progress1_desc,"Zeroing");
    show_progress=TRUE;
  }
  else
    show_progress=FALSE;
  while (cnt>0)
  {
    n=cnt;
    if (n>ZERO_BUF_SIZE)
      n=ZERO_BUF_SIZE;
    BlkWrite(dv,z,blk,n);
    blk+=n;
    cnt-=n;
    if (show_progress)
      progress1+=n;
    Yield;  //Prevent locking
  }
  Free(z);
  if (show_progress)
  {
    *progress1_desc=0;
    progress1=progress1_max=0;
  }
}

Bool BlkRead(CDrv *dv,U8 *buf, I64 blk, I64 cnt)
{//Read blk cnt from Drv to buf.
  Bool res=TRUE,unlock;
  CBlkDev *bd=dv->bd;
  if (cnt<=0) return TRUE;
  DrvChk(dv);
  try
  {
    unlock=DrvLock(dv);
    BlkDevInit(bd);
    if (dv->drv_offset && blk<dv->drv_offset ||
        blk+cnt>dv->drv_offset+dv->size)
      throw('Drv');
    if (bd->flags & BDF_READ_CACHE)
      RCache(dv,&buf,&blk,&cnt);
    if (cnt>0)
    {
      switch (bd->type)
      {
      case BDT_RAM:
        MemCpy(buf,bd->RAM_dsk+blk<<BLK_SIZE_BITS,cnt<<BLK_SIZE_BITS);
        break;
      case BDT_OTHER:
      case BDT_SERIAL:
      case BDT_SDHCI:
      case BDT_VIRTUAL:
      case BDT_USB:
        if (!BlkDevFnRw(bd, buf, blk, cnt, FALSE))
          res=FALSE;
        break;
      case BDT_ISO_FILE_READ:
        if (bd->RAM_dsk)
        {
          MemCpy(buf,bd->RAM_dsk+blk<<BLK_SIZE_BITS,cnt<<BLK_SIZE_BITS);
          break;
        }
      case BDT_ISO_FILE_WRITE:
        FBlkRead(bd->file_dsk,buf,blk,cnt);
        break;
      case BDT_AHCI_SATA:
        res = AHCIAtaRBlks(dv, buf, blk, cnt);
        break;
      case BDT_AHCI_SATAPI:
        res = AHCIAtapiRBlks(dv, buf, blk, cnt);
        break;
      case BDT_ATA:
      case BDT_ATAPI:
        res=ATARBlks(dv,buf,blk,cnt);
        break;
      }
      bd->last_time=tS;
      if (res && bd->flags & BDF_READ_CACHE)
        DskCacheAdd(dv,buf,blk,cnt);
    }
    if (unlock)
      DrvUnlock(dv);
  }
  catch
    if (unlock)
      DrvUnlock(dv);
  return res;
}

Bool BlkWrite(CDrv *dv,U8 *buf, I64 blk, I64 cnt)
{//Write blk cnt from buf to Drv.
  Bool res=TRUE,unlock;
  CBlkDev *bd=dv->bd;
  if (cnt<=0) return TRUE;
  DrvChk(dv);
  try
  {
    unlock=DrvLock(dv);
    BlkDevInit(bd);
    if (bd->flags&BDF_READ_ONLY && !(bd->flags & BDF_READ_ONLY_OVERRIDE))
      throw('BlkDev');
    if (dv->drv_offset && blk<dv->drv_offset ||
        blk+cnt>dv->drv_offset+dv->size)
      throw('Drv');
    if (cnt>0)
    {
      switch (bd->type)
      {
      case BDT_RAM:
        MemCpy(bd->RAM_dsk+blk<<BLK_SIZE_BITS,buf,cnt<<BLK_SIZE_BITS);
        break;
      case BDT_OTHER:
      case BDT_SERIAL:
      case BDT_SDHCI:
      case BDT_VIRTUAL:
      case BDT_USB:
        if (!BlkDevFnRw(bd, buf, blk, cnt, TRUE))
          res=FALSE;
        break;
      case BDT_ISO_FILE_READ:
        if (bd->RAM_dsk)
        {
          MemCpy(bd->RAM_dsk+blk<<BLK_SIZE_BITS,buf,cnt<<BLK_SIZE_BITS);
          break;
        }
      case BDT_ISO_FILE_WRITE:
        FBlkWrite(bd->file_dsk,buf,blk,cnt);
        break;
      case BDT_AHCI_SATA:
      case BDT_AHCI_SATAPI:
        res = AHCIAtaWBlks(dv, buf, blk, cnt);
        break;
      case BDT_ATA:
      case BDT_ATAPI:
        res=ATAWBlks(dv,buf,blk,cnt);
        break;
      }
      bd->last_time=tS;
      if (res && bd->flags & BDF_READ_CACHE)
        DskCacheAdd(dv,buf,blk,cnt);
    }
    if (unlock)
      DrvUnlock(dv);
  }
  catch
    if (unlock)
      DrvUnlock(dv);
  return res;
}

public U8 *BlkVolFSName(U8 *br)
{//"RedSea" or "FAT32" for a boot record, NULL if neither.
  CRedSeaBoot *br_rs=br;
  CFAT32Boot  *br_fat=br;
  if (br_rs->signature2!=0xAA55)
    return NULL;
  if (br_rs->signature==MBR_PT_REDSEA)
    return "RedSea";
  if (br_fat->ext_signature==0x29 && br_fat->bytes_per_sect==BLK_SIZE)
    return "FAT32";
  return NULL;
}

public I64 BlkVolSerial(U8 *br)
{//Unique id a $LK,"Fmt",A="MN:Fmt"$() put in a boot record. 0 if neither FS. Names a USB
//partition, which has no stable port to be named by.
  CRedSeaBoot *br_rs=br;
  CFAT32Boot  *br_fat=br;
  if (!BlkVolFSName(br))
    return 0;
  if (br_rs->signature==MBR_PT_REDSEA)
    return br_rs->unique_id;
  return br_fat->serial_num;
}

public U8 *BlkVolLabel(U8 *br,U8 *buf,I64 max)
{//Boot record's volume label, blank-trimmed, into buf. NULL if unprintable.
//$LK,"RedSeaFmt",A="MN:RedSeaFmt"$() writes it through a $LK,"CFAT32Boot",A="MN:CFAT32Boot"$ overlay, so both FS keep it at the
//same offset, ahead of the code $LK,"BootHDIns",A="MN:BootHDIns"$() rewrites.
  CFAT32Boot *br_fat=br;
  I64 i,j=0,n=sizeof(CFAT32Boot.vol_name);
  buf[0]=0;
  if (!BlkVolFSName(br))
    return NULL;
  if (n>max-1)
    n=max-1;
  for (i=0; i<n; i++)
  {
    if (!br_fat->vol_name[i])
      break;
    if (!(0x20<=br_fat->vol_name[i]<=0x7E))
      return NULL;
    buf[j++]=br_fat->vol_name[i];
  }
  buf[j]=0;
  while (j && buf[j-1]==' ')
    buf[--j]=0;
  if (!j)
    return NULL;
  return buf;
}

public I64 DrvVolSerial(U8 drv_let=0)
{//$LK,"BlkVolSerial",A="MN:BlkVolSerial"$() of a mounted drive's own boot record.  0 if it has none.
  I64 res=0;
  U8 *buf;
  CDrv *dv=Let2Drv(drv_let,FALSE);
  if (!dv || dv->dv_signature!=DRV_SIGNATURE_VAL)
    return 0;
  buf=CAlloc(BLK_SIZE);
  try
  {
    if (BlkRead(dv,buf,dv->drv_offset,1))
      res=BlkVolSerial(buf);
  }
  catch
    Fs->catch_except=TRUE;
  Free(buf);
  return res;
}
