#define SAMPLE_RATE       22050
#define BUF_SIZE          8192
#define BDL_CNT           4
#define MAX_AMP           32000.0
#define BYTES_PER_SAMPLE  4
#define PCM_OUTPUT_REG    0x10
#define CUR_ENTRY         0x4
#define LAST_VALID        0x05
#define XFR_STS           0x06
#define XFR_CTL           0x0B
#define RESET             0x00
#define GLOBAL_CTL        0x2C
#define MASTER_VOL        0x02
#define PCM_VOL           0x18
#define FRONT_SAMPLE_RATE 0x2C

class AC97BDLEntry
{
  U32 addr;
  U16 len;
  U16 flags;
};

static U8 *sine_buf;
static U32 AC97Nam, AC97Nabm;
static AC97BDLEntry *bdl, *bdl2, *cur_bdl, *next_bdl;
static I64 playing = 0;

U0 AC97AudioTask(U8 *data)
{
  I64 cur, status;
  no_warn data;
  while (1)
  {
    if (Bt(&playing,0)) {
      cur = InU8(AC97Nabm + PCM_OUTPUT_REG + CUR_ENTRY) % BDL_CNT;
      OutU8(AC97Nabm + PCM_OUTPUT_REG + LAST_VALID, (cur + BDL_CNT - 1) % BDL_CNT);

      status = InU16(AC97Nabm + PCM_OUTPUT_REG + XFR_STS);
      if (status & 0x1C)
        OutU16(AC97Nabm + PCM_OUTPUT_REG + XFR_STS, 0x1C);
    }
    Sleep(1);
  }
}

U0 AC97SwapBDL()
{
  next_bdl = cur_bdl;
  if (bdl == cur_bdl)
    cur_bdl = bdl2;
  else
    cur_bdl = bdl;

  OutU32(AC97Nabm + PCM_OUTPUT_REG + 0x00, cur_bdl);
}

U0 AC97Init()
{
  U8 *audio_buf, *audio_buf2;
  I64 i;

  audio_buf = CAllocAligned(BDL_CNT * BUF_SIZE, 4096, Fs->code_heap);
  audio_buf2 = CAllocAligned(BDL_CNT * BUF_SIZE, 4096, Fs->code_heap);

  cur_bdl = bdl = CAllocAligned(BDL_CNT * sizeof(AC97BDLEntry), 4096, Fs->code_heap);
  next_bdl = bdl2 = CAllocAligned(BDL_CNT * sizeof(AC97BDLEntry), 4096, Fs->code_heap);

  sine_buf = CAllocAligned(BUF_SIZE, 4096, Fs->code_heap);

  OutU32(AC97Nabm + PCM_OUTPUT_REG + 0x00, cur_bdl);

  for (i = 0; i < BDL_CNT; i++)
  {
    bdl[i].addr = audio_buf + (i * BUF_SIZE);
    bdl2[i].addr = audio_buf2 + (i * BUF_SIZE);
    bdl[i].len = bdl2[i].len = BUF_SIZE/4;
  }

  OutU8(AC97Nabm + PCM_OUTPUT_REG + LAST_VALID, BDL_CNT-1);
  OutU8(AC97Nabm + PCM_OUTPUT_REG + XFR_CTL, 0x00);
  OutU8(AC97Nabm + PCM_OUTPUT_REG + XFR_CTL, 0x01);

  Spawn(&AC97AudioTask,,"AC97 Audio",1);
}

U0 AC97Mute() { LBtr(&playing,0);}

U0 AC97SetFreq(F64 freq)
{
  I64 amp, i, j, period_samples, period_bytes, periods_per_buffer;
  F64 phase, samples_per_period_f;

  if (freq <= 30.0)
  {
    for (i = 0; i < BDL_CNT; i++)
    {
      MemSet(next_bdl[i].addr, 0, BUF_SIZE);
      next_bdl[i].len = BUF_SIZE/4;
    }
    AC97SwapBDL;
    LBtr(&playing,0);
    return;
  }

  samples_per_period_f = ToF64(SAMPLE_RATE) / freq;
  period_samples = ToI64(samples_per_period_f);
  period_bytes = period_samples * BYTES_PER_SAMPLE;
  periods_per_buffer = BUF_SIZE / period_bytes;

  if (period_bytes > BUF_SIZE) return;

  for (i = 0; i < period_samples; i++)
  {
    phase = ToF64(i) / samples_per_period_f;
    amp = ToI64(Sin(phase * 2.0 * ã) * MAX_AMP);
    sine_buf[i * 4 + 0] = sine_buf[i * 4 + 2] = amp & 0xFF;
    sine_buf[i * 4 + 1] = sine_buf[i * 4 + 3] = (amp >> 8) & 0xFF;
  }

  for (i = 0; i < BDL_CNT; i++)
  {
    for (j = 0; j < periods_per_buffer; j++)
      MemCpy(next_bdl[i].addr + (j * period_bytes), sine_buf, period_bytes);
    next_bdl[i].len = period_samples * periods_per_buffer * 2;
  }

  AC97SwapBDL;
  LBts(&playing,0);
}

I64 AC97Probe()
{
  I64 j = PCIClassFind(0x040100, 0);
  if (j < 0)
    return -1;

  CPciDevInfo info;
  PciGetDevInfo(&info, j.u8[2], j.u8[1], j.u8[0]);

  if (info.vendor_id != 0x8086 || info.device_id != 0x2415)
    return -1;

  AC97Nam = info.bar[0] & ~1;
  AC97Nabm = info.bar[1] & ~1;

  PCIWriteU8(j.u8[2], j.u8[1], j.u8[0], 0x4, 5);

  OutU32(AC97Nabm + GLOBAL_CTL, 0x03);
  OutU16(AC97Nam + RESET, 0xFFFF);
  OutU16(AC97Nam + PCM_VOL, 0x0000);
  OutU16(AC97Nam + MASTER_VOL, 0x0F0F);
  OutU16(AC97Nam + FRONT_SAMPLE_RATE, SAMPLE_RATE);

  AdamLog("\nAC'97 Device found!\n");

  return 0;
}

public U0 AC97Snd(I8 ona=0)
{
  CSndData *d;

  if (!ona) AC97Mute;

  if (!Bt(&sys_semas[SEMA_MUTE],0) &&
      !LBts(&sys_semas[SEMA_SND],0))
  {
    if (!ona)
    {
      scrncast.ona = ona;
    }
    else if (ona != scrncast.ona)
    {
      scrncast.ona = ona;
      AC97SetFreq(Ona2Freq(ona));
    }
    if (!IsDbgMode && scrncast.record)
    {
      d = ACAlloc(sizeof(CSndData));
      d->ona = ona;
      d->tS = tS;
      QueIns(d,scrncast.snd_head.last);
    }
    LBtr(&sys_semas[SEMA_SND],0);
  }
}

if (!AC97Probe)
{
  AC97Init;
  Snd(0);
  Mute(1);
  LBts(&sys_semas[SEMA_SND],0);
  Yield;
  HijackFunc(&Snd,&AC97Snd);
  LBtr(&sys_semas[SEMA_SND],0);
  Mute(0);
}
