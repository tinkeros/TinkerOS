#define GEN_STATE_VERSION	2

class CGenState
{
  U64 magic;
  I64 version;
  m68ki_cpu_core cpu;
  CZ80 z80_s;
  I64 z80_bus_ack_s,z80_reset_s;
  I64 control_code_s,control_pending_s;
  U32 control_address_s,vdp_status_s;
  I64 dma_length_s;
  U32 dma_source_s;
  I64 dma_fill_s;
  I64 scrn_w,scrn_h;
  U8 vdp_regs[0x20];
  U16 cram[0x40],vsram[0x40];
  U16 btns[3],pads[3];
  U8 ioregs[16];
  CYM2612 ym_s;
  CPSG psg_s;
  U8 ram[0x10000];
  U8 zram[0x2000];
  U8 vram[0x10000];
};

U0 SaveState()
{
  CGenState *s;
  if (!RAM)
    return;
  s=CAlloc(sizeof(CGenState));
  s->magic='TGENSAV';
  s->version=GEN_STATE_VERSION;
  MemCpy(&s->cpu,&m68ki_cpu,sizeof(m68ki_cpu_core));
  MemCpy(&s->z80_s,&z80,sizeof(CZ80));
  s->z80_bus_ack_s=z80_bus_ack;
  s->z80_reset_s=z80_reset;
  s->control_code_s=control_code;
  s->control_pending_s=control_pending;
  s->control_address_s=control_address;
  s->vdp_status_s=vdp_status;
  s->dma_length_s=dma_length;
  s->dma_source_s=dma_source;
  s->dma_fill_s=dma_fill;
  s->scrn_w=screen_width;
  s->scrn_h=screen_height;
  MemCpy(s->vdp_regs,vdp_reg,0x20);
  MemCpy(s->cram,CRAM,0x40*sizeof(U16));
  MemCpy(s->vsram,VSRAM,0x40*sizeof(U16));
  MemCpy(s->btns,button_state,3*sizeof(U16));
  MemCpy(s->pads,pad_state,3*sizeof(U16));
  MemCpy(s->ioregs,io_reg,16);
  MemCpy(&s->ym_s,&ym,sizeof(CYM2612));
  MemCpy(&s->psg_s,&psg,sizeof(CPSG));
  MemCpy(s->ram,RAM,0x10000);
  MemCpy(s->zram,ZRAM,0x2000);
  MemCpy(s->vram,VRAM,0x10000);
  if (FileWrite(gen_state_filename,s,sizeof(CGenState)))
		"TempleGen: state saved to \"%s\".\n",gen_state_filename;
  else
		"TempleGen: couldn't write \"%s\".\n",gen_state_filename;
  Free(s);
}

U0 LoadState()
{
  I64 size;
  CGenState *s=FileRead(gen_state_filename,&size);
  if (!s)
  {
		"TempleGen: no save state \"%s\".\n",gen_state_filename;
    return;
  }
  if (size!=sizeof(CGenState) || s->magic!='TGENSAV' ||
      s->version!=GEN_STATE_VERSION)
  {
    "TempleGen: \"%s\" isn't a valid save state.\n",
    gen_state_filename;
    Free(s);
    return;
  }
  MemCpy(&m68ki_cpu,&s->cpu,sizeof(m68ki_cpu_core));
  m68ki_cpu.cyc_instruction=m68ki_cycles[0];
  m68ki_cpu.cyc_exception=m68ki_exception_cycle_table[0];
  m68ki_cpu.int_ack_callback=NULL;
  m68ki_cpu.bkpt_ack_callback=NULL;
  m68ki_cpu.reset_instr_callback=NULL;
  m68ki_cpu.pc_changed_callback=NULL;
  m68ki_cpu.set_fc_callback=NULL;
  m68ki_cpu.instr_hook_callback=NULL;
  m68ki_remaining_cycles=0;
  MemCpy(&z80,&s->z80_s,sizeof(CZ80));
  z80_bus_ack=s->z80_bus_ack_s;
  z80_reset=s->z80_reset_s;
  control_code=s->control_code_s;
  control_pending=s->control_pending_s;
  control_address=s->control_address_s;
  vdp_status=s->vdp_status_s;
  dma_length=s->dma_length_s;
  dma_source=s->dma_source_s;
  dma_fill=s->dma_fill_s;
  screen_width=s->scrn_w;
  screen_height=s->scrn_h;
  MemCpy(vdp_reg,s->vdp_regs,0x20);
  MemCpy(CRAM,s->cram,0x40*sizeof(U16));
  MemCpy(VSRAM,s->vsram,0x40*sizeof(U16));
  MemCpy(button_state,s->btns,3*sizeof(U16));
  MemCpy(pad_state,s->pads,3*sizeof(U16));
  MemCpy(io_reg,s->ioregs,16);
  MemCpy(&ym,&s->ym_s,sizeof(CYM2612));
  MemCpy(&psg,&s->psg_s,sizeof(CPSG));
  MemCpy(RAM,s->ram,0x10000);
  MemCpy(ZRAM,s->zram,0x2000);
  MemCpy(VRAM,s->vram,0x10000);
  Free(s);
  gen_cram_dirty=~0;
  if (gen_snd_fifo)
  {
    FifoI64Flush(gen_snd_fifo);
    gen_snd_last=0;
  }
	"TempleGen: state loaded from \"%s\".\n",gen_state_filename;
}
