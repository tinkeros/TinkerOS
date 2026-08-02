#define NES_STATE_VERSION	2

U8 nes_state_filename[STR_LEN];
U8 nes_sram_filename[STR_LEN];

U0 SaveSRAM()
{
  if (!MMU.RAM || !(controlByte1 & 2))
    return;
  if (FileWrite(nes_sram_filename,MMU.RAM+0x6000,0x2000))
    "TempleNES: SRAM saved to \"%s\".\n",nes_sram_filename;
  else
    "TempleNES: couldn't write \"%s\".\n",nes_sram_filename;
}

U0 LoadSRAM()
{
  I64 size;
  U8 *buf;
  if (!(controlByte1 & 2))
    return;
  buf=FileRead(nes_sram_filename,&size);
  if (!buf)
    return;
  if (size==0x2000)
  {
    MemCpy(MMU.RAM+0x6000,buf,0x2000);
    "TempleNES: SRAM loaded from \"%s\".\n",nes_sram_filename;
  }
  else
    "TempleNES: \"%s\" isn't 8KB SRAM, ignored.\n",
    nes_sram_filename;
  Free(buf);
}

class CNESState
{
  U64 magic;
  I64 version,cpu_pc,cpu_sp,cpu_a,cpu_x,cpu_y,cpu_status,
      mmu_w,mmu_t,mmu_x,mmu_y,mmu_vram_address,mmu_internal_buffer,
      mirroring, papu_irq,mapper_irq,
      mmc1_reg_buffer,mmc1_reg_buffer_counter,mmc1_mirroring,
      mmc1_prg_switching_area,mmc1_prg_switching_size,
      mmc1_vrom_switching_size,mmc1_rom_selection_reg0,
      mmc1_rom_selection_reg1,mmc1_rom_bank_select,
      mmc3_regs[8],mmc3_prg0,mmc3_prg1,mmc3_prg_bank_mode,
      mmc3_chr_bank_mode,mmc3_command,mmc3_irq_latch,mmc3_irq_counter,
      mmc3_irq_reload,mmc3_irq_enable;
  PPU2C02state ppu;
  PAPU2A03 papu;
  U8 oam[0x100], ram[0x10000], vram[0x4000];
};

U0 SaveState()
{
  I64 i;
  CNESState *s=CAlloc(sizeof(CNESState));
  s->magic='TNESSAV';
  s->version=NES_STATE_VERSION;
  s->cpu_pc=pc;
  s->cpu_sp=sp;
  s->cpu_a=a;
  s->cpu_x=x;
  s->cpu_y=y;
  s->cpu_status=cpustatus;
  s->mmu_w=MMU.w;
  s->mmu_t=MMU.t;
  s->mmu_x=MMU.x;
  s->mmu_y=MMU.y;
  s->mmu_vram_address=MMU.VRAM_address;
  s->mmu_internal_buffer=MMU.internal_buffer;
  s->mirroring=mirroringType;
  s->papu_irq=papu_request_irq;
  s->mapper_irq=mapper_request_irq;
  s->mmc1_reg_buffer=MMC1_regBuffer;
  s->mmc1_reg_buffer_counter=MMC1_regBufferCounter;
  s->mmc1_mirroring=MMC1_mirroring;
  s->mmc1_prg_switching_area=MMC1_prgSwitchingArea;
  s->mmc1_prg_switching_size=MMC1_prgSwitchingSize;
  s->mmc1_vrom_switching_size=MMC1_vromSwitchingSize;
  s->mmc1_rom_selection_reg0=MMC1_romSelectionReg0;
  s->mmc1_rom_selection_reg1=MMC1_romSelectionReg1;
  s->mmc1_rom_bank_select=MMC1_romBankSelect;
  for (i=0; i<8; i++)
    s->mmc3_regs[i]=MMC3_Regs[i];
  s->mmc3_prg0=MMC3_Prg0;
  s->mmc3_prg1=MMC3_Prg1;
  s->mmc3_prg_bank_mode=MMC3_PrgBankMode;
  s->mmc3_chr_bank_mode=MMC3_ChrBankMode;
  s->mmc3_command=MMC3_Command;
  s->mmc3_irq_latch=MMC3_IrqLatch;
  s->mmc3_irq_counter=MMC3_IrqCounter;
  s->mmc3_irq_reload=MMC3_IrqReload;
  s->mmc3_irq_enable=MMC3_IrqEnable;
  MemCpy(&s->ppu,&PPU_state,sizeof(PPU2C02state));
  MemCpy(&s->papu,&PAPU,sizeof(PAPU2A03));
  MemCpy(s->oam,MMU.OAM,0x100);
  MemCpy(s->ram,MMU.RAM,0x10000);
  MemCpy(s->vram,MMU.VRAM,0x4000);
  if (FileWrite(nes_state_filename,s,sizeof(CNESState)))
    "TempleNES: state saved to \"%s\".\n",nes_state_filename;
  else
    "TempleNES: couldn't write \"%s\".\n",nes_state_filename;
  Free(s);
}

U0 LoadState()
{
  I64 i,size;
  CNESState *s=FileRead(nes_state_filename,&size);
  if (!s)
  {
      "TempleNES: no save state \"%s\".\n",nes_state_filename;
    return;
  }
  if (size!=sizeof(CNESState) || s->magic!='TNESSAV' ||
      s->version!=NES_STATE_VERSION)
  {
    "TempleNES: \"%s\" isn't a valid save state.\n",
    nes_state_filename;
    Free(s);
    return;
  }
  pc=s->cpu_pc;
  sp=s->cpu_sp;
  a=s->cpu_a;
  x=s->cpu_x;
  y=s->cpu_y;
  cpustatus=s->cpu_status;
  MMU.w=s->mmu_w;
  MMU.t=s->mmu_t;
  MMU.x=s->mmu_x;
  MMU.y=s->mmu_y;
  MMU.VRAM_address=s->mmu_vram_address;
  MMU.internal_buffer=s->mmu_internal_buffer;
  mirroringType=s->mirroring;
  papu_request_irq=s->papu_irq;
  mapper_request_irq=s->mapper_irq;
  MMC1_regBuffer=s->mmc1_reg_buffer;
  MMC1_regBufferCounter=s->mmc1_reg_buffer_counter;
  MMC1_mirroring=s->mmc1_mirroring;
  MMC1_prgSwitchingArea=s->mmc1_prg_switching_area;
  MMC1_prgSwitchingSize=s->mmc1_prg_switching_size;
  MMC1_vromSwitchingSize=s->mmc1_vrom_switching_size;
  MMC1_romSelectionReg0=s->mmc1_rom_selection_reg0;
  MMC1_romSelectionReg1=s->mmc1_rom_selection_reg1;
  MMC1_romBankSelect=s->mmc1_rom_bank_select;
  for (i=0; i<8; i++)
    MMC3_Regs[i]=s->mmc3_regs[i];
  MMC3_Prg0=s->mmc3_prg0;
  MMC3_Prg1=s->mmc3_prg1;
  MMC3_PrgBankMode=s->mmc3_prg_bank_mode;
  MMC3_ChrBankMode=s->mmc3_chr_bank_mode;
  MMC3_Command=s->mmc3_command;
  MMC3_IrqLatch=s->mmc3_irq_latch;
  MMC3_IrqCounter=s->mmc3_irq_counter;
  MMC3_IrqReload=s->mmc3_irq_reload;
  MMC3_IrqEnable=s->mmc3_irq_enable;
  MemCpy(&PPU_state,&s->ppu,sizeof(PPU2C02state));
  MemCpy(&PAPU,&s->papu,sizeof(PAPU2A03));
  MemCpy(MMU.OAM,s->oam,0x100);
  MemCpy(MMU.RAM,s->ram,0x10000);
  MemCpy(MMU.VRAM,s->vram,0x4000);
  Free(s);
  PAPU_initBuffers;
  "TempleNES: state loaded from \"%s\".\n",nes_state_filename;
}
