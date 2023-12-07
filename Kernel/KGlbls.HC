//Compiler initializes glbls in AOT bin modules to zero.
//$LK,"Globals Set to Zero Here",A="FF:::/Compiler/PrsStmt.HC,Init AOT glbl to zero"$.

CJob sys_macro_head;
CTask *sys_macro_task;
CDoc *sys_clip_doc;

I64 fps_master=30;
I64 blink_master_flag=1;
I64 scroll_master_flag=1;

CTask *adam_task;
CTask *last_init_task=NULL;

CGrGlbls gr;
CWinMgrGlbls winmgr= {0,0,0,WINMGR_FPS,0,0,NULL,FALSE,FALSE,FALSE};

I64 sys_num_spawned_tasks;

CTask *sys_winmgr_task,*sys_task_being_scrn_updated;
U8 *rev_bits_table, //Table with U8 bits revd
*set_bits_table; //Table with count of set bits in a U8
CDate local_time_offset;
F64	*pow10_I64,
    sys_os_version=5.120;

CAutoCompleteDictGlbls acd;
CAutoCompleteGlbls ac;
CBlkDevGlbls	blkdev;
CCntsGlbls	cnts= {1,0,2676302000,2676302,2676302000,FALSE};
CDbgGlbls	dbg;
CDevGlbls	dev;
CGridGlbls	ms_grid; //See $LK,"::/Demo/Graphics/Grid.HC"$.
CMsStateGlbls	ms,ms_last;
CKbdStateGlbls	kbd;
CKeyDevGlbls	keydev;
CMsHardStateGlbls ms_hard,ms_hard_last;
CScrnCastGlbls	scrncast;
CSndGlbls   snd;
CTextGlbls	text;

ms_hard.installed=FALSE;

U8  *(*fp_getstr2)(I64 flags=0);
U0 (*fp_update_ctrls)(CTask *task);
CDoc *(*fp_doc_put)(CTask *task=NULL);
U0 (*fp_set_std_palette)();
U8 *key_state, *sc_state;
I64 sc_flags_state;

I64 sys_num_usb=0;
CUSB sys_usb_devs[USB_NUM];

Bool BlkDevLtrOverride[26];
Bool AHCIMode=FALSE;
U32 hype_info[4];

I64 MCFGTableAddr=NULL;

Bool (*fp_serial_blkdev_init)()=NULL;
Bool (*fp_serial_blkdev_deinit)()=NULL;
Bool (*fp_serial_blkdev_read)(U8* buf, I64 blk, I64 cnt)=NULL;
Bool (*fp_serial_blkdev_write)(U8* buf, I64 blk, I64 cnt)=NULL;
I64 (*fp_serial_blkdev_get_max)()=NULL;

Bool (*fp_virtual_blkdev_init)()=NULL;
Bool (*fp_virtual_blkdev_deinit)()=NULL;
Bool (*fp_virtual_blkdev_read)(U8* buf, I64 blk, I64 cnt)=NULL;
Bool (*fp_virtual_blkdev_write)(U8* buf, I64 blk, I64 cnt)=NULL;
I64 (*fp_virtual_blkdev_get_max)()=NULL;

CDC *gr_alt_scrn=NULL;

