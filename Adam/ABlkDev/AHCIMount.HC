#help_index "PCI;Info;File/System;Devices"

public I64 SATARep(I64 bd_type=BDT_NULL, I64 *first_hdd=NULL)
{// Report ATA and ATAPI drives implemented by SATA controller.
  I64 i, j, i_max=0, num = 0, first_hd=-1;
  CAHCIPort	*port;
  CBlkDev	*temp_blkdev;
  U16	*st, *model, *serial;
  Bool show_atapi = FALSE, show_ata = FALSE;
  switch (bd_type)
  {
  case BDT_NULL:
    show_atapi = show_ata = TRUE;
    break;
  case BDT_AHCI_SATAPI:
    show_atapi = TRUE;
    break;
  case BDT_AHCI_SATA:
    show_ata = TRUE;
    break;
  }
  if (!IsRaw)
    "\n$$LTBLUE$$AHCI version %X.%1X%1X$$FG$$\n\n",
    blkdev.ahci_hba->version >> 16, (blkdev.ahci_hba->version & 0xFF00) >> 8,
        blkdev.ahci_hba->version & 0xFF;
  else
    "\nAHCI version %X.%1X%1X\n\n",
    blkdev.ahci_hba->version >> 16, (blkdev.ahci_hba->version & 0xFF00) >> 8,
        blkdev.ahci_hba->version & 0xFF;
  if (blkdev.ahci_hba)
  {
    "\n";
    for (i = 0; i < AHCI_MAX_PORTS; i++)
    {
      if (Bt(&blkdev.ahci_hba->ports_implemented, i))
      {
        port = &blkdev.ahci_hba->ports[i];
        if (port->signature == AHCI_PxSIG_ATAPI && show_atapi ||
            port->signature == AHCI_PxSIG_ATA	&& show_ata)
        {
          if (!IsRaw)
            "$$PURPLE$$ $$BT,\"%d\",LM=\"%d\n\"$$$$FG$$", i, i;
          else
            "[%d]", i;
          if (port->signature == AHCI_PxSIG_ATA)
          {
            if (!IsRaw)
              "$$LM,4$$$$RED$$Hard Drive   $$LTBLUE$$ATA$$FG$$\n";
            else
              "\tHard Drive   ATA\n";
          }
          else if (port->signature == AHCI_PxSIG_ATAPI)
          {
            if (!IsRaw)
              "$$LM,4$$$$RED$$CD/DVD Drive $$LTBLUE$$ATAPI$$FG$$\n";
            else
              "\tCD/DVD Drive ATAPI\n";
          }
          if (!IsRaw)
            "$$LM,0$$";
          '\n\t';
          temp_blkdev = CAlloc(sizeof(CBlkDev));
          if (port->signature == AHCI_PxSIG_ATAPI)
            temp_blkdev->first_drv_let = 'T';
          else // ATA
            temp_blkdev->first_drv_let = 'C';
          try
            AHCIPortInit(temp_blkdev, port, i);
          catch
          {
            Fs->catch_except = TRUE;
            "Error at SATA Port %d"
            , i;
          }
          "\n\t";
          if (temp_blkdev->dev_id_record)
          {
            st = CAlloc(40 + 1);
            for (j = 0; j < 20; j++)
              st[j] = EndianU16(temp_blkdev->dev_id_record[27 + j]);
            model = MStrUtil(st, SUF_REM_LEADING | SUF_REM_TRAILING);
            "Model:  %s\n\t"
            , model;
            Free(st);
            Free(model);
            st = CAlloc(20 + 1);
            for (j = 0; j < 10; j++)
              st[j] = EndianU16(temp_blkdev->dev_id_record[10 + j]);
            serial = MStrUtil(st, SUF_REM_LEADING | SUF_REM_TRAILING);
            "Serial: %s\n"
            , serial;
            Free(st);
            Free(serial);
            if (i>i_max)
            {
              i_max=i+1;
            }
            if (first_hd<0&&port->signature==AHCI_PxSIG_ATA)
              first_hd=i;
          }
          "\n";
          BlkDevDel(temp_blkdev);
          Free(temp_blkdev);
        }
        num++;
      }
    }
  }
  else
    "blkdev.ahci_hba is NULL !\n\n";
  if (first_hdd)
    *first_hdd=first_hd;
  return MaxI64(num,i_max);
}
