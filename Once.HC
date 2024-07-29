//Place this file in /Home and change
//anything you want.

//This file is executed by the
//first terminal window upon start-up.
//See $LK,"Once",A="FF:~/HomeSys.HC,Once"$ and $LK,"Home Files",A="FF:::/Doc/GuideLines.DD,/Home Files"$.

//Delete the rest from this file.

U0 Tmp()
{
  I64 old_silent;
  OnceExe;
  if(!DrvMounted('C')&&!DrvMounted('T')&&!AHCIMode)
  {
    old_silent=Silent;
    while (ms_hard.install_in_progress) Yield;
    SwitchToAHCI;
    Silent(old_silent);
  }
  switch (sys_boot_src.u16[0])
  {
  case BOOT_SRC_ROM:
    "Continue booting hard drive "
    ;
    if (YorN)
    {
      DocBottom;
      ExeFile("C:/Home/Once");
    }
    break;
  case BOOT_SRC_DVD:
    "\nIf you answer 'No' you can play with\n"
    "the live CD without installing.\n\n"
    "Install onto hard drive "
    ;
    if (YorN)
    {
      DocBottom;
      RunFile("::/Misc/OSInstall",,TRUE);
    }
    if (FileFind("::/Misc/Tour"))
    {
      "\nTake Tour";
      if (YorN)
      {
        DocBottom;
        Cd("::/Misc/Tour");
        InFile("Tour");
      }
    }
    break;
  case BOOT_SRC_RAM:
  case BOOT_SRC_HARDDRV:
    if ((!Bt(&sys_run_level,RLf_VGA)) && !GR_TEXT_MODE)
    {
      "Welcome to TinkerOS text mode!\n\n";
      "It appears you are here unexpectedly.\n\n";
      "This is because the video resolution\n";
      "you selected is not supported by your\n";
      "hardware (perhalps you selected the\n";
      "wrong mode or changed your monitor\n"
      ,
      "recently?).\n\n";
      "If you are an advanced user you can\n";
      "manually re-install the kernel and\n";
      "change it using BootHDIns.  Otherwise\n";
      "perform a manual re-install of this\n";
      "partition using a lower resolution.\n\n";
      "For a quick fix to try 640x480\n";
      "instead run Do640x480;\n\n";
    }
    else
    {
      "$$PURPLE$$$$TX+CX,\"Tip of the Day\"$$$$FG$$\n"
      ;
      TipOfDay;
      Type("::/Doc/Customize.DD");
      if (FileFind("::/Misc/Tour"))
      {
        "\nTake Tour";
        if (YorN)
        {
          DocBottom;
          Cd("::/Misc/Tour");
          InFile("Tour");
        }
      }
    }
    break;
  }
}

//#exe { if (SNAILNET_NATIVE_DRIVER != NULL) StreamPrint("Netcfg;\n"); }
Tmp;
