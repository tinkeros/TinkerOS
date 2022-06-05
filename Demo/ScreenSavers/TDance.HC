// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("TDance.HC");

U0 TerryDanceTask(U8 *data)
{
  CDC *dc=data;
  I64 i,j,size,pal_cnt,width,height,num_imgs,x=0,y=0,xdir=1,ydir=1;
  U8 *imgbuf,*imgsfile = FileRead("::/Demo/ScreenSavers/TDance.BIN.Z", &size);
  imgbuf=imgsfile;
  pal_cnt=*imgbuf++;
// Setup
  // load extended palette
  for (i=0; i<pal_cnt; i++)
    {
    gr_palette[16+i].r=*imgbuf++;
    gr_palette[16+i].g=*imgbuf++;
    gr_palette[16+i].b=*imgbuf++;
  }
  width=(*imgbuf++)<<8 | *imgbuf++;
  height=(*imgbuf++)<<8 | *imgbuf++;
  num_imgs=(*imgbuf++)<<8 | *imgbuf++;
  CDC *tdance=DCNew(width, height);
  i=0;
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
    i=i%num_imgs;
    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    MemSetU8(tdance->body,0xff,tdance->width_internal*height);
    for (j=0; j<height; j++)
      MemCpy(tdance->body+j*tdance->width_internal,imgbuf+i*width*height+j*width,width);
    GrBlot(dc,x,y,tdance);
    i++;
    Sleep(20);
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
U0 ScreenSaverTerryDance(CDC *dc, I64 ss_cnts)
{
  if (!ss_cnts)
    {
    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    gr.scrn_saver_task=Spawn(&TerryDanceTask,dc,"Screen Saver Task");
  }
}

gr.fp_draw_ss=&ScreenSaverTerryDance;
