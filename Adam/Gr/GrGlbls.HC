#help_index "Graphics"

public CBGR24 gr_palette[PAL_COLORS_NUM];

//See $LK,"RLf_VGA",A="FF:::/Kernel/KStart16.HC,RLf_VGA"$
//See $LK,"SysGrInit",A="MN:SysGrInit"$()
//Allows consts to be used instead of vars.
HashPublic("GR_WIDTH",HTT_DEFINE_STR);;
HashPublic("GR_HEIGHT",HTT_DEFINE_STR);;

#help_index "Char;TextBase Layer/Char"
DefinePrint("TEXT_ROWS","%d",text.rows);;;
HashPublic("TEXT_ROWS",HTT_DEFINE_STR);;;
DefinePrint("TEXT_COLS","%d",text.cols);;;
HashPublic("TEXT_COLS",HTT_DEFINE_STR);;;
