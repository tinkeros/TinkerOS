class CPaint
{
  U8 *fb;
  CDC *dc;
  I64 color;
  I64 width;
  I64 height;
  I64 width_internal;
  U64 thick;
  I64 stamp;
  U64 last_x;
  U64 last_y;
  U64 last_thick;
};

static CPaint paint;
paint.fb=NULL;
static Bool circle_brush=FALSE;
static Bool draw_image=FALSE;
static Bool draw_overlay=TRUE;
static Bool overlay_bottom=TRUE;
static Bool show_palette=FALSE;
static Bool show_stamps=FALSE;
static I64 last_ch=0, max_stamps=0,stamp_cnt=0, stamp_max_h=0, stamp_max_w=0,
           stamps_per_row=0, stamps_per_column=0;
static U8 *cur_filename=0;
static CDC *paint_palette=NULL;
static CDC *paint_stamps=NULL;
static CDC **stamps;

static I64 sorted_pal[25][10]=
{
  {15, 0, 1, 2, 3, 4, 5, 6, 7, 15},
  {15, 8, 9, 10, 11, 12, 13, 14, 15, 15},
  {0, 58, 8, 101, 144, 7, 187, 15, 180, 223},
  {51, 94, 137, 130, 173, 166, 216, 209, 12, 202},
  {87, 123, 4, 172, 159, 165, 215, 208, 195, 201},
  {93, 136, 129, 6, 179, 171, 222, 214, 207, 213},
  {143, 135, 186, 178, 177, 229, 228, 221, 220, 219},
  {57, 100, 99, 142, 141, 185, 184, 227, 14, 226},
  {105, 148, 183, 147, 192, 191, 190, 225, 189, 153},
  {63, 106, 69, 149, 112, 111, 155, 154, 118, 117},
  {64, 107, 70, 150, 113, 75, 193, 156, 119, 81},
  {21, 27, 33, 2, 76, 39, 10, 82, 45, 46},
  {71, 34, 114, 77, 40, 157, 120, 83, 84, 47},
  {28, 35, 151, 78, 41, 42, 121, 85, 48, 49},
  {65, 108, 72, 115, 79, 194, 158, 122, 11, 86},
  {22, 29, 36, 3, 43, 37, 116, 80, 50, 44},
  {23, 66, 30, 109, 73, 31, 152, 74, 38, 32},
  {102, 24, 145, 67, 25, 188, 146, 110, 68, 26},
  {16, 59, 17, 60, 18, 103, 61, 104, 9, 62},
  {54, 1, 97, 19, 55, 140, 98, 20, 56, 92},
  {53, 96, 90, 139, 133, 91, 182, 176, 134, 128},
  {95, 138, 181, 175, 127, 224, 218, 212, 170, 164},
  {52, 89, 132, 126, 5, 169, 163, 13, 206, 200},
  {131, 125, 174, 168, 162, 217, 211, 205, 199, 198},
  {88, 124, 167, 161, 160, 210, 204, 203, 197, 196}
};

U0 EnumPaintStamps()
{
  CDC *tmpdc;
  CDirEntry *tmpde1=NULL,*tmpde2;
  I64 res=0;
  U8 *files_find_mask="/Misc/Paint/Stamps/*.GR.Z";

  tmpde1=FilesFind(files_find_mask);
  if (tmpde1)
  {
    tmpde2=tmpde1;
    while (tmpde2)
    {
      tmpdc=GRRead(tmpde2->full_name);
      if (tmpdc->width>stamp_max_w)
        stamp_max_w=tmpdc->width;
      if (tmpdc->height>stamp_max_h)
        stamp_max_h=tmpdc->height;
      DCDel(tmpdc);
      tmpde2=tmpde2->next;
      res++;
    }
  }
  stamp_cnt=res;

  stamps_per_row=GR_WIDTH/(stamp_max_w+1);
  stamps_per_column=GR_HEIGHT/(stamp_max_h+1);
  max_stamps=stamps_per_row*stamps_per_column;

  if (stamp_cnt<max_stamps) max_stamps=stamp_cnt;

  if (stamp_cnt>0)
  {
    stamps=CAlloc(max_stamps*sizeof(CDC*));
    tmpde1=FilesFind(files_find_mask);
    res=0;
    if (tmpde1)
    {
      tmpde2=tmpde1;
      while (tmpde2 && res<max_stamps)
      {
        tmpdc=GRRead(tmpde2->full_name);
        stamps[res]=tmpdc;
        tmpde2=tmpde2->next;
        res++;
      }
    }
    if (res>max_stamps) res=max_stamps;
    max_stamps=res;
  }
}

U0 PaintStampsInit(CDC *dc)
{
  I64 cnt=0,x,y,xoff,yoff,xsize,ysize,sxoff,syoff;


  xsize = stamp_max_w+1;
  ysize = stamp_max_h+1;

  xoff = (GR_WIDTH - xsize * stamps_per_row) / 2;
  yoff = (GR_HEIGHT - ysize * stamps_per_column) / 2;

  paint_stamps=DCCopy(dc);
  DCFill(paint_stamps,15);


  for (y=0; y<stamps_per_column; y++)
    for (x=0; x<stamps_per_row; x++)
    {
      if (cnt==max_stamps) return;
      else
      {
        sxoff=(stamp_max_w-stamps[cnt]->width)/2;
        syoff=(stamp_max_h-stamps[cnt]->height)/2;
        GrBlot(paint_stamps,x*xsize+xoff+sxoff,y*ysize+yoff+syoff,stamps[cnt++]);
      }
    }
}

I64 PaintStampPeek(I64 x, I64 y)
{
  I64 res=stamps_per_row * (y/(stamp_max_h+1)) + x/(stamp_max_w+1);
  if (res>max_stamps-1) return max_stamps-1;
  return res;
}

U0 DrawImagePixel(I64 x, I64 y, U8 color)
{
  paint.fb[x + y * paint.width_internal] = color;
}

U0 DrawScrnPixel(CDC *dc, I64 x, I64 y, U8 color)
{
  dc->body[x + y * dc->width_internal] = color;
}

U0 DrawScrnChar(CDC *dc, I64 x, I64 y, I64 char)
{
  I64 i, j;
  for (i = 0; i < FONT_HEIGHT; i++)
    for (j = 0; j < FONT_WIDTH; j++)
      if (text.font[char] >> (i * 8) & 1 << j)
        DrawScrnPixel(dc, x + j, y + i, BLACK);
      else
        DrawScrnPixel(dc, x + j, y + i, WHITE);
}

U0 DrawScrnStr(CDC *dc, I64 x, I64 y, U8 *str)
{
  I64 c, i = 0;

  while (c = *str++)
  {
    DrawScrnChar(dc, x + FONT_WIDTH * i++, y, c);
  }
}

U0 DrawImageBrush(I64 ms_x, I64 ms_y, U8 color, I64 thick)
{
  I64 i, j, x, y;

  x=ms_x;
  y=ms_y;

  for (i = x; i < x + thick; i++)
    for (j = y; j < y + thick; j++)
      DrawImagePixel(i, j, color);
}

U0 DrawScrnBrush(CDC *dc, I64 x, I64 y, U8 color, I64 thick)
{
  I64 i, j;

  for (i = x; i < x + thick; i++)
    for (j = y; j < y + thick; j++)
      DrawScrnPixel(dc, i, j, color);

  paint.last_x = x;
  paint.last_y = y;
  paint.last_thick = thick;

}

U0 PaintSaveImage(U8 *fname=NULL)
{
  U8 *filename, *tmp;

  draw_image=FALSE;

  if (fname)
  {
    tmp=MStrPrint("Save Image:\n%s\n",fname);
    if (PopUpCancelOk(tmp))
    {
      GRWrite(fname,paint.dc);
    }
    Free(tmp);
  }
  else
  {
    tmp = PopUpFileName("~/");
    filename = ExtChg(tmp, "GR"); // make sure file ends in .GR32
    Free(tmp);
    GRWrite(filename,paint.dc);
    Free(filename);
  }
  draw_image=TRUE;
}

U0 PaintLoadImage(U8 *fname=NULL)
{
  CDC *dc;
  U8 ext[STR_LEN],
  *file,
  filename[STR_LEN];

  draw_image=FALSE;

  if (!fname)
  {
    PopUpOk("Pick a .GR file to load.\n\n"
			"(Double-click / ESC to pick.)");

    do
    {
      file = PopUpPickFile("~/");
      FileExtRem(file, ext);
    }
    while (StrCmp(ext, "GR")&&StrCmp(ext,"GR.Z"));

    StrCpy(filename, file);
    Free(file);
  }
  else
    StrCpy(filename, fname);

  dc=GRRead(filename);
  paint.dc = dc;
  paint.fb = dc->body;
  paint.thick = 8;
  paint.color = BLACK;
  paint.last_x = ms.pos.x;
  paint.last_y = ms.pos.y;
  paint.last_thick = paint.thick;
  paint.width=dc->width;
  paint.height=dc->height;
  paint.width_internal=dc->width_internal;
  draw_image=TRUE;
}

I64 PaintImagePeek(I64 x, I64 y)
{
  return paint.fb[x + y * paint.width_internal];
}

I64 PaintPalPeek(I64 x, I64 y)
{
  return paint_palette->body[x + y * paint_palette->width_internal];
}

U0 PaintGlblsInit(CDC *dc)
{
  paint.dc = DCNew(dc->width,dc->height);
  paint.fb = paint.dc->body;
  MemSet(paint.fb,WHITE,dc->width_internal*dc->height);
  paint.thick = 8;
  paint.color = BLACK;
  paint.last_x = ms.pos.x;
  paint.last_y = ms.pos.y;
  paint.last_thick = paint.thick;
  paint.stamp=-1;
  if (cur_filename) PaintLoadImage(cur_filename);
  paint.width=paint.dc->width;
  paint.height=paint.dc->height;
  paint.width_internal=paint.dc->width_internal;
  draw_image=TRUE;
}

U0 PaintPalInit(CDC *dc)
{
  I64 i,j,x,y,xoff,yoff,xsize,ysize;

  xsize = GR_WIDTH / 29;
  ysize = GR_HEIGHT / 14;

  xoff = (GR_WIDTH - xsize * 25) / 2;
  yoff = (GR_HEIGHT - ysize * 10) / 2;

  paint_palette=DCCopy(dc);
  DCFill(paint_palette,15);


  for (x=0; x<25; x++)
    for (y=0; y<10; y++)
      for (j=0; j<ysize-4; j++)
        for (i=0; i<xsize-4; i++)
          paint_palette->body[(y*ysize+yoff+j)*paint_palette->width_internal+x*xsize+xoff+i]=
              sorted_pal[x][y];
}

U0 DrawIt(CTask *, CDC *dc)
{

  I64 i, j, overlay_offset=0;
  F64 h,s,v;
  U8 tmp_str[STR_LEN];
  CBGR48 cur_color, tmp_clr;

  if (!paint_palette) PaintPalInit(dc);
  if (!paint_stamps) PaintStampsInit(dc);

  if (overlay_bottom) overlay_offset=GR_HEIGHT/FONT_HEIGHT-4;
  if (!paint.fb) PaintGlblsInit(dc);
  else if (show_stamps)
  {
    DCFill(dc,WHITE);
    GrBlot(dc,0,0,paint_stamps);
  }
  else if (show_palette)
  {
    DCFill(dc,WHITE);
    GrBlot(dc,0,0,paint_palette);
  }
  else if (draw_image)
  {
    DCFill(dc,WHITE);
    dc->color=BLACK;
    dc->thick=5;
    GrRect(dc,0,0,paint.dc->width+1,paint.dc->height+1);
    GrBlot(dc,0,0,paint.dc);
  }

  // draw the brush on the screen
  if (paint.stamp>=0)
  {
    GrBlot(dc,ms.pos.x,ms.pos.y,stamps[paint.stamp]);
  }
  else if (circle_brush)
  {
    dc->color=paint.color;
    for (i=0; i<=paint.thick/2+1; i++)
      GrCircle(dc, ms.pos.x,ms.pos.y,i);
  }
  else
  {
    if (show_stamps)
      DrawScrnBrush(dc, ms.pos.x, ms.pos.y, BLACK, paint.thick);
    else
      DrawScrnBrush(dc, ms.pos.x, ms.pos.y, paint.color, paint.thick);
  }

  cur_color = GrPaletteColorGet(paint.color);

  if (draw_overlay)
  {
    StrPrint(tmp_str, "Red:   %d", cur_color.r.u8[0]);
    DrawScrnStr(dc, 0, overlay_offset * FONT_HEIGHT, tmp_str);

    StrPrint(tmp_str, "Green: %d", cur_color.g.u8[0]);
    DrawScrnStr(dc, 0, (overlay_offset+1) * FONT_HEIGHT, tmp_str);

    StrPrint(tmp_str, "Blue:  %d", cur_color.b.u8[0]);
    DrawScrnStr(dc, 0, (overlay_offset+2) * FONT_HEIGHT, tmp_str);

    for (i = 2+overlay_offset*FONT_HEIGHT; i < (overlay_offset+3) * FONT_HEIGHT - 2; i++)
      for (j = 10*FONT_WIDTH+2; j < 13*FONT_WIDTH-2; j++)
        DrawScrnPixel(dc, j, i, BLACK);


    for (i = 4+overlay_offset*FONT_HEIGHT; i < (overlay_offset+3) * FONT_HEIGHT - 4; i++)
      for (j = 10*FONT_WIDTH+4; j < 13*FONT_WIDTH - 4; j++)
        DrawScrnPixel(dc, j, i, paint.color);

    StrPrint(tmp_str,"Canvas Size: %d x %d", paint.width,paint.height);
    DrawScrnStr(dc, FONT_WIDTH * 14, (overlay_offset+1)*FONT_HEIGHT, tmp_str);

    StrPrint(tmp_str,"Color Num: %d", paint.color);
    DrawScrnStr(dc, FONT_WIDTH * 14, overlay_offset* FONT_HEIGHT, tmp_str);

    tmp_clr=GrPaletteColorGet(paint.color);
    RGB2HSV(&tmp_clr,&h,&s,&v);
    StrPrint(tmp_str,"H: %1.1f S: %1.1f V: %1.1f", h,s,v);
    DrawScrnStr(dc, FONT_WIDTH * 14, (overlay_offset+2)*FONT_HEIGHT, tmp_str);

    if (Bt(char_bmp_printable,last_ch.u8[0]))
    {
      StrPrint(tmp_str,"%c",last_ch.u8[0]);
      DrawScrnStr(dc, dc->width-16, (overlay_offset+2)*FONT_HEIGHT, tmp_str);
    }
  }
}

Bool ProcessInput()
{
  I64 arg1, arg2, ch, i, msg, sc;
  Bool brush_down=FALSE;
  while (1)
  {
    msg = ScanMsg(&arg1,&arg2,
            +1<<MSG_MS_L_DOWN
            +1<<MSG_MS_L_UP
            +1<<MSG_MS_L_DOWN_UP
            +1<<MSG_MS_MOVE
            +1<<MSG_KEY_DOWN);
    switch (msg)
    {
    case 0:
      Refresh;
      break;
start:
    case MSG_MS_L_DOWN:
      if (show_stamps)
      {
        paint.stamp=PaintStampPeek(ms.pos.x, ms.pos.y);
      }
      else if (show_palette)
        paint.color=PaintPalPeek(ms.pos.x, ms.pos.y);
      else brush_down=TRUE;
    case MSG_MS_MOVE:
      if (brush_down)
      {
        if (circle_brush)
        {
          paint.dc->color=paint.color;
          for (i=0; i<=paint.thick/2+1; i++)
            GrCircle(paint.dc, ms.pos.x,ms.pos.y,i);
        }
        else
        {
          if (paint.stamp>=0) GrBlot(paint.dc,ms.pos.x,ms.pos.y,stamps[paint.stamp]);
          else DrawImageBrush(arg1, arg2, paint.color, paint.thick);
        }
      }
      break;
    case MSG_MS_L_DOWN_UP:
      if (show_stamps)
      {
        paint.stamp=PaintStampPeek(ms.pos.x, ms.pos.y);
      }
      else if (show_palette)
        paint.color=PaintPalPeek(ms.pos.x, ms.pos.y);
      else if (circle_brush)
      {
        paint.dc->color=paint.color;
        for (i=0; i<=paint.thick/2+1; i++)
          GrCircle(paint.dc, ms.pos.x,ms.pos.y,i);
      }
      else
      {
        if (paint.stamp>=0) GrBlot(paint.dc,ms.pos.x,ms.pos.y,stamps[paint.stamp]);
        else DrawImageBrush(arg1, arg2, paint.color, paint.thick);
      }
    case MSG_MS_L_UP:
      brush_down=FALSE;
      break;
    case MSG_KEY_DOWN:
      last_ch=ch=arg1;
      sc=arg2;
      switch (ch)
      {
      case 0:
        switch (sc.u8[0])
        {
        case SC_CURSOR_LEFT:
          ms.pos.x--;
          break;
        case SC_CURSOR_RIGHT:
          ms.pos.x++;
          break;
        case SC_CURSOR_UP:
          ms.pos.y--;
          break;
        case SC_CURSOR_DOWN:
          ms.pos.y++;
          break;
        }
        break;
      case 'p':
        paint.stamp=-1;
        if (show_palette)
          paint.color = PaintPalPeek(ms.pos.x, ms.pos.y);
        else
          paint.color = PaintImagePeek(ms.pos.x, ms.pos.y);
        break;
      case 'P':
        paint.stamp=-1;
        show_palette=!show_palette;
        break;
      case 't':
        paint.stamp=-1;
        circle_brush=!circle_brush;
        break;
      case 'o':
        draw_overlay=!draw_overlay;
        break;
      case '+':
        paint.thick++;
        break;
      case '-':
        paint.thick--;
        break;
      case 'x':
        if (stamp_cnt)
          show_stamps=!show_stamps;
        else
          show_stamps=FALSE;
        break;
      case 'v':
        paint.color=AdjColorBrightness(paint.color);
        break;
      case 'V':
        paint.color=AdjColorBrightness(paint.color,-1);
        break;
      case 's':
        paint.color=AdjColorSat(paint.color);
        break;
      case 'S':
        paint.color=AdjColorSat(paint.color,-1);
        break;
      case 'h':
        paint.color=AdjColorHue(paint.color);
        break;
      case 'H':
        paint.color=AdjColorHue(paint.color,-1);
        break;
      case 'r':
        paint.color=AdjColorR(paint.color);
        break;
      case 'g':
        paint.color=AdjColorG(paint.color);
        break;
      case 'b':
        paint.color=AdjColorB(paint.color);
        break;
      case 'R':
        paint.color=AdjColorR(paint.color,-1);
        break;
      case 'G':
        paint.color=AdjColorG(paint.color,-1);
        break;
      case 'B':
        paint.color=AdjColorB(paint.color,-1);
        break;
      case '0'...'9':
        paint.color = ch - '0';
        break;
      case CH_CTRLS:
        PaintSaveImage(cur_filename);
        break;
      case CH_CTRLL:
        PaintLoadImage;
        break;
      case CH_SHIFT_ESC:
        if (cur_filename) PaintSaveImage(cur_filename);
        return FALSE;
      }
end:
      break;
    }
  }
  return TRUE;
}

U0 MainLoop()
{
  while (ProcessInput)
  {
    Yield;
  }
}

public U0 GrPaint(U8 *filename=NULL)
{
  Bool old_ac=AutoComplete(0);
  PopUpOk("\n"
        "$$GREEN$$0-9$$FG$$ to get colors from current palette.\n"
        "$$GREEN$$o$$FG$$ to toggle top banner overlay.\n"
        "$$GREEN$$p$$FG$$ to peek and set brush to color underneath it.\n"
        "$$GREEN$$P$$FG$$ to toggle the color palette.\n"
        "$$GREEN$$x$$FG$$ to toggle the stamp palette.\n"
        "$$GREEN$$t$$FG$$ to toggle brush shape.\n"
        "$$GREEN$$R, G, or B$$FG$$ to increase color values.\n"
        "$$GREEN$$Shift-R, Shift-G, or Shift-B$$FG$$ to decrease.\n"
        "$$GREEN$$H, S, or V$$FG$$ to increase HSV values.\n"
        "$$GREEN$$Shift-H, Shift-S, or Shift-V$$FG$$ to decrease.\n"
        "$$GREEN$$+ or -$$FG$$ to change brush size.\n"
        "$$BLUE$$Ctrl-S$$FG$$ to save image.\n"
        "$$BLUE$$Ctrl-L$$FG$$ to load image.\n\n"
        "$$GREEN$$Left-click$$FG$$ to draw.\n\n"
        "$$RED$$Shift-Esc$$FG$$ to exit.");
  MenuPush("");
  SettingsPush;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  WinVert(0,TEXT_ROWS-1);
  ms.show=0;

  if (filename) cur_filename=filename;
  EnumPaintStamps;

  Fs->draw_it=&DrawIt;
  MainLoop;
  Fs->draw_it=NULL;
  Yield;
  AutoComplete(old_ac);
  DocCursor(1);

  DocClear;
  SettingsPop;
  MenuPop;
  ms.show=1;
}
