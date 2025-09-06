Cd(__DIR__);
#include "/Demo/Snd/Midi.HH"

// Pick one, then configure below

// QEMU / Real ISA Adlib or compatible card
#define ISA_OPL

// For OPT2LPT or OPL3LPT connected via a parallel port
// comment ISA_OPL define above, uncomment and setup
// next two lines (LptRep might help finding io port)
//#define OPL2LPT
//#define LPT_IOPORT_OPL_BASE 0x378

// For Serial OPL device
// comment ISA_OPL define above, uncomment and setup
// next two lines (CommRep might help finding port)
//#define SERIAL_OPL
//#define SERIAL_OPL_PORT 2

// Common OPL IO ports:
// QEMU/ISA sound card 0x388
// OPL2/3LPT on parallel port 0x3bc 0x378 0x278
// For FM801 after initialization base I/O port + 0x68

#ifdef FM801_OPL_BASE
#define ISA_IOPORT_OPL_BASE FM801_OPL_BASE
"Attempting to use alternate OPL IO port 0x%08x\n", ISA_IOPORT_OPL_BASE;
#else
#define ISA_IOPORT_OPL_BASE 0x388
#endif

#ifdef SERIAL_OPL
#ifdef SERIAL_OPL_PORT
#define FORCE_OPL_INIT 1
#endif
#endif

#ifdef OPL2LPT
#ifdef LPT_IOPORT_OPL_BASE
#define FORCE_OPL_INIT 1
#endif
#endif

/*
* This is a stripped down OPL2 for usage within TempleOS
*
* For use with qemu with -soundhw adlib
*
* This file supplies helper functions for 2-Operator FM sythesis base instruments.
*
* The user is of course able to play anything using WriteOPL.
*
* The following functions only effect the carrier not the modulator:
* SetAttack, SetDecay, SetSustain, SetRelease
*
*/

static U8 opl_registers[256];

static U8 **instruments[127]= {PIANO1,PIANO2,PIANO3,HONKTONK,EP1,EP2,HARPSIC,CLAVIC,CELESTA,GLOCK,MUSICBOX,VIBES,MARIMBA,XYLO,TUBEBELL,SANTUR,ORGAN1,ORGAN2,ORGAN3,PIPEORG,REEDORG,ACORDIAN,HARMONIC,BANDNEON,NYLONGT,STEELGT,JAZZGT,CLEANGT,MUTEGT,OVERDGT,DISTGT,GTHARMS,ACOUBASS,FINGBASS,PICKBASS,FRETLESS,SLAPBAS1,SLAPBAS2,SYNBASS1,SYNBASS2,VIOLIN,VIOLA,CELLO,CONTRAB,TREMSTR,PIZZ,HARP,TIMPANI,STRINGS,SLOWSTR,SYNSTR1,SYNSTR2,CHOIR,OOHS,SYNVOX,ORCHIT,TRUMPET,TROMBONE,TUBA,MUTETRP,FRHORN,BRASS1,SYNBRAS1,SYNBRAS2,SOPSAX,ALTOSAX,TENSAX,BARISAX,OBOE,ENGLHORN,BASSOON,CLARINET,PICCOLO,FLUTE1,RECORDER,PANFLUTE,BOTTLEB,SHAKU,WHISTLE,OCARINA,SQUARWAV,SAWWAV,SYNCALLI,CHIFLEAD,CHARANG,SOLOVOX,FIFTHSAW,BASSLEAD,FANTASIA,WARMPAD,POLYSYN,SPACEVOX,BOWEDGLS,METALPAD,HALOPAD,SWEEPPAD,ICERAIN,SOUNDTRK,CRYSTAL,ATMOSPH,BRIGHT,GOBLIN,ECHODROP,STARTHEM,SITAR,BANJO,SHAMISEN,KOTO,KALIMBA,BAGPIPE,FIDDLE,SHANNAI,TINKLBEL,AGOGO,STEELDRM,WOODBLOK,TAIKO,MELOTOM,SYNDRUM,REVRSCYM,FRETNOIS,BRTHNOIS,SEASHORE,BIRDS,TELEPHON,HELICOPT,APPLAUSE};

static U8 instrument_base_registers[6] = { 0x20, 0x40, 0x60, 0x80, 0xE0, 0xC0 };

// Channel Operator slot mapping for melodic voices
static I64 chan2op[9] = {0,1,2,8,9,10,16,17,18};

// One block value per channel
static I64 old_block[9];

// only first channel goes to screencast
// all are kept track of here
static I64 playing_onas[9];

#help_index "OPL"

#ifdef ISA_OPL
public U0 WriteOPL(I64 r, U8 data, I64 port=ISA_IOPORT_OPL_BASE)
{//Writes data to OPL registers
  I64 i;
  OutU8(port,r);
  for (i=0; i<4; i++) PortNop;
  OutU8(port+1,data);
  for (i=0; i<23; i++) PortNop;
}
// Usage assumes you have an OPL3 not OPL2
public U0 WriteOPL3(I64 port, I64 r, U8 data, I64 ioport=ISA_IOPORT_OPL_BASE)
{//Writes data to OPL registers
  I64 i;

  if (port)
  {
    OutU8(ioport+2,r);
    for (i=0; i<4; i++) PortNop;
    OutU8(ioport+3,data);
    for (i=0; i<23; i++) PortNop;
  }
  else
    WriteOPL(r,data,ioport);
}

#endif

#ifdef OPL2LPT
public U0 WriteOPL(I64 r, U8 data, I64 port=LPT_IOPORT_OPL_BASE)
{//Writes data to OPL registers
  I64 i;
  OutU8(port,r);
  OutU8(port+2,0x0d);
  OutU8(port+2,0x09);
  OutU8(port+2,0x0d);
  for (i=0; i<4; i++) PortNop;
  OutU8(port,data);
  OutU8(port+2,0x0c);
  OutU8(port+2,0x08);
  OutU8(port+2,0x0c);
  for (i=0; i<23; i++) PortNop;
}
#endif

#ifdef SERIAL_OPL
CommInit;
CommInit8n1(SERIAL_OPL_PORT,115200);

static Bool recording=FALSE;
static U64 commands=0;

public U0 WriteOPL(I64 r, U8 data, I64 func=0)
{//Writes data to OPL registers
  U8 bytes[3];
  bytes[0]=0x80 | ((func << 2)&0x7c)  | (r >> 6);
  bytes[1]=((r & 0x3F) << 1) | (data >> 7)&1;
  bytes[2]=data & 0x7f;
  CommPutBlk(SERIAL_OPL_PORT,bytes,3);
  PortNop;
  commands++;
}

// TODO make public when appropriate
U0 OPLRec()
{
  if (recording)
  {
    //CommPutChar(SERIAL_OPL_PORT,136);
    WriteOPL(0,0,8);
    "\nRecorded %d sent OPL2 commands\n"
    ,commands;
    commands=2;
  }
  else
  {
    commands=2;
    //CommPutChar(SERIAL_OPL_PORT,135);
    WriteOPL(0,0,4);
  }
  recording=!recording;
  PortNop;
}

U0 OPLReplay()
{//CommPutChar(SERIAL_OPL_PORT,137);
  WriteOPL(0,0,2);
  PortNop;
}
#endif

public Bool DetectOPL(I64 port=ISA_IOPORT_OPL_BASE)
{
  I64 x1=0,x2=0;
  WriteOPL(4,0x60,port);
  WriteOPL(4,0x80,port);
  x1=InU8(port)&0xe0;
  WriteOPL(2,0xff,port);
  WriteOPL(4,0x21,port);
  x2=InU8(port)&0xe0;
  WriteOPL(4,0x60,port);
  WriteOPL(4,0x80,port);
  if (x1==0 && x2==0xc0) {
    if (InU8(port)&0x06)
      "Found OPL2, enabling premium sound!\n";
    else "Found OPL3, enabling premium sound!\n";
    return TRUE;
  }
  return FALSE;
}

public U0 OPLReset()
{// Reset OPL chip
  I64 i;
  for(i = 0; i < 256; i ++)
  {
    opl_registers[i] = 0x00;
    WriteOPL(i, 0x00);
  }
  for (i=0;i<9;i++)
    old_block[i] = -1;
}

static U8 GetRegister(U8 r)
{
  return opl_registers[r];
}

static U8 SetRegister(U8 r, U8 val)
{
  opl_registers[r] = val;
  WriteOPL(r, val);
  return r;
}

static U0 SetBlock(I64 block, I64 chan=0)
{
  I64 r,c=ClampI64(chan,0,8);
  r = 0xB0 + c;
  SetRegister(r, (opl_registers[r] & 0xE3) | ((ClampI64(block,0,7) & 0x07) << 2));
  old_block[c]=block;
}

U0 SetAttack(I64 val, I64 chan=0)
{// Carrier only
  I64 c=ClampI64(chan,0,8);
  I64 r = 0x60 + chan2op[c] + 3;
  SetRegister(r, (opl_registers[r] & 0x0F) | ((ClampI64(val,0,15)&0x0F)<<4));
}

U0 SetDecay(I64 val, I64 chan=0)
{// Carrier only
  I64 r,c=ClampI64(chan,0,8);
  r = 0x60 + chan2op[c] + 3;
  SetRegister(r, (opl_registers[r] & 0xF0) | (ClampI64(val,0,15)&0x0F));
}

U0 SetSustain(I64 val, I64 chan=0)
{// Carrier only
  I64 r,c=ClampI64(chan,0,8);
  r = 0x80 + chan2op[c] + 3;
  SetRegister(r, (opl_registers[r] & 0x0F) | ((ClampI64(val,0,15)&0x0F)<<4));
}

U0 SetRelease(I64 val, I64 chan=0)
{// Carrier only
  I64 r,c=ClampI64(chan,0,8);
  r = 0x80 + chan2op[c] + 3;
  SetRegister(r, (opl_registers[r] & 0xF0) | (ClampI64(val,0,15)&0x0F));
}

static U0 SetVolReg(I64 val, I64 chan=0)
{// Carrier only (Total Level)
  I64 r,c=ClampI64(chan,0,8);
  r = 0x40 + chan2op[c] + 3;
  SetRegister(r, (opl_registers[r] & 0xC0) | (ClampI64(val,0,0x3F)&0x3F));
}

U0 SetVolume(I64 percent, I64 chan=0)
{
  if (!percent) Mute(1);
  else Mute(0);
  // TODO Mute and 200 divisor for QEMU
  // TODO limit with multiple channels to prevent clipping?
  SetVolReg(0x3f-ClampI64(percent*0x3f/200,0,0x3f), chan);
}

U0 SetInst(U8 *instrument, I64 chan=0)
{
  I64 base, i, opoff, c=ClampI64(chan,0,8);
  // Only melodic instruments for now
  SetRegister(0x01, opl_registers[0x01] | 0x20);

  for (i = 0; i < 11; i ++)
  {
    base = instrument_base_registers[i % 6];
    if (base == 0xC0)
    {
      // Channel feedback/connection register
      SetRegister(base + c, instrument[i + 1]);
    }
    else
    {
      // Operator registers: first 5 bytes -> mod, next 5 -> carrier
      opoff = chan2op[c];
      if (i > 5) opoff = (chan2op[c] + 3);
      SetRegister(base + opoff, instrument[i + 1]);
    }
  }
}

U8 SetFnum(I64 val, I64 chan=0)
{
  I64 r,c=ClampI64(chan,0,8);
  r = 0xA0 + c;
  SetRegister(r, val & 0x00FF);
  SetRegister(0xB0 + c,
      (opl_registers[0xB0+c] & 0xFC) |
      ((ClampI64(val,0,1023) & 0x0300) >> 8));
  return r;
}

U0 SetFreq(F64 freq, I64 chan=0)
{
  I64 c=ClampI64(chan,0,8);
  F64 fb_max=6208.431;
  I16 block=7,fnum=0;
  while (fb_max/2.0>freq && block>0)
  {
    block--;
    fb_max/=2.0;
  }
  fnum=ToI64(freq*2`(20-block)/49716.0);
  if (0<fnum<1024)
  {
    if (block!=old_block[c]) SetBlock(block,c);
    SetFnum(fnum,c);
  }
}

U8 SetKeyState(Bool state, I64 chan=0)
{
  I64 c=ClampI64(chan,0,8);
  I64 r = 0xB0 + c;
  if (state)
  {
    return SetRegister(r, opl_registers[r] | 0x20);
  }
  else
  {
    return SetRegister(r, opl_registers[r] & 0xDF);
  }
}

U0 SetOPLRegister(U8 r, U8 val)
{
  SetRegister(r,val);
}

U8 GetOPLRegister(U8 r)
{
  return opl_registers[r];
}

U0 OPLBeep(I64 chan=0)
{
  SetFreq(440.0,chan);
  SetKeyState(TRUE,chan);
  Sleep(1000);
  SetKeyState(FALSE,chan);
}

DefineLstLoad("ST_INSTRUMENTS","PIANO1\0PIANO2\0PIANO3\0HONKTONK\0EP1\0EP2\0HARPSIC\0CLAVIC\0CELESTA\0GLOCK\0MUSICBOX\0VIBES\0MARIMBA\0XYLO\0TUBEBELL\0SANTUR\0ORGAN1\0ORGAN2\0ORGAN3\0PIPEORG\0REEDORG\0ACORDIAN\0HARMONIC\0BANDNEON\0NYLONGT\0STEELGT\0JAZZGT\0CLEANGT\0MUTEGT\0OVERDGT\0DISTGT\0GTHARMS\0ACOUBASS\0FINGBASS\0PICKBASS\0FRETLESS\0SLAPBAS1\0SLAPBAS2\0SYNBASS1\0SYNBASS2\0VIOLIN\0VIOLA\0CELLO\0CONTRAB\0TREMSTR\0PIZZ\0HARP\0TIMPANI\0STRINGS\0SLOWSTR\0SYNSTR1\0SYNSTR2\0CHOIR\0OOHS\0SYNVOX\0ORCHIT\0TRUMPET\0TROMBONE\0TUBA\0MUTETRP\0FRHORN\0BRASS1\0SYNBRAS1\0SYNBRAS2\0SOPSAX\0ALTOSAX\0TENSAX\0BARISAX\0OBOE\0ENGLHORN\0BASSOON\0CLARINET\0PICCOLO\0FLUTE1\0RECORDER\0PANFLUTE\0BOTTLEB\0SHAKU\0WHISTLE\0OCARINA\0SQUARWAV\0SAWWAV\0SYNCALLI\0CHIFLEAD\0CHARANG\0SOLOVOX\0FIFTHSAW\0BASSLEAD\0FANTASIA\0WARMPAD\0POLYSYN\0SPACEVOX\0BOWEDGLS\0METALPAD\0HALOPAD\0SWEEPPAD\0ICERAIN\0SOUNDTRK\0CRYSTAL\0ATMOSPH\0BRIGHT\0GOBLIN\0ECHODROP\0STARTHEM\0SITAR\0BANJO\0SHAMISEN\0KOTO\0KALIMBA\0BAGPIPE\0FIDDLE\0SHANNAI\0TINKLBEL\0AGOGO\0STEELDRM\0WOODBLOK\0TAIKO\0MELOTOM\0SYNDRUM\0REVRSCYM\0FRETNOIS\0BRTHNOIS\0SEASHORE\0BIRDS\0TELEPHON\0HELICOPT\0APPLAUSE\0");

static U8 opl_inst_base[11]= {20,2,111,21,0,0,6,0,86,15,0};
static U8 opl_inst_mod1[11]= {128,64,128,128,16,2,128,32,128,128,2};
static U8 opl_inst_mod2[11]= {1,  1, 1,  1,  1, 1,1,  1, 1,  32, 1};

// 64-bit instrument is factored into an instrument as follows:
// 2^64 = 128*64*128*128*16*2*128*32*128*128*2
//        * 1* 1*  1*  1* 1*1*  1* 1*  1* 32*1

public U0 U64Inst(U64 inst, I64 chan=0)
{//Setup instrument registers from a 64-bit number
  I64 i;
  U8 opl2inst[12];
  opl2inst[0]=0;
  for (i=0; i<11; i++)
  {
    opl2inst[i+1]=opl_inst_base[i];
    opl2inst[i+1]+=inst%opl_inst_mod1[i];
    inst/=opl_inst_mod1[i];
    opl2inst[i+1]+=inst%opl_inst_mod2[i];
    inst/=opl_inst_mod2[i];
  }
  SetInst(opl2inst,chan);
}

public U64 RandInst(I64 chan=0)
{//Generate a random instrument from a random 64-bit number
  U64 inst=RandU64();
  SetKeyState(FALSE,chan);
  U64Inst(inst,chan);
  "Instrument number: %u = 0x%016x\n"
  ,inst,inst;
  return inst;
}

public I64 PickInst(I64 chan=0)
{//Popup a window to pick some standard instruments
  I64 ins;
  ins=PopUpPickDefineSub("ST_INSTRUMENTS");
  if (0<=ins<=127)
    SetInst(instruments[ins],chan);
  return ins;
}

public U0 PickInstLoop(Bool doc_clear=FALSE, I64 chan=0)
{//Keeps calling PickInst to open a new popup to change the instrument
  I64 ins;
  ins=PickInst(chan);
  while (ins>=0)
  {
    if (doc_clear) DocClear;
    OPLBeep(chan);
    "Using Instrument: %s\n"
    ,DefineSub(ins,"ST_INSTRUMENTS");
    ins=PickInst(chan);
  }
}


public U0 OPLSnd(I8 ona=0, I64 chan=0)
{//Play ona, a piano key num. 0 means rest.

  CSndData *d;
  if (!Bt(&sys_semas[SEMA_MUTE],0) &&
      !LBts(&sys_semas[SEMA_SND],0))   //Mutex. Just throw-out if in use
  {

    if (!chan)
    {
    if (!ona)
    {
      scrncast.ona=ona;
      playing_onas[chan]=ona;
      SetKeyState(FALSE,chan);
    }
    else if (ona!=scrncast.ona)
    {
      if (scrncast.ona)
        SetKeyState(FALSE,chan);
      scrncast.ona=ona;
      playing_onas[chan]=ona;
      SetFreq(Ona2Freq(ona),chan);
      SetKeyState(TRUE,chan);
    }
    if (!IsDbgMode && scrncast.record)
    {
      d=ACAlloc(sizeof(CSndData));
      d->ona=ona;
      d->tS=tS;
      QueIns(d,scrncast.snd_head.last);
    }
    LBtr(&sys_semas[SEMA_SND],0);
    }
    else {
    if (!ona)
    {
      playing_onas[chan]=ona;
      SetKeyState(FALSE,chan);
    }
    else if (ona!=playing_onas[chan])
    {
      if (playing_onas[chan])
        SetKeyState(FALSE,chan);
      playing_onas[chan]=ona;
      SetFreq(Ona2Freq(ona),chan);
      SetKeyState(TRUE,chan);
    }
    LBtr(&sys_semas[SEMA_SND],0);
    }

  }
}

public U0 OPLSnd0(I8 ona=0)
{
  OPLSnd(ona, 0);
}

public U0 OPLInit()
{//Reset OPL chip and set default square wave on channel 0-9.
  I64 i;
  OPLReset;
  for (i=0;i<1;i++)
  {
    SetInst(SQUARWAV,i);
    SetAttack(0xf,i);
    SetDecay(0xf,i);
    SetSustain(0,i);
    SetRelease(0xf,i);
  }
}

public U0 OPLSndRst()
{//Fix stuck sound.
  I64 i;
  for (i=0;i<9;i++)
    SetKeyState(FALSE,i);

  if (Bt(&sys_semas[SEMA_SND],0))
  {
    Sleep(1);
    if (Bt(&sys_semas[SEMA_SND],0))
    {
      Sleep(1);
      LBtr(&sys_semas[SEMA_SND],0);
    }
  }

  for (i=0;i<9;i++)
    SetKeyState(FALSE,i);

  OPLInit;
}


U0 HijackSndSystem()
{
  // Init new sound system
  OPLInit;
  // Reset old sound system
  Snd(0);
  SndRst;
  Mute(1);
  // Patch in new sound system
  LBts(&sys_semas[SEMA_SND],0);
  Yield;
  // Patch hook into sound system
  HijackFunc(&Snd,&OPLSnd0);
  HijackFunc(&SndM,&OPLSnd);
  HijackFunc(&SndRst,&OPLSndRst);
  LBtr(&sys_semas[SEMA_SND],0);
  Mute(0);
}

#ifdef ISA_OPL
U0 EnableISAOPL()
{
  if (DetectOPL)
    HijackSndSystem;
}

EnableISAOPL;
#endif

#ifdef FORCE_OPL_INIT
#ifdef OPL2LPT
AdamLog("Assuming OPL2/3LPT is connected and parallel port base is 0x%08x\n",LPT_IOPORT_OPL_BASE);
#endif
#ifdef SERIAL_OPL
AdamLog("Assuming OPL serial device is connected to com port %d\n",SERIAL_OPL_PORT);
#endif

HijackSndSystem;

#endif

#help_index ""
