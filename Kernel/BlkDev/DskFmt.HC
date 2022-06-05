Bool DrvTypeSet(U8 drv_let,I64 type=FSt_REDSEA)
{//Very dangerous
  I64 i,j,ext_base,drv_num,offset,cur_type;
  CMasterBoot mbr;
  CBlkDev *bd;
  drv_let=Let2Let(drv_let);
  bd=Let2BlkDev(drv_let);
  drv_num=bd->first_drv_let-'A';
  switch (bd->type)
  {
  case BDT_ATA:
  case BDT_AHCI_SATA:
  case BDT_OTHER:
  case BDT_SERIAL:
  case BDT_VIRTUAL:
    offset=0;
    ext_base=INVALID_CLUS;
    while (TRUE)
    {
      if ( bd->type>=BDT_OTHER)
      {
        if (bd->read_func)
          (*bd->read_func)(&mbr, offset, 1);
      }
      else if (BDT_ATA==bd->type)
        ATAReadBlks(bd,&mbr,offset,1);
      else
        AHCIAtaBlksRead(bd, &mbr, offset, 1);
      j=-1;
      for (i=0; i<4; i++)
      {
        cur_type=mbr.p[i].type;
        if (cur_type)
        {
          if (cur_type==5 || cur_type==15)
            j=i;
          else
          {
            if (drv_num+'A'==drv_let)
            {
              switch (type)
              {
              case FSt_REDSEA:
                mbr.p[i].type=MBR_PT_REDSEA;
                break;
              case FSt_FAT32:
                mbr.p[i].type=MBR_PT_FAT32a;
                break;
              default:
                throw('Drv');
              }
              mbr.p[i].active=0x80;
              if ( bd->type>=BDT_OTHER)
              {
                if (bd->write_func)
                  (*bd->write_func)(&mbr, offset, 1);
              }
              else if (BDT_ATA==bd->type)
                ATAWriteBlks(bd,&mbr,offset,1);
              else
                AHCIAtaBlksWrite(bd, &mbr, offset, 1);
              return TRUE;
            }
            drv_num++;
          }
        }
      }
      if (j<0)
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
    break;
  }
}

U0 Fmt(I64 drv_let,Bool quick=TRUE,Bool confirm=TRUE,I64 type=FSt_FAT32)
{//Format hard drive or RAM drive.
//$BK,1$Warning:$BK,0$ Destroys all prev info.
  //quick=FALSE means fill entire drive with zeros.
  //Choose $LK,"FSt_FAT32",A="MN:FSt_FAT32"$ or $LK,"FSt_REDSEA",A="MN:FSt_REDSEA"$.
  //You don't format a CD/DVD with this.
  CDrv *dv=Let2Drv(drv_let);
  Bool old_silent=IsSilent;
  if (confirm && !AreYouSure)
    return;
  if (!dv)
  {
    PrintErr("Invalid Drive\n");
    return;
  }
  switch (type)
  {
  case FSt_FAT32:
    if (dv->bd->type==BDT_ATA || dv->bd->type==BDT_AHCI_SATA)
    {
      Silent;
      Drv(drv_let);
      Silent(old_silent);
      FAT32Fmt(drv_let,quick);
      DskCacheInvalidate(Let2Drv(drv_let));
      Drv(drv_let);
      break;
    }
    else
    {
      "Error: Formating only supported for block device types BDT_ATA and BDT_AHCI_SATA at this time.\n";
      return;
    }
  case FSt_REDSEA:
    "Using RedSea File System.\n"
    ;
    Silent;
    Drv(drv_let);
    Silent(old_silent);
    RedSeaFmt(drv_let,quick);
    DskCacheInvalidate(Let2Drv(drv_let));
    Drv(drv_let);
    break;
  case FSt_ISO9660:
    PrintErr("Not Writable\n");
    break;
  default:
    PrintErr("File System Not Supported\n");
  }
}
