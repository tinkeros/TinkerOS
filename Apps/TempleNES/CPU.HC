#define NES_CPU

#define FLAG_CARRY     0x01
#define FLAG_ZERO      0x02
#define FLAG_INTERRUPT 0x04
#define FLAG_DECIMAL   0x08
#define FLAG_BREAK     0x10
#define FLAG_CONSTANT  0x20
#define FLAG_OVERFLOW  0x40
#define FLAG_SIGN      0x80

#define BASE_STACK     0x100

U16 pc;
U8 sp, a, x, y, cpustatus;

U0 saveaccum(I64 n)
{
  a = ((n) & 0x00FF)(U8);
};

U32 instructions = 0;
I32 clockticks6502 = 0, clockgoal6502 = 0;
U16 oldpc, ea, reladdr, value, result;
U8 opcode, oldcpustatus, useaccum;

U8 penalty_addr, penalty_op;

U0 setcarry()
{
  cpustatus |= FLAG_CARRY;
}
U0 clearcarry()
{
  cpustatus &= (~FLAG_CARRY);
}
U0 setzero()
{
  cpustatus |= FLAG_ZERO;
}
U0 clearzero()
{
  cpustatus &= (~FLAG_ZERO);
}
U0 setinterrupt()
{
  cpustatus |= FLAG_INTERRUPT;
}
U0 clearinterrupt()
{
  cpustatus &= (~FLAG_INTERRUPT);
}
U0 setdecimal()
{
  cpustatus |= FLAG_DECIMAL;
}
U0 cleardecimal()
{
  cpustatus &= (~FLAG_DECIMAL);
}
U0 setoverflow()
{
  cpustatus |= FLAG_OVERFLOW;
}
U0 clearoverflow()
{
  cpustatus &= (~FLAG_OVERFLOW);
}
U0 setsign()
{
  cpustatus |= FLAG_SIGN;
}
U0 clearsign()
{
  cpustatus &= (~FLAG_SIGN);
}

U0 zerocalc(I64 n)
{
  if ((n) & 0x00FF) clearzero;
  else setzero;
}
U0 signcalc(I64 n)
{
  if ((n) & 0x0080) setsign;
  else clearsign;
}
U0 carrycalc(I64 n)
{
  if ((n) & 0xFF00) setcarry;
  else clearcarry;
}
U0 overflowcalc(I64 n, I64 m, I64 o)
{
  if (((n) ^ (m)(U16)) & ((n) ^ (o)) & 0x0080) setoverflow;
  else clearoverflow;
}

U0 push16(U16 pushval)
{
  writeRAM(BASE_STACK + sp, (pushval >> 8) & 0xFF);
  writeRAM(BASE_STACK + ((sp - 1) & 0xFF), pushval & 0xFF);
  sp -= 2;
}

U0 push8(U8 pushval)
{
  writeRAM(BASE_STACK + sp--, pushval);
}

U16 pull16()
{
  U16 temp16;
  temp16 = readRAM(BASE_STACK + ((sp + 1) & 0xFF)) | (readRAM(BASE_STACK + ((
                      sp + 2) & 0xFF))(U16) << 8);
  sp += 2;
  return (temp16);
}

U8 pull8()
{
  return (readRAM(BASE_STACK + ++sp));
}

U0 reset6502()
{
  pc = readRAM(0xFFFC)(U16) | (readRAM(0xFFFD)(U16) << 8);

  instructions = 0;
  clockgoal6502 = 0;
  clockticks6502 = 0;

  a = 0;
  x = 0;
  y = 0;
  sp = 0xFD;

  cpustatus = FLAG_CONSTANT | FLAG_INTERRUPT;
}

U0 imp()
{
}

U0 acc()
{
  useaccum = 1;
}

U0 imm()
{
  ea = pc++;
}

U0 zp()
{
  ea = readRAM(pc++)(U16);
}

U0 zpx()
{
  ea = (readRAM(pc++)(U16) + (x & 0xFF)) & 0xFF;
}

U0 zpy()
{
  ea = (readRAM(pc++)(U16) + (y & 0xFF)) & 0xFF;
}

U0 rel()
{
  reladdr = readRAM(pc++)(U16);
  if (reladdr & 0x80) reladdr |= 0xFF00;
}

U0 abso()
{
  ea = readRAM(pc)(U16) | (readRAM(pc+1)(U16) << 8);
  pc += 2;
}

U0 absx()
{
  U16 base;
  base = readRAM(pc)(U16) | (readRAM(pc+1)(U16) << 8);
  ea = base + (x & 0xFF);
  if ((base & 0xFF00) != (ea & 0xFF00))
    penalty_addr = 1;
  pc += 2;
}

U0 absy()
{
  U16 base;
  base = readRAM(pc)(U16) | (readRAM(pc+1)(U16) << 8);
  ea = base + (y & 0xFF);
  if ((base & 0xFF00) != (ea & 0xFF00))
    penalty_addr = 1;
  pc += 2;
}

U0 ind()
{
  U16 eahelp, eahelp2;
  eahelp = readRAM(pc)(U16) | (readRAM(pc+1)(U16) << 8)(U16);
  eahelp2 = (eahelp & 0xFF00) | ((eahelp + 1) & 0x00FF);
  ea = readRAM(eahelp)(U16) | (readRAM(eahelp2)(U16) << 8);
  pc += 2;
}

U0 indx()
{
  U16 eahelp;
  eahelp = ((readRAM(pc++)(U16) + (x & 0xFF)) & 0xFF)(U16);
  ea = readRAM(eahelp & 0x00FF)(U16) | (readRAM((eahelp+1) & 0x00FF)(U16) << 8);
}

U0 indy()
{
  U16 eahelp, eahelp2, base;
#ifdef NES_DIAG
  U8 dg_lo, dg_hi;
  U16 dg_pc = pc;
#endif
  eahelp = readRAM(pc++)(U16);
  eahelp2 = (eahelp & 0xFF00) | ((eahelp + 1) & 0x00FF);
#ifdef NES_DIAG
  dg_lo = readRAM(eahelp);
  dg_hi = readRAM(eahelp2);
  base = dg_lo(U16) | (dg_hi(U16) << 8);
#else
  base = readRAM(eahelp)(U16) | (readRAM(eahelp2)(U16) << 8);
#endif
  ea = base + (y & 0xFF);
  if ((base & 0xFF00) != (ea & 0xFF00))
    penalty_addr = 1;
#ifdef NES_DIAG
  if (nes_dg_indy_cnt < NES_INDY_MAX)
  {
    nes_dg_indy_instr[nes_dg_indy_cnt] = instructions;
    nes_dg_indy_pc[nes_dg_indy_cnt] = dg_pc;
    nes_dg_indy_eah[nes_dg_indy_cnt] = eahelp;
    nes_dg_indy_eah2[nes_dg_indy_cnt] = eahelp2;
    nes_dg_indy_lo[nes_dg_indy_cnt] = dg_lo;
    nes_dg_indy_hi[nes_dg_indy_cnt] = dg_hi;
    nes_dg_indy_base[nes_dg_indy_cnt] = base;
    nes_dg_indy_y[nes_dg_indy_cnt] = y;
    nes_dg_indy_p[nes_dg_indy_cnt] = cpustatus;
    nes_dg_indy_ea[nes_dg_indy_cnt] = ea;
    nes_dg_indy_cnt++;
  }
#endif
}

static U16 getvalue()
{
  if (useaccum) return (a & 0xFF);
  else return (readRAM(ea)(U16));
}

static U16 getvalue16()
{
  return (readRAM(ea)(U16) | (readRAM(ea+1)(U16) << 8));
}

U0 putvalue(U16 saveval)
{
  if (useaccum) a = (saveval & 0x00FF)(U8);
  else writeRAM(ea, (saveval & 0x00FF));
}

U0 adc()
{
  penalty_op = 1;
  value = getvalue;
  result = (a & 0xFF) + value + (cpustatus & FLAG_CARRY)(U16);

  carrycalc(result);
  zerocalc(result);
  overflowcalc(result, a, value);
  signcalc(result);

#ifndef NES_CPU
  if (cpustatus & FLAG_DECIMAL)
  {
    clearcarry;

    if ((a & 0x0F) > 0x09)
    {
      a += 0x06;
    }
    if ((a & 0xF0) > 0x90)
    {
      a += 0x60;
      setcarry;
    }

    clockticks6502++;
  }
#endif

  saveaccum(result);
}

U0 op_and()
{
  penalty_op = 1;
  value = getvalue;
  result = (a & 0xFF) & value;

  zerocalc(result);
  signcalc(result);

  saveaccum(result);
}

U0 asl()
{
  value = getvalue;
  result = value << 1;

  carrycalc(result);
  zerocalc(result);
  signcalc(result);

  putvalue(result);
}

U0 bcc()
{
  if ((cpustatus & FLAG_CARRY) == 0)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 bcs()
{
  if ((cpustatus & FLAG_CARRY) == FLAG_CARRY)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 beq()
{
  if ((cpustatus & FLAG_ZERO) == FLAG_ZERO)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 op_bit()
{
  value = getvalue;
  result = (a & 0xFF) & value;

  zerocalc(result);
  cpustatus = (cpustatus & 0x3F) | (value & 0xC0)(U8);
}

U0 bmi()
{
  if ((cpustatus & FLAG_SIGN) == FLAG_SIGN)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 bne()
{
  if ((cpustatus & FLAG_ZERO) == 0)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 bpl()
{
  if ((cpustatus & FLAG_SIGN) == 0)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 brk()
{
  pc++;
  push16(pc);
  push8(cpustatus | FLAG_BREAK);
  setinterrupt;
  pc = readRAM(0xFFFE)(U16) | (readRAM(0xFFFF)(U16) << 8);
}

U0 bvc()
{
  if ((cpustatus & FLAG_OVERFLOW) == 0)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 bvs()
{
  if ((cpustatus & FLAG_OVERFLOW) == FLAG_OVERFLOW)
  {
    oldpc = pc;
    pc += reladdr;
    if ((oldpc & 0xFF00) != (pc & 0xFF00)) clockticks6502 += 2;
    else clockticks6502++;
  }
}

U0 clc()
{
  clearcarry;
}

U0 cld()
{
  cleardecimal;
}

U0 cli()
{
  clearinterrupt;
}

U0 clv()
{
  clearoverflow;
}

U0 _cmp()
{
  penalty_op = 1;
  value = getvalue;
  result = (a & 0xFF) - value;

  if (a >= (value & 0x00FF)(U8)) setcarry;
  else clearcarry;
  if (a == (value & 0x00FF)(U8)) setzero;
  else clearzero;
  signcalc(result);
}

U0 cpx()
{
  value = getvalue;
  result = (x & 0xFF) - value;

  if (x >= (value & 0x00FF)(U8)) setcarry;
  else clearcarry;
  if (x == (value & 0x00FF)(U8)) setzero;
  else clearzero;
  signcalc(result);
}

U0 cpy()
{
  value = getvalue;
  result = (y & 0xFF) - value;

  if (y >= (value & 0x00FF)(U8)) setcarry;
  else clearcarry;
  if (y == (value & 0x00FF)(U8)) setzero;
  else clearzero;
  signcalc(result);
}

U0 dec()
{
  value = getvalue;
  result = value - 1;

  zerocalc(result);
  signcalc(result);

  putvalue(result);
}

U0 dex()
{
  x--;

  zerocalc(x);
  signcalc(x);
}

U0 dey()
{
  y--;

  zerocalc(y);
  signcalc(y);
}

U0 eor()
{
  penalty_op = 1;
  value = getvalue;
  result = (a & 0xFF) ^ value;

  zerocalc(result);
  signcalc(result);

  saveaccum(result);
}

U0 inc()
{
  value = getvalue;
  result = value + 1;

  zerocalc(result);
  signcalc(result);

  putvalue(result);
}

U0 inx()
{
  x++;

  zerocalc(x);
  signcalc(x);
}

U0 iny()
{
  y++;

  zerocalc(y);
  signcalc(y);
}

U0 jmp()
{
  pc = ea;
}

U0 jsr()
{
  push16(pc - 1);
  pc = ea;
}

U0 lda()
{
  penalty_op = 1;
  value = getvalue;
  a = (value & 0x00FF)(U8);

  zerocalc(a);
  signcalc(a);
}

U0 ldx()
{
  penalty_op = 1;
  value = getvalue;
  x = (value & 0x00FF)(U8);

  zerocalc(x);
  signcalc(x);
}

U0 ldy()
{
  penalty_op = 1;
  value = getvalue;
  y = (value & 0x00FF)(U8);

  zerocalc(y);
  signcalc(y);
}

U0 lsr()
{
  value = getvalue;
  result = value >> 1;

  if (value & 1) setcarry;
  else clearcarry;
  zerocalc(result);
  signcalc(result);

  putvalue(result);
}

U0 nop()
{
  penalty_op = 1;
}

U0 ora()
{
  penalty_op = 1;
  value = getvalue;
  result = (a & 0xFF) | value;

  zerocalc(result);
  signcalc(result);

  saveaccum(result);
}

U0 pha()
{
  push8(a);
}

U0 php()
{
  push8(cpustatus | FLAG_BREAK);
}

U0 pla()
{
  a = pull8;

  zerocalc(a);
  signcalc(a);
}

U0 plp()
{
  cpustatus = pull8() | FLAG_CONSTANT;
}

U0 rol()
{
  value = getvalue;
  result = (value << 1) | (cpustatus & FLAG_CARRY);

  carrycalc(result);
  zerocalc(result);
  signcalc(result);

  putvalue(result);
}

U0 ror()
{
  value = getvalue;
  result = (value >> 1) | ((cpustatus & FLAG_CARRY) << 7);

  if (value & 1) setcarry;
  else clearcarry;
  zerocalc(result);
  signcalc(result);

  putvalue(result);
}

U0 rti()
{
  cpustatus = pull8;
  value = pull16;
  pc = value;
}

U0 rts()
{
  value = pull16;
  pc = value + 1;
}

U0 sbc()
{
  penalty_op = 1;
  value = getvalue() ^ 0x00FF;
  result = (a & 0xFF) + value + (cpustatus & FLAG_CARRY)(U16);

  carrycalc(result);
  zerocalc(result);
  overflowcalc(result, a, value);
  signcalc(result);

#ifndef NES_CPU
  if (cpustatus & FLAG_DECIMAL)
  {
    clearcarry;

    a -= 0x66;
    if ((a & 0x0F) > 0x09)
    {
      a += 0x06;
    }
    if ((a & 0xF0) > 0x90)
    {
      a += 0x60;
      setcarry;
    }

    clockticks6502++;
  }
#endif

  saveaccum(result);
}

U0 sec()
{
  setcarry;
}

U0 sed()
{
  setdecimal;
}

U0 sei()
{
  setinterrupt;
}

U0 sta()
{
  putvalue(a);
}

U0 stx()
{
  putvalue(x);
}

U0 sty()
{
  putvalue(y);
}

U0 tax()
{
  x = a;

  zerocalc(x);
  signcalc(x);
}

U0 tay()
{
  y = a;

  zerocalc(y);
  signcalc(y);
}

U0 tsx()
{
  x = sp;

  zerocalc(x);
  signcalc(x);
}

U0 txa()
{
  a = x;

  zerocalc(a);
  signcalc(a);
}

U0 txs()
{
  sp = x;
}

U0 tya()
{
  a = y;

  zerocalc(a);
  signcalc(a);
}

#ifdef UNDOCUMENTED
U0 lax()
{
  penalty_op = 1;
  lda;
  ldx;
}

U0 sax()
{
  sta;
  stx;
  putvalue(a & x);
}

U0 dcp()
{
  dec;
  _cmp;
}

U0 isb()
{
  inc;
  sbc;
}

U0 slo()
{
  asl;
  ora;
}

U0 rla()
{
  rol;
  op_and;
}

U0 sre()
{
  lsr;
  eor;
}

U0 rra()
{
  ror;
  adc;
}
#else
#define lax nop
#define sax nop
#define dcp nop
#define isb nop
#define slo nop
#define rla nop
#define sre nop
#define rra nop
#endif

U0 nmi6502()
{
  push16(pc);
  push8(cpustatus);
  cpustatus |= FLAG_INTERRUPT;

  pc = readRAM(0xFFFA)(U16) | (readRAM(0xFFFB)(U16) << 8);
}

U0 irq6502()
{
  cpustatus &= (~FLAG_BREAK);
  push16(pc);
  push8(cpustatus);
  cpustatus |= FLAG_INTERRUPT;
  pc = readRAM(0xFFFE)(U16) | (readRAM(0xFFFF)(U16) << 8);
}

U8 ticktable[256] =
{
  7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
  2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
  6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
  2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
  6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
  2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
  6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
  2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
  2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
  2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
  2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
  2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
  2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
  2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
  2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
  2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7
};

U0 exec6502(I32 tickcount)
{
#ifdef USE_TIMING
  clockgoal6502 += tickcount;

  while (clockgoal6502 > 0)
  {
#else
  while (tickcount--)
  {
#endif
    opcode = readRAM(pc++);
    cpustatus |= FLAG_CONSTANT;
#ifdef NES_DIAG
    nes_dg_cur_instr = instructions;
    nes_dg_cur_pc = pc;
#endif

    useaccum = 0;
    clockticks6502 = 0;
    penalty_addr = 0;
    penalty_op = 0;

    switch (opcode)
    {
    case 0x0:
      imp;
      brk;
      break;
    case 0x1:
      indx;
      ora;
      break;
    case 0x5:
      zp;
      ora;
      break;
    case 0x6:
      zp;
      asl;
      break;
    case 0x8:
      imp;
      php;
      break;
    case 0x9:
      imm;
      ora;
      break;
    case 0xA:
      acc;
      asl;
      break;
    case 0xD:
      abso;
      ora;
      break;
    case 0xE:
      abso;
      asl;
      break;
    case 0x10:
      rel;
      bpl;
      break;
    case 0x11:
      indy;
      ora;
      break;
    case 0x15:
      zpx;
      ora;
      break;
    case 0x16:
      zpx;
      asl;
      break;
    case 0x18:
      imp;
      clc;
      break;
    case 0x19:
      absy;
      ora;
      break;
    case 0x1D:
      absx;
      ora;
      break;
    case 0x1E:
      absx;
      asl;
      break;
    case 0x20:
      abso;
      jsr;
      break;
    case 0x21:
      indx;
      op_and;
      break;
    case 0x24:
      zp;
      op_bit;
      break;
    case 0x25:
      zp;
      op_and;
      break;
    case 0x26:
      zp;
      rol;
      break;
    case 0x28:
      imp;
      plp;
      break;
    case 0x29:
      imm;
      op_and;
      break;
    case 0x2A:
      acc;
      rol;
      break;
    case 0x2C:
      abso;
      op_bit;
      break;
    case 0x2D:
      abso;
      op_and;
      break;
    case 0x2E:
      abso;
      rol;
      break;
    case 0x30:
      rel;
      bmi;
      break;
    case 0x31:
      indy;
      op_and;
      break;
    case 0x35:
      zpx;
      op_and;
      break;
    case 0x36:
      zpx;
      rol;
      break;
    case 0x38:
      imp;
      sec;
      break;
    case 0x39:
      absy;
      op_and;
      break;
    case 0x3D:
      absx;
      op_and;
      break;
    case 0x3E:
      absx;
      rol;
      break;
    case 0x40:
      imp;
      rti;
      break;
    case 0x41:
      indx;
      eor;
      break;
    case 0x45:
      zp;
      eor;
      break;
    case 0x46:
      zp;
      lsr;
      break;
    case 0x48:
      imp;
      pha;
      break;
    case 0x49:
      imm;
      eor;
      break;
    case 0x4A:
      acc;
      lsr;
      break;
    case 0x4C:
      abso;
      jmp;
      break;
    case 0x4D:
      abso;
      eor;
      break;
    case 0x4E:
      abso;
      lsr;
      break;
    case 0x50:
      rel;
      bvc;
      break;
    case 0x51:
      indy;
      eor;
      break;
    case 0x55:
      zpx;
      eor;
      break;
    case 0x56:
      zpx;
      lsr;
      break;
    case 0x58:
      imp;
      cli;
      break;
    case 0x59:
      absy;
      eor;
      break;
    case 0x5D:
      absx;
      eor;
      break;
    case 0x5E:
      absx;
      lsr;
      break;
    case 0x60:
      imp;
      rts;
      break;
    case 0x61:
      indx;
      adc;
      break;
    case 0x65:
      zp;
      adc;
      break;
    case 0x66:
      zp;
      ror;
      break;
    case 0x68:
      imp;
      pla;
      break;
    case 0x69:
      imm;
      adc;
      break;
    case 0x6A:
      acc;
      ror;
      break;
    case 0x6C:
      ind;
      jmp;
      break;
    case 0x6D:
      abso;
      adc;
      break;
    case 0x6E:
      abso;
      ror;
      break;
    case 0x70:
      rel;
      bvs;
      break;
    case 0x71:
      indy;
      adc;
      break;
    case 0x75:
      zpx;
      adc;
      break;
    case 0x76:
      zpx;
      ror;
      break;
    case 0x78:
      imp;
      sei;
      break;
    case 0x79:
      absy;
      adc;
      break;
    case 0x7D:
      absx;
      adc;
      break;
    case 0x7E:
      absx;
      ror;
      break;
    case 0x81:
      indx;
      sta;
      break;
    case 0x84:
      zp;
      sty;
      break;
    case 0x85:
      zp;
      sta;
      break;
    case 0x86:
      zp;
      stx;
      break;
    case 0x88:
      imp;
      dey;
      break;
    case 0x8A:
      imp;
      txa;
      break;
    case 0x8C:
      abso;
      sty;
      break;
    case 0x8D:
      abso;
      sta;
      break;
    case 0x8E:
      abso;
      stx;
      break;
    case 0x90:
      rel;
      bcc;
      break;
    case 0x91:
      indy;
      sta;
      break;
    case 0x94:
      zpx;
      sty;
      break;
    case 0x95:
      zpx;
      sta;
      break;
    case 0x96:
      zpy;
      stx;
      break;
    case 0x98:
      imp;
      tya;
      break;
    case 0x99:
      absy;
      sta;
      break;
    case 0x9A:
      imp;
      txs;
      break;
    case 0x9D:
      absx;
      sta;
      break;
    case 0xA0:
      imm;
      ldy;
      break;
    case 0xA1:
      indx;
      lda;
      break;
    case 0xA2:
      imm;
      ldx;
      break;
    case 0xA4:
      zp;
      ldy;
      break;
    case 0xA5:
      zp;
      lda;
      break;
    case 0xA6:
      zp;
      ldx;
      break;
    case 0xA8:
      imp;
      tay;
      break;
    case 0xA9:
      imm;
      lda;
      break;
    case 0xAA:
      imp;
      tax;
      break;
    case 0xAC:
      abso;
      ldy;
      break;
    case 0xAD:
      abso;
      lda;
      break;
    case 0xAE:
      abso;
      ldx;
      break;
    case 0xB0:
      rel;
      bcs;
      break;
    case 0xB1:
      indy;
      lda;
      break;
    case 0xB4:
      zpx;
      ldy;
      break;
    case 0xB5:
      zpx;
      lda;
      break;
    case 0xB6:
      zpy;
      ldx;
      break;
    case 0xB8:
      imp;
      clv;
      break;
    case 0xB9:
      absy;
      lda;
      break;
    case 0xBA:
      imp;
      tsx;
      break;
    case 0xBC:
      absx;
      ldy;
      break;
    case 0xBD:
      absx;
      lda;
      break;
    case 0xBE:
      absy;
      ldx;
      break;
    case 0xC0:
      imm;
      cpy;
      break;
    case 0xC1:
      indx;
      _cmp;
      break;
    case 0xC4:
      zp;
      cpy;
      break;
    case 0xC5:
      zp;
      _cmp;
      break;
    case 0xC6:
      zp;
      dec;
      break;
    case 0xC8:
      imp;
      iny;
      break;
    case 0xC9:
      imm;
      _cmp;
      break;
    case 0xCA:
      imp;
      dex;
      break;
    case 0xCC:
      abso;
      cpy;
      break;
    case 0xCD:
      abso;
      _cmp;
      break;
    case 0xCE:
      abso;
      dec;
      break;
    case 0xD0:
      rel;
      bne;
      break;
    case 0xD1:
      indy;
      _cmp;
      break;
    case 0xD5:
      zpx;
      _cmp;
      break;
    case 0xD6:
      zpx;
      dec;
      break;
    case 0xD8:
      imp;
      cld;
      break;
    case 0xD9:
      absy;
      _cmp;
      break;
    case 0xDD:
      absx;
      _cmp;
      break;
    case 0xDE:
      absx;
      dec;
      break;
    case 0xE0:
      imm;
      cpx;
      break;
    case 0xE1:
      indx;
      sbc;
      break;
    case 0xE4:
      zp;
      cpx;
      break;
    case 0xE5:
      zp;
      sbc;
      break;
    case 0xE6:
      zp;
      inc;
      break;
    case 0xE8:
      imp;
      inx;
      break;
    case 0xE9:
      imm;
      sbc;
      break;
    case 0xEA:
      imp;
      nop;
      break;
    case 0xEB:
      imm;
      sbc;
      break;
    case 0xEC:
      abso;
      cpx;
      break;
    case 0xED:
      abso;
      sbc;
      break;
    case 0xEE:
      abso;
      inc;
      break;
    case 0xF0:
      rel;
      beq;
      break;
    case 0xF1:
      indy;
      sbc;
      break;
    case 0xF5:
      zpx;
      sbc;
      break;
    case 0xF6:
      zpx;
      inc;
      break;
    case 0xF8:
      imp;
      sed;
      break;
    case 0xF9:
      absy;
      sbc;
      break;
    case 0xFD:
      absx;
      sbc;
      break;
    case 0xFE:
      absx;
      inc;
      break;
    default:
      nes_badop_cnt++;
      nes_badop_last = opcode;
      nes_badop_pc = pc - 1;
      nes_badop_bank = nes_last_ld16_bank;
      nes_badop_seq = nes_ld16_seq;
      break;
    }
    if (penalty_addr && penalty_op)
      clockticks6502++;
#ifdef USE_TIMING
    clockgoal6502 -= ticktable[opcode](I32) + clockticks6502;
#endif
    instructions++;
  }
}
