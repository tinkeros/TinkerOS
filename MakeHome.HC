Cd(__DIR__);;

//If these are not present in /Home, it uses the version in the root dir.  You
//can make your own, modified, version of these files in your /Home directory.
#include "~/HomeLocalize"

// Comment these if you do not want extra utilities

#include "/Adam/Opt/Boot/MakeBoot"
#include "/Adam/Opt/Utils/MakeUtils"

// Comment this if you do not want autocomplete
SethFile("/Adam/AutoComplete/DoACInit",-1);

// Uncomment these to enable networking

//#include "/Demo/Net/Load"
//NetCfg;
//Cd;

// TODO retest network

// Misc helper functions
U0 AutoHome()
{
  MountAuto(1);
  Cdd("C:/Home");
}

// Experimental FM 801 sound card OPL support
#include "/Demo/Snd/FM801"

// Enable ISA OPL sounds if detected
#include "/Demo/Snd/OPL2"

// Enable Virtualbox guest additions if detected
SethFile("/Demo/VM/VBoxAdd",-2);

#include "~/HomeWrappers"
MapFileLoad("::/Kernel/Kernel");
MapFileLoad("::/Compiler/Compiler");
#include "~/HomeKeyPlugIns"
#include "~/HomeSys"
Cd("..");;
