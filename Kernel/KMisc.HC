U0 PortNop()
{//Innoculous (reads IRQ Mask) which should take fixed time
//because it's an ISA-bus standard.  It takes 1.0uS-2.0uS.
  InU8(0x21);
}

U16 EndianU16(U16 d)
{//Swap big<-->little endian.
  I64 res=0;
  res.u8[1]=d.u8[0];
  res.u8[0]=d.u8[1];
  return res;
}

U32 EndianU32(U32 d)
{//Swap big<-->little endian.
  I64 res=0;
  res.u8[3]=d.u8[0];
  res.u8[2]=d.u8[1];
  res.u8[1]=d.u8[2];
  res.u8[0]=d.u8[3];
  return res;
}

I64 EndianI64(I64 d)
{//Swap big<-->little endian.
  U64 res;
  res.u8[7]=d.u8[0];
  res.u8[6]=d.u8[1];
  res.u8[5]=d.u8[2];
  res.u8[4]=d.u8[3];
  res.u8[3]=d.u8[4];
  res.u8[2]=d.u8[5];
  res.u8[1]=d.u8[6];
  res.u8[0]=d.u8[7];
  return res;
}

I64 BCnt(I64 d)
{//Count set bits in I64.
  I64 res=0,i;
  for (i=0; i<8; i++)
    res+=set_bits_table[d.u8[i]];
  return res;
}

U0 IntCore0TimerHndlr(CTask *)
{//Called from $LK,"IntCore0TimerHndlr",A="FF:::/Kernel/KInts.HC,IntCore0TimerHndlr"$
  I64 i;
  if (mp_cnt>1)
    while (LBts(&sys_semas[SEMA_SYS_TIMER],0))
      PAUSE
      lock cnts.jiffies++;
  cnts.timer+=SYS_TIMER0_PERIOD+1;
  LBtr(&sys_semas[SEMA_SYS_TIMER],0);
  if (Bt(&sys_run_level,RLf_MP))
    for (i=1; i<mp_cnt; i++)
      MPInt(I_TIMER,i);
  OutU8(0x20,0x20); //Acknowledge PIC Interrupt
}

I64 SysTimerRead()
{//System timer count with overflow already handled.
  I64 i,res;
  PUSHFD
  CLI
  if (mp_cnt>1)
    while (LBts(&sys_semas[SEMA_SYS_TIMER],0))
      PAUSE
      OutU8(0x43,0); //Latch Timer0
  if ((i=InU8(0x40)+InU8(0x40)<<8)==SYS_TIMER0_PERIOD)
  {
    if (InU8(0x20) & 1)
      i=-1;
  }
  res=cnts.timer+SYS_TIMER0_PERIOD-i;
  LBtr(&sys_semas[SEMA_SYS_TIMER],0);
  POPFD
  return res;
}

I64 TimeCal()
{
  static I64 time_stamp_start=0,timer_start=0;
  I64 i;
  if (time_stamp_start)
  {
    PUSHFD
    CLI
    cnts.time_stamp_freq=SYS_TIMER_FREQ*(GetTSC-time_stamp_start);
    i=SysTimerRead-timer_start;
    if (!i)
      AdamErr("Timer Cal Error");
    else
    {
      cnts.time_stamp_freq/=i;
      cnts.time_stamp_kHz_freq=cnts.time_stamp_freq/1000;
      cnts.time_stamp_calibrated=TRUE;
    }
    POPFD
  }
  PUSHFD
  CLI
  timer_start=SysTimerRead;
  time_stamp_start=GetTSC;
  POPFD
  return cnts.time_stamp_freq;
}

F64 tS()
{//Time since boot in seconds as a float.
  return SysTimerRead/ToF64(SYS_TIMER_FREQ);
}

Bool Blink(F64 Hz=2.5)
{//Return TRUE, then FALSE, then TRUE at given frequency.
  if (!Hz) return 0;
  if (!blink_master_flag) return 0;
  return ToI64(cnts.jiffies*2*Hz/JIFFY_FREQ)&1;
}

U0 Busy(I64 uS)
{//Loosely timed.
  I64 i;
  for (i=0; i<uS; i++)
    PortNop;
}

U0 SleepUntil(I64 wake_jiffy)
{//Not for power-saving.It is to make a program pause without hogging the CPU.
  Bool old_idle=LBts(&Fs->task_flags,TASKf_IDLE);
  Fs->wake_jiffy=wake_jiffy;
  Yield;
  LBEqu(&Fs->task_flags,TASKf_IDLE,old_idle);
}

U0 Sleep(I64 mS)
{//Not for power-saving.It is to make a program pause without hogging the CPU.
  if (!mS)
    Yield;
  else
    SleepUntil(cnts.jiffies+mS*JIFFY_FREQ/1000);
}

F64 Ona2Freq(I8 ona)
{//Ona to freq. Ona=60 is 440.0Hz.
  if (!ona)
    return 0;
  else
    return 440.0/32*2.0`(ona/12.0);
}

I8 Freq2Ona(F64 freq)
{//Freq to Ona. 440.0Hz is Ona=60.
  if (freq>0)
    return ClampI64(12*Log2(32.0/440.0*freq),1,I8_MAX);
  else
    return 0;
}

U0 Snd(I8 ona=0)
{//Play ona, a piano key num. 0 means rest.
  I64 period;
  CSndData *d;
  if (!Bt(&sys_semas[SEMA_MUTE],0) &&
      !LBts(&sys_semas[SEMA_SND],0))   //Mutex. Just throw-out if in use
  {
    if (!ona)
    {
      scrncast.ona=ona;
      snd.ona=ona;
      if (snd.fp_alt_snd_dev)
        snd.fp_alt_snd_dev(ona);
      else
        OutU8(0x61,InU8(0x61)&~3);
    }
    else if (ona!=scrncast.ona || ona!=snd.ona)
    {
      scrncast.ona=ona;
      snd.ona=ona;
      if (snd.fp_alt_snd_dev)
        snd.fp_alt_snd_dev(ona);
      else {
        period=ClampI64(SYS_TIMER_FREQ/Ona2Freq(ona),1,U16_MAX);
        OutU8(0x43,0xB6);
        OutU8(0x42,period);
        OutU8(0x42,period.u8[1]);
        OutU8(0x61,3|InU8(0x61));
      }
    }
    if (!IsDbgMode && scrncast.record)
    {
      d=ACAlloc(sizeof(CSndData));
      d->ona=ona;
      d->tS=tS;
      QueIns(d,scrncast.snd_head.last);
    }
    if (!IsDbgMode && snd.record)
    {
      d=ACAlloc(sizeof(CSndData));
      d->ona=ona;
      d->tS=tS;
      QueIns(d,scrncast.snd_head.last);
    }
    LBtr(&sys_semas[SEMA_SND],0);
  }
}

Bool ScrnCast(Bool val=ON,Bool just_audio=FALSE,U8 *print_fmt="B:/Tmp/%X.GR")
{//WinMgr saves GR files to a dir.
  Bool old_val;
  scrncast.just_audio=just_audio;
  if (val)
  {
    if (!(old_val=LBtr(&scrncast.record,0)))
    {
      Free(scrncast.print_fmt);
      scrncast.print_fmt=AStrNew(print_fmt);
      scrncast.t0_now=Now;
      scrncast.snd_head.tS=scrncast.t0_tS=tS;
      scrncast.snd_head.ona=scrncast.ona;
      LBts(&scrncast.record,0);
    }
  }
  else
    old_val=LBtr(&scrncast.record,0);
  Snd;
  return old_val;
}

U0 SndRst()
{//Fix stuck sound.
  if (Bt(&sys_semas[SEMA_SND],0))
  {
    Sleep(1);
    if (Bt(&sys_semas[SEMA_SND],0))
    {
      Sleep(1);
      LBtr(&sys_semas[SEMA_SND],0);
    }
  }
  Snd;
}

U0 Beep(I8 ona=62,Bool busy=FALSE)
{//Make beep at given ona freq.
  Snd(ona);
  if (busy)
    Busy(500000);
  else
    Sleep(500);
  Snd;
  if (busy)
    Busy(200000);
  else
    Sleep(200);
}

Bool Mute(Bool val)
{//Turn-off sound.
  Bool res;
  if (val)
  {
    PUSHFD
    CLI
    Snd;
    res=LBts(&sys_semas[SEMA_MUTE],0);
    POPFD
  }
  else
    res=LBtr(&sys_semas[SEMA_MUTE],0);
  return res;
}

Bool IsMute()
{//Return is-mute flag.
  return Bt(&sys_semas[SEMA_MUTE],0);
}

Bool Silent(Bool val=ON)
{//Turn-off StdOut console text. (Not sound.)
  return LBEqu(&Fs->display_flags,DISPLAYf_SILENT,val);
}

Bool IsSilent()
{//Return StdOut turned-off?
  return Bt(&Fs->display_flags,DISPLAYf_SILENT);
}

Bool SysDbg(Bool val)
{//Set SysDbg bit you can use while debugging.
  return LBEqu(&sys_semas[SEMA_DEBUG],0,val);
}

Bool IsSysDbg()
{//Return SysDbg bit.
  return Bt(&sys_semas[SEMA_DEBUG],0);
}

Bool Raw(Bool val)
{//Set to direct scrn, BLACK & WHITE, non-windowed output mode.
  if (!val)
    VGAFlush;
  return !LBEqu(&Fs->display_flags,DISPLAYf_NOT_RAW,!val);
}

Bool IsRaw()
{//Are we in BLACK & WHITE raw scrn mode?
  return !Bt(&Fs->display_flags,DISPLAYf_NOT_RAW);
}

Bool SingleUser(Bool val)
{//Set single-user mode.
  return LBEqu(&sys_semas[SEMA_SINGLE_USER],0,val);
}

Bool IsSingleUser()
{//Return single-user mode.
  return Bt(&sys_semas[SEMA_SINGLE_USER],0);
}

Bool DbgMode(Bool val)
{//Set dbg-mode.
  return LBEqu(&sys_semas[SEMA_DBG_MODE],0,val);
}

Bool IsDbgMode()
{//Return dbg-mode.
  return Bt(&sys_semas[SEMA_DBG_MODE],0);
}

CTask *LastTask()
{
  return last_init_task;
}

public U0 SetAltScrn(CDC *scrn=NULL)
{ // Sets CDC to use as alternate source writing to framebuffer
  PUSHFD
  CLI
  gr_alt_scrn=scrn;
  POPFD
}

CTask *SetSysFocusTask(CTask *task=Fs,Bool check_raw=TRUE)
{
  PUSHFD
  CLI
  SetAltScrn;  // Restore screen if full screen app loses focus
  CMsRawQue *entry = ms_hard.raw_queue->next;
  if (!check_raw || !ms_hard.installed || IsDbgMode || IsRaw)
  {
    sys_focus_task=task;
    POPFD
    return task;
  }
  ms_hard.raw_mode = MsRawQueFind(task);
  ms.show = !ms_hard.raw_mode;
  sys_focus_task=task;
  while (ms_hard.installed && entry && entry != ms_hard.raw_queue)
  {
    if (!TaskValidate(entry->task))
    {
      QueRem(entry);
      Free(entry);
      break;
    }
    entry=entry->next;
  }
  POPFD
  return task;
}

U0 ProgressBarsRst(U8 *path=NULL)
{//Reset all progress bars to zero.
  CallExtStr("ProgressBarsRegTf",path);
  MemSet(sys_progresses,0,sizeof(sys_progresses));
}

U0 KeyStateRst()
{//Clears state of all keys in key_state and sc_state
  MemSetI64(key_state,0,16);
  MemSetI64(sc_state,0,32);
  sc_flags_state=0;
}

U0 BitFieldSet(U8 *bit_field, U8 offset, U8 size, U8 value)
{//Sets values in a bit field
  I64 i;
  for (i=0; i<size; i++)
    BEqu(bit_field,offset+i,value>>i);
}


U64 BitFieldGet(U8 *bit_field, U8 offset, U8 size)
{//Gets values from a bit field
  I64 i;
  U64 val=0;
  for (i=0; i<size; i++)
    BEqu(&val,i,Bt(bit_field,offset+i));
  return val;
}

U8 *HypeInfo()
{
  return hype_info;
}
