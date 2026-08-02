#define NES_SCRN_W	256
#define NES_SCRN_H	240
#define NES_OVERSCAN	8
#define MIRR_HORZ		0
#define MIRR_VERT		1
#define MIRR_SINGLE		2
#define MIRR_FOUR		3
#define MIRR_SINGLE_UPPER	4

#define NES_DEBUG_VER 5

#ifdef NES_DIAG

I64 nes_dg_r2002=0, nes_dg_r2002_hit=0,
    nes_dg_nmi_set=0, nes_dg_nmi_clr=0, nes_dg_nmi_fire=0,
    nes_dg_w2000=0, nes_dg_w2001=0, nes_dg_r4016=0;

I64 nes_dg_w2000_val=-1, nes_dg_w2001_val=-1;

I64 NESDiagSum(U8 *p,I64 n)
{
  I64 i,h=0;
  for (i=0; i<n; i++)
    h=(h<<5)+h+p[i];
  return h;
}

I64 nes_dg_frame=0;

I64 nes_dg_mapw=0, nes_dg_mapdflt=0, nes_dg_mapper_seen=-1;

I64 nes_dg_oamdma_over=0;

I64 nes_dg_palw=0, nes_dg_palw_frame=-1;

I64 nes_dg_inc32_frame=-1, nes_dg_inc32_val=-1, nes_dg_inc32_shown=FALSE;

U8 *nes_dg_ram_written=NULL;
I64 nes_dg_uninit_rd=0, nes_dg_uninit_addr=-1;

U8 *nes_dg_ram_mirror=NULL;
I64 nes_dg_mirror_addr=-1, nes_dg_mirror_want=-1, nes_dg_mirror_got=-1,
    nes_dg_mirror_frame=-1;

U8 nes_dg_ppureg_mirror[8];
U8 *nes_dg_oam_mirror=NULL;
I64 nes_dg_ppureg_addr=-1, nes_dg_ppureg_want=-1, nes_dg_ppureg_got=-1;

I64 nes_dg_cur_instr=0;
U16 nes_dg_cur_pc=0;

#define NES_PW_MAX 48
I64 nes_dg_pw_instr[NES_PW_MAX];
U16 nes_dg_pw_pc[NES_PW_MAX], nes_dg_pw_addr[NES_PW_MAX];
U8 nes_dg_pw_val[NES_PW_MAX];
U8 nes_dg_pw_zp6[NES_PW_MAX], nes_dg_pw_zp7[NES_PW_MAX];

#define NES_INDY_MAX 24
I64 nes_dg_indy_instr[NES_INDY_MAX];
U16 nes_dg_indy_pc[NES_INDY_MAX], nes_dg_indy_eah[NES_INDY_MAX],
    nes_dg_indy_eah2[NES_INDY_MAX], nes_dg_indy_base[NES_INDY_MAX],
    nes_dg_indy_ea[NES_INDY_MAX];
U8 nes_dg_indy_lo[NES_INDY_MAX], nes_dg_indy_hi[NES_INDY_MAX],
    nes_dg_indy_y[NES_INDY_MAX], nes_dg_indy_p[NES_INDY_MAX];
I64 nes_dg_indy_cnt=0, nes_dg_indy_got=0;

I64 nes_dg_cast_y=-1, nes_dg_cast_x=-1, nes_dg_cast_a=-1;
I64 nes_dg_pw_cnt=0, nes_dg_pw_got=0;
I64 nes_dg_oamm_addr=-1, nes_dg_oamm_want=-1, nes_dg_oamm_got=-1;

#define NES_CANARY_VRAM_HIGH 1
#define NES_CANARY_PRG       2
#define NES_CANARY_CHR       3
#define NES_CANARY_RAM_GAP1  4
#define NES_CANARY_RAM_GAP2  5
#define NES_CANARY_PPUREG    6
#define NES_CANARY_OAM       7
I64 nes_dg_prg_sum0=-1, nes_dg_chr_sum0=-1;
I64 nes_dg_canary_frame=-1, nes_dg_canary_what=-1,
    nes_dg_canary_now=-1, nes_dg_canary_want=-1;

#define NES_CKPT_MAX 64
class NESCkpt
{
  I64 frame, instr;
  U16 pc;
  U8 a, x, y, sp, cpustatus;
  U8 r2000, r2001, pad;
  U16 scanline, dot, vaddr, t;
  U8 nmi_occ, nmi_out, nmi_pend, w;
  I64 ramsum, vramsum, oamsum;
};
NESCkpt nes_ckpt[NES_CKPT_MAX];
I64 nes_ckpt_put=0, nes_ckpt_got=0;

#define NES_ISAMP_MAX 256
class NESISamp
{
  I64 instr;
  U16 pc, scanline, dot;
  U8 opcode, cycles, a, x, y, sp, cpustatus;
};
NESISamp nes_isamp[NES_ISAMP_MAX];
I64 nes_isamp_put=0, nes_isamp_got=0;
public I64 nes_dg_isample=0, nes_dg_isample_from=0, nes_dg_isample_to=0;

#define NES_NMI_TRACE 24
class NESNmiRec
{
  I64 frame, instr;
  U16 pc, scanline, dot;
};
NESNmiRec nes_nmi_trace[NES_NMI_TRACE];
I64 nes_nmi_trace_cnt=0, nes_nmi_trace_got=0;

I64 nes_dg_render_busy=0, nes_dg_fifo_busy=0;
I64 nes_dg_draw_cnt=0, nes_dg_draw_overlap=0, nes_dg_draw_core=-1;
I64 nes_dg_fill_cnt=0, nes_dg_fill_overlap=0, nes_dg_fill_core=-1;
I64 nes_dg_flush_cnt=0, nes_dg_flush_overlap=0;
I64 nes_dg_emu_core=-1, nes_dg_ui_core=-1, nes_dg_emu_iters=0;

public I64 nes_heap_jitter=0;
#endif

U8 *cartridgebuffer=NULL;
I64 numPRGROM,
    numCHRROM,
    controlByte1,
    mapper,
    mirroringType=MIRR_VERT;

Bool papu_request_irq=FALSE, mapper_request_irq=FALSE;

I64 cpu_stall_cycles=0;

I64 nes_badop_cnt=0, nes_badop_last=-1, nes_badop_pc=-1;

I64 nes_last_ld16_bank=-1, nes_last_ld16_addr=-1, nes_ld16_seq=0;
I64 nes_badop_bank=-1, nes_badop_seq=-1;

CDC *gameCanvas=NULL, *gameCanvas2x=NULL;

CBGR48 nes_sys_palette[COLORS_NUM];

class PPUsprite {
  U8 shifts_remaining;
  U8 sprite_index;
  U8 byte2;
  U8 shift_register_0;
  U8 shift_register_1;
  U8 attribute;
  U8 x;
};

class PPU2C02state {
  U8 odd_frame;
  U16 scanline;
  U16 dot;

  U8 nmi_occurred;

  U8 nmi_output;

  U8 nmi_pending;

  U8 sprite_zero_hit;

  U16 nametable_base;

  U16 bitmap_shift_0_latch;
  U16 bitmap_shift_1_latch;

  U16 bitmap_shift_0;
  U16 bitmap_shift_1;

  U16 AT_shift_0_latch;
  U16 AT_shift_1_latch;
  U16 AT_shift_0;
  U16 AT_shift_1;

  U8 num_sprites;
  PPUsprite sprites[8];
};

PPU2C02state PPU_state;
