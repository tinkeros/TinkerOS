static U8 steps[6] = {0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF};

public U0 GrSetRGB(I64 color_num,U8 r, U8 g, U8 b)
{ // Sets color from r,g,b values 0-255
  gr_palette[color_num].r=r;
  gr_palette[color_num].g=g;
  gr_palette[color_num].b=b;
  VGAFlush;
}

public U0 GrSetExtPalette() {
// Adds extra 214 web-safe colors not already in CGA palette
    I64 r,g,b,cnt = 16;
    U32 color;

    for (r = 0; r < 6; r++) {
        for (g = 0; g < 6; g++) {
            for (b = 0; b < 6; b++) {
                color = steps[r] << 16 | steps[g] << 8 | steps[b];

                // Skip pure black and pure white, they are in CGA palette
                if (color != 0x000000 && color != 0xFFFFFF) 
                  GrSetRGB(cnt++,steps[r], steps[g], steps[b]);
            }
        }
    }
}


static I64 safe_levels[6] = {0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF};

I64 NearestLvlIdx(I64 value)
{ // Map r,g,b 255 value to nearest index in {0x00, 0x33, ..., 0xFF}
    I64 i, closest_index = 0, diff, min_diff = AbsI64(value - safe_levels[0]);

    for (i = 1; i < 6; i++) {
        diff = AbsI64(value - safe_levels[i]);
        if (diff < min_diff) {
            min_diff = diff;
            closest_index = i;
        }
    }

    return closest_index;
}

public I64 GetColorNum(U8 r, U8 g, U8 b)
{ // Return index (0..215) of nearest web-safe color

    I64 val, ri, gi, bi;
    ri = NearestLvlIdx(r);
    gi = NearestLvlIdx(g);
    bi = NearestLvlIdx(b);

    val = ri * 36 + gi * 6 + bi;

    if (!val) return 0;
    if (val == 215) return 15;
    return val + 15;
}

public I64 GetNearestColorNum(U8 r, U8 g, U8 b)
{// Get neartest TinkerOS color
    I64 i, val, ri, gi, bi, safe_diff, tos_diff;
    CBGR48 tmp_clr;
    ri = NearestLvlIdx(r);
    gi = NearestLvlIdx(g);
    bi = NearestLvlIdx(b);

    val = ri * 36 + gi * 6 + bi;

    safe_diff  = AbsI64(r - safe_levels[ri]);
    safe_diff += AbsI64(g - safe_levels[gi]);
    safe_diff += AbsI64(b - safe_levels[bi]);  

    for (i=0;i<16;i++)
    {
      tmp_clr = GrPaletteColorGet(i);
      tos_diff  = AbsI64(r - tmp_clr.r.u8[1]);
      tos_diff += AbsI64(g - tmp_clr.g.u8[1]);
      tos_diff += AbsI64(b - tmp_clr.b.u8[1]);  
      if (tos_diff<safe_diff) return i;
    }

    if (!val) return 0;
    if (val == 215) return 15;
    return val + 15;
}

F64 FMod(F64 x, F64 y)
{
  if (y==0.0) return 0.0;

  F64 r, q = x /y;
  I64 qi = ToI64(q);

  r = x - ToF64(qi)*y;

  return r;
}

U0 HSV2RGB(F64 h, F64 s, F64 v, CBGR48 *color) {
    F64 c = v * s, x, m, r, g, b;
    x = c * (1 - Abs(FMod(h / 60.0, 2) - 1));
    m = v - c;
    
    if (h < 60) {
        r = c; g = x; b = 0;
    } else if (h < 120) {
        r = x; g = c; b = 0;
    } else if (h < 180) {
        r = 0; g = c; b = x;
    } else if (h < 240) {
        r = 0; g = x; b = c;
    } else if (h < 300) {
        r = x; g = 0; b = c;
    } else {
        r = c; g = 0; b = x;
    }
    
    color->r.u8[1]=ClampU64(ToI64((r + m) * 255),0,255);
    color->g.u8[1]=ClampU64(ToI64((g + m) * 255),0,255);
    color->b.u8[1]=ClampU64(ToI64((b + m) * 255),0,255);
}

U0 RGB2HSV(CBGR48 *color, F64 *h, F64 *s, F64 *v)
{
    F64 r,g,b,delta,maxc,minc;

    r = ToF64(color->r.u8[1]) / 255.0;
    g = ToF64(color->g.u8[1]) / 255.0;
    b = ToF64(color->b.u8[1]) / 255.0;
    minc = maxc = r;

    if (g > maxc) maxc = g;
    if (b > maxc) maxc = b;

    if (g < minc) minc = g;
    if (b < minc) minc = b;

    delta = maxc - minc;

    // Value
    *v = maxc;

    // Saturation
    if (maxc == 0.0)
        *s = 0.0;
    else
        *s = delta / maxc;

    // Hue
    if (delta == 0.0) {
        *h = 0.0; // Undefined hue, return 0
    } else {
        if (maxc == r) {
            *h = 60.0 * FMod((g - b) / delta, 6.0);
        } else if (maxc == g) {
            *h = 60.0 * ((b - r) / delta + 2.0);
        } else {
            *h = 60.0 * ((r - g) / delta + 4.0);
        }
    }

    // Ensure hue is positive
    if (*h < 0.0)
        *h += 360.0;
}

public I64 AdjColorBrightness(U8 color, I64 dir=1)
{// change color brightness
    I64 new_color, cnt=32;
    F64 h,s,v;
    CBGR48 tmp_clr=GrPaletteColorGet(color);
    RGB2HSV(&tmp_clr,&h,&s,&v);
    new_color=color;
    while (cnt && new_color==color)
    {
      cnt--;
      v+=ToF64(dir)/64.0;
      v=Clamp(v,0.0,1.0);
      
      HSV2RGB(h, s, v, &tmp_clr);
      new_color=GetNearestColorNum(tmp_clr.r.u8[1],tmp_clr.g.u8[1],tmp_clr.b.u8[1]);
    }
    return new_color;
}

public I64 AdjColorSat(U8 color, I64 dir=1)
{// change color saturation
    I64 new_color, cnt=32;
    F64 h,s,v;
    CBGR48 tmp_clr=GrPaletteColorGet(color);
    RGB2HSV(&tmp_clr,&h,&s,&v);
    new_color=color;
    while (cnt && new_color==color)
    {
      cnt--;
      s+=ToF64(dir)/64.0;
      s=Clamp(s,0.0,1.0);

      HSV2RGB(h, s, v, &tmp_clr);
      new_color=GetNearestColorNum(tmp_clr.r.u8[1],tmp_clr.g.u8[1],tmp_clr.b.u8[1]);
    }
    return new_color;
}

public I64 AdjColorHue(U8 color, I64 dir=1)
{// change color hue
    I64 new_color, cnt=64;
    F64 h,s,v;
    CBGR48 tmp_clr=GrPaletteColorGet(color);
    RGB2HSV(&tmp_clr,&h,&s,&v);
    new_color=color;
    while (cnt && new_color==color)
    {
      cnt--;
      h+=ToF64(dir);
      h=Clamp(h,0.0,360.0);

      HSV2RGB(h, s, v, &tmp_clr);
      new_color=GetNearestColorNum(tmp_clr.r.u8[1],tmp_clr.g.u8[1],tmp_clr.b.u8[1]);
    }
    return new_color;
}

public I64 AdjColorR(U8 color, I64 dir=1)
{// change color R value
    I64 new_color, cnt=16;
    CBGR48 tmp_clr=GrPaletteColorGet(color);
    new_color=color;
    while (cnt && new_color==color)
    {
      cnt--;
      tmp_clr.r.u8[1]=ClampI64(tmp_clr.r.u8[1]+16*dir,0,255);
      new_color=GetNearestColorNum(tmp_clr.r.u8[1],tmp_clr.g.u8[1],tmp_clr.b.u8[1]);
    }
    return new_color;
}

public I64 AdjColorG(U8 color, I64 dir=1)
{// change color G value
    I64 new_color, cnt=16;
    CBGR48 tmp_clr=GrPaletteColorGet(color);
    new_color=color;
    while (cnt && new_color==color)
    {
      cnt--;
      tmp_clr.g.u8[1]=ClampI64(tmp_clr.g.u8[1]+16*dir,0,255);
      new_color=GetNearestColorNum(tmp_clr.r.u8[1],tmp_clr.g.u8[1],tmp_clr.b.u8[1]);
    }
    return new_color;
}

public I64 AdjColorB(U8 color, I64 dir=1)
{// change color B value
    I64 new_color, cnt=16;
    CBGR48 tmp_clr=GrPaletteColorGet(color);
    new_color=color;
    while (cnt && new_color==color)
    {
      cnt--;
      tmp_clr.b.u8[1]=ClampI64(tmp_clr.b.u8[1]+16*dir,0,255);
      new_color=GetNearestColorNum(tmp_clr.r.u8[1],tmp_clr.g.u8[1],tmp_clr.b.u8[1]);
    }
    return new_color;
}
