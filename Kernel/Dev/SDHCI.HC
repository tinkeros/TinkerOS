// PCI SD Host Controller Interface (only works with a few models)
// Was targeting Lenovo Thinkpad T420/T430, but sadly found out PIO
// mode sucks, in fact the Linux driver sets a quirk that only
// allows DMA mode.  Seems to work slow, but does work, occasionally
// the controller needs to be reset which this code handles.
//
// Will my controller work?
//
// If the driver under linux with lspci says pci_sdhci, you might be in luck
// and can try adding its device and vendor codes. It might work?

#define VERBOSE_SDHCI 0
#define VERBOSE_SDHCI_FREQ 1

static I64 ok_count=0;
static I64 rst_count=0;
static I64 sd_max_xfr_blk_size=128;

public U0 SetSdXfrBlkSize(I64 size)
{
  sd_max_xfr_blk_size=size;
}

public I64 GetSdXfrBlkSize()
{
  return sd_max_xfr_blk_size;
}

static U32 TimerCalc(U32 t)
{
  U32 quit_time = ToI64(tS*1000)+t;
  return quit_time;
}

static U32 TimerCheck(U32 t)
{
  U32 cur_time;
  SYield;
  cur_time=ToI64(tS*1000);
  if (t>cur_time) return 0;
  return 1;
}

static I64 SdWaitW(U16 *r,U16 mask)
{
  I64 i=0,v;
  U32 end_ts;
  while (1)
  {
    v = MInU16D(r);
    if (v & mask) 
      return v;
    if (i==512) end_ts = TimerCalc(1000);
    if (i>516 && TimerCheck(end_ts))
    {
      SYield;
      return -1;
    }
    i++;
  }
}

static I64 SdSetFreq(sdhci_regs *regs,U32 khz)
{
  U16 creg,ver = MInU16D(&regs->controller_version);
  U32 base_freq,divisor,cap = MInU32D(&regs->cap_lo);
  I64 ret;

  base_freq = cap >> 8 & 0xff;
  if (!base_freq) return -1;
  
  if (!base_freq)
  {
    if (cap & 1 << 21)
    {
      base_freq = 50;
    }
    else
    {
      base_freq = 25;
    }
  }

  divisor = (base_freq * 1000 + khz - 1) / khz;
  if (ver & 0xff <= 1)
  {
    if (divisor > 1)
      divisor = 1 << Bsr(divisor - 1);
    else
      divisor = 0;

    creg = (divisor & 0xff) << 8;
  }
  else
  {
    divisor = (divisor + 2 - 1) / 2;
    creg = (divisor & 0xff) << 8;
    creg |= (divisor & 0x300) >> 2;
  }

  MOutU16D(&regs->clock_control,0);
  MOutU16D(&regs->clock_control,creg | 1);

  ret = SdWaitW(&regs->clock_control, 2);

  if (ret < 0) return ret;

  MOutU16D(&regs->clock_control,creg | 5);
  return 0;
}

static I32 SdRst(sdhci_regs *regs,I32 flags)
{
  MOutU8D(&regs->software_reset,flags);

  U32 end_ts = TimerCalc(1000);
  while (MInU8D(&regs->software_reset))
    if (TimerCheck(end_ts)) return -1;
  return 0;
}

static I64 SdPIO(sdhci_regs *regs,I32 cmd,U32 *param)
{
  I64 attempt=0, ret;
  U16 err;
  U32 state;

  for (attempt=0; attempt<3; attempt++)
  {
    state = MInU32D(&regs->present_state);

    if (state & 1 || cmd & 3 == 3 && state & 2)
    {
      if (attempt==2) return -1;
      else SYield;
    }
    else break;
  }

  MOutU32D(&regs->arg, *param);
  MOutU16D(&regs->cmd,cmd);

  ret = SdWaitW(&regs->irq_status,1 << 15 | 1);

  if (ret < 0) return ret;

  if (ret & 1 << 15)
  {
    err = MInU16D(&regs->error_irq_status);

    SdRst(regs,0x02 | 0x04);

    MOutU16D(&regs->error_irq_status,err);
    return -1;
  }

  MOutU16D(&regs->irq_status, 1);
  MemCpy(param,regs->response,sizeof(U32)*4);

  return 0;
}

static I64 SdPIOApp(sdhci_regs *regs,I32 cmd,U32 *param)
{
  U32 aparam[4];
  I64 ret;
  aparam[0]=0;
  aparam[1]=0;
  aparam[2]=0;
  aparam[3]=0;

  ret = SdPIO(regs,55 << 8 | 0x1a,aparam);

  if (ret) return ret;

  ret = SdPIO(regs,cmd,param);

  return ret;
}

static I64 SdPIOXfr(sd_drv *drive,I32 cmd,U32 addr,U8 *data,I32 count)
{// Do SD PIO transfer
  I64 i, isread, ret;
  U16 cbit,tmode;
  U32 param[4];

  MOutU16D(&drive->regs->block_size,512);
  MOutU16D(&drive->regs->block_count,count);

  isread = cmd != 24 << 8 | 0x3a && cmd != 25 << 8 | 0x3a;

  tmode = 0;

  if (count > 1)
    tmode = 1 << 5 | 1 << 2 | 1 << 1;

  if (isread)
    tmode |= 1 << 4;

  MOutU16D(&drive->regs->transfer_mode,tmode);
  if (!(drive->card_type & 2))
    addr *= 512;
  param[0] = addr;
  ret = SdPIO(drive->regs,cmd,param);

  if (ret) return ret;

  if (isread)
    cbit = 1 << 5;
  else
    cbit = 1 << 4;

  while (count--)
  {
    ret = SdWaitW(&drive->regs->irq_status,cbit);

    if (ret < 0) return ret;

    MOutU16D(&drive->regs->irq_status,cbit);
    for (i = 0; i < 512 / 4; i++)
    {
      if (isread)
      {
        *data(U32*)=MInU32D(&drive->regs->data);
      }
      else
      {
        MOutU32D(&drive->regs->data, *data(U32*));
      }
      data += 4;
    }
  }

  ret = SdWaitW(&drive->regs->irq_status,2);

  if (ret < 0) return ret;

  MOutU16D(&drive->regs->irq_status,2);

  return 0;
}

static I64 SdPIOXfrTry(sd_drv *drive,I32 cmd,U32 addr,U8 *data,I32 count)
{// Try SD PIO transfer, if fails reset and try again for quirky hardware
  I64 res=SdPIOXfr(drive,cmd,addr,data,count);
  if (!res) 
  {
    ok_count++;
    return 0;
  }

  // For quirky hardware, do reset and retyr PIO transfer
  // Not needed for all hardware, Lenovo T420/T430 PIO
  // seems broke without it!
  rst_count++;
  SdRst(drive->regs,6);
  SdSetFreq(drive->regs,12500);

  return SdPIOXfr(drive,cmd,addr,data,count);
}

public U0 SdStats()
{
  I64 total=ok_count+rst_count;
  "Total Xfr Request: %d\n",total;
  if (total>0)
  {
    "OK  percent: %1.2f\n",100.0*ToF64(ok_count)/ToF64(total);
    "RST percent: %1.2f\n",100.0*ToF64(rst_count)/ToF64(total);
  }
}

static I64 SdBlkRW(sd_drv *drive, I32 iswrite, I64 lba, I64 count, U8 *data)
{
  I64 cmd, ret;

  if (count > 1)
  {
    if (iswrite)
      cmd = 25 << 8 | 0x3a;
    else
      cmd = 18 << 8 | 0x3a;
  }
  else
  {
    if (iswrite)
      cmd = 24 << 8 | 0x3a;
    else
      cmd = 17 << 8 | 0x3a;
  }

  ret = SdPIOXfrTry(drive,cmd,lba,data,count);

  if (ret) return 0xc;

  return 0;
}

static I64 SdSetPwr(sdhci_regs *regs)
{
  U32 volt,vbits,cap = MInU32D(&regs->cap_lo);
  if (cap & 1 << 24)
  {
    volt = 1 << 20;
    vbits = 0x0e;
  }
  else if (cap & 1 << 25)
  {
    volt = 1 << 18;
    vbits = 0x0c;
  }
  else if (cap & 1 << 26)
  {
    volt = 1 << 7;
    vbits = 0x0a;
  }
  else return -1;

  MOutU8D(&regs->power_control,0);
  Sleep(1);

  MOutU8D(&regs->power_control,vbits | 1);
  Sleep(5);

  return volt;
}

static I64 SdGetCap(sd_drv *drive,U8 *csd)
{
  I64 card_size_mult,csd_struct, read_bl_len, ret;
  U16 card_size;
  U8 ext_csd[512];
  U32 count, card_size2;

  card_size = csd[6] >> 6 | csd[7] << 2 | (csd[8] & 0x03) << 10;
  card_size_mult = csd[4] >> 7 | (csd[5] & 0x03) << 1;
  read_bl_len = csd[9] & 0x0f;

  count = (card_size + 1) << (card_size_mult + 2 + read_bl_len - 9);

  csd_struct = csd[14] >> 6;
  if (drive->card_type & 1 && csd_struct >= 2)
  {
    ret = SdPIOXfrTry(drive, 8 << 8 | 0x3a,0,ext_csd,1);
    if (ret) return ret;

    count = *&ext_csd[212];
  }
  else if (!(drive->card_type & 1) && csd_struct >= 1)
  {
    card_size2 = csd[5] | csd[6] << 8 | (csd[7] & 0x3f) << 16;
    count = (card_size2 + 1) << 10;
  }

  drive->blksize=512;
  drive->sectors=count;

  return 0;
}

public Bool SdEraseBlks(I64 start_blk, I64 cnt)
{
  U32 end_ts, param[4];
  sd_drv *drive = sdhci_drv;
  I64 ret, end_blk = start_blk + cnt - 1;

  if (!sdhci_drv) return FALSE;
  if (cnt <= 0) return TRUE;

  // For non-HC cards, addresses are byte-based
  if (!(drive->card_type & 2)) {
    start_blk *= 512;
    end_blk   *= 512;
  }

  param[0] = start_blk;
  ret = SdPIO(drive->regs, 32 << 8 | 0x1a, param);
  if (ret) {
    "ERASE CMD32 failed\n";
    return FALSE;
  }

  param[0] = end_blk;
  ret = SdPIO(drive->regs, 33 << 8 | 0x1a, param);
  if (ret) {
    "ERASE CMD33 failed\n";
    return FALSE;
  }

  param[0] = 0;
  ret = SdPIO(drive->regs, 38 << 8 | 0x1a, param);
  if (ret) {
    "ERASE CMD38 failed\n";
    return FALSE;
  }

  end_ts = TimerCalc(10000);
  while (1) {
    param[0] = 0;
    ret = SdPIO(drive->regs, 13 << 8 | 0x1a, param);
    if (ret) break;
    if (!(param[0] & 1 << 9))
      break;

    if (TimerCheck(end_ts)) return FALSE;
    Sleep(10);
  }

  return TRUE;
}

static I64 SdCardSetup(sd_drv *drive,I32 volt)
{
  U8 csd[16];
  U16 rca;
  U32 end_ts,hcs,vrange,param[4];
  I64 tmp, ret;

  param[0]=0;
  param[1]=0;
  param[2]=0;
  param[3]=0;

  sdhci_regs *regs = drive->regs;

  ret = SdSetFreq(regs,400);

  if (ret) return ret;

  Sleep(1);

  ret = SdPIO(regs,0,param);

  if (ret) return ret;

  hcs = 0;

  if (volt >= 1 << 15)
    tmp = 0x100;
  else tmp = 0x200;

  vrange = tmp | 0xaa;

  param[0] = vrange;

  ret = SdPIO(regs,8 << 8 | 0x1a,param);

  Sleep(5);

  if (!ret && param[0] == vrange)
    hcs = 1 << 30;

  param[0] = 0x00;
  Sleep(5);
  ret = SdPIOApp(regs,41 << 8 | 2,param);

  Sleep(5);

  if (ret)
  {
    param[0] = 0x00;
    ret = SdPIO(regs,1 << 8 | 2,param);
    Sleep(5);
    drive->card_type |= 1;
    hcs = 1 << 30;
  }

  end_ts = TimerCalc(1000);

  while (1)
  {
    param[0] = hcs | volt;

    if (drive->card_type & 1)
      ret = SdPIO(regs,1 << 8 | 2,param);
    else
      ret = SdPIOApp(regs,41 << 8 | 2,param);

    if (ret) return ret;

    if (param[0] & 1 << 31) break;

    if (TimerCheck(end_ts)) return -1;

    Sleep(5);
  }

  if (param[0] & 1 << 30)
    tmp = 2;
  else tmp = 0;

  drive->card_type |= tmp;

  param[0] = 0;
  ret = SdPIO(regs,2 << 8 | 9,param);

  if (ret) return ret;

  if (drive->card_type & 1)
    param[0] = 1 << 16;
  else param[0] = 0;

  ret = SdPIO(regs,3 << 8 | 0x1a,param);

  if (ret) return ret;

  rca = param[0] >> 16;
  if (drive->card_type & 1)
    rca = 0x0001;

  param[0] = rca << 16;
  ret = SdPIO(regs,9 << 8 | 9,param);

  if (ret) return ret;

  MemCpy(csd,param,sizeof(csd));

  param[0] = rca << 16;
  ret = SdPIO(regs,7 << 8 | 0x1b,param);

  if (ret) return ret;

  ret = SdSetFreq(regs,12500);

  if (ret) return ret;

  ret = SdGetCap(drive,csd);

  if (ret) return ret;

  return 0;
}

static sd_drv SdCtrlSetup(sdhci_regs *regs)
{
  I64 ret,volt;
  U32 present_state;

  present_state = MInU32D(&regs->present_state);
  if (!(present_state & 1 << 16)) return NULL;

  SdRst(regs,0x01);

  MOutU16D(&regs->irq_signal,0);
  MOutU16D(&regs->irq_enable,0x01ff);
  MOutU16D(&regs->irq_status,MInU16D(&regs->irq_status));
  MOutU16D(&regs->error_signal,0);
  MOutU16D(&regs->error_irq_enable,0x01ff);
  MOutU16D(&regs->error_irq_status,MInU16D(&regs->error_irq_status));
  MOutU8D(&regs->timeout_control,0x0e);

  volt = SdSetPwr(regs);

  if (volt < 0) return NULL;

  sd_drv *drive = UncachedDevCAlloc(sizeof(sd_drv));
  if (!drive)
  {
    goto fail;
  }

  drive->regs = regs;

  ret = SdCardSetup(drive,volt);

  if (ret)
  {
    UncachedDevFree(drive);
    goto fail;
  }

  return drive;

fail:
  MOutU8D(&regs->power_control,0);
  MOutU16D(&regs->clock_control,0);

  return NULL;
}

Bool fp_sdhci_blkdev_init_impl()
{
  return TRUE;
}

Bool fp_sdhci_blkdev_deinit_impl()
{
  return TRUE;
}

Bool fp_sdhci_blkdev_read_impl(U8* buf, I64 blk, I64 cnt)
{
  I64 i, res=1, bs=sd_max_xfr_blk_size;

  if (bs<=1)
    return !SdBlkRW(sdhci_drv, 0, blk, cnt, buf);
  else
  {
    if (cnt>=bs)
      for (i=0;i<cnt/bs;i++)
        res &= !SdBlkRW(sdhci_drv, 0, blk+i*bs, bs, buf+512*i*bs);
    if (cnt%bs>0)
    {
      i=cnt/bs;
      res &= !SdBlkRW(sdhci_drv, 0, blk+i*bs, cnt%bs, buf+512*i*bs);
    }
  }
  return res;
}

Bool fp_sdhci_blkdev_write_impl(U8* buf, I64 blk, I64 cnt)
{
  I64 i, res=1, bs=sd_max_xfr_blk_size;

  if (bs<=1)
    return !SdBlkRW(sdhci_drv, 1, blk, cnt, buf);
  else
  {
    if (cnt>=bs)
      for (i=0;i<cnt/bs;i++)
        res &= !SdBlkRW(sdhci_drv, 1, blk+i*bs, bs, buf+512*i*bs);
    if (cnt%bs>0)
    {
      i=cnt/bs;
      res &= !SdBlkRW(sdhci_drv, 1, blk+i*bs, cnt%bs, buf+512*i*bs);
    }
  }
  return res;
}

I64 fp_sdhci_blkdev_get_max_impl()
{
  return sdhci_drv->sectors;
}

U0 SdhciInitBlkDevFp()
{
  if (sdhci_drv)
  {
    if (sdhci_drv->blksize>=512 && sdhci_drv->sectors>1024)
    {

      fp_sdhci_blkdev_init=&fp_sdhci_blkdev_init_impl;
      fp_sdhci_blkdev_deinit = &fp_sdhci_blkdev_deinit_impl;
      fp_sdhci_blkdev_read = &fp_sdhci_blkdev_read_impl;
      fp_sdhci_blkdev_write = &fp_sdhci_blkdev_write_impl;
      fp_sdhci_blkdev_get_max = &fp_sdhci_blkdev_get_max_impl;
    }
  }
}

public U0 SetupSdhciDrvs()
{
  SetDrvLetType('W', BDT_SDHCI);
  SetDrvLetType('X', BDT_SDHCI);
  SetDrvLetType('Y', BDT_SDHCI);
  SetDrvLetType('Z', BDT_SDHCI);
}

public sd_drv *SdhciInit(I64 vendor_id=NULL, I64 device_id=NULL, Bool setup_drvs=TRUE)
{
  I64 b=0, d=0, f=0;
  U32 bar=0;
  CPciDevInfo *sdhci_pci=CAlloc(sizeof(CPciDevInfo));

  if (sdhci_drv) return sdhci_drv;

  if (setup_drvs) SetupSdhciDrvs;

  if (vendor_id && device_id && PciFindByID(vendor_id,device_id, 0, 0, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x1180,0xE823, 0x08, 0x80, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x1B36,0x0007, 0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x1217,0x8320, 0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x1217,0x8321, 0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x1217,0x8620, 0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x1217,0x8621, 0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x197B,0x2386,0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }
  else if (PciFindByID(0x197B,0x2391,0x08, 0x05, &b, &d, &f))
  {
    PciGetDevInfo(sdhci_pci,b,d,f);
  }

  bar=sdhci_pci->bar[0];
  Free(sdhci_pci);

  if (!bar) return NULL;

  PCIWriteU16(b,d,f,PCIR_COMMAND,PCIReadU16(b,d,f,PCIR_COMMAND)|0x6);

  sd_drv *drive=SdCtrlSetup(bar);

  if (drive)
  {
    sdhci_drv=drive;
    SdhciInitBlkDevFp;
  }
  else "Setup failed, no SD card perhalps?\n";

  return drive;
}
