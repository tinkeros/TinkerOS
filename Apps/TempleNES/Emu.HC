I64 win_scale=2, win_set_w=0;

//Coordination between the UI task (owns the window, on Core0) and
//the emulation task (runs the CPU/PPU/APU loop, possibly on another
//core).  nes_paused doubles as the "please stand still" request the
//UI task raises before touching engine state; nes_emu_idle is the
//emulation task's ack that it saw the request and is parked.
Bool nes_quit, nes_paused, nes_emu_idle, nes_task_done;

U0 NESDrawWindow(CTask *task, CDC *dc)
{

  I64 x,y;
  U8 *src;
  U16 *d0;
  no_warn task;
  if (win_scale==2 && gameCanvas2x)
  {
    for (y=0; y<NES_SCRN_H-2*NES_OVERSCAN; y++)
    {
      src=gameCanvas->body+
          (y+NES_OVERSCAN)*gameCanvas->width_internal;
      d0=gameCanvas2x->body+
          2*y*gameCanvas2x->width_internal;
      for (x=0; x<NES_SCRN_W; x++)
        d0[x]=src[x]*0x0101;
      MemCpy(d0(U8 *)+gameCanvas2x->width_internal,d0,
          NES_SCRN_W*2);
    }
    GrBlot(dc,0,0,gameCanvas2x);
  }
  else
    GrBlot(dc,0,0,gameCanvas);
}

U0 NESSnapWindow()
{

  I64 want_cols,want_rows,snap_left,snap_top;
  if (Fs->pix_width!=win_set_w)
  {

    if (Fs->pix_width>=NES_SCRN_W*3/2)
      win_scale=2;
    else
      win_scale=1;
  }
  want_cols=win_scale*NES_SCRN_W/FONT_WIDTH;
  if (win_scale==2)
    want_rows=2*(NES_SCRN_H-2*NES_OVERSCAN)/FONT_HEIGHT;
  else
    want_rows=NES_SCRN_H/FONT_HEIGHT;
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
  win_set_w=win_scale*NES_SCRN_W;
}

U0 NESReset()
{
  reset6502;
  initPPU2C02(&PPU_state);
  JoypadInit(&nes_joypad);
}

Bool NESIsRomName(U8 *name)
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
  return n>=4 && !StrICmp(buf+n-4,".NES");
}

Bool NESPickRom(U8 *rom_name)
{

  CDirEntry *de_list,*tmpde,**arr;
  I64 i,n=0,sel=0,top=0,rows,sc;
  U8 mask[256];
  Bool picked=FALSE,done=FALSE;
  U0 (*old_draw_it)(CTask *task,CDC *dc);
  old_draw_it=Fs->draw_it;

  Fs->draw_it=NULL;
  StrPrint(mask,"%s/Roms/*",__DIR__);
  de_list=FilesFind(mask,FUF_JUST_FILES);
  tmpde=de_list;
  while (tmpde)
  {
    if (NESIsRomName(tmpde->name))
      n++;
    tmpde=tmpde->next;
  }
  if (!n)
  {
    DocClear;
		"$FG,4$No ROMs found.$FG$\n\n"
    "Put .NES (or .NES.Z) files in\n"
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
    if (NESIsRomName(tmpde->name))
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

Bool NESLoadRom(U8 *rom_filename)
{

  I64 i,size,controlByte2;
  U8 *dot;

  cartridgebuffer=FileRead(rom_filename,&size);
  if (!cartridgebuffer)
  {
    PrintErr("iNES ROM file not found.\n");
    return FALSE;
  }
  if (size<16 || cartridgebuffer[0]!='N' || cartridgebuffer[1]!='E' ||
      cartridgebuffer[2]!='S' || cartridgebuffer[3]!=0x1A)
  {
    PrintErr("\"%s\" is not an iNES file.\n",rom_filename);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    return FALSE;
  }

  numPRGROM =cartridgebuffer[4];
  numCHRROM =cartridgebuffer[5];
  controlByte1=cartridgebuffer[6];
  controlByte2=cartridgebuffer[7];
  mapper=(controlByte2&0xF0)|((controlByte1&0xF0)>>4);
  if (controlByte1&1)
    mirroringType=MIRR_VERT;
  else
    mirroringType=MIRR_HORZ;

  MMUInit;
  switch (mapper)
  {
  case 0:
  case 3:

    MemCpy(MMU.RAM+0x8000,cartridgebuffer+0x10,numPRGROM*0x4000);
    if (numPRGROM==1)
      MemCpy(MMU.RAM+0xC000,cartridgebuffer+0x10,0x4000);

    if (numCHRROM)
      MemCpy(MMU.VRAM,cartridgebuffer+0x10+0x4000*numPRGROM,
          0x2000);
    break;
  case 1:
  case 2:

    MemCpy(MMU.RAM+0x8000,cartridgebuffer+0x10,0x4000);

    MemCpy(MMU.RAM+0xC000,
        cartridgebuffer+0x10+0x4000*(numPRGROM-1),0x4000);

    if (numCHRROM)
      MemCpy(MMU.VRAM,cartridgebuffer+0x10+0x4000*numPRGROM,
          0x2000);
    break;
  case 4:
    MMC3_Init();
    break;
  case 7:
    MemCpy(MMU.RAM+0x8000,cartridgebuffer+0x10,0x8000);
    mirroringType=MIRR_SINGLE;
    break;
  default:
    PrintErr("iNES mapper %d isn't supported "
		        "(0, 1, 2, 3, 4 and 7 are).\n",mapper);
    Free(cartridgebuffer);
    cartridgebuffer=NULL;
    MMUFree;
    return FALSE;
  }

  StrCpy(nes_state_filename,rom_filename);
  i=StrLen(nes_state_filename);
  if (i>2 && !StrICmp(nes_state_filename+i-2,".Z"))
    nes_state_filename[i-2]=0;
  dot=StrLastOcc(nes_state_filename,".");
  if (dot)
    *dot=0;
  StrCpy(nes_sram_filename,nes_state_filename);
  CatPrint(nes_state_filename,".BIN.Z");
  CatPrint(nes_sram_filename,".SRM");

  LoadSRAM;
  return TRUE;
}

Bool NESChangeRom()
{

  U8 new_rom[256];
  if (!NESPickRom(new_rom))
    return TRUE;
  SaveSRAM;
  Free(cartridgebuffer);
  cartridgebuffer=NULL;
  MMUFree;
  while (!NESLoadRom(new_rom))
    if (!NESPickRom(new_rom))
      return FALSE;
  NESReset;
  initPAPU(&PAPU);
  papu_request_irq=FALSE;
  mapper_request_irq=FALSE;
  DCFill(gameCanvas,0);
  DCFill(gameCanvas2x,0);
  return TRUE;
}

U0 NESPauseEmu()
{//Stop the emu task before the UI task touches shared engine state.
  nes_paused=TRUE;
  while (!nes_emu_idle)
    Sleep(1);
}

U0 NESEmuTask(U8 *data)
{//Runs on its own core when one is free.  Never touches Fs -- this
//task has no window, only Core0 tasks do.
  I64 cycles,loop;
  U8 frame_finished=0;
  F64 next_frame;
  Bool was_paused;
  no_warn data;
  was_paused=TRUE;
  next_frame=tS+1.0/60;
  try
  {
    while (!nes_quit)
    {
      if (nes_paused)
      {
        nes_emu_idle=TRUE;
        was_paused=TRUE;
        Sleep(20);
      }
      else
      {
        nes_emu_idle=FALSE;
        if (was_paused)
        {
          next_frame=tS+1.0/60;
          was_paused=FALSE;
        }
        if (papu_request_irq)
        {
          irq6502;
          papu_request_irq=FALSE;
        }
        if (mapper_request_irq)
        {
          irq6502;
          mapper_request_irq=FALSE;
        }
        exec6502(1);
        cycles=ticktable[opcode];
        PAPU_clockFrameCounter(&PAPU,cycles);
        loop=cycles*3;
        while (loop)
        {
          frame_finished|=PPUcycle(&PPU_state);
          loop--;
        }
        if (frame_finished)
        {
          frame_finished=0;
          NESSndThrottle;
          while (tS<next_frame)
            Sleep(1);
          next_frame+=1.0/60;
          if (next_frame<tS)
            next_frame=tS+1.0/60;
          JoypadScan(&nes_joypad);
        }
      }
    }
  }
  catch
  {
    PutExcept;
    nes_quit=TRUE;
  }
  nes_emu_idle=TRUE;
  nes_task_done=TRUE;
}

U0 TempleNES(U8 *rom_filename=NULL)
{

  I64 arg1,arg2;
  U8 rom_name[256],help_path[256];

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
      "}"
      "View {"
      "  Scale1x(,'1');"
      "  Scale2x(,'2');"
	        "}");
  AutoComplete;
  WinBorder(ON);
  DocCursor;
  DocClear;
  win_set_w=Fs->pix_width;
  NESSnapWindow;
  WinFocus;

  StrPrint(help_path,"%s/Help.DD",__DIR__);
  Type(help_path);
  if (rom_filename)
		"\n$FG,14$Press any key to start...$FG$\n";
  else
		"\n$FG,14$Press any key to pick a ROM...$FG$\n";
  GetKey;
  DocClear;

  if (!rom_filename)
  {
    if (!NESPickRom(rom_name))
    {
      MenuPop;
      SettingsPop;
      DocClear;
      return;
    }
    rom_filename=rom_name;
  }
  if (!NESLoadRom(rom_filename))
  {

    MenuPop;
    SettingsPop;
    return;
  }

  gameCanvas=DCNew(NES_SCRN_W,NES_SCRN_H);
  DCFill(gameCanvas,0);

  gameCanvas->flags|=DCF_NO_TRANSPARENTS;
  gameCanvas2x=DCNew(2*NES_SCRN_W,2*(NES_SCRN_H-2*NES_OVERSCAN));
  DCFill(gameCanvas2x,0);
  gameCanvas2x->flags|=DCF_NO_TRANSPARENTS;

  reset6502;
  initPPU2C02(&PPU_state);
  initPAPU(&PAPU);
  JoypadInit(&nes_joypad);

  GrPaletteGet(&nes_sys_palette);
  PPU_InitPalette;

  Fs->draw_it=&NESDrawWindow;

  nes_quit=FALSE;
  nes_paused=FALSE;
  nes_emu_idle=FALSE;
  nes_task_done=FALSE;
//Most of the emulation work (CPU/PPU/APU) runs in its own task, on
//its own core when one is free, leaving this (Core0, windowed) task
//free to service input and the window.
  if (mp_cnt>1)
    Spawn(&NESEmuTask,NULL,"TempleNES Core",1);
  else
    Spawn(&NESEmuTask,NULL,"TempleNES Core",,Fs);
  try
  {
    while (!nes_quit)
    {
      while (ScanMsg(&arg1,&arg2,1<<MSG_KEY_DOWN))
      {
        switch (arg1)
        {
        case CH_ESC:
        case CH_SHIFT_ESC:
        case 'q':
        case 'Q':
          nes_quit=TRUE;
          break;
        case 'r':
        case 'R':
          NESPauseEmu;
          NESReset;
          nes_paused=FALSE;
          break;
        case 'p':
        case 'P':
          NESPauseEmu;
          if (NESChangeRom())
            nes_paused=FALSE;
          else
            nes_quit=TRUE;
          break;
        case ' ':
          nes_paused=!nes_paused;
          break;
        case 's':
        case 'S':
          NESPauseEmu;
          SaveState;
          nes_paused=FALSE;
          break;
        case 'l':
        case 'L':
          NESPauseEmu;
          LoadState;
          nes_paused=FALSE;
          break;
        case '1':
          win_scale=1;
          break;
        case '2':
          win_scale=2;
          break;
        }
      }
      NESSnapWindow;
      Sleep(20);
    }
  }
  catch
    PutExcept;

  nes_quit=TRUE;
  while (!nes_task_done)
    Sleep(1);

  Fs->draw_it=NULL;
  SaveSRAM;
  PAPU_initBuffers;
  GrPaletteSet(&nes_sys_palette);
  Free(cartridgebuffer);
  cartridgebuffer=NULL;
  MMUFree;
  DCDel(gameCanvas);
  gameCanvas=NULL;
  DCDel(gameCanvas2x);
  gameCanvas2x=NULL;
  MenuPop;
  SettingsPop;
  DocClear;
}
