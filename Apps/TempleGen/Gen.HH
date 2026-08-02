#define GEN_SCRN_W	320
#define GEN_SCRN_H	240

#define GEN_OVERSCAN	8

#define GEN_PAL_EXTRA_BASE	230
#define GEN_PAL_EXTRA_CNT	25

I64 T(I64 val, I64 if_true, I64 if_false)
{
	if (val)
		return if_true;
	return if_false;
}

Bool KeyDown(I64 sc)
{
	return Bt(kbd.down_bitmap, sc);
}

#define GEN_ROM_SIZE	0x400000
U8 *ROM = NULL;
U8 *RAM = NULL;
U8 *ZRAM = NULL;

CDC *gameCanvas = NULL;
CDC *gameCanvas2 = NULL;
CDC *gen_shown_canvas = NULL;
CDC *gameCanvas2x = NULL;

CBGR48 gen_sys_palette[COLORS_NUM];
CBGR48 gen_sys_extra[GEN_PAL_EXTRA_CNT];

U8 gen_state_filename[256];
