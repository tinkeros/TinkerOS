U0 ShowVolume()
{
  progress3=GetVolume;
  StrPrint(progress3_desc, "Volume %d %%",progress3);
  progress3_max=100;
  Sleep(1000);
  progress3_max=0;
}

