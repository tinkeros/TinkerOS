// Demo all 230 colors of the TinkerOS palette sorted

#define PS_CATS         20
#define PS_PER_CAT      12
#define PS_COLORS       230
#define PS_LABEL_CHARS  10
#define PS_NUM_CHARS    3

#define PS_MIN_CONTRAST 4.5

#define PS_EGGPLANT_FIRST 16

static U8 *ps_names[PS_CATS]={
  "Greyscale", "CGA colors", "Lemon", "Apricot",
  "Orange", "Pumpkin", "Tomato", "Cherry",
  "Plum", "Chestnut", "Olive", "Olive 2",
  "Pear", "Honeydew", "Lime", "Apple",
  "Pistachio", "Kiwi", "Avocado", "Eggplant"
};

static I64 ps_cnt[PS_CATS]={
  8, 12, 11, 11, 12, 12, 12, 12, 12, 12,
  11, 11, 12, 12, 12, 12, 12, 12, 11, 11
};

static I64 ps_cols[PS_CATS][PS_PER_CAT]={
  {   0,  58,   8, 101, 144,   7, 187,  15,  -1,  -1,  -1,  -1},
  {   4,  12,   6,  14,   2,  10,   3,  11,   1,   9,   5,  13},
  { 189, 190, 191, 192, 193, 194, 229, 228, 227, 226, 225,  -1},
  { 183, 184, 185, 186, 188, 224, 223, 222, 221, 220, 219,  -1},
  { 177, 178, 179, 180, 181, 182, 218, 217, 216, 215, 214, 213},
  { 171, 172, 173, 174, 175, 176, 212, 211, 210, 209, 208, 207},
  { 165, 166, 167, 168, 169, 170, 206, 205, 204, 203, 202, 201},
  { 159, 160, 161, 162, 163, 164, 200, 199, 198, 197, 196, 195},
  {  87,  88,  89,  90,  91,  92, 128, 127, 126, 125, 124, 123},
  {  93,  94,  95,  96,  97,  98, 134, 133, 132, 131, 130, 129},
  {  99, 100, 102, 103, 104, 140, 139, 138, 137, 136, 135,  -1},
  { 105, 106, 107, 108, 109, 110, 146, 145, 143, 142, 141,  -1},
  { 111, 112, 113, 114, 115, 116, 152, 151, 150, 149, 148, 147},
  { 117, 118, 119, 120, 121, 122, 158, 157, 156, 155, 154, 153},
  {  45,  46,  47,  48,  49,  50,  86,  85,  84,  83,  82,  81},
  {  39,  40,  41,  42,  43,  44,  80,  79,  78,  77,  76,  75},
  {  33,  34,  35,  36,  37,  38,  74,  73,  72,  71,  70,  69},
  {  27,  28,  29,  30,  31,  32,  68,  67,  66,  65,  64,  63},
  {  21,  22,  23,  24,  25,  26,  62,  61,  60,  59,  57,  -1},
  {  16,  17,  18,  19,  20,  56,  55,  54,  53,  52,  51,  -1}
};

static F64 ps_sats[5]={1.0, 0.8, 0.6, 0.4, 0.2};
static F64 ps_vals[6]={0.0, 0.2, 0.4, 0.6, 0.8, 1.0};

F64 PSLum(CBGR48 *c)
{// Gamma-2.0 approximation of WCAG relative luminance, 0.0 to 1.0.
  F64 r=ToF64(c->r.u8[1])/255.0,
      g=ToF64(c->g.u8[1])/255.0,
      b=ToF64(c->b.u8[1])/255.0;
  return 0.2126*r*r+0.7152*g*g+0.0722*b*b;
}

F64 PSContrast(F64 l1,F64 l2)
{// WCAG contrast ratio: 1.0 identical, 21.0 for black against white.
  if (l1<l2)
    return (l2+0.05)/(l1+0.05);
  return (l1+0.05)/(l2+0.05);
}

I64 PSOppColor(I64 color_num)
{// Pick the label color for a swatch.
  I64 i,j,cand,best=WHITE,best_ok=-1;
  F64 h,s,v,cand_h,cand_s,cand_v,try_s,try_v,bg_lum,cand_lum,ratio,
      best_ratio=-1.0,best_ok_sat=-1.0,best_ok_ratio=-1.0;
  CBGR48 bg=GrPaletteColorGet(color_num),tmp;
  Bool grey;

  if (color_num==BLACK)
    return WHITE;
  if (color_num==PS_EGGPLANT_FIRST)
    return LTGRAY;

  bg_lum=PSLum(&bg);
  RGB2HSV(&bg,&h,&s,&v);
  grey=(s<0.10);
  h+=180.0;
  if (h>=360.0)
    h-=360.0;

  for (i=0; i<5; i++)
    for (j=0; j<6; j++)
    {
      if (grey)
        try_s=0.0;
      else
        try_s=ps_sats[i];
      try_v=ps_vals[j];
      HSV2RGB(h,try_s,try_v,&tmp);
      cand=GetNearestColorNum(tmp.r.u8[1],tmp.g.u8[1],tmp.b.u8[1]);

      tmp=GrPaletteColorGet(cand);
      cand_lum=PSLum(&tmp);
      ratio=PSContrast(bg_lum,cand_lum);
      if (ratio>best_ratio)
      {
        best_ratio=ratio;
        best=cand;
      }
      if (ratio>=PS_MIN_CONTRAST)
      {
        RGB2HSV(&tmp,&cand_h,&cand_s,&cand_v);
        if ((cand_s>best_ok_sat) ||
            (cand_s==best_ok_sat && ratio>best_ok_ratio))
        {
          best_ok_sat=cand_s;
          best_ok_ratio=ratio;
          best_ok=cand;
        }
      }
    }
  if (best_ok>=0)
    return best_ok;
  return best;
}

U0 PSDraw(CDC *img,I64 w,I64 h)
{// Render the whole chart once into an off-screen DC.
  I64 c,i,n,x,y,hdr_h,lbl_w,row_h,cell_w,sw_w,sw_h,num_w;

  hdr_h =FONT_HEIGHT+4;
  lbl_w =FONT_WIDTH*PS_LABEL_CHARS;
  num_w =FONT_WIDTH*PS_NUM_CHARS;
  row_h =(h-hdr_h)/PS_CATS;
  cell_w=(w-lbl_w)/PS_PER_CAT;
  if (row_h<FONT_HEIGHT+2)
    row_h=FONT_HEIGHT+2;
  if (cell_w<num_w+2)
    cell_w=num_w+2;
  sw_w=cell_w-2;
  sw_h=row_h-2;

  DCFill(img,BLACK);
  img->color=WHITE;
  GrPrint(img,0,0,
      "TinkerOS palette: %d colors by category - press any key to exit",
      PS_COLORS);

  for (n=0; n<PS_CATS; n++)
  {
    y=hdr_h+n*row_h;
    img->color=WHITE;
    GrPrint(img,0,y+(sw_h-FONT_HEIGHT)/2,"%s",ps_names[n]);
    for (i=0; i<ps_cnt[n]; i++)
    {
      c=ps_cols[n][i];
      x=lbl_w+i*cell_w;
      img->color=c;
      GrRect(img,x,y,sw_w,sw_h);
      img->color=PSOppColor(c);
      GrPrint(img,x+(sw_w-num_w)/2,y+(sw_h-FONT_HEIGHT)/2,"%03d",c);
    }
  }
}

U0 PalSortDemo()
{
  CDC *dc=DCAlias,*img;
  I64 w,h;

  SettingsPush;
  WinMax;
  DocCursor(OFF);

  w=Fs->pix_width;
  h=Fs->pix_height;
  img=DCNew(w,h);
  PSDraw(img,w,h);

  while (!ScanChar)
  {
    GrBlot(dc,0,0,img);
    Sleep(10);
  }

  DCDel(img);
  DCFill(dc);
  DCDel(dc);
  DocCursor(ON);
  SettingsPop;
}

PalSortDemo;
