U0 BlkDevLockFwdingSet(CBlkDev *bd)
{//If two blkdevs on same controller, use just one lock
  CBlkDev *bd1;
  I64 i;
  switch (bd->type)
  {
  case BDT_RAM:
    break;
  case BDT_ISO_FILE_READ:
  case BDT_ISO_FILE_WRITE:
    bd->lock_fwding=Let2BlkDev(*bd->file_dsk_name);
    break;
  case BDT_ATA:
  case BDT_ATAPI:
  case BDT_AHCI_SATA:
  case BDT_AHCI_SATAPI:
    for (i=0; i<BLKDEVS_NUM; i++)
    {
      bd1=&blkdev.blkdevs[i];
      if (bd1->bd_signature==BD_SIGNATURE_VAL && bd!=bd1 &&
          (bd1->type==BDT_ATAPI || bd1->type==BDT_ATA || bd1->type==BDT_AHCI_SATAPI
              || bd1->type==BDT_AHCI_SATA) &&
          bd1->base0==bd->base0)
      {
        bd->lock_fwding=bd1;
        break;
      }
    }
    break;
  }
}

I64 BlkDevAdd(CBlkDev *bd,I64 prt_num=I64_MIN,
    Bool whole_drv,Bool make_free)
{//It will mount just one partition of prt_num>=0.
//When repartitioing whole drive, whole_drv=TRUE.
  I64 i,j,ext_base,offset,res=0,num=0;
  CDrv *dv;
  CRedSeaBoot br;
  CMasterBoot mbr;
  bd->bd_signature=BD_SIGNATURE_VAL;
  if (make_free)
    dv=DrvMakeFreeSlot(bd->first_drv_let);
  else
    dv=DrvMakeFreeSlot(DrvNextFreeLet(bd->first_drv_let));
  dv->bd=bd;
  dv->drv_offset=bd->drv_offset;
  dv->size=bd->max_blk+1-bd->drv_offset;
  switch (bd->type)
  {
  case BDT_RAM:
  case BDT_ISO_FILE_READ:
  case BDT_ISO_FILE_WRITE:
    dv->dv_signature=DRV_SIGNATURE_VAL;
    dv->prt_num=num;
    dv->fs_type=FSt_REDSEA;
//This is to force creation of a RAM
    //drive during boot, so it is probably
    //MAlloced to the same addr and can
    //be assumed to be already formatted.
    //If this line is removed, RAM Drives
    //will be alloced on a just-in-time
    //basis.
    if (BlkDevInit(bd))
      res++;
    else
      dv->dv_signature=0;
    break;
  case BDT_OTHER:
  case BDT_SERIAL:
  case BDT_VIRTUAL:
  case BDT_ATA:
  case BDT_AHCI_SATA:
    dv->dv_signature=DRV_SIGNATURE_VAL; //Temporarily validate
    if (!BlkDevInit(bd))
      dv->dv_signature=0; //Revoke validation
    else
    {
      dv->dv_signature=0; //Revoke validation
      if (whole_drv)
      {
        dv->dv_signature=DRV_SIGNATURE_VAL;
        dv->prt_num=num;
        res++;
        dv->fs_type=FSt_REDSEA;
        dv->size=bd->max_blk+1-bd->drv_offset;
//The following read is a test read.
        //if it hangs, the drive is not supported.
        if (bd->type < BDT_OTHER)
          ATAReadBlks(bd,&mbr,0,1);
        else if (bd->read_func)
          (*bd->read_func)(&mbr,0,1);
        break;
      }
      offset=0;
      ext_base=INVALID_CLUS;
      while (prt_num<0 || num<=prt_num)
      {
        if (bd->type < BDT_OTHER)
          ATAReadBlks(bd,&mbr,offset,1);
        else if (bd->read_func)
          (*bd->read_func)(&mbr,offset,1);
        if (mbr.signature!=0xAA55)
          break;
        j=-1;
        for (i=0; i<4 && (prt_num<0 || num<=prt_num); i++)
        {
          if (bd->type >= BDT_OTHER && prt_num > 0)
          {
            "\nOnly one parition/drive supported for serial/other/virtual devices!\n";
            break;
          }
          if (mbr.p[i].type)
          {
            if (make_free)
              dv=DrvMakeFreeSlot(bd->first_drv_let+res);
            else
              dv=DrvMakeFreeSlot(DrvNextFreeLet(bd->first_drv_let+res));
            dv->bd=bd;
            dv->drv_offset=mbr.p[i].offset+offset;
            dv->size	=mbr.p[i].size;
            switch (mbr.p[i].type)
            {
            case MBR_PT_REDSEA:
              dv->dv_signature=DRV_SIGNATURE_VAL;
              dv->prt_num=num;
              res++;
              dv->fs_type=FSt_REDSEA;
              RedSeaInit(dv);
              break;
            case MBR_PT_FAT32a:
            case MBR_PT_FAT32b:
            case MBR_PT_FAT32c:
            case MBR_PT_FAT32d:
            case MBR_PT_FAT32e:
            case MBR_PT_FAT32f:
              if (bd->type < BDT_OTHER)
                ATAReadBlks(bd,&br,dv->drv_offset,1);
              else if (bd->read_func)
                (*bd->read_func)(&br,dv->drv_offset,1);
              dv->dv_signature=DRV_SIGNATURE_VAL;
              dv->prt_num=num;
              res++;
              if (br.signature==MBR_PT_REDSEA)
              {
                dv->fs_type=FSt_REDSEA;
                RedSeaInit(dv);
              }
              else
              {
                dv->fs_type=FSt_FAT32;
                FAT32Init(dv);
              }
              break;
            case MBR_PT_NTFS:
              dv->dv_signature=DRV_SIGNATURE_VAL;
              dv->prt_num=num;
              res++;
              dv->fs_type=FSt_NTFS;
              break;
            case 5:
            case 15:
              j=i;
              break;
            default:
              dv->dv_signature=DRV_SIGNATURE_VAL;
              dv->prt_num=num;
              res++;
              dv->fs_type=FSt_UNKNOWN;
            }
            num++;
          }
        }
        if (Let2BlkDevType(bd->first_drv_let+res)!=bd->type)
          break;
        if (j<0)
          break;
        if (bd->type >= BDT_OTHER)
          break;
        if (!mbr.p[j].offset)
          break;
        if (ext_base==INVALID_CLUS)
        {
          offset=mbr.p[j].offset;
          ext_base=offset;
        }
        else
          offset=mbr.p[j].offset+ext_base;
      }
    }
    break;
  case BDT_ATAPI:
  case BDT_AHCI_SATAPI:
    dv->dv_signature=DRV_SIGNATURE_VAL;
    dv->prt_num=num;
    res++;
    dv->fs_type=FSt_ISO9660; //Start with this
    dv->size=0;
    break;
  }
  if (res)
    BlkDevLockFwdingSet(bd);
  else
    BlkDevDel(bd);
  return res;
}

Bool DrvEnable(U8 drv_let,Bool val)
{//Can unmount or remount, but not mount the first time.
  CDrv *dv;
  if (dv=Let2Drv(drv_let,FALSE))
    return !LBEqu(&dv->fs_type,FStf_DISABLE,!val);
  else
    return FALSE;
}

I64 SysGetI64()
{
  U8 st[STR_LEN];
  GetS(st,STR_LEN,FALSE);
  return Str2I64(st,16);
}

U0 SwitchDrvsToAHCI()
{// Switch drive letters to AHCI mode block device types.
  I64 i, type;
  for (i=0; i<26; i++)
  {
    type=Let2BlkDevType('A'+i);
    switch (type)
    {
    case BDT_ATA:
      SetDrvLetType('A'+i,BDT_AHCI_SATA);
      break;
    case BDT_ATAPI:
      SetDrvLetType('A'+i,BDT_AHCI_SATAPI);
      break;
    }
  }
}

U0 SwitchDrvsToIDE()
{// Switch drive letters to IDE mode block device types.
  I64 i, type;
  for (i=0; i<26; i++)
  {
    type=Let2BlkDevType('A'+i);
    switch (type)
    {
    case BDT_AHCI_SATA:
      SetDrvLetType('A'+i,BDT_ATA);
      break;
    case BDT_AHCI_SATAPI:
      SetDrvLetType('A'+i,BDT_ATAPI);
      break;
    }
  }
}

public Bool SwitchToAHCI()
{// Switch from Legacy to AHCI mode.
  AHCIInit;
  if (!blkdev.ahci_hba)
    return FALSE;
  if (blkdev.ahci_hba->version == 0xffffffff)
    return FALSE;
  AHCIMode=TRUE;
  SwitchDrvsToAHCI;
  return TRUE;
}

public Bool SwitchToIDE()
{// Switch from AHCI mode to IDE/Legacy.
  AHCIMode=FALSE;
  SwitchDrvsToIDE;
  return TRUE;
}

Bool GetBaseUnit(CBlkDev *bd)
{
  I64 ch;
  Bool probe, legacy, ahci;
#exe {
  if (kernel_cfg->opts[CFG_DONT_PROBE])
    StreamPrint("probe=FALSE;");
  else
    StreamPrint("probe=TRUE;");
};
blkdev.dvd_boot_is_good=FALSE;
if (!probe)
{
  "\nDon't worry.  This is not a product\n"
  "registration.	TempleOS just needs the\n"
  "I/O port numbers for the CD/DVD.\n"
  "\nRetry the ports above or check Windows\n"
  "system information under I/O ports for\n"
  "'IDE', 'ATA' or 'SATA'.\n"
  "In Linux, use 'lspci -v' for ports.\n"
  "\n\nEnter 4-digit hex I/O Port number.\n"
  "CD/DVD I/O Port Base0: 0x";
  bd->base0=SysGetI64;
  bd->base1=0;
  bd->unit =0;
  if (bd->base0)
  {
    "\nUnit (0 or 1): ";
    do ch=GetChar(,FALSE);
    while (!('0'<=ch<='1'));
    ''
    ch;
    bd->unit=ch-'0';
    blkdev.dvd_boot_is_good=BootDVDProbe(bd);
    return TRUE;
  }
}
else
{
  if (AHCIInit)
  {
    AHCIMode=TRUE;
    SwitchToAHCI;
    bd->type=BDT_AHCI_SATAPI;
    ahci=AHCIBootDVDProbeAll(bd);
  }
  if (!ahci)
  {
    "AHCI not detected, trying legacy mode...\n\n";
    AHCIMode=FALSE;
    SwitchToIDE;
    bd->type=BDT_ATAPI;
    legacy = BootDVDProbeAll(bd);
    if (!legacy)
    {
      "Failed to find any legacy or AHCI mode devices!\n\n";
      "Please Reboot!\n";
      while (TRUE)
      {
        Sleep(10000);
      }
    }
    else
    {
      "Found IDE device!\n";
      blkdev.dvd_boot_is_good=TRUE;
    }
  }
  else
  {
    "Found AHCI device!\n";
    blkdev.dvd_boot_is_good=TRUE;
  }
}
return blkdev.dvd_boot_is_good;
}

U0 MountAuto()
{
  Bool silent=IsSilent;
  if (AHCIMode)
  {
    try
    {
      MountAHCIAuto;
    }
    catch
      Fs->catch_except=TRUE;
  }
  else MountIDEAuto;
  Silent(silent);
}

U0 BlkDevsInitAll()
{
  CBlkDev *bd;
  I64 i;
  blkdev.ahci_hba=NULL;
  blkdev.blkdevs=CAlloc(sizeof(CBlkDev)*BLKDEVS_NUM);
  blkdev.drvs=CAlloc(sizeof(CDrv)*DRVS_NUM);
  for (i=0; i<DRVS_NUM; i++)
    blkdev.let_to_drv[i]=&blkdev.drvs[i];
#exe {
  if (kernel_cfg->opts[CFG_AHCI_MODE])
    StreamPrint("SwitchToAHCI;");
};
#exe {
if (kernel_cfg->opts[CFG_MOUNT_IDE_AUTO])
  StreamPrint("MountAuto;");
StreamPrint("#exe {Option(OPTf_WARN_PAREN,OFF);}");
StreamDoc(kernel_cfg->add_dev);
StreamPrint("#exe {Option(OPTf_WARN_PAREN,ON);}");
};
}
