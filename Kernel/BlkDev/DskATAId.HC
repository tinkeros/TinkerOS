Bool BootDVDProbe(CBlkDev *bd)
{
  U8 *img=CAlloc(DVD_BLK_SIZE);
  I64 i;
  Bool res=FALSE;
  if (ATAProbe(bd->base0,bd->base1,bd->unit)==BDT_ATAPI)
  {
    if (ATAPIStartStop(bd,tS+5.0,TRUE))
    {
      for (i=0; i<2; i++) //Retry
      {
        if (ATAPIReadBlks2(bd,tS+7.0,img,sys_boot_blk,1,FALSE))
        {
          if ((img+sys_boot_src.u16[1]<<BLK_SIZE_BITS)(CKernel *)
              ->compile_time==sys_compile_time)
          {
            "Port:%04X,%04XUnit:%02X",bd->base0,bd->base1,bd->unit;
            "ATAPI";
            "Started";
            "Found\n";
            return TRUE;
          }
        }
      }
    }
  }
  Free(img);
  return res;
}

Bool ProbeClass(I64 code,CBlkDev *bd)
{
  I64 i=-1,j,k,d1,d2;
  for (k=0; k<256; k++)
  {
    while (TRUE)
    {
      j=PCIClassFind(code+k,++i);
      if (j<0)
        break;
      "Subcode:0x%X Bus:0x%X Dev:0x%X Fun:0x%X\n"
      ,k,j.u8[2],j.u8[1],j.u8[0];
      d1=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x10);
      d2=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x14);
      if (d1&1 && d2&1)
      {
        if (bd->base0=d1&~7)
        {
          bd->unit=0;
          if (BootDVDProbe(bd))
            return TRUE;
          bd->unit=1;
          if (BootDVDProbe(bd))
            return TRUE;
        }
      }
      d1=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x18);
      d2=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x1C);
      if (d1&1 && d2&1)
      {
        if (bd->base0=d1&~7)
        {
          bd->unit=0;
          if (BootDVDProbe(bd))
            return TRUE;
          bd->unit=1;
          if (BootDVDProbe(bd))
            return TRUE;
        }
      }
    }
  }
}

Bool BootDVDProbeAll(CBlkDev *bd)
{
  I64 d1,d2;
  bd->base1=0;
  "Probing for IDE controllers...\n";
  ProbeClass(0x010100,bd);
  d1=0x1F0;
  d2=0x3F6;
  if (bd->base0=d1&~7)
  {
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x170;
  d2=0x376;
  if (bd->base0=d1&~7)
  {
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x170;
  d2=0x374;
  if (bd->base0=d1&~7)
  {
    bd->base1=d2;
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x1f0;
  d2=0x3f4;
  if (bd->base0=d1&~7)
  {
    bd->base1=d2;
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x2118;
  d2=0x2124;
  if (bd->base0=d1&~7)
  {
    bd->base1=d2;
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x2110;
  d2=0x2120;
  if (bd->base0=d1&~7)
  {
    bd->base1=d2;
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x5118;
  d2=0x5124;
  if (bd->base0=d1&~7)
  {
    bd->base1=d2;
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
  d1=0x5110;
  d2=0x5120;
  if (bd->base0=d1&~7)
  {
    bd->base1=d2;
    bd->unit=0;
    if (BootDVDProbe(bd))
      return TRUE;
    bd->unit=1;
    if (BootDVDProbe(bd))
      return TRUE;
  }
}

U0 ATARepEntry(I64 base0,I64 base1,I64 unit,U8 *msg,
               CATARep **_head,I64 *num_hints, I64 *_type=NULL)
{
  I64 type;
  base0&=-8;
  base1&=-4;
  CATARep *tmpha;
  if (type=ATAProbe(base0,base1,unit))
  {
    *num_hints+=1;
    "\n$$PURPLE$$$$BT+X,\"%d\",LM=\"%d\\n\"$$$$FG$$$$LM,4$$"
    ,*num_hints,*num_hints;
    if (type==BDT_ATA)
      "$$RED$$HardDrive$$LTBLUE$$ATA";
    else
      "$$RED$$CD/DVDDrive$$LTBLUE$$ATAPI";
    "%s$$FG$$\n"
    ,msg;
    if (base0==blkdev.ins_base0 && unit==blkdev.ins_unit)
      "$$PURPLE$$(Drive originally installed from.)$$FG$$\n";
    "Base0:0x%04XBase1:0x%04XUnit:%d$$LM,0$$\n"
    ,
    base0,base1,unit;
    if (_head)
    {
      tmpha=CAlloc(sizeof(CATARep));
      tmpha->next=*_head;
      *_head=tmpha;
      tmpha->num=*num_hints;
      tmpha->type=type;
      tmpha->base0=base0;
      tmpha->base1=base1;
      tmpha->unit=unit;
    }
    if (_type)
      *_type=type;
  }
}

Bool ATARepExitAllApplications()
{
  "\nWe're going to probe hardware.\n"
  "$$RED$$Exit all other applications.$$FG$$\n"
  "Press '$$PURPLE$$p$$FG$$' to probe or '$$PURPLE$$s$$FG$$' to skip.\n";
  if (ToUpper(GetChar(,FALSE))=='S')
    return TRUE;
  else
    return FALSE;
}

public I64 ATARep(Bool pmt=TRUE,Bool just_ide=FALSE,CATARep **_head=NULL)
{//Report possible ATA devices by probing.  Hard disks and CD/DVDs.
  I64 d1,d2,i,j,k,type,old_hints,hd_cnt=0,cnt=0,unlock_flags=0,num_hints=0;
#assert BLKDEVS_NUM<=64
  if (_head) *_head=NULL;
  if (pmt && ATARepExitAllApplications)
    return 0;
  for (i=0; i<BLKDEVS_NUM; i++)
    if (blkdev.blkdevs[i].bd_signature==BD_SIGNATURE_VAL)
      BEqu(&unlock_flags,i,
           BlkDevLock(&blkdev.blkdevs[i]));
  if (!just_ide)
    for (k=0; k<256; k++)
    {
      i=-1;
      while (TRUE)
      {
        j=PCIClassFind(0x010100+k,++i);
        if (j<0)
          break;
        "\nSubcode:0x%X Bus:0x%X Dev:0x%X Fun:0x%X\n"
        ,k,j.u8[2],j.u8[1],j.u8[0];
        cnt++;
        d1=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x10);
        d2=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x14);
        if (d1&1 && d2&1)
        {
          ATARepEntry(d1,d2,0,"Primary IDE",_head,&num_hints,&type);
          if (type==BDT_ATA && d1 & -8 != 0) hd_cnt++;
          ATARepEntry(d1,d2,1,"Primary IDE",_head,&num_hints,&type);
          if (type==BDT_ATA && d1 & -8 != 0) hd_cnt++;
        }
        d1=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x18);
        d2=PCIReadU32(j.u8[2],j.u8[1],j.u8[0],0x1C);
        if (d1&1 && d2&1)
        {
          ATARepEntry(d1,d2,0,"Secondary IDE",_head,&num_hints,&type);
          if (type==BDT_ATA && d1 & -8 != 0) hd_cnt++;
          ATARepEntry(d1,d2,1,"Secondary IDE",_head,&num_hints,&type);
          if (type==BDT_ATA && d1 & -8 != 0) hd_cnt++;
        }
      }
    }
  old_hints = num_hints;
  if (!cnt || !hd_cnt)
  {
    d1=0x1F0;
    d2=0x3F6;
    ATARepEntry(d1,d2,0,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    ATARepEntry(d1,d2,1,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    d1=0x170;
    d2=0x376;
    ATARepEntry(d1,d2,0,"Secondary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    ATARepEntry(d1,d2,1,"Secondary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    Sleep(2);
  }
  if (!just_ide && !hd_cnt)
  {
    // Some non-standard ports for some Legacy mode SATA
    // that do not show up from scans above
    d1=0x2118;
    d2=0x2124;
    ATARepEntry(d1,d2,0,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    ATARepEntry(d1,d2,1,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    d1=0x2110;
    d2=0x2120;
    ATARepEntry(d1,d2,0,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    ATARepEntry(d1,d2,1,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    d1=0x5118;
    d2=0x5124;
    ATARepEntry(d1,d2,0,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    ATARepEntry(d1,d2,1,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    d1=0x5110;
    d2=0x5120;
    ATARepEntry(d1,d2,0,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
    ATARepEntry(d1,d2,1,"Primary IDE",_head,&num_hints,&type);
    Sleep(2);
    if (type==BDT_ATA) hd_cnt++;
  }
  '\n\n';
  for (i=0; i<BLKDEVS_NUM; i++)
    if (Bt(&unlock_flags,i))
      BlkDevUnlock(&blkdev.blkdevs[i]);
  return num_hints;
}

CATARep *ATARepFind(CATARep *haystack_head,I64 needle_num)
{
  while (haystack_head)
  {
    if (haystack_head->num==needle_num)
      return haystack_head;
    haystack_head=haystack_head->next;
  }
  return NULL;
}

CATARep *ATAIDDrvs(CATARep *head,CATARep **_ata_drv,CATARep **_atapi_drv)
{//This is for when trying to sort-out main hard drives and CD/DVD drives.
  CATARep *res=NULL,*tmpha=head,*ata_drv=NULL,*atapi_drv=NULL;
  CBlkDev *bd;
  Bool was_silent=Silent,ins_found=FALSE;
  bd=Let2BlkDev(':',FALSE);
  Silent(was_silent);
  while (tmpha)
  {
    if (tmpha->base0)
    {
      if (!res && bd && bd->type==tmpha->type)
      {
        if (bd->type==BDT_ATAPI &&
            bd->base0==tmpha->base0 && bd->unit==tmpha->unit)
          res=atapi_drv=tmpha;
        else if (bd->type==BDT_ATA && bd->base0==tmpha->base0 &&
                 bd->base1==tmpha->base1 && bd->unit==tmpha->unit)
          res=ata_drv=tmpha;
      }
      if (!res || res->type!=tmpha->type)
      {
        if (tmpha->type==BDT_ATA)
        {
          if (!ata_drv || tmpha->unit<ata_drv->unit ||
              tmpha->unit==ata_drv->unit && tmpha->num<ata_drv->num)
            ata_drv=tmpha;
        }
        else if (tmpha->type==BDT_ATAPI)
        {
          if (!atapi_drv || !ins_found && (tmpha->unit<atapi_drv->unit ||
                                           tmpha->unit==atapi_drv->unit && tmpha->num<atapi_drv->num))
            atapi_drv=tmpha;
        }
      }
      if (tmpha->type==BDT_ATAPI && bd && bd->type==BDT_ATA &&
          tmpha->base0==blkdev.ins_base0 && tmpha->unit==blkdev.ins_unit)
      {
        if (!ins_found)
        {
          atapi_drv=tmpha;
          ins_found=TRUE;
        }
      }
    }
    tmpha=tmpha->next;
  }
  if (_ata_drv)   *_ata_drv  =ata_drv;
  if (_atapi_drv) *_atapi_drv=atapi_drv;
  return res;
}

CBlkDev *ATAMount(U8 first_drv_let,I64 type,I64 base0,I64 base1,I64 unit)
{
  CBlkDev *res;
  if (0<=first_drv_let-'A'<DRVS_NUM && (type==BDT_ATA || type==BDT_ATAPI) &&
      0<=unit<=1)
  {
    res=BlkDevNextFreeSlot(first_drv_let,type);
    res->unit=unit;
    res->base0=base0;
    res->base1=base1;
    if (BlkDevAdd(res,,FALSE,FALSE))
      return res;
  }
  return NULL;
}

CBlkDev *AHCIMount(U8 first_drv_let, I64 type, I64 port_num)
{
  CBlkDev *res;
  if (0 <= first_drv_let - 'A' < DRVS_NUM && (type == BDT_AHCI_SATA || type == BDT_AHCI_SATAPI) && 0 <= port_num <= AHCI_MAX_PORTS)
  {
    res = BlkDevNextFreeSlot(first_drv_let, type);
    res->port_num = port_num;
    res->ahci_port = &blkdev.ahci_hba->ports[port_num];
    res->ahci_port->cmd_list_base = NULL; // See $LK+PU,"AHCIAtaInit",A="FF:::/Kernel/BlkDev/DiskAHCI.CC,if (bd->ahci_port->cmd_list_base)"$ ...
    if (BlkDevAdd(res,, FALSE, FALSE))
      return res;
  }
  return NULL;
}



I64 MountAHCIAuto()
{//Try to mount hard drives and CD/DVD drives automatically. (Kernel.Config option).
//It uses 'C' and 'T' as first drive letters or whatever you set
//in config when compiling Kernel.BIN.
  CBlkDev     *bd     = Let2BlkDev(':', FALSE);
  I64          res    = 0, i, ata_port = -1, atapi_port = -1;
  CAHCIPort   *port;
  "MountAHCIAuto;\n";
  if (bd)
  {
    // if boot-drive blkdev exists, do a SATA port iteration to mount it first
    "( : BlkDev at 0x%0X )\n", bd;
    for (i = 0; i < AHCI_MAX_PORTS; i++)
      if (Bt(&blkdev.ahci_hba->ports_implemented, i))
      {
        port = &blkdev.ahci_hba->ports[i];
        if (bd->port_num == i)
        {
          if (ata_port == -1 && bd->type == BDT_AHCI_SATA && port->signature == AHCI_PxSIG_ATA)
          {
            "AHCIMount(%C, BDT_AHCI_SATA, %d);\n", blkdev.first_hd_drv_let, i;
            AHCIMount(blkdev.first_hd_drv_let, BDT_AHCI_SATA, i);
            ata_port = i;
            res++;
          }
          else if (atapi_port == -1 && bd->type == BDT_AHCI_SATAPI && port->signature == AHCI_PxSIG_ATAPI)
          {
            "AHCIMount(%C, BDT_AHCI_SATAPI, %d);\n", blkdev.first_dvd_drv_let, i;
            AHCIMount(blkdev.first_dvd_drv_let, BDT_AHCI_SATAPI, i);
            atapi_port = i;
            res++;
          }
        }
      }
  }
  // do a 2nd iteration to mount remaining drives
  // (we will end up trying to boot off whichever drive/partition ends up at chosen letter)
  for (i = 0; i < AHCI_MAX_PORTS; i++)
    if (i != ata_port && i != atapi_port && Bt(&blkdev.ahci_hba->ports_implemented, i))
    {
      port = &blkdev.ahci_hba->ports[i];
      if (port->signature == AHCI_PxSIG_ATA)
      {
        "AHCIMount(%C, BDT_AHCI_SATA, %d);\n", blkdev.first_hd_drv_let, i;
        if (AHCIMount(blkdev.first_hd_drv_let, BDT_AHCI_SATA, i))
          res++;
      }
      else if (port->signature == AHCI_PxSIG_ATAPI)
      {
        "AHCIMount(%C, BDT_AHCI_SATAPI, %d);\n", blkdev.first_dvd_drv_let, i;
        if (AHCIMount(blkdev.first_dvd_drv_let, BDT_AHCI_SATAPI, i))
          res++;
      }
    }
  "\n";
  blkdev.mount_ide_auto_cnt = res;
  return res;
}


I64 MountIDEAuto(Bool ATAPIOnly=FALSE)
{//Try to mount hard drive and CD/DVD, automatically. (Kernel.Cfg option).
//It uses 'C' and 'T' as first drive letters or whatever you set
  //in config when compiling Kernel.BIN.
  I64 res=0;
  CATARep *head=NULL,*ata_drv=NULL,*atapi_drv=NULL,*tmpha;
  if (AHCIMode)
  {
    MountAHCIAuto;
  }
  ATARep(FALSE,TRUE,&head);
  ATAIDDrvs(head,&ata_drv,&atapi_drv);
  if (ata_drv && !ATAPIOnly)
    if(ATAMount(blkdev.first_hd_drv_let,BDT_ATA,
                ata_drv->base0,ata_drv->base1,ata_drv->unit))
      res++;
  if (atapi_drv && ATAMount(blkdev.first_dvd_drv_let,BDT_ATAPI,
                            atapi_drv->base0,atapi_drv->base1,atapi_drv->unit))
    res++;
  tmpha=head;
  while (tmpha)
  {
    if (tmpha!=ata_drv && tmpha!=atapi_drv)
    {
      if (tmpha->type==BDT_ATA && !ATAPIOnly)
        if (ATAMount(blkdev.first_hd_drv_let,BDT_ATA,
                     tmpha->base0,tmpha->base1,tmpha->unit))
          res++;
        else if (tmpha->type==BDT_ATAPI &&
                 ATAMount(blkdev.first_dvd_drv_let,BDT_ATAPI,
                          tmpha->base0,tmpha->base1,tmpha->unit))
          res++;
    }
    tmpha=tmpha->next;
  }
  LinkedLstDel(head);
  blkdev.mount_ide_auto_cnt=res;
  return res;
}


