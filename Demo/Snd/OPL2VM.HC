#include "/Demo/Snd/Midi.HH"

// Pick one, then configure below

// QEMU / Real ISA Adlib card
#define ISA_OPL
// OPT2LPT or OPL3LPT connected via a parallel port
//#define OPL2LPT
// Serial OPL device
//#define SERIAL_OPL

// Common OPL IO ports:
// QEMU/ISA sound card 0x388
// OPL2/3LPT on parallel port 0x3bc 0x378 0x278
#define ISA_IOPORT_OPL_BASE 0x388
#define LPT_IOPORT_OPL_BASE 0x378
#define SERIAL_OPL_PORT 2

/*
* This is a stripped own OPL2 implementation for single instrument usage within TempleOS
*
* For use with qemu with -soundhw adlib
*
* This uses 2-Operator FM sythesis only.
*
* The following functions only effect the carrier not the modulator:
* SetAttack, SetDecay, SetSustain, SetRelease
*
*/

static U8 opl_registers[256];

static U8 **instruments[127]= {PIANO1,PIANO2,PIANO3,HONKTONK,EP1,EP2,HARPSIC,CLAVIC,CELESTA,GLOCK,MUSICBOX,VIBES,MARIMBA,XYLO,TUBEBELL,SANTUR,ORGAN1,ORGAN2,ORGAN3,PIPEORG,REEDORG,ACORDIAN,HARMONIC,BANDNEON,NYLONGT,STEELGT,JAZZGT,CLEANGT,MUTEGT,OVERDGT,DISTGT,GTHARMS,ACOUBASS,FINGBASS,PICKBASS,FRETLESS,SLAPBAS1,SLAPBAS2,SYNBASS1,SYNBASS2,VIOLIN,VIOLA,CELLO,CONTRAB,TREMSTR,PIZZ,HARP,TIMPANI,STRINGS,SLOWSTR,SYNSTR1,SYNSTR2,CHOIR,OOHS,SYNVOX,ORCHIT,TRUMPET,TROMBONE,TUBA,MUTETRP,FRHORN,BRASS1,SYNBRAS1,SYNBRAS2,SOPSAX,ALTOSAX,TENSAX,BARISAX,OBOE,ENGLHORN,BASSOON,CLARINET,PICCOLO,FLUTE1,RECORDER,PANFLUTE,BOTTLEB,SHAKU,WHISTLE,OCARINA,SQUARWAV,SAWWAV,SYNCALLI,CHIFLEAD,CHARANG,SOLOVOX,FIFTHSAW,BASSLEAD,FANTASIA,WARMPAD,POLYSYN,SPACEVOX,BOWEDGLS,METALPAD,HALOPAD,SWEEPPAD,ICERAIN,SOUNDTRK,CRYSTAL,ATMOSPH,BRIGHT,GOBLIN,ECHODROP,STARTHEM,SITAR,BANJO,SHAMISEN,KOTO,KALIMBA,BAGPIPE,FIDDLE,SHANNAI,TINKLBEL,AGOGO,STEELDRM,WOODBLOK,TAIKO,MELOTOM,SYNDRUM,REVRSCYM,FRETNOIS,BRTHNOIS,SEASHORE,BIRDS,TELEPHON,HELICOPT,APPLAUSE};

static U8 instrument_base_registers[6] = { 0x20, 0x40, 0x60, 0x80, 0xE0, 0xC0 };

static I64 old_block=-1;

#ifdef OPL2LPT
static U0 Write(I64 r, U8 data)
{
  I64 i;
  OutU8(LPT_IOPORT_OPL_BASE,r);
  OutU8(LPT_IOPORT_OPL_BASE+2,0x0d);
  OutU8(LPT_IOPORT_OPL_BASE+2,0x09);
  OutU8(LPT_IOPORT_OPL_BASE+2,0x0d);
  for (i=0; i<4; i++) PortNop;
  OutU8(LPT_IOPORT_OPL_BASE,data);
  OutU8(LPT_IOPORT_OPL_BASE+2,0x0c);
  OutU8(LPT_IOPORT_OPL_BASE+2,0x08);
  OutU8(LPT_IOPORT_OPL_BASE+2,0x0c);
  for (i=0; i<23; i++) PortNop;
}
#endif

#ifdef ISA_OPL
static U0 Write(I64 r, U8 data)
{
  I64 i;
  OutU8(ISA_IOPORT_OPL_BASE,r);
  for (i=0; i<4; i++) PortNop;
  OutU8(ISA_IOPORT_OPL_BASE+1,data);
  for (i=0; i<23; i++) PortNop;
}
#endif

#ifdef SERIAL_OPL
CommInit;
CommInit8n1(SERIAL_OPL_PORT,115200);

static Bool recording=FALSE;
static U64 commands=0;

static U0 Write(I64 r, U8 data, I64 func=0)
{
  U8 bytes[3];
  bytes[0]=0x80 | ((func << 2)&0x7c)  | (r >> 6);
  bytes[1]=((r & 0x3F) << 1) | (data >> 7)&1;
  bytes[2]=data & 0x7f;
  CommPutBlk(SERIAL_OPL_PORT,bytes,3);
  PortNop;
  commands++;
}

public U0 OPLRec()
{
  if (recording)
  {
    //CommPutChar(SERIAL_OPL_PORT,136);
    Write(0,0,8);
    "\nRecorded %d sent OPL2 commands\n"
    ,commands;
    commands=2;
  }
  else
  {
    commands=2;
    //CommPutChar(SERIAL_OPL_PORT,135);
    Write(0,0,4);
  }
  recording=!recording;
  PortNop;
}

public U0 OPLReplay()
{//CommPutChar(SERIAL_OPL_PORT,137);
  Write(0,0,2);
  PortNop;
}
#endif

public U0 AdlibReset()
{
  I64 i;
  for(i = 0; i < 256; i ++)
  {
    opl_registers[i] = 0x00;
  }
  for(i = 0; i < 256; i ++)
  {
    Write(i, 0x00);
  }
}

static U8 GetRegister(U8 r)
{
  return opl_registers[r];
}

static U8 SetRegister(U8 r, U8 val)
{
  opl_registers[r] = val;
  Write(r, val);
  return r;
}

static U0 SetBlock(I64 block)
{
  I64 r = 0xB0;
  SetRegister(r, (opl_registers[r] & 0xE3) | ((ClampI64(block,0,7) & 0x07) << 2));
  old_block=block;
}

U0 SetAttack(I64 val)
{
  I64 r = 0x60;
  SetRegister(r, (opl_registers[r] & 0x0F) | ((ClampI64(val,0,15)&0x0F)<<4));
}

U0 SetDecay(I64 val)
{
  I64 r = 0x60;
  SetRegister(r, (opl_registers[r] & 0xF0) | (ClampI64(val,0,15)&0x0F));
}

U0 SetSustain(I64 val)
{
  I64 r = 0x80;
  SetRegister(r, (opl_registers[r] & 0x0F) | ((ClampI64(val,0,15)&0x0F)<<4));
}

U0 SetRelease(I64 val)
{
  I64 r = 0x80;
  SetRegister(r, (opl_registers[r] & 0xF0) | (ClampI64(val,0,15)&0x0F));
}

static U0 SetVolReg(I64 val)
{
  I64 r = 0x40;
  SetRegister(r, (opl_registers[r] & 0xC0) | (ClampI64(val,0,0x3F)&0x3F));
}

U0 SetVolume(I64 percent)
{
  if (!percent) Mute(1);
  else Mute(0);
  // TODO Mute and 200 divisor for QEMU
  SetVolReg(0x3f-ClampI64(percent*0x3f/200,0,0x3f));
}

U0 SetInst(U8 *instrument)
{
  I64 i;
  // Only melodic instruments for now
  SetRegister(0x01, opl_registers[0x01] | 0x20);
  for (i = 0; i < 11; i ++)
  {
    SetRegister(instrument_base_registers[i % 6] + 3*(i > 5), instrument[i + 1]);
  }
}

U8 SetFnum(I64 val)
{
  I64 r = 0xA0;
  SetRegister(r, val & 0x00FF);
  SetRegister(r + 0x10, (opl_registers[r + 0x10] & 0xFC) | ((ClampI64(val,0,1023) & 0x0300) >> 8));
  return r;
}

U0 SetFreq(F64 freq)
{
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
    if (block!=old_block) SetBlock(block);
    SetFnum(fnum);
  }
}

U8 SetKeyState(Bool state)
{
  I64 r = 0xB0;
  if (state)
  {
    return SetRegister(r, opl_registers[r] | 0x20);
  }
  else
  {
    return SetRegister(r, opl_registers[r] & 0xDF);
  }
}

public U0 SetOPLRegister(U8 r, U8 val)
{
  SetRegister(r,val);
}

public U8 GetOPLRegister(U8 r)
{
  return opl_registers[r];
}

public U0 AdlibBeep()
{
  SetFreq(440.0);
  SetKeyState(TRUE);
  Sleep(1000);
  SetKeyState(FALSE);
}

DefineLstLoad("ST_INSTRUMENTS","PIANO1\0PIANO2\0PIANO3\0HONKTONK\0EP1\0EP2\0HARPSIC\0CLAVIC\0CELESTA\0GLOCK\0MUSICBOX\0VIBES\0MARIMBA\0XYLO\0TUBEBELL\0SANTUR\0ORGAN1\0ORGAN2\0ORGAN3\0PIPEORG\0REEDORG\0ACORDIAN\0HARMONIC\0BANDNEON\0NYLONGT\0STEELGT\0JAZZGT\0CLEANGT\0MUTEGT\0OVERDGT\0DISTGT\0GTHARMS\0ACOUBASS\0FINGBASS\0PICKBASS\0FRETLESS\0SLAPBAS1\0SLAPBAS2\0SYNBASS1\0SYNBASS2\0VIOLIN\0VIOLA\0CELLO\0CONTRAB\0TREMSTR\0PIZZ\0HARP\0TIMPANI\0STRINGS\0SLOWSTR\0SYNSTR1\0SYNSTR2\0CHOIR\0OOHS\0SYNVOX\0ORCHIT\0TRUMPET\0TROMBONE\0TUBA\0MUTETRP\0FRHORN\0BRASS1\0SYNBRAS1\0SYNBRAS2\0SOPSAX\0ALTOSAX\0TENSAX\0BARISAX\0OBOE\0ENGLHORN\0BASSOON\0CLARINET\0PICCOLO\0FLUTE1\0RECORDER\0PANFLUTE\0BOTTLEB\0SHAKU\0WHISTLE\0OCARINA\0SQUARWAV\0SAWWAV\0SYNCALLI\0CHIFLEAD\0CHARANG\0SOLOVOX\0FIFTHSAW\0BASSLEAD\0FANTASIA\0WARMPAD\0POLYSYN\0SPACEVOX\0BOWEDGLS\0METALPAD\0HALOPAD\0SWEEPPAD\0ICERAIN\0SOUNDTRK\0CRYSTAL\0ATMOSPH\0BRIGHT\0GOBLIN\0ECHODROP\0STARTHEM\0SITAR\0BANJO\0SHAMISEN\0KOTO\0KALIMBA\0BAGPIPE\0FIDDLE\0SHANNAI\0TINKLBEL\0AGOGO\0STEELDRM\0WOODBLOK\0TAIKO\0MELOTOM\0SYNDRUM\0REVRSCYM\0FRETNOIS\0BRTHNOIS\0SEASHORE\0BIRDS\0TELEPHON\0HELICOPT\0APPLAUSE\0");

static U8 base[11]= {20,2,111,21,0,0,6,0,86,15,0};
static U8 mod1[11]= {128,64,128,128,16,2,128,32,128,128,2};
static U8 mod2[11]= {1,  1, 1,  1,  1, 1,1,  1, 1,  32, 1};

// 64-bit instrument is factored into an instrument as follows:
// 2^64 = 128*64*128*128*16*2*128*32*128*128*2
//        * 1* 1*  1*  1* 1*1*  1* 1*  1* 32*1

U0 U64Inst(U64 inst)
{// Setup an instruments registers from a 64-bit number
  I64 i;
  U8 opl2inst[12];
  opl2inst[0]=0;
  for (i=0; i<11; i++)
  {
    opl2inst[i+1]=base[i];
    opl2inst[i+1]+=inst%mod1[i];
    inst/=mod1[i];
    opl2inst[i+1]+=inst%mod2[i];
    inst/=mod2[i];
  }
  SetInst(opl2inst);
}

U64 RandInst()
{// Generate a random instrument from a random 64-bit number
  U64 inst=RandU64();
  SetKeyState(FALSE);
  U64Inst(inst);
  "Instrument number: %u = 0x%016x\n"
  ,inst,inst;
  return inst;
}

I64 PickInst()
{// Popup a window to pick some standard instruments
  I64 ins;
  ins=PopUpPickDefineSub("ST_INSTRUMENTS");
  if (0<=ins<=127)
    SetInst(instruments[ins]);
  return ins;
}

U0 PickInstLoop(Bool doc_clear=FALSE)
{// Keeps calling PickInst to open a new popup to change the instrument
  I64 ins;
  ins=PickInst;
  while (ins>=0)
  {
    if (doc_clear) DocClear;
    AdlibBeep;
    "Using Instrument: %s\n"
    ,DefineSub(ins,"ST_INSTRUMENTS");
    ins=PickInst;
  }
}

U0 AdlibSnd(I8 ona=0)
{//Play ona, a piano key num. 0 means rest.
  CSndData *d;
  if (!Bt(&sys_semas[SEMA_MUTE],0) &&
      !LBts(&sys_semas[SEMA_SND],0))   //Mutex. Just throw-out if in use
  {
    if (!ona)
    {
      scrncast.ona=ona;
      SetKeyState(FALSE);
    }
    else if (ona!=scrncast.ona)
    {
      if (scrncast.ona)
        SetKeyState(FALSE);
      scrncast.ona=ona;
      SetFreq(Ona2Freq(ona));
      SetKeyState(TRUE);
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
}

public U0 AdlibInit()
{
  AdlibReset;
  SetInst(SQUARWAV);
  SetAttack(0xf);
  SetDecay(0xf);
  SetSustain(0);
  SetRelease(0xf);
}

AdlibInit;

// Patch hook into sound system
Snd(0);
Mute(1);
LBts(&sys_semas[SEMA_SND],0);
Yield;
*(&Snd(U8*))=0xe9;
*((&Snd+1)(U32*))=&AdlibSnd-&Snd-5;
LBtr(&sys_semas[SEMA_SND],0);
Mute(0);


