//GrFancyPutS()/GrFancyPrint() live in $LK,"::/Adam/Gr/GrComposites.HC"$.

U0 DemoFancyTextDrawIt(CTask *,CDC *dc)
{
  GrFancyPrint(dc,20,20,YELLOW,   DKGRAY,BLACK,"TinkerOS");
  GrFancyPrint(dc,20,40,LTGREEN,  DKGRAY,BLACK,"GrFancyPrint() Demo");
  GrFancyPrint(dc,20,60,LTCYAN,   LTGRAY,BLACK,"Any color, any string");
  GrFancyPrint(dc,20,80,LTRED,    BLACK, WHITE,"Even inverted borders");
  if (Blink) GrFancyPrint(dc,20,100,YELLOW,   DKGRAY,BLACK,"And of course Blinky Blink!!!");
}

U0 DemoFancyText()
{
  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  DocClear;
  Fs->draw_it=&DemoFancyTextDrawIt;
  while (!ScanChar)
    Sleep(50);
  SettingsPop;
}

DemoFancyText;
