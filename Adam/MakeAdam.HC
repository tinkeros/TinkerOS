Cd(__DIR__);;
#include "/Kernel/KCfg.HH"
#include "AExts"
#include "AMath"
#include "AMathODE"
#include "Gr/MakeGr"
#include "AMem"
#include "Training"
#include "ASnd"
#include "ABlkDev/MakeABlkDev"
#include "Menu"
#include "Win"
#include "WinMgr"
SetFPS(10); // slow FPS while compiling below
#include "ADbg"
#include "::/Adam/God/GodExt"
#include "DolDoc/MakeDoc"
LBts(&sys_run_level,RLf_DOC);
#include "Find"
#include "Ctrls/MakeCtrls"
#include "InFile"
#include "ARegistry"
#include "InsReg"
#include "AutoComplete/MakeAC"
#include "God/MakeGod"
#include "AHash"
#include "TaskSettings"
#include "ADefine"
#include "WallPaper"
#include "AMouse"
#include "Host"
#include "Opt/Utils/Comm"
Cd("..");;
if (mp_cnt>1)
  EnableSethGfx;
SetFPS(30); // restore default FPS now
