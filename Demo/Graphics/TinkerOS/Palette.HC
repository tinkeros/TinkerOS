// Demo 238 default colors available in TinkerOS

U0 PaletteDemo()
{
  CDC *dc=DCAlias;
  SettingsPush;
  WinMax;
  ms.show=0;
  if (!PaintPalGet)
    PaintPalInit(dc);

  "\nPress any key to exit demo.\n\n";

  Sleep(1000);

  while (!ScanChar)
  {
    GrBlot(dc,0,0,PaintPalGet);
    Sleep(1);
  }

  DCFill(dc);
  DCDel(dc);
  SettingsPop;
  ms.show=1;
}

PaletteDemo;

