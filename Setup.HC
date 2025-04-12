DocClear;
"\nInstall FKey for TempleOS ";

if (YorN)
{
    Copy("HomeKeyPlugInsFR.HC", "~/HomeKeyPlugIns.HC");
    "\n\nReboot Now ";
    if (YorN)
        ExitAiwnios;
}
else
    "\nSetup aborted !\n";

