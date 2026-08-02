
class CNESMMU
{
  U8 *RAM;
  U8 *VRAM;
  U8 *OAM;

  U8 w;
  U16 t;
  U16 x;
  U16 y;

  U16 VRAM_address;
  U8 internal_buffer;
};

CNESMMU MMU;

U8 readVRAM(U16 address)
{

  if (address >= 0x2000 && address < 0x3F00)
  {
    switch (mirroringType)
    {
    case MIRR_HORZ:
      if (address >= 0x2400 && address < 0x2800)
      {
        address -= 0x0400;
      }
      else if (address >= 0x2C00 && address < 0x3000)
      {
        address -= 0x0400;
      }
      break;
    case MIRR_VERT:
      if (address >= 0x2800 && address < 0x2C00)
      {
        address -= 0x0800;
      }
      else if (address >= 0x2C00 && address < 0x3000)
      {
        address -= 0x0800;
      }
      break;
    case MIRR_SINGLE:
      address &= 0x23FF;
      break;
    case MIRR_SINGLE_UPPER:
      address = 0x2400 | (address & 0x03FF);
      break;
    case MIRR_FOUR:

      break;
    }
  }
  return MMU.VRAM[address & 0x3FFF];
}

U0 writeVRAM(U16 address, U8 value)
{

  if (address >= 0x2000 && address < 0x3F00)
  {
    switch (mirroringType)
    {
    case MIRR_HORZ:
      if (address >= 0x2400 && address < 0x2800)
      {
        address -= 0x0400;
      }
      else if (address >= 0x2C00 && address < 0x3000)
      {
        address -= 0x0400;
      }
      break;
    case MIRR_VERT:
      if (address >= 0x2800 && address < 0x2C00)
      {
        address -= 0x0800;
      }
      else if (address >= 0x2C00 && address < 0x3000)
      {
        address -= 0x0800;
      }
      break;
    case MIRR_SINGLE:
      address &= 0x23FF;
      break;
    case MIRR_SINGLE_UPPER:
      address = 0x2400 | (address & 0x03FF);
      break;
    case MIRR_FOUR:

      break;
    }
  }
  if (numCHRROM && (address & 0x3FFF) < 0x2000)
    return;
  MMU.VRAM[address & 0x3FFF] = value;
#ifdef NES_DIAG
  if ((address & 0x3FFF) >= 0x3F00 && (address & 0x3FFF) <= 0x3F1F)
  {
    nes_dg_palw++;
    if (nes_dg_palw_frame < 0)
      nes_dg_palw_frame = nes_dg_frame;
  }
#endif
}

I64 MMC1_regBuffer = 0;
I64 MMC1_regBufferCounter = 0;

I64 MMC1_mirroring = 0;
I64 MMC1_prgSwitchingArea = 1;
I64 MMC1_prgSwitchingSize = 1;
I64 MMC1_vromSwitchingSize = 0;

I64 MMC1_romSelectionReg0 = 0;

I64 MMC1_romSelectionReg1 = 0;

I64 MMC1_romBankSelect = 0;

I64 MMC1_getRegNumber(U16 address)
{
  if (address >= 0x8000 && address <= 0x9fff)
  {
    return 0;
  }
  else if (address >= 0xa000 && address <= 0xbfff)
  {
    return 1;
  }
  else if (address >= 0xc000 && address <= 0xdfff)
  {
    return 2;
  }
  else
  {
    return 3;
  }
}

U0 LoadPrgBank16k(I64 bank, U16 address)
{
  bank = bank % numPRGROM;
  nes_last_ld16_bank = bank;
  nes_last_ld16_addr = address;
  nes_ld16_seq++;
  MemCpy(MMU.RAM + address, cartridgebuffer + 0x10 + 0x4000 * bank, 0x4000);
}

U0 LoadPrgBank32k(I64 bank, U16 address)
{
  if (numPRGROM > 1)
    bank = bank % (numPRGROM / 2);
  else
    bank = 0;
  MemCpy(MMU.RAM + address, cartridgebuffer + 0x10 + 0x8000 * bank, 0x8000);
}

U0 LoadChrBank4k(I64 bank, U16 address)
{

  bank = bank % (numCHRROM * 2);
  MemCpy(MMU.VRAM + address, cartridgebuffer + 0x10 + 0x4000 * numPRGROM + 0x1000 * bank,
      0x1000);
}

U0 LoadChrBank8k(I64 bank, U16 address)
{

  LoadChrBank4k(bank & ~1, address);
  LoadChrBank4k((bank & ~1) + 1, address + 0x1000);
}

U0 MMC1_setReg(I64 _reg, I64 value)
{
  I64 tmp;
  switch (_reg)
  {
  case 0:

    tmp = value & 3;
    if (tmp != MMC1_mirroring)
    {

      MMC1_mirroring = tmp;
      if (MMC1_mirroring & 0x02)
      {
        if (MMC1_mirroring & 0x01)
        {
          mirroringType = MIRR_HORZ;
        }
        else
        {
          mirroringType = MIRR_VERT;
        }
      }
      else
      {

        if (MMC1_mirroring & 0x01)
        {
          mirroringType = MIRR_SINGLE_UPPER;
        }
        else
        {
          mirroringType = MIRR_SINGLE;
        }
      }

    }

    MMC1_prgSwitchingArea = (value >> 2) & 1;

    MMC1_prgSwitchingSize = (value >> 3) & 1;

    MMC1_vromSwitchingSize = (value >> 4) & 1;
    break;
  case 1:

    MMC1_romSelectionReg0 = (value >> 4) & 1;

    if (numCHRROM > 0)
    {

      if (MMC1_vromSwitchingSize == 0)
      {

        LoadChrBank8k(value & 0x1f, 0x0000);
      }
      else
      {

        LoadChrBank4k(value & 0x1f, 0x0000);
      }
    }
    break;
  case 2:

    MMC1_romSelectionReg1 = (value >> 4) & 1;

    if (numCHRROM > 0)
    {

      if (MMC1_vromSwitchingSize == 1)
      {
        LoadChrBank4k(value & 0x1f, 0x1000);
      }
    }
    break;
  default:

    tmp = value & 0xf;
    I64 bank;
    I64 baseBank = 0;
    if (numPRGROM >= 32)
    {

      if (MMC1_vromSwitchingSize == 0)
      {
        if (MMC1_romSelectionReg0 == 1)
        {
          baseBank = 16;
        }
      }
      else
      {
        baseBank = (MMC1_romSelectionReg0 | (MMC1_romSelectionReg1 << 1)) << 3;
      }
    }
    else if (numPRGROM >= 16)
    {

      if (MMC1_romSelectionReg0 == 1)
      {
        baseBank = 8;
      }
    }
    if (MMC1_prgSwitchingSize == 0)
    {

      bank = baseBank + (value & 0xf);
      LoadPrgBank32k(bank, 0x8000);
    }
    else
    {

      bank = baseBank * 2 + (value & 0xf);
      if (MMC1_prgSwitchingArea == 0)
      {
        LoadPrgBank16k(bank, 0xc000);
      }
      else
      {
        LoadPrgBank16k(bank, 0x8000);
      }
    }
  }
}

U0 MMC1_Write(U16 address, U8 value)
{

  if ((value & 128) != 0)
  {

    MMC1_regBufferCounter = 0;
    MMC1_regBuffer = 0;

    if (MMC1_getRegNumber(address) == 0)
    {
      MMC1_prgSwitchingArea = 1;
      MMC1_prgSwitchingSize = 1;
    }
  }
  else
  {

    MMC1_regBuffer = (MMC1_regBuffer & (0xff - (1 << MMC1_regBufferCounter))) | ((
                value & 1) << MMC1_regBufferCounter);
    MMC1_regBufferCounter++;
    if (MMC1_regBufferCounter == 5)
    {

      MMC1_setReg(MMC1_getRegNumber(address), MMC1_regBuffer);

      MMC1_regBuffer = 0;
      MMC1_regBufferCounter = 0;
    }
  }
}

U0 UNROM_Write(U16 address, U8 value)
{
  LoadPrgBank16k(value, 0x8000);
}

U0 CNROM_Write(U16 address, U8 value)
{
  I64 bank;
  bank = value % numCHRROM;
  MemCpy(MMU.VRAM, cartridgebuffer + 0x10 + 0x4000 * numPRGROM + 0x2000 * bank, 0x2000);
}

U0 AxROM_Write(U16 address, U8 value)
{
  LoadPrgBank32k(value & 7, 0x8000);
  if (value & 0x10)
    mirroringType = MIRR_SINGLE_UPPER;
  else
    mirroringType = MIRR_SINGLE;
}

I64 MMC3_Regs[8];
I64 MMC3_Prg0 = 0;
I64 MMC3_Prg1 = 1;
I64 MMC3_PrgBankMode = 0;
I64 MMC3_ChrBankMode = 0;
I64 MMC3_Command = 0;
I64 MMC3_IrqLatch = 0;
I64 MMC3_IrqCounter = 0;
I64 MMC3_IrqReload = FALSE;
I64 MMC3_IrqEnable = FALSE;

U0 LoadPrgBank8k(I64 bank, U16 address)
{
  I64 totalBanks = numPRGROM * 2;
  MemCpy(MMU.RAM + address, cartridgebuffer + 0x10 + 0x2000 * (bank % totalBanks), 0x2000);
}

U0 LoadChrBank1k(I64 bank, U16 address)
{

  I64 totalBanks = numCHRROM * 8;
  MemCpy(MMU.VRAM + address, cartridgebuffer + 0x10 + 0x4000 * numPRGROM + 0x400 *
      (bank % totalBanks), 0x400);
}

U0 MMC3_SetPrgBanks()
{
  I64 lastBank = numPRGROM * 2 - 1;
  I64 secondLastBank = numPRGROM * 2 - 2;
  if (MMC3_PrgBankMode == 0)
  {
    LoadPrgBank8k(MMC3_Prg0, 0x8000);
    LoadPrgBank8k(MMC3_Prg1, 0xa000);
    LoadPrgBank8k(secondLastBank, 0xc000);
  }
  else
  {
    LoadPrgBank8k(secondLastBank, 0x8000);
    LoadPrgBank8k(MMC3_Prg1, 0xa000);
    LoadPrgBank8k(MMC3_Prg0, 0xc000);
  }
  LoadPrgBank8k(lastBank, 0xe000);
}

U0 MMC3_SetChrBanks()
{
  if (numCHRROM == 0)
  {
    return;
  }
  if (MMC3_ChrBankMode == 0)
  {
    LoadChrBank1k(MMC3_Regs[0] & 0xfe, 0x0000);
    LoadChrBank1k((MMC3_Regs[0] & 0xfe) + 1, 0x0400);
    LoadChrBank1k(MMC3_Regs[1] & 0xfe, 0x0800);
    LoadChrBank1k((MMC3_Regs[1] & 0xfe) + 1, 0x0c00);
    LoadChrBank1k(MMC3_Regs[2], 0x1000);
    LoadChrBank1k(MMC3_Regs[3], 0x1400);
    LoadChrBank1k(MMC3_Regs[4], 0x1800);
    LoadChrBank1k(MMC3_Regs[5], 0x1c00);
  }
  else
  {
    LoadChrBank1k(MMC3_Regs[2], 0x0000);
    LoadChrBank1k(MMC3_Regs[3], 0x0400);
    LoadChrBank1k(MMC3_Regs[4], 0x0800);
    LoadChrBank1k(MMC3_Regs[5], 0x0c00);
    LoadChrBank1k(MMC3_Regs[0] & 0xfe, 0x1000);
    LoadChrBank1k((MMC3_Regs[0] & 0xfe) + 1, 0x1400);
    LoadChrBank1k(MMC3_Regs[1] & 0xfe, 0x1800);
    LoadChrBank1k((MMC3_Regs[1] & 0xfe) + 1, 0x1c00);
  }
}

U0 MMC3_Init()
{
  I64 i;
  for (i = 0; i < 8; i++)
  {
    MMC3_Regs[i] = 0;
  }
  MMC3_Prg0 = 0;
  MMC3_Prg1 = 1;
  MMC3_PrgBankMode = 0;
  MMC3_ChrBankMode = 0;
  MMC3_Command = 0;
  MMC3_IrqLatch = 0;
  MMC3_IrqCounter = 0;
  MMC3_IrqReload = FALSE;
  MMC3_IrqEnable = FALSE;

  MMC3_SetPrgBanks();
  MMC3_SetChrBanks();
}

U0 MMC3_Write(U16 address, U8 value)
{
  address &= 0xe001;
  switch (address)
  {
  case 0x8000:
    MMC3_Command = value & 7;
    MMC3_PrgBankMode = (value >> 6) & 1;
    MMC3_ChrBankMode = (value >> 7) & 1;
    MMC3_SetPrgBanks();
    MMC3_SetChrBanks();
    break;
  case 0x8001:
    MMC3_Regs[MMC3_Command] = value;

    if (MMC3_Command == 6)
    {
      MMC3_Prg0 = value;
      MMC3_SetPrgBanks();
    }
    else if (MMC3_Command == 7)
    {
      MMC3_Prg1 = value;
      MMC3_SetPrgBanks();
    }
    else
    {
      MMC3_SetChrBanks();
    }
    break;
  case 0xa000:
    if ((value & 1) != 0)
    {
      mirroringType = MIRR_HORZ;
    }
    else
    {
      mirroringType = MIRR_VERT;
    }
    break;
  case 0xa001:

    break;
  case 0xc000:
    MMC3_IrqLatch = value;
    break;
  case 0xc001:
    MMC3_IrqCounter = 0;
    MMC3_IrqReload = TRUE;
    break;
  case 0xe000:
    MMC3_IrqEnable = FALSE;
    mapper_request_irq = FALSE;
    break;
  case 0xe001:
    MMC3_IrqEnable = TRUE;
    break;
  }
}

U0 MMC3_clockIrqCounter()
{
  if (MMC3_IrqCounter == 0 || MMC3_IrqReload)
  {
    MMC3_IrqCounter = MMC3_IrqLatch;
    MMC3_IrqReload = FALSE;
  }
  else
  {
    MMC3_IrqCounter--;
  }
  if (MMC3_IrqCounter == 0 && MMC3_IrqEnable)
  {
    mapper_request_irq = TRUE;
  }
}

U0 MMUInit()
{

  MMU.RAM = CAlloc(0x10000);
  MMU.VRAM = CAlloc(0x10000);
  MMU.OAM = MAlloc(0x100);
  MemSet(MMU.OAM, 0xFF, 0x100);
#ifdef NES_DIAG
  if (!nes_dg_ram_written)
    nes_dg_ram_written = CAlloc(0x800);
  else
    MemSet(nes_dg_ram_written, 0, 0x800);
  if (!nes_dg_ram_mirror)
    nes_dg_ram_mirror = CAlloc(0x800);
  else
    MemSet(nes_dg_ram_mirror, 0, 0x800);
  if (!nes_dg_oam_mirror)
    nes_dg_oam_mirror = MAlloc(0x100);
  MemSet(nes_dg_oam_mirror, 0xFF, 0x100);
  MemSet(nes_dg_ppureg_mirror, 0, 8);
  nes_dg_ppureg_addr = -1;
  nes_dg_oamm_addr = -1;
  nes_dg_uninit_rd = 0;
  nes_dg_uninit_addr = -1;
  nes_dg_mirror_addr = -1;
  nes_dg_mirror_frame = -1;
  if (nes_heap_jitter)
    MAlloc(nes_heap_jitter);
#endif

  MMU.internal_buffer = 0;
  MMU.VRAM_address = 0;

  MMU.w = 0;
  MMU.t = 0;
  MMU.x = 0;
  MMU.y = 0;
}

U0 MMUFree()
{
  Free(MMU.RAM);
  Free(MMU.VRAM);
  Free(MMU.OAM);
  MMU.RAM = NULL;
  MMU.VRAM = NULL;
  MMU.OAM = NULL;
#ifdef NES_DIAG
  Free(nes_dg_ram_written);
  Free(nes_dg_ram_mirror);
  Free(nes_dg_oam_mirror);
  nes_dg_ram_written = NULL;
  nes_dg_ram_mirror = NULL;
  nes_dg_oam_mirror = NULL;
#endif
}

U0 writeSPRRAM(U8 address, U8 value)
{
  MMU.OAM[address] = value;
#ifdef NES_DIAG
  if (nes_dg_oam_mirror)
    nes_dg_oam_mirror[address] = value;
#endif
}
U8 readSPRRAM(U8 address)
{
  return MMU.OAM[address];
}

U8 writeRAM(U16 address, U8 value)
{
  U16 val;
  U8 old_nmi_output;
#ifdef NES_DIAG
  U16 nes_dg_raw = address;
#endif
  while (address >= 0x2008 && address < 0x4000)
  {
    address -= 8;
  }
  while (address >= 0x0800 && address < 0x2000)
  {
    address -= 0x0800;
  }

#ifdef NES_DIAG
  if (address == 0x2000)
  {
    nes_dg_w2000++;
    nes_dg_w2000_val = value;
  }
  if (address == 0x2001)
  {
    nes_dg_w2001++;
    nes_dg_w2001_val = value;
  }
  if (address == 0x2000 && value & 0x04 && nes_dg_inc32_frame < 0)
  {
    nes_dg_inc32_frame = nes_dg_frame;
    nes_dg_inc32_val = value;
  }
#endif
  if (address == 0x2000)
  {
    val = value & 3;
    MMU.t &= 0xF3FF;
    MMU.t |= (val << 10);
    old_nmi_output = PPU_state.nmi_output;
    PPU_state.nmi_output = ((value & (1 << 7)) >> 7);
    if (!old_nmi_output && PPU_state.nmi_output &&
        PPU_state.nmi_occurred)
    {
      PPU_state.nmi_pending = 1;
    }
  }

  else if (address == 0x2004)
  {
    writeSPRRAM(MMU.RAM[0x2003], value);
    MMU.RAM[0x2003] = MMU.RAM[0x2003] + 1;
#ifdef NES_DIAG
    nes_dg_ppureg_mirror[3] = MMU.RAM[0x2003];
#endif
  }

  else if (address == 0x2005)
  {
    if (MMU.w == 0)
    {
      MMU.t &= ~31;
      MMU.t |= ((value & 248) >> 3);
      MMU.x = (value & 7);

    }
    else
    {

      MMU.t &= 3103;
      val = value;
      MMU.t |= ((val & 7) << 12);
      MMU.t |= ((val & 248) << 2);
    }
    MMU.w ^= 1;
  }

  else if (address == 0x2006)
  {
    if (MMU.w == 0)
    {
      MMU.t &= 0x00FF;
      val = value;
      val <<= 8;
      MMU.t |= val;
    }
    else
    {
      MMU.t &= 0xFF00;
      MMU.t |= value;
      MMU.VRAM_address = MMU.t;
    }
    MMU.w ^= 1;

  }

  else if (address == 0x2007)
  {
    writeVRAM((MMU.VRAM_address & 0x3FFF), value);
    if ((MMU.RAM[0x2000] & 4) == 0)
    {
      MMU.VRAM_address += 1;
    }
    else
    {
      MMU.VRAM_address += 32;
    }
  }

  else if (address == 0x4014)
  {
    I64 i;
    for (i = 0; i <= 0xFF; ++i)
    {
#ifdef NES_DIAG
      if (MMU.RAM[0x2003] + i > 0xFF)
        nes_dg_oamdma_over++;
#endif
      writeSPRRAM(MMU.RAM[0x2003] + i, MMU.RAM[(value << 8) | i]);
    }
    cpu_stall_cycles += 513 + PPU_state.odd_frame;
    return 0;
  }

  if (address == 0x4016)
  {
    JoypadWrite(&nes_joypad, value);
  }

  else if (address > 0x3fff && address < 0x4018)
  {
    PAPU_writeReg(&PAPU, address, value);
  }

  else if (address > 0x7FFF)
  {
#ifdef NES_DIAG
    nes_dg_mapw++;
    nes_dg_mapper_seen = mapper;
#endif
    switch (mapper)
    {
    case 1:
      MMC1_Write(address, value);
      return 0;
      break;
    case 2:
      UNROM_Write(address, value);
      return 0;
      break;
    case 3:
      CNROM_Write(address, value);
      return 0;
      break;
    case 4:
      MMC3_Write(address, value);
      return 0;
      break;
    case 7:
      AxROM_Write(address, value);
      return 0;
      break;
    default:
#ifdef NES_DIAG
      nes_dg_mapdflt++;
#endif
      break;
    }
    return 0;
  }

  MMU.RAM[address] = value;
#ifdef NES_DIAG
  if (address < 0x800)
  {
    if (nes_dg_ram_written)
      nes_dg_ram_written[address] = 1;
    if (nes_dg_ram_mirror)
      nes_dg_ram_mirror[address] = value;
  }
  else if (address >= 0x2000 && address <= 0x2007)
  {
    nes_dg_ppureg_mirror[address - 0x2000] = value;
    if (nes_dg_pw_cnt < NES_PW_MAX)
    {
      nes_dg_pw_instr[nes_dg_pw_cnt] = nes_dg_cur_instr;
      nes_dg_pw_pc[nes_dg_pw_cnt] = nes_dg_cur_pc;
      nes_dg_pw_addr[nes_dg_pw_cnt] = nes_dg_raw;
      nes_dg_pw_val[nes_dg_pw_cnt] = value;
      nes_dg_pw_zp6[nes_dg_pw_cnt] = MMU.RAM[0x06];
      nes_dg_pw_zp7[nes_dg_pw_cnt] = MMU.RAM[0x07];
      nes_dg_pw_cnt++;
    }
  }
#endif
  return 0;
}

U8 readRAM(U16 address)
{
  while (address >= 0x2008 && address < 0x4000)
  {
    address -= 8;
  }
  while (address >= 0x0800 && address < 0x2000)
  {
    address -= 0x0800;
  }

  U8 retVal = MMU.RAM[address];
#ifdef NES_DIAG
  if (address < 0x800 && nes_dg_ram_written && !nes_dg_ram_written[address])
  {
    nes_dg_uninit_rd++;
    if (nes_dg_uninit_addr < 0)
      nes_dg_uninit_addr = address;
  }
#endif

  if (address == 0x2002)
  {
    MMU.w = 0;
    retVal = ((PPU_state.sprite_zero_hit << 6) | (PPU_state.nmi_occurred << 7));
    PPU_state.nmi_occurred = 0;
#ifdef NES_DIAG
    nes_dg_r2002++;
    if (retVal & 0x80)
      nes_dg_r2002_hit++;
#endif
  }

  if (address == 0x2004)
  {
    return MMU.OAM[MMU.RAM[0x2003]];
  }

  else if (address == 0x2007)
  {

    if (MMU.VRAM_address <= 0x3EFF)
    {
      retVal = MMU.internal_buffer;
      MMU.internal_buffer = readVRAM(MMU.VRAM_address & 0x3FFF);
    }
    else
    {
      MMU.internal_buffer = readVRAM(MMU.VRAM_address & 0x3FFF);
      retVal = MMU.internal_buffer;
    }

    if ((MMU.RAM[0x2000] & 4) == 0)
    {
      MMU.VRAM_address += 1;
    }
    else
    {
      MMU.VRAM_address += 32;
    }
  }

  else if (address == 0x4016)
  {
    retVal = JoypadNextButton(&nes_joypad);
#ifdef NES_DIAG
    nes_dg_r4016++;
#endif
  }

  if (address == 0x4015)
  {
    retVal = PAPU_readReg(&PAPU, address);
  }

  return retVal;
}
