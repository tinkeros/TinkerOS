//Uses $LK,"fixed-point",A="FI:::/Demo/Lectures/FixedPoint.HC"$.















$SP,"<1>",BI=1,BP="./Mountain.HC.Z,Mountain"$ //Pointer to sprite in $LK,"Mountain.HC",A="FI:./Mountain.HC"$ file

#define CLOUDS_NUM		16
#define SKY_LINES		30
#define CLOUD_PTS		512
#define CLOUD_PENS		8
#define CLOUD_PEN_PTS	16
#define CLOUD_PEN_SIZE		16

                  class Cloud
{
  I64 i,x,y,w,h,dx,dy;
  I64 color;
  I64 px[CLOUD_PTS],py[CLOUD_PTS],pc[CLOUD_PTS];
} clouds[CLOUDS_NUM];

class CloudPen
{
  CDC *img;
  I64 px[CLOUD_PEN_PTS],py[CLOUD_PEN_PTS];
} cloud_pens[CLOUD_PENS];

CDC *cloud_pen;

I64 mp_not_done_flags;
U0 MPDrawClouds(CTask *task)
{
  Cloud *c;
  CDC *dc=DCAlias(gr.dc2,task);
  I64 i,j,k,xx,yy,lo=Gs->num*CLOUD_PTS/mp_cnt,hi=(Gs->num+1)*CLOUD_PTS/mp_cnt;
  for (j=0,c=clouds; j<CLOUDS_NUM; j++,c++)
    for (i=lo; i<hi; i++)
    {
      k=c->pc[i];
      if (k<c->color)
        dc->color=ROP_MONO+LTGRAY;
      else
        dc->color=ROP_MONO+WHITE;
      xx=c->x.i32[1]+c->px[i];
      yy=c->y.i32[1]+c->py[i];
      k=RandU16&31-16;
      if (k==-16)
        k=-c->px[i];
      c->px[i]+=SignI64(k);
      k=RandU16&31-16;
      if (k==-16)
        k=-c->py[i];
      c->py[i]+=SignI64(k);
      GrBlot(dc,xx,yy,cloud_pens[i&(CLOUD_PENS-1)].img);
    }
  DCDel(dc);
  LBtr(&mp_not_done_flags,Gs->num);
}

U0 DrawIt(CTask *task,CDC *dc)
{
  I64 i;
  Sprite3(dc,0,SKY_LINES*FONT_HEIGHT,0,$IB,"<1>",BI=1$);
  mp_not_done_flags=1<<mp_cnt-1;
  for (i=0; i<mp_cnt; i++)
    JobQue(&MPDrawClouds,task,i);
  while (mp_not_done_flags)
    Yield;
}

U0 AnimateTask(I64)
{
  I64 i,j;
  Cloud *c;
  CloudPen *cp;
  while (TRUE)
  {
    Refresh;
    for (i=0,cp=cloud_pens; i<CLOUD_PENS; i++,cp++)
    {
      DCClear(cp->img);
      cp->img->color=COLOR_MONO;
      for (j=0; j<CLOUD_PEN_PTS; j++)
      {
        GrPlot(cp->img,cp->px[j],cp->py[j]);
        cp->px[j]=ClampI64(cp->px[j]+RandU16%3-1,0,CLOUD_PEN_SIZE-1);
        cp->py[j]=ClampI64(cp->py[j]+RandU16%3-1,0,CLOUD_PEN_SIZE-1);
      }
    }
    for (i=0,c=clouds; i<CLOUDS_NUM; i++,c++)
    {
      c->x+=c->dx;
      c->y=ClampI64(c->y+c->dy,0,0.7*(SKY_LINES*FONT_HEIGHT)<<32);
      c->color=U16_MAX*c->y.i32[1]/(0.8*(SKY_LINES*FONT_HEIGHT));
    }
    Sleep(20);
  }
}

#define SAMPLES	6
U0 Init()
{
  Cloud *c=clouds;
  CloudPen *cp=cloud_pens;
  I64 i,j,k,l,
      w=Fs->pix_width,
      h=SKY_LINES*FONT_HEIGHT;
  for (i=0; i<CLOUDS_NUM; i++,c++)
  {
    c->x=ToI64(w/2+Rand*w/2-w/4)<<32;
    c->y=ToI64(h/2+Rand*h/2-h/4)<<32;
    c->dx=RandI32;
    c->dy=RandI32;
    c->w=100;
    c->h=50;
    c->color=RandU16;
    for (l=0; l<CLOUD_PTS; l++)
    {
      k=0;
      for (j=0; j<SAMPLES; j++)
        k+=RandI16;
      c->px[l]=(k*c->w/I16_MAX)/SAMPLES;
      k=0;
      for (j=0; j<SAMPLES; j++)
        k+=RandI16;
      c->py[l]=(k*c->h/I16_MAX)/SAMPLES;
      c->pc[l]=RandU16;
    }
  }
  for (i=0; i<CLOUD_PENS; i++,cp++)
  {
    cp->img=DCNew(CLOUD_PEN_SIZE,CLOUD_PEN_SIZE);
    for (j=0; j<CLOUD_PEN_PTS; j++)
    {
      cp->px[j]=RandU16%CLOUD_PEN_SIZE;
      cp->py[j]=RandU16%CLOUD_PEN_SIZE;
    }
  }
}

U0 CleanUp()
{
  I64 i;
  CloudPen *cp=cloud_pens;
  for (i=0; i<CLOUD_PENS; i++,cp++)
    DCDel(cp->img);
}

U0 SongTask(I64)
{//Song by the Holy Spirit
//This specifies a callback routine
  //to be called when the task dies.
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  while (TRUE)
  {
    Play("4qB5etD4AG5qD4sG5E4G5EetCEDqFEeDC");
    Play("4qB5etD4AG5qD4sG5E4G5EetCEDqFEeDC");
    Play("5CGqD4eA5DsDCDCqGEetD4A5D4sG5D4G5D");
    Play("5eCGqD4eA5DsDCDCqGEetD4A5D4sG5D4G5D");
  }
}

U0 CloudScene()
{
  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  try
  {
    Fs->text_attr=YELLOW<<4+BLUE;
    Fs->song_task=Spawn(&SongTask,NULL,"Song",,Fs);
    AutoComplete;
    WinBorder;
    WinMax;
    DocCursor;
    DocClear;
    Init;
    Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
    "$$BG,LTCYAN$$%h*c"
    ,SKY_LINES,'\n';
    "$$BG,YELLOW$$%h5c"
    ,'\n';
    BibleVerse(,"Exodus,14:19",7);
    Fs->draw_it=&DrawIt;
    GetChar;
    Refresh;
  }
  catch
    PutExcept;
  SettingsPop;
  CleanUp;
}

#if __CMD_LINE__
CloudScene;
#endif
