#help_index "Video"

public U0 VidModes()
{// List detected video resolutions possible.
  I64 i;
  "Detected resolution options:\n\n";
  for (i=0;i<32;i++)
  {
    if (vbe_vid_modes[i])
    {
      "  %dx%d\n",vbe_vid_modes[i].u16[1],vbe_vid_modes[i].u16[0];
    }
  }
  "\n";
}

Bool CheckVidMode(I64 width, I64 height, I64 scale=1)
{
  I64 i;
  for (i=0;i<32;i++)
  {
    if (vbe_vid_modes[i])
    {
      if (width == vbe_vid_modes[i].u16[1]/scale && height == vbe_vid_modes[i].u16[0]/scale)
        return 1;
    }
  }
  return 0;
}

U0 BuildModesDef(I64 scale=1)
{
  I64 i,w,h;
  U8 *vid_modes_str=CAlloc(32*10);
  for (i=0;i<32;i++)
  {
    if (vbe_vid_modes[i])
    {
      w=vbe_vid_modes[i].u16[1]/scale;
      h=vbe_vid_modes[i].u16[0]/scale;

      if (w>=640 && h>=360 && w%8==0 && h%4==0)
      {
        CatPrint(vid_modes_str,"%dx%d\n",w,h);
      }
    }
  }
  for (i=0;i<32*10;i++)
    if (vid_modes_str[i]=='\n') vid_modes_str[i]=0;
  if (scale==1)
    DefineLstLoad("ST_VID_MODES",vid_modes_str);
  if (scale==2)
    DefineLstLoad("ST_VID_MODES2X",vid_modes_str);
}

BuildModesDef;
BuildModesDef(2);

public U0 ChangeRes(I64 scale=1)
{// Change resolution (optionally with scaling)
  I64 i,w,h;
  U8 *mode_str, *h_str;
  "This will compile and install a new kernel and master boot record, do you wish to continue";
  if (!YorN('n')) return;

  if (scale==1)
    i=PopUpPickDefineSub("ST_VID_MODES");
  if (scale==2)
    i=PopUpPickDefineSub("ST_VID_MODES2X");
  if (0<=i<=31)
  {
    if (scale==1)
      mode_str=StrNew(DefineSub(i,"ST_VID_MODES"));
    if (scale==2)
      mode_str=StrNew(DefineSub(i,"ST_VID_MODES2X"));
    h_str=StrFirstOcc(mode_str,"x");
    *h_str=0;
    w=Str2I64(mode_str);
    h_str=mode_str+StrLen(mode_str)+1;
    h=Str2I64(h_str);
    MakeAllDef(1,w,h,1,scale);
  }

  "Reboot ";
  if (YorN) Reboot;
}
#help_index ""
