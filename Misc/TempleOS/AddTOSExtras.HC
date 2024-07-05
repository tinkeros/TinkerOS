Cd(__DIR__);;

// This file is used to add some
// new features from TinkerOS to
// a TempleOS install.

// Please give credit to TinkerOS
// if you pull these into your own fork!

Bool silent=Silent(1);
Bool AHCIMode=FALSE;

#define PCIR_SUB_CODE 0x0A
#define PCIR_BASE0 0x10
#define PCIR_BASE5 0x24
#define FB_WIDTH 640
#define FB_HEIGHT 480

#include "/Kernel/StrC"
#include "/Kernel/BlkDev/DskDrvB"
#include "/Kernel/BlkDev/DskDirC"
#include "/Kernel/BlkDev/DskStrC"
#include "/Adam/Device/Comm"
#include "/Adam/DolDoc/DocFileB"
#include "/Adam/Opt/Utils/Adam"
#include "/Adam/Opt/Utils/SysRep"
#include "/Adam/Opt/Utils/TaskRep"
#include "/Adam/Opt/Utils/MD5"
#include "/Adam/Opt/Utils/FileBMP"
#include "/Adam/Opt/Utils/SethUtil"
#include "/Adam Opt/Utils/TOSClient"
#include "/Demo/Snd/OPL2"

Cd(__DIR__);;
Silent(silent);
