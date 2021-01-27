Cd(__DIR__);;

//If these are not present in /Home, it uses the version in the root dir.  You
//can make your own, modified, version of these files in your /Home directory.
#include "~/HomeLocalize"

// Comment these if you do not want extra utilities

#include "/Adam/Opt/Boot/MakeBoot"
#include "/Adam/Opt/Utils/MakeUtils"

// Comment these if you do not want autocomplete

#include "/Adam/AutoComplete/ACInit"
Silent;       //no output to scrn
ACInit("/*;!*/Bible.TXT*");
Silent(OFF); //no output to scrn

#include "~/HomeWrappers"
MapFileLoad("::/Kernel/Kernel");
MapFileLoad("::/Compiler/Compiler");
#include "~/HomeKeyPlugIns"
#include "~/HomeSys"
Cd("..");;
