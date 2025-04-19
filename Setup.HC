DocClear;
"\nInstall the FR keyboard layout for TempleOS ";

if (YorN)
{
    Copy("HomeKeyPlugInsFR.HC", "~/HomeKeyPlugIns.HC");
    "\n\nReboot Now ";
    if (YorN)
        Reboot;
}
else
    "\nSetup aborted !\n";

DocClear;

"\nSet Gruvbox theme ";

if (YorN)
{
    #include "~/skins/Gruvbox/Gruvbox.HC"
}
else
    "\nSetup aborted !\n";


