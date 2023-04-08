// This file contains utility functions

U0 GrChar(CDC *dc=gr.dc, U8 ch, I64 x, I64 y, I64 scale=1)
{
  I64 i,j,k=0;
  for (i=0; i<FONT_HEIGHT; i++)
  {
    for (j=0; j<FONT_WIDTH; j++)
    {
      if (Bt(&text.font[ch],k++))
      {
        GrRect(dc, x+j*scale, y+i*scale, scale, scale);
      }
    }
  }
}

U0 GrRndRect(CDC *dc=gr.dc, I64 x, I64 y, I64 w, I64 h, I64 rad)
{// Draw a rounded rectangle, rad is the radius
  GrFillCircle(dc, x,   y,, rad*2);
  GrFillCircle(dc, x+w, y,, rad*2);
  GrFillCircle(dc, x,   y+h,, rad*2);
  GrFillCircle(dc, x+w, y+h,, rad*2);
  GrRect(dc, x,     y-rad, w,        h+(rad*2));
  GrRect(dc, x-rad, y,     w+(rad*2), h);
}

I64 RandRng(I64 min=0, I64 max)
{
  return min+(Rand() * (max-min-1));
}

Bool U8InStr(U8 ch, U8 *str)
{
  I64 i;
  for (i=0; i<StrLen(str); i++)
  {
    if (ch == str[i])
    {
      return TRUE;
    }
  }
  return FALSE;
}
