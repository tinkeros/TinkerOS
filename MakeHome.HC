Cd(__DIR__);;

//If these are not present in /Home, it uses the version in the root dir.  You
//can make your own, modified, version of these files in your /Home directory.
#include "~/HomeLocalize"

// Comment these if you do not want extra utilities
#include "/Adam/Opt/Boot/MakeBoot"
#include "/Adam/Opt/Utils/MakeUtils"

// Comment this if you do not want autocomplete
AdamFile("/Adam/AutoComplete/DoACInit");

// Comment this if you don't want Ed to pop-up warnings
// to help prevent overwriting already changed file.
doc_ed_warn_overwrite=TRUE;
// Comment this if you don't want Ed to pop-up warnings
// to help prevent opening the same file twice.
doc_ed_warn_already_open=TRUE;

// Misc helper functions
U0 AutoHome()
{
  MountAuto(1);
  Cdd("C:/Home");
}

// Experimental FM 801 sound card OPL support
#include "/Demo/Snd/FM801"

if (IsHypervisorPresent) {
  // AC97 sound support
  AdamFile("/Demo/VM/AC97");
  // Enable experimental Virtualbox guest additions if detected
  // SethFile("/Demo/VM/VBoxAdd",-2);
  //
  // Enable VMW mouse if detected
  // Better mouse performance, but breaks raw mouse mode
  AdamFile("/Demo/VM/VMMouse");
  // Try enabling ISA OPL sounds if VM detected
  AdamFile("/Demo/Snd/OPL2");
}
else {
#ifdef FM801_OPL_BASE
  AdamFile("/Demo/Snd/OPL2");
#endif
}

#include "~/HomeWrappers"
MapFileLoad("::/Kernel/Kernel");
MapFileLoad("::/Compiler/Compiler");
#include "~/HomeKeyPlugIns"
#include "~/HomeSys"
Cd("..");;
