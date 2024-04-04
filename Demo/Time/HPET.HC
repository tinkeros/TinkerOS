// This demo enables the HPET
//
// Adam include this, do NOT do a regular include.
//
// I removed HPET from TempleOS/TinkerOS because it caused
// boot failures on incompatible systems so this will not
// work on all systems.
//
// If it works it provided better timing.

#help_index "Time/CPU Cycles;Time/HPET;Time/Jiffies"
#define HPET_GCAP_ID  (0xFED00000+0x00)
#define HPET_GEN_CONF (0xFED00000+0x10)
#define HPET_MAIN_CNT (0xFED00000+0xF0)

static I64 HPET_freq, HPET_kHz_freq, HPET_initial;
static F64 tS_initial;

I64 HPET()
{ //Get high precision event timer.
  return *(dev.uncached_alias+HPET_MAIN_CNT)(I64 *);
}

F64 tS_HPET()
{//Time since boot in seconds as a float.
  return tS_initial+ToF64(HPET-HPET_initial)/HPET_freq;
}

U0 Busy_HPET(I64 uS)
{//Precisely timed instead of loosely timed using PortNop
  I64 i=HPET+HPET_freq*uS/1000000;
    while (HPET<i);
}

Bool HPETInit()
{
  I64 i,*_q;
  U32 *_d;

  //High Precision Event Timer
  if (PCIReadU16(0,31,0,0)==0x8086) {//Intel?
    //D31 F0, cfg 0xF0=RCBA of PCI-LPC Bridge
    _d=PCIReadU32(0,31,0,0xF0)(U8 *)&~0x3FFF+0x3404; //HPET cfg
    //7     enable
    //1:0 HPET is at 0xFED00000,0xFED01000, 0xFED02000 or 0xFED03000.
    *_d=*_d&3|0x80;
  }

  _q=dev.uncached_alias+HPET_GCAP_ID;
  i=*_q; //i.u32[1]= period in femtoS (10e-15)
  if (100000<i.u32[1]<1000000000) {
    HPET_freq    =1000000000000000/i.u32[1];
    HPET_kHz_freq=1000000000000/i.u32[1];
    _q=dev.uncached_alias+HPET_GEN_CONF;
    *_q|=1; //Enable counting
    HPET_initial=HPET;
	tS_initial=tS;
  } else {
    return FALSE;
  }
  // Hijack normal system function to use HPET version instead.
  HijackFunc(&tS,&ts_HPET);
  HijackFunc(&Busy,&Busy_HPET);
  return TRUE;
}

