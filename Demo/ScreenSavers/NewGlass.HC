// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("NewGlass.HC");
//
// Thanks Rendello!

U0 NewGlassTask(U8 *data)
{
  I64 i;
  I64 phase=0;
  F64 x=1;
  F64 y=1;
  F64 frame=1;
  CDC *dc=data;
  for (i=0; i<COLORS_NUM; i++)
  {
    // +16 to modify/use TinkerOS extended palette
    // and leave default 16 colors alone
    GrPaletteColorSet(i+16,i*5432543264755675350);
  }
  while (TRUE)
  {
    if (frame>200)
    {
      frame=0;
      phase=(phase+1)%4;
    }
    frame+=.000016;
    if (phase==0)
    {
      dc->color=(Sin((x+frame)/(y+1)-Sin(frame/20))*(frame/10))&15+16;
    }
    else if (phase==1)
    {
      dc->color=(Sin(x/frame)*y)&15+16;
    }
    else if (phase==2)
    {
      dc->color=(frame/Sin(x/20)*(y+1))&15+16;
    }
    else
    {
      dc->color=(x*(frame*y))&15+16;
    }
    GrRect(dc,x,y,2,2);
    x=(x+RandRange(,3))%GR_WIDTH;
    y=(y+RandRange(,5))%GR_HEIGHT;
    Sleep(.1);
    // Note a screen saver must yield or it cannot be drawn!
    // Sleep calls Yield
  }
}


// Window manager tries to call this as
// many times per second as the frame rate.
//
// Every time it is called it increments
// ss_cnts starting with 0
//
// Here we just use it once to copy the
// current screen and spawn a task to
// draw the screen saved version.
U0 ScreenSaverNewGlass(CDC *dc, I64 ss_cnts)
{
  if (!ss_cnts)
  {
    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    gr.scrn_saver_task=Spawn(&NewGlassTask,dc,"Screen Saver Task");
  }
}

gr.fp_draw_ss=&ScreenSaverNewGlass;
