// Texas Dithersparkle Flag

static CD3I32 t1[3] = { {40, 90, 0}, {47, 110, 0}, {33, 110, 0} };
static CD3I32 t2[3] = { {68, 110, 0}, {52, 124, 0}, {47, 110, 0} };
static CD3I32 t3[3] = { {59, 145, 0}, {40, 132, 0}, {52, 124, 0} };
static CD3I32 t4[3] = { {21, 145, 0}, {28, 124, 0}, {40, 132, 0} };
static CD3I32 t5[3] = { {12, 110, 0}, {33, 110, 0}, {28, 124, 0} };
static CD3I32 p[5] = { {47, 110, 0}, {52, 124, 0}, {40, 132, 0}, {28, 124, 0}, {33, 110, 0} };

U0 TexasFlag()
{
  I64 ch;
  CDC *dca=DCAlias;
  SettingsPush;
  CDC *dc=DCNew(240,240);
  DCDepthBufAlloc(dc);
  dc->z=5;

  try
  {
    do
    {
      DCFill(dc,BLACK);
      dc->color=WHITE;
      dc->thick=1;
      dc->dither_probability_u16=1<<15;
      dc->color=ROPF_PROBABILITY_DITHER+BLUE<<16+LTBLUE;
      GrRect3(dc,0,40,0,240,160);
      dc->color=ROPF_PROBABILITY_DITHER+RED<<16+LTRED;
      GrRect3(dc,80,120,0,160,80);
      dc->color=ROPF_PROBABILITY_DITHER+LTGRAY<<16+WHITE;
      GrRect3(dc,80,40,0,160,80);

      GrFillPoly3(dc,3,&t1);
      GrFillPoly3(dc,3,&t2);
      GrFillPoly3(dc,3,&t3);
      GrFillPoly3(dc,3,&t4);
      GrFillPoly3(dc,3,&t5);
      GrFillPoly3(dc,5,&p);

      GrBlot(dca,0,0,dc);

      Yield;
    }
    while (!(ch=ScanChar) || (ch!=CH_SHIFT_ESC && ch!=CH_ESC));
  }
  catch
    PutExcept;

  DCFill(dca);
  DCDel(dca);
  DCDel(dc);
  SettingsPop;
}

TexasFlag;

