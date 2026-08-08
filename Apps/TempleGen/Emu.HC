I64 win_scale=2;

U0 GenDrawWindow(CTask *task, CDC *dc)
{
  I64 x,y;
  U8 *src;
  U16 *d0;
  CDC *shown=gen_shown_canvas;
  no_warn task;
  if (!shown)
    return;
  if (win_scale==2 && gameCanvas2x)
  {
    for (y=0; y<GEN_SCRN_H-2*GEN_OVERSCAN; y++)
    {
      src=shown->body+
          (y+GEN_OVERSCAN)*shown->width_internal;
      d0=gameCanvas2x->body+
          2*y*gameCanvas2x->width_internal;
      for (x=0; x<GEN_SCRN_W; x++)
        d0[x]=src[x]*0x0101;
      MemCpy(d0(U8 *)+gameCanvas2x->width_internal,d0,
          GEN_SCRN_W*2);
    }
    GrBlot(dc,0,0,gameCanvas2x);
  }
  else
    GrBlot(dc,0,0,shown);
}

U0 GenSnapWindow()
{
  I64 want_cols,want_rows,snap_left,snap_top;
  if (win_scale==2)
  {
    WinBorder(OFF);
    WinHorz(0,TEXT_COLS-1);
    WinVert(1,2*(GEN_SCRN_H-2*GEN_OVERSCAN)/FONT_HEIGHT);
  }
  else
  {
    WinBorder(ON);
    want_cols=GEN_SCRN_W/FONT_WIDTH;
    want_rows=GEN_SCRN_H/FONT_HEIGHT;
    snap_left=Fs->win_left;
    snap_top=Fs->win_top;
    if (snap_left+want_cols>TEXT_COLS-1)
      snap_left=TEXT_COLS-1-want_cols;
    if (snap_left<1)
      snap_left=1;
    if (snap_top+want_rows>TEXT_ROWS-1)
      snap_top=TEXT_ROWS-1-want_rows;
    if (snap_top<2)
      snap_top=2;
    WinHorz(snap_left,snap_left+want_cols-1);
    WinVert(snap_top,snap_top+want_rows-1);
  }
}

U0 GenReset()
{
  VDPReset;
  GenSndReset;
  GenJoypadInit;
  z80_bus_ack=0;
  z80_reset=0;
  Z80Reset;
  m68k_pulse_reset;
}

Bool GenIsRomName(U8 *name)
{
  U8 buf[256];
  I64 n;
  StrCpy(buf,name);
  n=StrLen(buf);
  if (n>2 && !StrICmp(buf+n-2,".Z"))
  {
    n-=2;
    buf[n]=0;
  }
  if (n>=4 && (!StrICmp(buf+n-4,".BIN") || !StrICmp(buf+n-4,".GEN")))
    return TRUE;
  return n>=3 && !StrICmp(buf+n-3,".MD");
}

Bool GenPickRom(U8 *rom_name)
{
  CDirEntry *de_list,*tmpde,**arr;
  I64 i,n=0,sel=0,top=0,rows,sc;
  U8 mask[256];
  Bool picked=FALSE,done=FALSE;
  U0(*old_draw_it)(CTask *task,CDC *dc);
  old_draw_it=Fs->draw_it;

  Fs->draw_it=NULL;
  StrPrint(mask,"%s/Roms/*",__DIR__);
  de_list=FilesFind(mask,FUF_JUST_FILES);
  tmpde=de_list;
  while (tmpde)
  {
    if (GenIsRomName(tmpde->name))
      n++;
    tmpde=tmpde->next;
  }
  if (!n)
  {
    DocClear;
		"$FG,4$No ROMs found.$FG$\n\n"
    "Put .BIN/.GEN/.MD (or .Z-compressed) files in\n"
    "\"%s/Roms\".\n\n"
		        "$FG,14$Press any key...$FG$\n",__DIR__;
    GetKey;
    DirTreeDel(de_list);
    DocClear;
    Fs->draw_it=old_draw_it;
    return FALSE;
  }
  arr=MAlloc(n*sizeof(CDirEntry *));
  i=0;
  tmpde=de_list;
  while (tmpde)
  {
    if (GenIsRomName(tmpde->name))
      arr[i++]=tmpde;
    tmpde=tmpde->next;
  }

  rows=Fs->win_bottom-Fs->win_top-3;
  if (rows<1)
    rows=1;
  while (!done)
  {
    if (sel<top)
      top=sel;
    if (sel>=top+rows)
      top=sel-rows+1;
    DocClear;
		"$FG,14$Pick a ROM$FG$ (%d found)\n"
		        "$FG,11$Arrows$FG$ move, $FG,11$Space$FG$/"
		        "$FG,11$Enter$FG$ pick, $FG,11$ESC$FG$ backs out.\n\n",
    n;
    for (i=top; i<n && i<top+rows; i++)
      if (i==sel)
				"$IV,1$%s$IV,0$\n",arr[i]->name;
      else
				"%s\n",arr[i]->name;
    switch (GetKey(&sc))
    {
    case 0:
      switch (sc.u8[0])
      {
      case SC_CURSOR_UP:
        if (sel)
          sel--;
        break;
      case SC_CURSOR_DOWN:
        if (sel<n-1)
          sel++;
        break;
      case SC_PAGE_UP:
        sel-=rows;
        if (sel<0)
          sel=0;
        break;
      case SC_PAGE_DOWN:
        sel+=rows;
        if (sel>n-1)
          sel=n-1;
        break;
      case SC_HOME:
        sel=0;
        break;
      case SC_END:
        sel=n-1;
        break;
      }
      break;
    case ' ':
    case '\n':
      StrCpy(rom_name,arr[sel]->full_name);
      picked=TRUE;
      done=TRUE;
      break;
    case CH_ESC:
    case CH_SHIFT_ESC:
      done=TRUE;
      break;
    }
  }
  Free(arr);
  DirTreeDel(de_list);
  DocClear;
  Fs->draw_it=old_draw_it;
  return picked;
}

Bool GenLoadRom(U8 *rom_filename)
{
  I64 size,i;
  U8 *buf,*dot;

  buf=FileRead(rom_filename,&size);
  if (!buf)
  {
    PrintErr("ROM file not found.\n");
    return FALSE;
  }
  if (size<0x200 || size>GEN_ROM_SIZE)
  {
    PrintErr("\"%s\" isn't a usable size for a Genesis ROM.\n",
        rom_filename);
    Free(buf);
    return FALSE;
  }
  if (size%16384==512)
  {
    PrintErr("\"%s\" is an interleaved .SMD image -- convert it "
		        "to .BIN format.\n",rom_filename);
    Free(buf);
    return FALSE;
  }
  if (MemCmp(buf+0x100,"SEGA",4) && MemCmp(buf+0x101,"SEGA",4))
  {
    PrintErr("\"%s\" doesn't look like a Genesis ROM "
		        "(no SEGA header at 0x100).\n",rom_filename);
    Free(buf);
    return FALSE;
  }
  GenSetRom(buf,size);
  Free(buf);

  StrCpy(gen_state_filename,rom_filename);
  i=StrLen(gen_state_filename);
  if (i>2 && !StrICmp(gen_state_filename+i-2,".Z"))
    gen_state_filename[i-2]=0;
  dot=StrLastOcc(gen_state_filename,".");
  if (dot)
    *dot=0;
  CatPrint(gen_state_filename,".SAV.Z");

  //Codes are per game, so the last ROM's picks go with it.
  GenGenieLoadList(rom_filename);
  return TRUE;
}

U0 GenChangeRom()
{
  U8 new_rom[256];
  if (!GenPickRom(new_rom))
    return;
  //Codes belong to one game, and GenSetRom refills the ROM image
  //anyway, so the saved-off original words would be stale.
  GenGenieClear;
  while (!GenLoadRom(new_rom))
    if (!GenPickRom(new_rom))
      return;
  GenReset;
  if (gen_snd_fifo)
    FifoI64Flush(gen_snd_fifo);
  gen_snd_last=0;
  DCFill(gameCanvas,BLACK);
  DCFill(gameCanvas2,BLACK);
  DCFill(gameCanvas2x,BLACK);
}

U0 TempleGen(U8 *rom_filename=NULL)
{
  I64 arg1,arg2;
  Bool quit=FALSE,paused=FALSE;
  F64 next_frame;
  U8 rom_name[256],help_path[256];

#ifdef MIXER_MAX_SRC
  if (snd_dev==SD_HD_AUDIO)
    GenSndInstall;
#endif
  SettingsPush;
  Fs->text_attr=BLACK<<4+WHITE;
  MenuPush(
      "File {"
      "  Exit(,CH_ESC);"
      "}"
      "Game {"
      "  PickROM(,'P');"
      "  Reset(,'R');"
      "  Pause(,' ');"
      "  SaveState(,'S');"
      "  LoadState(,'L');"
      "  GameGenie(,'g');"
      "}"
      "View {"
      "  Scale1x(,'1');"
      "  Scale2x(,'2');"
	        "}");
  AutoComplete;
  DocCursor;
  DocClear;
  GenSnapWindow;
  WinFocus;

  StrPrint(help_path,"%s/Help.DD",__DIR__);
  Type(help_path);
  //Start with nothing applied, so the first GenLoadRom has no stale
  //original words to write back over the fresh ROM image.
  GenGenieClear;
  if (rom_filename)
		"\n$FG,14$Press any key to start...$FG$\n";
  else
		"\n$FG,14$Press any key to pick a ROM...$FG$\n";
  GetKey;
  DocClear;

  if (!rom_filename)
  {
    if (!GenPickRom(rom_name))
    {
      GenGenieClear;
      MenuPop;
      SettingsPop;
      DocClear;
      return;
    }
    rom_filename=rom_name;
  }

  ROM=MAlloc(GEN_ROM_SIZE);
  RAM=MAlloc(0x10000);
  ZRAM=MAlloc(0x2000);
  if (!GenLoadRom(rom_filename))
  {
    GenGenieClear;
    Free(ROM);
    ROM=NULL;
    Free(RAM);
    RAM=NULL;
    Free(ZRAM);
    ZRAM=NULL;
    MenuPop;
    SettingsPop;
    return;
  }
  GenGenieApply;

  gameCanvas=DCNew(GEN_SCRN_W,GEN_SCRN_H);
  DCFill(gameCanvas,BLACK);
  gameCanvas2=DCNew(GEN_SCRN_W,GEN_SCRN_H);
  DCFill(gameCanvas2,BLACK);
  gen_shown_canvas=gameCanvas2;
  gameCanvas->flags|=DCF_NO_TRANSPARENTS;
  gameCanvas2->flags|=DCF_NO_TRANSPARENTS;
  gameCanvas2x=DCNew(2*GEN_SCRN_W,2*(GEN_SCRN_H-2*GEN_OVERSCAN));
  DCFill(gameCanvas2x,BLACK);
  gameCanvas2x->flags|=DCF_NO_TRANSPARENTS;

  GenSavePalette;
  GenInitPalette;
  GenReset;
  GenSyncPalette;

  Fs->draw_it=&GenDrawWindow;
  next_frame=tS+1.0/60;
  try
  {
    while (!quit)
    {
      if (!paused)
      {
        GenFrame;
        GenSndThrottle;
        while (tS<next_frame)
          Sleep(1);
        next_frame+=1.0/60;
        if (next_frame<tS)
          next_frame=tS+1.0/60;
      }
      else
        Sleep(20);
      GenSyncPalette;
      while (ScanMsg(&arg1,&arg2,1<<MSG_KEY_DOWN))
      {
        switch (arg1)
        {
        case CH_ESC:
        case CH_SHIFT_ESC:
        case 'q':
        case 'Q':
          quit=TRUE;
          break;
        case 'r':
        case 'R':
          GenReset;
          break;
        case 'p':
        case 'P':
          GenChangeRom;
          paused=FALSE;
          next_frame=tS+1.0/60;
          break;
        case ' ':
          paused=!paused;
          if (!paused)
            next_frame=tS+1.0/60;
          break;
        case 's':
        case 'S':
          SaveState;
          break;
        case 'l':
        case 'L':
          LoadState;
          break;
        case 'g':
          if (GenGeniePick)
            GenReset;
          next_frame=tS+1.0/60;
          break;
        case '1':
          win_scale=1;
          break;
        case '2':
          win_scale=2;
          break;
        }
      }
      GenSnapWindow;
      GenJoypadScan;
    }
  }
  catch
    PutExcept;

  Fs->draw_it=NULL;
  GenSndUninstall;
  GenRestorePalette;
  GenGenieClear;
  Free(ROM);
  ROM=NULL;
  Free(RAM);
  RAM=NULL;
  Free(ZRAM);
  ZRAM=NULL;
  gen_shown_canvas=NULL;
  DCDel(gameCanvas);
  gameCanvas=NULL;
  DCDel(gameCanvas2);
  gameCanvas2=NULL;
  DCDel(gameCanvas2x);
  gameCanvas2x=NULL;
  MenuPop;
  SettingsPop;
  DocClear;
}
