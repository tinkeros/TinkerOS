Bool BlkDevLock(CBlkDev *bd)
{//Make this task have exclusive access to BlkDev.
  BlkDevChk(bd);
  while (bd->lock_fwding)
    bd=bd->lock_fwding; //If two blkdevs on same controller, use just one lock
  if (!Bt(&bd->locked_flags,BDlf_LOCKED) || bd->owning_task!=Fs)
  {
    while (LBts(&bd->locked_flags,BDlf_LOCKED))
      Yield;
    bd->owning_task=Fs;
    return TRUE;
  }
  else
    return FALSE;
}

Bool BlkDevUnlock(CBlkDev *bd,Bool rst=FALSE)
{//Release exclusive lock on access to BlkDev.
  BlkDevChk(bd);
  while (bd->lock_fwding)
    bd=bd->lock_fwding; //If two blkdevs on same controller, use just one lock
  if (Bt(&bd->locked_flags,BDlf_LOCKED) && bd->owning_task==Fs)
  {
    if (rst)
      bd->flags&=~(BDF_INITIALIZED|BDF_INIT_IN_PROGRESS);
    bd->owning_task=NULL;
    LBtr(&bd->locked_flags,BDlf_LOCKED);
    Yield; //Prevent deadlock
    return TRUE;
  }
  else
    return FALSE;
}

Bool BlkDevInit(CBlkDev *bd)
{
  CDirEntry de;
  U8 buf[STR_LEN];
  CDrv *dv=Let2Drv(bd->first_drv_let);
  Bool res=FALSE;
  if (!LBts(&bd->flags,BDf_INITIALIZED))
  {
    bd->flags|=BDF_INIT_IN_PROGRESS;
    switch (bd->type)
    {
    case BDT_OTHER:
      // Just call init if it already exists
      if (bd->init_func)
        (*bd->init_func)();
      break;
    case BDT_SDHCI:
      if (fp_sdhci_blkdev_init)
      {
        bd->max_reads=128;
        bd->max_writes=1;
        bd->init_func = fp_sdhci_blkdev_init;
        bd->deinit_func = fp_sdhci_blkdev_deinit;
        bd->read_func = fp_sdhci_blkdev_read;
        bd->write_func = fp_sdhci_blkdev_write;
        bd->max_func = fp_sdhci_blkdev_get_max;
        bd->base0 = 0x3f8; //TODO
        bd->base1 = 4; //TODO
        if (bd->init_func)
          (*bd->init_func)();
        bd->max_blk=(*bd->max_func)()-1;
        dv->size=bd->max_blk+1;
        dv->fs_type=FSt_FAT32;
        res=TRUE;
      }
      else
      {
        "Init function fp_sdhci_blkdev_init NULL?\n";
      }
      break;
    case BDT_SERIAL:
      if (fp_serial_blkdev_init)
      {
        bd->max_reads=128;
        bd->max_writes=1;
        bd->init_func = fp_serial_blkdev_init;
        bd->deinit_func = fp_serial_blkdev_deinit;
        bd->read_func = fp_serial_blkdev_read;
        bd->write_func = fp_serial_blkdev_write;
        bd->max_func = fp_serial_blkdev_get_max;
        bd->base0 = 0x3f8; //TODO
        bd->base1 = 4; //TODO
        if (bd->init_func)
          (*bd->init_func)();
        bd->max_blk=(*bd->max_func)()-1;
        dv->size=bd->max_blk+1;
        dv->fs_type=FSt_FAT32;
        res=TRUE;
      }
      else
      {
        "Init function fp_serial_blkdev_init NULL?\n";
      }
      break;
    case BDT_VIRTUAL:
      if (fp_virtual_blkdev_init)
      {
        bd->max_reads=128;
        bd->max_writes=1;
        bd->init_func = fp_virtual_blkdev_init;
        bd->deinit_func = fp_virtual_blkdev_deinit;
        bd->read_func = fp_virtual_blkdev_read;
        bd->write_func = fp_virtual_blkdev_write;
        bd->max_func = fp_virtual_blkdev_get_max;
        if (bd->init_func)
          (*bd->init_func)();
        bd->max_blk=(*bd->max_func)()-1;
        dv->size=bd->max_blk+1;
        dv->fs_type=FSt_FAT32;
        res=TRUE;
      }
      else
      {
        "Init function fp_virtual_blkdev_init NULL?\n";
      }
      break;
    case BDT_RAM:
      if (!bd->RAM_dsk)
      {
        bd->RAM_dsk=ACAlloc((bd->max_blk+1)<<BLK_SIZE_BITS);
        bd->max_blk=MSize(bd->RAM_dsk)>>BLK_SIZE_BITS-1;
      }
      dv->fs_type=FSt_REDSEA;
      dv->size=bd->max_blk+1-bd->drv_offset;
      if (RedSeaValidate(bd->first_drv_let))
        RedSeaInit(dv);
      else
        RedSeaFmt(bd->first_drv_let);
      res=TRUE;
      break;
    case BDT_ISO_FILE_READ:
      if (bd->RAM_dsk)
      {
        dv->fs_type=FSt_REDSEA;
        dv->size=bd->max_blk+1-bd->drv_offset;
        if (RedSeaValidate(bd->first_drv_let))
        {
          RedSeaInit(dv);
          res=TRUE;
        }
        else
          PrintErr("Not RedSea\n");
      }
      else if (FileFind(bd->file_dsk_name,&de,FUF_JUST_FILES))
      {
        bd->max_blk=de.size>>BLK_SIZE_BITS-1;
        try bd->file_dsk=FOpen(bd->file_dsk_name,"rc",bd->max_blk+1);
        catch
        {
          if (Fs->except_ch=='File')
            PrintErr("Not Contiguous.Move file to filename.ISO.C.\n");
          Fs->catch_except=TRUE;
        }
        if (bd->file_dsk)
        {
          dv->fs_type=FSt_REDSEA;
          dv->size=bd->max_blk+1-bd->drv_offset;
          if (RedSeaValidate(bd->first_drv_let))
          {
            RedSeaInit(dv);
            res=TRUE;
          }
          else
            PrintErr("Not RedSea\n");
        }
      }
      break;
    case BDT_ISO_FILE_WRITE:
      if (!bd->file_dsk_name)
      {
        StrPrint(buf,"%C:/Drv%C.ISO.C",
                 blkdev.boot_drv_let,bd->first_drv_let);
        bd->file_dsk_name=AStrNew(buf);
      }
      if (bd->max_blk<7)
        bd->max_blk=7;
      bd->file_dsk=FOpen(bd->file_dsk_name,"wc",bd->max_blk+1);
      dv->fs_type=FSt_REDSEA;
      dv->size=bd->max_blk+1-bd->drv_offset;
      RedSeaFmt(bd->first_drv_let);
      CallExtStr("RedSeaISO9660",bd->file_dsk_name,bd->first_drv_let);
      res=TRUE;
      break;
    case BDT_AHCI_SATA:
      bd->max_reads = 128;
      bd->max_writes = 1;
      res = AHCIAtaInit(bd);
      break;
    case BDT_AHCI_SATAPI:
      //0xFFFF*4 is too big for Terry's taste
      bd->max_reads = 0x800 * 4;
      //max of maybe a quarter of disk cache
      if (bd->max_reads > blkdev.cache_size / BLK_SIZE / 4)
        bd->max_reads = blkdev.cache_size / BLK_SIZE / 4 & ~3;
      if (bd->max_reads < 128)
        bd->max_reads = 128;
      bd->max_writes = 0xFFFF * 4;
      if (res = AHCIAtaInit(bd))
        dv->size = bd->max_blk + 1;
      break;
    case BDT_ATA:
      bd->max_reads=128;
      bd->max_writes=1;
      res=ATAInit(bd);
      break;
    case BDT_ATAPI:
//0xFFFF*4 is too big for my taste
      bd->max_reads=0x800*4;
//max of maybe a quarter of disk cache
      if (bd->max_reads>blkdev.cache_size/BLK_SIZE/4)
        bd->max_reads=blkdev.cache_size/BLK_SIZE/4 & ~3;
      if (bd->max_reads<128)
        bd->max_reads=128;
      bd->max_writes=0xFFFF*4;
      if (res=ATAInit(bd))
        dv->size=bd->max_blk+1;
      break;
    }
    if (res && bd->flags & BDF_READ_CACHE)
      DskCacheInvalidate(dv);
    bd->flags&=~BDF_INIT_IN_PROGRESS;
  }
  else
    res=TRUE;
  return res;
}

U0 BlkDevsRelease()
{//When task dies, release all owned BlkDevs.
  I64 i;
  CBlkDev *bd;
  for (i=0; i<BLKDEVS_NUM; i++)
  {
    bd=&blkdev.blkdevs[i];
    if (bd->owning_task==Fs && bd->bd_signature==BD_SIGNATURE_VAL)
      BlkDevUnlock(bd,TRUE);
  }
}

CBlkDev *BlkDevNextFreeSlot(U8 first_drv_let,I64 type)
{//Locate free slot for new BlkDev, like during $LK,"Mount",A="MN:Mount"$().
  I64 i=0;
  CBlkDev *res;
  if (Let2BlkDevType(first_drv_let)!=type)
    throw('BlkDev');
  do
  {
    res=&blkdev.blkdevs[i];
    if (res->bd_signature!=BD_SIGNATURE_VAL)
    {
      MemSet(res,0,sizeof(CBlkDev));
      res->first_drv_let=first_drv_let;
      res->type=type;
      res->flags=BDF_READ_CACHE;
      res->blk_size=BLK_SIZE;
      res->max_blk=0xEFFFFFFF;
      res->RAM_dsk=0;
      switch (type)
      {
      case BDT_RAM:
        res->flags&=~BDF_READ_CACHE;
        break;
      case BDT_ISO_FILE_READ:
        res->flags|=BDF_READ_ONLY;
        break;
      case BDT_ATAPI:
      case BDT_AHCI_SATAPI:
        res->flags|=BDF_REMOVABLE|BDF_READ_ONLY;
        res->blk_size=DVD_BLK_SIZE;
        break;
      }
      return res;
    }
  }
  while (++i<BLKDEVS_NUM);
  throw('BlkDev');
  return NULL; //never gets here
}

U0 BlkDevDel(CBlkDev *bd)
{//Delete BlkDev
  if ( (bd->type == BDT_OTHER) || (bd->type == BDT_SERIAL) || (bd->type == BDT_SDHCI) || (bd->type == BDT_VIRTUAL))
    if (bd->deinit_func)
      (*bd->deinit_func)();
  DrvBlkDevDel(bd);
  FClose(bd->file_dsk);
  if ( bd->type == BDT_ISO_FILE_READ
      && bd->file_dsk_name
      && bd->RAM_dsk) Free(bd->RAM_dsk);
  Free(bd->file_dsk_name);
  Free(bd->dev_id_record);
  MemSet(bd,0,sizeof(CBlkDev));
}

CBlkDev *BlkDevChk(CBlkDev *bd,Bool except=TRUE)
{//Check for valid BlkDev. Throw exception.
  if (!bd || bd->bd_signature!=BD_SIGNATURE_VAL ||
      !(BDT_NULL<bd->type<BDT_TYPES_NUM))
  {
    if (except)
      throw('BlkDev');
    else
      return NULL;
  }
  else
    return bd;
}

CBlkDev *Let2BlkDev(U8 drv_let=0,Bool except=TRUE)
{//Drv letter to BlkDev ptr.
  CDrv *dv;
  if (dv=Let2Drv(drv_let,except))
    return BlkDevChk(dv->bd,except);
  else
    return NULL;
}
