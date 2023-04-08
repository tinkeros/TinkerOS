// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("LineSand.HC");
//
// Thanks Rendello!

#define RAINDROP_NO 1000

U0 LineSandTask(U8 *data)
{
  I64 i;
  I64 raindrops[RAINDROP_NO][3];
  CDC *dc=data;
  for (i=0; i<RAINDROP_NO; i++)
  {
    raindrops[i][0]=RandRange(,GR_WIDTH);
    raindrops[i][1]=-RandRange(,GR_HEIGHT);
    raindrops[i][2]=BLUE;
  }
  while (TRUE)
  {
    for (i=0; i<RAINDROP_NO; i++)
    {
      dc->color=raindrops[i][2];
      GrCircle(dc,raindrops[i][0],raindrops[i][1],1);
      raindrops[i][0]=(raindrops[i][0]+RandRange(,4))%GR_WIDTH;
      raindrops[i][1]=(raindrops[i][1]+RandRange(2,10));
      if (raindrops[i][1]>GR_HEIGHT)
      {
        raindrops[i][1]=raindrops[i][1]%GR_HEIGHT;
        if (raindrops[i][2]==BLUE)
        {
          raindrops[i][2]=BLACK;
        }
        else
        {
          raindrops[i][2]=BLUE;
        }
      }
    }
    Sleep(10);
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
U0 ScreenSaverLineSand(CDC *dc, I64 ss_cnts)
{
  if (!ss_cnts)
  {
    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    gr.scrn_saver_task=Spawn(&LineSandTask,dc,"Screen Saver Task");
  }
}

gr.fp_draw_ss=&ScreenSaverLineSand;
