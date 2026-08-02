I64 cycle_counter;
I64 lines_per_frame;
I64 MCYCLES_PER_LINE;

#define M68K_CPU_TYPE_INVALID 0
#define M68K_CPU_TYPE_68000 1
#define M68K_CPU_TYPE_68010 2
#define M68K_CPU_TYPE_68EC020 3
#define M68K_CPU_TYPE_68020 4
#define M68K_CPU_TYPE_68030 5
#define M68K_CPU_TYPE_68040 6

#define M68K_REG_D0 0
#define M68K_REG_D1 1
#define M68K_REG_D2 2
#define M68K_REG_D3 3
#define M68K_REG_D4 4
#define M68K_REG_D5 5
#define M68K_REG_D6 6
#define M68K_REG_D7 7
#define M68K_REG_A0 8
#define M68K_REG_A1 9
#define M68K_REG_A2 10
#define M68K_REG_A3 11
#define M68K_REG_A4 12
#define M68K_REG_A5 13
#define M68K_REG_A6 14
#define M68K_REG_A7 15
#define M68K_REG_PC 16
#define M68K_REG_SR 17
#define M68K_REG_SP 18
#define M68K_REG_USP 19
#define M68K_REG_ISP 20
#define M68K_REG_MSP 21
#define M68K_REG_SFC 22
#define M68K_REG_DFC 23
#define M68K_REG_VBR 24
#define M68K_REG_CACR 25
#define M68K_REG_CAAR 26
#define M68K_REG_PREF_ADDR 27
#define M68K_REG_PREF_DATA 28
#define M68K_REG_PPC 29
#define M68K_REG_IR 30
#define M68K_REG_CPU_TYPE 31

I8 MAKE_INT_8(U32 value) {
  return T((value & 0x80), value | ~0xff, value & 0xff);
}

I16 MAKE_INT_16(U32 value) {
  return T((value & 0x8000), value | ~0xffff, value & 0xffff);
}

I32 MAKE_INT_32(U32 value) {
  return T((value & 0x80000000), value | ~0xffffffff, value & 0xffffffff);
}

class m68ki_cpu_core {
  U32 cpu_type;
  U32 dar[16];
  U32 ppc;
  U32 pc;
  U32 sp[7];
  U32 vbr;
  U32 sfc;
  U32 dfc;
  U32 cacr;
  U32 caar;
  U32 ir;
  U32 t1_flag;
  U32 t0_flag;
  U32 s_flag;
  U32 m_flag;
  U32 x_flag;
  U32 n_flag;
  U32 not_z_flag;
  U32 v_flag;
  U32 c_flag;
  U32 int_mask;
  U32 int_level;
  U32 int_cycles;
  U32 stopped;
  U32 pref_addr;
  U32 pref_data;
  U32 address_mask;
  U32 sr_mask;
  U32 cyc_bcc_notake_b;
  U32 cyc_bcc_notake_w;
  U32 cyc_dbcc_f_noexp;
  U32 cyc_dbcc_f_exp;
  U32 cyc_scc_r_false;
  U32 cyc_movem_w;
  U32 cyc_movem_l;
  U32 cyc_shift;
  U32 cyc_reset;
  U8 *cyc_instruction;
  U8 *cyc_exception;

  I64 (*int_ack_callback)(I64 int_line);
  U0 (*bkpt_ack_callback)(U32 data);
  U0 (*reset_instr_callback)();
  U0 (*pc_changed_callback)(U32 new_pc);
  U0 (*set_fc_callback)(U32 new_fc);
  U0 (*instr_hook_callback)();
};

#define NUM_CPU_TYPES 3

m68ki_cpu_core m68ki_cpu;
MemSet(&m68ki_cpu, 0, sizeof(m68ki_cpu_core));

I32 m68ki_initial_cycles;
I32 m68ki_remaining_cycles = 0;
U32 m68ki_tracing = 0;
U32 m68ki_address_space;

U8 *m68ki_cpu_names[9];
m68ki_cpu_names[0] = "Invalid CPU";
m68ki_cpu_names[1] = "M68000";
m68ki_cpu_names[2] = "M68010";
m68ki_cpu_names[3] = "Invalid CPU";
m68ki_cpu_names[4] = "M68EC020";
m68ki_cpu_names[5] = "Invalid CPU";
m68ki_cpu_names[6] = "Invalid CPU";
m68ki_cpu_names[7] = "Invalid CPU";
m68ki_cpu_names[8] = "M68020";

U64 m68ki_instruction_jump_table[0x10000];
U8 m68ki_cycles[NUM_CPU_TYPES][0x10000];

class opcode_handler_struct {
  U64 opcode_handler;
  U32 mask;
  U32 match;
  U8 cycles[NUM_CPU_TYPES];
};

U8 m68ki_shift_8_table[65] = {
    0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
U16 m68ki_shift_16_table[65] = {
    0x0000, 0x8000, 0xc000, 0xe000, 0xf000, 0xf800, 0xfc00, 0xfe00, 0xff00,
    0xff80, 0xffc0, 0xffe0, 0xfff0, 0xfff8, 0xfffc, 0xfffe, 0xffff, 0xffff,
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    0xffff, 0xffff};
U32 m68ki_shift_32_table[65] = {
    0x00000000, 0x80000000, 0xc0000000, 0xe0000000, 0xf0000000, 0xf8000000,
    0xfc000000, 0xfe000000, 0xff000000, 0xff800000, 0xffc00000, 0xffe00000,
    0xfff00000, 0xfff80000, 0xfffc0000, 0xfffe0000, 0xffff0000, 0xffff8000,
    0xffffc000, 0xffffe000, 0xfffff000, 0xfffff800, 0xfffffc00, 0xfffffe00,
    0xffffff00, 0xffffff80, 0xffffffc0, 0xffffffe0, 0xfffffff0, 0xfffffff8,
    0xfffffffc, 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff};

U8 m68ki_exception_cycle_table[3][256] = {
    {4,  4,  50, 50, 34, 38, 40, 34, 34, 34, 4,  4,  4,  4,  4,  44, 4,  4,
     4,  4,  4,  4,  4,  4,  44, 44, 44, 44, 44, 44, 44, 44, 34, 34, 34, 34,
     34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,

     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4},
    {4,  4,  126, 126, 38, 44, 44, 34, 38, 38, 4,  4,  4,  4,  4,  44, 4,  4,
     4,  4,  4,   4,   4,  4,  46, 46, 46, 46, 46, 46, 46, 46, 38, 38, 38, 38,
     38, 38, 38,  38,  38, 38, 38, 38, 38, 38, 38, 38, 4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,

     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,   4,   4,  4,  4,  4,  4,  4,  4,  4},
    {4,  4,  50, 50, 20, 38, 40, 20, 34, 25, 20, 20, 4,  4,  4,  30, 4,  4,
     4,  4,  4,  4,  4,  4,  30, 30, 30, 30, 30, 30, 30, 30, 20, 20, 20, 20,
     20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,

     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,
     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4}};

U8 m68ki_ea_idx_cycle_table[64] = {
    0, 0, 0, 0, 0, 0,  0,  0,  0, 0,  0,  0,  0, 0,  0,  0,  0, 5,  7,  7, 0, 5,
    7, 7, 0, 5, 7, 7,  0,  5,  7, 7,  2,  7,  9, 9,  0,  7,  9, 9,  0,  7, 9, 9,
    0, 7, 9, 9, 6, 11, 13, 13, 0, 11, 13, 13, 0, 11, 13, 13, 0, 11, 13, 13};
I32 default_int_ack_callback_data;

extern U32 m68k_read_memory_8(U32 address);
extern U32 m68k_read_memory_16(U32 address);
extern U32 m68k_read_memory_32(U32 address);

extern U0 m68k_write_memory_8(U32 address, U32 value);
extern U0 m68k_write_memory_16(U32 address, U32 value);
extern U0 m68k_write_memory_32(U32 address, U32 value);

U32 m68ki_read_8_fc(U32 address, U32 fc) {
  no_warn fc;
  return m68k_read_memory_8(((address)&m68ki_cpu.address_mask));
}
U32 m68ki_read_16_fc(U32 address, U32 fc) {
  no_warn fc;
  return m68k_read_memory_16(((address)&m68ki_cpu.address_mask));
}
U32 m68ki_read_32_fc(U32 address, U32 fc) {
  no_warn fc;
  return m68k_read_memory_32(((address)&m68ki_cpu.address_mask));
}

U0 m68ki_write_8_fc(U32 address, U32 fc, U32 value) {
  no_warn fc;
  m68k_write_memory_8(((address)&m68ki_cpu.address_mask), value);
}
U0 m68ki_write_16_fc(U32 address, U32 fc, U32 value) {
  no_warn fc;
  m68k_write_memory_16(((address)&m68ki_cpu.address_mask), value);
}
U0 m68ki_write_32_fc(U32 address, U32 fc, U32 value) {
  no_warn fc;
  m68k_write_memory_32(((address)&m68ki_cpu.address_mask), value);
}
U32 m68ki_read_imm_16() {
  ;
  ;
  m68ki_cpu.pc += 2;
  return m68ki_read_16_fc(((m68ki_cpu.pc - 2) & m68ki_cpu.address_mask),
                          m68ki_cpu.s_flag | 2);
}
U32 m68ki_read_imm_32() {
  ;
  ;
  m68ki_cpu.pc += 4;
  return m68ki_read_32_fc(((m68ki_cpu.pc - 4) & m68ki_cpu.address_mask),
                          m68ki_cpu.s_flag | 2);
}

U32 m68ki_get_ea_pcdi() {
  U32 old_pc = m68ki_cpu.pc;
  ;
  return old_pc + (MAKE_INT_16(m68ki_read_imm_16()));
}

U32 m68ki_get_ea_ix(U32 An) {

  U32 extension = m68ki_read_imm_16();
  U32 Xn = 0;
  U32 bd = 0;
  U32 od = 0;

  if (((m68ki_cpu.cpu_type) & (1 | 2))) {

    Xn = m68ki_cpu.dar[extension >> 12];
    if (!((extension)&0x00000800))
      Xn = MAKE_INT_16(Xn);

    return An + Xn + MAKE_INT_8(extension);
  }

  if (!((extension)&0x00000100)) {

    Xn = m68ki_cpu.dar[extension >> 12];
    if (!((extension)&0x00000800))
      Xn = MAKE_INT_16(Xn);

    if (((m68ki_cpu.cpu_type) & (4 | 8)))
      Xn <<= (extension >> 9) & 3;

    return An + Xn + MAKE_INT_8(extension);
  }

  m68ki_remaining_cycles -= (m68ki_ea_idx_cycle_table[extension & 0x3f]);

  if (((extension)&0x00000080))
    An = 0;

  if (!((extension)&0x00000040)) {
    Xn = m68ki_cpu.dar[extension >> 12];
    if (!((extension)&0x00000800))
      Xn = MAKE_INT_16(Xn);
    Xn <<= (extension >> 9) & 3;
  }

  if (((extension)&0x00000020))
    bd = T((extension)&0x00000010, m68ki_read_imm_32(),
           MAKE_INT_16(m68ki_read_imm_16()));

  if (!(extension & 7))
    return An + bd + Xn;

  if (((extension)&0x00000002))
    od = T((extension)&0x00000001, m68ki_read_imm_32(),
           MAKE_INT_16(m68ki_read_imm_16()));

  if (((extension)&0x00000004))
    return m68ki_read_32_fc(An + bd, m68ki_cpu.s_flag | 1) + Xn + od;

  return m68ki_read_32_fc(An + bd + Xn, m68ki_cpu.s_flag | 1) + od;
}
U32 m68ki_get_ea_pcix() {
  ;
  return m68ki_get_ea_ix(m68ki_cpu.pc);
}

U32 OPER_AY_AI_8() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_AI_16() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_AI_32() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_PI_8() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_PI_16() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_PI_32() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_PD_8() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_PD_16() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_PD_32() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_DI_8() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_DI_16() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_DI_32() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_IX_8() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_IX_16() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AY_IX_32() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}

U32 OPER_AX_AI_8() {
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_AI_16() {
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_AI_32() {
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_PI_8() {
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_PI_16() {
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_PI_32() {
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_PD_8() {
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_PD_16() {
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_PD_32() {
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_DI_8() {
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_DI_16() {
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_DI_32() {
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_IX_8() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_IX_16() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AX_IX_32() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}

U32 OPER_A7_PI_8() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_A7_PD_8() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}

U32 OPER_AW_8() {
  U32 ea = (MAKE_INT_16(m68ki_read_imm_16()));
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AW_16() {
  U32 ea = (MAKE_INT_16(m68ki_read_imm_16()));
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AW_32() {
  U32 ea = (MAKE_INT_16(m68ki_read_imm_16()));
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AL_8() {
  U32 ea = m68ki_read_imm_32();
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AL_16() {
  U32 ea = m68ki_read_imm_32();
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_AL_32() {
  U32 ea = m68ki_read_imm_32();
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
}
U32 OPER_PCDI_8() {
  U32 ea = m68ki_get_ea_pcdi();
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 2);
}
U32 OPER_PCDI_16() {
  U32 ea = m68ki_get_ea_pcdi();
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 2);
}
U32 OPER_PCDI_32() {
  U32 ea = m68ki_get_ea_pcdi();
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 2);
}
U32 OPER_PCIX_8() {
  U32 ea = m68ki_get_ea_pcix();
  return m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 2);
}
U32 OPER_PCIX_16() {
  U32 ea = m68ki_get_ea_pcix();
  return m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 2);
}
U32 OPER_PCIX_32() {
  U32 ea = m68ki_get_ea_pcix();
  return m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 2);
}

U0 m68ki_push_16(U32 value) {
  m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] - 2);
  m68ki_write_16_fc(m68ki_cpu.dar[15], m68ki_cpu.s_flag | 1, value);
}

U0 m68ki_push_32(U32 value) {
  m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] - 4);
  m68ki_write_32_fc(m68ki_cpu.dar[15], m68ki_cpu.s_flag | 1, value);
}

U32 m68ki_pull_16() {
  m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] + 2);
  return m68ki_read_16_fc(m68ki_cpu.dar[15] - 2, m68ki_cpu.s_flag | 1);
}

U32 m68ki_pull_32() {
  m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] + 4);
  m68ki_read_32_fc(m68ki_cpu.dar[15] - 4, m68ki_cpu.s_flag | 1);
  return m68ki_read_32_fc(m68ki_cpu.dar[15] - 4, m68ki_cpu.s_flag | 1);
}

U0 m68ki_fake_push_16() { m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] - 2); }

U0 m68ki_fake_push_32() { m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] - 4); }

U0 m68ki_fake_pull_16() { m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] + 2); }

U0 m68ki_fake_pull_32() { m68ki_cpu.dar[15] = (m68ki_cpu.dar[15] + 4); }
U0 m68ki_jump(U32 new_pc) {
  m68ki_cpu.pc = new_pc;
  ;
}

U0 m68ki_jump_vector(U32 vector) {
  m68ki_cpu.pc = (vector << 2) + m68ki_cpu.vbr;
  m68ki_cpu.pc = m68ki_read_32_fc(m68ki_cpu.pc, m68ki_cpu.s_flag | 1);
  ;
}

U0 m68ki_branch_8(U32 offset) { m68ki_cpu.pc += MAKE_INT_8(offset); }

U0 m68ki_branch_16(U32 offset) { m68ki_cpu.pc += MAKE_INT_16(offset); }

U0 m68ki_branch_32(U32 offset) {
  m68ki_cpu.pc += offset;
  ;
}
U0 m68ki_set_s_flag(U32 value) {

  m68ki_cpu
      .sp[m68ki_cpu.s_flag | ((m68ki_cpu.s_flag >> 1) & m68ki_cpu.m_flag)] =
      m68ki_cpu.dar[15];

  m68ki_cpu.s_flag = value;

  m68ki_cpu.dar[15] =
      m68ki_cpu
          .sp[m68ki_cpu.s_flag | ((m68ki_cpu.s_flag >> 1) & m68ki_cpu.m_flag)];
}

U0 m68ki_set_sm_flag(U32 value) {

  m68ki_cpu
      .sp[m68ki_cpu.s_flag | ((m68ki_cpu.s_flag >> 1) & m68ki_cpu.m_flag)] =
      m68ki_cpu.dar[15];

  m68ki_cpu.s_flag = value & 4;
  m68ki_cpu.m_flag = value & 2;

  m68ki_cpu.dar[15] =
      m68ki_cpu
          .sp[m68ki_cpu.s_flag | ((m68ki_cpu.s_flag >> 1) & m68ki_cpu.m_flag)];
}

U0 m68ki_set_ccr(U32 value) {
  m68ki_cpu.x_flag = ((value)&0x00000010) << 4;
  m68ki_cpu.n_flag = ((value)&0x00000008) << 4;
  m68ki_cpu.not_z_flag = !((value)&0x00000004);
  m68ki_cpu.v_flag = ((value)&0x00000002) << 6;
  m68ki_cpu.c_flag = ((value)&0x00000001) << 8;
}

U0 m68ki_set_sr_noint(U32 value) {

  value &= m68ki_cpu.sr_mask;

  m68ki_cpu.t1_flag = ((value)&0x00008000);
  m68ki_cpu.t0_flag = ((value)&0x00004000);
  m68ki_cpu.int_mask = value & 0x0700;
  m68ki_set_ccr(value);
  m68ki_set_sm_flag((value >> 11) & 6);
}

U32 m68ki_init_exception() {

  U32 sr =
      (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
       (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
       (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
        ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
        ((m68ki_cpu.c_flag & 0x100) >> 8)));

  m68ki_cpu.t1_flag = m68ki_cpu.t0_flag = 0;
  ;

  m68ki_set_s_flag(4);

  return sr;
}

U0 m68ki_stack_frame_3word(U32 pc, U32 sr) {
  m68ki_push_32(pc);
  m68ki_push_16(sr);
}

U0 m68ki_stack_frame_0000(U32 pc, U32 sr, U32 vector) {

  if (m68ki_cpu.cpu_type == 1) {
    m68ki_stack_frame_3word(pc, sr);
    return;
  }
  m68ki_push_16(vector << 2);
  m68ki_push_32(pc);
  m68ki_push_16(sr);
}

U0 m68ki_stack_frame_0001(U32 pc, U32 sr, U32 vector) {
  m68ki_push_16(0x1000 | (vector << 2));
  m68ki_push_32(pc);
  m68ki_push_16(sr);
}

U0 m68ki_stack_frame_0010(U32 sr, U32 vector) {
  m68ki_push_32(m68ki_cpu.ppc);
  m68ki_push_16(0x2000 | (vector << 2));
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_push_16(sr);
}

U0 m68ki_stack_frame_buserr(U32 pc, U32 sr, U32 address, U32 write,
                            U32 instruction, U32 fc) {
  m68ki_push_32(pc);
  m68ki_push_16(sr);
  m68ki_push_16(m68ki_cpu.ir);
  m68ki_push_32(address);

  m68ki_push_16(((!write) << 4) | ((!instruction) << 3) | fc);
}

U0 m68ki_stack_frame_1000(U32 pc, U32 sr, U32 vector) {

  m68ki_fake_push_32();
  m68ki_fake_push_32();
  m68ki_fake_push_32();
  m68ki_fake_push_32();
  m68ki_fake_push_32();
  m68ki_fake_push_32();
  m68ki_fake_push_32();
  m68ki_fake_push_32();

  m68ki_push_16(0);

  m68ki_fake_push_16();

  m68ki_push_16(0);

  m68ki_fake_push_16();

  m68ki_push_16(0);

  m68ki_fake_push_16();

  m68ki_push_32(0);

  m68ki_push_16(0);

  m68ki_push_16(0x8000 | (vector << 2));

  m68ki_push_32(pc);

  m68ki_push_16(sr);
}

U0 m68ki_stack_frame_1010(U32 sr, U32 vector, U32 pc) {

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_32(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_32(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_16(0xa000 | (vector << 2));

  m68ki_push_32(pc);

  m68ki_push_16(sr);
}

U0 m68ki_stack_frame_1011(U32 sr, U32 vector, U32 pc) {

  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);
  m68ki_push_32(0);

  m68ki_push_16(0);

  m68ki_push_32(0);
  m68ki_push_16(0);

  m68ki_push_32(0);

  m68ki_push_32(0);

  m68ki_push_32(0);

  m68ki_push_32(0);
  m68ki_push_32(0);

  m68ki_push_32(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_32(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_16(0);

  m68ki_push_16(0xb000 | (vector << 2));

  m68ki_push_32(pc);

  m68ki_push_16(sr);
}

U0 m68ki_exception_trap(U32 vector) {
  U32 sr = m68ki_init_exception();

  if (((m68ki_cpu.cpu_type) & (1 | 2)))
    m68ki_stack_frame_0000(m68ki_cpu.pc, sr, vector);
  else
    m68ki_stack_frame_0010(sr, vector);

  m68ki_jump_vector(vector);

  m68ki_remaining_cycles -= (m68ki_cpu.cyc_exception[vector]);
}

U0 m68ki_exception_trapN(U32 vector) {
  U32 sr = m68ki_init_exception();
  m68ki_stack_frame_0000(m68ki_cpu.pc, sr, vector);
  m68ki_jump_vector(vector);

  m68ki_remaining_cycles -= (m68ki_cpu.cyc_exception[vector]);
}

U0 m68ki_exception_trace() {
  U32 sr = m68ki_init_exception();

  if (((m68ki_cpu.cpu_type) & (1 | 2)))
    m68ki_stack_frame_0000(m68ki_cpu.pc, sr, 9);
  else
    m68ki_stack_frame_0010(sr, 9);

  m68ki_jump_vector(9);

  m68ki_cpu.stopped &= ~1;

  m68ki_remaining_cycles -= (m68ki_cpu.cyc_exception[9]);
}

U0 m68ki_exception_privilege_violation() {
  U32 sr = m68ki_init_exception();
  m68ki_stack_frame_0000(m68ki_cpu.pc, sr, 8);
  m68ki_jump_vector(8);

  m68ki_remaining_cycles -=
      (m68ki_cpu.cyc_exception[8] - m68ki_cpu.cyc_instruction[m68ki_cpu.ir]);
}

U0 m68ki_exception_1010() {
  U32 sr;

  sr = m68ki_init_exception();
  m68ki_stack_frame_0000(m68ki_cpu.pc - 2, sr, 10);
  m68ki_jump_vector(10);

  m68ki_remaining_cycles -=
      (m68ki_cpu.cyc_exception[10] - m68ki_cpu.cyc_instruction[m68ki_cpu.ir]);
}

U0 m68ki_exception_1111() {
  U32 sr;

  sr = m68ki_init_exception();
  m68ki_stack_frame_0000(m68ki_cpu.pc - 2, sr, 11);
  m68ki_jump_vector(11);

  m68ki_remaining_cycles -=
      (m68ki_cpu.cyc_exception[11] - m68ki_cpu.cyc_instruction[m68ki_cpu.ir]);
}

U0 m68ki_exception_illegal() {
  U32 sr;

  ;

  sr = m68ki_init_exception();
  m68ki_stack_frame_0000(m68ki_cpu.pc, sr, 4);
  m68ki_jump_vector(4);

  m68ki_remaining_cycles -=
      (m68ki_cpu.cyc_exception[4] - m68ki_cpu.cyc_instruction[m68ki_cpu.ir]);
}

U0 m68ki_exception_format_error() {
  U32 sr = m68ki_init_exception();
  m68ki_stack_frame_0000(m68ki_cpu.pc, sr, 14);
  m68ki_jump_vector(14);

  m68ki_remaining_cycles -=
      (m68ki_cpu.cyc_exception[14] - m68ki_cpu.cyc_instruction[m68ki_cpu.ir]);
}

U0 m68ki_exception_address_error() {}

U0 m68ki_exception_interrupt(U32 int_level) {
  U32 vector;
  U32 sr;
  U32 new_pc;

  m68ki_cpu.stopped &= ~1;

  if (m68ki_cpu.stopped)
    return;

  vector = 0xffffffff;

  if (vector == 0xffffffff)

    vector = 24 + int_level;
  else if (vector == 0xfffffffe)

    vector = 24;
  else if (vector > 255) {

    ;
    return;
  }

  sr = m68ki_init_exception();

  m68ki_cpu.int_mask = int_level << 8;

  new_pc =
      m68ki_read_32_fc((vector << 2) + m68ki_cpu.vbr, m68ki_cpu.s_flag | 1);

  if (new_pc == 0)
    new_pc = m68ki_read_32_fc((15 << 2) + m68ki_cpu.vbr, m68ki_cpu.s_flag | 1);

  m68ki_stack_frame_0000(m68ki_cpu.pc, sr, vector);
  if (m68ki_cpu.m_flag && ((m68ki_cpu.cpu_type) & (4 | 8))) {

    m68ki_set_sm_flag(m68ki_cpu.s_flag);
    sr |= 0x2000;
    m68ki_stack_frame_0001(m68ki_cpu.pc, sr, vector);
  }

  m68ki_jump(new_pc);

  m68ki_cpu.int_cycles += m68ki_cpu.cyc_exception[vector];

  m68ki_cpu.int_level = 0;
}

U0 m68ki_check_interrupts() {
  if (m68ki_cpu.int_level > m68ki_cpu.int_mask)
    m68ki_exception_interrupt(m68ki_cpu.int_level >> 8);
}

U0 m68ki_set_sr(U32 value) {
  m68ki_set_sr_noint(value);
  m68ki_check_interrupts();
}

U0 m68k_op_1010() { m68ki_exception_1010(); }

U0 m68k_op_1111() { m68ki_exception_1111(); }

U0 m68k_op_abcd_8_rr() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 dst = *r_dst;
  U32 res = ((src)&0x0f) + ((dst)&0x0f) + ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res += 6;
  res += ((src)&0xf0) + ((dst)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res -= 0xa0;

  m68ki_cpu.n_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xff) | res;
}

U0 m68k_op_abcd_8_mm_ax7() {
  U32 src = OPER_AY_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src)&0x0f) + ((dst)&0x0f) + ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res += 6;
  res += ((src)&0xf0) + ((dst)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res -= 0xa0;

  m68ki_cpu.n_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_abcd_8_mm_ay7() {
  U32 src = OPER_A7_PD_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src)&0x0f) + ((dst)&0x0f) + ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res += 6;
  res += ((src)&0xf0) + ((dst)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res -= 0xa0;

  m68ki_cpu.n_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_abcd_8_mm_axy7() {
  U32 src = OPER_A7_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src)&0x0f) + ((dst)&0x0f) + ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res += 6;
  res += ((src)&0xf0) + ((dst)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res -= 0xa0;

  m68ki_cpu.n_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_abcd_8_mm() {
  U32 src = OPER_AY_PD_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src)&0x0f) + ((dst)&0x0f) + ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res += 6;
  res += ((src)&0xf0) + ((dst)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res -= 0xa0;

  m68ki_cpu.n_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_add_8_er_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_AI_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PI_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_pi7() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_A7_PI_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PD_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_pd7() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_A7_PD_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_DI_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_IX_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AW_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AL_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCDI_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCIX_8();
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_er_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_a() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_AI_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PI_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PD_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_DI_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_IX_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AW_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AL_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCDI_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCIX_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_16_er_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = m68ki_read_imm_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_a() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_AI_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PI_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PD_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_DI_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_IX_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AW_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AL_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCDI_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCIX_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_32_er_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = m68ki_read_imm_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_add_8_re_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_pi() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_pi7() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_pd() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_pd7() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_8_re_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_16_re_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_add_32_re_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_adda_16_d() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7])));
}

U0 m68k_op_adda_16_a() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])));
}

U0 m68k_op_adda_16_ai() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AY_AI_16()));
}

U0 m68k_op_adda_16_pi() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AY_PI_16()));
}

U0 m68k_op_adda_16_pd() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AY_PD_16()));
}

U0 m68k_op_adda_16_di() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AY_DI_16()));
}

U0 m68k_op_adda_16_ix() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AY_IX_16()));
}

U0 m68k_op_adda_16_aw() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AW_16()));
}

U0 m68k_op_adda_16_al() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_AL_16()));
}

U0 m68k_op_adda_16_pcdi() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_PCDI_16()));
}

U0 m68k_op_adda_16_pcix() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(OPER_PCIX_16()));
}

U0 m68k_op_adda_16_i() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + MAKE_INT_16(m68ki_read_imm_16()));
}

U0 m68k_op_adda_32_d() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + (m68ki_cpu.dar[m68ki_cpu.ir & 7]));
}

U0 m68k_op_adda_32_a() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
}

U0 m68k_op_adda_32_ai() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AY_AI_32());
}

U0 m68k_op_adda_32_pi() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AY_PI_32());
}

U0 m68k_op_adda_32_pd() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AY_PD_32());
}

U0 m68k_op_adda_32_di() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AY_DI_32());
}

U0 m68k_op_adda_32_ix() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AY_IX_32());
}

U0 m68k_op_adda_32_aw() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AW_32());
}

U0 m68k_op_adda_32_al() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_AL_32());
}

U0 m68k_op_adda_32_pcdi() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_PCDI_32());
}

U0 m68k_op_adda_32_pcix() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + OPER_PCIX_32());
}

U0 m68k_op_adda_32_i() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst + m68ki_read_imm_32());
}

U0 m68k_op_addi_8_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_addi_8_ai() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_pi() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_pi7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_pd() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_pd7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_di() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_ix() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_aw() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_8_al() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_read_imm_32();
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_imm_16();
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_addi_16_ai() {
  U32 src = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_pi() {
  U32 src = m68ki_read_imm_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_pd() {
  U32 src = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_di() {
  U32 src = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_ix() {
  U32 src = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_aw() {
  U32 src = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_16_al() {
  U32 src = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_imm_32();
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_addi_32_ai() {
  U32 src = m68ki_read_imm_32();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_pi() {
  U32 src = m68ki_read_imm_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_pd() {
  U32 src = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_di() {
  U32 src = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_ix() {
  U32 src = m68ki_read_imm_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_aw() {
  U32 src = m68ki_read_imm_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addi_32_al() {
  U32 src = m68ki_read_imm_32();
  U32 ea = m68ki_read_imm_32();
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_addq_8_ai() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_pi() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_pi7() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_pd() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_pd7() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_di() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_ix() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_aw() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_8_al() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = m68ki_read_imm_32();
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_addq_16_a() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  *r_dst = (*r_dst + (((m68ki_cpu.ir >> 9) - 1) & 7) + 1);
}

U0 m68k_op_addq_16_ai() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_pi() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_pd() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_di() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_ix() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_aw() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_16_al() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = m68ki_read_imm_32();
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 dst = *r_dst;
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_addq_32_a() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  *r_dst = (*r_dst + (((m68ki_cpu.ir >> 9) - 1) & 7) + 1);
}

U0 m68k_op_addq_32_ai() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_pi() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_pd() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_di() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_ix() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_aw() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addq_32_al() {
  U32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 ea = m68ki_read_imm_32();
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_addx_8_rr() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 dst = ((*r_dst) & 0xff);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xff) | res;
}

U0 m68k_op_addx_16_rr() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 dst = ((*r_dst) & 0xffff);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xffff) | res;
}

U0 m68k_op_addx_32_rr() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 dst = *r_dst;
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = res;
}

U0 m68k_op_addx_8_mm_ax7() {
  U32 src = OPER_AY_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_addx_8_mm_ay7() {
  U32 src = OPER_A7_PD_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_addx_8_mm_axy7() {
  U32 src = OPER_A7_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_addx_8_mm() {
  U32 src = OPER_AY_PD_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  U32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.v_flag = ((src ^ res) & (dst ^ res));
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_addx_16_mm() {
  U32 src = OPER_AY_PD_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);
  U32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_addx_32_mm() {
  U32 src = OPER_AY_PD_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);
  U32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src + dst + ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = (((src ^ res) & (dst ^ res)) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & dst) | (~res & (src | dst))) >> 23);

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_8_er_d() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           ((m68ki_cpu.dar[m68ki_cpu.ir & 7]) | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_ai() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_AI_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_pi() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_PI_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_pi7() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_A7_PI_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_pd() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_PD_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_pd7() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_A7_PD_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_di() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_DI_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_ix() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_IX_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_aw() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AW_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_al() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AL_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_pcdi() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_PCDI_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_pcix() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_PCIX_8() | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_er_i() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (((m68ki_read_imm_16()) & 0xff) | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_d() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           ((m68ki_cpu.dar[m68ki_cpu.ir & 7]) | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_ai() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_AI_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_pi() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_PI_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_pd() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_PD_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_di() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_DI_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_ix() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AY_IX_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_aw() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AW_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_al() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_AL_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_pcdi() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_PCDI_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_pcix() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (OPER_PCIX_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_16_er_i() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
                           (m68ki_read_imm_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_d() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      (m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_ai() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AY_AI_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_pi() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AY_PI_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_pd() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AY_PD_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_di() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AY_DI_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_ix() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AY_IX_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_aw() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AW_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_al() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_AL_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_pcdi() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_PCDI_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_pcix() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      OPER_PCIX_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_32_er_i() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &=
      m68ki_read_imm_32();

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_and_8_re_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_pi() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_pi7() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_pd() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_pd7() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_8_re_al() {
  U32 ea = m68ki_read_imm_32();
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_16_re_al() {
  U32 ea = m68ki_read_imm_32();
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_and_32_re_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_32_re_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_32_re_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_32_re_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_32_re_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_32_re_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_and_32_re_al() {
  U32 ea = m68ki_read_imm_32();
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) &
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_d() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) &=
                           (((m68ki_read_imm_16()) & 0xff) | 0xffffff00)) &
                          0xff);

  m68ki_cpu.n_flag = (m68ki_cpu.not_z_flag);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_andi_8_ai() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_pi() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_pi7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_pd() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_pd7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_di() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_ix() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_aw() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_8_al() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_read_imm_32();
  U32 res = src & m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_d() {
  m68ki_cpu.not_z_flag = (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) &=
                           (m68ki_read_imm_16() | 0xffff0000)) &
                          0xffff);

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 8);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_andi_16_ai() {
  U32 src = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_pi() {
  U32 src = m68ki_read_imm_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_pd() {
  U32 src = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_di() {
  U32 src = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_ix() {
  U32 src = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_aw() {
  U32 src = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_al() {
  U32 src = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 res = src & m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_d() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &=
      (m68ki_read_imm_32());

  m68ki_cpu.n_flag = ((m68ki_cpu.not_z_flag) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_andi_32_ai() {
  U32 src = m68ki_read_imm_32();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_pi() {
  U32 src = m68ki_read_imm_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_pd() {
  U32 src = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_di() {
  U32 src = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_ix() {
  U32 src = m68ki_read_imm_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_aw() {
  U32 src = m68ki_read_imm_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_32_al() {
  U32 src = m68ki_read_imm_32();
  U32 ea = m68ki_read_imm_32();
  U32 res = src & m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_andi_16_toc() {
  m68ki_set_ccr(
      (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
       ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
       ((m68ki_cpu.c_flag & 0x100) >> 8)) &
      m68ki_read_imm_16());
}

U0 m68k_op_andi_16_tos() {
  if (m68ki_cpu.s_flag) {
    U32 src = m68ki_read_imm_16();
    ;
    m68ki_set_sr(
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))) &
        src);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_asr_8_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xff);
  U32 res = src >> shift;

  if (((src)&0x80))
    res |= m68ki_shift_8_table[shift];

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
}

U0 m68k_op_asr_16_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = src >> shift;

  if (((src)&0x8000))
    res |= m68ki_shift_16_table[shift];

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
}

U0 m68k_op_asr_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = src >> shift;

  if (((src)&0x80000000))
    res |= m68ki_shift_32_table[shift];

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
}

U0 m68k_op_asr_8_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xff);
  U32 res = src >> shift;

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 8) {
      if (((src)&0x80))
        res |= m68ki_shift_8_table[shift];

      *r_dst = ((*r_dst) & ~0xff) | res;

      m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
      m68ki_cpu.n_flag = (res);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    if (((src)&0x80)) {
      *r_dst |= 0xff;
      m68ki_cpu.c_flag = 0x100;
      m68ki_cpu.x_flag = 0x100;
      m68ki_cpu.n_flag = 0x80;
      m68ki_cpu.not_z_flag = 0xffffffff;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst &= 0xffffff00;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = (src);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_asr_16_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = src >> shift;

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 16) {
      if (((src)&0x8000))
        res |= m68ki_shift_16_table[shift];

      *r_dst = ((*r_dst) & ~0xffff) | res;

      m68ki_cpu.c_flag = m68ki_cpu.x_flag = (src >> (shift - 1)) << 8;
      m68ki_cpu.n_flag = ((res) >> 8);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    if (((src)&0x8000)) {
      *r_dst |= 0xffff;
      m68ki_cpu.c_flag = 0x100;
      m68ki_cpu.x_flag = 0x100;
      m68ki_cpu.n_flag = 0x80;
      m68ki_cpu.not_z_flag = 0xffffffff;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst &= 0xffff0000;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 8);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_asr_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = *r_dst;
  U32 res = src >> shift;

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 32) {
      if (((src)&0x80000000))
        res |= m68ki_shift_32_table[shift];

      *r_dst = res;

      m68ki_cpu.c_flag = m68ki_cpu.x_flag = (src >> (shift - 1)) << 8;
      m68ki_cpu.n_flag = ((res) >> 24);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    if (((src)&0x80000000)) {
      *r_dst = 0xffffffff;
      m68ki_cpu.c_flag = 0x100;
      m68ki_cpu.x_flag = 0x100;
      m68ki_cpu.n_flag = 0x80;
      m68ki_cpu.not_z_flag = 0xffffffff;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst = 0;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 24);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_asr_16_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asr_16_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asr_16_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asr_16_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asr_16_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asr_16_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asr_16_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  if (((src)&0x8000))
    res |= 0x8000;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
}

U0 m68k_op_asl_8_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xff);
  U32 res = ((src << shift) & 0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << shift;
  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  src &= m68ki_shift_8_table[shift + 1];
  m68ki_cpu.v_flag =
      (!(src == 0 || (src == m68ki_shift_8_table[shift + 1] && shift < 8)))
      << 7;
}

U0 m68k_op_asl_16_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = ((src << shift) & 0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> (8 - shift);
  src &= m68ki_shift_16_table[shift + 1];
  m68ki_cpu.v_flag = (!(src == 0 || src == m68ki_shift_16_table[shift + 1]))
                     << 7;
}

U0 m68k_op_asl_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = (src << shift);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> (24 - shift);
  src &= m68ki_shift_32_table[shift + 1];
  m68ki_cpu.v_flag = (!(src == 0 || src == m68ki_shift_32_table[shift + 1]))
                     << 7;
}

U0 m68k_op_asl_8_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xff);
  U32 res = ((src << shift) & 0xff);

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 8) {
      *r_dst = ((*r_dst) & ~0xff) | res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << shift;
      m68ki_cpu.n_flag = (res);
      m68ki_cpu.not_z_flag = res;
      src &= m68ki_shift_8_table[shift + 1];
      m68ki_cpu.v_flag = (!(src == 0 || src == m68ki_shift_8_table[shift + 1]))
                         << 7;
      return;
    }

    *r_dst &= 0xffffff00;
    m68ki_cpu.x_flag = m68ki_cpu.c_flag = T(shift == 8, src & 1, 0) << 8;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = (!(src == 0)) << 7;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = (src);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_asl_16_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = ((src << shift) & 0xffff);

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 16) {
      *r_dst = ((*r_dst) & ~0xffff) | res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = (src << shift) >> 8;
      m68ki_cpu.n_flag = ((res) >> 8);
      m68ki_cpu.not_z_flag = res;
      src &= m68ki_shift_16_table[shift + 1];
      m68ki_cpu.v_flag = (!(src == 0 || src == m68ki_shift_16_table[shift + 1]))
                         << 7;
      return;
    }

    *r_dst &= 0xffff0000;
    m68ki_cpu.x_flag = m68ki_cpu.c_flag = T(shift == 16, src & 1, 0) << 8;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = (!(src == 0)) << 7;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 8);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_asl_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = *r_dst;
  U32 res = (src << shift);

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 32) {
      *r_dst = res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = (src >> (32 - shift)) << 8;
      m68ki_cpu.n_flag = ((res) >> 24);
      m68ki_cpu.not_z_flag = res;
      src &= m68ki_shift_32_table[shift + 1];
      m68ki_cpu.v_flag = (!(src == 0 || src == m68ki_shift_32_table[shift + 1]))
                         << 7;
      return;
    }

    *r_dst = 0;
    m68ki_cpu.x_flag = m68ki_cpu.c_flag = T(shift == 32, src & 1, 0) << 8;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = (!(src == 0)) << 7;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 24);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_asl_16_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_asl_16_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_asl_16_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_asl_16_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_asl_16_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_asl_16_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_asl_16_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  src &= 0xc000;
  m68ki_cpu.v_flag = (!(src == 0 || src == 0xc000)) << 7;
}

U0 m68k_op_bhi_8() {
  if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bls_8() {
  if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bcc_8() {
  if ((!(m68ki_cpu.c_flag & 0x100))) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bcs_8() {
  if ((m68ki_cpu.c_flag & 0x100)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bne_8() {
  if (m68ki_cpu.not_z_flag) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_beq_8() {
  if ((!m68ki_cpu.not_z_flag)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bvc_8() {
  if ((!(m68ki_cpu.v_flag & 0x80))) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bvs_8() {
  if ((m68ki_cpu.v_flag & 0x80)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bpl_8() {
  if ((!(m68ki_cpu.n_flag & 0x80))) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bmi_8() {
  if ((m68ki_cpu.n_flag & 0x80)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bge_8() {
  if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_blt_8() {
  if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bgt_8() {
  if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
       m68ki_cpu.not_z_flag)) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_ble_8() {
  if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
       (!m68ki_cpu.not_z_flag))) {
    ;
    m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
    return;
  }
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_b);
}

U0 m68k_op_bhi_16() {
  if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bls_16() {
  if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bcc_16() {
  if ((!(m68ki_cpu.c_flag & 0x100))) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bcs_16() {
  if ((m68ki_cpu.c_flag & 0x100)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bne_16() {
  if (m68ki_cpu.not_z_flag) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_beq_16() {
  if ((!m68ki_cpu.not_z_flag)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bvc_16() {
  if ((!(m68ki_cpu.v_flag & 0x80))) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bvs_16() {
  if ((m68ki_cpu.v_flag & 0x80)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bpl_16() {
  if ((!(m68ki_cpu.n_flag & 0x80))) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bmi_16() {
  if ((m68ki_cpu.n_flag & 0x80)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bge_16() {
  if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_blt_16() {
  if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bgt_16() {
  if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
       m68ki_cpu.not_z_flag)) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_ble_16() {
  if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
       (!m68ki_cpu.not_z_flag))) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
  m68ki_remaining_cycles -= (m68ki_cpu.cyc_bcc_notake_w);
}

U0 m68k_op_bhi_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bls_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bcc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.c_flag & 0x100))) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bcs_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.c_flag & 0x100)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bne_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (m68ki_cpu.not_z_flag) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_beq_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!m68ki_cpu.not_z_flag)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bvc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.v_flag & 0x80))) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bvs_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.v_flag & 0x80)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bpl_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.n_flag & 0x80))) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bmi_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.n_flag & 0x80)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bge_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_blt_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bgt_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
         m68ki_cpu.not_z_flag)) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_ble_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
         (!m68ki_cpu.not_z_flag))) {
      U32 offset = m68ki_read_imm_32();
      m68ki_cpu.pc -= 4;
      ;
      m68ki_branch_32(offset);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bchg_32_r_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x1f);

  m68ki_cpu.not_z_flag = *r_dst & mask;
  *r_dst ^= mask;
}

U0 m68k_op_bchg_8_r_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_pi() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_pi7() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_pd() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_pd7() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_r_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_32_s_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 0x1f);

  m68ki_cpu.not_z_flag = *r_dst & mask;
  *r_dst ^= mask;
}

U0 m68k_op_bchg_8_s_ai() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_pi() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_pi7() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_pd() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_pd7() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_di() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_ix() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_aw() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bchg_8_s_al() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src ^ mask);
}

U0 m68k_op_bclr_32_r_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x1f);

  m68ki_cpu.not_z_flag = *r_dst & mask;
  *r_dst &= ~mask;
}

U0 m68k_op_bclr_8_r_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_pi() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_pi7() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_pd() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_pd7() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_r_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_32_s_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 0x1f);

  m68ki_cpu.not_z_flag = *r_dst & mask;
  *r_dst &= ~mask;
}

U0 m68k_op_bclr_8_s_ai() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_pi() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_pi7() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_pd() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_pd7() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_di() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_ix() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_aw() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bclr_8_s_al() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src & ~mask);
}

U0 m68k_op_bfchg_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 *data = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 mask;

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    mask = (0xffffffff << (32 - width));
    mask = (T((offset) < 32, (mask) >> (offset), 0) |
            T((32 - (offset)) < 32, (mask) << (32 - (offset)), 0));

    m68ki_cpu.n_flag = ((*data << offset) >> 24);
    m68ki_cpu.not_z_flag = *data & mask;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    *data ^= mask;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfchg_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long ^ mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte ^ mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfchg_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long ^ mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte ^ mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfchg_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long ^ mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte ^ mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfchg_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long ^ mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte ^ mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfchg_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long ^ mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte ^ mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfclr_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 *data = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 mask;

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    mask = (0xffffffff << (32 - width));
    mask = (T((offset) < 32, (mask) >> (offset), 0) |
            T((32 - (offset)) < 32, (mask) << (32 - (offset)), 0));

    m68ki_cpu.n_flag = ((*data << offset) >> 24);
    m68ki_cpu.not_z_flag = *data & mask;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    *data &= ~mask;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfclr_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long & ~mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte & ~mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfclr_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long & ~mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte & ~mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfclr_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long & ~mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte & ~mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfclr_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long & ~mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte & ~mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfclr_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long & ~mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte & ~mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    data = (T((offset) < 32, (data) << (offset), 0) |
            T((32 - (offset)) < 32, (data) >> (32 - (offset)), 0));
    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_get_ea_pcdi();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfexts_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_get_ea_pcix();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data = MAKE_INT_32(data) >> (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    data = (T((offset) < 32, (data) << (offset), 0) |
            T((32 - (offset)) < 32, (data) >> (32 - (offset)), 0));
    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= 32 - width;

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_get_ea_pcdi();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfextu_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data;
    U32 ea = m68ki_get_ea_pcix();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << offset);

    if ((offset + width) > 32)
      data |= (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_cpu.dar[(word2 >> 12) & 7] = data;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 data = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 bit;

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    data = (T((offset) < 32, (data) << (offset), 0) |
            T((32 - (offset)) < 32, (data) >> (32 - (offset)), 0));
    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= 32 - width;

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = m68ki_get_ea_pcdi();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfffo_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    I32 local_offset;
    U32 width = word2;
    U32 data;
    U32 bit;
    U32 ea = m68ki_get_ea_pcix();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    local_offset = offset % 8;
    if (local_offset < 0) {
      local_offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    data = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    data = (data << local_offset);

    if ((local_offset + width) > 32)
      data |=
          (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << local_offset) >> 8;

    m68ki_cpu.n_flag = ((data) >> 24);
    data >>= (32 - width);

    m68ki_cpu.not_z_flag = data;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    for (bit = 1 << (width - 1); bit && !(data & bit); bit >>= 1)
      offset++;

    m68ki_cpu.dar[(word2 >> 12) & 7] = offset;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfins_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 *data = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 mask;
    U32 insert = m68ki_cpu.dar[(word2 >> 12) & 7];

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    mask = (0xffffffff << (32 - width));
    mask = (T((offset) < 32, (mask) >> (offset), 0) |
            T((32 - (offset)) < 32, (mask) << (32 - (offset)), 0));

    insert = (insert << (32 - width));
    m68ki_cpu.n_flag = ((insert) >> 24);
    m68ki_cpu.not_z_flag = insert;
    insert = (T((offset) < 32, (insert) >> (offset), 0) |
              T((32 - (offset)) < 32, (insert) << (32 - (offset)), 0));

    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    *data &= ~mask;
    *data |= insert;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfins_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 insert_base = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 insert_long;
    U32 insert_byte;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    insert_base = (insert_base << (32 - width));
    m68ki_cpu.n_flag = ((insert_base) >> 24);
    m68ki_cpu.not_z_flag = insert_base;
    insert_long = insert_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                      (data_long & ~mask_long) | insert_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      insert_byte = ((insert_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1,
                       (data_byte & ~mask_byte) | insert_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfins_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 insert_base = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 insert_long;
    U32 insert_byte;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    insert_base = (insert_base << (32 - width));
    m68ki_cpu.n_flag = ((insert_base) >> 24);
    m68ki_cpu.not_z_flag = insert_base;
    insert_long = insert_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                      (data_long & ~mask_long) | insert_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      insert_byte = ((insert_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1,
                       (data_byte & ~mask_byte) | insert_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfins_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 insert_base = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 insert_long;
    U32 insert_byte;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    insert_base = (insert_base << (32 - width));
    m68ki_cpu.n_flag = ((insert_base) >> 24);
    m68ki_cpu.not_z_flag = insert_base;
    insert_long = insert_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                      (data_long & ~mask_long) | insert_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      insert_byte = ((insert_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1,
                       (data_byte & ~mask_byte) | insert_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfins_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 insert_base = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 insert_long;
    U32 insert_byte;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    insert_base = (insert_base << (32 - width));
    m68ki_cpu.n_flag = ((insert_base) >> 24);
    m68ki_cpu.not_z_flag = insert_base;
    insert_long = insert_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                      (data_long & ~mask_long) | insert_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      insert_byte = ((insert_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1,
                       (data_byte & ~mask_byte) | insert_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfins_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 insert_base = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 insert_long;
    U32 insert_byte;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    insert_base = (insert_base << (32 - width));
    m68ki_cpu.n_flag = ((insert_base) >> 24);
    m68ki_cpu.not_z_flag = insert_base;
    insert_long = insert_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                      (data_long & ~mask_long) | insert_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      insert_byte = ((insert_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1,
                       (data_byte & ~mask_byte) | insert_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfset_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 *data = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 mask;

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    mask = (0xffffffff << (32 - width));
    mask = (T((offset) < 32, (mask) >> (offset), 0) |
            T((32 - (offset)) < 32, (mask) << (32 - (offset)), 0));

    m68ki_cpu.n_flag = ((*data << offset) >> 24);
    m68ki_cpu.not_z_flag = *data & mask;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    *data |= mask;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfset_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long | mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte | mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfset_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long | mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte | mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfset_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long | mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte | mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfset_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long | mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte | mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bfset_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long << offset) >> 24);
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, data_long | mask_long);

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
      m68ki_write_8_fc(ea + 4, m68ki_cpu.s_flag | 1, data_byte | mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 *data = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 mask;

    if (((word2)&0x00000800))
      offset = m68ki_cpu.dar[offset & 7];
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    offset &= 31;
    width = ((width - 1) & 31) + 1;

    mask = (0xffffffff << (32 - width));
    mask = (T((offset) < 32, (mask) >> (offset), 0) |
            T((32 - (offset)) < 32, (mask) << (32 - (offset)), 0));

    m68ki_cpu.n_flag = ((*data << offset) >> 24);
    m68ki_cpu.not_z_flag = *data & mask;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_read_imm_32();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_pcdi();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bftst_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    I32 offset = (word2 >> 6) & 31;
    U32 width = word2;
    U32 mask_base;
    U32 data_long;
    U32 mask_long;
    U32 data_byte = 0;
    U32 mask_byte = 0;
    U32 ea = m68ki_get_ea_pcix();

    if (((word2)&0x00000800))
      offset = MAKE_INT_32(m68ki_cpu.dar[offset & 7]);
    if (((word2)&0x00000020))
      width = m68ki_cpu.dar[width & 7];

    ea += offset / 8;
    offset %= 8;
    if (offset < 0) {
      offset += 8;
      ea--;
    }
    width = ((width - 1) & 31) + 1;

    mask_base = (0xffffffff << (32 - width));
    mask_long = mask_base >> offset;

    data_long = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    m68ki_cpu.n_flag = ((data_long & (0x80000000 >> offset)) << offset) >> 24;
    m68ki_cpu.not_z_flag = data_long & mask_long;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;

    if ((width + offset) > 32) {
      mask_byte = ((mask_base)&0xff);
      data_byte = m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1);
      m68ki_cpu.not_z_flag |= (data_byte & mask_byte);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bkpt() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    ;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bra_8() {
  ;
  m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_bra_16() {
  U32 offset = m68ki_read_imm_16();
  m68ki_cpu.pc -= 2;
  ;
  m68ki_branch_16(offset);
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_bra_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 offset = m68ki_read_imm_32();
    m68ki_cpu.pc -= 4;
    ;
    m68ki_branch_32(offset);
    if (m68ki_cpu.pc == m68ki_cpu.ppc)
      m68ki_remaining_cycles = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_bset_32_r_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x1f);

  m68ki_cpu.not_z_flag = *r_dst & mask;
  *r_dst |= mask;
}

U0 m68k_op_bset_8_r_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_pi() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_pi7() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_pd() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_pd7() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_r_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  U32 mask = 1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_32_s_d() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 0x1f);

  m68ki_cpu.not_z_flag = *r_dst & mask;
  *r_dst |= mask;
}

U0 m68k_op_bset_8_s_ai() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_pi() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_pi7() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_pd() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_pd7() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_di() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_ix() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_aw() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bset_8_s_al() {
  U32 mask = 1 << (((m68ki_read_imm_16()) & 0xff) & 7);
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = src & mask;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, src | mask);
}

U0 m68k_op_bsr_8() {
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_branch_8(((m68ki_cpu.ir) & 0xff));
}

U0 m68k_op_bsr_16() {
  U32 offset = m68ki_read_imm_16();
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_cpu.pc -= 2;
  m68ki_branch_16(offset);
}

U0 m68k_op_bsr_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 offset = m68ki_read_imm_32();
    ;
    m68ki_push_32(m68ki_cpu.pc);
    m68ki_cpu.pc -= 4;
    m68ki_branch_32(offset);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_btst_32_r_d() {
  m68ki_cpu.not_z_flag =
      (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &
      (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x1f));
}

U0 m68k_op_btst_8_r_ai() {
  m68ki_cpu.not_z_flag =
      OPER_AY_AI_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_pi() {
  m68ki_cpu.not_z_flag =
      OPER_AY_PI_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_pi7() {
  m68ki_cpu.not_z_flag =
      OPER_A7_PI_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_pd() {
  m68ki_cpu.not_z_flag =
      OPER_AY_PD_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_pd7() {
  m68ki_cpu.not_z_flag =
      OPER_A7_PD_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_di() {
  m68ki_cpu.not_z_flag =
      OPER_AY_DI_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_ix() {
  m68ki_cpu.not_z_flag =
      OPER_AY_IX_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_aw() {
  m68ki_cpu.not_z_flag =
      OPER_AW_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_al() {
  m68ki_cpu.not_z_flag =
      OPER_AL_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_pcdi() {
  m68ki_cpu.not_z_flag =
      OPER_PCDI_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_pcix() {
  m68ki_cpu.not_z_flag =
      OPER_PCIX_8() & (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_8_r_i() {
  m68ki_cpu.not_z_flag = ((m68ki_read_imm_16()) & 0xff) &
                         (1 << ((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 7));
}

U0 m68k_op_btst_32_s_d() {
  m68ki_cpu.not_z_flag = (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &
                         (1 << (((m68ki_read_imm_16()) & 0xff) & 0x1f));
}

U0 m68k_op_btst_8_s_ai() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AY_AI_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_pi() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AY_PI_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_pi7() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_A7_PI_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_pd() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AY_PD_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_pd7() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_A7_PD_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_di() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AY_DI_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_ix() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AY_IX_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_aw() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AW_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_al() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_AL_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_pcdi() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_PCDI_8() & (1 << bit);
}

U0 m68k_op_btst_8_s_pcix() {
  U32 bit = ((m68ki_read_imm_16()) & 0xff) & 7;

  m68ki_cpu.not_z_flag = OPER_PCIX_8() & (1 << bit);
}

U0 m68k_op_callm_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_callm_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_callm_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_callm_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_callm_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = m68ki_read_imm_32();
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_callm_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = m68ki_get_ea_pcdi();
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_callm_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 ea = m68ki_get_ea_pcix();
    no_warn ea;
    ;
    m68ki_cpu.pc += 2;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_pi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_pi7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_pd() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_pd7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_8_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = m68ki_read_imm_32();
    U32 dest = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xff);

    ;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((*compare ^ dest) & (res ^ dest));
    m68ki_cpu.c_flag = (res);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1,
                       ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_pi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_pd() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_16_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = m68ki_read_imm_32();
    U32 dest = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - ((*compare) & 0xffff);

    ;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);

    if (m68ki_cpu.not_z_flag)
      *compare = ((*compare) & ~0xffff) | dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[(word2 >> 6) & 7]) & 0xffff));
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_pi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_pd() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 ea = m68ki_read_imm_32();
    U32 dest = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 *compare = &m68ki_cpu.dar[word2 & 7];
    U32 res = dest - *compare;

    ;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((*compare ^ dest) & (res ^ dest)) >> 24);
    m68ki_cpu.c_flag = (((*compare & res) | (~dest & (*compare | res))) >> 23);

    if (m68ki_cpu.not_z_flag)
      *compare = dest;
    else {
      m68ki_remaining_cycles -= (3);
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1,
                        m68ki_cpu.dar[(word2 >> 6) & 7]);
    }
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas2_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_32();
    U32 *compare1 = &m68ki_cpu.dar[(word2 >> 16) & 7];
    U32 ea1 = m68ki_cpu.dar[(word2 >> 28) & 15];
    U32 dest1 = m68ki_read_16_fc(ea1, m68ki_cpu.s_flag | 1);
    U32 res1 = dest1 - ((*compare1) & 0xffff);
    U32 *compare2 = &m68ki_cpu.dar[word2 & 7];
    U32 ea2 = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 dest2 = m68ki_read_16_fc(ea2, m68ki_cpu.s_flag | 1);
    U32 res2;

    ;
    m68ki_cpu.n_flag = ((res1) >> 8);
    m68ki_cpu.not_z_flag = ((res1)&0xffff);
    m68ki_cpu.v_flag = (((*compare1 ^ dest1) & (res1 ^ dest1)) >> 8);
    m68ki_cpu.c_flag = ((res1) >> 8);

    if ((!m68ki_cpu.not_z_flag)) {
      res2 = dest2 - ((*compare2) & 0xffff);

      m68ki_cpu.n_flag = ((res2) >> 8);
      m68ki_cpu.not_z_flag = ((res2)&0xffff);
      m68ki_cpu.v_flag = (((*compare2 ^ dest2) & (res2 ^ dest2)) >> 8);
      m68ki_cpu.c_flag = ((res2) >> 8);

      if ((!m68ki_cpu.not_z_flag)) {
        m68ki_remaining_cycles -= (3);
        m68ki_write_16_fc(ea1, m68ki_cpu.s_flag | 1,
                          m68ki_cpu.dar[(word2 >> 22) & 7]);
        m68ki_write_16_fc(ea2, m68ki_cpu.s_flag | 1,
                          m68ki_cpu.dar[(word2 >> 6) & 7]);
        return;
      }
    }
    *compare1 = T(((word2)&0x80000000), MAKE_INT_16(dest1),
                  ((*compare1) & ~0xffff) | dest1);
    *compare2 = T(((word2)&0x00008000), MAKE_INT_16(dest2),
                  ((*compare2) & ~0xffff) | dest2);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cas2_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_32();
    U32 *compare1 = &m68ki_cpu.dar[(word2 >> 16) & 7];
    U32 ea1 = m68ki_cpu.dar[(word2 >> 28) & 15];
    U32 dest1 = m68ki_read_32_fc(ea1, m68ki_cpu.s_flag | 1);
    U32 res1 = dest1 - *compare1;
    U32 *compare2 = &m68ki_cpu.dar[word2 & 7];
    U32 ea2 = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 dest2 = m68ki_read_32_fc(ea2, m68ki_cpu.s_flag | 1);
    U32 res2;

    ;
    m68ki_cpu.n_flag = ((res1) >> 24);
    m68ki_cpu.not_z_flag = (res1);
    m68ki_cpu.v_flag = (((*compare1 ^ dest1) & (res1 ^ dest1)) >> 24);
    m68ki_cpu.c_flag =
        (((*compare1 & res1) | (~dest1 & (*compare1 | res1))) >> 23);

    if ((!m68ki_cpu.not_z_flag)) {
      res2 = dest2 - *compare2;

      m68ki_cpu.n_flag = ((res2) >> 24);
      m68ki_cpu.not_z_flag = (res2);
      m68ki_cpu.v_flag = (((*compare2 ^ dest2) & (res2 ^ dest2)) >> 24);
      m68ki_cpu.c_flag =
          (((*compare2 & res2) | (~dest2 & (*compare2 | res2))) >> 23);

      if ((!m68ki_cpu.not_z_flag)) {
        m68ki_remaining_cycles -= (3);
        m68ki_write_32_fc(ea1, m68ki_cpu.s_flag | 1,
                          m68ki_cpu.dar[(word2 >> 22) & 7]);
        m68ki_write_32_fc(ea2, m68ki_cpu.s_flag | 1,
                          m68ki_cpu.dar[(word2 >> 6) & 7]);
        return;
      }
    }
    *compare1 = dest1;
    *compare2 = dest2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_16_d() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7]));

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_ai() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AY_AI_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_pi() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AY_PI_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_pd() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AY_PD_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_di() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AY_DI_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_ix() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AY_IX_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_aw() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AW_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_al() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_AL_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_pcdi() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_PCDI_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_pcix() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(OPER_PCIX_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_16_i() {
  I32 src = MAKE_INT_16((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
  I32 bound = MAKE_INT_16(m68ki_read_imm_16());

  if (src >= 0 && src <= bound) {
    return;
  }
  m68ki_cpu.n_flag = (src < 0) << 7;
  m68ki_exception_trap(6);
}

U0 m68k_op_chk_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32((m68ki_cpu.dar[m68ki_cpu.ir & 7]));

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AY_AI_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_pi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AY_PI_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_pd() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AY_PD_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AY_DI_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AY_IX_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AW_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_AL_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_PCDI_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(OPER_PCIX_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk_32_i() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = MAKE_INT_32((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]));
    I32 bound = MAKE_INT_32(m68ki_read_imm_32());

    if (src >= 0 && src <= bound) {
      return;
    }
    m68ki_cpu.n_flag = (src < 0) << 7;
    m68ki_exception_trap(6);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_read_imm_32();
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_pcdi();
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_8_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_pcix();
    U32 lower_bound = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_8_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_8(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xff);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_read_imm_32();
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_pcdi();
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_16_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_pcix();
    U32 lower_bound = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_16_fc(ea + 1, m68ki_cpu.s_flag | 1);

    if (!((word2)&0x00008000))
      compare = MAKE_INT_16(compare);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = ((m68ki_cpu.c_flag) & 0xffff);
    m68ki_cpu.c_flag = ((m68ki_cpu.c_flag) >> 8);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16()));
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_read_imm_32();
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_pcdi();
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_chk2cmp2_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 compare = m68ki_cpu.dar[(word2 >> 12) & 15];
    U32 ea = m68ki_get_ea_pcix();
    U32 lower_bound = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
    U32 upper_bound = m68ki_read_32_fc(ea + 1, m68ki_cpu.s_flag | 1);

    m68ki_cpu.c_flag = compare - lower_bound;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((lower_bound & m68ki_cpu.c_flag) |
                         (~compare & (lower_bound | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100)) {
      if (((word2)&0x00000800))
        m68ki_exception_trap(6);
      return;
    }

    m68ki_cpu.c_flag = upper_bound - compare;
    m68ki_cpu.not_z_flag = (m68ki_cpu.c_flag);
    m68ki_cpu.c_flag = (((compare & m68ki_cpu.c_flag) |
                         (~upper_bound & (compare | m68ki_cpu.c_flag))) >>
                        23);
    if ((m68ki_cpu.c_flag & 0x100) && ((word2)&0x00000800))
      m68ki_exception_trap(6);

    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_clr_8_d() {
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_d() {
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffff0000;

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_ai() {
  m68ki_write_16_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_pi() {
  m68ki_write_16_fc(((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_pd() {
  m68ki_write_16_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_di() {
  m68ki_write_16_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                     MAKE_INT_16(m68ki_read_imm_16())),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_ix() {
  m68ki_write_16_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_aw() {
  m68ki_write_16_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_16_al() {
  m68ki_write_16_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_d() {
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) = 0;

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_ai() {
  m68ki_write_32_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_pi() {
  m68ki_write_32_fc(((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_pd() {
  m68ki_write_32_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_di() {
  m68ki_write_32_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                     MAKE_INT_16(m68ki_read_imm_16())),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_ix() {
  m68ki_write_32_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                    m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_aw() {
  m68ki_write_32_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_clr_32_al() {
  m68ki_write_32_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1, 0);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.not_z_flag = 0;
}

U0 m68k_op_cmp_8_d() {
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_ai() {
  U32 src = OPER_AY_AI_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_pi() {
  U32 src = OPER_AY_PI_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_pi7() {
  U32 src = OPER_A7_PI_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_pd() {
  U32 src = OPER_AY_PD_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_pd7() {
  U32 src = OPER_A7_PD_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_di() {
  U32 src = OPER_AY_DI_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_ix() {
  U32 src = OPER_AY_IX_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_aw() {
  U32 src = OPER_AW_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_al() {
  U32 src = OPER_AL_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_pcdi() {
  U32 src = OPER_PCDI_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_pcix() {
  U32 src = OPER_PCIX_8();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_8_i() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmp_16_d() {
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_a() {
  U32 src = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_ai() {
  U32 src = OPER_AY_AI_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_pi() {
  U32 src = OPER_AY_PI_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_pd() {
  U32 src = OPER_AY_PD_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_di() {
  U32 src = OPER_AY_DI_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_ix() {
  U32 src = OPER_AY_IX_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_aw() {
  U32 src = OPER_AW_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_al() {
  U32 src = OPER_AL_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_pcdi() {
  U32 src = OPER_PCDI_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_pcix() {
  U32 src = OPER_PCIX_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_16_i() {
  U32 src = m68ki_read_imm_16();
  U32 dst = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmp_32_d() {
  U32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_a() {
  U32 src = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_ai() {
  U32 src = OPER_AY_AI_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_pi() {
  U32 src = OPER_AY_PI_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_pd() {
  U32 src = OPER_AY_PD_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_di() {
  U32 src = OPER_AY_DI_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_ix() {
  U32 src = OPER_AY_IX_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_aw() {
  U32 src = OPER_AW_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_al() {
  U32 src = OPER_AL_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_pcdi() {
  U32 src = OPER_PCDI_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_pcix() {
  U32 src = OPER_PCIX_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmp_32_i() {
  U32 src = m68ki_read_imm_32();
  U32 dst = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_d() {
  U32 src = MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7]));
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_a() {
  U32 src = MAKE_INT_16(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_ai() {
  U32 src = MAKE_INT_16(OPER_AY_AI_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_pi() {
  U32 src = MAKE_INT_16(OPER_AY_PI_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_pd() {
  U32 src = MAKE_INT_16(OPER_AY_PD_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_di() {
  U32 src = MAKE_INT_16(OPER_AY_DI_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_ix() {
  U32 src = MAKE_INT_16(OPER_AY_IX_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_aw() {
  U32 src = MAKE_INT_16(OPER_AW_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_al() {
  U32 src = MAKE_INT_16(OPER_AL_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_pcdi() {
  U32 src = MAKE_INT_16(OPER_PCDI_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_pcix() {
  U32 src = MAKE_INT_16(OPER_PCIX_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_16_i() {
  U32 src = MAKE_INT_16(m68ki_read_imm_16());
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_d() {
  U32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_a() {
  U32 src = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_ai() {
  U32 src = OPER_AY_AI_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_pi() {
  U32 src = OPER_AY_PI_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_pd() {
  U32 src = OPER_AY_PD_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_di() {
  U32 src = OPER_AY_DI_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_ix() {
  U32 src = OPER_AY_IX_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_aw() {
  U32 src = OPER_AW_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_al() {
  U32 src = OPER_AL_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_pcdi() {
  U32 src = OPER_PCDI_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_pcix() {
  U32 src = OPER_PCIX_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpa_32_i() {
  U32 src = m68ki_read_imm_32();
  U32 dst = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_8_d() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_ai() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AY_AI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_pi() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AY_PI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_pi7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_A7_PI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_pd() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AY_PD_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_pd7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_A7_PD_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_di() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AY_DI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_ix() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AY_IX_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_aw() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AW_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_al() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 dst = OPER_AL_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpi_8_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 src = ((m68ki_read_imm_16()) & 0xff);
    U32 dst = OPER_PCDI_8();
    U32 res = dst - src;

    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
    m68ki_cpu.c_flag = (res);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cmpi_8_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 src = ((m68ki_read_imm_16()) & 0xff);
    U32 dst = OPER_PCIX_8();
    U32 res = dst - src;

    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = ((res)&0xff);
    m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
    m68ki_cpu.c_flag = (res);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cmpi_16_d() {
  U32 src = m68ki_read_imm_16();
  U32 dst = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_ai() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AY_AI_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_pi() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AY_PI_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_pd() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AY_PD_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_di() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AY_DI_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_ix() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AY_IX_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_aw() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AW_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_al() {
  U32 src = m68ki_read_imm_16();
  U32 dst = OPER_AL_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpi_16_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 src = m68ki_read_imm_16();
    U32 dst = OPER_PCDI_16();
    U32 res = dst - src;

    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cmpi_16_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 src = m68ki_read_imm_16();
    U32 dst = OPER_PCIX_16();
    U32 res = dst - src;

    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = ((res)&0xffff);
    m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
    m68ki_cpu.c_flag = ((res) >> 8);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cmpi_32_d() {
  U32 src = m68ki_read_imm_32();
  U32 dst = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_ai() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AY_AI_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_pi() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AY_PI_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_pd() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AY_PD_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_di() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AY_DI_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_ix() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AY_IX_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_aw() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AW_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_al() {
  U32 src = m68ki_read_imm_32();
  U32 dst = OPER_AL_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cmpi_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 src = m68ki_read_imm_32();
    U32 dst = OPER_PCDI_32();
    U32 res = dst - src;

    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
    m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cmpi_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 src = m68ki_read_imm_32();
    U32 dst = OPER_PCIX_32();
    U32 res = dst - src;

    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = (res);
    m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
    m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_cmpm_8_ax7() {
  U32 src = OPER_AY_PI_8();
  U32 dst = OPER_A7_PI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpm_8_ay7() {
  U32 src = OPER_A7_PI_8();
  U32 dst = OPER_AX_PI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpm_8_axy7() {
  U32 src = OPER_A7_PI_8();
  U32 dst = OPER_A7_PI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpm_8() {
  U32 src = OPER_AY_PI_8();
  U32 dst = OPER_AX_PI_8();
  U32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.c_flag = (res);
}

U0 m68k_op_cmpm_16() {
  U32 src = OPER_AY_PI_16();
  U32 dst = OPER_AX_PI_16();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.c_flag = ((res) >> 8);
}

U0 m68k_op_cmpm_32() {
  U32 src = OPER_AY_PI_32();
  U32 dst = OPER_AX_PI_32();
  U32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.c_flag = (((src & res) | (~dst & (src | res))) >> 23);
}

U0 m68k_op_cpbcc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    ;
    return;
  }
  m68ki_exception_1111();
}

U0 m68k_op_cpdbcc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    ;
    return;
  }
  m68ki_exception_1111();
}

U0 m68k_op_cpgen_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    ;
    return;
  }
  m68ki_exception_1111();
}

U0 m68k_op_cpscc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    ;
    return;
  }
  m68ki_exception_1111();
}

U0 m68k_op_cptrapcc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    ;
    return;
  }
  m68ki_exception_1111();
}

U0 m68k_op_dbt_16() { m68ki_cpu.pc += 2; }

U0 m68k_op_dbf_16() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 res = ((*r_dst - 1) & 0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;
  if (res != 0xffff) {
    U32 offset = m68ki_read_imm_16();
    m68ki_cpu.pc -= 2;
    ;
    m68ki_branch_16(offset);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbhi_16() {
  if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbls_16() {
  if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbcc_16() {
  if ((m68ki_cpu.c_flag & 0x100)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbcs_16() {
  if ((!(m68ki_cpu.c_flag & 0x100))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbne_16() {
  if ((!m68ki_cpu.not_z_flag)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbeq_16() {
  if (m68ki_cpu.not_z_flag) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbvc_16() {
  if ((m68ki_cpu.v_flag & 0x80)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbvs_16() {
  if ((!(m68ki_cpu.v_flag & 0x80))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbpl_16() {
  if ((m68ki_cpu.n_flag & 0x80)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbmi_16() {
  if ((!(m68ki_cpu.n_flag & 0x80))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbge_16() {
  if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dblt_16() {
  if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dbgt_16() {
  if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
       (!m68ki_cpu.not_z_flag))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_dble_16() {
  if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
       m68ki_cpu.not_z_flag)) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 res = ((*r_dst - 1) & 0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    if (res != 0xffff) {
      U32 offset = m68ki_read_imm_16();
      m68ki_cpu.pc -= 2;
      ;
      m68ki_branch_16(offset);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_noexp);
      return;
    }
    m68ki_cpu.pc += 2;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_dbcc_f_exp);
    return;
  }
  m68ki_cpu.pc += 2;
}

U0 m68k_op_divs_16_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7]));
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AY_AI_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AY_PI_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AY_PD_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AY_DI_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AY_IX_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AW_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_AL_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_PCDI_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = MAKE_INT_16(OPER_PCIX_16());
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divs_16_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (MAKE_INT_16(m68ki_read_imm_16()));
  I32 quotient;
  I32 remainder;

  if (src != 0) {
    if (*r_dst(U32) == 0x80000000 && src == -1) {
      m68ki_cpu.not_z_flag = 0;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = 0;
      return;
    }

    quotient = MAKE_INT_32(*r_dst) / src;
    remainder = MAKE_INT_32(*r_dst) % src;

    if (quotient == MAKE_INT_16(quotient)) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_AI_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PI_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_PD_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_DI_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AY_IX_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AW_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_AL_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCDI_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = OPER_PCIX_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divu_16_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 src = m68ki_read_imm_16();

  if (src != 0) {
    U32 quotient = *r_dst / src;
    U32 remainder = *r_dst % src;

    if (quotient < 0x10000) {
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.n_flag = ((quotient) >> 8);
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      *r_dst = (((quotient)&0xffff) | (remainder << 16));
      return;
    }
    m68ki_cpu.v_flag = 0x80;
    return;
  }
  m68ki_exception_trap(5);
}

U0 m68k_op_divl_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AY_AI_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_pi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AY_PI_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_pd() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AY_PD_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AY_DI_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AY_IX_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AW_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_AL_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_PCDI_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = OPER_PCIX_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_divl_32_i() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 divisor = m68ki_read_imm_32();
    U32 dividend_hi = m68ki_cpu.dar[word2 & 7];
    U32 dividend_lo = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 quotient = 0;
    U32 remainder = 0;
    U32 dividend_neg = 0;
    U32 divisor_neg = 0;
    I32 i;
    U32 overflow;

    if (divisor != 0) {

      if (((word2)&0x00000400)) {
        if (((word2)&0x00000800)) {

          if (dividend_hi == 0 && dividend_lo == 0x80000000 &&
              divisor == 0xffffffff) {
            m68ki_cpu.dar[word2 & 7] = 0;
            m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;

            m68ki_cpu.n_flag = 0x80;
            m68ki_cpu.not_z_flag = 0xffffffff;
            m68ki_cpu.v_flag = 0;
            m68ki_cpu.c_flag = 0;
            return;
          }
          if (((dividend_hi)&0x80000000)) {
            dividend_neg = 1;
            dividend_hi = ((-dividend_hi(I32)) - (dividend_lo != 0))(U32);
            dividend_lo = (-dividend_lo(I32))(U32);
          }
          if (((divisor)&0x80000000)) {
            divisor_neg = 1;
            divisor = (-divisor(I32))(U32);
          }
        }

        if (dividend_hi >= divisor) {
          m68ki_cpu.v_flag = 0x80;
          return;
        }

        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          remainder = (remainder << 1) + ((dividend_hi >> i) & 1);
          if (remainder >= divisor) {
            remainder -= divisor;
            quotient++;
          }
        }
        for (i = 31; i >= 0; i--) {
          quotient <<= 1;
          overflow = ((remainder)&0x80000000);
          remainder = (remainder << 1) + ((dividend_lo >> i) & 1);
          if (remainder >= divisor || overflow) {
            remainder -= divisor;
            quotient++;
          }
        }

        if (((word2)&0x00000800)) {
          if (quotient > 0x7fffffff) {
            m68ki_cpu.v_flag = 0x80;
            return;
          }
          if (dividend_neg) {
            remainder = (-remainder(I32))(U32);
            quotient = (-quotient(I32))(U32);
          }
          if (divisor_neg)
            quotient = (-quotient(I32))(U32);
        }

        m68ki_cpu.dar[word2 & 7] = remainder;
        m68ki_cpu.dar[(word2 >> 12) & 7] = quotient;

        m68ki_cpu.n_flag = ((quotient) >> 24);
        m68ki_cpu.not_z_flag = quotient;
        m68ki_cpu.v_flag = 0;
        m68ki_cpu.c_flag = 0;
        return;
      }

      if (((word2)&0x00000800)) {

        if (dividend_lo == 0x80000000 && divisor == 0xffffffff) {
          m68ki_cpu.n_flag = 0x80;
          m68ki_cpu.not_z_flag = 0xffffffff;
          m68ki_cpu.v_flag = 0;
          m68ki_cpu.c_flag = 0;
          m68ki_cpu.dar[(word2 >> 12) & 7] = 0x80000000;
          m68ki_cpu.dar[word2 & 7] = 0;
          return;
        }
        m68ki_cpu.dar[word2 & 7] =
            MAKE_INT_32(dividend_lo) % MAKE_INT_32(divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] =
            MAKE_INT_32(dividend_lo) / MAKE_INT_32(divisor);
      } else {
        m68ki_cpu.dar[word2 & 7] = (dividend_lo) % (divisor);
        quotient = m68ki_cpu.dar[(word2 >> 12) & 7] = (dividend_lo) / (divisor);
      }

      m68ki_cpu.n_flag = ((quotient) >> 24);
      m68ki_cpu.not_z_flag = quotient;
      m68ki_cpu.v_flag = 0;
      m68ki_cpu.c_flag = 0;
      return;
    }
    m68ki_exception_trap(5);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_eor_8_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) ^=
              (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff)) &
             0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_pi() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_pi7() {
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_pd() {
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_pd7() {
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_8_al() {
  U32 ea = m68ki_read_imm_32();
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) ^=
              (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff)) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_16_al() {
  U32 ea = m68ki_read_imm_32();
  U32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]) ^=
      (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eor_32_al() {
  U32 ea = m68ki_read_imm_32();
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) ^
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_d() {
  U32 res =
      (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) ^= ((m68ki_read_imm_16()) & 0xff)) &
       0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_ai() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_pi() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_pi7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_pd() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_pd7() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_di() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_ix() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_aw() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_8_al() {
  U32 src = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_read_imm_32();
  U32 res = src ^ m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_d() {
  U32 res =
      (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) ^= m68ki_read_imm_16()) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_ai() {
  U32 src = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_pi() {
  U32 src = m68ki_read_imm_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_pd() {
  U32 src = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_di() {
  U32 src = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_ix() {
  U32 src = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_aw() {
  U32 src = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_al() {
  U32 src = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 res = src ^ m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]) ^= m68ki_read_imm_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_ai() {
  U32 src = m68ki_read_imm_32();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_pi() {
  U32 src = m68ki_read_imm_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_pd() {
  U32 src = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_di() {
  U32 src = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_ix() {
  U32 src = m68ki_read_imm_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_aw() {
  U32 src = m68ki_read_imm_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_32_al() {
  U32 src = m68ki_read_imm_32();
  U32 ea = m68ki_read_imm_32();
  U32 res = src ^ m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_eori_16_toc() {
  m68ki_set_ccr(
      (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
       ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
       ((m68ki_cpu.c_flag & 0x100) >> 8)) ^
      m68ki_read_imm_16());
}

U0 m68k_op_eori_16_tos() {
  if (m68ki_cpu.s_flag) {
    U32 src = m68ki_read_imm_16();
    ;
    m68ki_set_sr(
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))) ^
        src);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_exg_32_dd() {
  U32 *reg_a = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 *reg_b = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 tmp = *reg_a;
  *reg_a = *reg_b;
  *reg_b = tmp;
}

U0 m68k_op_exg_32_aa() {
  U32 *reg_a = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);
  U32 *reg_b = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 tmp = *reg_a;
  *reg_a = *reg_b;
  *reg_b = tmp;
}

U0 m68k_op_exg_32_da() {
  U32 *reg_a = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 *reg_b = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 tmp = *reg_a;
  *reg_a = *reg_b;
  *reg_b = tmp;
}

U0 m68k_op_ext_16() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | ((*r_dst) & 0xff) |
           T(((*r_dst) & 0x80), 0xff00, 0);

  m68ki_cpu.n_flag = ((*r_dst) >> 8);
  m68ki_cpu.not_z_flag = ((*r_dst) & 0xffff);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_ext_32() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  *r_dst = ((*r_dst) & 0xffff) | T(((*r_dst) & 0x8000), 0xffff0000, 0);

  m68ki_cpu.n_flag = ((*r_dst) >> 24);
  m68ki_cpu.not_z_flag = *r_dst;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_extb_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);

    *r_dst = ((*r_dst) & 0xff) | T(((*r_dst) & 0x80), 0xffffff00, 0);

    m68ki_cpu.n_flag = ((*r_dst) >> 24);
    m68ki_cpu.not_z_flag = *r_dst;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_illegal() { m68ki_exception_illegal(); }
U0 m68k_op_illegal2() {
  "Illegal instruction: %08X\n", m68ki_cpu.ir;
  while (1)
    Sleep(1);
}

U0 m68k_op_jmp_32_ai() {
  m68ki_jump(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jmp_32_di() {
  m68ki_jump((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              MAKE_INT_16(m68ki_read_imm_16())));
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jmp_32_ix() {
  m68ki_jump(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])));
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jmp_32_aw() {
  m68ki_jump((MAKE_INT_16(m68ki_read_imm_16())));
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jmp_32_al() {
  m68ki_jump(m68ki_read_imm_32());
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jmp_32_pcdi() {
  m68ki_jump(m68ki_get_ea_pcdi());
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jmp_32_pcix() {
  m68ki_jump(m68ki_get_ea_pcix());
  ;
  if (m68ki_cpu.pc == m68ki_cpu.ppc)
    m68ki_remaining_cycles = 0;
}

U0 m68k_op_jsr_32_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_jsr_32_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_jsr_32_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_jsr_32_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_jsr_32_al() {
  U32 ea = m68ki_read_imm_32();
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_jsr_32_pcdi() {
  U32 ea = m68ki_get_ea_pcdi();
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_jsr_32_pcix() {
  U32 ea = m68ki_get_ea_pcix();
  ;
  m68ki_push_32(m68ki_cpu.pc);
  m68ki_jump(ea);
}

U0 m68k_op_lea_32_ai() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
}

U0 m68k_op_lea_32_di() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
       (MAKE_INT_16(m68ki_read_imm_16())));
}

U0 m68k_op_lea_32_ix() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
}

U0 m68k_op_lea_32_aw() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      MAKE_INT_16(m68ki_read_imm_16());
}

U0 m68k_op_lea_32_al() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = m68ki_read_imm_32();
}

U0 m68k_op_lea_32_pcdi() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = m68ki_get_ea_pcdi();
}

U0 m68k_op_lea_32_pcix() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = m68ki_get_ea_pcix();
}

U0 m68k_op_link_16_a7() {
  (m68ki_cpu.dar + 8)[7] -= 4;
  m68ki_write_32_fc((m68ki_cpu.dar + 8)[7], m68ki_cpu.s_flag | 1,
                    (m68ki_cpu.dar + 8)[7]);
  (m68ki_cpu.dar + 8)[7] =
      ((m68ki_cpu.dar + 8)[7] + (MAKE_INT_16(m68ki_read_imm_16())));
}

U0 m68k_op_link_16() {
  U32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  m68ki_push_32(*r_dst);
  *r_dst = (m68ki_cpu.dar + 8)[7];
  (m68ki_cpu.dar + 8)[7] =
      ((m68ki_cpu.dar + 8)[7] + (MAKE_INT_16(m68ki_read_imm_16())));
}

U0 m68k_op_link_32_a7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    (m68ki_cpu.dar + 8)[7] -= 4;
    m68ki_write_32_fc((m68ki_cpu.dar + 8)[7], m68ki_cpu.s_flag | 1,
                      (m68ki_cpu.dar + 8)[7]);
    (m68ki_cpu.dar + 8)[7] = ((m68ki_cpu.dar + 8)[7] + m68ki_read_imm_32());
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_link_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    m68ki_push_32(*r_dst);
    *r_dst = (m68ki_cpu.dar + 8)[7];
    (m68ki_cpu.dar + 8)[7] = ((m68ki_cpu.dar + 8)[7] + m68ki_read_imm_32());
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_lsr_8_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xff);
  U32 res = src >> shift;

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = src >> shift;

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = src >> shift;

  *r_dst = res;

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_8_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xff);
  U32 res = src >> shift;

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift <= 8) {
      *r_dst = ((*r_dst) & ~0xff) | res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << (9 - shift);
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst &= 0xffffff00;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = (src);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = src >> shift;

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift <= 16) {
      *r_dst = ((*r_dst) & ~0xffff) | res;
      m68ki_cpu.c_flag = m68ki_cpu.x_flag = (src >> (shift - 1)) << 8;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst &= 0xffff0000;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 8);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = *r_dst;
  U32 res = src >> shift;

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 32) {
      *r_dst = res;
      m68ki_cpu.c_flag = m68ki_cpu.x_flag = (src >> (shift - 1)) << 8;
      m68ki_cpu.n_flag = 0;
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst = 0;
    m68ki_cpu.x_flag = m68ki_cpu.c_flag =
        T(shift == 32, ((src)&0x80000000) >> 23, 0);
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 24);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsr_16_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = src >> 1;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = 0;
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_8_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xff);
  U32 res = ((src << shift) & 0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << shift;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = ((src << shift) & 0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> (8 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = (src << shift);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> (24 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_8_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xff);
  U32 res = ((src << shift) & 0xff);

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift <= 8) {
      *r_dst = ((*r_dst) & ~0xff) | res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = src << shift;
      m68ki_cpu.n_flag = (res);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst &= 0xffffff00;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = (src);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = ((*r_dst) & 0xffff);
  U32 res = ((src << shift) & 0xffff);

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift <= 16) {
      *r_dst = ((*r_dst) & ~0xffff) | res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = (src << shift) >> 8;
      m68ki_cpu.n_flag = ((res) >> 8);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst &= 0xffff0000;
    m68ki_cpu.x_flag = 0;
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 8);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 src = *r_dst;
  U32 res = (src << shift);

  if (shift != 0) {
    m68ki_remaining_cycles -= (shift << m68ki_cpu.cyc_shift);

    if (shift < 32) {
      *r_dst = res;
      m68ki_cpu.x_flag = m68ki_cpu.c_flag = (src >> (32 - shift)) << 8;
      m68ki_cpu.n_flag = ((res) >> 24);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }

    *r_dst = 0;
    m68ki_cpu.x_flag = m68ki_cpu.c_flag = (T(shift == 32, src & 1, 0)) << 8;
    m68ki_cpu.n_flag = 0;
    m68ki_cpu.not_z_flag = 0;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 24);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_ai() {
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_pi() {
  U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_pd() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_di() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_ix() {
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_aw() {
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_lsl_16_al() {
  U32 ea = m68ki_read_imm_32();
  U32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  U32 res = ((src << 1) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_move_8_d_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_ai() {
  U32 res = OPER_AY_AI_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_pi() {
  U32 res = OPER_AY_PI_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_pd() {
  U32 res = OPER_AY_PD_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_di() {
  U32 res = OPER_AY_DI_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_ix() {
  U32 res = OPER_AY_IX_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_aw() {
  U32 res = OPER_AW_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_al() {
  U32 res = OPER_AL_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_pcix() {
  U32 res = OPER_PCIX_8();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_d_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_aw() {
  U32 res = OPER_AW_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_al() {
  U32 res = OPER_AL_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ai_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_aw() {
  U32 res = OPER_AW_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_al() {
  U32 res = OPER_AL_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi7_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_aw() {
  U32 res = OPER_AW_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_al() {
  U32 res = OPER_AL_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pi_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])++);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_aw() {
  U32 res = OPER_AW_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_al() {
  U32 res = OPER_AL_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd7_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_aw() {
  U32 res = OPER_AW_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_al() {
  U32 res = OPER_AL_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_pd_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_aw() {
  U32 res = OPER_AW_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_al() {
  U32 res = OPER_AL_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_di_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_aw() {
  U32 res = OPER_AW_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_al() {
  U32 res = OPER_AL_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_ix_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_aw() {
  U32 res = OPER_AW_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_al() {
  U32 res = OPER_AL_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_aw_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_ai() {
  U32 res = OPER_AY_AI_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_pi() {
  U32 res = OPER_AY_PI_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_pi7() {
  U32 res = OPER_A7_PI_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_pd() {
  U32 res = OPER_AY_PD_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_pd7() {
  U32 res = OPER_A7_PD_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_di() {
  U32 res = OPER_AY_DI_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_ix() {
  U32 res = OPER_AY_IX_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_aw() {
  U32 res = OPER_AW_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_al() {
  U32 res = OPER_AL_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_pcdi() {
  U32 res = OPER_PCDI_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_pcix() {
  U32 res = OPER_PCIX_8();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_8_al_i() {
  U32 res = ((m68ki_read_imm_16()) & 0xff);
  U32 ea = m68ki_read_imm_32();

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_ai() {
  U32 res = OPER_AY_AI_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_pi() {
  U32 res = OPER_AY_PI_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_pd() {
  U32 res = OPER_AY_PD_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_di() {
  U32 res = OPER_AY_DI_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_ix() {
  U32 res = OPER_AY_IX_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_aw() {
  U32 res = OPER_AW_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_al() {
  U32 res = OPER_AL_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_pcix() {
  U32 res = OPER_PCIX_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_d_i() {
  U32 res = m68ki_read_imm_16();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_aw() {
  U32 res = OPER_AW_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_al() {
  U32 res = OPER_AL_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ai_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_aw() {
  U32 res = OPER_AW_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_al() {
  U32 res = OPER_AL_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pi_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 2) - 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_aw() {
  U32 res = OPER_AW_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_al() {
  U32 res = OPER_AL_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_pd_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_aw() {
  U32 res = OPER_AW_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_al() {
  U32 res = OPER_AL_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_di_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_aw() {
  U32 res = OPER_AW_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_al() {
  U32 res = OPER_AL_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_ix_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_aw() {
  U32 res = OPER_AW_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_al() {
  U32 res = OPER_AL_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_aw_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_d() {
  U32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_a() {
  U32 res = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_ai() {
  U32 res = OPER_AY_AI_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_pi() {
  U32 res = OPER_AY_PI_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_pd() {
  U32 res = OPER_AY_PD_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_di() {
  U32 res = OPER_AY_DI_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_ix() {
  U32 res = OPER_AY_IX_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_aw() {
  U32 res = OPER_AW_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_al() {
  U32 res = OPER_AL_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_pcdi() {
  U32 res = OPER_PCDI_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_pcix() {
  U32 res = OPER_PCIX_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_16_al_i() {
  U32 res = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_ai() {
  U32 res = OPER_AY_AI_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_pi() {
  U32 res = OPER_AY_PI_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_pd() {
  U32 res = OPER_AY_PD_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_di() {
  U32 res = OPER_AY_DI_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_ix() {
  U32 res = OPER_AY_IX_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_aw() {
  U32 res = OPER_AW_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_al() {
  U32 res = OPER_AL_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_pcix() {
  U32 res = OPER_PCIX_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_d_i() {
  U32 res = m68ki_read_imm_32();
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_aw() {
  U32 res = OPER_AW_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_al() {
  U32 res = OPER_AL_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ai_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_aw() {
  U32 res = OPER_AW_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_al() {
  U32 res = OPER_AL_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pi_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = ((((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) += 4) - 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_aw() {
  U32 res = OPER_AW_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_al() {
  U32 res = OPER_AL_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_pd_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_aw() {
  U32 res = OPER_AW_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_al() {
  U32 res = OPER_AL_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_di_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_aw() {
  U32 res = OPER_AW_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_al() {
  U32 res = OPER_AL_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_ix_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_aw() {
  U32 res = OPER_AW_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_al() {
  U32 res = OPER_AL_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_aw_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_d() {
  U32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_a() {
  U32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_ai() {
  U32 res = OPER_AY_AI_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_pi() {
  U32 res = OPER_AY_PI_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_pd() {
  U32 res = OPER_AY_PD_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_di() {
  U32 res = OPER_AY_DI_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_ix() {
  U32 res = OPER_AY_IX_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_aw() {
  U32 res = OPER_AW_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_al() {
  U32 res = OPER_AL_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_pcdi() {
  U32 res = OPER_PCDI_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_pcix() {
  U32 res = OPER_PCIX_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_move_32_al_i() {
  U32 res = m68ki_read_imm_32();
  U32 ea = m68ki_read_imm_32();

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_movea_16_d() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7]));
}

U0 m68k_op_movea_16_a() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      MAKE_INT_16(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
}

U0 m68k_op_movea_16_ai() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AY_AI_16());
}

U0 m68k_op_movea_16_pi() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AY_PI_16());
}

U0 m68k_op_movea_16_pd() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AY_PD_16());
}

U0 m68k_op_movea_16_di() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AY_DI_16());
}

U0 m68k_op_movea_16_ix() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AY_IX_16());
}

U0 m68k_op_movea_16_aw() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AW_16());
}

U0 m68k_op_movea_16_al() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_AL_16());
}

U0 m68k_op_movea_16_pcdi() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_PCDI_16());
}

U0 m68k_op_movea_16_pcix() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = MAKE_INT_16(OPER_PCIX_16());
}

U0 m68k_op_movea_16_i() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      MAKE_INT_16(m68ki_read_imm_16());
}

U0 m68k_op_movea_32_d() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
}

U0 m68k_op_movea_32_a() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) =
      ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
}

U0 m68k_op_movea_32_ai() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AY_AI_32();
}

U0 m68k_op_movea_32_pi() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AY_PI_32();
}

U0 m68k_op_movea_32_pd() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AY_PD_32();
}

U0 m68k_op_movea_32_di() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AY_DI_32();
}

U0 m68k_op_movea_32_ix() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AY_IX_32();
}

U0 m68k_op_movea_32_aw() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AW_32();
}

U0 m68k_op_movea_32_al() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_AL_32();
}

U0 m68k_op_movea_32_pcdi() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_PCDI_32();
}

U0 m68k_op_movea_32_pcix() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = OPER_PCIX_32();
}

U0 m68k_op_movea_32_i() {
  ((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) = m68ki_read_imm_32();
}

U0 m68k_op_move_16_frc_d() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) =
        (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & ~0xffff) |
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_ai() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]), m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_pi() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2),
        m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_pd() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2), m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_di() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
         MAKE_INT_16(m68ki_read_imm_16())),
        m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_ix() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
        m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_aw() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_frc_al() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    m68ki_write_16_fc(
        m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
        (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
         ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
         ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_move_16_toc_d() { m68ki_set_ccr((m68ki_cpu.dar[m68ki_cpu.ir & 7])); }

U0 m68k_op_move_16_toc_ai() { m68ki_set_ccr(OPER_AY_AI_16()); }

U0 m68k_op_move_16_toc_pi() { m68ki_set_ccr(OPER_AY_PI_16()); }

U0 m68k_op_move_16_toc_pd() { m68ki_set_ccr(OPER_AY_PD_16()); }

U0 m68k_op_move_16_toc_di() { m68ki_set_ccr(OPER_AY_DI_16()); }

U0 m68k_op_move_16_toc_ix() { m68ki_set_ccr(OPER_AY_IX_16()); }

U0 m68k_op_move_16_toc_aw() { m68ki_set_ccr(OPER_AW_16()); }

U0 m68k_op_move_16_toc_al() { m68ki_set_ccr(OPER_AL_16()); }

U0 m68k_op_move_16_toc_pcdi() { m68ki_set_ccr(OPER_PCDI_16()); }

U0 m68k_op_move_16_toc_pcix() { m68ki_set_ccr(OPER_PCIX_16()); }

U0 m68k_op_move_16_toc_i() { m68ki_set_ccr(m68ki_read_imm_16()); }

U0 m68k_op_move_16_frs_d() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) =
        (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & ~0xffff) |
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8)));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_ai() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_pi() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_pd() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_di() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
              (MAKE_INT_16(m68ki_read_imm_16())));
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_ix() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_aw() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = MAKE_INT_16(m68ki_read_imm_16());
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_frs_al() {
  if (((m68ki_cpu.cpu_type) == 1) || m68ki_cpu.s_flag) {
    U32 ea = m68ki_read_imm_32();
    m68ki_write_16_fc(
        ea, m68ki_cpu.s_flag | 1,
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_d() {
  if (m68ki_cpu.s_flag) {
    m68ki_set_sr((m68ki_cpu.dar[m68ki_cpu.ir & 7]));
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_ai() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AY_AI_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_pi() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AY_PI_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_pd() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AY_PD_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_di() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AY_DI_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_ix() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AY_IX_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_aw() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AW_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_al() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_AL_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_pcdi() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_PCDI_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_pcix() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = OPER_PCIX_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_16_tos_i() {
  if (m68ki_cpu.s_flag) {
    U32 new_sr = m68ki_read_imm_16();
    ;
    m68ki_set_sr(new_sr);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_32_fru() {
  if (m68ki_cpu.s_flag) {
    ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) = m68ki_cpu.sp[0];
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_move_32_tou() {
  if (m68ki_cpu.s_flag) {
    ;
    m68ki_cpu.sp[0] = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_movec_32_cr() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();

      ;
      switch (word2 & 0xfff) {
      case 0x000:
        m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_cpu.sfc;
        return;
      case 0x001:
        m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_cpu.dfc;
        return;
      case 0x002:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_cpu.cacr;
          return;
        }
        return;
      case 0x800:
        m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_cpu.sp[0];
        return;
      case 0x801:
        m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_cpu.vbr;
        return;
      case 0x802:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_cpu.caar;
          return;
        }
        m68ki_exception_illegal();
        break;
      case 0x803:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          m68ki_cpu.dar[(word2 >> 12) & 15] =
              T(m68ki_cpu.m_flag, m68ki_cpu.dar[15], m68ki_cpu.sp[6]);
          return;
        }
        m68ki_exception_illegal();
        return;
      case 0x804:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          m68ki_cpu.dar[(word2 >> 12) & 15] =
              T(m68ki_cpu.m_flag, m68ki_cpu.sp[4], m68ki_cpu.dar[15]);
          return;
        }
        m68ki_exception_illegal();
        return;
      default:
        m68ki_exception_illegal();
        return;
      }
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_movec_32_rc() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();

      ;
      switch (word2 & 0xfff) {
      case 0x000:
        m68ki_cpu.sfc = m68ki_cpu.dar[(word2 >> 12) & 15] & 7;
        return;
      case 0x001:
        m68ki_cpu.dfc = m68ki_cpu.dar[(word2 >> 12) & 15] & 7;
        return;
      case 0x002:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          m68ki_cpu.cacr = m68ki_cpu.dar[(word2 >> 12) & 15];
          return;
        }
        m68ki_exception_illegal();
        return;
      case 0x800:
        m68ki_cpu.sp[0] = m68ki_cpu.dar[(word2 >> 12) & 15];
        return;
      case 0x801:
        m68ki_cpu.vbr = m68ki_cpu.dar[(word2 >> 12) & 15];
        return;
      case 0x802:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          m68ki_cpu.caar = m68ki_cpu.dar[(word2 >> 12) & 15];
          return;
        }
        m68ki_exception_illegal();
        return;
      case 0x803:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {

          if (!m68ki_cpu.m_flag) {
            m68ki_cpu.sp[6] = m68ki_cpu.dar[(word2 >> 12) & 15];
            return;
          }
          m68ki_cpu.dar[15] = m68ki_cpu.dar[(word2 >> 12) & 15];
          return;
        }
        m68ki_exception_illegal();
        return;
      case 0x804:
        if (((m68ki_cpu.cpu_type) & (4 | 8))) {
          if (!m68ki_cpu.m_flag) {
            m68ki_cpu.dar[15] = m68ki_cpu.dar[(word2 >> 12) & 15];
            return;
          }
          m68ki_cpu.sp[4] = m68ki_cpu.dar[(word2 >> 12) & 15];
          return;
        }
        m68ki_exception_illegal();
        return;
      default:
        m68ki_exception_illegal();
        return;
      }
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_movem_16_re_pd() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      ea -= 2;
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[15 - i]) & 0xffff));
      count++;
    }
  ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) = ea;

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_re_ai() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[i]) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_re_di() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[i]) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_re_ix() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[i]) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_re_aw() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[i]) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_re_al() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1,
                        ((m68ki_cpu.dar[i]) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_32_re_pd() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      ea -= 4;
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.dar[15 - i]);
      count++;
    }
  ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) = ea;

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_re_ai() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.dar[i]);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_re_di() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.dar[i]);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_re_ix() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.dar[i]);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_re_aw() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.dar[i]);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_re_al() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.dar[i]);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_16_er_pi() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }
  ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) = ea;

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_ai() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_di() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_ix() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_aw() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_al() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_pcdi() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_pcdi();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_16_er_pcix() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_pcix();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] =
          MAKE_INT_16(((m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff));
      ea += 2;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_w);
}

U0 m68k_op_movem_32_er_pi() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }
  ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) = ea;

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_ai() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_di() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_ix() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_aw() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = MAKE_INT_16(m68ki_read_imm_16());
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_al() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_read_imm_32();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_pcdi() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_pcdi();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movem_32_er_pcix() {
  U32 i = 0;
  U32 register_list = m68ki_read_imm_16();
  U32 ea = m68ki_get_ea_pcix();
  U32 count = 0;

  for (; i < 16; i++)
    if (register_list & (1 << i)) {
      m68ki_cpu.dar[i] = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
      ea += 4;
      count++;
    }

  m68ki_remaining_cycles -= (count << m68ki_cpu.cyc_movem_l);
}

U0 m68k_op_movep_16_re() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((src >> 8) & 0xff));
  m68ki_write_8_fc(ea += 2, m68ki_cpu.s_flag | 1, ((src)&0xff));
}

U0 m68k_op_movep_32_re() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((src >> 24) & 0xff));
  m68ki_write_8_fc(ea += 2, m68ki_cpu.s_flag | 1, ((src >> 16) & 0xff));
  m68ki_write_8_fc(ea += 2, m68ki_cpu.s_flag | 1, ((src >> 8) & 0xff));
  m68ki_write_8_fc(ea += 2, m68ki_cpu.s_flag | 1, ((src)&0xff));
}

U0 m68k_op_movep_16_er() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst =
      ((*r_dst) & ~0xffff) | ((m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1) << 8) +
                              m68ki_read_8_fc(ea + 2, m68ki_cpu.s_flag | 1));
}

U0 m68k_op_movep_32_er() {
  U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            (MAKE_INT_16(m68ki_read_imm_16())));

  (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) =
      (m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1) << 24) +
      (m68ki_read_8_fc(ea + 2, m68ki_cpu.s_flag | 1) << 16) +
      (m68ki_read_8_fc(ea + 4, m68ki_cpu.s_flag | 1) << 8) +
      m68ki_read_8_fc(ea + 6, m68ki_cpu.s_flag | 1);
}

U0 m68k_op_moves_8_ai() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_pi() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_pi7() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_pd() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_pd7() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_di() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                (MAKE_INT_16(m68ki_read_imm_16())));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_ix() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_aw() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = MAKE_INT_16(m68ki_read_imm_16());

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_8_al() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = m68ki_read_imm_32();

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_8_fc(ea, m68ki_cpu.dfc,
                         ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_8(m68ki_read_8_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xff) |
          m68ki_read_8_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_ai() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_pi() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_pd() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_di() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                (MAKE_INT_16(m68ki_read_imm_16())));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_ix() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_aw() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = MAKE_INT_16(m68ki_read_imm_16());

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_16_al() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = m68ki_read_imm_32();

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_16_fc(ea, m68ki_cpu.dfc,
                          ((m68ki_cpu.dar[(word2 >> 12) & 15]) & 0xffff));
        return;
      }
      if (((word2)&0x00008000)) {
        (m68ki_cpu.dar + 8)[(word2 >> 12) & 7] =
            MAKE_INT_16(m68ki_read_16_fc(ea, m68ki_cpu.sfc));
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 7] =
          ((m68ki_cpu.dar[(word2 >> 12) & 7]) & ~0xffff) |
          m68ki_read_16_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_ai() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_pi() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_pd() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_di() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                (MAKE_INT_16(m68ki_read_imm_16())));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_ix() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_aw() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = MAKE_INT_16(m68ki_read_imm_16());

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moves_32_al() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    if (m68ki_cpu.s_flag) {
      U32 word2 = m68ki_read_imm_16();
      U32 ea = m68ki_read_imm_32();

      ;
      if (((word2)&0x00000800)) {
        m68ki_write_32_fc(ea, m68ki_cpu.dfc, m68ki_cpu.dar[(word2 >> 12) & 15]);
        if (((m68ki_cpu.cpu_type) & (4 | 8)))
          m68ki_remaining_cycles -= (2);
        return;
      }

      m68ki_cpu.dar[(word2 >> 12) & 15] = m68ki_read_32_fc(ea, m68ki_cpu.sfc);
      if (((m68ki_cpu.cpu_type) & (4 | 8)))
        m68ki_remaining_cycles -= (2);
      return;
    }
    m68ki_exception_privilege_violation();
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_moveq_32() {
  U32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) =
      MAKE_INT_8(((m68ki_cpu.ir) & 0xff));

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7])) *
             MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AY_AI_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AY_PI_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AY_PD_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AY_DI_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AY_IX_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AW_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_AL_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_PCDI_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = (MAKE_INT_16(OPER_PCIX_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_muls_16_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res =
      (MAKE_INT_16(m68ki_read_imm_16()) * MAKE_INT_16(((*r_dst) & 0xffff)));

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_d() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res =
      (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff) * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_ai() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AY_AI_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_pi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AY_PI_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_pd() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AY_PD_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_di() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AY_DI_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_ix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AY_IX_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_aw() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AW_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_al() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_AL_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_pcdi() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_PCDI_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_pcix() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = OPER_PCIX_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mulu_16_i() {
  U32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  U32 res = m68ki_read_imm_16() * ((*r_dst) & 0xffff);

  *r_dst = res;

  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_mull_32_d() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_ai() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AY_AI_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_pi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AY_PI_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_pd() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AY_PD_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_di() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AY_DI_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_ix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AY_IX_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_aw() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AW_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_al() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_AL_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_PCDI_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = OPER_PCIX_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_mull_32_i() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    U32 word2 = m68ki_read_imm_16();
    U32 src = m68ki_read_imm_32();
    U32 dst = m68ki_cpu.dar[(word2 >> 12) & 7];
    U32 neg = ((src ^ dst) & 0x80000000);
    U32 src1;
    U32 src2;
    U32 dst1;
    U32 dst2;
    U32 r1;
    U32 r2;
    U32 r3;
    U32 r4;
    U32 lo;
    U32 hi;

    m68ki_cpu.c_flag = 0;

    if (((word2)&0x00000800)) {
      if (((src)&0x80000000))
        src = (-src(I32))(U32);
      if (((dst)&0x80000000))
        dst = (-dst(I32))(U32);
    }

    src1 = ((src)&0xffff);
    src2 = src >> 16;
    dst1 = ((dst)&0xffff);
    dst2 = dst >> 16;

    r1 = src1 * dst1;
    r2 = src1 * dst2;
    r3 = src2 * dst1;
    r4 = src2 * dst2;

    lo = r1 + (((r2)&0xffff) << 16) + (((r3)&0xffff) << 16);
    hi = r4 + (r2 >> 16) + (r3 >> 16) +
         (((r1 >> 16) + ((r2)&0xffff) + ((r3)&0xffff)) >> 16);

    if (((word2)&0x00000800) && neg) {
      hi = ((-hi(I32)) - (lo != 0))(U32);
      lo = (-lo(I32))(U32);
    }

    if (((word2)&0x00000400)) {
      m68ki_cpu.dar[word2 & 7] = hi;
      m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
      m68ki_cpu.n_flag = ((hi) >> 24);
      m68ki_cpu.not_z_flag = hi | lo;
      m68ki_cpu.v_flag = 0;
      return;
    }

    m68ki_cpu.dar[(word2 >> 12) & 7] = lo;
    m68ki_cpu.n_flag = ((lo) >> 24);
    m68ki_cpu.not_z_flag = lo;
    if (((word2)&0x00000800))
      m68ki_cpu.v_flag = (!((((lo)&0x80000000) && hi == 0xffffffff) ||
                            (!((lo)&0x80000000) && !hi)))
                         << 7;
    else
      m68ki_cpu.v_flag = (hi != 0) << 7;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_nbcd_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 dst = *r_dst;
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    *r_dst = ((*r_dst) & ~0xff) | res;

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_nbcd_8_al() {
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((0x9a - dst - ((m68ki_cpu.x_flag >> 8) & 1)) & 0xff);

  if (res != 0x9a) {
    if ((res & 0x0f) == 0xa)
      res = (res & 0xf0) + 0x10;

    res = ((res)&0xff);

    m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, ((res)&0xff));

    m68ki_cpu.not_z_flag |= res;
    m68ki_cpu.c_flag = 0x100;
    m68ki_cpu.x_flag = 0x100;
  } else {
    m68ki_cpu.c_flag = 0;
    m68ki_cpu.x_flag = 0;
  }
  m68ki_cpu.n_flag = (res);
}

U0 m68k_op_neg_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = 0 - ((*r_dst) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = *r_dst & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_neg_8_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_8_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (res);
  m68ki_cpu.v_flag = src & res;
  m68ki_cpu.not_z_flag = ((res)&0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = 0 - ((*r_dst) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (*r_dst & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_neg_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = 0 - *r_dst;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((*r_dst & res) | (~0 & (*r_dst | res))) >> 23);
  m68ki_cpu.v_flag = (*r_dst & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_neg_32_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_neg_32_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.c_flag = m68ki_cpu.x_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;
  m68ki_cpu.not_z_flag = (res);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_negx_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = 0 - ((*r_dst) & 0xff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = *r_dst & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xff) | res;
}

U0 m68k_op_negx_8_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_8_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = src & res;

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = 0 - ((*r_dst) & 0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (*r_dst & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xffff) | res;
}

U0 m68k_op_negx_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - ((src)&0xffff) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (src & res) >> 8;

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = 0 - (*r_dst) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((*r_dst & res) | (~0 & (*r_dst | res))) >> 23);
  m68ki_cpu.v_flag = (*r_dst & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = res;
}

U0 m68k_op_negx_32_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_negx_32_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = 0 - (src) - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~0 & (src | res))) >> 23);
  m68ki_cpu.v_flag = (src & res) >> 24;

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_nop() { ; }

U0 m68k_op_not_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = ((~*r_dst) & 0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_8_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = ((~m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = ((~*r_dst) & 0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = ((~m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 res = *r_dst = (~*r_dst);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_not_32_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = (~m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1));

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_d() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |=
               (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff))) &
             0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_ai() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_AI_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_pi() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_PI_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_pi7() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_A7_PI_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_pd() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_PD_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_pd7() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_A7_PD_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_di() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_DI_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_ix() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_IX_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_aw() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AW_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_al() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AL_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_pcdi() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_PCDI_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_pcix() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_PCIX_8())) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_er_i() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |=
               ((m68ki_read_imm_16()) & 0xff))) &
             0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_d() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |=
               (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff))) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_ai() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_AI_16())) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_pi() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_PI_16())) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_pd() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_PD_16())) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_di() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_DI_16())) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_ix() {
  I32 res = ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_IX_16())) &
             0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_aw() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AW_16())) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_al() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AL_16())) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_pcdi() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_PCDI_16())) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_pcix() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_PCIX_16())) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_er_i() {
  I32 res =
      ((((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= m68ki_read_imm_16())) &
       0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_d() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |=
      (m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_ai() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_AI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_pi() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_PI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_pd() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_PD_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_di() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_DI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_ix() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AY_IX_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_aw() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AW_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_al() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_AL_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_pcdi() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_PCDI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_pcix() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= OPER_PCIX_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_er_i() {
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |= m68ki_read_imm_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_8_re_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_16_re_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
              m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) &
             0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_or_32_re_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) |
            m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_d() {
  I32 res =
      ((((m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= ((m68ki_read_imm_16()) & 0xff))) &
       0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_ai() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_pi() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_pi7() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_pd() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_pd7() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_di() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_ix() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_aw() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_8_al() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = m68ki_read_imm_32();
  I32 res = ((src | m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1)) & 0xff);

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_d() {
  I32 res =
      (((m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= m68ki_read_imm_16()) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_ai() {
  I32 src = m68ki_read_imm_16();
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_pi() {
  I32 src = m68ki_read_imm_16();
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_pd() {
  I32 src = m68ki_read_imm_16();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_di() {
  I32 src = m68ki_read_imm_16();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_ix() {
  I32 src = m68ki_read_imm_16();
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_aw() {
  I32 src = m68ki_read_imm_16();
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_al() {
  I32 src = m68ki_read_imm_16();
  I32 ea = m68ki_read_imm_32();
  I32 res = ((src | m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_d() {
  I32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= m68ki_read_imm_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_ai() {
  I32 src = m68ki_read_imm_32();
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_pi() {
  I32 src = m68ki_read_imm_32();
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_pd() {
  I32 src = m68ki_read_imm_32();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_di() {
  I32 src = m68ki_read_imm_32();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_ix() {
  I32 src = m68ki_read_imm_32();
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_aw() {
  I32 src = m68ki_read_imm_32();
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_32_al() {
  I32 src = m68ki_read_imm_32();
  I32 ea = m68ki_read_imm_32();
  I32 res = src | m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ori_16_toc() {
  m68ki_set_ccr(
      (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
       ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
       ((m68ki_cpu.c_flag & 0x100) >> 8)) |
      m68ki_read_imm_16());
}

U0 m68k_op_ori_16_tos() {
  if (m68ki_cpu.s_flag) {
    I32 src = m68ki_read_imm_16();
    ;
    m68ki_set_sr(
        (m68ki_cpu.t1_flag | m68ki_cpu.t0_flag | (m68ki_cpu.s_flag << 11) |
         (m68ki_cpu.m_flag << 11) | m68ki_cpu.int_mask |
         (((m68ki_cpu.x_flag & 0x100) >> 4) | ((m68ki_cpu.n_flag & 0x80) >> 4) |
          ((!m68ki_cpu.not_z_flag) << 2) | ((m68ki_cpu.v_flag & 0x80) >> 6) |
          ((m68ki_cpu.c_flag & 0x100) >> 8))) |
        src);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_pack_16_rr() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]) + m68ki_read_imm_16();
    I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

    *r_dst = ((*r_dst) & ~0xff) | ((src >> 4) & 0x00f0) | (src & 0x000f);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_pack_16_mm_ax7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 ea_src = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    I32 src = m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1);
    ea_src = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    src = ((src << 8) | m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1)) +
          m68ki_read_imm_16();

    m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                     ((src >> 4) & 0x00f0) | (src & 0x000f));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_pack_16_mm_ay7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 ea_src = ((m68ki_cpu.dar + 8)[7] -= 2);
    I32 src = m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1);
    ea_src = ((m68ki_cpu.dar + 8)[7] -= 2);
    src = ((src << 8) | m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1)) +
          m68ki_read_imm_16();

    m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])),
                     m68ki_cpu.s_flag | 1,
                     ((src >> 4) & 0x00f0) | (src & 0x000f));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_pack_16_mm_axy7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 ea_src = ((m68ki_cpu.dar + 8)[7] -= 2);
    I32 src = m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1);
    ea_src = ((m68ki_cpu.dar + 8)[7] -= 2);
    src = ((src << 8) | m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1)) +
          m68ki_read_imm_16();

    m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                     ((src >> 4) & 0x00f0) | (src & 0x000f));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_pack_16_mm() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 ea_src = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    I32 src = m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1);
    ea_src = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
    src = ((src << 8) | m68ki_read_8_fc(ea_src, m68ki_cpu.s_flag | 1)) +
          m68ki_read_imm_16();

    m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7])),
                     m68ki_cpu.s_flag | 1,
                     ((src >> 4) & 0x00f0) | (src & 0x000f));
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_pea_32_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  m68ki_push_32(ea);
}

U0 m68k_op_pea_32_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));

  m68ki_push_32(ea);
}

U0 m68k_op_pea_32_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

  m68ki_push_32(ea);
}

U0 m68k_op_pea_32_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());

  m68ki_push_32(ea);
}

U0 m68k_op_pea_32_al() {
  I32 ea = m68ki_read_imm_32();

  m68ki_push_32(ea);
}

U0 m68k_op_pea_32_pcdi() {
  I32 ea = m68ki_get_ea_pcdi();

  m68ki_push_32(ea);
}

U0 m68k_op_pea_32_pcix() {
  I32 ea = m68ki_get_ea_pcix();

  m68ki_push_32(ea);
}

U0 m68k_op_reset() {
  if (m68ki_cpu.s_flag) {
    ;
    m68ki_remaining_cycles -= (m68ki_cpu.cyc_reset);
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_ror_8_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 shift = orig_shift & 7;
  I32 src = ((*r_dst) & 0xff);
  I32 res = ((((src) >> (shift)) | ((src) << (8 - (shift)))) & 0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << (9 - orig_shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 src = ((*r_dst) & 0xffff);
  I32 res = ((((src) >> (shift)) | ((src) << (16 - (shift)))) & 0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << (9 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = (T((shift) < 32, (src) >> (shift), 0) |
             T((32 - (shift)) < 32, (src) << (32 - (shift)), 0));

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << (9 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_8_r() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  I32 shift = orig_shift & 7;
  I32 src = ((*r_dst) & 0xff);
  I32 res = ((((src) >> (shift)) | ((src) << (8 - (shift)))) & 0xff);

  if (orig_shift != 0) {
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    *r_dst = ((*r_dst) & ~0xff) | res;
    m68ki_cpu.c_flag = src << (8 - ((shift - 1) & 7));
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = (src);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_r() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  I32 shift = orig_shift & 15;
  I32 src = ((*r_dst) & 0xffff);
  I32 res = ((((src) >> (shift)) | ((src) << (16 - (shift)))) & 0xffff);

  if (orig_shift != 0) {
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    m68ki_cpu.c_flag = (src >> ((shift - 1) & 15)) << 8;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 8);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 shift = orig_shift & 31;
  U32 src = *r_dst;
  U32 res = (T((shift) < 32, (src) >> (shift), 0) |
             T((32 - (shift)) < 32, (src) << (32 - (shift)), 0));

  if (orig_shift != 0) {
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    *r_dst = res;
    m68ki_cpu.c_flag = (src >> ((shift - 1) & 31)) << 8;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 24);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_ror_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((src) >> (1)) | ((src) << (16 - (1)))) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << 8;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_8_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 shift = orig_shift & 7;
  I32 src = ((*r_dst) & 0xff);
  I32 res = ((((src) << (shift)) | ((src) >> (8 - (shift)))) & 0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src << orig_shift;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 src = ((*r_dst) & 0xffff);
  I32 res = ((((src) << (shift)) | ((src) >> (16 - (shift)))) & 0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> (8 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = (T((shift) < 32, (src) << (shift), 0) |
             T((32 - (shift)) < 32, (src) >> (32 - (shift)), 0));

  *r_dst = res;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> (24 - shift);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_8_r() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  I32 shift = orig_shift & 7;
  I32 src = ((*r_dst) & 0xff);
  I32 res = ((((src) << (shift)) | ((src) >> (8 - (shift)))) & 0xff);

  if (orig_shift != 0) {
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    if (shift != 0) {
      *r_dst = ((*r_dst) & ~0xff) | res;
      m68ki_cpu.c_flag = src << shift;
      m68ki_cpu.n_flag = (res);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }
    m68ki_cpu.c_flag = (src & 1) << 8;
    m68ki_cpu.n_flag = (src);
    m68ki_cpu.not_z_flag = src;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = (src);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_r() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  I32 shift = orig_shift & 15;
  I32 src = ((*r_dst) & 0xffff);
  I32 res =
      ((((((src) << (shift)) | ((src) >> (16 - (shift)))) & 0xffff)) & 0xffff);

  if (orig_shift != 0) {
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    if (shift != 0) {
      *r_dst = ((*r_dst) & ~0xffff) | res;
      m68ki_cpu.c_flag = (src << shift) >> 8;
      m68ki_cpu.n_flag = ((res) >> 8);
      m68ki_cpu.not_z_flag = res;
      m68ki_cpu.v_flag = 0;
      return;
    }
    m68ki_cpu.c_flag = (src & 1) << 8;
    m68ki_cpu.n_flag = ((src) >> 8);
    m68ki_cpu.not_z_flag = src;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 8);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 shift = orig_shift & 31;
  U32 src = *r_dst;
  U32 res = (T((shift) < 32, (src) << (shift), 0) |
             T((32 - (shift)) < 32, (src) >> (32 - (shift)), 0));

  if (orig_shift != 0) {
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    *r_dst = res;

    m68ki_cpu.c_flag = (src >> (32 - shift)) << 8;
    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = 0;
  m68ki_cpu.n_flag = ((src) >> 24);
  m68ki_cpu.not_z_flag = src;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rol_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((((((src) << (1)) | ((src) >> (16 - (1)))) & 0xffff)) & 0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.c_flag = src >> 7;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_8_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 src = ((*r_dst) & 0xff);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) >> (shift)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) << (9 - (shift))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res;
  res = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 src = ((*r_dst) & 0xffff);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (shift)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (shift))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = (((T((shift) < 32, (src) >> (shift), 0) |
               T((33 - (shift)) < 32, (src) << (33 - (shift)), 0)) &
              ~(1 << (32 - shift))) |
             (((m68ki_cpu.x_flag >> 8) & 1) << (32 - shift)));
  U32 new_x_flag = src & (1 << (shift - 1));

  *r_dst = res;

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (new_x_flag != 0) << 8;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_8_r() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;

  if (orig_shift != 0) {
    I32 shift = orig_shift % 9;
    I32 src = ((*r_dst) & 0xff);
    I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) >> (shift)) |
               ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) << (9 - (shift))));

    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    m68ki_cpu.c_flag = m68ki_cpu.x_flag = res;
    res = ((res)&0xff);

    *r_dst = ((*r_dst) & ~0xff) | res;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = m68ki_cpu.x_flag;
  m68ki_cpu.n_flag = (*r_dst);
  m68ki_cpu.not_z_flag = ((*r_dst) & 0xff);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;

  if (orig_shift != 0) {
    I32 shift = orig_shift % 17;
    I32 src = ((*r_dst) & 0xffff);
    I32 res =
        (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (shift)) |
         ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (shift))));

    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
    res = ((res)&0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = m68ki_cpu.x_flag;
  m68ki_cpu.n_flag = ((*r_dst) >> 8);
  m68ki_cpu.not_z_flag = ((*r_dst) & 0xffff);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 shift = orig_shift % 33;
  U32 src = *r_dst;
  U32 res = (((T((shift) < 32, (src) >> (shift), 0) |
               T((33 - (shift)) < 32, (src) << (33 - (shift)), 0)) &
              ~(1 << (32 - shift))) |
             (((m68ki_cpu.x_flag >> 8) & 1) << (32 - shift)));
  U32 new_x_flag = src & (1 << (shift - 1));

  if (orig_shift != 0)
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

  if (shift != 0) {
    *r_dst = res;
    m68ki_cpu.x_flag = (new_x_flag != 0) << 8;
  } else
    res = src;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxr_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_8_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 src = ((*r_dst) & 0xff);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) << (shift)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) >> (9 - (shift))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res;
  res = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | res;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_s() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 src = ((*r_dst) & 0xffff);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (shift)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (shift))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | res;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_32_s() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  U32 shift = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  U32 src = *r_dst;
  U32 res = (((T((shift) < 32, (src) << (shift), 0) |
               T((33 - (shift)) < 32, (src) >> (33 - (shift)), 0)) &
              ~(1 << (shift - 1))) |
             (((m68ki_cpu.x_flag >> 8) & 1) << (shift - 1)));
  U32 new_x_flag = src & (1 << (32 - shift));

  *r_dst = res;

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = (new_x_flag != 0) << 8;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_8_r() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;

  if (orig_shift != 0) {
    I32 shift = orig_shift % 9;
    I32 src = ((*r_dst) & 0xff);
    I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) << (shift)) |
               ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 8)) >> (9 - (shift))));

    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    m68ki_cpu.c_flag = m68ki_cpu.x_flag = res;
    res = ((res)&0xff);

    *r_dst = ((*r_dst) & ~0xff) | res;
    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = m68ki_cpu.x_flag;
  m68ki_cpu.n_flag = (*r_dst);
  m68ki_cpu.not_z_flag = ((*r_dst) & 0xff);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;

  if (orig_shift != 0) {
    I32 shift = orig_shift % 17;
    I32 src = ((*r_dst) & 0xffff);
    I32 res =
        (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (shift)) |
         ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (shift))));

    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

    m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
    res = ((res)&0xffff);

    *r_dst = ((*r_dst) & ~0xffff) | res;
    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    return;
  }

  m68ki_cpu.c_flag = m68ki_cpu.x_flag;
  m68ki_cpu.n_flag = ((*r_dst) >> 8);
  m68ki_cpu.not_z_flag = ((*r_dst) & 0xffff);
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_32_r() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 orig_shift = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]) & 0x3f;
  U32 shift = orig_shift % 33;
  U32 src = *r_dst;
  U32 res = (((T((shift) < 32, (src) << (shift), 0) |
               T((33 - (shift)) < 32, (src) >> (33 - (shift)), 0)) &
              ~(1 << (shift - 1))) |
             (((m68ki_cpu.x_flag >> 8) & 1) << (shift - 1)));
  U32 new_x_flag = src & (1 << (32 - shift));

  if (orig_shift != 0)
    m68ki_remaining_cycles -= (orig_shift << m68ki_cpu.cyc_shift);

  if (shift != 0) {
    *r_dst = res;
    m68ki_cpu.x_flag = (new_x_flag != 0) << 8;
  } else
    res = src;
  m68ki_cpu.c_flag = m68ki_cpu.x_flag;
  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_roxl_16_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = (((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) << (1)) |
             ((src | (((m68ki_cpu.x_flag >> 8) & 1) << 16)) >> (17 - (1))));

  m68ki_cpu.c_flag = m68ki_cpu.x_flag = res >> 8;
  res = ((res)&0xffff);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_rtd_32() {
  if (((m68ki_cpu.cpu_type) & (2 | 4 | 8))) {
    I32 new_pc = m68ki_pull_32();

    ;
    (m68ki_cpu.dar + 8)[7] =
        ((m68ki_cpu.dar + 8)[7] + MAKE_INT_16(m68ki_read_imm_16()));
    m68ki_jump(new_pc);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_rte_32() {
  if (m68ki_cpu.s_flag) {
    I32 new_sr;
    I32 new_pc;
    I32 format_word;

    ;

    if (((m68ki_cpu.cpu_type) == 1)) {
      new_sr = m68ki_pull_16();
      new_pc = m68ki_pull_32();
      m68ki_jump(new_pc);
      m68ki_set_sr(new_sr);
      return;
    }

    if (((m68ki_cpu.cpu_type) == 2)) {
      format_word =
          m68ki_read_16_fc((m68ki_cpu.dar + 8)[7] + 6, m68ki_cpu.s_flag | 1) >>
          12;
      if (format_word == 0) {
        new_sr = m68ki_pull_16();
        new_pc = m68ki_pull_32();
        m68ki_fake_pull_16();
        m68ki_jump(new_pc);
        m68ki_set_sr(new_sr);
        return;
      }

      m68ki_exception_format_error();
      return;
    }

  rte_loop:
    format_word =
        m68ki_read_16_fc((m68ki_cpu.dar + 8)[7] + 6, m68ki_cpu.s_flag | 1) >>
        12;
    switch (format_word) {
    case 0:
      new_sr = m68ki_pull_16();
      new_pc = m68ki_pull_32();
      m68ki_fake_pull_16();
      m68ki_jump(new_pc);
      m68ki_set_sr(new_sr);
      return;
    case 1:
      new_sr = m68ki_pull_16();
      m68ki_fake_pull_32();
      m68ki_fake_pull_16();
      m68ki_set_sr_noint(new_sr);
      goto rte_loop;
    case 2:
      new_sr = m68ki_pull_16();
      new_pc = m68ki_pull_32();
      m68ki_fake_pull_16();
      m68ki_fake_pull_32();
      m68ki_jump(new_pc);
      m68ki_set_sr(new_sr);
      return;
    }

    m68ki_exception_format_error();
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_rtm_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    ;

    ;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_rtr_32() {
  ;
  m68ki_set_ccr(m68ki_pull_16());
  m68ki_jump(m68ki_pull_32());
}

U0 m68k_op_rts_32() {
  ;
  m68ki_jump(m68ki_pull_32());
}

U0 m68k_op_sbcd_8_rr() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 dst = *r_dst;
  I32 res = ((dst)&0x0f) - ((src)&0x0f) - ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res -= 6;
  res += ((dst)&0xf0) - ((src)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res += 0xa0;

  res = ((res)&0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xff) | res;
}

U0 m68k_op_sbcd_8_mm_ax7() {
  I32 src = OPER_AY_PD_8();
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((dst)&0x0f) - ((src)&0x0f) - ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res -= 6;
  res += ((dst)&0xf0) - ((src)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res += 0xa0;

  res = ((res)&0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_sbcd_8_mm_ay7() {
  I32 src = OPER_A7_PD_8();
  I32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((dst)&0x0f) - ((src)&0x0f) - ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res -= 6;
  res += ((dst)&0xf0) - ((src)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res += 0xa0;

  res = ((res)&0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_sbcd_8_mm_axy7() {
  I32 src = OPER_A7_PD_8();
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((dst)&0x0f) - ((src)&0x0f) - ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res -= 6;
  res += ((dst)&0xf0) - ((src)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res += 0xa0;

  res = ((res)&0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_sbcd_8_mm() {
  I32 src = OPER_AY_PD_8();
  I32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = ((dst)&0x0f) - ((src)&0x0f) - ((m68ki_cpu.x_flag >> 8) & 1);

  if (res > 9)
    res -= 6;
  res += ((dst)&0xf0) - ((src)&0xf0);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res > 0x99) << 8;
  if (m68ki_cpu.c_flag)
    res += 0xa0;

  res = ((res)&0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_st_8_d() { (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff; }

U0 m68k_op_st_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_st_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_st_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   0xff);
}

U0 m68k_op_st_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_st_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_st_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_st_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_st_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   0xff);
}

U0 m68k_op_st_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1, 0xff);
}

U0 m68k_op_sf_8_d() { (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00; }

U0 m68k_op_sf_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   0);
}

U0 m68k_op_sf_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_sf_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1, 0);
}

U0 m68k_op_shi_8_d() {
  if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_sls_8_d() {
  if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_scc_8_d() {
  if ((!(m68ki_cpu.c_flag & 0x100))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_scs_8_d() {
  if ((m68ki_cpu.c_flag & 0x100)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_sne_8_d() {
  if (m68ki_cpu.not_z_flag) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_seq_8_d() {
  if ((!m68ki_cpu.not_z_flag)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_svc_8_d() {
  if ((!(m68ki_cpu.v_flag & 0x80))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_svs_8_d() {
  if ((m68ki_cpu.v_flag & 0x80)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_spl_8_d() {
  if ((!(m68ki_cpu.n_flag & 0x80))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_smi_8_d() {
  if ((m68ki_cpu.n_flag & 0x80)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_sge_8_d() {
  if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_slt_8_d() {
  if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_sgt_8_d() {
  if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
       m68ki_cpu.not_z_flag)) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_sle_8_d() {
  if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
       (!m68ki_cpu.not_z_flag))) {
    (m68ki_cpu.dar[m68ki_cpu.ir & 7]) |= 0xff;
    return;
  }
  (m68ki_cpu.dar[m68ki_cpu.ir & 7]) &= 0xffffff00;
}

U0 m68k_op_shi_8_ai() {
  m68ki_write_8_fc(
      ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_pi() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_pi7() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_pd() {
  m68ki_write_8_fc(
      (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_pd7() {
  m68ki_write_8_fc(
      ((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_di() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
       MAKE_INT_16(m68ki_read_imm_16())),
      m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_ix() {
  m68ki_write_8_fc(
      m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
      m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_aw() {
  m68ki_write_8_fc(
      MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_shi_8_al() {
  m68ki_write_8_fc(
      m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
      T(((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_sls_8_ai() {
  m68ki_write_8_fc(
      ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_pi() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_pi7() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_pd() {
  m68ki_write_8_fc(
      (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_pd7() {
  m68ki_write_8_fc(
      ((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_di() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
       MAKE_INT_16(m68ki_read_imm_16())),
      m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_ix() {
  m68ki_write_8_fc(
      m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
      m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_aw() {
  m68ki_write_8_fc(
      MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_sls_8_al() {
  m68ki_write_8_fc(
      m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
      T(((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)), 0xff, 0));
}

U0 m68k_op_scc_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scc_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.c_flag & 0x100)), 0xff, 0));
}

U0 m68k_op_scs_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_scs_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.c_flag & 0x100), 0xff, 0));
}

U0 m68k_op_sne_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_aw() {
  m68ki_write_8_fc((m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_sne_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T(m68ki_cpu.not_z_flag, 0xff, 0));
}

U0 m68k_op_seq_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_seq_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((!m68ki_cpu.not_z_flag), 0xff, 0));
}

U0 m68k_op_svc_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svc_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.v_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_svs_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_svs_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.v_flag & 0x80), 0xff, 0));
}

U0 m68k_op_spl_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_spl_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((!(m68ki_cpu.n_flag & 0x80)), 0xff, 0));
}

U0 m68k_op_smi_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1, T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_smi_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((m68ki_cpu.n_flag & 0x80), 0xff, 0));
}

U0 m68k_op_sge_8_ai() {
  m68ki_write_8_fc(
      ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_pi() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_pi7() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_pd() {
  m68ki_write_8_fc(
      (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_pd7() {
  m68ki_write_8_fc(
      ((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_di() {
  m68ki_write_8_fc(
      (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
       MAKE_INT_16(m68ki_read_imm_16())),
      m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_ix() {
  m68ki_write_8_fc(
      m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
      m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_aw() {
  m68ki_write_8_fc(
      MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_sge_8_al() {
  m68ki_write_8_fc(
      m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
      T((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)), 0xff, 0));
}

U0 m68k_op_slt_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_slt_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T(((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80), 0xff, 0));
}

U0 m68k_op_sgt_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sgt_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T(((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
                      m68ki_cpu.not_z_flag),
                     0xff, 0));
}

U0 m68k_op_sle_8_ai() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]),
                   m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_pi() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++),
                   m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_pi7() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[7] += 2) - 2), m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_pd() {
  m68ki_write_8_fc((--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_pd7() {
  m68ki_write_8_fc(((m68ki_cpu.dar + 8)[7] -= 2), m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_di() {
  m68ki_write_8_fc((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
                    MAKE_INT_16(m68ki_read_imm_16())),
                   m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_ix() {
  m68ki_write_8_fc(m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])),
                   m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_aw() {
  m68ki_write_8_fc(MAKE_INT_16(m68ki_read_imm_16()), m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_sle_8_al() {
  m68ki_write_8_fc(m68ki_read_imm_32(), m68ki_cpu.s_flag | 1,
                   T((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
                      (!m68ki_cpu.not_z_flag)),
                     0xff, 0));
}

U0 m68k_op_stop() {
  if (m68ki_cpu.s_flag) {
    I32 new_sr = m68ki_read_imm_16();
    ;
    m68ki_cpu.stopped |= 1;
    m68ki_set_sr(new_sr);
    m68ki_remaining_cycles = 0;
    return;
  }
  m68ki_exception_privilege_violation();
}

U0 m68k_op_sub_8_er_d() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_ai() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_AI_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_pi() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_PI_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_pi7() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_A7_PI_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_pd() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_PD_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_pd7() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_A7_PD_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_di() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_DI_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_ix() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_IX_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_aw() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AW_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_al() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AL_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_pcdi() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_PCDI_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_pcix() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_PCIX_8();
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_er_i() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));
  m68ki_cpu.not_z_flag = ((res)&0xff);

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_d() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_a() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])) & 0xffff);
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_ai() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_AI_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_pi() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_PI_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_pd() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_PD_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_di() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_DI_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_ix() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_IX_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_aw() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AW_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_al() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AL_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_pcdi() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_PCDI_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_pcix() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_PCIX_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_16_er_i() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = m68ki_read_imm_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_d() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_a() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_ai() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_AI_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_pi() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_PI_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_pd() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_PD_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_di() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_DI_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_ix() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AY_IX_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_aw() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AW_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_al() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_AL_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_pcdi() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_PCDI_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_pcix() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = OPER_PCIX_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_32_er_i() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = m68ki_read_imm_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);
  m68ki_cpu.not_z_flag = (res);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_sub_8_re_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_8_re_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xff);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_16_re_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = (((m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7])) & 0xffff);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_pi() {
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_pd() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_sub_32_re_al() {
  I32 ea = m68ki_read_imm_32();
  I32 src = (m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_suba_16_d() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16((m68ki_cpu.dar[m68ki_cpu.ir & 7])));
}

U0 m68k_op_suba_16_a() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])));
}

U0 m68k_op_suba_16_ai() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AY_AI_16()));
}

U0 m68k_op_suba_16_pi() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AY_PI_16()));
}

U0 m68k_op_suba_16_pd() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AY_PD_16()));
}

U0 m68k_op_suba_16_di() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AY_DI_16()));
}

U0 m68k_op_suba_16_ix() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AY_IX_16()));
}

U0 m68k_op_suba_16_aw() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AW_16()));
}

U0 m68k_op_suba_16_al() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_AL_16()));
}

U0 m68k_op_suba_16_pcdi() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_PCDI_16()));
}

U0 m68k_op_suba_16_pcix() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(OPER_PCIX_16()));
}

U0 m68k_op_suba_16_i() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - MAKE_INT_16(m68ki_read_imm_16()));
}

U0 m68k_op_suba_32_d() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - (m68ki_cpu.dar[m68ki_cpu.ir & 7]));
}

U0 m68k_op_suba_32_a() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
}

U0 m68k_op_suba_32_ai() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AY_AI_32());
}

U0 m68k_op_suba_32_pi() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AY_PI_32());
}

U0 m68k_op_suba_32_pd() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AY_PD_32());
}

U0 m68k_op_suba_32_di() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AY_DI_32());
}

U0 m68k_op_suba_32_ix() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AY_IX_32());
}

U0 m68k_op_suba_32_aw() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AW_32());
}

U0 m68k_op_suba_32_al() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_AL_32());
}

U0 m68k_op_suba_32_pcdi() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_PCDI_32());
}

U0 m68k_op_suba_32_pcix() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - OPER_PCIX_32());
}

U0 m68k_op_suba_32_i() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]);

  *r_dst = (*r_dst - m68ki_read_imm_32());
}

U0 m68k_op_subi_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_subi_8_ai() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_pi() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_pi7() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_pd() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_pd7() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_di() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_ix() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_aw() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_8_al() {
  I32 src = ((m68ki_read_imm_16()) & 0xff);
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_imm_16();
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_subi_16_ai() {
  I32 src = m68ki_read_imm_16();
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_pi() {
  I32 src = m68ki_read_imm_16();
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_pd() {
  I32 src = m68ki_read_imm_16();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_di() {
  I32 src = m68ki_read_imm_16();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_ix() {
  I32 src = m68ki_read_imm_16();
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_aw() {
  I32 src = m68ki_read_imm_16();
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_16_al() {
  I32 src = m68ki_read_imm_16();
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 src = m68ki_read_imm_32();
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_subi_32_ai() {
  I32 src = m68ki_read_imm_32();
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_pi() {
  I32 src = m68ki_read_imm_32();
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_pd() {
  I32 src = m68ki_read_imm_32();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_di() {
  I32 src = m68ki_read_imm_32();
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_ix() {
  I32 src = m68ki_read_imm_32();
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_aw() {
  I32 src = m68ki_read_imm_32();
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subi_32_al() {
  I32 src = m68ki_read_imm_32();
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  *r_dst = ((*r_dst) & ~0xff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_subq_8_ai() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_pi() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_pi7() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_pd() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_pd7() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_di() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_ix() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_aw() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_8_al() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = ((res)&0xff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  *r_dst = ((*r_dst) & ~0xffff) | m68ki_cpu.not_z_flag;
}

U0 m68k_op_subq_16_a() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  *r_dst = (*r_dst - ((((m68ki_cpu.ir >> 9) - 1) & 7) + 1));
}

U0 m68k_op_subq_16_ai() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_pi() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 2) - 2);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_pd() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 2);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_di() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_ix() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_aw() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_16_al() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = ((res)&0xffff);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 dst = *r_dst;
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  *r_dst = m68ki_cpu.not_z_flag;
}

U0 m68k_op_subq_32_a() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  *r_dst = (*r_dst - ((((m68ki_cpu.ir >> 9) - 1) & 7) + 1));
}

U0 m68k_op_subq_32_ai() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_pi() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = ((((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) += 4) - 4);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_pd() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) -= 4);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_di() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_ix() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_aw() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subq_32_al() {
  I32 src = (((m68ki_cpu.ir >> 9) - 1) & 7) + 1;
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src;

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, m68ki_cpu.not_z_flag);
}

U0 m68k_op_subx_8_rr() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);
  I32 dst = ((*r_dst) & 0xff);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xff) | res;
}

U0 m68k_op_subx_16_rr() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);
  I32 dst = ((*r_dst) & 0xffff);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = ((*r_dst) & ~0xffff) | res;
}

U0 m68k_op_subx_32_rr() {
  I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);
  I32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
  I32 dst = *r_dst;
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  *r_dst = res;
}

U0 m68k_op_subx_8_mm_ax7() {
  I32 src = OPER_AY_PD_8();
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_subx_8_mm_ay7() {
  I32 src = OPER_A7_PD_8();
  I32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_subx_8_mm_axy7() {
  I32 src = OPER_A7_PD_8();
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_subx_8_mm() {
  I32 src = OPER_AY_PD_8();
  I32 ea = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = (res);
  m68ki_cpu.v_flag = ((src ^ dst) & (res ^ dst));

  res = ((res)&0xff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_subx_16_mm() {
  I32 src = OPER_AY_PD_16();
  I32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 2);
  I32 dst = m68ki_read_16_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag = ((res) >> 8);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 8);

  res = ((res)&0xffff);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_16_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_subx_32_mm() {
  I32 src = OPER_AY_PD_32();
  I32 ea = (((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]) -= 4);
  I32 dst = m68ki_read_32_fc(ea, m68ki_cpu.s_flag | 1);
  I32 res = dst - src - ((m68ki_cpu.x_flag >> 8) & 1);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.x_flag = m68ki_cpu.c_flag =
      (((src & res) | (~dst & (src | res))) >> 23);
  m68ki_cpu.v_flag = (((src ^ dst) & (res ^ dst)) >> 24);

  res = (res);
  m68ki_cpu.not_z_flag |= res;

  m68ki_write_32_fc(ea, m68ki_cpu.s_flag | 1, res);
}

U0 m68k_op_swap_32() {
  U32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  m68ki_cpu.not_z_flag = (*r_dst << 16);
  *r_dst = (*r_dst >> 16) | m68ki_cpu.not_z_flag;

  m68ki_cpu.not_z_flag = *r_dst;
  m68ki_cpu.n_flag = ((*r_dst) >> 24);
  m68ki_cpu.c_flag = 0;
  m68ki_cpu.v_flag = 0;
}

U0 m68k_op_tas_8_d() {
  I32 *r_dst = &(m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  m68ki_cpu.not_z_flag = ((*r_dst) & 0xff);
  m68ki_cpu.n_flag = (*r_dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  *r_dst |= 0x80;
}

U0 m68k_op_tas_8_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_tas_8_al() {
  I32 ea = m68ki_read_imm_32();
  I32 dst = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.not_z_flag = dst;
  m68ki_cpu.n_flag = (dst);
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
  m68ki_write_8_fc(ea, m68ki_cpu.s_flag | 1, dst | 0x80);
}

U0 m68k_op_trap() { m68ki_exception_trapN(32 + (m68ki_cpu.ir & 0xf)); }

U0 m68k_op_trapt() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapt_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapt_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapf() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapf_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapf_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traphi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapls() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag)))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapcc() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.c_flag & 0x100)))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapcs() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.c_flag & 0x100))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapne() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (m68ki_cpu.not_z_flag)
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapeq() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!m68ki_cpu.not_z_flag))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapvc() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.v_flag & 0x80)))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapvs() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.v_flag & 0x80))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trappl() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.n_flag & 0x80)))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapmi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.n_flag & 0x80))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapge() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traplt() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapgt() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
         m68ki_cpu.not_z_flag))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traple() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
         (!m68ki_cpu.not_z_flag)))
      m68ki_exception_trap(7);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traphi_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapls_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapcc_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.c_flag & 0x100))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapcs_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.c_flag & 0x100)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapne_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (m68ki_cpu.not_z_flag) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapeq_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!m68ki_cpu.not_z_flag)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapvc_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.v_flag & 0x80))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapvs_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.v_flag & 0x80)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trappl_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.n_flag & 0x80))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapmi_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.n_flag & 0x80)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapge_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traplt_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapgt_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
         m68ki_cpu.not_z_flag)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traple_16() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
         (!m68ki_cpu.not_z_flag))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 2;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traphi_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!(m68ki_cpu.c_flag & 0x100)) && m68ki_cpu.not_z_flag)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapls_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.c_flag & 0x100) || (!m68ki_cpu.not_z_flag))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapcc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.c_flag & 0x100))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapcs_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.c_flag & 0x100)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapne_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (m68ki_cpu.not_z_flag) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapeq_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!m68ki_cpu.not_z_flag)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapvc_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.v_flag & 0x80))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapvs_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.v_flag & 0x80)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trappl_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!(m68ki_cpu.n_flag & 0x80))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapmi_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((m68ki_cpu.n_flag & 0x80)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapge_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traplt_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapgt_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if (((!((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80)) &&
         m68ki_cpu.not_z_flag)) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_traple_32() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    if ((((m68ki_cpu.n_flag ^ m68ki_cpu.v_flag) & 0x80) ||
         (!m68ki_cpu.not_z_flag))) {
      m68ki_exception_trap(7);
      return;
    }
    m68ki_cpu.pc += 4;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_trapv() {
  if ((!(m68ki_cpu.v_flag & 0x80))) {
    return;
  }
  m68ki_exception_trap(7);
}

U0 m68k_op_tst_8_d() {
  I32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xff);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_ai() {
  I32 ea = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_pi() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7])++);
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_pi7() {
  I32 ea = (((m68ki_cpu.dar + 8)[7] += 2) - 2);
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_pd() {
  I32 ea = (--((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_pd7() {
  I32 ea = ((m68ki_cpu.dar + 8)[7] -= 2);
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_di() {
  I32 ea = (((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]) +
            MAKE_INT_16(m68ki_read_imm_16()));
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_ix() {
  I32 ea = m68ki_get_ea_ix(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_aw() {
  I32 ea = MAKE_INT_16(m68ki_read_imm_16());
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_al() {
  I32 ea = m68ki_read_imm_32();
  I32 res = m68ki_read_8_fc(ea, m68ki_cpu.s_flag | 1);

  m68ki_cpu.n_flag = (res);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_8_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = OPER_PCDI_8();

    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_8_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = OPER_PCIX_8();

    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_8_i() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = ((m68ki_read_imm_16()) & 0xff);

    m68ki_cpu.n_flag = (res);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_16_d() {
  I32 res = (((m68ki_cpu.dar[m68ki_cpu.ir & 7])) & 0xffff);

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_a() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = MAKE_INT_16(((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]));

    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_16_ai() {
  I32 res = OPER_AY_AI_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_pi() {
  I32 res = OPER_AY_PI_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_pd() {
  I32 res = OPER_AY_PD_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_di() {
  I32 res = OPER_AY_DI_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_ix() {
  I32 res = OPER_AY_IX_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_aw() {
  I32 res = OPER_AW_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_al() {
  I32 res = OPER_AL_16();

  m68ki_cpu.n_flag = ((res) >> 8);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_16_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = OPER_PCDI_16();

    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_16_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = OPER_PCIX_16();

    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_16_i() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = m68ki_read_imm_16();

    m68ki_cpu.n_flag = ((res) >> 8);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_32_d() {
  I32 res = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_a() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = ((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_32_ai() {
  I32 res = OPER_AY_AI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_pi() {
  I32 res = OPER_AY_PI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_pd() {
  I32 res = OPER_AY_PD_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_di() {
  I32 res = OPER_AY_DI_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_ix() {
  I32 res = OPER_AY_IX_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_aw() {
  I32 res = OPER_AW_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_al() {
  I32 res = OPER_AL_32();

  m68ki_cpu.n_flag = ((res) >> 24);
  m68ki_cpu.not_z_flag = res;
  m68ki_cpu.v_flag = 0;
  m68ki_cpu.c_flag = 0;
}

U0 m68k_op_tst_32_pcdi() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = OPER_PCDI_32();

    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_32_pcix() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = OPER_PCIX_32();

    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_tst_32_i() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 res = m68ki_read_imm_32();

    m68ki_cpu.n_flag = ((res) >> 24);
    m68ki_cpu.not_z_flag = res;
    m68ki_cpu.v_flag = 0;
    m68ki_cpu.c_flag = 0;
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_unlk_32_a7() {
  (m68ki_cpu.dar + 8)[7] =
      m68ki_read_32_fc((m68ki_cpu.dar + 8)[7], m68ki_cpu.s_flag | 1);
}

U0 m68k_op_unlk_32() {
  I32 *r_dst = &((m68ki_cpu.dar + 8)[m68ki_cpu.ir & 7]);

  (m68ki_cpu.dar + 8)[7] = *r_dst;
  *r_dst = m68ki_pull_32();
}

U0 m68k_op_unpk_16_rr() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 src = (m68ki_cpu.dar[m68ki_cpu.ir & 7]);
    I32 *r_dst = &(m68ki_cpu.dar[(m68ki_cpu.ir >> 9) & 7]);

    *r_dst = ((*r_dst) & ~0xffff) |
             (((((src << 4) & 0x0f00) | (src & 0x000f)) + m68ki_read_imm_16()) &
              0xffff);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_unpk_16_mm_ax7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 src = OPER_AY_PD_8();
    I32 ea_dst;

    src = (((src << 4) & 0x0f00) | (src & 0x000f)) + m68ki_read_imm_16();
    ea_dst = ((m68ki_cpu.dar + 8)[7] -= 2);
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, (src >> 8) & 0xff);
    ea_dst = ((m68ki_cpu.dar + 8)[7] -= 2);
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, src & 0xff);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_unpk_16_mm_ay7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 src = OPER_A7_PD_8();
    I32 ea_dst;

    src = (((src << 4) & 0x0f00) | (src & 0x000f)) + m68ki_read_imm_16();
    ea_dst = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, (src >> 8) & 0xff);
    ea_dst = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, src & 0xff);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_unpk_16_mm_axy7() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {
    I32 src = OPER_A7_PD_8();
    I32 ea_dst;

    src = (((src << 4) & 0x0f00) | (src & 0x000f)) + m68ki_read_imm_16();
    ea_dst = ((m68ki_cpu.dar + 8)[7] -= 2);
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, (src >> 8) & 0xff);
    ea_dst = ((m68ki_cpu.dar + 8)[7] -= 2);
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, src & 0xff);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_op_unpk_16_mm() {
  if (((m68ki_cpu.cpu_type) & (4 | 8))) {

    I32 src = OPER_AY_PD_8();
    I32 ea_dst;

    src = (((src << 4) & 0x0f00) | (src & 0x000f)) + m68ki_read_imm_16();
    ea_dst = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, (src >> 8) & 0xff);
    ea_dst = (--((m68ki_cpu.dar + 8)[(m68ki_cpu.ir >> 9) & 7]));
    m68ki_write_8_fc(ea_dst, m68ki_cpu.s_flag | 1, src & 0xff);
    return;
  }
  m68ki_exception_illegal();
}

U0 m68k_set_irq(U32 int_level) {
  U32 old_level = m68ki_cpu.int_level;
  m68ki_cpu.int_level = int_level << 8;

  if (old_level != 0x0700 && m68ki_cpu.int_level == 0x0700)
    m68ki_exception_interrupt(7);
  else
    m68ki_check_interrupts();
}

U0 m68k_single_step() {
  while (!KeyDown(SC_ENTER))
    Sleep(1);
  while (KeyDown(SC_ENTER))
    Sleep(1);
}

I32 m68k_execute(I32 num_cycles) {
  num_cycles /= 7;

  if (!m68ki_cpu.stopped) {

    m68ki_remaining_cycles = num_cycles;
    m68ki_initial_cycles = num_cycles;

    m68ki_remaining_cycles -= (m68ki_cpu.int_cycles);
    m68ki_cpu.int_cycles = 0;

    ;

    do {

      ;

      ;

      ;

      m68ki_cpu.ppc = m68ki_cpu.pc;
      m68ki_cpu.ir = m68ki_read_imm_16();
      Call(m68ki_instruction_jump_table[m68ki_cpu.ir]);
      m68ki_remaining_cycles -= (m68ki_cpu.cyc_instruction[m68ki_cpu.ir]);

      ;
    } while (m68ki_remaining_cycles > 0);

    m68ki_cpu.ppc = m68ki_cpu.pc;

    m68ki_remaining_cycles -= (m68ki_cpu.int_cycles);
    m68ki_cpu.int_cycles = 0;

    cycle_counter += (m68ki_initial_cycles - m68ki_remaining_cycles) * 7;

    return m68ki_initial_cycles - m68ki_remaining_cycles;
  }

  m68ki_remaining_cycles = 0;
  m68ki_cpu.int_cycles = 0;

  cycle_counter += num_cycles * 7;

  return num_cycles;
}

opcode_handler_struct m68k_opcode_handler_table[1963] = {
    {&m68k_op_1010, 0xf000, 0xa000, {4, 4, 4}},
    {&m68k_op_1111, 0xf000, 0xf000, {4, 4, 4}},
    {&m68k_op_moveq_32, 0xf100, 0x7000, {4, 4, 2}},
    {&m68k_op_cpbcc_32, 0xf180, 0xf080, {0, 0, 4}},
    {&m68k_op_cpgen_32, 0xf1c0, 0xf000, {0, 0, 4}},
    {&m68k_op_cpscc_32, 0xf1c0, 0xf040, {0, 0, 4}},
    {&m68k_op_bra_8, 0xff00, 0x6000, {10, 10, 10}},
    {&m68k_op_bsr_8, 0xff00, 0x6100, {18, 18, 7}},
    {&m68k_op_bhi_8, 0xff00, 0x6200, {8, 8, 6}},
    {&m68k_op_bls_8, 0xff00, 0x6300, {8, 8, 6}},
    {&m68k_op_bcc_8, 0xff00, 0x6400, {8, 8, 6}},
    {&m68k_op_bcs_8, 0xff00, 0x6500, {8, 8, 6}},
    {&m68k_op_bne_8, 0xff00, 0x6600, {8, 8, 6}},
    {&m68k_op_beq_8, 0xff00, 0x6700, {8, 8, 6}},
    {&m68k_op_bvc_8, 0xff00, 0x6800, {8, 8, 6}},
    {&m68k_op_bvs_8, 0xff00, 0x6900, {8, 8, 6}},
    {&m68k_op_bpl_8, 0xff00, 0x6a00, {8, 8, 6}},
    {&m68k_op_bmi_8, 0xff00, 0x6b00, {8, 8, 6}},
    {&m68k_op_bge_8, 0xff00, 0x6c00, {8, 8, 6}},
    {&m68k_op_blt_8, 0xff00, 0x6d00, {8, 8, 6}},
    {&m68k_op_bgt_8, 0xff00, 0x6e00, {8, 8, 6}},
    {&m68k_op_ble_8, 0xff00, 0x6f00, {8, 8, 6}},
    {&m68k_op_btst_32_r_d, 0xf1f8, 0x0100, {6, 6, 4}},
    {&m68k_op_movep_16_er, 0xf1f8, 0x0108, {16, 16, 12}},
    {&m68k_op_btst_8_r_ai, 0xf1f8, 0x0110, {8, 8, 8}},
    {&m68k_op_btst_8_r_pi, 0xf1f8, 0x0118, {8, 8, 8}},
    {&m68k_op_btst_8_r_pd, 0xf1f8, 0x0120, {10, 10, 9}},
    {&m68k_op_btst_8_r_di, 0xf1f8, 0x0128, {12, 12, 9}},
    {&m68k_op_btst_8_r_ix, 0xf1f8, 0x0130, {14, 14, 11}},
    {&m68k_op_bchg_32_r_d, 0xf1f8, 0x0140, {8, 8, 4}},
    {&m68k_op_movep_32_er, 0xf1f8, 0x0148, {24, 24, 18}},
    {&m68k_op_bchg_8_r_ai, 0xf1f8, 0x0150, {12, 12, 8}},
    {&m68k_op_bchg_8_r_pi, 0xf1f8, 0x0158, {12, 12, 8}},
    {&m68k_op_bchg_8_r_pd, 0xf1f8, 0x0160, {14, 14, 9}},
    {&m68k_op_bchg_8_r_di, 0xf1f8, 0x0168, {16, 16, 9}},
    {&m68k_op_bchg_8_r_ix, 0xf1f8, 0x0170, {18, 18, 11}},
    {&m68k_op_bclr_32_r_d, 0xf1f8, 0x0180, {10, 10, 4}},
    {&m68k_op_movep_16_re, 0xf1f8, 0x0188, {16, 16, 11}},
    {&m68k_op_bclr_8_r_ai, 0xf1f8, 0x0190, {12, 14, 8}},
    {&m68k_op_bclr_8_r_pi, 0xf1f8, 0x0198, {12, 14, 8}},
    {&m68k_op_bclr_8_r_pd, 0xf1f8, 0x01a0, {14, 16, 9}},
    {&m68k_op_bclr_8_r_di, 0xf1f8, 0x01a8, {16, 18, 9}},
    {&m68k_op_bclr_8_r_ix, 0xf1f8, 0x01b0, {18, 20, 11}},
    {&m68k_op_bset_32_r_d, 0xf1f8, 0x01c0, {8, 8, 4}},
    {&m68k_op_movep_32_re, 0xf1f8, 0x01c8, {24, 24, 17}},
    {&m68k_op_bset_8_r_ai, 0xf1f8, 0x01d0, {12, 12, 8}},
    {&m68k_op_bset_8_r_pi, 0xf1f8, 0x01d8, {12, 12, 8}},
    {&m68k_op_bset_8_r_pd, 0xf1f8, 0x01e0, {14, 14, 9}},
    {&m68k_op_bset_8_r_di, 0xf1f8, 0x01e8, {16, 16, 9}},
    {&m68k_op_bset_8_r_ix, 0xf1f8, 0x01f0, {18, 18, 11}},
    {&m68k_op_move_8_d_d, 0xf1f8, 0x1000, {4, 4, 2}},
    {&m68k_op_move_8_d_ai, 0xf1f8, 0x1010, {8, 8, 6}},
    {&m68k_op_move_8_d_pi, 0xf1f8, 0x1018, {8, 8, 6}},
    {&m68k_op_move_8_d_pd, 0xf1f8, 0x1020, {10, 10, 7}},
    {&m68k_op_move_8_d_di, 0xf1f8, 0x1028, {12, 12, 7}},
    {&m68k_op_move_8_d_ix, 0xf1f8, 0x1030, {14, 14, 9}},
    {&m68k_op_move_8_ai_d, 0xf1f8, 0x1080, {8, 8, 4}},
    {&m68k_op_move_8_ai_ai, 0xf1f8, 0x1090, {12, 12, 8}},
    {&m68k_op_move_8_ai_pi, 0xf1f8, 0x1098, {12, 12, 8}},
    {&m68k_op_move_8_ai_pd, 0xf1f8, 0x10a0, {14, 14, 9}},
    {&m68k_op_move_8_ai_di, 0xf1f8, 0x10a8, {16, 16, 9}},
    {&m68k_op_move_8_ai_ix, 0xf1f8, 0x10b0, {18, 18, 11}},
    {&m68k_op_move_8_pi_d, 0xf1f8, 0x10c0, {8, 8, 4}},
    {&m68k_op_move_8_pi_ai, 0xf1f8, 0x10d0, {12, 12, 8}},
    {&m68k_op_move_8_pi_pi, 0xf1f8, 0x10d8, {12, 12, 8}},
    {&m68k_op_move_8_pi_pd, 0xf1f8, 0x10e0, {14, 14, 9}},
    {&m68k_op_move_8_pi_di, 0xf1f8, 0x10e8, {16, 16, 9}},
    {&m68k_op_move_8_pi_ix, 0xf1f8, 0x10f0, {18, 18, 11}},
    {&m68k_op_move_8_pd_d, 0xf1f8, 0x1100, {8, 8, 5}},
    {&m68k_op_move_8_pd_ai, 0xf1f8, 0x1110, {12, 12, 9}},
    {&m68k_op_move_8_pd_pi, 0xf1f8, 0x1118, {12, 12, 9}},
    {&m68k_op_move_8_pd_pd, 0xf1f8, 0x1120, {14, 14, 10}},
    {&m68k_op_move_8_pd_di, 0xf1f8, 0x1128, {16, 16, 10}},
    {&m68k_op_move_8_pd_ix, 0xf1f8, 0x1130, {18, 18, 12}},
    {&m68k_op_move_8_di_d, 0xf1f8, 0x1140, {12, 12, 5}},
    {&m68k_op_move_8_di_ai, 0xf1f8, 0x1150, {16, 16, 9}},
    {&m68k_op_move_8_di_pi, 0xf1f8, 0x1158, {16, 16, 9}},
    {&m68k_op_move_8_di_pd, 0xf1f8, 0x1160, {18, 18, 10}},
    {&m68k_op_move_8_di_di, 0xf1f8, 0x1168, {20, 20, 10}},
    {&m68k_op_move_8_di_ix, 0xf1f8, 0x1170, {22, 22, 12}},
    {&m68k_op_move_8_ix_d, 0xf1f8, 0x1180, {14, 14, 7}},
    {&m68k_op_move_8_ix_ai, 0xf1f8, 0x1190, {18, 18, 11}},
    {&m68k_op_move_8_ix_pi, 0xf1f8, 0x1198, {18, 18, 11}},
    {&m68k_op_move_8_ix_pd, 0xf1f8, 0x11a0, {20, 20, 12}},
    {&m68k_op_move_8_ix_di, 0xf1f8, 0x11a8, {22, 22, 12}},
    {&m68k_op_move_8_ix_ix, 0xf1f8, 0x11b0, {24, 24, 14}},
    {&m68k_op_move_32_d_d, 0xf1f8, 0x2000, {4, 4, 2}},
    {&m68k_op_move_32_d_a, 0xf1f8, 0x2008, {4, 4, 2}},
    {&m68k_op_move_32_d_ai, 0xf1f8, 0x2010, {12, 12, 6}},
    {&m68k_op_move_32_d_pi, 0xf1f8, 0x2018, {12, 12, 6}},
    {&m68k_op_move_32_d_pd, 0xf1f8, 0x2020, {14, 14, 7}},
    {&m68k_op_move_32_d_di, 0xf1f8, 0x2028, {16, 16, 7}},
    {&m68k_op_move_32_d_ix, 0xf1f8, 0x2030, {18, 18, 9}},
    {&m68k_op_movea_32_d, 0xf1f8, 0x2040, {4, 4, 2}},
    {&m68k_op_movea_32_a, 0xf1f8, 0x2048, {4, 4, 2}},
    {&m68k_op_movea_32_ai, 0xf1f8, 0x2050, {12, 12, 6}},
    {&m68k_op_movea_32_pi, 0xf1f8, 0x2058, {12, 12, 6}},
    {&m68k_op_movea_32_pd, 0xf1f8, 0x2060, {14, 14, 7}},
    {&m68k_op_movea_32_di, 0xf1f8, 0x2068, {16, 16, 7}},
    {&m68k_op_movea_32_ix, 0xf1f8, 0x2070, {18, 18, 9}},
    {&m68k_op_move_32_ai_d, 0xf1f8, 0x2080, {12, 12, 4}},
    {&m68k_op_move_32_ai_a, 0xf1f8, 0x2088, {12, 12, 4}},
    {&m68k_op_move_32_ai_ai, 0xf1f8, 0x2090, {20, 20, 8}},
    {&m68k_op_move_32_ai_pi, 0xf1f8, 0x2098, {20, 20, 8}},
    {&m68k_op_move_32_ai_pd, 0xf1f8, 0x20a0, {22, 22, 9}},
    {&m68k_op_move_32_ai_di, 0xf1f8, 0x20a8, {24, 24, 9}},
    {&m68k_op_move_32_ai_ix, 0xf1f8, 0x20b0, {26, 26, 11}},
    {&m68k_op_move_32_pi_d, 0xf1f8, 0x20c0, {12, 12, 4}},
    {&m68k_op_move_32_pi_a, 0xf1f8, 0x20c8, {12, 12, 4}},
    {&m68k_op_move_32_pi_ai, 0xf1f8, 0x20d0, {20, 20, 8}},
    {&m68k_op_move_32_pi_pi, 0xf1f8, 0x20d8, {20, 20, 8}},
    {&m68k_op_move_32_pi_pd, 0xf1f8, 0x20e0, {22, 22, 9}},
    {&m68k_op_move_32_pi_di, 0xf1f8, 0x20e8, {24, 24, 9}},
    {&m68k_op_move_32_pi_ix, 0xf1f8, 0x20f0, {26, 26, 11}},
    {&m68k_op_move_32_pd_d, 0xf1f8, 0x2100, {12, 14, 5}},
    {&m68k_op_move_32_pd_a, 0xf1f8, 0x2108, {12, 14, 5}},
    {&m68k_op_move_32_pd_ai, 0xf1f8, 0x2110, {20, 22, 9}},
    {&m68k_op_move_32_pd_pi, 0xf1f8, 0x2118, {20, 22, 9}},
    {&m68k_op_move_32_pd_pd, 0xf1f8, 0x2120, {22, 24, 10}},
    {&m68k_op_move_32_pd_di, 0xf1f8, 0x2128, {24, 26, 10}},
    {&m68k_op_move_32_pd_ix, 0xf1f8, 0x2130, {26, 28, 12}},
    {&m68k_op_move_32_di_d, 0xf1f8, 0x2140, {16, 16, 5}},
    {&m68k_op_move_32_di_a, 0xf1f8, 0x2148, {16, 16, 5}},
    {&m68k_op_move_32_di_ai, 0xf1f8, 0x2150, {24, 24, 9}},
    {&m68k_op_move_32_di_pi, 0xf1f8, 0x2158, {24, 24, 9}},
    {&m68k_op_move_32_di_pd, 0xf1f8, 0x2160, {26, 26, 10}},
    {&m68k_op_move_32_di_di, 0xf1f8, 0x2168, {28, 28, 10}},
    {&m68k_op_move_32_di_ix, 0xf1f8, 0x2170, {30, 30, 12}},
    {&m68k_op_move_32_ix_d, 0xf1f8, 0x2180, {18, 18, 7}},
    {&m68k_op_move_32_ix_a, 0xf1f8, 0x2188, {18, 18, 7}},
    {&m68k_op_move_32_ix_ai, 0xf1f8, 0x2190, {26, 26, 11}},
    {&m68k_op_move_32_ix_pi, 0xf1f8, 0x2198, {26, 26, 11}},
    {&m68k_op_move_32_ix_pd, 0xf1f8, 0x21a0, {28, 28, 12}},
    {&m68k_op_move_32_ix_di, 0xf1f8, 0x21a8, {30, 30, 12}},
    {&m68k_op_move_32_ix_ix, 0xf1f8, 0x21b0, {32, 32, 14}},
    {&m68k_op_move_16_d_d, 0xf1f8, 0x3000, {4, 4, 2}},
    {&m68k_op_move_16_d_a, 0xf1f8, 0x3008, {4, 4, 2}},
    {&m68k_op_move_16_d_ai, 0xf1f8, 0x3010, {8, 8, 6}},
    {&m68k_op_move_16_d_pi, 0xf1f8, 0x3018, {8, 8, 6}},
    {&m68k_op_move_16_d_pd, 0xf1f8, 0x3020, {10, 10, 7}},
    {&m68k_op_move_16_d_di, 0xf1f8, 0x3028, {12, 12, 7}},
    {&m68k_op_move_16_d_ix, 0xf1f8, 0x3030, {14, 14, 9}},
    {&m68k_op_movea_16_d, 0xf1f8, 0x3040, {4, 4, 2}},
    {&m68k_op_movea_16_a, 0xf1f8, 0x3048, {4, 4, 2}},
    {&m68k_op_movea_16_ai, 0xf1f8, 0x3050, {8, 8, 6}},
    {&m68k_op_movea_16_pi, 0xf1f8, 0x3058, {8, 8, 6}},
    {&m68k_op_movea_16_pd, 0xf1f8, 0x3060, {10, 10, 7}},
    {&m68k_op_movea_16_di, 0xf1f8, 0x3068, {12, 12, 7}},
    {&m68k_op_movea_16_ix, 0xf1f8, 0x3070, {14, 14, 9}},
    {&m68k_op_move_16_ai_d, 0xf1f8, 0x3080, {8, 8, 4}},
    {&m68k_op_move_16_ai_a, 0xf1f8, 0x3088, {8, 8, 4}},
    {&m68k_op_move_16_ai_ai, 0xf1f8, 0x3090, {12, 12, 8}},
    {&m68k_op_move_16_ai_pi, 0xf1f8, 0x3098, {12, 12, 8}},
    {&m68k_op_move_16_ai_pd, 0xf1f8, 0x30a0, {14, 14, 9}},
    {&m68k_op_move_16_ai_di, 0xf1f8, 0x30a8, {16, 16, 9}},
    {&m68k_op_move_16_ai_ix, 0xf1f8, 0x30b0, {18, 18, 11}},
    {&m68k_op_move_16_pi_d, 0xf1f8, 0x30c0, {8, 8, 4}},
    {&m68k_op_move_16_pi_a, 0xf1f8, 0x30c8, {8, 8, 4}},
    {&m68k_op_move_16_pi_ai, 0xf1f8, 0x30d0, {12, 12, 8}},
    {&m68k_op_move_16_pi_pi, 0xf1f8, 0x30d8, {12, 12, 8}},
    {&m68k_op_move_16_pi_pd, 0xf1f8, 0x30e0, {14, 14, 9}},
    {&m68k_op_move_16_pi_di, 0xf1f8, 0x30e8, {16, 16, 9}},
    {&m68k_op_move_16_pi_ix, 0xf1f8, 0x30f0, {18, 18, 11}},
    {&m68k_op_move_16_pd_d, 0xf1f8, 0x3100, {8, 8, 5}},
    {&m68k_op_move_16_pd_a, 0xf1f8, 0x3108, {8, 8, 5}},
    {&m68k_op_move_16_pd_ai, 0xf1f8, 0x3110, {12, 12, 9}},
    {&m68k_op_move_16_pd_pi, 0xf1f8, 0x3118, {12, 12, 9}},
    {&m68k_op_move_16_pd_pd, 0xf1f8, 0x3120, {14, 14, 10}},
    {&m68k_op_move_16_pd_di, 0xf1f8, 0x3128, {16, 16, 10}},
    {&m68k_op_move_16_pd_ix, 0xf1f8, 0x3130, {18, 18, 12}},
    {&m68k_op_move_16_di_d, 0xf1f8, 0x3140, {12, 12, 5}},
    {&m68k_op_move_16_di_a, 0xf1f8, 0x3148, {12, 12, 5}},
    {&m68k_op_move_16_di_ai, 0xf1f8, 0x3150, {16, 16, 9}},
    {&m68k_op_move_16_di_pi, 0xf1f8, 0x3158, {16, 16, 9}},
    {&m68k_op_move_16_di_pd, 0xf1f8, 0x3160, {18, 18, 10}},
    {&m68k_op_move_16_di_di, 0xf1f8, 0x3168, {20, 20, 10}},
    {&m68k_op_move_16_di_ix, 0xf1f8, 0x3170, {22, 22, 12}},
    {&m68k_op_move_16_ix_d, 0xf1f8, 0x3180, {14, 14, 7}},
    {&m68k_op_move_16_ix_a, 0xf1f8, 0x3188, {14, 14, 7}},
    {&m68k_op_move_16_ix_ai, 0xf1f8, 0x3190, {18, 18, 11}},
    {&m68k_op_move_16_ix_pi, 0xf1f8, 0x3198, {18, 18, 11}},
    {&m68k_op_move_16_ix_pd, 0xf1f8, 0x31a0, {20, 20, 12}},
    {&m68k_op_move_16_ix_di, 0xf1f8, 0x31a8, {22, 22, 12}},
    {&m68k_op_move_16_ix_ix, 0xf1f8, 0x31b0, {24, 24, 14}},
    {&m68k_op_chk_32_d, 0xf1f8, 0x4100, {0, 0, 8}},
    {&m68k_op_chk_32_ai, 0xf1f8, 0x4110, {0, 0, 12}},
    {&m68k_op_chk_32_pi, 0xf1f8, 0x4118, {0, 0, 12}},
    {&m68k_op_chk_32_pd, 0xf1f8, 0x4120, {0, 0, 13}},
    {&m68k_op_chk_32_di, 0xf1f8, 0x4128, {0, 0, 13}},
    {&m68k_op_chk_32_ix, 0xf1f8, 0x4130, {0, 0, 15}},
    {&m68k_op_chk_16_d, 0xf1f8, 0x4180, {10, 8, 8}},
    {&m68k_op_chk_16_ai, 0xf1f8, 0x4190, {14, 12, 12}},
    {&m68k_op_chk_16_pi, 0xf1f8, 0x4198, {14, 12, 12}},
    {&m68k_op_chk_16_pd, 0xf1f8, 0x41a0, {16, 14, 13}},
    {&m68k_op_chk_16_di, 0xf1f8, 0x41a8, {18, 16, 13}},
    {&m68k_op_chk_16_ix, 0xf1f8, 0x41b0, {20, 18, 15}},
    {&m68k_op_lea_32_ai, 0xf1f8, 0x41d0, {4, 4, 6}},
    {&m68k_op_lea_32_di, 0xf1f8, 0x41e8, {8, 8, 7}},
    {&m68k_op_lea_32_ix, 0xf1f8, 0x41f0, {12, 12, 9}},
    {&m68k_op_addq_8_d, 0xf1f8, 0x5000, {4, 4, 2}},
    {&m68k_op_addq_8_ai, 0xf1f8, 0x5010, {12, 12, 8}},
    {&m68k_op_addq_8_pi, 0xf1f8, 0x5018, {12, 12, 8}},
    {&m68k_op_addq_8_pd, 0xf1f8, 0x5020, {14, 14, 9}},
    {&m68k_op_addq_8_di, 0xf1f8, 0x5028, {16, 16, 9}},
    {&m68k_op_addq_8_ix, 0xf1f8, 0x5030, {18, 18, 11}},
    {&m68k_op_addq_16_d, 0xf1f8, 0x5040, {4, 4, 2}},
    {&m68k_op_addq_16_a, 0xf1f8, 0x5048, {4, 4, 2}},
    {&m68k_op_addq_16_ai, 0xf1f8, 0x5050, {12, 12, 8}},
    {&m68k_op_addq_16_pi, 0xf1f8, 0x5058, {12, 12, 8}},
    {&m68k_op_addq_16_pd, 0xf1f8, 0x5060, {14, 14, 9}},
    {&m68k_op_addq_16_di, 0xf1f8, 0x5068, {16, 16, 9}},
    {&m68k_op_addq_16_ix, 0xf1f8, 0x5070, {18, 18, 11}},
    {&m68k_op_addq_32_d, 0xf1f8, 0x5080, {8, 8, 2}},
    {&m68k_op_addq_32_a, 0xf1f8, 0x5088, {8, 8, 2}},
    {&m68k_op_addq_32_ai, 0xf1f8, 0x5090, {20, 20, 8}},
    {&m68k_op_addq_32_pi, 0xf1f8, 0x5098, {20, 20, 8}},
    {&m68k_op_addq_32_pd, 0xf1f8, 0x50a0, {22, 22, 9}},
    {&m68k_op_addq_32_di, 0xf1f8, 0x50a8, {24, 24, 9}},
    {&m68k_op_addq_32_ix, 0xf1f8, 0x50b0, {26, 26, 11}},
    {&m68k_op_subq_8_d, 0xf1f8, 0x5100, {4, 4, 2}},
    {&m68k_op_subq_8_ai, 0xf1f8, 0x5110, {12, 12, 8}},
    {&m68k_op_subq_8_pi, 0xf1f8, 0x5118, {12, 12, 8}},
    {&m68k_op_subq_8_pd, 0xf1f8, 0x5120, {14, 14, 9}},
    {&m68k_op_subq_8_di, 0xf1f8, 0x5128, {16, 16, 9}},
    {&m68k_op_subq_8_ix, 0xf1f8, 0x5130, {18, 18, 11}},
    {&m68k_op_subq_16_d, 0xf1f8, 0x5140, {4, 4, 2}},
    {&m68k_op_subq_16_a, 0xf1f8, 0x5148, {8, 4, 2}},
    {&m68k_op_subq_16_ai, 0xf1f8, 0x5150, {12, 12, 8}},
    {&m68k_op_subq_16_pi, 0xf1f8, 0x5158, {12, 12, 8}},
    {&m68k_op_subq_16_pd, 0xf1f8, 0x5160, {14, 14, 9}},
    {&m68k_op_subq_16_di, 0xf1f8, 0x5168, {16, 16, 9}},
    {&m68k_op_subq_16_ix, 0xf1f8, 0x5170, {18, 18, 11}},
    {&m68k_op_subq_32_d, 0xf1f8, 0x5180, {8, 8, 2}},
    {&m68k_op_subq_32_a, 0xf1f8, 0x5188, {8, 8, 2}},
    {&m68k_op_subq_32_ai, 0xf1f8, 0x5190, {20, 20, 8}},
    {&m68k_op_subq_32_pi, 0xf1f8, 0x5198, {20, 20, 8}},
    {&m68k_op_subq_32_pd, 0xf1f8, 0x51a0, {22, 22, 9}},
    {&m68k_op_subq_32_di, 0xf1f8, 0x51a8, {24, 24, 9}},
    {&m68k_op_subq_32_ix, 0xf1f8, 0x51b0, {26, 26, 11}},
    {&m68k_op_or_8_er_d, 0xf1f8, 0x8000, {4, 4, 2}},
    {&m68k_op_or_8_er_ai, 0xf1f8, 0x8010, {8, 8, 6}},
    {&m68k_op_or_8_er_pi, 0xf1f8, 0x8018, {8, 8, 6}},
    {&m68k_op_or_8_er_pd, 0xf1f8, 0x8020, {10, 10, 7}},
    {&m68k_op_or_8_er_di, 0xf1f8, 0x8028, {12, 12, 7}},
    {&m68k_op_or_8_er_ix, 0xf1f8, 0x8030, {14, 14, 9}},
    {&m68k_op_or_16_er_d, 0xf1f8, 0x8040, {4, 4, 2}},
    {&m68k_op_or_16_er_ai, 0xf1f8, 0x8050, {8, 8, 6}},
    {&m68k_op_or_16_er_pi, 0xf1f8, 0x8058, {8, 8, 6}},
    {&m68k_op_or_16_er_pd, 0xf1f8, 0x8060, {10, 10, 7}},
    {&m68k_op_or_16_er_di, 0xf1f8, 0x8068, {12, 12, 7}},
    {&m68k_op_or_16_er_ix, 0xf1f8, 0x8070, {14, 14, 9}},
    {&m68k_op_or_32_er_d, 0xf1f8, 0x8080, {6, 6, 2}},
    {&m68k_op_or_32_er_ai, 0xf1f8, 0x8090, {14, 14, 6}},
    {&m68k_op_or_32_er_pi, 0xf1f8, 0x8098, {14, 14, 6}},
    {&m68k_op_or_32_er_pd, 0xf1f8, 0x80a0, {16, 16, 7}},
    {&m68k_op_or_32_er_di, 0xf1f8, 0x80a8, {18, 18, 7}},
    {&m68k_op_or_32_er_ix, 0xf1f8, 0x80b0, {20, 20, 9}},
    {&m68k_op_divu_16_d, 0xf1f8, 0x80c0, {140, 108, 44}},
    {&m68k_op_divu_16_ai, 0xf1f8, 0x80d0, {144, 112, 48}},
    {&m68k_op_divu_16_pi, 0xf1f8, 0x80d8, {144, 112, 48}},
    {&m68k_op_divu_16_pd, 0xf1f8, 0x80e0, {146, 114, 49}},
    {&m68k_op_divu_16_di, 0xf1f8, 0x80e8, {148, 116, 49}},
    {&m68k_op_divu_16_ix, 0xf1f8, 0x80f0, {150, 118, 51}},
    {&m68k_op_sbcd_8_rr, 0xf1f8, 0x8100, {6, 6, 4}},
    {&m68k_op_sbcd_8_mm, 0xf1f8, 0x8108, {18, 18, 16}},
    {&m68k_op_or_8_re_ai, 0xf1f8, 0x8110, {12, 12, 8}},
    {&m68k_op_or_8_re_pi, 0xf1f8, 0x8118, {12, 12, 8}},
    {&m68k_op_or_8_re_pd, 0xf1f8, 0x8120, {14, 14, 9}},
    {&m68k_op_or_8_re_di, 0xf1f8, 0x8128, {16, 16, 9}},
    {&m68k_op_or_8_re_ix, 0xf1f8, 0x8130, {18, 18, 11}},
    {&m68k_op_pack_16_rr, 0xf1f8, 0x8140, {0, 0, 6}},
    {&m68k_op_pack_16_mm, 0xf1f8, 0x8148, {0, 0, 13}},
    {&m68k_op_or_16_re_ai, 0xf1f8, 0x8150, {12, 12, 8}},
    {&m68k_op_or_16_re_pi, 0xf1f8, 0x8158, {12, 12, 8}},
    {&m68k_op_or_16_re_pd, 0xf1f8, 0x8160, {14, 14, 9}},
    {&m68k_op_or_16_re_di, 0xf1f8, 0x8168, {16, 16, 9}},
    {&m68k_op_or_16_re_ix, 0xf1f8, 0x8170, {18, 18, 11}},
    {&m68k_op_unpk_16_rr, 0xf1f8, 0x8180, {0, 0, 8}},
    {&m68k_op_unpk_16_mm, 0xf1f8, 0x8188, {0, 0, 13}},
    {&m68k_op_or_32_re_ai, 0xf1f8, 0x8190, {20, 20, 8}},
    {&m68k_op_or_32_re_pi, 0xf1f8, 0x8198, {20, 20, 8}},
    {&m68k_op_or_32_re_pd, 0xf1f8, 0x81a0, {22, 22, 9}},
    {&m68k_op_or_32_re_di, 0xf1f8, 0x81a8, {24, 24, 9}},
    {&m68k_op_or_32_re_ix, 0xf1f8, 0x81b0, {26, 26, 11}},
    {&m68k_op_divs_16_d, 0xf1f8, 0x81c0, {158, 122, 56}},
    {&m68k_op_divs_16_ai, 0xf1f8, 0x81d0, {162, 126, 60}},
    {&m68k_op_divs_16_pi, 0xf1f8, 0x81d8, {162, 126, 60}},
    {&m68k_op_divs_16_pd, 0xf1f8, 0x81e0, {164, 128, 61}},
    {&m68k_op_divs_16_di, 0xf1f8, 0x81e8, {166, 130, 61}},
    {&m68k_op_divs_16_ix, 0xf1f8, 0x81f0, {168, 132, 63}},
    {&m68k_op_sub_8_er_d, 0xf1f8, 0x9000, {4, 4, 2}},
    {&m68k_op_sub_8_er_ai, 0xf1f8, 0x9010, {8, 8, 6}},
    {&m68k_op_sub_8_er_pi, 0xf1f8, 0x9018, {8, 8, 6}},
    {&m68k_op_sub_8_er_pd, 0xf1f8, 0x9020, {10, 10, 7}},
    {&m68k_op_sub_8_er_di, 0xf1f8, 0x9028, {12, 12, 7}},
    {&m68k_op_sub_8_er_ix, 0xf1f8, 0x9030, {14, 14, 9}},
    {&m68k_op_sub_16_er_d, 0xf1f8, 0x9040, {4, 4, 2}},
    {&m68k_op_sub_16_er_a, 0xf1f8, 0x9048, {4, 4, 2}},
    {&m68k_op_sub_16_er_ai, 0xf1f8, 0x9050, {8, 8, 6}},
    {&m68k_op_sub_16_er_pi, 0xf1f8, 0x9058, {8, 8, 6}},
    {&m68k_op_sub_16_er_pd, 0xf1f8, 0x9060, {10, 10, 7}},
    {&m68k_op_sub_16_er_di, 0xf1f8, 0x9068, {12, 12, 7}},
    {&m68k_op_sub_16_er_ix, 0xf1f8, 0x9070, {14, 14, 9}},
    {&m68k_op_sub_32_er_d, 0xf1f8, 0x9080, {6, 6, 2}},
    {&m68k_op_sub_32_er_a, 0xf1f8, 0x9088, {6, 6, 2}},
    {&m68k_op_sub_32_er_ai, 0xf1f8, 0x9090, {14, 14, 6}},
    {&m68k_op_sub_32_er_pi, 0xf1f8, 0x9098, {14, 14, 6}},
    {&m68k_op_sub_32_er_pd, 0xf1f8, 0x90a0, {16, 16, 7}},
    {&m68k_op_sub_32_er_di, 0xf1f8, 0x90a8, {18, 18, 7}},
    {&m68k_op_sub_32_er_ix, 0xf1f8, 0x90b0, {20, 20, 9}},
    {&m68k_op_suba_16_d, 0xf1f8, 0x90c0, {8, 8, 2}},
    {&m68k_op_suba_16_a, 0xf1f8, 0x90c8, {8, 8, 2}},
    {&m68k_op_suba_16_ai, 0xf1f8, 0x90d0, {12, 12, 6}},
    {&m68k_op_suba_16_pi, 0xf1f8, 0x90d8, {12, 12, 6}},
    {&m68k_op_suba_16_pd, 0xf1f8, 0x90e0, {14, 14, 7}},
    {&m68k_op_suba_16_di, 0xf1f8, 0x90e8, {16, 16, 7}},
    {&m68k_op_suba_16_ix, 0xf1f8, 0x90f0, {18, 18, 9}},
    {&m68k_op_subx_8_rr, 0xf1f8, 0x9100, {4, 4, 2}},
    {&m68k_op_subx_8_mm, 0xf1f8, 0x9108, {18, 18, 12}},
    {&m68k_op_sub_8_re_ai, 0xf1f8, 0x9110, {12, 12, 8}},
    {&m68k_op_sub_8_re_pi, 0xf1f8, 0x9118, {12, 12, 8}},
    {&m68k_op_sub_8_re_pd, 0xf1f8, 0x9120, {14, 14, 9}},
    {&m68k_op_sub_8_re_di, 0xf1f8, 0x9128, {16, 16, 9}},
    {&m68k_op_sub_8_re_ix, 0xf1f8, 0x9130, {18, 18, 11}},
    {&m68k_op_subx_16_rr, 0xf1f8, 0x9140, {4, 4, 2}},
    {&m68k_op_subx_16_mm, 0xf1f8, 0x9148, {18, 18, 12}},
    {&m68k_op_sub_16_re_ai, 0xf1f8, 0x9150, {12, 12, 8}},
    {&m68k_op_sub_16_re_pi, 0xf1f8, 0x9158, {12, 12, 8}},
    {&m68k_op_sub_16_re_pd, 0xf1f8, 0x9160, {14, 14, 9}},
    {&m68k_op_sub_16_re_di, 0xf1f8, 0x9168, {16, 16, 9}},
    {&m68k_op_sub_16_re_ix, 0xf1f8, 0x9170, {18, 18, 11}},
    {&m68k_op_subx_32_rr, 0xf1f8, 0x9180, {8, 6, 2}},
    {&m68k_op_subx_32_mm, 0xf1f8, 0x9188, {30, 30, 12}},
    {&m68k_op_sub_32_re_ai, 0xf1f8, 0x9190, {20, 20, 8}},
    {&m68k_op_sub_32_re_pi, 0xf1f8, 0x9198, {20, 20, 8}},
    {&m68k_op_sub_32_re_pd, 0xf1f8, 0x91a0, {22, 22, 9}},
    {&m68k_op_sub_32_re_di, 0xf1f8, 0x91a8, {24, 24, 9}},
    {&m68k_op_sub_32_re_ix, 0xf1f8, 0x91b0, {26, 26, 11}},
    {&m68k_op_suba_32_d, 0xf1f8, 0x91c0, {6, 6, 2}},
    {&m68k_op_suba_32_a, 0xf1f8, 0x91c8, {6, 6, 2}},
    {&m68k_op_suba_32_ai, 0xf1f8, 0x91d0, {14, 14, 6}},
    {&m68k_op_suba_32_pi, 0xf1f8, 0x91d8, {14, 14, 6}},
    {&m68k_op_suba_32_pd, 0xf1f8, 0x91e0, {16, 16, 7}},
    {&m68k_op_suba_32_di, 0xf1f8, 0x91e8, {18, 18, 7}},
    {&m68k_op_suba_32_ix, 0xf1f8, 0x91f0, {20, 20, 9}},
    {&m68k_op_cmp_8_d, 0xf1f8, 0xb000, {4, 4, 2}},
    {&m68k_op_cmp_8_ai, 0xf1f8, 0xb010, {8, 8, 6}},
    {&m68k_op_cmp_8_pi, 0xf1f8, 0xb018, {8, 8, 6}},
    {&m68k_op_cmp_8_pd, 0xf1f8, 0xb020, {10, 10, 7}},
    {&m68k_op_cmp_8_di, 0xf1f8, 0xb028, {12, 12, 7}},
    {&m68k_op_cmp_8_ix, 0xf1f8, 0xb030, {14, 14, 9}},
    {&m68k_op_cmp_16_d, 0xf1f8, 0xb040, {4, 4, 2}},
    {&m68k_op_cmp_16_a, 0xf1f8, 0xb048, {4, 4, 2}},
    {&m68k_op_cmp_16_ai, 0xf1f8, 0xb050, {8, 8, 6}},
    {&m68k_op_cmp_16_pi, 0xf1f8, 0xb058, {8, 8, 6}},
    {&m68k_op_cmp_16_pd, 0xf1f8, 0xb060, {10, 10, 7}},
    {&m68k_op_cmp_16_di, 0xf1f8, 0xb068, {12, 12, 7}},
    {&m68k_op_cmp_16_ix, 0xf1f8, 0xb070, {14, 14, 9}},
    {&m68k_op_cmp_32_d, 0xf1f8, 0xb080, {6, 6, 2}},
    {&m68k_op_cmp_32_a, 0xf1f8, 0xb088, {6, 6, 2}},
    {&m68k_op_cmp_32_ai, 0xf1f8, 0xb090, {14, 14, 6}},
    {&m68k_op_cmp_32_pi, 0xf1f8, 0xb098, {14, 14, 6}},
    {&m68k_op_cmp_32_pd, 0xf1f8, 0xb0a0, {16, 16, 7}},
    {&m68k_op_cmp_32_di, 0xf1f8, 0xb0a8, {18, 18, 7}},
    {&m68k_op_cmp_32_ix, 0xf1f8, 0xb0b0, {20, 20, 9}},
    {&m68k_op_cmpa_16_d, 0xf1f8, 0xb0c0, {6, 6, 4}},
    {&m68k_op_cmpa_16_a, 0xf1f8, 0xb0c8, {6, 6, 4}},
    {&m68k_op_cmpa_16_ai, 0xf1f8, 0xb0d0, {10, 10, 8}},
    {&m68k_op_cmpa_16_pi, 0xf1f8, 0xb0d8, {10, 10, 8}},
    {&m68k_op_cmpa_16_pd, 0xf1f8, 0xb0e0, {12, 12, 9}},
    {&m68k_op_cmpa_16_di, 0xf1f8, 0xb0e8, {14, 14, 9}},
    {&m68k_op_cmpa_16_ix, 0xf1f8, 0xb0f0, {16, 16, 11}},
    {&m68k_op_eor_8_d, 0xf1f8, 0xb100, {4, 4, 2}},
    {&m68k_op_cmpm_8, 0xf1f8, 0xb108, {12, 12, 9}},
    {&m68k_op_eor_8_ai, 0xf1f8, 0xb110, {12, 12, 8}},
    {&m68k_op_eor_8_pi, 0xf1f8, 0xb118, {12, 12, 8}},
    {&m68k_op_eor_8_pd, 0xf1f8, 0xb120, {14, 14, 9}},
    {&m68k_op_eor_8_di, 0xf1f8, 0xb128, {16, 16, 9}},
    {&m68k_op_eor_8_ix, 0xf1f8, 0xb130, {18, 18, 11}},
    {&m68k_op_eor_16_d, 0xf1f8, 0xb140, {4, 4, 2}},
    {&m68k_op_cmpm_16, 0xf1f8, 0xb148, {12, 12, 9}},
    {&m68k_op_eor_16_ai, 0xf1f8, 0xb150, {12, 12, 8}},
    {&m68k_op_eor_16_pi, 0xf1f8, 0xb158, {12, 12, 8}},
    {&m68k_op_eor_16_pd, 0xf1f8, 0xb160, {14, 14, 9}},
    {&m68k_op_eor_16_di, 0xf1f8, 0xb168, {16, 16, 9}},
    {&m68k_op_eor_16_ix, 0xf1f8, 0xb170, {18, 18, 11}},
    {&m68k_op_eor_32_d, 0xf1f8, 0xb180, {8, 6, 2}},
    {&m68k_op_cmpm_32, 0xf1f8, 0xb188, {20, 20, 9}},
    {&m68k_op_eor_32_ai, 0xf1f8, 0xb190, {20, 20, 8}},
    {&m68k_op_eor_32_pi, 0xf1f8, 0xb198, {20, 20, 8}},
    {&m68k_op_eor_32_pd, 0xf1f8, 0xb1a0, {22, 22, 9}},
    {&m68k_op_eor_32_di, 0xf1f8, 0xb1a8, {24, 24, 9}},
    {&m68k_op_eor_32_ix, 0xf1f8, 0xb1b0, {26, 26, 11}},
    {&m68k_op_cmpa_32_d, 0xf1f8, 0xb1c0, {6, 6, 4}},
    {&m68k_op_cmpa_32_a, 0xf1f8, 0xb1c8, {6, 6, 4}},
    {&m68k_op_cmpa_32_ai, 0xf1f8, 0xb1d0, {14, 14, 8}},
    {&m68k_op_cmpa_32_pi, 0xf1f8, 0xb1d8, {14, 14, 8}},
    {&m68k_op_cmpa_32_pd, 0xf1f8, 0xb1e0, {16, 16, 9}},
    {&m68k_op_cmpa_32_di, 0xf1f8, 0xb1e8, {18, 18, 9}},
    {&m68k_op_cmpa_32_ix, 0xf1f8, 0xb1f0, {20, 20, 11}},
    {&m68k_op_and_8_er_d, 0xf1f8, 0xc000, {4, 4, 2}},
    {&m68k_op_and_8_er_ai, 0xf1f8, 0xc010, {8, 8, 6}},
    {&m68k_op_and_8_er_pi, 0xf1f8, 0xc018, {8, 8, 6}},
    {&m68k_op_and_8_er_pd, 0xf1f8, 0xc020, {10, 10, 7}},
    {&m68k_op_and_8_er_di, 0xf1f8, 0xc028, {12, 12, 7}},
    {&m68k_op_and_8_er_ix, 0xf1f8, 0xc030, {14, 14, 9}},
    {&m68k_op_and_16_er_d, 0xf1f8, 0xc040, {4, 4, 2}},
    {&m68k_op_and_16_er_ai, 0xf1f8, 0xc050, {8, 8, 6}},
    {&m68k_op_and_16_er_pi, 0xf1f8, 0xc058, {8, 8, 6}},
    {&m68k_op_and_16_er_pd, 0xf1f8, 0xc060, {10, 10, 7}},
    {&m68k_op_and_16_er_di, 0xf1f8, 0xc068, {12, 12, 7}},
    {&m68k_op_and_16_er_ix, 0xf1f8, 0xc070, {14, 14, 9}},
    {&m68k_op_and_32_er_d, 0xf1f8, 0xc080, {6, 6, 2}},
    {&m68k_op_and_32_er_ai, 0xf1f8, 0xc090, {14, 14, 6}},
    {&m68k_op_and_32_er_pi, 0xf1f8, 0xc098, {14, 14, 6}},
    {&m68k_op_and_32_er_pd, 0xf1f8, 0xc0a0, {16, 16, 7}},
    {&m68k_op_and_32_er_di, 0xf1f8, 0xc0a8, {18, 18, 7}},
    {&m68k_op_and_32_er_ix, 0xf1f8, 0xc0b0, {20, 20, 9}},
    {&m68k_op_mulu_16_d, 0xf1f8, 0xc0c0, {54, 30, 27}},
    {&m68k_op_mulu_16_ai, 0xf1f8, 0xc0d0, {58, 34, 31}},
    {&m68k_op_mulu_16_pi, 0xf1f8, 0xc0d8, {58, 34, 31}},
    {&m68k_op_mulu_16_pd, 0xf1f8, 0xc0e0, {60, 36, 32}},
    {&m68k_op_mulu_16_di, 0xf1f8, 0xc0e8, {62, 38, 32}},
    {&m68k_op_mulu_16_ix, 0xf1f8, 0xc0f0, {64, 40, 34}},
    {&m68k_op_abcd_8_rr, 0xf1f8, 0xc100, {6, 6, 4}},
    {&m68k_op_abcd_8_mm, 0xf1f8, 0xc108, {18, 18, 16}},
    {&m68k_op_and_8_re_ai, 0xf1f8, 0xc110, {12, 12, 8}},
    {&m68k_op_and_8_re_pi, 0xf1f8, 0xc118, {12, 12, 8}},
    {&m68k_op_and_8_re_pd, 0xf1f8, 0xc120, {14, 14, 9}},
    {&m68k_op_and_8_re_di, 0xf1f8, 0xc128, {16, 16, 9}},
    {&m68k_op_and_8_re_ix, 0xf1f8, 0xc130, {18, 18, 11}},
    {&m68k_op_exg_32_dd, 0xf1f8, 0xc140, {6, 6, 2}},
    {&m68k_op_exg_32_aa, 0xf1f8, 0xc148, {6, 6, 2}},
    {&m68k_op_and_16_re_ai, 0xf1f8, 0xc150, {12, 12, 8}},
    {&m68k_op_and_16_re_pi, 0xf1f8, 0xc158, {12, 12, 8}},
    {&m68k_op_and_16_re_pd, 0xf1f8, 0xc160, {14, 14, 9}},
    {&m68k_op_and_16_re_di, 0xf1f8, 0xc168, {16, 16, 9}},
    {&m68k_op_and_16_re_ix, 0xf1f8, 0xc170, {18, 18, 11}},
    {&m68k_op_exg_32_da, 0xf1f8, 0xc188, {6, 6, 2}},
    {&m68k_op_and_32_re_ai, 0xf1f8, 0xc190, {20, 20, 8}},
    {&m68k_op_and_32_re_pi, 0xf1f8, 0xc198, {20, 20, 8}},
    {&m68k_op_and_32_re_pd, 0xf1f8, 0xc1a0, {22, 22, 9}},
    {&m68k_op_and_32_re_di, 0xf1f8, 0xc1a8, {24, 24, 9}},
    {&m68k_op_and_32_re_ix, 0xf1f8, 0xc1b0, {26, 26, 11}},
    {&m68k_op_muls_16_d, 0xf1f8, 0xc1c0, {54, 32, 27}},
    {&m68k_op_muls_16_ai, 0xf1f8, 0xc1d0, {58, 36, 31}},
    {&m68k_op_muls_16_pi, 0xf1f8, 0xc1d8, {58, 36, 31}},
    {&m68k_op_muls_16_pd, 0xf1f8, 0xc1e0, {60, 38, 32}},
    {&m68k_op_muls_16_di, 0xf1f8, 0xc1e8, {62, 40, 32}},
    {&m68k_op_muls_16_ix, 0xf1f8, 0xc1f0, {64, 42, 34}},
    {&m68k_op_add_8_er_d, 0xf1f8, 0xd000, {4, 4, 2}},
    {&m68k_op_add_8_er_ai, 0xf1f8, 0xd010, {8, 8, 6}},
    {&m68k_op_add_8_er_pi, 0xf1f8, 0xd018, {8, 8, 6}},
    {&m68k_op_add_8_er_pd, 0xf1f8, 0xd020, {10, 10, 7}},
    {&m68k_op_add_8_er_di, 0xf1f8, 0xd028, {12, 12, 7}},
    {&m68k_op_add_8_er_ix, 0xf1f8, 0xd030, {14, 14, 9}},
    {&m68k_op_add_16_er_d, 0xf1f8, 0xd040, {4, 4, 2}},
    {&m68k_op_add_16_er_a, 0xf1f8, 0xd048, {4, 4, 2}},
    {&m68k_op_add_16_er_ai, 0xf1f8, 0xd050, {8, 8, 6}},
    {&m68k_op_add_16_er_pi, 0xf1f8, 0xd058, {8, 8, 6}},
    {&m68k_op_add_16_er_pd, 0xf1f8, 0xd060, {10, 10, 7}},
    {&m68k_op_add_16_er_di, 0xf1f8, 0xd068, {12, 12, 7}},
    {&m68k_op_add_16_er_ix, 0xf1f8, 0xd070, {14, 14, 9}},
    {&m68k_op_add_32_er_d, 0xf1f8, 0xd080, {6, 6, 2}},
    {&m68k_op_add_32_er_a, 0xf1f8, 0xd088, {6, 6, 2}},
    {&m68k_op_add_32_er_ai, 0xf1f8, 0xd090, {14, 14, 6}},
    {&m68k_op_add_32_er_pi, 0xf1f8, 0xd098, {14, 14, 6}},
    {&m68k_op_add_32_er_pd, 0xf1f8, 0xd0a0, {16, 16, 7}},
    {&m68k_op_add_32_er_di, 0xf1f8, 0xd0a8, {18, 18, 7}},
    {&m68k_op_add_32_er_ix, 0xf1f8, 0xd0b0, {20, 20, 9}},
    {&m68k_op_adda_16_d, 0xf1f8, 0xd0c0, {8, 8, 2}},
    {&m68k_op_adda_16_a, 0xf1f8, 0xd0c8, {8, 8, 2}},
    {&m68k_op_adda_16_ai, 0xf1f8, 0xd0d0, {12, 12, 6}},
    {&m68k_op_adda_16_pi, 0xf1f8, 0xd0d8, {12, 12, 6}},
    {&m68k_op_adda_16_pd, 0xf1f8, 0xd0e0, {14, 14, 7}},
    {&m68k_op_adda_16_di, 0xf1f8, 0xd0e8, {16, 16, 7}},
    {&m68k_op_adda_16_ix, 0xf1f8, 0xd0f0, {18, 18, 9}},
    {&m68k_op_addx_8_rr, 0xf1f8, 0xd100, {4, 4, 2}},
    {&m68k_op_addx_8_mm, 0xf1f8, 0xd108, {18, 18, 12}},
    {&m68k_op_add_8_re_ai, 0xf1f8, 0xd110, {12, 12, 8}},
    {&m68k_op_add_8_re_pi, 0xf1f8, 0xd118, {12, 12, 8}},
    {&m68k_op_add_8_re_pd, 0xf1f8, 0xd120, {14, 14, 9}},
    {&m68k_op_add_8_re_di, 0xf1f8, 0xd128, {16, 16, 9}},
    {&m68k_op_add_8_re_ix, 0xf1f8, 0xd130, {18, 18, 11}},
    {&m68k_op_addx_16_rr, 0xf1f8, 0xd140, {4, 4, 2}},
    {&m68k_op_addx_16_mm, 0xf1f8, 0xd148, {18, 18, 12}},
    {&m68k_op_add_16_re_ai, 0xf1f8, 0xd150, {12, 12, 8}},
    {&m68k_op_add_16_re_pi, 0xf1f8, 0xd158, {12, 12, 8}},
    {&m68k_op_add_16_re_pd, 0xf1f8, 0xd160, {14, 14, 9}},
    {&m68k_op_add_16_re_di, 0xf1f8, 0xd168, {16, 16, 9}},
    {&m68k_op_add_16_re_ix, 0xf1f8, 0xd170, {18, 18, 11}},
    {&m68k_op_addx_32_rr, 0xf1f8, 0xd180, {8, 6, 2}},
    {&m68k_op_addx_32_mm, 0xf1f8, 0xd188, {30, 30, 12}},
    {&m68k_op_add_32_re_ai, 0xf1f8, 0xd190, {20, 20, 8}},
    {&m68k_op_add_32_re_pi, 0xf1f8, 0xd198, {20, 20, 8}},
    {&m68k_op_add_32_re_pd, 0xf1f8, 0xd1a0, {22, 22, 9}},
    {&m68k_op_add_32_re_di, 0xf1f8, 0xd1a8, {24, 24, 9}},
    {&m68k_op_add_32_re_ix, 0xf1f8, 0xd1b0, {26, 26, 11}},
    {&m68k_op_adda_32_d, 0xf1f8, 0xd1c0, {6, 6, 2}},
    {&m68k_op_adda_32_a, 0xf1f8, 0xd1c8, {6, 6, 2}},
    {&m68k_op_adda_32_ai, 0xf1f8, 0xd1d0, {14, 14, 6}},
    {&m68k_op_adda_32_pi, 0xf1f8, 0xd1d8, {14, 14, 6}},
    {&m68k_op_adda_32_pd, 0xf1f8, 0xd1e0, {16, 16, 7}},
    {&m68k_op_adda_32_di, 0xf1f8, 0xd1e8, {18, 18, 7}},
    {&m68k_op_adda_32_ix, 0xf1f8, 0xd1f0, {20, 20, 9}},
    {&m68k_op_asr_8_s, 0xf1f8, 0xe000, {6, 6, 6}},
    {&m68k_op_lsr_8_s, 0xf1f8, 0xe008, {6, 6, 4}},
    {&m68k_op_roxr_8_s, 0xf1f8, 0xe010, {6, 6, 12}},
    {&m68k_op_ror_8_s, 0xf1f8, 0xe018, {6, 6, 8}},
    {&m68k_op_asr_8_r, 0xf1f8, 0xe020, {6, 6, 6}},
    {&m68k_op_lsr_8_r, 0xf1f8, 0xe028, {6, 6, 6}},
    {&m68k_op_roxr_8_r, 0xf1f8, 0xe030, {6, 6, 12}},
    {&m68k_op_ror_8_r, 0xf1f8, 0xe038, {6, 6, 8}},
    {&m68k_op_asr_16_s, 0xf1f8, 0xe040, {6, 6, 6}},
    {&m68k_op_lsr_16_s, 0xf1f8, 0xe048, {6, 6, 4}},
    {&m68k_op_roxr_16_s, 0xf1f8, 0xe050, {6, 6, 12}},
    {&m68k_op_ror_16_s, 0xf1f8, 0xe058, {6, 6, 8}},
    {&m68k_op_asr_16_r, 0xf1f8, 0xe060, {6, 6, 6}},
    {&m68k_op_lsr_16_r, 0xf1f8, 0xe068, {6, 6, 6}},
    {&m68k_op_roxr_16_r, 0xf1f8, 0xe070, {6, 6, 12}},
    {&m68k_op_ror_16_r, 0xf1f8, 0xe078, {6, 6, 8}},
    {&m68k_op_asr_32_s, 0xf1f8, 0xe080, {8, 8, 6}},
    {&m68k_op_lsr_32_s, 0xf1f8, 0xe088, {8, 8, 4}},
    {&m68k_op_roxr_32_s, 0xf1f8, 0xe090, {8, 8, 12}},
    {&m68k_op_ror_32_s, 0xf1f8, 0xe098, {8, 8, 8}},
    {&m68k_op_asr_32_r, 0xf1f8, 0xe0a0, {8, 8, 6}},
    {&m68k_op_lsr_32_r, 0xf1f8, 0xe0a8, {8, 8, 6}},
    {&m68k_op_roxr_32_r, 0xf1f8, 0xe0b0, {8, 8, 12}},
    {&m68k_op_ror_32_r, 0xf1f8, 0xe0b8, {8, 8, 8}},
    {&m68k_op_asl_8_s, 0xf1f8, 0xe100, {6, 6, 8}},
    {&m68k_op_lsl_8_s, 0xf1f8, 0xe108, {6, 6, 4}},
    {&m68k_op_roxl_8_s, 0xf1f8, 0xe110, {6, 6, 12}},
    {&m68k_op_rol_8_s, 0xf1f8, 0xe118, {6, 6, 8}},
    {&m68k_op_asl_8_r, 0xf1f8, 0xe120, {6, 6, 8}},
    {&m68k_op_lsl_8_r, 0xf1f8, 0xe128, {6, 6, 6}},
    {&m68k_op_roxl_8_r, 0xf1f8, 0xe130, {6, 6, 12}},
    {&m68k_op_rol_8_r, 0xf1f8, 0xe138, {6, 6, 8}},
    {&m68k_op_asl_16_s, 0xf1f8, 0xe140, {6, 6, 8}},
    {&m68k_op_lsl_16_s, 0xf1f8, 0xe148, {6, 6, 4}},
    {&m68k_op_roxl_16_s, 0xf1f8, 0xe150, {6, 6, 12}},
    {&m68k_op_rol_16_s, 0xf1f8, 0xe158, {6, 6, 8}},
    {&m68k_op_asl_16_r, 0xf1f8, 0xe160, {6, 6, 8}},
    {&m68k_op_lsl_16_r, 0xf1f8, 0xe168, {6, 6, 6}},
    {&m68k_op_roxl_16_r, 0xf1f8, 0xe170, {6, 6, 12}},
    {&m68k_op_rol_16_r, 0xf1f8, 0xe178, {6, 6, 8}},
    {&m68k_op_asl_32_s, 0xf1f8, 0xe180, {8, 8, 8}},
    {&m68k_op_lsl_32_s, 0xf1f8, 0xe188, {8, 8, 4}},
    {&m68k_op_roxl_32_s, 0xf1f8, 0xe190, {8, 8, 12}},
    {&m68k_op_rol_32_s, 0xf1f8, 0xe198, {8, 8, 8}},
    {&m68k_op_asl_32_r, 0xf1f8, 0xe1a0, {8, 8, 8}},
    {&m68k_op_lsl_32_r, 0xf1f8, 0xe1a8, {8, 8, 6}},
    {&m68k_op_roxl_32_r, 0xf1f8, 0xe1b0, {8, 8, 12}},
    {&m68k_op_rol_32_r, 0xf1f8, 0xe1b8, {8, 8, 8}},
    {&m68k_op_cpdbcc_32, 0xf1f8, 0xf048, {0, 0, 4}},
    {&m68k_op_cptrapcc_32, 0xf1f8, 0xf078, {0, 0, 4}},
    {&m68k_op_rtm_32, 0xfff0, 0x06c0, {0, 0, 19}},
    {&m68k_op_trap, 0xfff0, 0x4e40, {4, 4, 4}},
    {&m68k_op_btst_8_r_pi7, 0xf1ff, 0x011f, {8, 8, 8}},
    {&m68k_op_btst_8_r_pd7, 0xf1ff, 0x0127, {10, 10, 9}},
    {&m68k_op_btst_8_r_aw, 0xf1ff, 0x0138, {12, 12, 8}},
    {&m68k_op_btst_8_r_al, 0xf1ff, 0x0139, {16, 16, 8}},
    {&m68k_op_btst_8_r_pcdi, 0xf1ff, 0x013a, {12, 12, 9}},
    {&m68k_op_btst_8_r_pcix, 0xf1ff, 0x013b, {14, 14, 11}},
    {&m68k_op_btst_8_r_i, 0xf1ff, 0x013c, {8, 8, 6}},
    {&m68k_op_bchg_8_r_pi7, 0xf1ff, 0x015f, {12, 12, 8}},
    {&m68k_op_bchg_8_r_pd7, 0xf1ff, 0x0167, {14, 14, 9}},
    {&m68k_op_bchg_8_r_aw, 0xf1ff, 0x0178, {16, 16, 8}},
    {&m68k_op_bchg_8_r_al, 0xf1ff, 0x0179, {20, 20, 8}},
    {&m68k_op_bclr_8_r_pi7, 0xf1ff, 0x019f, {12, 14, 8}},
    {&m68k_op_bclr_8_r_pd7, 0xf1ff, 0x01a7, {14, 16, 9}},
    {&m68k_op_bclr_8_r_aw, 0xf1ff, 0x01b8, {16, 18, 8}},
    {&m68k_op_bclr_8_r_al, 0xf1ff, 0x01b9, {20, 22, 8}},
    {&m68k_op_bset_8_r_pi7, 0xf1ff, 0x01df, {12, 12, 8}},
    {&m68k_op_bset_8_r_pd7, 0xf1ff, 0x01e7, {14, 14, 9}},
    {&m68k_op_bset_8_r_aw, 0xf1ff, 0x01f8, {16, 16, 8}},
    {&m68k_op_bset_8_r_al, 0xf1ff, 0x01f9, {20, 20, 8}},
    {&m68k_op_move_8_d_pi7, 0xf1ff, 0x101f, {8, 8, 6}},
    {&m68k_op_move_8_d_pd7, 0xf1ff, 0x1027, {10, 10, 7}},
    {&m68k_op_move_8_d_aw, 0xf1ff, 0x1038, {12, 12, 6}},
    {&m68k_op_move_8_d_al, 0xf1ff, 0x1039, {16, 16, 6}},
    {&m68k_op_move_8_d_pcdi, 0xf1ff, 0x103a, {12, 12, 7}},
    {&m68k_op_move_8_d_pcix, 0xf1ff, 0x103b, {14, 14, 9}},
    {&m68k_op_move_8_d_i, 0xf1ff, 0x103c, {8, 8, 4}},
    {&m68k_op_move_8_ai_pi7, 0xf1ff, 0x109f, {12, 12, 8}},
    {&m68k_op_move_8_ai_pd7, 0xf1ff, 0x10a7, {14, 14, 9}},
    {&m68k_op_move_8_ai_aw, 0xf1ff, 0x10b8, {16, 16, 8}},
    {&m68k_op_move_8_ai_al, 0xf1ff, 0x10b9, {20, 20, 8}},
    {&m68k_op_move_8_ai_pcdi, 0xf1ff, 0x10ba, {16, 16, 9}},
    {&m68k_op_move_8_ai_pcix, 0xf1ff, 0x10bb, {18, 18, 11}},
    {&m68k_op_move_8_ai_i, 0xf1ff, 0x10bc, {12, 12, 6}},
    {&m68k_op_move_8_pi_pi7, 0xf1ff, 0x10df, {12, 12, 8}},
    {&m68k_op_move_8_pi_pd7, 0xf1ff, 0x10e7, {14, 14, 9}},
    {&m68k_op_move_8_pi_aw, 0xf1ff, 0x10f8, {16, 16, 8}},
    {&m68k_op_move_8_pi_al, 0xf1ff, 0x10f9, {20, 20, 8}},
    {&m68k_op_move_8_pi_pcdi, 0xf1ff, 0x10fa, {16, 16, 9}},
    {&m68k_op_move_8_pi_pcix, 0xf1ff, 0x10fb, {18, 18, 11}},
    {&m68k_op_move_8_pi_i, 0xf1ff, 0x10fc, {12, 12, 6}},
    {&m68k_op_move_8_pd_pi7, 0xf1ff, 0x111f, {12, 12, 9}},
    {&m68k_op_move_8_pd_pd7, 0xf1ff, 0x1127, {14, 14, 10}},
    {&m68k_op_move_8_pd_aw, 0xf1ff, 0x1138, {16, 16, 9}},
    {&m68k_op_move_8_pd_al, 0xf1ff, 0x1139, {20, 20, 9}},
    {&m68k_op_move_8_pd_pcdi, 0xf1ff, 0x113a, {16, 16, 10}},
    {&m68k_op_move_8_pd_pcix, 0xf1ff, 0x113b, {18, 18, 12}},
    {&m68k_op_move_8_pd_i, 0xf1ff, 0x113c, {12, 12, 7}},
    {&m68k_op_move_8_di_pi7, 0xf1ff, 0x115f, {16, 16, 9}},
    {&m68k_op_move_8_di_pd7, 0xf1ff, 0x1167, {18, 18, 10}},
    {&m68k_op_move_8_di_aw, 0xf1ff, 0x1178, {20, 20, 9}},
    {&m68k_op_move_8_di_al, 0xf1ff, 0x1179, {24, 24, 9}},
    {&m68k_op_move_8_di_pcdi, 0xf1ff, 0x117a, {20, 20, 10}},
    {&m68k_op_move_8_di_pcix, 0xf1ff, 0x117b, {22, 22, 12}},
    {&m68k_op_move_8_di_i, 0xf1ff, 0x117c, {16, 16, 7}},
    {&m68k_op_move_8_ix_pi7, 0xf1ff, 0x119f, {18, 18, 11}},
    {&m68k_op_move_8_ix_pd7, 0xf1ff, 0x11a7, {20, 20, 12}},
    {&m68k_op_move_8_ix_aw, 0xf1ff, 0x11b8, {22, 22, 11}},
    {&m68k_op_move_8_ix_al, 0xf1ff, 0x11b9, {26, 26, 11}},
    {&m68k_op_move_8_ix_pcdi, 0xf1ff, 0x11ba, {22, 22, 12}},
    {&m68k_op_move_8_ix_pcix, 0xf1ff, 0x11bb, {24, 24, 14}},
    {&m68k_op_move_8_ix_i, 0xf1ff, 0x11bc, {18, 18, 9}},
    {&m68k_op_move_32_d_aw, 0xf1ff, 0x2038, {16, 16, 6}},
    {&m68k_op_move_32_d_al, 0xf1ff, 0x2039, {20, 20, 6}},
    {&m68k_op_move_32_d_pcdi, 0xf1ff, 0x203a, {16, 16, 7}},
    {&m68k_op_move_32_d_pcix, 0xf1ff, 0x203b, {18, 18, 9}},
    {&m68k_op_move_32_d_i, 0xf1ff, 0x203c, {12, 12, 6}},
    {&m68k_op_movea_32_aw, 0xf1ff, 0x2078, {16, 16, 6}},
    {&m68k_op_movea_32_al, 0xf1ff, 0x2079, {20, 20, 6}},
    {&m68k_op_movea_32_pcdi, 0xf1ff, 0x207a, {16, 16, 7}},
    {&m68k_op_movea_32_pcix, 0xf1ff, 0x207b, {18, 18, 9}},
    {&m68k_op_movea_32_i, 0xf1ff, 0x207c, {12, 12, 6}},
    {&m68k_op_move_32_ai_aw, 0xf1ff, 0x20b8, {24, 24, 8}},
    {&m68k_op_move_32_ai_al, 0xf1ff, 0x20b9, {28, 28, 8}},
    {&m68k_op_move_32_ai_pcdi, 0xf1ff, 0x20ba, {24, 24, 9}},
    {&m68k_op_move_32_ai_pcix, 0xf1ff, 0x20bb, {26, 26, 11}},
    {&m68k_op_move_32_ai_i, 0xf1ff, 0x20bc, {20, 20, 8}},
    {&m68k_op_move_32_pi_aw, 0xf1ff, 0x20f8, {24, 24, 8}},
    {&m68k_op_move_32_pi_al, 0xf1ff, 0x20f9, {28, 28, 8}},
    {&m68k_op_move_32_pi_pcdi, 0xf1ff, 0x20fa, {24, 24, 9}},
    {&m68k_op_move_32_pi_pcix, 0xf1ff, 0x20fb, {26, 26, 11}},
    {&m68k_op_move_32_pi_i, 0xf1ff, 0x20fc, {20, 20, 8}},
    {&m68k_op_move_32_pd_aw, 0xf1ff, 0x2138, {24, 26, 9}},
    {&m68k_op_move_32_pd_al, 0xf1ff, 0x2139, {28, 30, 9}},
    {&m68k_op_move_32_pd_pcdi, 0xf1ff, 0x213a, {24, 26, 10}},
    {&m68k_op_move_32_pd_pcix, 0xf1ff, 0x213b, {26, 28, 12}},
    {&m68k_op_move_32_pd_i, 0xf1ff, 0x213c, {20, 22, 9}},
    {&m68k_op_move_32_di_aw, 0xf1ff, 0x2178, {28, 28, 9}},
    {&m68k_op_move_32_di_al, 0xf1ff, 0x2179, {32, 32, 9}},
    {&m68k_op_move_32_di_pcdi, 0xf1ff, 0x217a, {28, 28, 10}},
    {&m68k_op_move_32_di_pcix, 0xf1ff, 0x217b, {30, 30, 12}},
    {&m68k_op_move_32_di_i, 0xf1ff, 0x217c, {24, 24, 9}},
    {&m68k_op_move_32_ix_aw, 0xf1ff, 0x21b8, {30, 30, 11}},
    {&m68k_op_move_32_ix_al, 0xf1ff, 0x21b9, {34, 34, 11}},
    {&m68k_op_move_32_ix_pcdi, 0xf1ff, 0x21ba, {30, 30, 12}},
    {&m68k_op_move_32_ix_pcix, 0xf1ff, 0x21bb, {32, 32, 14}},
    {&m68k_op_move_32_ix_i, 0xf1ff, 0x21bc, {26, 26, 11}},
    {&m68k_op_move_16_d_aw, 0xf1ff, 0x3038, {12, 12, 6}},
    {&m68k_op_move_16_d_al, 0xf1ff, 0x3039, {16, 16, 6}},
    {&m68k_op_move_16_d_pcdi, 0xf1ff, 0x303a, {12, 12, 7}},
    {&m68k_op_move_16_d_pcix, 0xf1ff, 0x303b, {14, 14, 9}},
    {&m68k_op_move_16_d_i, 0xf1ff, 0x303c, {8, 8, 4}},
    {&m68k_op_movea_16_aw, 0xf1ff, 0x3078, {12, 12, 6}},
    {&m68k_op_movea_16_al, 0xf1ff, 0x3079, {16, 16, 6}},
    {&m68k_op_movea_16_pcdi, 0xf1ff, 0x307a, {12, 12, 7}},
    {&m68k_op_movea_16_pcix, 0xf1ff, 0x307b, {14, 14, 9}},
    {&m68k_op_movea_16_i, 0xf1ff, 0x307c, {8, 8, 4}},
    {&m68k_op_move_16_ai_aw, 0xf1ff, 0x30b8, {16, 16, 8}},
    {&m68k_op_move_16_ai_al, 0xf1ff, 0x30b9, {20, 20, 8}},
    {&m68k_op_move_16_ai_pcdi, 0xf1ff, 0x30ba, {16, 16, 9}},
    {&m68k_op_move_16_ai_pcix, 0xf1ff, 0x30bb, {18, 18, 11}},
    {&m68k_op_move_16_ai_i, 0xf1ff, 0x30bc, {12, 12, 6}},
    {&m68k_op_move_16_pi_aw, 0xf1ff, 0x30f8, {16, 16, 8}},
    {&m68k_op_move_16_pi_al, 0xf1ff, 0x30f9, {20, 20, 8}},
    {&m68k_op_move_16_pi_pcdi, 0xf1ff, 0x30fa, {16, 16, 9}},
    {&m68k_op_move_16_pi_pcix, 0xf1ff, 0x30fb, {18, 18, 11}},
    {&m68k_op_move_16_pi_i, 0xf1ff, 0x30fc, {12, 12, 6}},
    {&m68k_op_move_16_pd_aw, 0xf1ff, 0x3138, {16, 16, 9}},
    {&m68k_op_move_16_pd_al, 0xf1ff, 0x3139, {20, 20, 9}},
    {&m68k_op_move_16_pd_pcdi, 0xf1ff, 0x313a, {16, 16, 10}},
    {&m68k_op_move_16_pd_pcix, 0xf1ff, 0x313b, {18, 18, 12}},
    {&m68k_op_move_16_pd_i, 0xf1ff, 0x313c, {12, 12, 7}},
    {&m68k_op_move_16_di_aw, 0xf1ff, 0x3178, {20, 20, 9}},
    {&m68k_op_move_16_di_al, 0xf1ff, 0x3179, {24, 24, 9}},
    {&m68k_op_move_16_di_pcdi, 0xf1ff, 0x317a, {20, 20, 10}},
    {&m68k_op_move_16_di_pcix, 0xf1ff, 0x317b, {22, 22, 12}},
    {&m68k_op_move_16_di_i, 0xf1ff, 0x317c, {16, 16, 7}},
    {&m68k_op_move_16_ix_aw, 0xf1ff, 0x31b8, {22, 22, 11}},
    {&m68k_op_move_16_ix_al, 0xf1ff, 0x31b9, {26, 26, 11}},
    {&m68k_op_move_16_ix_pcdi, 0xf1ff, 0x31ba, {22, 22, 12}},
    {&m68k_op_move_16_ix_pcix, 0xf1ff, 0x31bb, {24, 24, 14}},
    {&m68k_op_move_16_ix_i, 0xf1ff, 0x31bc, {18, 18, 9}},
    {&m68k_op_chk_32_aw, 0xf1ff, 0x4138, {0, 0, 12}},
    {&m68k_op_chk_32_al, 0xf1ff, 0x4139, {0, 0, 12}},
    {&m68k_op_chk_32_pcdi, 0xf1ff, 0x413a, {0, 0, 13}},
    {&m68k_op_chk_32_pcix, 0xf1ff, 0x413b, {0, 0, 15}},
    {&m68k_op_chk_32_i, 0xf1ff, 0x413c, {0, 0, 12}},
    {&m68k_op_chk_16_aw, 0xf1ff, 0x41b8, {18, 16, 12}},
    {&m68k_op_chk_16_al, 0xf1ff, 0x41b9, {22, 20, 12}},
    {&m68k_op_chk_16_pcdi, 0xf1ff, 0x41ba, {18, 16, 13}},
    {&m68k_op_chk_16_pcix, 0xf1ff, 0x41bb, {20, 18, 15}},
    {&m68k_op_chk_16_i, 0xf1ff, 0x41bc, {14, 12, 10}},
    {&m68k_op_lea_32_aw, 0xf1ff, 0x41f8, {8, 8, 6}},
    {&m68k_op_lea_32_al, 0xf1ff, 0x41f9, {12, 12, 6}},
    {&m68k_op_lea_32_pcdi, 0xf1ff, 0x41fa, {8, 8, 7}},
    {&m68k_op_lea_32_pcix, 0xf1ff, 0x41fb, {12, 12, 9}},
    {&m68k_op_addq_8_pi7, 0xf1ff, 0x501f, {12, 12, 8}},
    {&m68k_op_addq_8_pd7, 0xf1ff, 0x5027, {14, 14, 9}},
    {&m68k_op_addq_8_aw, 0xf1ff, 0x5038, {16, 16, 8}},
    {&m68k_op_addq_8_al, 0xf1ff, 0x5039, {20, 20, 8}},
    {&m68k_op_addq_16_aw, 0xf1ff, 0x5078, {16, 16, 8}},
    {&m68k_op_addq_16_al, 0xf1ff, 0x5079, {20, 20, 8}},
    {&m68k_op_addq_32_aw, 0xf1ff, 0x50b8, {24, 24, 8}},
    {&m68k_op_addq_32_al, 0xf1ff, 0x50b9, {28, 28, 8}},
    {&m68k_op_subq_8_pi7, 0xf1ff, 0x511f, {12, 12, 8}},
    {&m68k_op_subq_8_pd7, 0xf1ff, 0x5127, {14, 14, 9}},
    {&m68k_op_subq_8_aw, 0xf1ff, 0x5138, {16, 16, 8}},
    {&m68k_op_subq_8_al, 0xf1ff, 0x5139, {20, 20, 8}},
    {&m68k_op_subq_16_aw, 0xf1ff, 0x5178, {16, 16, 8}},
    {&m68k_op_subq_16_al, 0xf1ff, 0x5179, {20, 20, 8}},
    {&m68k_op_subq_32_aw, 0xf1ff, 0x51b8, {24, 24, 8}},
    {&m68k_op_subq_32_al, 0xf1ff, 0x51b9, {28, 28, 8}},
    {&m68k_op_or_8_er_pi7, 0xf1ff, 0x801f, {8, 8, 6}},
    {&m68k_op_or_8_er_pd7, 0xf1ff, 0x8027, {10, 10, 7}},
    {&m68k_op_or_8_er_aw, 0xf1ff, 0x8038, {12, 12, 6}},
    {&m68k_op_or_8_er_al, 0xf1ff, 0x8039, {16, 16, 6}},
    {&m68k_op_or_8_er_pcdi, 0xf1ff, 0x803a, {12, 12, 7}},
    {&m68k_op_or_8_er_pcix, 0xf1ff, 0x803b, {14, 14, 9}},
    {&m68k_op_or_8_er_i, 0xf1ff, 0x803c, {10, 8, 4}},
    {&m68k_op_or_16_er_aw, 0xf1ff, 0x8078, {12, 12, 6}},
    {&m68k_op_or_16_er_al, 0xf1ff, 0x8079, {16, 16, 6}},
    {&m68k_op_or_16_er_pcdi, 0xf1ff, 0x807a, {12, 12, 7}},
    {&m68k_op_or_16_er_pcix, 0xf1ff, 0x807b, {14, 14, 9}},
    {&m68k_op_or_16_er_i, 0xf1ff, 0x807c, {10, 8, 4}},
    {&m68k_op_or_32_er_aw, 0xf1ff, 0x80b8, {18, 18, 6}},
    {&m68k_op_or_32_er_al, 0xf1ff, 0x80b9, {22, 22, 6}},
    {&m68k_op_or_32_er_pcdi, 0xf1ff, 0x80ba, {18, 18, 7}},
    {&m68k_op_or_32_er_pcix, 0xf1ff, 0x80bb, {20, 20, 9}},
    {&m68k_op_or_32_er_i, 0xf1ff, 0x80bc, {16, 14, 6}},
    {&m68k_op_divu_16_aw, 0xf1ff, 0x80f8, {148, 116, 48}},
    {&m68k_op_divu_16_al, 0xf1ff, 0x80f9, {152, 120, 48}},
    {&m68k_op_divu_16_pcdi, 0xf1ff, 0x80fa, {148, 116, 49}},
    {&m68k_op_divu_16_pcix, 0xf1ff, 0x80fb, {150, 118, 51}},
    {&m68k_op_divu_16_i, 0xf1ff, 0x80fc, {144, 112, 46}},
    {&m68k_op_sbcd_8_mm_ay7, 0xf1ff, 0x810f, {18, 18, 16}},
    {&m68k_op_or_8_re_pi7, 0xf1ff, 0x811f, {12, 12, 8}},
    {&m68k_op_or_8_re_pd7, 0xf1ff, 0x8127, {14, 14, 9}},
    {&m68k_op_or_8_re_aw, 0xf1ff, 0x8138, {16, 16, 8}},
    {&m68k_op_or_8_re_al, 0xf1ff, 0x8139, {20, 20, 8}},
    {&m68k_op_pack_16_mm_ay7, 0xf1ff, 0x814f, {0, 0, 13}},
    {&m68k_op_or_16_re_aw, 0xf1ff, 0x8178, {16, 16, 8}},
    {&m68k_op_or_16_re_al, 0xf1ff, 0x8179, {20, 20, 8}},
    {&m68k_op_unpk_16_mm_ay7, 0xf1ff, 0x818f, {0, 0, 13}},
    {&m68k_op_or_32_re_aw, 0xf1ff, 0x81b8, {24, 24, 8}},
    {&m68k_op_or_32_re_al, 0xf1ff, 0x81b9, {28, 28, 8}},
    {&m68k_op_divs_16_aw, 0xf1ff, 0x81f8, {166, 130, 60}},
    {&m68k_op_divs_16_al, 0xf1ff, 0x81f9, {170, 134, 60}},
    {&m68k_op_divs_16_pcdi, 0xf1ff, 0x81fa, {166, 130, 61}},
    {&m68k_op_divs_16_pcix, 0xf1ff, 0x81fb, {168, 132, 63}},
    {&m68k_op_divs_16_i, 0xf1ff, 0x81fc, {162, 126, 58}},
    {&m68k_op_sub_8_er_pi7, 0xf1ff, 0x901f, {8, 8, 6}},
    {&m68k_op_sub_8_er_pd7, 0xf1ff, 0x9027, {10, 10, 7}},
    {&m68k_op_sub_8_er_aw, 0xf1ff, 0x9038, {12, 12, 6}},
    {&m68k_op_sub_8_er_al, 0xf1ff, 0x9039, {16, 16, 6}},
    {&m68k_op_sub_8_er_pcdi, 0xf1ff, 0x903a, {12, 12, 7}},
    {&m68k_op_sub_8_er_pcix, 0xf1ff, 0x903b, {14, 14, 9}},
    {&m68k_op_sub_8_er_i, 0xf1ff, 0x903c, {10, 8, 4}},
    {&m68k_op_sub_16_er_aw, 0xf1ff, 0x9078, {12, 12, 6}},
    {&m68k_op_sub_16_er_al, 0xf1ff, 0x9079, {16, 16, 6}},
    {&m68k_op_sub_16_er_pcdi, 0xf1ff, 0x907a, {12, 12, 7}},
    {&m68k_op_sub_16_er_pcix, 0xf1ff, 0x907b, {14, 14, 9}},
    {&m68k_op_sub_16_er_i, 0xf1ff, 0x907c, {10, 8, 4}},
    {&m68k_op_sub_32_er_aw, 0xf1ff, 0x90b8, {18, 18, 6}},
    {&m68k_op_sub_32_er_al, 0xf1ff, 0x90b9, {22, 22, 6}},
    {&m68k_op_sub_32_er_pcdi, 0xf1ff, 0x90ba, {18, 18, 7}},
    {&m68k_op_sub_32_er_pcix, 0xf1ff, 0x90bb, {20, 20, 9}},
    {&m68k_op_sub_32_er_i, 0xf1ff, 0x90bc, {16, 14, 6}},
    {&m68k_op_suba_16_aw, 0xf1ff, 0x90f8, {16, 16, 6}},
    {&m68k_op_suba_16_al, 0xf1ff, 0x90f9, {20, 20, 6}},
    {&m68k_op_suba_16_pcdi, 0xf1ff, 0x90fa, {16, 16, 7}},
    {&m68k_op_suba_16_pcix, 0xf1ff, 0x90fb, {18, 18, 9}},
    {&m68k_op_suba_16_i, 0xf1ff, 0x90fc, {14, 12, 4}},
    {&m68k_op_subx_8_mm_ay7, 0xf1ff, 0x910f, {18, 18, 12}},
    {&m68k_op_sub_8_re_pi7, 0xf1ff, 0x911f, {12, 12, 8}},
    {&m68k_op_sub_8_re_pd7, 0xf1ff, 0x9127, {14, 14, 9}},
    {&m68k_op_sub_8_re_aw, 0xf1ff, 0x9138, {16, 16, 8}},
    {&m68k_op_sub_8_re_al, 0xf1ff, 0x9139, {20, 20, 8}},
    {&m68k_op_sub_16_re_aw, 0xf1ff, 0x9178, {16, 16, 8}},
    {&m68k_op_sub_16_re_al, 0xf1ff, 0x9179, {20, 20, 8}},
    {&m68k_op_sub_32_re_aw, 0xf1ff, 0x91b8, {24, 24, 8}},
    {&m68k_op_sub_32_re_al, 0xf1ff, 0x91b9, {28, 28, 8}},
    {&m68k_op_suba_32_aw, 0xf1ff, 0x91f8, {18, 18, 6}},
    {&m68k_op_suba_32_al, 0xf1ff, 0x91f9, {22, 22, 6}},
    {&m68k_op_suba_32_pcdi, 0xf1ff, 0x91fa, {18, 18, 7}},
    {&m68k_op_suba_32_pcix, 0xf1ff, 0x91fb, {20, 20, 9}},
    {&m68k_op_suba_32_i, 0xf1ff, 0x91fc, {16, 14, 6}},
    {&m68k_op_cmp_8_pi7, 0xf1ff, 0xb01f, {8, 8, 6}},
    {&m68k_op_cmp_8_pd7, 0xf1ff, 0xb027, {10, 10, 7}},
    {&m68k_op_cmp_8_aw, 0xf1ff, 0xb038, {12, 12, 6}},
    {&m68k_op_cmp_8_al, 0xf1ff, 0xb039, {16, 16, 6}},
    {&m68k_op_cmp_8_pcdi, 0xf1ff, 0xb03a, {12, 12, 7}},
    {&m68k_op_cmp_8_pcix, 0xf1ff, 0xb03b, {14, 14, 9}},
    {&m68k_op_cmp_8_i, 0xf1ff, 0xb03c, {8, 8, 4}},
    {&m68k_op_cmp_16_aw, 0xf1ff, 0xb078, {12, 12, 6}},
    {&m68k_op_cmp_16_al, 0xf1ff, 0xb079, {16, 16, 6}},
    {&m68k_op_cmp_16_pcdi, 0xf1ff, 0xb07a, {12, 12, 7}},
    {&m68k_op_cmp_16_pcix, 0xf1ff, 0xb07b, {14, 14, 9}},
    {&m68k_op_cmp_16_i, 0xf1ff, 0xb07c, {8, 8, 4}},
    {&m68k_op_cmp_32_aw, 0xf1ff, 0xb0b8, {18, 18, 6}},
    {&m68k_op_cmp_32_al, 0xf1ff, 0xb0b9, {22, 22, 6}},
    {&m68k_op_cmp_32_pcdi, 0xf1ff, 0xb0ba, {18, 18, 7}},
    {&m68k_op_cmp_32_pcix, 0xf1ff, 0xb0bb, {20, 20, 9}},
    {&m68k_op_cmp_32_i, 0xf1ff, 0xb0bc, {14, 14, 6}},
    {&m68k_op_cmpa_16_aw, 0xf1ff, 0xb0f8, {14, 14, 8}},
    {&m68k_op_cmpa_16_al, 0xf1ff, 0xb0f9, {18, 18, 8}},
    {&m68k_op_cmpa_16_pcdi, 0xf1ff, 0xb0fa, {14, 14, 9}},
    {&m68k_op_cmpa_16_pcix, 0xf1ff, 0xb0fb, {16, 16, 11}},
    {&m68k_op_cmpa_16_i, 0xf1ff, 0xb0fc, {10, 10, 6}},
    {&m68k_op_cmpm_8_ay7, 0xf1ff, 0xb10f, {12, 12, 9}},
    {&m68k_op_eor_8_pi7, 0xf1ff, 0xb11f, {12, 12, 8}},
    {&m68k_op_eor_8_pd7, 0xf1ff, 0xb127, {14, 14, 9}},
    {&m68k_op_eor_8_aw, 0xf1ff, 0xb138, {16, 16, 8}},
    {&m68k_op_eor_8_al, 0xf1ff, 0xb139, {20, 20, 8}},
    {&m68k_op_eor_16_aw, 0xf1ff, 0xb178, {16, 16, 8}},
    {&m68k_op_eor_16_al, 0xf1ff, 0xb179, {20, 20, 8}},
    {&m68k_op_eor_32_aw, 0xf1ff, 0xb1b8, {24, 24, 8}},
    {&m68k_op_eor_32_al, 0xf1ff, 0xb1b9, {28, 28, 8}},
    {&m68k_op_cmpa_32_aw, 0xf1ff, 0xb1f8, {18, 18, 8}},
    {&m68k_op_cmpa_32_al, 0xf1ff, 0xb1f9, {22, 22, 8}},
    {&m68k_op_cmpa_32_pcdi, 0xf1ff, 0xb1fa, {18, 18, 9}},
    {&m68k_op_cmpa_32_pcix, 0xf1ff, 0xb1fb, {20, 20, 11}},
    {&m68k_op_cmpa_32_i, 0xf1ff, 0xb1fc, {14, 14, 8}},
    {&m68k_op_and_8_er_pi7, 0xf1ff, 0xc01f, {8, 8, 6}},
    {&m68k_op_and_8_er_pd7, 0xf1ff, 0xc027, {10, 10, 7}},
    {&m68k_op_and_8_er_aw, 0xf1ff, 0xc038, {12, 12, 6}},
    {&m68k_op_and_8_er_al, 0xf1ff, 0xc039, {16, 16, 6}},
    {&m68k_op_and_8_er_pcdi, 0xf1ff, 0xc03a, {12, 12, 7}},
    {&m68k_op_and_8_er_pcix, 0xf1ff, 0xc03b, {14, 14, 9}},
    {&m68k_op_and_8_er_i, 0xf1ff, 0xc03c, {10, 8, 4}},
    {&m68k_op_and_16_er_aw, 0xf1ff, 0xc078, {12, 12, 6}},
    {&m68k_op_and_16_er_al, 0xf1ff, 0xc079, {16, 16, 6}},
    {&m68k_op_and_16_er_pcdi, 0xf1ff, 0xc07a, {12, 12, 7}},
    {&m68k_op_and_16_er_pcix, 0xf1ff, 0xc07b, {14, 14, 9}},
    {&m68k_op_and_16_er_i, 0xf1ff, 0xc07c, {10, 8, 4}},
    {&m68k_op_and_32_er_aw, 0xf1ff, 0xc0b8, {18, 18, 6}},
    {&m68k_op_and_32_er_al, 0xf1ff, 0xc0b9, {22, 22, 6}},
    {&m68k_op_and_32_er_pcdi, 0xf1ff, 0xc0ba, {18, 18, 7}},
    {&m68k_op_and_32_er_pcix, 0xf1ff, 0xc0bb, {20, 20, 9}},
    {&m68k_op_and_32_er_i, 0xf1ff, 0xc0bc, {16, 14, 6}},
    {&m68k_op_mulu_16_aw, 0xf1ff, 0xc0f8, {62, 38, 31}},
    {&m68k_op_mulu_16_al, 0xf1ff, 0xc0f9, {66, 42, 31}},
    {&m68k_op_mulu_16_pcdi, 0xf1ff, 0xc0fa, {62, 38, 32}},
    {&m68k_op_mulu_16_pcix, 0xf1ff, 0xc0fb, {64, 40, 34}},
    {&m68k_op_mulu_16_i, 0xf1ff, 0xc0fc, {58, 34, 29}},
    {&m68k_op_abcd_8_mm_ay7, 0xf1ff, 0xc10f, {18, 18, 16}},
    {&m68k_op_and_8_re_pi7, 0xf1ff, 0xc11f, {12, 12, 8}},
    {&m68k_op_and_8_re_pd7, 0xf1ff, 0xc127, {14, 14, 9}},
    {&m68k_op_and_8_re_aw, 0xf1ff, 0xc138, {16, 16, 8}},
    {&m68k_op_and_8_re_al, 0xf1ff, 0xc139, {20, 20, 8}},
    {&m68k_op_and_16_re_aw, 0xf1ff, 0xc178, {16, 16, 8}},
    {&m68k_op_and_16_re_al, 0xf1ff, 0xc179, {20, 20, 8}},
    {&m68k_op_and_32_re_aw, 0xf1ff, 0xc1b8, {24, 24, 8}},
    {&m68k_op_and_32_re_al, 0xf1ff, 0xc1b9, {28, 28, 8}},
    {&m68k_op_muls_16_aw, 0xf1ff, 0xc1f8, {62, 40, 31}},
    {&m68k_op_muls_16_al, 0xf1ff, 0xc1f9, {66, 44, 31}},
    {&m68k_op_muls_16_pcdi, 0xf1ff, 0xc1fa, {62, 40, 32}},
    {&m68k_op_muls_16_pcix, 0xf1ff, 0xc1fb, {64, 42, 34}},
    {&m68k_op_muls_16_i, 0xf1ff, 0xc1fc, {58, 36, 29}},
    {&m68k_op_add_8_er_pi7, 0xf1ff, 0xd01f, {8, 8, 6}},
    {&m68k_op_add_8_er_pd7, 0xf1ff, 0xd027, {10, 10, 7}},
    {&m68k_op_add_8_er_aw, 0xf1ff, 0xd038, {12, 12, 6}},
    {&m68k_op_add_8_er_al, 0xf1ff, 0xd039, {16, 16, 6}},
    {&m68k_op_add_8_er_pcdi, 0xf1ff, 0xd03a, {12, 12, 7}},
    {&m68k_op_add_8_er_pcix, 0xf1ff, 0xd03b, {14, 14, 9}},
    {&m68k_op_add_8_er_i, 0xf1ff, 0xd03c, {10, 8, 4}},
    {&m68k_op_add_16_er_aw, 0xf1ff, 0xd078, {12, 12, 6}},
    {&m68k_op_add_16_er_al, 0xf1ff, 0xd079, {16, 16, 6}},
    {&m68k_op_add_16_er_pcdi, 0xf1ff, 0xd07a, {12, 12, 7}},
    {&m68k_op_add_16_er_pcix, 0xf1ff, 0xd07b, {14, 14, 9}},
    {&m68k_op_add_16_er_i, 0xf1ff, 0xd07c, {10, 8, 4}},
    {&m68k_op_add_32_er_aw, 0xf1ff, 0xd0b8, {18, 18, 6}},
    {&m68k_op_add_32_er_al, 0xf1ff, 0xd0b9, {22, 22, 6}},
    {&m68k_op_add_32_er_pcdi, 0xf1ff, 0xd0ba, {18, 18, 7}},
    {&m68k_op_add_32_er_pcix, 0xf1ff, 0xd0bb, {20, 20, 9}},
    {&m68k_op_add_32_er_i, 0xf1ff, 0xd0bc, {16, 14, 6}},
    {&m68k_op_adda_16_aw, 0xf1ff, 0xd0f8, {16, 16, 6}},
    {&m68k_op_adda_16_al, 0xf1ff, 0xd0f9, {20, 20, 6}},
    {&m68k_op_adda_16_pcdi, 0xf1ff, 0xd0fa, {16, 16, 7}},
    {&m68k_op_adda_16_pcix, 0xf1ff, 0xd0fb, {18, 18, 9}},
    {&m68k_op_adda_16_i, 0xf1ff, 0xd0fc, {14, 12, 4}},
    {&m68k_op_addx_8_mm_ay7, 0xf1ff, 0xd10f, {18, 18, 12}},
    {&m68k_op_add_8_re_pi7, 0xf1ff, 0xd11f, {12, 12, 8}},
    {&m68k_op_add_8_re_pd7, 0xf1ff, 0xd127, {14, 14, 9}},
    {&m68k_op_add_8_re_aw, 0xf1ff, 0xd138, {16, 16, 8}},
    {&m68k_op_add_8_re_al, 0xf1ff, 0xd139, {20, 20, 8}},
    {&m68k_op_add_16_re_aw, 0xf1ff, 0xd178, {16, 16, 8}},
    {&m68k_op_add_16_re_al, 0xf1ff, 0xd179, {20, 20, 8}},
    {&m68k_op_add_32_re_aw, 0xf1ff, 0xd1b8, {24, 24, 8}},
    {&m68k_op_add_32_re_al, 0xf1ff, 0xd1b9, {28, 28, 8}},
    {&m68k_op_adda_32_aw, 0xf1ff, 0xd1f8, {18, 18, 6}},
    {&m68k_op_adda_32_al, 0xf1ff, 0xd1f9, {22, 22, 6}},
    {&m68k_op_adda_32_pcdi, 0xf1ff, 0xd1fa, {18, 18, 7}},
    {&m68k_op_adda_32_pcix, 0xf1ff, 0xd1fb, {20, 20, 9}},
    {&m68k_op_adda_32_i, 0xf1ff, 0xd1fc, {16, 14, 6}},
    {&m68k_op_ori_8_d, 0xfff8, 0x0000, {8, 8, 2}},
    {&m68k_op_ori_8_ai, 0xfff8, 0x0010, {16, 16, 8}},
    {&m68k_op_ori_8_pi, 0xfff8, 0x0018, {16, 16, 8}},
    {&m68k_op_ori_8_pd, 0xfff8, 0x0020, {18, 18, 9}},
    {&m68k_op_ori_8_di, 0xfff8, 0x0028, {20, 20, 9}},
    {&m68k_op_ori_8_ix, 0xfff8, 0x0030, {22, 22, 11}},
    {&m68k_op_ori_16_d, 0xfff8, 0x0040, {8, 8, 2}},
    {&m68k_op_ori_16_ai, 0xfff8, 0x0050, {16, 16, 8}},
    {&m68k_op_ori_16_pi, 0xfff8, 0x0058, {16, 16, 8}},
    {&m68k_op_ori_16_pd, 0xfff8, 0x0060, {18, 18, 9}},
    {&m68k_op_ori_16_di, 0xfff8, 0x0068, {20, 20, 9}},
    {&m68k_op_ori_16_ix, 0xfff8, 0x0070, {22, 22, 11}},
    {&m68k_op_ori_32_d, 0xfff8, 0x0080, {16, 14, 2}},
    {&m68k_op_ori_32_ai, 0xfff8, 0x0090, {28, 28, 8}},
    {&m68k_op_ori_32_pi, 0xfff8, 0x0098, {28, 28, 8}},
    {&m68k_op_ori_32_pd, 0xfff8, 0x00a0, {30, 30, 9}},
    {&m68k_op_ori_32_di, 0xfff8, 0x00a8, {32, 32, 9}},
    {&m68k_op_ori_32_ix, 0xfff8, 0x00b0, {34, 34, 11}},
    {&m68k_op_chk2cmp2_8_ai, 0xfff8, 0x00d0, {0, 0, 22}},
    {&m68k_op_chk2cmp2_8_di, 0xfff8, 0x00e8, {0, 0, 23}},
    {&m68k_op_chk2cmp2_8_ix, 0xfff8, 0x00f0, {0, 0, 25}},
    {&m68k_op_andi_8_d, 0xfff8, 0x0200, {8, 8, 2}},
    {&m68k_op_andi_8_ai, 0xfff8, 0x0210, {16, 16, 8}},
    {&m68k_op_andi_8_pi, 0xfff8, 0x0218, {16, 16, 8}},
    {&m68k_op_andi_8_pd, 0xfff8, 0x0220, {18, 18, 9}},
    {&m68k_op_andi_8_di, 0xfff8, 0x0228, {20, 20, 9}},
    {&m68k_op_andi_8_ix, 0xfff8, 0x0230, {22, 22, 11}},
    {&m68k_op_andi_16_d, 0xfff8, 0x0240, {8, 8, 2}},
    {&m68k_op_andi_16_ai, 0xfff8, 0x0250, {16, 16, 8}},
    {&m68k_op_andi_16_pi, 0xfff8, 0x0258, {16, 16, 8}},
    {&m68k_op_andi_16_pd, 0xfff8, 0x0260, {18, 18, 9}},
    {&m68k_op_andi_16_di, 0xfff8, 0x0268, {20, 20, 9}},
    {&m68k_op_andi_16_ix, 0xfff8, 0x0270, {22, 22, 11}},
    {&m68k_op_andi_32_d, 0xfff8, 0x0280, {14, 14, 2}},
    {&m68k_op_andi_32_ai, 0xfff8, 0x0290, {28, 28, 8}},
    {&m68k_op_andi_32_pi, 0xfff8, 0x0298, {28, 28, 8}},
    {&m68k_op_andi_32_pd, 0xfff8, 0x02a0, {30, 30, 9}},
    {&m68k_op_andi_32_di, 0xfff8, 0x02a8, {32, 32, 9}},
    {&m68k_op_andi_32_ix, 0xfff8, 0x02b0, {34, 34, 11}},
    {&m68k_op_chk2cmp2_16_ai, 0xfff8, 0x02d0, {0, 0, 22}},
    {&m68k_op_chk2cmp2_16_di, 0xfff8, 0x02e8, {0, 0, 23}},
    {&m68k_op_chk2cmp2_16_ix, 0xfff8, 0x02f0, {0, 0, 25}},
    {&m68k_op_subi_8_d, 0xfff8, 0x0400, {8, 8, 2}},
    {&m68k_op_subi_8_ai, 0xfff8, 0x0410, {16, 16, 8}},
    {&m68k_op_subi_8_pi, 0xfff8, 0x0418, {16, 16, 8}},
    {&m68k_op_subi_8_pd, 0xfff8, 0x0420, {18, 18, 9}},
    {&m68k_op_subi_8_di, 0xfff8, 0x0428, {20, 20, 9}},
    {&m68k_op_subi_8_ix, 0xfff8, 0x0430, {22, 22, 11}},
    {&m68k_op_subi_16_d, 0xfff8, 0x0440, {8, 8, 2}},
    {&m68k_op_subi_16_ai, 0xfff8, 0x0450, {16, 16, 8}},
    {&m68k_op_subi_16_pi, 0xfff8, 0x0458, {16, 16, 8}},
    {&m68k_op_subi_16_pd, 0xfff8, 0x0460, {18, 18, 9}},
    {&m68k_op_subi_16_di, 0xfff8, 0x0468, {20, 20, 9}},
    {&m68k_op_subi_16_ix, 0xfff8, 0x0470, {22, 22, 11}},
    {&m68k_op_subi_32_d, 0xfff8, 0x0480, {16, 14, 2}},
    {&m68k_op_subi_32_ai, 0xfff8, 0x0490, {28, 28, 8}},
    {&m68k_op_subi_32_pi, 0xfff8, 0x0498, {28, 28, 8}},
    {&m68k_op_subi_32_pd, 0xfff8, 0x04a0, {30, 30, 9}},
    {&m68k_op_subi_32_di, 0xfff8, 0x04a8, {32, 32, 9}},
    {&m68k_op_subi_32_ix, 0xfff8, 0x04b0, {34, 34, 11}},
    {&m68k_op_chk2cmp2_32_ai, 0xfff8, 0x04d0, {0, 0, 22}},
    {&m68k_op_chk2cmp2_32_di, 0xfff8, 0x04e8, {0, 0, 23}},
    {&m68k_op_chk2cmp2_32_ix, 0xfff8, 0x04f0, {0, 0, 25}},
    {&m68k_op_addi_8_d, 0xfff8, 0x0600, {8, 8, 2}},
    {&m68k_op_addi_8_ai, 0xfff8, 0x0610, {16, 16, 8}},
    {&m68k_op_addi_8_pi, 0xfff8, 0x0618, {16, 16, 8}},
    {&m68k_op_addi_8_pd, 0xfff8, 0x0620, {18, 18, 9}},
    {&m68k_op_addi_8_di, 0xfff8, 0x0628, {20, 20, 9}},
    {&m68k_op_addi_8_ix, 0xfff8, 0x0630, {22, 22, 11}},
    {&m68k_op_addi_16_d, 0xfff8, 0x0640, {8, 8, 2}},
    {&m68k_op_addi_16_ai, 0xfff8, 0x0650, {16, 16, 8}},
    {&m68k_op_addi_16_pi, 0xfff8, 0x0658, {16, 16, 8}},
    {&m68k_op_addi_16_pd, 0xfff8, 0x0660, {18, 18, 9}},
    {&m68k_op_addi_16_di, 0xfff8, 0x0668, {20, 20, 9}},
    {&m68k_op_addi_16_ix, 0xfff8, 0x0670, {22, 22, 11}},
    {&m68k_op_addi_32_d, 0xfff8, 0x0680, {16, 14, 2}},
    {&m68k_op_addi_32_ai, 0xfff8, 0x0690, {28, 28, 8}},
    {&m68k_op_addi_32_pi, 0xfff8, 0x0698, {28, 28, 8}},
    {&m68k_op_addi_32_pd, 0xfff8, 0x06a0, {30, 30, 9}},
    {&m68k_op_addi_32_di, 0xfff8, 0x06a8, {32, 32, 9}},
    {&m68k_op_addi_32_ix, 0xfff8, 0x06b0, {34, 34, 11}},
    {&m68k_op_callm_32_ai, 0xfff8, 0x06d0, {0, 0, 64}},
    {&m68k_op_callm_32_di, 0xfff8, 0x06e8, {0, 0, 65}},
    {&m68k_op_callm_32_ix, 0xfff8, 0x06f0, {0, 0, 67}},
    {&m68k_op_btst_32_s_d, 0xfff8, 0x0800, {10, 10, 4}},
    {&m68k_op_btst_8_s_ai, 0xfff8, 0x0810, {12, 12, 8}},
    {&m68k_op_btst_8_s_pi, 0xfff8, 0x0818, {12, 12, 8}},
    {&m68k_op_btst_8_s_pd, 0xfff8, 0x0820, {14, 14, 9}},
    {&m68k_op_btst_8_s_di, 0xfff8, 0x0828, {16, 16, 9}},
    {&m68k_op_btst_8_s_ix, 0xfff8, 0x0830, {18, 18, 11}},
    {&m68k_op_bchg_32_s_d, 0xfff8, 0x0840, {12, 12, 4}},
    {&m68k_op_bchg_8_s_ai, 0xfff8, 0x0850, {16, 16, 8}},
    {&m68k_op_bchg_8_s_pi, 0xfff8, 0x0858, {16, 16, 8}},
    {&m68k_op_bchg_8_s_pd, 0xfff8, 0x0860, {18, 18, 9}},
    {&m68k_op_bchg_8_s_di, 0xfff8, 0x0868, {20, 20, 9}},
    {&m68k_op_bchg_8_s_ix, 0xfff8, 0x0870, {22, 22, 11}},
    {&m68k_op_bclr_32_s_d, 0xfff8, 0x0880, {14, 14, 4}},
    {&m68k_op_bclr_8_s_ai, 0xfff8, 0x0890, {16, 16, 8}},
    {&m68k_op_bclr_8_s_pi, 0xfff8, 0x0898, {16, 16, 8}},
    {&m68k_op_bclr_8_s_pd, 0xfff8, 0x08a0, {18, 18, 9}},
    {&m68k_op_bclr_8_s_di, 0xfff8, 0x08a8, {20, 20, 9}},
    {&m68k_op_bclr_8_s_ix, 0xfff8, 0x08b0, {22, 22, 11}},
    {&m68k_op_bset_32_s_d, 0xfff8, 0x08c0, {12, 12, 4}},
    {&m68k_op_bset_8_s_ai, 0xfff8, 0x08d0, {16, 16, 8}},
    {&m68k_op_bset_8_s_pi, 0xfff8, 0x08d8, {16, 16, 8}},
    {&m68k_op_bset_8_s_pd, 0xfff8, 0x08e0, {18, 18, 9}},
    {&m68k_op_bset_8_s_di, 0xfff8, 0x08e8, {20, 20, 9}},
    {&m68k_op_bset_8_s_ix, 0xfff8, 0x08f0, {22, 22, 11}},
    {&m68k_op_eori_8_d, 0xfff8, 0x0a00, {8, 8, 2}},
    {&m68k_op_eori_8_ai, 0xfff8, 0x0a10, {16, 16, 8}},
    {&m68k_op_eori_8_pi, 0xfff8, 0x0a18, {16, 16, 8}},
    {&m68k_op_eori_8_pd, 0xfff8, 0x0a20, {18, 18, 9}},
    {&m68k_op_eori_8_di, 0xfff8, 0x0a28, {20, 20, 9}},
    {&m68k_op_eori_8_ix, 0xfff8, 0x0a30, {22, 22, 11}},
    {&m68k_op_eori_16_d, 0xfff8, 0x0a40, {8, 8, 2}},
    {&m68k_op_eori_16_ai, 0xfff8, 0x0a50, {16, 16, 8}},
    {&m68k_op_eori_16_pi, 0xfff8, 0x0a58, {16, 16, 8}},
    {&m68k_op_eori_16_pd, 0xfff8, 0x0a60, {18, 18, 9}},
    {&m68k_op_eori_16_di, 0xfff8, 0x0a68, {20, 20, 9}},
    {&m68k_op_eori_16_ix, 0xfff8, 0x0a70, {22, 22, 11}},
    {&m68k_op_eori_32_d, 0xfff8, 0x0a80, {16, 14, 2}},
    {&m68k_op_eori_32_ai, 0xfff8, 0x0a90, {28, 28, 8}},
    {&m68k_op_eori_32_pi, 0xfff8, 0x0a98, {28, 28, 8}},
    {&m68k_op_eori_32_pd, 0xfff8, 0x0aa0, {30, 30, 9}},
    {&m68k_op_eori_32_di, 0xfff8, 0x0aa8, {32, 32, 9}},
    {&m68k_op_eori_32_ix, 0xfff8, 0x0ab0, {34, 34, 11}},
    {&m68k_op_cas_8_ai, 0xfff8, 0x0ad0, {0, 0, 16}},
    {&m68k_op_cas_8_pi, 0xfff8, 0x0ad8, {0, 0, 16}},
    {&m68k_op_cas_8_pd, 0xfff8, 0x0ae0, {0, 0, 17}},
    {&m68k_op_cas_8_di, 0xfff8, 0x0ae8, {0, 0, 17}},
    {&m68k_op_cas_8_ix, 0xfff8, 0x0af0, {0, 0, 19}},
    {&m68k_op_cmpi_8_d, 0xfff8, 0x0c00, {8, 8, 2}},
    {&m68k_op_cmpi_8_ai, 0xfff8, 0x0c10, {12, 12, 6}},
    {&m68k_op_cmpi_8_pi, 0xfff8, 0x0c18, {12, 12, 6}},
    {&m68k_op_cmpi_8_pd, 0xfff8, 0x0c20, {14, 14, 7}},
    {&m68k_op_cmpi_8_di, 0xfff8, 0x0c28, {16, 16, 7}},
    {&m68k_op_cmpi_8_ix, 0xfff8, 0x0c30, {18, 18, 9}},
    {&m68k_op_cmpi_16_d, 0xfff8, 0x0c40, {8, 8, 2}},
    {&m68k_op_cmpi_16_ai, 0xfff8, 0x0c50, {12, 12, 6}},
    {&m68k_op_cmpi_16_pi, 0xfff8, 0x0c58, {12, 12, 6}},
    {&m68k_op_cmpi_16_pd, 0xfff8, 0x0c60, {14, 14, 7}},
    {&m68k_op_cmpi_16_di, 0xfff8, 0x0c68, {16, 16, 7}},
    {&m68k_op_cmpi_16_ix, 0xfff8, 0x0c70, {18, 18, 9}},
    {&m68k_op_cmpi_32_d, 0xfff8, 0x0c80, {14, 12, 2}},
    {&m68k_op_cmpi_32_ai, 0xfff8, 0x0c90, {20, 20, 6}},
    {&m68k_op_cmpi_32_pi, 0xfff8, 0x0c98, {20, 20, 6}},
    {&m68k_op_cmpi_32_pd, 0xfff8, 0x0ca0, {22, 22, 7}},
    {&m68k_op_cmpi_32_di, 0xfff8, 0x0ca8, {24, 24, 7}},
    {&m68k_op_cmpi_32_ix, 0xfff8, 0x0cb0, {26, 26, 9}},
    {&m68k_op_cas_16_ai, 0xfff8, 0x0cd0, {0, 0, 16}},
    {&m68k_op_cas_16_pi, 0xfff8, 0x0cd8, {0, 0, 16}},
    {&m68k_op_cas_16_pd, 0xfff8, 0x0ce0, {0, 0, 17}},
    {&m68k_op_cas_16_di, 0xfff8, 0x0ce8, {0, 0, 17}},
    {&m68k_op_cas_16_ix, 0xfff8, 0x0cf0, {0, 0, 19}},
    {&m68k_op_moves_8_ai, 0xfff8, 0x0e10, {0, 18, 9}},
    {&m68k_op_moves_8_pi, 0xfff8, 0x0e18, {0, 18, 9}},
    {&m68k_op_moves_8_pd, 0xfff8, 0x0e20, {0, 20, 10}},
    {&m68k_op_moves_8_di, 0xfff8, 0x0e28, {0, 26, 10}},
    {&m68k_op_moves_8_ix, 0xfff8, 0x0e30, {0, 30, 12}},
    {&m68k_op_moves_16_ai, 0xfff8, 0x0e50, {0, 18, 9}},
    {&m68k_op_moves_16_pi, 0xfff8, 0x0e58, {0, 18, 9}},
    {&m68k_op_moves_16_pd, 0xfff8, 0x0e60, {0, 20, 10}},
    {&m68k_op_moves_16_di, 0xfff8, 0x0e68, {0, 26, 10}},
    {&m68k_op_moves_16_ix, 0xfff8, 0x0e70, {0, 30, 12}},
    {&m68k_op_moves_32_ai, 0xfff8, 0x0e90, {0, 22, 9}},
    {&m68k_op_moves_32_pi, 0xfff8, 0x0e98, {0, 22, 9}},
    {&m68k_op_moves_32_pd, 0xfff8, 0x0ea0, {0, 28, 10}},
    {&m68k_op_moves_32_di, 0xfff8, 0x0ea8, {0, 32, 10}},
    {&m68k_op_moves_32_ix, 0xfff8, 0x0eb0, {0, 36, 12}},
    {&m68k_op_cas_32_ai, 0xfff8, 0x0ed0, {0, 0, 16}},
    {&m68k_op_cas_32_pi, 0xfff8, 0x0ed8, {0, 0, 16}},
    {&m68k_op_cas_32_pd, 0xfff8, 0x0ee0, {0, 0, 17}},
    {&m68k_op_cas_32_di, 0xfff8, 0x0ee8, {0, 0, 17}},
    {&m68k_op_cas_32_ix, 0xfff8, 0x0ef0, {0, 0, 19}},
    {&m68k_op_move_8_aw_d, 0xfff8, 0x11c0, {12, 12, 4}},
    {&m68k_op_move_8_aw_ai, 0xfff8, 0x11d0, {16, 16, 8}},
    {&m68k_op_move_8_aw_pi, 0xfff8, 0x11d8, {16, 16, 8}},
    {&m68k_op_move_8_aw_pd, 0xfff8, 0x11e0, {18, 18, 9}},
    {&m68k_op_move_8_aw_di, 0xfff8, 0x11e8, {20, 20, 9}},
    {&m68k_op_move_8_aw_ix, 0xfff8, 0x11f0, {22, 22, 11}},
    {&m68k_op_move_8_al_d, 0xfff8, 0x13c0, {16, 16, 6}},
    {&m68k_op_move_8_al_ai, 0xfff8, 0x13d0, {20, 20, 10}},
    {&m68k_op_move_8_al_pi, 0xfff8, 0x13d8, {20, 20, 10}},
    {&m68k_op_move_8_al_pd, 0xfff8, 0x13e0, {22, 22, 11}},
    {&m68k_op_move_8_al_di, 0xfff8, 0x13e8, {24, 24, 11}},
    {&m68k_op_move_8_al_ix, 0xfff8, 0x13f0, {26, 26, 13}},
    {&m68k_op_move_8_pi7_d, 0xfff8, 0x1ec0, {8, 8, 4}},
    {&m68k_op_move_8_pi7_ai, 0xfff8, 0x1ed0, {12, 12, 8}},
    {&m68k_op_move_8_pi7_pi, 0xfff8, 0x1ed8, {12, 12, 8}},
    {&m68k_op_move_8_pi7_pd, 0xfff8, 0x1ee0, {14, 14, 9}},
    {&m68k_op_move_8_pi7_di, 0xfff8, 0x1ee8, {16, 16, 9}},
    {&m68k_op_move_8_pi7_ix, 0xfff8, 0x1ef0, {18, 18, 11}},
    {&m68k_op_move_8_pd7_d, 0xfff8, 0x1f00, {8, 8, 5}},
    {&m68k_op_move_8_pd7_ai, 0xfff8, 0x1f10, {12, 12, 9}},
    {&m68k_op_move_8_pd7_pi, 0xfff8, 0x1f18, {12, 12, 9}},
    {&m68k_op_move_8_pd7_pd, 0xfff8, 0x1f20, {14, 14, 10}},
    {&m68k_op_move_8_pd7_di, 0xfff8, 0x1f28, {16, 16, 10}},
    {&m68k_op_move_8_pd7_ix, 0xfff8, 0x1f30, {18, 18, 12}},
    {&m68k_op_move_32_aw_d, 0xfff8, 0x21c0, {16, 16, 4}},
    {&m68k_op_move_32_aw_a, 0xfff8, 0x21c8, {16, 16, 4}},
    {&m68k_op_move_32_aw_ai, 0xfff8, 0x21d0, {24, 24, 8}},
    {&m68k_op_move_32_aw_pi, 0xfff8, 0x21d8, {24, 24, 8}},
    {&m68k_op_move_32_aw_pd, 0xfff8, 0x21e0, {26, 26, 9}},
    {&m68k_op_move_32_aw_di, 0xfff8, 0x21e8, {28, 28, 9}},
    {&m68k_op_move_32_aw_ix, 0xfff8, 0x21f0, {30, 30, 11}},
    {&m68k_op_move_32_al_d, 0xfff8, 0x23c0, {20, 20, 6}},
    {&m68k_op_move_32_al_a, 0xfff8, 0x23c8, {20, 20, 6}},
    {&m68k_op_move_32_al_ai, 0xfff8, 0x23d0, {28, 28, 10}},
    {&m68k_op_move_32_al_pi, 0xfff8, 0x23d8, {28, 28, 10}},
    {&m68k_op_move_32_al_pd, 0xfff8, 0x23e0, {30, 30, 11}},
    {&m68k_op_move_32_al_di, 0xfff8, 0x23e8, {32, 32, 11}},
    {&m68k_op_move_32_al_ix, 0xfff8, 0x23f0, {34, 34, 13}},
    {&m68k_op_move_16_aw_d, 0xfff8, 0x31c0, {12, 12, 4}},
    {&m68k_op_move_16_aw_a, 0xfff8, 0x31c8, {12, 12, 4}},
    {&m68k_op_move_16_aw_ai, 0xfff8, 0x31d0, {16, 16, 8}},
    {&m68k_op_move_16_aw_pi, 0xfff8, 0x31d8, {16, 16, 8}},
    {&m68k_op_move_16_aw_pd, 0xfff8, 0x31e0, {18, 18, 9}},
    {&m68k_op_move_16_aw_di, 0xfff8, 0x31e8, {20, 20, 9}},
    {&m68k_op_move_16_aw_ix, 0xfff8, 0x31f0, {22, 22, 11}},
    {&m68k_op_move_16_al_d, 0xfff8, 0x33c0, {16, 16, 6}},
    {&m68k_op_move_16_al_a, 0xfff8, 0x33c8, {16, 16, 6}},
    {&m68k_op_move_16_al_ai, 0xfff8, 0x33d0, {20, 20, 10}},
    {&m68k_op_move_16_al_pi, 0xfff8, 0x33d8, {20, 20, 10}},
    {&m68k_op_move_16_al_pd, 0xfff8, 0x33e0, {22, 22, 11}},
    {&m68k_op_move_16_al_di, 0xfff8, 0x33e8, {24, 24, 11}},
    {&m68k_op_move_16_al_ix, 0xfff8, 0x33f0, {26, 26, 13}},
    {&m68k_op_negx_8_d, 0xfff8, 0x4000, {4, 4, 2}},
    {&m68k_op_negx_8_ai, 0xfff8, 0x4010, {12, 12, 8}},
    {&m68k_op_negx_8_pi, 0xfff8, 0x4018, {12, 12, 8}},
    {&m68k_op_negx_8_pd, 0xfff8, 0x4020, {14, 14, 9}},
    {&m68k_op_negx_8_di, 0xfff8, 0x4028, {16, 16, 9}},
    {&m68k_op_negx_8_ix, 0xfff8, 0x4030, {18, 18, 11}},
    {&m68k_op_negx_16_d, 0xfff8, 0x4040, {4, 4, 2}},
    {&m68k_op_negx_16_ai, 0xfff8, 0x4050, {12, 12, 8}},
    {&m68k_op_negx_16_pi, 0xfff8, 0x4058, {12, 12, 8}},
    {&m68k_op_negx_16_pd, 0xfff8, 0x4060, {14, 14, 9}},
    {&m68k_op_negx_16_di, 0xfff8, 0x4068, {16, 16, 9}},
    {&m68k_op_negx_16_ix, 0xfff8, 0x4070, {18, 18, 11}},
    {&m68k_op_negx_32_d, 0xfff8, 0x4080, {6, 6, 2}},
    {&m68k_op_negx_32_ai, 0xfff8, 0x4090, {20, 20, 8}},
    {&m68k_op_negx_32_pi, 0xfff8, 0x4098, {20, 20, 8}},
    {&m68k_op_negx_32_pd, 0xfff8, 0x40a0, {22, 22, 9}},
    {&m68k_op_negx_32_di, 0xfff8, 0x40a8, {24, 24, 9}},
    {&m68k_op_negx_32_ix, 0xfff8, 0x40b0, {26, 26, 11}},
    {&m68k_op_move_16_frs_d, 0xfff8, 0x40c0, {6, 4, 8}},
    {&m68k_op_move_16_frs_ai, 0xfff8, 0x40d0, {12, 12, 12}},
    {&m68k_op_move_16_frs_pi, 0xfff8, 0x40d8, {12, 12, 12}},
    {&m68k_op_move_16_frs_pd, 0xfff8, 0x40e0, {14, 14, 13}},
    {&m68k_op_move_16_frs_di, 0xfff8, 0x40e8, {16, 16, 13}},
    {&m68k_op_move_16_frs_ix, 0xfff8, 0x40f0, {18, 18, 15}},
    {&m68k_op_clr_8_d, 0xfff8, 0x4200, {4, 4, 2}},
    {&m68k_op_clr_8_ai, 0xfff8, 0x4210, {12, 8, 8}},
    {&m68k_op_clr_8_pi, 0xfff8, 0x4218, {12, 8, 8}},
    {&m68k_op_clr_8_pd, 0xfff8, 0x4220, {14, 10, 9}},
    {&m68k_op_clr_8_di, 0xfff8, 0x4228, {16, 12, 9}},
    {&m68k_op_clr_8_ix, 0xfff8, 0x4230, {18, 14, 11}},
    {&m68k_op_clr_16_d, 0xfff8, 0x4240, {4, 4, 2}},
    {&m68k_op_clr_16_ai, 0xfff8, 0x4250, {12, 8, 8}},
    {&m68k_op_clr_16_pi, 0xfff8, 0x4258, {12, 8, 8}},
    {&m68k_op_clr_16_pd, 0xfff8, 0x4260, {14, 10, 9}},
    {&m68k_op_clr_16_di, 0xfff8, 0x4268, {16, 12, 9}},
    {&m68k_op_clr_16_ix, 0xfff8, 0x4270, {18, 14, 11}},
    {&m68k_op_clr_32_d, 0xfff8, 0x4280, {6, 6, 2}},
    {&m68k_op_clr_32_ai, 0xfff8, 0x4290, {20, 12, 8}},
    {&m68k_op_clr_32_pi, 0xfff8, 0x4298, {20, 12, 8}},
    {&m68k_op_clr_32_pd, 0xfff8, 0x42a0, {22, 14, 9}},
    {&m68k_op_clr_32_di, 0xfff8, 0x42a8, {24, 16, 9}},
    {&m68k_op_clr_32_ix, 0xfff8, 0x42b0, {26, 20, 11}},
    {&m68k_op_move_16_frc_d, 0xfff8, 0x42c0, {0, 4, 4}},
    {&m68k_op_move_16_frc_ai, 0xfff8, 0x42d0, {0, 12, 8}},
    {&m68k_op_move_16_frc_pi, 0xfff8, 0x42d8, {0, 12, 8}},
    {&m68k_op_move_16_frc_pd, 0xfff8, 0x42e0, {0, 14, 9}},
    {&m68k_op_move_16_frc_di, 0xfff8, 0x42e8, {0, 16, 9}},
    {&m68k_op_move_16_frc_ix, 0xfff8, 0x42f0, {0, 18, 11}},
    {&m68k_op_neg_8_d, 0xfff8, 0x4400, {4, 4, 2}},
    {&m68k_op_neg_8_ai, 0xfff8, 0x4410, {12, 12, 8}},
    {&m68k_op_neg_8_pi, 0xfff8, 0x4418, {12, 12, 8}},
    {&m68k_op_neg_8_pd, 0xfff8, 0x4420, {14, 14, 9}},
    {&m68k_op_neg_8_di, 0xfff8, 0x4428, {16, 16, 9}},
    {&m68k_op_neg_8_ix, 0xfff8, 0x4430, {18, 18, 11}},
    {&m68k_op_neg_16_d, 0xfff8, 0x4440, {4, 4, 2}},
    {&m68k_op_neg_16_ai, 0xfff8, 0x4450, {12, 12, 8}},
    {&m68k_op_neg_16_pi, 0xfff8, 0x4458, {12, 12, 8}},
    {&m68k_op_neg_16_pd, 0xfff8, 0x4460, {14, 14, 9}},
    {&m68k_op_neg_16_di, 0xfff8, 0x4468, {16, 16, 9}},
    {&m68k_op_neg_16_ix, 0xfff8, 0x4470, {18, 18, 11}},
    {&m68k_op_neg_32_d, 0xfff8, 0x4480, {6, 6, 2}},
    {&m68k_op_neg_32_ai, 0xfff8, 0x4490, {20, 20, 8}},
    {&m68k_op_neg_32_pi, 0xfff8, 0x4498, {20, 20, 8}},
    {&m68k_op_neg_32_pd, 0xfff8, 0x44a0, {22, 22, 9}},
    {&m68k_op_neg_32_di, 0xfff8, 0x44a8, {24, 24, 9}},
    {&m68k_op_neg_32_ix, 0xfff8, 0x44b0, {26, 26, 11}},
    {&m68k_op_move_16_toc_d, 0xfff8, 0x44c0, {12, 12, 4}},
    {&m68k_op_move_16_toc_ai, 0xfff8, 0x44d0, {16, 16, 8}},
    {&m68k_op_move_16_toc_pi, 0xfff8, 0x44d8, {16, 16, 8}},
    {&m68k_op_move_16_toc_pd, 0xfff8, 0x44e0, {18, 18, 9}},
    {&m68k_op_move_16_toc_di, 0xfff8, 0x44e8, {20, 20, 9}},
    {&m68k_op_move_16_toc_ix, 0xfff8, 0x44f0, {22, 22, 11}},
    {&m68k_op_not_8_d, 0xfff8, 0x4600, {4, 4, 2}},
    {&m68k_op_not_8_ai, 0xfff8, 0x4610, {12, 12, 8}},
    {&m68k_op_not_8_pi, 0xfff8, 0x4618, {12, 12, 8}},
    {&m68k_op_not_8_pd, 0xfff8, 0x4620, {14, 14, 9}},
    {&m68k_op_not_8_di, 0xfff8, 0x4628, {16, 16, 9}},
    {&m68k_op_not_8_ix, 0xfff8, 0x4630, {18, 18, 11}},
    {&m68k_op_not_16_d, 0xfff8, 0x4640, {4, 4, 2}},
    {&m68k_op_not_16_ai, 0xfff8, 0x4650, {12, 12, 8}},
    {&m68k_op_not_16_pi, 0xfff8, 0x4658, {12, 12, 8}},
    {&m68k_op_not_16_pd, 0xfff8, 0x4660, {14, 14, 9}},
    {&m68k_op_not_16_di, 0xfff8, 0x4668, {16, 16, 9}},
    {&m68k_op_not_16_ix, 0xfff8, 0x4670, {18, 18, 11}},
    {&m68k_op_not_32_d, 0xfff8, 0x4680, {6, 6, 2}},
    {&m68k_op_not_32_ai, 0xfff8, 0x4690, {20, 20, 8}},
    {&m68k_op_not_32_pi, 0xfff8, 0x4698, {20, 20, 8}},
    {&m68k_op_not_32_pd, 0xfff8, 0x46a0, {22, 22, 9}},
    {&m68k_op_not_32_di, 0xfff8, 0x46a8, {24, 24, 9}},
    {&m68k_op_not_32_ix, 0xfff8, 0x46b0, {26, 26, 11}},
    {&m68k_op_move_16_tos_d, 0xfff8, 0x46c0, {12, 12, 8}},
    {&m68k_op_move_16_tos_ai, 0xfff8, 0x46d0, {16, 16, 12}},
    {&m68k_op_move_16_tos_pi, 0xfff8, 0x46d8, {16, 16, 12}},
    {&m68k_op_move_16_tos_pd, 0xfff8, 0x46e0, {18, 18, 13}},
    {&m68k_op_move_16_tos_di, 0xfff8, 0x46e8, {20, 20, 13}},
    {&m68k_op_move_16_tos_ix, 0xfff8, 0x46f0, {22, 22, 15}},
    {&m68k_op_nbcd_8_d, 0xfff8, 0x4800, {6, 6, 6}},
    {&m68k_op_link_32, 0xfff8, 0x4808, {0, 0, 6}},
    {&m68k_op_nbcd_8_ai, 0xfff8, 0x4810, {12, 12, 10}},
    {&m68k_op_nbcd_8_pi, 0xfff8, 0x4818, {12, 12, 10}},
    {&m68k_op_nbcd_8_pd, 0xfff8, 0x4820, {14, 14, 11}},
    {&m68k_op_nbcd_8_di, 0xfff8, 0x4828, {16, 16, 11}},
    {&m68k_op_nbcd_8_ix, 0xfff8, 0x4830, {18, 18, 13}},
    {&m68k_op_swap_32, 0xfff8, 0x4840, {4, 4, 4}},
    {&m68k_op_bkpt, 0xfff8, 0x4848, {0, 10, 10}},
    {&m68k_op_pea_32_ai, 0xfff8, 0x4850, {10, 10, 9}},
    {&m68k_op_pea_32_di, 0xfff8, 0x4868, {16, 16, 10}},
    {&m68k_op_pea_32_ix, 0xfff8, 0x4870, {20, 20, 12}},
    {&m68k_op_ext_16, 0xfff8, 0x4880, {4, 4, 4}},
    {&m68k_op_movem_16_re_ai, 0xfff8, 0x4890, {12, 12, 8}},
    {&m68k_op_movem_16_re_pd, 0xfff8, 0x48a0, {8, 8, 4}},
    {&m68k_op_movem_16_re_di, 0xfff8, 0x48a8, {16, 16, 9}},
    {&m68k_op_movem_16_re_ix, 0xfff8, 0x48b0, {18, 18, 11}},
    {&m68k_op_ext_32, 0xfff8, 0x48c0, {4, 4, 4}},
    {&m68k_op_movem_32_re_ai, 0xfff8, 0x48d0, {16, 16, 8}},
    {&m68k_op_movem_32_re_pd, 0xfff8, 0x48e0, {8, 8, 4}},
    {&m68k_op_movem_32_re_di, 0xfff8, 0x48e8, {20, 20, 9}},
    {&m68k_op_movem_32_re_ix, 0xfff8, 0x48f0, {22, 22, 11}},
    {&m68k_op_extb_32, 0xfff8, 0x49c0, {0, 0, 4}},
    {&m68k_op_tst_8_d, 0xfff8, 0x4a00, {4, 4, 2}},
    {&m68k_op_tst_8_ai, 0xfff8, 0x4a10, {8, 8, 6}},
    {&m68k_op_tst_8_pi, 0xfff8, 0x4a18, {8, 8, 6}},
    {&m68k_op_tst_8_pd, 0xfff8, 0x4a20, {10, 10, 7}},
    {&m68k_op_tst_8_di, 0xfff8, 0x4a28, {12, 12, 7}},
    {&m68k_op_tst_8_ix, 0xfff8, 0x4a30, {14, 14, 9}},
    {&m68k_op_tst_16_d, 0xfff8, 0x4a40, {4, 4, 2}},
    {&m68k_op_tst_16_a, 0xfff8, 0x4a48, {0, 0, 2}},
    {&m68k_op_tst_16_ai, 0xfff8, 0x4a50, {8, 8, 6}},
    {&m68k_op_tst_16_pi, 0xfff8, 0x4a58, {8, 8, 6}},
    {&m68k_op_tst_16_pd, 0xfff8, 0x4a60, {10, 10, 7}},
    {&m68k_op_tst_16_di, 0xfff8, 0x4a68, {12, 12, 7}},
    {&m68k_op_tst_16_ix, 0xfff8, 0x4a70, {14, 14, 9}},
    {&m68k_op_tst_32_d, 0xfff8, 0x4a80, {4, 4, 2}},
    {&m68k_op_tst_32_a, 0xfff8, 0x4a88, {0, 0, 2}},
    {&m68k_op_tst_32_ai, 0xfff8, 0x4a90, {12, 12, 6}},
    {&m68k_op_tst_32_pi, 0xfff8, 0x4a98, {12, 12, 6}},
    {&m68k_op_tst_32_pd, 0xfff8, 0x4aa0, {14, 14, 7}},
    {&m68k_op_tst_32_di, 0xfff8, 0x4aa8, {16, 16, 7}},
    {&m68k_op_tst_32_ix, 0xfff8, 0x4ab0, {18, 18, 9}},
    {&m68k_op_tas_8_d, 0xfff8, 0x4ac0, {4, 4, 4}},
    {&m68k_op_tas_8_ai, 0xfff8, 0x4ad0, {18, 18, 16}},
    {&m68k_op_tas_8_pi, 0xfff8, 0x4ad8, {18, 18, 16}},
    {&m68k_op_tas_8_pd, 0xfff8, 0x4ae0, {20, 20, 17}},
    {&m68k_op_tas_8_di, 0xfff8, 0x4ae8, {22, 22, 17}},
    {&m68k_op_tas_8_ix, 0xfff8, 0x4af0, {24, 24, 19}},
    {&m68k_op_mull_32_d, 0xfff8, 0x4c00, {0, 0, 43}},
    {&m68k_op_mull_32_ai, 0xfff8, 0x4c10, {0, 0, 47}},
    {&m68k_op_mull_32_pi, 0xfff8, 0x4c18, {0, 0, 47}},
    {&m68k_op_mull_32_pd, 0xfff8, 0x4c20, {0, 0, 48}},
    {&m68k_op_mull_32_di, 0xfff8, 0x4c28, {0, 0, 48}},
    {&m68k_op_mull_32_ix, 0xfff8, 0x4c30, {0, 0, 50}},
    {&m68k_op_divl_32_d, 0xfff8, 0x4c40, {0, 0, 84}},
    {&m68k_op_divl_32_ai, 0xfff8, 0x4c50, {0, 0, 88}},
    {&m68k_op_divl_32_pi, 0xfff8, 0x4c58, {0, 0, 88}},
    {&m68k_op_divl_32_pd, 0xfff8, 0x4c60, {0, 0, 89}},
    {&m68k_op_divl_32_di, 0xfff8, 0x4c68, {0, 0, 89}},
    {&m68k_op_divl_32_ix, 0xfff8, 0x4c70, {0, 0, 91}},
    {&m68k_op_movem_16_er_ai, 0xfff8, 0x4c90, {16, 16, 12}},
    {&m68k_op_movem_16_er_pi, 0xfff8, 0x4c98, {12, 12, 8}},
    {&m68k_op_movem_16_er_di, 0xfff8, 0x4ca8, {20, 20, 13}},
    {&m68k_op_movem_16_er_ix, 0xfff8, 0x4cb0, {22, 22, 15}},
    {&m68k_op_movem_32_er_ai, 0xfff8, 0x4cd0, {20, 20, 12}},
    {&m68k_op_movem_32_er_pi, 0xfff8, 0x4cd8, {12, 12, 8}},
    {&m68k_op_movem_32_er_di, 0xfff8, 0x4ce8, {24, 24, 13}},
    {&m68k_op_movem_32_er_ix, 0xfff8, 0x4cf0, {26, 26, 15}},
    {&m68k_op_link_16, 0xfff8, 0x4e50, {16, 16, 5}},
    {&m68k_op_unlk_32, 0xfff8, 0x4e58, {12, 12, 6}},
    {&m68k_op_move_32_tou, 0xfff8, 0x4e60, {4, 6, 2}},
    {&m68k_op_move_32_fru, 0xfff8, 0x4e68, {4, 6, 2}},
    {&m68k_op_jsr_32_ai, 0xfff8, 0x4e90, {16, 16, 4}},
    {&m68k_op_jsr_32_di, 0xfff8, 0x4ea8, {18, 18, 5}},
    {&m68k_op_jsr_32_ix, 0xfff8, 0x4eb0, {22, 22, 7}},
    {&m68k_op_jmp_32_ai, 0xfff8, 0x4ed0, {8, 8, 4}},
    {&m68k_op_jmp_32_di, 0xfff8, 0x4ee8, {10, 10, 5}},
    {&m68k_op_jmp_32_ix, 0xfff8, 0x4ef0, {12, 12, 7}},
    {&m68k_op_st_8_d, 0xfff8, 0x50c0, {6, 4, 4}},
    {&m68k_op_dbt_16, 0xfff8, 0x50c8, {12, 12, 6}},
    {&m68k_op_st_8_ai, 0xfff8, 0x50d0, {12, 12, 10}},
    {&m68k_op_st_8_pi, 0xfff8, 0x50d8, {12, 12, 10}},
    {&m68k_op_st_8_pd, 0xfff8, 0x50e0, {14, 14, 11}},
    {&m68k_op_st_8_di, 0xfff8, 0x50e8, {16, 16, 11}},
    {&m68k_op_st_8_ix, 0xfff8, 0x50f0, {18, 18, 13}},
    {&m68k_op_sf_8_d, 0xfff8, 0x51c0, {4, 4, 4}},
    {&m68k_op_dbf_16, 0xfff8, 0x51c8, {14, 14, 6}},
    {&m68k_op_sf_8_ai, 0xfff8, 0x51d0, {12, 12, 10}},
    {&m68k_op_sf_8_pi, 0xfff8, 0x51d8, {12, 12, 10}},
    {&m68k_op_sf_8_pd, 0xfff8, 0x51e0, {14, 14, 11}},
    {&m68k_op_sf_8_di, 0xfff8, 0x51e8, {16, 16, 11}},
    {&m68k_op_sf_8_ix, 0xfff8, 0x51f0, {18, 18, 13}},
    {&m68k_op_shi_8_d, 0xfff8, 0x52c0, {4, 4, 4}},
    {&m68k_op_dbhi_16, 0xfff8, 0x52c8, {12, 12, 6}},
    {&m68k_op_shi_8_ai, 0xfff8, 0x52d0, {12, 12, 10}},
    {&m68k_op_shi_8_pi, 0xfff8, 0x52d8, {12, 12, 10}},
    {&m68k_op_shi_8_pd, 0xfff8, 0x52e0, {14, 14, 11}},
    {&m68k_op_shi_8_di, 0xfff8, 0x52e8, {16, 16, 11}},
    {&m68k_op_shi_8_ix, 0xfff8, 0x52f0, {18, 18, 13}},
    {&m68k_op_sls_8_d, 0xfff8, 0x53c0, {4, 4, 4}},
    {&m68k_op_dbls_16, 0xfff8, 0x53c8, {12, 12, 6}},
    {&m68k_op_sls_8_ai, 0xfff8, 0x53d0, {12, 12, 10}},
    {&m68k_op_sls_8_pi, 0xfff8, 0x53d8, {12, 12, 10}},
    {&m68k_op_sls_8_pd, 0xfff8, 0x53e0, {14, 14, 11}},
    {&m68k_op_sls_8_di, 0xfff8, 0x53e8, {16, 16, 11}},
    {&m68k_op_sls_8_ix, 0xfff8, 0x53f0, {18, 18, 13}},
    {&m68k_op_scc_8_d, 0xfff8, 0x54c0, {4, 4, 4}},
    {&m68k_op_dbcc_16, 0xfff8, 0x54c8, {12, 12, 6}},
    {&m68k_op_scc_8_ai, 0xfff8, 0x54d0, {12, 12, 10}},
    {&m68k_op_scc_8_pi, 0xfff8, 0x54d8, {12, 12, 10}},
    {&m68k_op_scc_8_pd, 0xfff8, 0x54e0, {14, 14, 11}},
    {&m68k_op_scc_8_di, 0xfff8, 0x54e8, {16, 16, 11}},
    {&m68k_op_scc_8_ix, 0xfff8, 0x54f0, {18, 18, 13}},
    {&m68k_op_scs_8_d, 0xfff8, 0x55c0, {4, 4, 4}},
    {&m68k_op_dbcs_16, 0xfff8, 0x55c8, {12, 12, 6}},
    {&m68k_op_scs_8_ai, 0xfff8, 0x55d0, {12, 12, 10}},
    {&m68k_op_scs_8_pi, 0xfff8, 0x55d8, {12, 12, 10}},
    {&m68k_op_scs_8_pd, 0xfff8, 0x55e0, {14, 14, 11}},
    {&m68k_op_scs_8_di, 0xfff8, 0x55e8, {16, 16, 11}},
    {&m68k_op_scs_8_ix, 0xfff8, 0x55f0, {18, 18, 13}},
    {&m68k_op_sne_8_d, 0xfff8, 0x56c0, {4, 4, 4}},
    {&m68k_op_dbne_16, 0xfff8, 0x56c8, {12, 12, 6}},
    {&m68k_op_sne_8_ai, 0xfff8, 0x56d0, {12, 12, 10}},
    {&m68k_op_sne_8_pi, 0xfff8, 0x56d8, {12, 12, 10}},
    {&m68k_op_sne_8_pd, 0xfff8, 0x56e0, {14, 14, 11}},
    {&m68k_op_sne_8_di, 0xfff8, 0x56e8, {16, 16, 11}},
    {&m68k_op_sne_8_ix, 0xfff8, 0x56f0, {18, 18, 13}},
    {&m68k_op_seq_8_d, 0xfff8, 0x57c0, {4, 4, 4}},
    {&m68k_op_dbeq_16, 0xfff8, 0x57c8, {12, 12, 6}},
    {&m68k_op_seq_8_ai, 0xfff8, 0x57d0, {12, 12, 10}},
    {&m68k_op_seq_8_pi, 0xfff8, 0x57d8, {12, 12, 10}},
    {&m68k_op_seq_8_pd, 0xfff8, 0x57e0, {14, 14, 11}},
    {&m68k_op_seq_8_di, 0xfff8, 0x57e8, {16, 16, 11}},
    {&m68k_op_seq_8_ix, 0xfff8, 0x57f0, {18, 18, 13}},
    {&m68k_op_svc_8_d, 0xfff8, 0x58c0, {4, 4, 4}},
    {&m68k_op_dbvc_16, 0xfff8, 0x58c8, {12, 12, 6}},
    {&m68k_op_svc_8_ai, 0xfff8, 0x58d0, {12, 12, 10}},
    {&m68k_op_svc_8_pi, 0xfff8, 0x58d8, {12, 12, 10}},
    {&m68k_op_svc_8_pd, 0xfff8, 0x58e0, {14, 14, 11}},
    {&m68k_op_svc_8_di, 0xfff8, 0x58e8, {16, 16, 11}},
    {&m68k_op_svc_8_ix, 0xfff8, 0x58f0, {18, 18, 13}},
    {&m68k_op_svs_8_d, 0xfff8, 0x59c0, {4, 4, 4}},
    {&m68k_op_dbvs_16, 0xfff8, 0x59c8, {12, 12, 6}},
    {&m68k_op_svs_8_ai, 0xfff8, 0x59d0, {12, 12, 10}},
    {&m68k_op_svs_8_pi, 0xfff8, 0x59d8, {12, 12, 10}},
    {&m68k_op_svs_8_pd, 0xfff8, 0x59e0, {14, 14, 11}},
    {&m68k_op_svs_8_di, 0xfff8, 0x59e8, {16, 16, 11}},
    {&m68k_op_svs_8_ix, 0xfff8, 0x59f0, {18, 18, 13}},
    {&m68k_op_spl_8_d, 0xfff8, 0x5ac0, {4, 4, 4}},
    {&m68k_op_dbpl_16, 0xfff8, 0x5ac8, {12, 12, 6}},
    {&m68k_op_spl_8_ai, 0xfff8, 0x5ad0, {12, 12, 10}},
    {&m68k_op_spl_8_pi, 0xfff8, 0x5ad8, {12, 12, 10}},
    {&m68k_op_spl_8_pd, 0xfff8, 0x5ae0, {14, 14, 11}},
    {&m68k_op_spl_8_di, 0xfff8, 0x5ae8, {16, 16, 11}},
    {&m68k_op_spl_8_ix, 0xfff8, 0x5af0, {18, 18, 13}},
    {&m68k_op_smi_8_d, 0xfff8, 0x5bc0, {4, 4, 4}},
    {&m68k_op_dbmi_16, 0xfff8, 0x5bc8, {12, 12, 6}},
    {&m68k_op_smi_8_ai, 0xfff8, 0x5bd0, {12, 12, 10}},
    {&m68k_op_smi_8_pi, 0xfff8, 0x5bd8, {12, 12, 10}},
    {&m68k_op_smi_8_pd, 0xfff8, 0x5be0, {14, 14, 11}},
    {&m68k_op_smi_8_di, 0xfff8, 0x5be8, {16, 16, 11}},
    {&m68k_op_smi_8_ix, 0xfff8, 0x5bf0, {18, 18, 13}},
    {&m68k_op_sge_8_d, 0xfff8, 0x5cc0, {4, 4, 4}},
    {&m68k_op_dbge_16, 0xfff8, 0x5cc8, {12, 12, 6}},
    {&m68k_op_sge_8_ai, 0xfff8, 0x5cd0, {12, 12, 10}},
    {&m68k_op_sge_8_pi, 0xfff8, 0x5cd8, {12, 12, 10}},
    {&m68k_op_sge_8_pd, 0xfff8, 0x5ce0, {14, 14, 11}},
    {&m68k_op_sge_8_di, 0xfff8, 0x5ce8, {16, 16, 11}},
    {&m68k_op_sge_8_ix, 0xfff8, 0x5cf0, {18, 18, 13}},
    {&m68k_op_slt_8_d, 0xfff8, 0x5dc0, {4, 4, 4}},
    {&m68k_op_dblt_16, 0xfff8, 0x5dc8, {12, 12, 6}},
    {&m68k_op_slt_8_ai, 0xfff8, 0x5dd0, {12, 12, 10}},
    {&m68k_op_slt_8_pi, 0xfff8, 0x5dd8, {12, 12, 10}},
    {&m68k_op_slt_8_pd, 0xfff8, 0x5de0, {14, 14, 11}},
    {&m68k_op_slt_8_di, 0xfff8, 0x5de8, {16, 16, 11}},
    {&m68k_op_slt_8_ix, 0xfff8, 0x5df0, {18, 18, 13}},
    {&m68k_op_sgt_8_d, 0xfff8, 0x5ec0, {4, 4, 4}},
    {&m68k_op_dbgt_16, 0xfff8, 0x5ec8, {12, 12, 6}},
    {&m68k_op_sgt_8_ai, 0xfff8, 0x5ed0, {12, 12, 10}},
    {&m68k_op_sgt_8_pi, 0xfff8, 0x5ed8, {12, 12, 10}},
    {&m68k_op_sgt_8_pd, 0xfff8, 0x5ee0, {14, 14, 11}},
    {&m68k_op_sgt_8_di, 0xfff8, 0x5ee8, {16, 16, 11}},
    {&m68k_op_sgt_8_ix, 0xfff8, 0x5ef0, {18, 18, 13}},
    {&m68k_op_sle_8_d, 0xfff8, 0x5fc0, {4, 4, 4}},
    {&m68k_op_dble_16, 0xfff8, 0x5fc8, {12, 12, 6}},
    {&m68k_op_sle_8_ai, 0xfff8, 0x5fd0, {12, 12, 10}},
    {&m68k_op_sle_8_pi, 0xfff8, 0x5fd8, {12, 12, 10}},
    {&m68k_op_sle_8_pd, 0xfff8, 0x5fe0, {14, 14, 11}},
    {&m68k_op_sle_8_di, 0xfff8, 0x5fe8, {16, 16, 11}},
    {&m68k_op_sle_8_ix, 0xfff8, 0x5ff0, {18, 18, 13}},
    {&m68k_op_sbcd_8_mm_ax7, 0xfff8, 0x8f08, {18, 18, 16}},
    {&m68k_op_pack_16_mm_ax7, 0xfff8, 0x8f48, {0, 0, 13}},
    {&m68k_op_unpk_16_mm_ax7, 0xfff8, 0x8f88, {0, 0, 13}},
    {&m68k_op_subx_8_mm_ax7, 0xfff8, 0x9f08, {18, 18, 12}},
    {&m68k_op_cmpm_8_ax7, 0xfff8, 0xbf08, {12, 12, 9}},
    {&m68k_op_abcd_8_mm_ax7, 0xfff8, 0xcf08, {18, 18, 16}},
    {&m68k_op_addx_8_mm_ax7, 0xfff8, 0xdf08, {18, 18, 12}},
    {&m68k_op_asr_16_ai, 0xfff8, 0xe0d0, {12, 12, 9}},
    {&m68k_op_asr_16_pi, 0xfff8, 0xe0d8, {12, 12, 9}},
    {&m68k_op_asr_16_pd, 0xfff8, 0xe0e0, {14, 14, 10}},
    {&m68k_op_asr_16_di, 0xfff8, 0xe0e8, {16, 16, 10}},
    {&m68k_op_asr_16_ix, 0xfff8, 0xe0f0, {18, 18, 12}},
    {&m68k_op_asl_16_ai, 0xfff8, 0xe1d0, {12, 12, 10}},
    {&m68k_op_asl_16_pi, 0xfff8, 0xe1d8, {12, 12, 10}},
    {&m68k_op_asl_16_pd, 0xfff8, 0xe1e0, {14, 14, 11}},
    {&m68k_op_asl_16_di, 0xfff8, 0xe1e8, {16, 16, 11}},
    {&m68k_op_asl_16_ix, 0xfff8, 0xe1f0, {18, 18, 13}},
    {&m68k_op_lsr_16_ai, 0xfff8, 0xe2d0, {12, 12, 9}},
    {&m68k_op_lsr_16_pi, 0xfff8, 0xe2d8, {12, 12, 9}},
    {&m68k_op_lsr_16_pd, 0xfff8, 0xe2e0, {14, 14, 10}},
    {&m68k_op_lsr_16_di, 0xfff8, 0xe2e8, {16, 16, 10}},
    {&m68k_op_lsr_16_ix, 0xfff8, 0xe2f0, {18, 18, 12}},
    {&m68k_op_lsl_16_ai, 0xfff8, 0xe3d0, {12, 12, 9}},
    {&m68k_op_lsl_16_pi, 0xfff8, 0xe3d8, {12, 12, 9}},
    {&m68k_op_lsl_16_pd, 0xfff8, 0xe3e0, {14, 14, 10}},
    {&m68k_op_lsl_16_di, 0xfff8, 0xe3e8, {16, 16, 10}},
    {&m68k_op_lsl_16_ix, 0xfff8, 0xe3f0, {18, 18, 12}},
    {&m68k_op_roxr_16_ai, 0xfff8, 0xe4d0, {12, 12, 9}},
    {&m68k_op_roxr_16_pi, 0xfff8, 0xe4d8, {12, 12, 9}},
    {&m68k_op_roxr_16_pd, 0xfff8, 0xe4e0, {14, 14, 10}},
    {&m68k_op_roxr_16_di, 0xfff8, 0xe4e8, {16, 16, 10}},
    {&m68k_op_roxr_16_ix, 0xfff8, 0xe4f0, {18, 18, 12}},
    {&m68k_op_roxl_16_ai, 0xfff8, 0xe5d0, {12, 12, 9}},
    {&m68k_op_roxl_16_pi, 0xfff8, 0xe5d8, {12, 12, 9}},
    {&m68k_op_roxl_16_pd, 0xfff8, 0xe5e0, {14, 14, 10}},
    {&m68k_op_roxl_16_di, 0xfff8, 0xe5e8, {16, 16, 10}},
    {&m68k_op_roxl_16_ix, 0xfff8, 0xe5f0, {18, 18, 12}},
    {&m68k_op_ror_16_ai, 0xfff8, 0xe6d0, {12, 12, 11}},
    {&m68k_op_ror_16_pi, 0xfff8, 0xe6d8, {12, 12, 11}},
    {&m68k_op_ror_16_pd, 0xfff8, 0xe6e0, {14, 14, 12}},
    {&m68k_op_ror_16_di, 0xfff8, 0xe6e8, {16, 16, 12}},
    {&m68k_op_ror_16_ix, 0xfff8, 0xe6f0, {18, 18, 14}},
    {&m68k_op_rol_16_ai, 0xfff8, 0xe7d0, {12, 12, 11}},
    {&m68k_op_rol_16_pi, 0xfff8, 0xe7d8, {12, 12, 11}},
    {&m68k_op_rol_16_pd, 0xfff8, 0xe7e0, {14, 14, 12}},
    {&m68k_op_rol_16_di, 0xfff8, 0xe7e8, {16, 16, 12}},
    {&m68k_op_rol_16_ix, 0xfff8, 0xe7f0, {18, 18, 14}},
    {&m68k_op_bftst_32_d, 0xfff8, 0xe8c0, {0, 0, 6}},
    {&m68k_op_bftst_32_ai, 0xfff8, 0xe8d0, {0, 0, 17}},
    {&m68k_op_bftst_32_di, 0xfff8, 0xe8e8, {0, 0, 18}},
    {&m68k_op_bftst_32_ix, 0xfff8, 0xe8f0, {0, 0, 20}},
    {&m68k_op_bfextu_32_d, 0xfff8, 0xe9c0, {0, 0, 8}},
    {&m68k_op_bfextu_32_ai, 0xfff8, 0xe9d0, {0, 0, 19}},
    {&m68k_op_bfextu_32_di, 0xfff8, 0xe9e8, {0, 0, 20}},
    {&m68k_op_bfextu_32_ix, 0xfff8, 0xe9f0, {0, 0, 22}},
    {&m68k_op_bfchg_32_d, 0xfff8, 0xeac0, {0, 0, 12}},
    {&m68k_op_bfchg_32_ai, 0xfff8, 0xead0, {0, 0, 24}},
    {&m68k_op_bfchg_32_di, 0xfff8, 0xeae8, {0, 0, 25}},
    {&m68k_op_bfchg_32_ix, 0xfff8, 0xeaf0, {0, 0, 27}},
    {&m68k_op_bfexts_32_d, 0xfff8, 0xebc0, {0, 0, 8}},
    {&m68k_op_bfexts_32_ai, 0xfff8, 0xebd0, {0, 0, 19}},
    {&m68k_op_bfexts_32_di, 0xfff8, 0xebe8, {0, 0, 20}},
    {&m68k_op_bfexts_32_ix, 0xfff8, 0xebf0, {0, 0, 22}},
    {&m68k_op_bfclr_32_d, 0xfff8, 0xecc0, {0, 0, 12}},
    {&m68k_op_bfclr_32_ai, 0xfff8, 0xecd0, {0, 0, 24}},
    {&m68k_op_bfclr_32_di, 0xfff8, 0xece8, {0, 0, 25}},
    {&m68k_op_bfclr_32_ix, 0xfff8, 0xecf0, {0, 0, 27}},
    {&m68k_op_bfffo_32_d, 0xfff8, 0xedc0, {0, 0, 18}},
    {&m68k_op_bfffo_32_ai, 0xfff8, 0xedd0, {0, 0, 32}},
    {&m68k_op_bfffo_32_di, 0xfff8, 0xede8, {0, 0, 33}},
    {&m68k_op_bfffo_32_ix, 0xfff8, 0xedf0, {0, 0, 35}},
    {&m68k_op_bfset_32_d, 0xfff8, 0xeec0, {0, 0, 12}},
    {&m68k_op_bfset_32_ai, 0xfff8, 0xeed0, {0, 0, 24}},
    {&m68k_op_bfset_32_di, 0xfff8, 0xeee8, {0, 0, 25}},
    {&m68k_op_bfset_32_ix, 0xfff8, 0xeef0, {0, 0, 27}},
    {&m68k_op_bfins_32_d, 0xfff8, 0xefc0, {0, 0, 10}},
    {&m68k_op_bfins_32_ai, 0xfff8, 0xefd0, {0, 0, 21}},
    {&m68k_op_bfins_32_di, 0xfff8, 0xefe8, {0, 0, 22}},
    {&m68k_op_bfins_32_ix, 0xfff8, 0xeff0, {0, 0, 24}},
    {&m68k_op_ori_8_pi7, 0xffff, 0x001f, {16, 16, 8}},
    {&m68k_op_ori_8_pd7, 0xffff, 0x0027, {18, 18, 9}},
    {&m68k_op_ori_8_aw, 0xffff, 0x0038, {20, 20, 8}},
    {&m68k_op_ori_8_al, 0xffff, 0x0039, {24, 24, 8}},
    {&m68k_op_ori_16_toc, 0xffff, 0x003c, {20, 16, 12}},
    {&m68k_op_ori_16_aw, 0xffff, 0x0078, {20, 20, 8}},
    {&m68k_op_ori_16_al, 0xffff, 0x0079, {24, 24, 8}},
    {&m68k_op_ori_16_tos, 0xffff, 0x007c, {20, 16, 12}},
    {&m68k_op_ori_32_aw, 0xffff, 0x00b8, {32, 32, 8}},
    {&m68k_op_ori_32_al, 0xffff, 0x00b9, {36, 36, 8}},
    {&m68k_op_chk2cmp2_8_aw, 0xffff, 0x00f8, {0, 0, 22}},
    {&m68k_op_chk2cmp2_8_al, 0xffff, 0x00f9, {0, 0, 22}},
    {&m68k_op_chk2cmp2_8_pcdi, 0xffff, 0x00fa, {0, 0, 23}},
    {&m68k_op_chk2cmp2_8_pcix, 0xffff, 0x00fb, {0, 0, 25}},
    {&m68k_op_andi_8_pi7, 0xffff, 0x021f, {16, 16, 8}},
    {&m68k_op_andi_8_pd7, 0xffff, 0x0227, {18, 18, 9}},
    {&m68k_op_andi_8_aw, 0xffff, 0x0238, {20, 20, 8}},
    {&m68k_op_andi_8_al, 0xffff, 0x0239, {24, 24, 8}},
    {&m68k_op_andi_16_toc, 0xffff, 0x023c, {20, 16, 12}},
    {&m68k_op_andi_16_aw, 0xffff, 0x0278, {20, 20, 8}},
    {&m68k_op_andi_16_al, 0xffff, 0x0279, {24, 24, 8}},
    {&m68k_op_andi_16_tos, 0xffff, 0x027c, {20, 16, 12}},
    {&m68k_op_andi_32_aw, 0xffff, 0x02b8, {32, 32, 8}},
    {&m68k_op_andi_32_al, 0xffff, 0x02b9, {36, 36, 8}},
    {&m68k_op_chk2cmp2_16_aw, 0xffff, 0x02f8, {0, 0, 22}},
    {&m68k_op_chk2cmp2_16_al, 0xffff, 0x02f9, {0, 0, 22}},
    {&m68k_op_chk2cmp2_16_pcdi, 0xffff, 0x02fa, {0, 0, 23}},
    {&m68k_op_chk2cmp2_16_pcix, 0xffff, 0x02fb, {0, 0, 25}},
    {&m68k_op_subi_8_pi7, 0xffff, 0x041f, {16, 16, 8}},
    {&m68k_op_subi_8_pd7, 0xffff, 0x0427, {18, 18, 9}},
    {&m68k_op_subi_8_aw, 0xffff, 0x0438, {20, 20, 8}},
    {&m68k_op_subi_8_al, 0xffff, 0x0439, {24, 24, 8}},
    {&m68k_op_subi_16_aw, 0xffff, 0x0478, {20, 20, 8}},
    {&m68k_op_subi_16_al, 0xffff, 0x0479, {24, 24, 8}},
    {&m68k_op_subi_32_aw, 0xffff, 0x04b8, {32, 32, 8}},
    {&m68k_op_subi_32_al, 0xffff, 0x04b9, {36, 36, 8}},
    {&m68k_op_chk2cmp2_32_aw, 0xffff, 0x04f8, {0, 0, 22}},
    {&m68k_op_chk2cmp2_32_al, 0xffff, 0x04f9, {0, 0, 22}},
    {&m68k_op_chk2cmp2_32_pcdi, 0xffff, 0x04fa, {0, 0, 23}},
    {&m68k_op_chk2cmp2_32_pcix, 0xffff, 0x04fb, {0, 0, 25}},
    {&m68k_op_addi_8_pi7, 0xffff, 0x061f, {16, 16, 8}},
    {&m68k_op_addi_8_pd7, 0xffff, 0x0627, {18, 18, 9}},
    {&m68k_op_addi_8_aw, 0xffff, 0x0638, {20, 20, 8}},
    {&m68k_op_addi_8_al, 0xffff, 0x0639, {24, 24, 8}},
    {&m68k_op_addi_16_aw, 0xffff, 0x0678, {20, 20, 8}},
    {&m68k_op_addi_16_al, 0xffff, 0x0679, {24, 24, 8}},
    {&m68k_op_addi_32_aw, 0xffff, 0x06b8, {32, 32, 8}},
    {&m68k_op_addi_32_al, 0xffff, 0x06b9, {36, 36, 8}},
    {&m68k_op_callm_32_aw, 0xffff, 0x06f8, {0, 0, 64}},
    {&m68k_op_callm_32_al, 0xffff, 0x06f9, {0, 0, 64}},
    {&m68k_op_callm_32_pcdi, 0xffff, 0x06fa, {0, 0, 65}},
    {&m68k_op_callm_32_pcix, 0xffff, 0x06fb, {0, 0, 67}},
    {&m68k_op_btst_8_s_pi7, 0xffff, 0x081f, {12, 12, 8}},
    {&m68k_op_btst_8_s_pd7, 0xffff, 0x0827, {14, 14, 9}},
    {&m68k_op_btst_8_s_aw, 0xffff, 0x0838, {16, 16, 8}},
    {&m68k_op_btst_8_s_al, 0xffff, 0x0839, {20, 20, 8}},
    {&m68k_op_btst_8_s_pcdi, 0xffff, 0x083a, {16, 16, 9}},
    {&m68k_op_btst_8_s_pcix, 0xffff, 0x083b, {18, 18, 11}},
    {&m68k_op_bchg_8_s_pi7, 0xffff, 0x085f, {16, 16, 8}},
    {&m68k_op_bchg_8_s_pd7, 0xffff, 0x0867, {18, 18, 9}},
    {&m68k_op_bchg_8_s_aw, 0xffff, 0x0878, {20, 20, 8}},
    {&m68k_op_bchg_8_s_al, 0xffff, 0x0879, {24, 24, 8}},
    {&m68k_op_bclr_8_s_pi7, 0xffff, 0x089f, {16, 16, 8}},
    {&m68k_op_bclr_8_s_pd7, 0xffff, 0x08a7, {18, 18, 9}},
    {&m68k_op_bclr_8_s_aw, 0xffff, 0x08b8, {20, 20, 8}},
    {&m68k_op_bclr_8_s_al, 0xffff, 0x08b9, {24, 24, 8}},
    {&m68k_op_bset_8_s_pi7, 0xffff, 0x08df, {16, 16, 8}},
    {&m68k_op_bset_8_s_pd7, 0xffff, 0x08e7, {18, 18, 9}},
    {&m68k_op_bset_8_s_aw, 0xffff, 0x08f8, {20, 20, 8}},
    {&m68k_op_bset_8_s_al, 0xffff, 0x08f9, {24, 24, 8}},
    {&m68k_op_eori_8_pi7, 0xffff, 0x0a1f, {16, 16, 8}},
    {&m68k_op_eori_8_pd7, 0xffff, 0x0a27, {18, 18, 9}},
    {&m68k_op_eori_8_aw, 0xffff, 0x0a38, {20, 20, 8}},
    {&m68k_op_eori_8_al, 0xffff, 0x0a39, {24, 24, 8}},
    {&m68k_op_eori_16_toc, 0xffff, 0x0a3c, {20, 16, 12}},
    {&m68k_op_eori_16_aw, 0xffff, 0x0a78, {20, 20, 8}},
    {&m68k_op_eori_16_al, 0xffff, 0x0a79, {24, 24, 8}},
    {&m68k_op_eori_16_tos, 0xffff, 0x0a7c, {20, 16, 12}},
    {&m68k_op_eori_32_aw, 0xffff, 0x0ab8, {32, 32, 8}},
    {&m68k_op_eori_32_al, 0xffff, 0x0ab9, {36, 36, 8}},
    {&m68k_op_cas_8_pi7, 0xffff, 0x0adf, {0, 0, 16}},
    {&m68k_op_cas_8_pd7, 0xffff, 0x0ae7, {0, 0, 17}},
    {&m68k_op_cas_8_aw, 0xffff, 0x0af8, {0, 0, 16}},
    {&m68k_op_cas_8_al, 0xffff, 0x0af9, {0, 0, 16}},
    {&m68k_op_cmpi_8_pi7, 0xffff, 0x0c1f, {12, 12, 6}},
    {&m68k_op_cmpi_8_pd7, 0xffff, 0x0c27, {14, 14, 7}},
    {&m68k_op_cmpi_8_aw, 0xffff, 0x0c38, {16, 16, 6}},
    {&m68k_op_cmpi_8_al, 0xffff, 0x0c39, {20, 20, 6}},
    {&m68k_op_cmpi_8_pcdi, 0xffff, 0x0c3a, {0, 0, 7}},
    {&m68k_op_cmpi_8_pcix, 0xffff, 0x0c3b, {0, 0, 9}},
    {&m68k_op_cmpi_16_aw, 0xffff, 0x0c78, {16, 16, 6}},
    {&m68k_op_cmpi_16_al, 0xffff, 0x0c79, {20, 20, 6}},
    {&m68k_op_cmpi_16_pcdi, 0xffff, 0x0c7a, {0, 0, 7}},
    {&m68k_op_cmpi_16_pcix, 0xffff, 0x0c7b, {0, 0, 9}},
    {&m68k_op_cmpi_32_aw, 0xffff, 0x0cb8, {24, 24, 6}},
    {&m68k_op_cmpi_32_al, 0xffff, 0x0cb9, {28, 28, 6}},
    {&m68k_op_cmpi_32_pcdi, 0xffff, 0x0cba, {0, 0, 7}},
    {&m68k_op_cmpi_32_pcix, 0xffff, 0x0cbb, {0, 0, 9}},
    {&m68k_op_cas_16_aw, 0xffff, 0x0cf8, {0, 0, 16}},
    {&m68k_op_cas_16_al, 0xffff, 0x0cf9, {0, 0, 16}},
    {&m68k_op_cas2_16, 0xffff, 0x0cfc, {0, 0, 12}},
    {&m68k_op_moves_8_pi7, 0xffff, 0x0e1f, {0, 18, 9}},
    {&m68k_op_moves_8_pd7, 0xffff, 0x0e27, {0, 20, 10}},
    {&m68k_op_moves_8_aw, 0xffff, 0x0e38, {0, 26, 9}},
    {&m68k_op_moves_8_al, 0xffff, 0x0e39, {0, 30, 9}},
    {&m68k_op_moves_16_aw, 0xffff, 0x0e78, {0, 26, 9}},
    {&m68k_op_moves_16_al, 0xffff, 0x0e79, {0, 30, 9}},
    {&m68k_op_moves_32_aw, 0xffff, 0x0eb8, {0, 32, 9}},
    {&m68k_op_moves_32_al, 0xffff, 0x0eb9, {0, 36, 9}},
    {&m68k_op_cas_32_aw, 0xffff, 0x0ef8, {0, 0, 16}},
    {&m68k_op_cas_32_al, 0xffff, 0x0ef9, {0, 0, 16}},
    {&m68k_op_cas2_32, 0xffff, 0x0efc, {0, 0, 12}},
    {&m68k_op_move_8_aw_pi7, 0xffff, 0x11df, {16, 16, 8}},
    {&m68k_op_move_8_aw_pd7, 0xffff, 0x11e7, {18, 18, 9}},
    {&m68k_op_move_8_aw_aw, 0xffff, 0x11f8, {20, 20, 8}},
    {&m68k_op_move_8_aw_al, 0xffff, 0x11f9, {24, 24, 8}},
    {&m68k_op_move_8_aw_pcdi, 0xffff, 0x11fa, {20, 20, 9}},
    {&m68k_op_move_8_aw_pcix, 0xffff, 0x11fb, {22, 22, 11}},
    {&m68k_op_move_8_aw_i, 0xffff, 0x11fc, {16, 16, 6}},
    {&m68k_op_move_8_al_pi7, 0xffff, 0x13df, {20, 20, 10}},
    {&m68k_op_move_8_al_pd7, 0xffff, 0x13e7, {22, 22, 11}},
    {&m68k_op_move_8_al_aw, 0xffff, 0x13f8, {24, 24, 10}},
    {&m68k_op_move_8_al_al, 0xffff, 0x13f9, {28, 28, 10}},
    {&m68k_op_move_8_al_pcdi, 0xffff, 0x13fa, {24, 24, 11}},
    {&m68k_op_move_8_al_pcix, 0xffff, 0x13fb, {26, 26, 13}},
    {&m68k_op_move_8_al_i, 0xffff, 0x13fc, {20, 20, 8}},
    {&m68k_op_move_8_pi7_pi7, 0xffff, 0x1edf, {12, 12, 8}},
    {&m68k_op_move_8_pi7_pd7, 0xffff, 0x1ee7, {14, 14, 9}},
    {&m68k_op_move_8_pi7_aw, 0xffff, 0x1ef8, {16, 16, 8}},
    {&m68k_op_move_8_pi7_al, 0xffff, 0x1ef9, {20, 20, 8}},
    {&m68k_op_move_8_pi7_pcdi, 0xffff, 0x1efa, {16, 16, 9}},
    {&m68k_op_move_8_pi7_pcix, 0xffff, 0x1efb, {18, 18, 11}},
    {&m68k_op_move_8_pi7_i, 0xffff, 0x1efc, {12, 12, 6}},
    {&m68k_op_move_8_pd7_pi7, 0xffff, 0x1f1f, {12, 12, 9}},
    {&m68k_op_move_8_pd7_pd7, 0xffff, 0x1f27, {14, 14, 10}},
    {&m68k_op_move_8_pd7_aw, 0xffff, 0x1f38, {16, 16, 9}},
    {&m68k_op_move_8_pd7_al, 0xffff, 0x1f39, {20, 20, 9}},
    {&m68k_op_move_8_pd7_pcdi, 0xffff, 0x1f3a, {16, 16, 10}},
    {&m68k_op_move_8_pd7_pcix, 0xffff, 0x1f3b, {18, 18, 12}},
    {&m68k_op_move_8_pd7_i, 0xffff, 0x1f3c, {12, 12, 7}},
    {&m68k_op_move_32_aw_aw, 0xffff, 0x21f8, {28, 28, 8}},
    {&m68k_op_move_32_aw_al, 0xffff, 0x21f9, {32, 32, 8}},
    {&m68k_op_move_32_aw_pcdi, 0xffff, 0x21fa, {28, 28, 9}},
    {&m68k_op_move_32_aw_pcix, 0xffff, 0x21fb, {30, 30, 11}},
    {&m68k_op_move_32_aw_i, 0xffff, 0x21fc, {24, 24, 8}},
    {&m68k_op_move_32_al_aw, 0xffff, 0x23f8, {32, 32, 10}},
    {&m68k_op_move_32_al_al, 0xffff, 0x23f9, {36, 36, 10}},
    {&m68k_op_move_32_al_pcdi, 0xffff, 0x23fa, {32, 32, 11}},
    {&m68k_op_move_32_al_pcix, 0xffff, 0x23fb, {34, 34, 13}},
    {&m68k_op_move_32_al_i, 0xffff, 0x23fc, {28, 28, 10}},
    {&m68k_op_move_16_aw_aw, 0xffff, 0x31f8, {20, 20, 8}},
    {&m68k_op_move_16_aw_al, 0xffff, 0x31f9, {24, 24, 8}},
    {&m68k_op_move_16_aw_pcdi, 0xffff, 0x31fa, {20, 20, 9}},
    {&m68k_op_move_16_aw_pcix, 0xffff, 0x31fb, {22, 22, 11}},
    {&m68k_op_move_16_aw_i, 0xffff, 0x31fc, {16, 16, 6}},
    {&m68k_op_move_16_al_aw, 0xffff, 0x33f8, {24, 24, 10}},
    {&m68k_op_move_16_al_al, 0xffff, 0x33f9, {28, 28, 10}},
    {&m68k_op_move_16_al_pcdi, 0xffff, 0x33fa, {24, 24, 11}},
    {&m68k_op_move_16_al_pcix, 0xffff, 0x33fb, {26, 26, 13}},
    {&m68k_op_move_16_al_i, 0xffff, 0x33fc, {20, 20, 8}},
    {&m68k_op_negx_8_pi7, 0xffff, 0x401f, {12, 12, 8}},
    {&m68k_op_negx_8_pd7, 0xffff, 0x4027, {14, 14, 9}},
    {&m68k_op_negx_8_aw, 0xffff, 0x4038, {16, 16, 8}},
    {&m68k_op_negx_8_al, 0xffff, 0x4039, {20, 20, 8}},
    {&m68k_op_negx_16_aw, 0xffff, 0x4078, {16, 16, 8}},
    {&m68k_op_negx_16_al, 0xffff, 0x4079, {20, 20, 8}},
    {&m68k_op_negx_32_aw, 0xffff, 0x40b8, {24, 24, 8}},
    {&m68k_op_negx_32_al, 0xffff, 0x40b9, {28, 28, 8}},
    {&m68k_op_move_16_frs_aw, 0xffff, 0x40f8, {16, 16, 12}},
    {&m68k_op_move_16_frs_al, 0xffff, 0x40f9, {20, 20, 12}},
    {&m68k_op_clr_8_pi7, 0xffff, 0x421f, {12, 8, 8}},
    {&m68k_op_clr_8_pd7, 0xffff, 0x4227, {14, 10, 9}},
    {&m68k_op_clr_8_aw, 0xffff, 0x4238, {16, 12, 8}},
    {&m68k_op_clr_8_al, 0xffff, 0x4239, {20, 14, 8}},
    {&m68k_op_clr_16_aw, 0xffff, 0x4278, {16, 12, 8}},
    {&m68k_op_clr_16_al, 0xffff, 0x4279, {20, 14, 8}},
    {&m68k_op_clr_32_aw, 0xffff, 0x42b8, {24, 16, 8}},
    {&m68k_op_clr_32_al, 0xffff, 0x42b9, {28, 20, 8}},
    {&m68k_op_move_16_frc_aw, 0xffff, 0x42f8, {0, 16, 8}},
    {&m68k_op_move_16_frc_al, 0xffff, 0x42f9, {0, 20, 8}},
    {&m68k_op_neg_8_pi7, 0xffff, 0x441f, {12, 12, 8}},
    {&m68k_op_neg_8_pd7, 0xffff, 0x4427, {14, 14, 9}},
    {&m68k_op_neg_8_aw, 0xffff, 0x4438, {16, 16, 8}},
    {&m68k_op_neg_8_al, 0xffff, 0x4439, {20, 20, 8}},
    {&m68k_op_neg_16_aw, 0xffff, 0x4478, {16, 16, 8}},
    {&m68k_op_neg_16_al, 0xffff, 0x4479, {20, 20, 8}},
    {&m68k_op_neg_32_aw, 0xffff, 0x44b8, {24, 24, 8}},
    {&m68k_op_neg_32_al, 0xffff, 0x44b9, {28, 28, 8}},
    {&m68k_op_move_16_toc_aw, 0xffff, 0x44f8, {20, 20, 8}},
    {&m68k_op_move_16_toc_al, 0xffff, 0x44f9, {24, 24, 8}},
    {&m68k_op_move_16_toc_pcdi, 0xffff, 0x44fa, {20, 20, 9}},
    {&m68k_op_move_16_toc_pcix, 0xffff, 0x44fb, {22, 22, 11}},
    {&m68k_op_move_16_toc_i, 0xffff, 0x44fc, {16, 16, 6}},
    {&m68k_op_not_8_pi7, 0xffff, 0x461f, {12, 12, 8}},
    {&m68k_op_not_8_pd7, 0xffff, 0x4627, {14, 14, 9}},
    {&m68k_op_not_8_aw, 0xffff, 0x4638, {16, 16, 8}},
    {&m68k_op_not_8_al, 0xffff, 0x4639, {20, 20, 8}},
    {&m68k_op_not_16_aw, 0xffff, 0x4678, {16, 16, 8}},
    {&m68k_op_not_16_al, 0xffff, 0x4679, {20, 20, 8}},
    {&m68k_op_not_32_aw, 0xffff, 0x46b8, {24, 24, 8}},
    {&m68k_op_not_32_al, 0xffff, 0x46b9, {28, 28, 8}},
    {&m68k_op_move_16_tos_aw, 0xffff, 0x46f8, {20, 20, 12}},
    {&m68k_op_move_16_tos_al, 0xffff, 0x46f9, {24, 24, 12}},
    {&m68k_op_move_16_tos_pcdi, 0xffff, 0x46fa, {20, 20, 13}},
    {&m68k_op_move_16_tos_pcix, 0xffff, 0x46fb, {22, 22, 15}},
    {&m68k_op_move_16_tos_i, 0xffff, 0x46fc, {16, 16, 10}},
    {&m68k_op_link_32_a7, 0xffff, 0x480f, {0, 0, 6}},
    {&m68k_op_nbcd_8_pi7, 0xffff, 0x481f, {12, 12, 10}},
    {&m68k_op_nbcd_8_pd7, 0xffff, 0x4827, {14, 14, 11}},
    {&m68k_op_nbcd_8_aw, 0xffff, 0x4838, {16, 16, 10}},
    {&m68k_op_nbcd_8_al, 0xffff, 0x4839, {20, 20, 10}},
    {&m68k_op_pea_32_aw, 0xffff, 0x4878, {16, 16, 9}},
    {&m68k_op_pea_32_al, 0xffff, 0x4879, {20, 20, 9}},
    {&m68k_op_pea_32_pcdi, 0xffff, 0x487a, {16, 16, 10}},
    {&m68k_op_pea_32_pcix, 0xffff, 0x487b, {20, 20, 12}},
    {&m68k_op_movem_16_re_aw, 0xffff, 0x48b8, {16, 16, 8}},
    {&m68k_op_movem_16_re_al, 0xffff, 0x48b9, {20, 20, 8}},
    {&m68k_op_movem_32_re_aw, 0xffff, 0x48f8, {20, 20, 8}},
    {&m68k_op_movem_32_re_al, 0xffff, 0x48f9, {24, 24, 8}},
    {&m68k_op_tst_8_pi7, 0xffff, 0x4a1f, {8, 8, 6}},
    {&m68k_op_tst_8_pd7, 0xffff, 0x4a27, {10, 10, 7}},
    {&m68k_op_tst_8_aw, 0xffff, 0x4a38, {12, 12, 6}},
    {&m68k_op_tst_8_al, 0xffff, 0x4a39, {16, 16, 6}},
    {&m68k_op_tst_8_pcdi, 0xffff, 0x4a3a, {0, 0, 7}},
    {&m68k_op_tst_8_pcix, 0xffff, 0x4a3b, {0, 0, 9}},
    {&m68k_op_tst_8_i, 0xffff, 0x4a3c, {0, 0, 6}},
    {&m68k_op_tst_16_aw, 0xffff, 0x4a78, {12, 12, 6}},
    {&m68k_op_tst_16_al, 0xffff, 0x4a79, {16, 16, 6}},
    {&m68k_op_tst_16_pcdi, 0xffff, 0x4a7a, {0, 0, 7}},
    {&m68k_op_tst_16_pcix, 0xffff, 0x4a7b, {0, 0, 9}},
    {&m68k_op_tst_16_i, 0xffff, 0x4a7c, {0, 0, 6}},
    {&m68k_op_tst_32_aw, 0xffff, 0x4ab8, {16, 16, 6}},
    {&m68k_op_tst_32_al, 0xffff, 0x4ab9, {20, 20, 6}},
    {&m68k_op_tst_32_pcdi, 0xffff, 0x4aba, {0, 0, 7}},
    {&m68k_op_tst_32_pcix, 0xffff, 0x4abb, {0, 0, 9}},
    {&m68k_op_tst_32_i, 0xffff, 0x4abc, {0, 0, 6}},
    {&m68k_op_tas_8_pi7, 0xffff, 0x4adf, {18, 18, 16}},
    {&m68k_op_tas_8_pd7, 0xffff, 0x4ae7, {20, 20, 17}},
    {&m68k_op_tas_8_aw, 0xffff, 0x4af8, {22, 22, 16}},
    {&m68k_op_tas_8_al, 0xffff, 0x4af9, {26, 26, 16}},
    {&m68k_op_illegal, 0xffff, 0x4afc, {4, 4, 4}},
    {&m68k_op_mull_32_aw, 0xffff, 0x4c38, {0, 0, 47}},
    {&m68k_op_mull_32_al, 0xffff, 0x4c39, {0, 0, 47}},
    {&m68k_op_mull_32_pcdi, 0xffff, 0x4c3a, {0, 0, 48}},
    {&m68k_op_mull_32_pcix, 0xffff, 0x4c3b, {0, 0, 50}},
    {&m68k_op_mull_32_i, 0xffff, 0x4c3c, {0, 0, 47}},
    {&m68k_op_divl_32_aw, 0xffff, 0x4c78, {0, 0, 88}},
    {&m68k_op_divl_32_al, 0xffff, 0x4c79, {0, 0, 88}},
    {&m68k_op_divl_32_pcdi, 0xffff, 0x4c7a, {0, 0, 89}},
    {&m68k_op_divl_32_pcix, 0xffff, 0x4c7b, {0, 0, 91}},
    {&m68k_op_divl_32_i, 0xffff, 0x4c7c, {0, 0, 88}},
    {&m68k_op_movem_16_er_aw, 0xffff, 0x4cb8, {20, 20, 12}},
    {&m68k_op_movem_16_er_al, 0xffff, 0x4cb9, {24, 24, 12}},
    {&m68k_op_movem_16_er_pcdi, 0xffff, 0x4cba, {20, 20, 13}},
    {&m68k_op_movem_16_er_pcix, 0xffff, 0x4cbb, {22, 22, 15}},
    {&m68k_op_movem_32_er_aw, 0xffff, 0x4cf8, {24, 24, 12}},
    {&m68k_op_movem_32_er_al, 0xffff, 0x4cf9, {28, 28, 12}},
    {&m68k_op_movem_32_er_pcdi, 0xffff, 0x4cfa, {24, 24, 13}},
    {&m68k_op_movem_32_er_pcix, 0xffff, 0x4cfb, {26, 26, 15}},
    {&m68k_op_link_16_a7, 0xffff, 0x4e57, {16, 16, 5}},
    {&m68k_op_unlk_32_a7, 0xffff, 0x4e5f, {12, 12, 6}},
    {&m68k_op_reset, 0xffff, 0x4e70, {0, 0, 0}},
    {&m68k_op_nop, 0xffff, 0x4e71, {4, 4, 2}},
    {&m68k_op_stop, 0xffff, 0x4e72, {4, 4, 8}},
    {&m68k_op_rte_32, 0xffff, 0x4e73, {20, 24, 20}},
    {&m68k_op_rtd_32, 0xffff, 0x4e74, {0, 16, 10}},
    {&m68k_op_rts_32, 0xffff, 0x4e75, {16, 16, 10}},
    {&m68k_op_trapv, 0xffff, 0x4e76, {4, 4, 4}},
    {&m68k_op_rtr_32, 0xffff, 0x4e77, {20, 20, 14}},
    {&m68k_op_movec_32_cr, 0xffff, 0x4e7a, {0, 12, 6}},
    {&m68k_op_movec_32_rc, 0xffff, 0x4e7b, {0, 10, 12}},
    {&m68k_op_jsr_32_aw, 0xffff, 0x4eb8, {18, 18, 4}},
    {&m68k_op_jsr_32_al, 0xffff, 0x4eb9, {20, 20, 4}},
    {&m68k_op_jsr_32_pcdi, 0xffff, 0x4eba, {18, 18, 5}},
    {&m68k_op_jsr_32_pcix, 0xffff, 0x4ebb, {22, 22, 7}},
    {&m68k_op_jmp_32_aw, 0xffff, 0x4ef8, {10, 10, 4}},
    {&m68k_op_jmp_32_al, 0xffff, 0x4ef9, {12, 12, 4}},
    {&m68k_op_jmp_32_pcdi, 0xffff, 0x4efa, {10, 10, 5}},
    {&m68k_op_jmp_32_pcix, 0xffff, 0x4efb, {14, 14, 7}},
    {&m68k_op_st_8_pi7, 0xffff, 0x50df, {12, 12, 10}},
    {&m68k_op_st_8_pd7, 0xffff, 0x50e7, {14, 14, 11}},
    {&m68k_op_st_8_aw, 0xffff, 0x50f8, {16, 16, 10}},
    {&m68k_op_st_8_al, 0xffff, 0x50f9, {20, 20, 10}},
    {&m68k_op_trapt_16, 0xffff, 0x50fa, {0, 0, 6}},
    {&m68k_op_trapt_32, 0xffff, 0x50fb, {0, 0, 8}},
    {&m68k_op_trapt, 0xffff, 0x50fc, {0, 0, 4}},
    {&m68k_op_sf_8_pi7, 0xffff, 0x51df, {12, 12, 10}},
    {&m68k_op_sf_8_pd7, 0xffff, 0x51e7, {14, 14, 11}},
    {&m68k_op_sf_8_aw, 0xffff, 0x51f8, {16, 16, 10}},
    {&m68k_op_sf_8_al, 0xffff, 0x51f9, {20, 20, 10}},
    {&m68k_op_trapf_16, 0xffff, 0x51fa, {0, 0, 6}},
    {&m68k_op_trapf_32, 0xffff, 0x51fb, {0, 0, 8}},
    {&m68k_op_trapf, 0xffff, 0x51fc, {0, 0, 4}},
    {&m68k_op_shi_8_pi7, 0xffff, 0x52df, {12, 12, 10}},
    {&m68k_op_shi_8_pd7, 0xffff, 0x52e7, {14, 14, 11}},
    {&m68k_op_shi_8_aw, 0xffff, 0x52f8, {16, 16, 10}},
    {&m68k_op_shi_8_al, 0xffff, 0x52f9, {20, 20, 10}},
    {&m68k_op_traphi_16, 0xffff, 0x52fa, {0, 0, 6}},
    {&m68k_op_traphi_32, 0xffff, 0x52fb, {0, 0, 8}},
    {&m68k_op_traphi, 0xffff, 0x52fc, {0, 0, 4}},
    {&m68k_op_sls_8_pi7, 0xffff, 0x53df, {12, 12, 10}},
    {&m68k_op_sls_8_pd7, 0xffff, 0x53e7, {14, 14, 11}},
    {&m68k_op_sls_8_aw, 0xffff, 0x53f8, {16, 16, 10}},
    {&m68k_op_sls_8_al, 0xffff, 0x53f9, {20, 20, 10}},
    {&m68k_op_trapls_16, 0xffff, 0x53fa, {0, 0, 6}},
    {&m68k_op_trapls_32, 0xffff, 0x53fb, {0, 0, 8}},
    {&m68k_op_trapls, 0xffff, 0x53fc, {0, 0, 4}},
    {&m68k_op_scc_8_pi7, 0xffff, 0x54df, {12, 12, 10}},
    {&m68k_op_scc_8_pd7, 0xffff, 0x54e7, {14, 14, 11}},
    {&m68k_op_scc_8_aw, 0xffff, 0x54f8, {16, 16, 10}},
    {&m68k_op_scc_8_al, 0xffff, 0x54f9, {20, 20, 10}},
    {&m68k_op_trapcc_16, 0xffff, 0x54fa, {0, 0, 6}},
    {&m68k_op_trapcc_32, 0xffff, 0x54fb, {0, 0, 8}},
    {&m68k_op_trapcc, 0xffff, 0x54fc, {0, 0, 4}},
    {&m68k_op_scs_8_pi7, 0xffff, 0x55df, {12, 12, 10}},
    {&m68k_op_scs_8_pd7, 0xffff, 0x55e7, {14, 14, 11}},
    {&m68k_op_scs_8_aw, 0xffff, 0x55f8, {16, 16, 10}},
    {&m68k_op_scs_8_al, 0xffff, 0x55f9, {20, 20, 10}},
    {&m68k_op_trapcs_16, 0xffff, 0x55fa, {0, 0, 6}},
    {&m68k_op_trapcs_32, 0xffff, 0x55fb, {0, 0, 8}},
    {&m68k_op_trapcs, 0xffff, 0x55fc, {0, 0, 4}},
    {&m68k_op_sne_8_pi7, 0xffff, 0x56df, {12, 12, 10}},
    {&m68k_op_sne_8_pd7, 0xffff, 0x56e7, {14, 14, 11}},
    {&m68k_op_sne_8_aw, 0xffff, 0x56f8, {16, 16, 10}},
    {&m68k_op_sne_8_al, 0xffff, 0x56f9, {20, 20, 10}},
    {&m68k_op_trapne_16, 0xffff, 0x56fa, {0, 0, 6}},
    {&m68k_op_trapne_32, 0xffff, 0x56fb, {0, 0, 8}},
    {&m68k_op_trapne, 0xffff, 0x56fc, {0, 0, 4}},
    {&m68k_op_seq_8_pi7, 0xffff, 0x57df, {12, 12, 10}},
    {&m68k_op_seq_8_pd7, 0xffff, 0x57e7, {14, 14, 11}},
    {&m68k_op_seq_8_aw, 0xffff, 0x57f8, {16, 16, 10}},
    {&m68k_op_seq_8_al, 0xffff, 0x57f9, {20, 20, 10}},
    {&m68k_op_trapeq_16, 0xffff, 0x57fa, {0, 0, 6}},
    {&m68k_op_trapeq_32, 0xffff, 0x57fb, {0, 0, 8}},
    {&m68k_op_trapeq, 0xffff, 0x57fc, {0, 0, 4}},
    {&m68k_op_svc_8_pi7, 0xffff, 0x58df, {12, 12, 10}},
    {&m68k_op_svc_8_pd7, 0xffff, 0x58e7, {14, 14, 11}},
    {&m68k_op_svc_8_aw, 0xffff, 0x58f8, {16, 16, 10}},
    {&m68k_op_svc_8_al, 0xffff, 0x58f9, {20, 20, 10}},
    {&m68k_op_trapvc_16, 0xffff, 0x58fa, {0, 0, 6}},
    {&m68k_op_trapvc_32, 0xffff, 0x58fb, {0, 0, 8}},
    {&m68k_op_trapvc, 0xffff, 0x58fc, {0, 0, 4}},
    {&m68k_op_svs_8_pi7, 0xffff, 0x59df, {12, 12, 10}},
    {&m68k_op_svs_8_pd7, 0xffff, 0x59e7, {14, 14, 11}},
    {&m68k_op_svs_8_aw, 0xffff, 0x59f8, {16, 16, 10}},
    {&m68k_op_svs_8_al, 0xffff, 0x59f9, {20, 20, 10}},
    {&m68k_op_trapvs_16, 0xffff, 0x59fa, {0, 0, 6}},
    {&m68k_op_trapvs_32, 0xffff, 0x59fb, {0, 0, 8}},
    {&m68k_op_trapvs, 0xffff, 0x59fc, {0, 0, 4}},
    {&m68k_op_spl_8_pi7, 0xffff, 0x5adf, {12, 12, 10}},
    {&m68k_op_spl_8_pd7, 0xffff, 0x5ae7, {14, 14, 11}},
    {&m68k_op_spl_8_aw, 0xffff, 0x5af8, {16, 16, 10}},
    {&m68k_op_spl_8_al, 0xffff, 0x5af9, {20, 20, 10}},
    {&m68k_op_trappl_16, 0xffff, 0x5afa, {0, 0, 6}},
    {&m68k_op_trappl_32, 0xffff, 0x5afb, {0, 0, 8}},
    {&m68k_op_trappl, 0xffff, 0x5afc, {0, 0, 4}},
    {&m68k_op_smi_8_pi7, 0xffff, 0x5bdf, {12, 12, 10}},
    {&m68k_op_smi_8_pd7, 0xffff, 0x5be7, {14, 14, 11}},
    {&m68k_op_smi_8_aw, 0xffff, 0x5bf8, {16, 16, 10}},
    {&m68k_op_smi_8_al, 0xffff, 0x5bf9, {20, 20, 10}},
    {&m68k_op_trapmi_16, 0xffff, 0x5bfa, {0, 0, 6}},
    {&m68k_op_trapmi_32, 0xffff, 0x5bfb, {0, 0, 8}},
    {&m68k_op_trapmi, 0xffff, 0x5bfc, {0, 0, 4}},
    {&m68k_op_sge_8_pi7, 0xffff, 0x5cdf, {12, 12, 10}},
    {&m68k_op_sge_8_pd7, 0xffff, 0x5ce7, {14, 14, 11}},
    {&m68k_op_sge_8_aw, 0xffff, 0x5cf8, {16, 16, 10}},
    {&m68k_op_sge_8_al, 0xffff, 0x5cf9, {20, 20, 10}},
    {&m68k_op_trapge_16, 0xffff, 0x5cfa, {0, 0, 6}},
    {&m68k_op_trapge_32, 0xffff, 0x5cfb, {0, 0, 8}},
    {&m68k_op_trapge, 0xffff, 0x5cfc, {0, 0, 4}},
    {&m68k_op_slt_8_pi7, 0xffff, 0x5ddf, {12, 12, 10}},
    {&m68k_op_slt_8_pd7, 0xffff, 0x5de7, {14, 14, 11}},
    {&m68k_op_slt_8_aw, 0xffff, 0x5df8, {16, 16, 10}},
    {&m68k_op_slt_8_al, 0xffff, 0x5df9, {20, 20, 10}},
    {&m68k_op_traplt_16, 0xffff, 0x5dfa, {0, 0, 6}},
    {&m68k_op_traplt_32, 0xffff, 0x5dfb, {0, 0, 8}},
    {&m68k_op_traplt, 0xffff, 0x5dfc, {0, 0, 4}},
    {&m68k_op_sgt_8_pi7, 0xffff, 0x5edf, {12, 12, 10}},
    {&m68k_op_sgt_8_pd7, 0xffff, 0x5ee7, {14, 14, 11}},
    {&m68k_op_sgt_8_aw, 0xffff, 0x5ef8, {16, 16, 10}},
    {&m68k_op_sgt_8_al, 0xffff, 0x5ef9, {20, 20, 10}},
    {&m68k_op_trapgt_16, 0xffff, 0x5efa, {0, 0, 6}},
    {&m68k_op_trapgt_32, 0xffff, 0x5efb, {0, 0, 8}},
    {&m68k_op_trapgt, 0xffff, 0x5efc, {0, 0, 4}},
    {&m68k_op_sle_8_pi7, 0xffff, 0x5fdf, {12, 12, 10}},
    {&m68k_op_sle_8_pd7, 0xffff, 0x5fe7, {14, 14, 11}},
    {&m68k_op_sle_8_aw, 0xffff, 0x5ff8, {16, 16, 10}},
    {&m68k_op_sle_8_al, 0xffff, 0x5ff9, {20, 20, 10}},
    {&m68k_op_traple_16, 0xffff, 0x5ffa, {0, 0, 6}},
    {&m68k_op_traple_32, 0xffff, 0x5ffb, {0, 0, 8}},
    {&m68k_op_traple, 0xffff, 0x5ffc, {0, 0, 4}},
    {&m68k_op_bra_16, 0xffff, 0x6000, {10, 10, 10}},
    {&m68k_op_bra_32, 0xffff, 0x60ff, {0, 0, 10}},
    {&m68k_op_bsr_16, 0xffff, 0x6100, {18, 18, 7}},
    {&m68k_op_bsr_32, 0xffff, 0x61ff, {0, 0, 7}},
    {&m68k_op_bhi_16, 0xffff, 0x6200, {10, 10, 6}},
    {&m68k_op_bhi_32, 0xffff, 0x62ff, {0, 0, 6}},
    {&m68k_op_bls_16, 0xffff, 0x6300, {10, 10, 6}},
    {&m68k_op_bls_32, 0xffff, 0x63ff, {0, 0, 6}},
    {&m68k_op_bcc_16, 0xffff, 0x6400, {10, 10, 6}},
    {&m68k_op_bcc_32, 0xffff, 0x64ff, {0, 0, 6}},
    {&m68k_op_bcs_16, 0xffff, 0x6500, {10, 10, 6}},
    {&m68k_op_bcs_32, 0xffff, 0x65ff, {0, 0, 6}},
    {&m68k_op_bne_16, 0xffff, 0x6600, {10, 10, 6}},
    {&m68k_op_bne_32, 0xffff, 0x66ff, {0, 0, 6}},
    {&m68k_op_beq_16, 0xffff, 0x6700, {10, 10, 6}},
    {&m68k_op_beq_32, 0xffff, 0x67ff, {0, 0, 6}},
    {&m68k_op_bvc_16, 0xffff, 0x6800, {10, 10, 6}},
    {&m68k_op_bvc_32, 0xffff, 0x68ff, {0, 0, 6}},
    {&m68k_op_bvs_16, 0xffff, 0x6900, {10, 10, 6}},
    {&m68k_op_bvs_32, 0xffff, 0x69ff, {0, 0, 6}},
    {&m68k_op_bpl_16, 0xffff, 0x6a00, {10, 10, 6}},
    {&m68k_op_bpl_32, 0xffff, 0x6aff, {0, 0, 6}},
    {&m68k_op_bmi_16, 0xffff, 0x6b00, {10, 10, 6}},
    {&m68k_op_bmi_32, 0xffff, 0x6bff, {0, 0, 6}},
    {&m68k_op_bge_16, 0xffff, 0x6c00, {10, 10, 6}},
    {&m68k_op_bge_32, 0xffff, 0x6cff, {0, 0, 6}},
    {&m68k_op_blt_16, 0xffff, 0x6d00, {10, 10, 6}},
    {&m68k_op_blt_32, 0xffff, 0x6dff, {0, 0, 6}},
    {&m68k_op_bgt_16, 0xffff, 0x6e00, {10, 10, 6}},
    {&m68k_op_bgt_32, 0xffff, 0x6eff, {0, 0, 6}},
    {&m68k_op_ble_16, 0xffff, 0x6f00, {10, 10, 6}},
    {&m68k_op_ble_32, 0xffff, 0x6fff, {0, 0, 6}},
    {&m68k_op_sbcd_8_mm_axy7, 0xffff, 0x8f0f, {18, 18, 16}},
    {&m68k_op_pack_16_mm_axy7, 0xffff, 0x8f4f, {0, 0, 13}},
    {&m68k_op_unpk_16_mm_axy7, 0xffff, 0x8f8f, {0, 0, 13}},
    {&m68k_op_subx_8_mm_axy7, 0xffff, 0x9f0f, {18, 18, 12}},
    {&m68k_op_cmpm_8_axy7, 0xffff, 0xbf0f, {12, 12, 9}},
    {&m68k_op_abcd_8_mm_axy7, 0xffff, 0xcf0f, {18, 18, 16}},
    {&m68k_op_addx_8_mm_axy7, 0xffff, 0xdf0f, {18, 18, 12}},
    {&m68k_op_asr_16_aw, 0xffff, 0xe0f8, {16, 16, 9}},
    {&m68k_op_asr_16_al, 0xffff, 0xe0f9, {20, 20, 9}},
    {&m68k_op_asl_16_aw, 0xffff, 0xe1f8, {16, 16, 10}},
    {&m68k_op_asl_16_al, 0xffff, 0xe1f9, {20, 20, 10}},
    {&m68k_op_lsr_16_aw, 0xffff, 0xe2f8, {16, 16, 9}},
    {&m68k_op_lsr_16_al, 0xffff, 0xe2f9, {20, 20, 9}},
    {&m68k_op_lsl_16_aw, 0xffff, 0xe3f8, {16, 16, 9}},
    {&m68k_op_lsl_16_al, 0xffff, 0xe3f9, {20, 20, 9}},
    {&m68k_op_roxr_16_aw, 0xffff, 0xe4f8, {16, 16, 9}},
    {&m68k_op_roxr_16_al, 0xffff, 0xe4f9, {20, 20, 9}},
    {&m68k_op_roxl_16_aw, 0xffff, 0xe5f8, {16, 16, 9}},
    {&m68k_op_roxl_16_al, 0xffff, 0xe5f9, {20, 20, 9}},
    {&m68k_op_ror_16_aw, 0xffff, 0xe6f8, {16, 16, 11}},
    {&m68k_op_ror_16_al, 0xffff, 0xe6f9, {20, 20, 11}},
    {&m68k_op_rol_16_aw, 0xffff, 0xe7f8, {16, 16, 11}},
    {&m68k_op_rol_16_al, 0xffff, 0xe7f9, {20, 20, 11}},
    {&m68k_op_bftst_32_aw, 0xffff, 0xe8f8, {0, 0, 17}},
    {&m68k_op_bftst_32_al, 0xffff, 0xe8f9, {0, 0, 17}},
    {&m68k_op_bftst_32_pcdi, 0xffff, 0xe8fa, {0, 0, 18}},
    {&m68k_op_bftst_32_pcix, 0xffff, 0xe8fb, {0, 0, 20}},
    {&m68k_op_bfextu_32_aw, 0xffff, 0xe9f8, {0, 0, 19}},
    {&m68k_op_bfextu_32_al, 0xffff, 0xe9f9, {0, 0, 19}},
    {&m68k_op_bfextu_32_pcdi, 0xffff, 0xe9fa, {0, 0, 20}},
    {&m68k_op_bfextu_32_pcix, 0xffff, 0xe9fb, {0, 0, 22}},
    {&m68k_op_bfchg_32_aw, 0xffff, 0xeaf8, {0, 0, 24}},
    {&m68k_op_bfchg_32_al, 0xffff, 0xeaf9, {0, 0, 24}},
    {&m68k_op_bfexts_32_aw, 0xffff, 0xebf8, {0, 0, 19}},
    {&m68k_op_bfexts_32_al, 0xffff, 0xebf9, {0, 0, 19}},
    {&m68k_op_bfexts_32_pcdi, 0xffff, 0xebfa, {0, 0, 20}},
    {&m68k_op_bfexts_32_pcix, 0xffff, 0xebfb, {0, 0, 22}},
    {&m68k_op_bfclr_32_aw, 0xffff, 0xecf8, {0, 0, 24}},
    {&m68k_op_bfclr_32_al, 0xffff, 0xecf9, {0, 0, 24}},
    {&m68k_op_bfffo_32_aw, 0xffff, 0xedf8, {0, 0, 32}},
    {&m68k_op_bfffo_32_al, 0xffff, 0xedf9, {0, 0, 32}},
    {&m68k_op_bfffo_32_pcdi, 0xffff, 0xedfa, {0, 0, 33}},
    {&m68k_op_bfffo_32_pcix, 0xffff, 0xedfb, {0, 0, 35}},
    {&m68k_op_bfset_32_aw, 0xffff, 0xeef8, {0, 0, 24}},
    {&m68k_op_bfset_32_al, 0xffff, 0xeef9, {0, 0, 24}},
    {&m68k_op_bfins_32_aw, 0xffff, 0xeff8, {0, 0, 21}},
    {&m68k_op_bfins_32_al, 0xffff, 0xeff9, {0, 0, 21}},
    {0, 0, 0, {0, 0, 0}}};

U0 m68ki_build_opcode_table() {
  opcode_handler_struct *ostruct;
  I32 instr;
  I32 i;
  I32 j;
  I32 k;

  for (i = 0; i < 0x10000; i++) {
    m68ki_instruction_jump_table[i] = &m68k_op_illegal;
    for (k = 0; k < NUM_CPU_TYPES; k++)
      m68ki_cycles[k][i] = 0;
  }

  ostruct = m68k_opcode_handler_table;
  while (ostruct->mask != 0xff00) {
    for (i = 0; i < 0x10000; i++) {
      if ((i & ostruct->mask) == ostruct->match) {
        m68ki_instruction_jump_table[i] = ostruct->opcode_handler;
        for (k = 0; k < NUM_CPU_TYPES; k++)
          m68ki_cycles[k][i] = ostruct->cycles[k];
      }
    }
    ostruct++;
  }
  while (ostruct->mask == 0xff00) {
    for (i = 0; i <= 0xff; i++) {
      m68ki_instruction_jump_table[ostruct->match | i] =
          ostruct->opcode_handler;
      for (k = 0; k < NUM_CPU_TYPES; k++)
        m68ki_cycles[k][ostruct->match | i] = ostruct->cycles[k];
    }
    ostruct++;
  }
  while (ostruct->mask == 0xf1f8) {
    for (i = 0; i < 8; i++) {
      for (j = 0; j < 8; j++) {
        instr = ostruct->match | (i << 9) | j;
        m68ki_instruction_jump_table[instr] = ostruct->opcode_handler;
        for (k = 0; k < NUM_CPU_TYPES; k++)
          m68ki_cycles[k][instr] = ostruct->cycles[k];
        if ((instr & 0xf000) == 0xe000 && (!(instr & 0x20)))
          m68ki_cycles[0][instr] = m68ki_cycles[1][instr] =
              ostruct->cycles[k] + ((((j - 1) & 7) + 1) << 1);
      }
    }
    ostruct++;
  }
  while (ostruct->mask == 0xfff0) {
    for (i = 0; i <= 0x0f; i++) {
      m68ki_instruction_jump_table[ostruct->match | i] =
          ostruct->opcode_handler;
      for (k = 0; k < NUM_CPU_TYPES; k++)
        m68ki_cycles[k][ostruct->match | i] = ostruct->cycles[k];
    }
    ostruct++;
  }
  while (ostruct->mask == 0xf1ff) {
    for (i = 0; i <= 0x07; i++) {
      m68ki_instruction_jump_table[ostruct->match | (i << 9)] =
          ostruct->opcode_handler;
      for (k = 0; k < NUM_CPU_TYPES; k++)
        m68ki_cycles[k][ostruct->match | (i << 9)] = ostruct->cycles[k];
    }
    ostruct++;
  }
  while (ostruct->mask == 0xfff8) {
    for (i = 0; i <= 0x07; i++) {
      m68ki_instruction_jump_table[ostruct->match | i] =
          ostruct->opcode_handler;
      for (k = 0; k < NUM_CPU_TYPES; k++)
        m68ki_cycles[k][ostruct->match | i] = ostruct->cycles[k];
    }
    ostruct++;
  }
  while (ostruct->mask == 0xffff) {
    m68ki_instruction_jump_table[ostruct->match] = ostruct->opcode_handler;
    for (k = 0; k < NUM_CPU_TYPES; k++)
      m68ki_cycles[k][ostruct->match] = ostruct->cycles[k];
    ostruct++;
  }
}

m68ki_build_opcode_table;

U0 m68k_set_cpu_type(U32 cpu_type) {
  switch (cpu_type) {
  case M68K_CPU_TYPE_68000:
    m68ki_cpu.cpu_type = 1;
    m68ki_cpu.address_mask = 0x00ffffff;
    m68ki_cpu.sr_mask = 0xa71f;
    m68ki_cpu.cyc_instruction = m68ki_cycles[0];
    m68ki_cpu.cyc_exception = m68ki_exception_cycle_table[0];
    m68ki_cpu.cyc_bcc_notake_b = -2;
    m68ki_cpu.cyc_bcc_notake_w = 2;
    m68ki_cpu.cyc_dbcc_f_noexp = -2;
    m68ki_cpu.cyc_dbcc_f_exp = 2;
    m68ki_cpu.cyc_scc_r_false = 2;
    m68ki_cpu.cyc_movem_w = 2;
    m68ki_cpu.cyc_movem_l = 3;
    m68ki_cpu.cyc_shift = 1;
    m68ki_cpu.cyc_reset = 132;
    return;
  case M68K_CPU_TYPE_68010:
    m68ki_cpu.cpu_type = 2;
    m68ki_cpu.address_mask = 0x00ffffff;
    m68ki_cpu.sr_mask = 0xa71f;
    m68ki_cpu.cyc_instruction = m68ki_cycles[1];
    m68ki_cpu.cyc_exception = m68ki_exception_cycle_table[1];
    m68ki_cpu.cyc_bcc_notake_b = -4;
    m68ki_cpu.cyc_bcc_notake_w = 0;
    m68ki_cpu.cyc_dbcc_f_noexp = 0;
    m68ki_cpu.cyc_dbcc_f_exp = 6;
    m68ki_cpu.cyc_scc_r_false = 0;
    m68ki_cpu.cyc_movem_w = 2;
    m68ki_cpu.cyc_movem_l = 3;
    m68ki_cpu.cyc_shift = 1;
    m68ki_cpu.cyc_reset = 130;
    return;
  case M68K_CPU_TYPE_68EC020:
    m68ki_cpu.cpu_type = 4;
    m68ki_cpu.address_mask = 0x00ffffff;
    m68ki_cpu.sr_mask = 0xf71f;
    m68ki_cpu.cyc_instruction = m68ki_cycles[2];
    m68ki_cpu.cyc_exception = m68ki_exception_cycle_table[2];
    m68ki_cpu.cyc_bcc_notake_b = -2;
    m68ki_cpu.cyc_bcc_notake_w = 0;
    m68ki_cpu.cyc_dbcc_f_noexp = 0;
    m68ki_cpu.cyc_dbcc_f_exp = 4;
    m68ki_cpu.cyc_scc_r_false = 0;
    m68ki_cpu.cyc_movem_w = 2;
    m68ki_cpu.cyc_movem_l = 2;
    m68ki_cpu.cyc_shift = 0;
    m68ki_cpu.cyc_reset = 518;
    return;
  case M68K_CPU_TYPE_68020:
    m68ki_cpu.cpu_type = 8;
    m68ki_cpu.address_mask = 0xffffffff;
    m68ki_cpu.sr_mask = 0xf71f;
    m68ki_cpu.cyc_instruction = m68ki_cycles[2];
    m68ki_cpu.cyc_exception = m68ki_exception_cycle_table[2];
    m68ki_cpu.cyc_bcc_notake_b = -2;
    m68ki_cpu.cyc_bcc_notake_w = 0;
    m68ki_cpu.cyc_dbcc_f_noexp = 0;
    m68ki_cpu.cyc_dbcc_f_exp = 4;
    m68ki_cpu.cyc_scc_r_false = 0;
    m68ki_cpu.cyc_movem_w = 2;
    m68ki_cpu.cyc_movem_l = 2;
    m68ki_cpu.cyc_shift = 0;
    m68ki_cpu.cyc_reset = 518;
    return;
  }
}

U0 m68k_pulse_reset() {
  U32 emulation_initialized = 0;

  if (!emulation_initialized) {
    emulation_initialized = 1;
  }

  if (m68ki_cpu.cpu_type == 0)
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);

  m68ki_cpu.stopped = 0;
  m68ki_remaining_cycles = 0;

  m68ki_cpu.t1_flag = m68ki_cpu.t0_flag = 0;
  ;

  m68ki_cpu.int_mask = 0x0700;

  m68ki_cpu.vbr = 0;

  m68ki_set_sm_flag(4 | 0);
  m68ki_jump(0);
  m68ki_cpu.dar[15] = m68ki_read_imm_32();
  m68ki_cpu.pc = m68ki_read_imm_32();
  m68ki_jump(m68ki_cpu.pc);
}
