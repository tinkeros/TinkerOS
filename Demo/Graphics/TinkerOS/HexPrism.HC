// Dithersparke Hexagonal Prism

#define NUM_SIDES 6

static CD3I32 top_poly[NUM_SIDES];
static CD3I32 bottom_poly[NUM_SIDES];
static CD3I32 side_face[NUM_SIDES][4];


U0 HexPrism()
{
  CDC *dca=DCAlias;
  F64 angle, angle_step, height, radius, x_off, y_off, z_off;

  I64 ch,frame_num,i,next;

  SettingsPush;
  CDC *dc=DCNew(GR_WIDTH,GR_HEIGHT);
  DCDepthBufAlloc(dc);
  DCDepthBufAlloc(dca);

  try
  {
    do
    {
      DCDepthBufRst(dca);
      DCDepthBufRst(dc);

      DCRst(dc);
      DCFill(dc,0);
    
      dc->z=100;

      Mat4x4IdentEqu(dc->r);
      Mat4x4RotX(dc->r,tS*ã/4.0);
      Mat4x4RotZ(dc->r,2.0*tS*ã/8.0);
      dc->flags|=DCF_TRANSFORMATION;
      dc->x=GR_WIDTH/2;
      dc->y=GR_HEIGHT/2;
      dc->thick=1;
      dc->dither_probability_u16=1<<15;

      angle_step = 2.0 * ã / ToF64(NUM_SIDES);
      radius = 50.0;
      height = 75.0;

      for (i=0; i<NUM_SIDES; i++) {
        angle = angle_step * i;
        x_off = radius * Cos(angle);
        y_off = radius * Sin(angle);
        z_off = height / 2.0;

        top_poly[i].x = ToI64(x_off);
        top_poly[i].y = ToI64(y_off);
        top_poly[i].z = ToI64(z_off);

        bottom_poly[i].x = ToI64(x_off);
        bottom_poly[i].y = ToI64(y_off);
        bottom_poly[i].z = ToI64(-z_off);
      }

      dc->color=ROPF_PROBABILITY_DITHER+DKGRAY<<16+WHITE;
      GrFillPoly3(dc,NUM_SIDES,&bottom_poly);

      dc->color=ROPF_PROBABILITY_DITHER+CYAN<<16+BLUE;
      GrFillPoly3(dc,NUM_SIDES,&top_poly);

      for(i=0; i<NUM_SIDES; i++) {
        next = (i + 1) % NUM_SIDES;

        MemCpy(&side_face[i][0],&bottom_poly[i],sizeof(CD3I32));
        MemCpy(&side_face[i][1],&bottom_poly[next],sizeof(CD3I32));
        MemCpy(&side_face[i][2],&top_poly[next],sizeof(CD3I32));
        MemCpy(&side_face[i][3],&top_poly[i],sizeof(CD3I32));

        dc->color=ROPF_PROBABILITY_DITHER+(BLUE+8+i)<<16+(BLUE+i);

        GrFillPoly3(dc,4,&side_face[i]);
      }

      GrBlot3(dca,0,0,50,dc);

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

HexPrism;

