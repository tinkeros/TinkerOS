lines_per_frame=262;
MCYCLES_PER_LINE=3420;
cycle_counter=0;

U0 GenSetRom(U8 *buffer, I64 size)
{
  MemSet(ROM,0,GEN_ROM_SIZE);
  MemSet(RAM,0,0x10000);
  MemSet(ZRAM,0,0x2000);
  MemCpy(ROM,buffer,size);
}

#define GEN_ADDR_MASK	0xFFFFFF

U32 read_memory(U32 address)
{
  U32 range;
  address&=GEN_ADDR_MASK;
  range=(address&0xFF0000)>>16;
  if (range<=0x3F)
    return ROM[address];
  else if (range==0xA0)
  {
    if (address>=0xA00000 && address<0xA04000)
      return ZRAM[address&0x1FFF];
    if (address>=0xA04000 && address<0xA04004)
      return YMReadStatus;
    return 0;
  }
  else if (range==0xA1)
  {
    if (address>=0xA10000 && address<0xA10020)
      return io_read_memory(address&0x1F);
    else if (address>=0xA11100 && address<0xA11300)
      return z80_ctrl_read(address&0xFFFF);
    return 0;
  }
  else if (range>=0xC0 && range<=0xDF)
    return vdp_read_byte(address);
  else if (range>=0xE0 && range<=0xFF)
    return RAM[address&0xFFFF];
  return 0;
}

U0 write_memory(U32 address, U32 value)
{
  U32 range;
  address&=GEN_ADDR_MASK;
  range=(address&0xFF0000)>>16;
  if (range<=0x3F)
  {
    ROM[address]=value;
    return;
  }
  else if (range==0xA0)
  {
    if (address>=0xA00000 && address<0xA04000)
      ZRAM[address&0x1FFF]=value;
    else if (address>=0xA04000 && address<0xA04004)
      YMWrite(address&3,value);
    return;
  }
  else if (range==0xA1)
  {
    if (address>=0xA10000 && address<0xA10020)
      io_write_memory(address&0x1F,value);
    else if (address>=0xA11100 && address<0xA11300)
      z80_ctrl_write(address&0xFFFF,value);
    return;
  }
  else if (range>=0xC0 && range<=0xDF)
  {
    value&=0xFF;
    if ((address&0x1F)<0x08)
      vdp_write(address,value|(value<<8));
    else if ((address&0x18)==0x10)
      PSGWrite(value);
    return;
  }
  else if (range>=0xE0 && range<=0xFF)
  {
    RAM[address&0xFFFF]=value;
    return;
  }
}

U32 m68k_read_memory_8(U32 address)
{
  return read_memory(address);
}

U32 m68k_read_memory_16(U32 address)
{
  U32 range;
  address&=GEN_ADDR_MASK;
  range=(address&0xFF0000)>>16;
  if (range>=0xC0 && range<=0xDF)
    return vdp_read(address);
  return (read_memory(address)<<8)|read_memory(address+1);
}

U32 m68k_read_memory_32(U32 address)
{
  return (m68k_read_memory_16(address)<<16)|
      m68k_read_memory_16(address+2);
}

U0 m68k_write_memory_8(U32 address, U32 value)
{
  write_memory(address,value);
}

U0 m68k_write_memory_16(U32 address, U32 value)
{
  U32 range;
  address&=GEN_ADDR_MASK;
  range=(address&0xFF0000)>>16;
  if (range>=0xC0 && range<=0xDF)
    vdp_write(address,value);
  else
  {
    write_memory(address,(value>>8)&0xFF);
    write_memory(address+1,value&0xFF);
  }
}

U0 m68k_write_memory_32(U32 address, U32 value)
{
  m68k_write_memory_16(address,(value>>16)&0xFFFF);
  m68k_write_memory_16(address+2,value&0xFFFF);
}

U0 GenSetIrq(I64 level)
{
  if ((m68ki_cpu.int_level>>8)>level)
    return;
  m68k_set_irq(level);
}

U0 GenExec(I64 mcycles)
{
  m68k_execute(mcycles);
  Z80Run(mcycles);
}

U0 GenFrame()
{
  I64 hint_counter=vdp_reg[10];
  cycle_counter=0;
  GenGenieFrame;
  screen_width=T(vdp_reg[12]&0x01,320,256);
  screen_height=T(vdp_reg[1]&0x08,240,224);
  vdp_clear_vblank;
  VDPClearCanvas;
  for (line=0; line<screen_height; line++)
  {
    GenExec(2560+120);
    vdp_render_line(line);
    if (--hint_counter<0)
    {
      hint_counter=vdp_reg[10];
      if (vdp_reg[0]&0x10)
        GenSetIrq(4);
    }
    vdp_set_hblank;
    GenExec(64+313+259);
    vdp_clear_hblank;
    GenExec(104);
  }
  vdp_set_vblank;
  GenExec(588);
  vdp_status|=0x80;
  GenExec(200);
  if (vdp_reg[1]&0x20)
    GenSetIrq(6);
  Z80SetIrq(TRUE);
  GenExec(3420-788);
  Z80SetIrq(FALSE);
  line++;
  for (; line<lines_per_frame; line++)
    GenExec(3420);
  GenSwapCanvas;
  GenSndFrame;
}
