//GrFancyPutS()/GrFancyPrint() live in $LK,"::/Adam/Gr/GrComposites.HC"$.

U0 DemoFancyTextDrawIt(CTask *,CDC *dc)
{
  GrFancyPrint(dc,20,20,YELLOW,DKGRAY,BLACK,"TinkerOS");
  GrFancyPrint(dc,20,40,LTGREEN,DKGRAY,BLACK,"GrFancyPrint() Demo");
  GrFancyPrint(dc,20,60,LTCYAN,LTGRAY,BLACK,"Any colors, any string");

  dc->color=BLACK;
  GrRect(dc,18,77,180,14);
  GrFancyPrint(dc,20,80,LTRED,BLACK, WHITE,"Any two borders colors");


  GrFancyPrint(dc,20,120,YELLOW,DKGRAY,BLACK,"Or Blink and HV_SWAP!");

  if (Blink)
    GrFancyPrint(dc,20,100,YELLOW,DKGRAY,BLACK,"And of course Blinky Blink!");
  else
  {
    dc->color=ROP_HV_SWAP+HV_SWAP_ALL;
    GrRect(dc,20,119,168,11);
  }

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
