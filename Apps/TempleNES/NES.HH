#define NES_SCRN_W	256
#define NES_SCRN_H	240
#define NES_OVERSCAN	8
#define MIRR_HORZ		0
#define MIRR_VERT		1
#define MIRR_SINGLE		2
#define MIRR_FOUR		3
#define MIRR_SINGLE_UPPER	4

U8 *cartridgebuffer=NULL;
I64 numPRGROM,
    numCHRROM,
    controlByte1,
    mapper,
    mirroringType=MIRR_VERT;

//IRQ lines into the 6502, polled once per instruction by the main loop
Bool papu_request_irq=FALSE, mapper_request_irq=FALSE;

//The PPU renders into gameCanvas; NESDrawWindow (Emu.HC) blits it (or
//a pre-doubled copy in gameCanvas2x) into the task window.
CDC *gameCanvas=NULL, *gameCanvas2x=NULL;

CBGR48 nes_sys_palette[COLORS_NUM];

//Sprite fetched onto the current scanline (secondary OAM)
class PPUsprite {
  U8 shifts_remaining;
  U8 sprite_index;
  U8 byte2;
  U8 shift_register_0;
  U8 shift_register_1;
  U8 attribute;
  U8 x;
};

//Complete 2C02 PPU state (also snapshotted whole into save states)
class PPU2C02state {
  U8 odd_frame;
  U16 scanline;
  U16 dot;
  
  U8 nmi_occurred;
  

  U8 nmi_output;
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
