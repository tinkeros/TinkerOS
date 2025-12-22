DocClear;
"\nWould you like to install the French keyboard layout ";

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

"\nWould you like to set Gruvbox theme ";

if (YorN)
{
    #include "~/skins/Gruvbox/Gruvbox.HC"
}
else
    "\nSetup aborted !\n";


