#help_index "Graphics/Color"
public U8 gr_rainbow_10[10]=
{
  BLACK,BROWN,RED,LTRED,YELLOW,GREEN,BLUE,PURPLE,LTGRAY,WHITE
};

DefineLstLoad("ST_RAINBOW_10",
              "BLACK\0BROWN\0RED\0LTRED\0YELLOW\0GREEN\0BLUE\0PURPLE\0LTGRAY\0WHITE\0");

public U0 GrPaletteGet32(CBGR24 *bgr24)
{//16 colors
  MemCpy(bgr24, &gr_palette, sizeof(CBGR24) * 16);
}

public U0 GrPaletteSet32(CBGR24 *bgr24)
{//16 colors
  MemCpy(&gr_palette, bgr24, sizeof(CBGR24) * 16);
}

public CBGR24 gr32_palette_std[COLORS_NUM]=
{
  0x000000, 0x0000AA, 0x00AA00, 0x00AAAA, 0xAA0000, 0xAA00AA, 0xAA5500, 0xAAAAAA,
  0x555555, 0x5555FF, 0x55FF55, 0x55FFFF, 0xFF5555, 0xFF55FF, 0xFFFF55, 0xFFFFFF
};

public U0 PaletteSetStd(Bool persistent=TRUE)
{//Activate std palette.
  GrPaletteSet32(gr32_palette_std);
  GrSetExtPalette;
  if (persistent)
    fp_set_std_palette = &PaletteSetStd;
  VGAFlush;
}

public CBGR24 gr_palette_gray[COLORS_NUM] =
{
  0x000000, 0x111111, 0x222222, 0x333333, 0x444444, 0x555555, 0x666666, 0x777777,
  0x888888, 0x999999, 0xAAAAAA, 0xBBBBBB, 0xCCCCCC, 0xDDDDDD, 0xEEEEEE, 0xFFFFFF
};

public U0 PaletteSetGray(Bool persistent=TRUE)
{//Activate gray palette.
  GrPaletteSet32(gr_palette_gray);
  if (persistent)
    fp_set_std_palette = &PaletteSetGray;
  VGAFlush;
}

public CBGR48 gr_palette_std[COLORS_NUM]=
{
  0x000000000000,0x00000000AAAA,0x0000AAAA0000,0x0000AAAAAAAA,
  0xAAAA00000000,0xAAAA0000AAAA,0xAAAA55550000,0xAAAAAAAAAAAA,
  0x555555555555,0x55555555FFFF,0x5555FFFF5555,0x5555FFFFFFFF,
  0xFFFF55555555,0xFFFF5555FFFF,0xFFFFFFFF5555,0xFFFFFFFFFFFF
};

public CBGR48 gr_palette_gray[COLORS_NUM]=
{
  0x000000000000,0x111111111111,0x222222222222,0x333333333333,
  0x444444444444,0x555555555555,0x666666666666,0x777777777777,
  0x888888888888,0x999999999999,0xAAAAAAAAAAAA,0xBBBBBBBBBBBB,
  0xCCCCCCCCCCCC,0xDDDDDDDDDDDD,0xEEEEEEEEEEEE,0xFFFFFFFFFFFF
};

public U0 GrPaletteColorSet(I64 color_num,CBGR48 bgr48)
{
  gr_palette[color_num].r=bgr48.r.u8[1];
  gr_palette[color_num].g=bgr48.g.u8[1];
  gr_palette[color_num].b=bgr48.b.u8[1];
  VGAFlush;
}

public CBGR48 GrPaletteColorGet(I64 color_num)
{
  CBGR48 res=0;
  res.r=(gr_palette[color_num].r | gr_palette[color_num].r << 8) & 0xffff;
  res.g=(gr_palette[color_num].g | gr_palette[color_num].g << 8) & 0xffff;
  res.b=(gr_palette[color_num].b | gr_palette[color_num].b << 8) & 0xffff;
  return res;
}

public U0 GrPaletteGet(CBGR48 *bgr48)
{//16 colors
  I64 i;
  for (i=0; i<COLORS_NUM; i++)
    bgr48[i]=GrPaletteColorGet(i);
}

public U0 GrPaletteSet(CBGR48 *bgr48)
{//16 colors
  I64 i;
  for (i=0; i<COLORS_NUM; i++)
    GrPaletteColorSet(i,bgr48[i]);
}

public U0 SetBrightness(U64 p)
{//Sets default 16 colors scaled by p/100
  I64 i;
  CBGR48 c;
  for (i=0;i<16;i++)
  {
    c=gr_palette_std[i];
    c.r.u8[1]=ClampU64(c.r.u8[1]*p/100,0,255);
    c.g.u8[1]=ClampU64(c.g.u8[1]*p/100,0,255);
    c.b.u8[1]=ClampU64(c.b.u8[1]*p/100,0,255);
    GrPaletteColorSet(i,c);
  }
}

U8 *Color2Str(U8 *buf,CColorROPU32 c)
{//$LK,"CColorROPU32",A="MN:CColorROPU32"$ with flags to $LK,"DCLighting",A="MN:DCLighting"$ str.
  *buf=0;
  if (c.c0.rop&ROPBF_TWO_SIDED)
    CatPrint(buf,"TWO|");
  if (c.c0.rop&ROPBF_HALF_RANGE_COLOR)
    CatPrint(buf,"HALF|");
  if (0<=c.c0.color<16)
    CatPrint(buf,DefineSub(c.c0.color,"ST_COLORS"));
  else if (c.c0.color==TRANSPARENT)
    CatPrint(buf,"TRANSPARENT");
  else
    CatPrint(buf,"INVALID");
  if (c&ROPF_DITHER)
  {
    CatPrint(buf,"/");
    if (c.c1.rop&ROPBF_TWO_SIDED)
      CatPrint(buf,"TWO|");
    if (c.c1.rop&ROPBF_HALF_RANGE_COLOR)
      CatPrint(buf,"HALF|");
    if (0<=c.c1.color<16)
      CatPrint(buf,DefineSub(c.c1.color,"ST_COLORS"));
    else if (c.c1.color==TRANSPARENT)
      CatPrint(buf,"TRANSPARENT");
    else
      CatPrint(buf,"INVALID");
  }
  return buf;
}

U8 *str2color_lst="/,)}>";

CColorROPU16 Str2ColorU16(U8 *st)
{//$LK,"DCLighting",A="MN:DCLighting"$ color str with flags to $LK,"CColorROPU16",A="MN:CColorROPU16"$.
  CColorROPU16 res=COLOR_INVALID;
  I64 i;
  U8 *ptr,*ptr2,*st2;
  if (!st) return COLOR_INVALID;
  while (TRUE)
  {
    if (!*st||StrOcc(str2color_lst,*st))
      return res;
    if (Bt(char_bmp_alpha,*st))
    {
      ptr=st;
      while (Bt(char_bmp_alpha_numeric,*ptr))
        ptr++;
      st2=ptr2=MAlloc(ptr-st+1);
      while (st<ptr)
        *ptr2++=*st++;
      *ptr2++=0;
      if (!StrICmp(st2,"TWO"))
        res.rop|=ROPBF_TWO_SIDED;
      else if (!StrICmp(st2,"HALF"))
        res.rop|=ROPBF_HALF_RANGE_COLOR;
      else if ((i=DefineMatch(st2,"ST_COLORS",LMF_IGNORE_CASE))>=0)
        res.color=i;
      else if (!StrICmp(st2,"TRANSPARENT"))
        res.color=TRANSPARENT;
      else
      {
        Free(st2);
        return COLOR_INVALID;
      }
      Free(st2);
    }
    else if (*st=='+'||*st=='|'||Bt(char_bmp_white_space,*st))
      st++;
    else if ('0'<=*st<='9')
    {
      i=Str2I64(st,10,&ptr);
      if (0<=i<=0xFF)
      {
        res.color=i;
        st=ptr;
      }
      else
        return COLOR_INVALID;
    }
    else
      return COLOR_INVALID;
  }
}

CColorROPU32 Str2ColorU32(U8 *st)
{//$LK,"DCLighting",A="MN:DCLighting"$ color str with flags to $LK,"CColorROPU32",A="MN:CColorROPU32"$.
  U8 *st2;
  CColorROPU32 res=0;
  if (!st) return COLOR_INVALID;
  st2=MAlloc(StrLen(st)+1);
  StrFirstRem(st,str2color_lst,st2);
  res.c0=Str2ColorU16(st2);
  if (*st)
  {
    res.c1=Str2ColorU16(st);
    res|=ROPF_DITHER;
  }
  if (res.c0.color==COLOR_INVALID||res.c1.color==COLOR_INVALID)
    return COLOR_INVALID;
  else
    return res;
}
