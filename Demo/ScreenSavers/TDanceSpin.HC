// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("TDanceSpin.HC");

U0 TerryDanceSpinTask(U8 *data)
{
  CDC *dc=data;
  I64 i,j,size,width,height,num_imgs,x=0,y=0,xdir=1,ydir=1;
  U8 *imgbuf,*imgsfile = FileRead("::/Demo/ScreenSavers/TDance.BIN.Z", &size);
  imgbuf=imgsfile;
  width=(*imgbuf++)<<8 | *imgbuf++;
  height=(*imgbuf++)<<8 | *imgbuf++;
  num_imgs=(*imgbuf++)<<8 | *imgbuf++;
  CDC *tdance=DCNew(width, height);
  U8 *elems=DC2Sprite(tdance);
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
    if (x<width/2)
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
    Mat4x4IdentEqu(tdance->r);
    Mat4x4RotY(tdance->r,tS*ã/8.0);

    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    MemSetU8(tdance->body,0xff,tdance->width_internal*height);
    for (j=0; j<height; j++)
      MemCpy(tdance->body+j*tdance->width_internal,imgbuf+i*width*height+j*width,width);
    UpdateSpriteDC(elems,tdance);
    Sprite3Mat4x4B(dc,x,y,0,elems,tdance->r);
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
U0 ScreenSaverTerryDanceSpin(CDC *dc, I64 ss_cnts)
{
  if (!ss_cnts)
    {
    MemCpy(dc->body,gr.dc2->body,GR_WIDTH*GR_HEIGHT);
    gr.scrn_saver_task=Spawn(&TerryDanceSpinTask,dc,"Screen Saver Task");
  }
}

gr.fp_draw_ss=&ScreenSaverTerryDanceSpin;
