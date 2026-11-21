// Terry HV_SWAP shadow dance
//
// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("ShadowDance.HC");

#define TSD_DEC_MAX_SPANS	127
#define TSD_FILENAME		"::/Demo/ScreenSavers/ShadowDance.BIN.Z"

class CTSDPlayer
{
  U8  *file,*start,*ptr;
  I64 width,height,num_imgs,ystep,rows, *k;
  I32 *st,*en;
};

CTSDPlayer *TSDOpen(U8 *filename)
{
  CTSDPlayer *tp;
  U8 *b=FileRead(filename);
  if (!b) return NULL;
  tp=CAlloc(sizeof(CTSDPlayer));
  tp->file=b;
  tp->width   =b[0]<<8 | b[1];
  tp->height  =b[2]<<8 | b[3];
  tp->num_imgs=b[4]<<8 | b[5];
  tp->ystep   =b[6];
  tp->rows=(tp->height+tp->ystep-1)/tp->ystep;
  tp->start=b+7;
  tp->ptr=tp->start;
  tp->k =CAlloc(tp->rows*sizeof(I64));
  tp->st=CAlloc(tp->rows*TSD_DEC_MAX_SPANS*sizeof(I32));
  tp->en=CAlloc(tp->rows*TSD_DEC_MAX_SPANS*sizeof(I32));
  return tp;
}

U0 TSDRewind(CTSDPlayer *tp)
{
  tp->ptr=tp->start;
  MemSet(tp->k,0,tp->rows*sizeof(I64));
}

U0 TSDNextFrame(CTSDPlayer *tp,CDC *dc)
{
  I64 ry,y,y2,j,c,k,d;
  I32 *st,*en;
  U8 *p=tp->ptr;

  MemSetU8(dc->body,0xFF,dc->width_internal*tp->height);
  for (ry=0; ry<tp->rows; ry++)
  {
    st=tp->st+ry*TSD_DEC_MAX_SPANS;
    en=tp->en+ry*TSD_DEC_MAX_SPANS;
    c=*p++;
    if (c!=0xFF)
    {
      k=c&0x7F;
      if (c&0x80)
      {
        for (j=0; j<k; j++)
        {
          d=*p++; if (d>=128) d-=256;
          st[j]+=d;
          d=*p++; if (d>=128) d-=256;
          en[j]+=d;
        }
      }
      else
      {
        for (j=0; j<k; j++)
        {
          st[j]=p[0]<<8 | p[1];
          en[j]=p[2]<<8 | p[3];
          p+=4;
        }
      }
      tp->k[ry]=k;
    }
    k=tp->k[ry];
    y2=(ry+1)*tp->ystep;
    if (y2>tp->height) y2=tp->height;
    for (y=ry*tp->ystep; y<y2; y++)
      for (j=0; j<k; j++)
        MemSetU8(dc->body+y*dc->width_internal+st[j],0,en[j]-st[j]);
  }
  tp->ptr=p;
}

U0 ShadowDanceTask(U8 *data)
{
  CDC *dc=data;
  I64 i=0,x=0,y=0,xdir=1,ydir=1,width,height;
  CTSDPlayer *tp=TSDOpen(TSD_FILENAME);
  if (!tp) return;
  width=tp->width;
  height=tp->height;
  CDC *tdance=DCNew(width,height);
  CDC *back=DCNew(GR_WIDTH,GR_HEIGHT);
  while(TRUE)
  {
    x=x+xdir;
    y=y+ydir;
    if (x>GR_WIDTH-width)
    {
      x--;
      xdir=-1;
    }
    if (x<0)
    {
      x++;
      xdir=1;
    }
    if (y>GR_HEIGHT-height)
    {
      y--;
      ydir=-1;
    }
    if (y<0)
    {
      y++;
      ydir=1;
    }
    if (i>=tp->num_imgs)
    {
      TSDRewind(tp);
      i=0;
    }
    MemCpy(back->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    TSDNextFrame(tp,tdance);

    back->color=ROP_HV_SWAP+HV_SWAP_ALL;

    GrBlot(back,x,y,tdance);
    MemCpy(dc->body,back->body,GR_WIDTH*GR_HEIGHT);
    i++;
    Sleep(20);
  }
}

U0 ScreenSaverShadowDance(CDC *dc, I64 ss_cnts)
{
  if (!ss_cnts)
  {
    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    gr.scrn_saver_task=Spawn(&ShadowDanceTask,dc,"Screen Saver Task");
  }
}

if (IsFileZorNotZ(TSD_FILENAME))
  gr.fp_draw_ss=&ScreenSaverShadowDance;
else
  PrintErr("ShadowDance: \"%s\" not found.\n",TSD_FILENAME);
