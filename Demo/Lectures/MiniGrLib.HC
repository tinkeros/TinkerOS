//See $LK,"::/Demo/Lectures/GraphicsCPULoad.HC"$

/*A mini graphics library, writing straight onto scrn memory.

It used to rasterize 1 bit per pixel for the planar 0xA0000 window.
That window could not be read back, so every op went through a shadow
buffer, and a rev[256] table undid VGA's bwd bit order on the way out.

A VBE mode is 32 bits per pixel, 0x00RRGGBB, with rows
sys_vbe_mode_pitch BYTES apart, and it reads back fine.  All the bit
work is gone: a pixel is one store, a horizontal line is a MemSetU32.

The shadow buffer is still worth keeping.  Video memory is much slower
than RAM, so rasterize into RAM and blit once.  That is what the window
mgr does with $LK,"gr.dc",A="MN:CGrGlbls"$, except it writes only the pixels that changed.
*/

U32 *image;		//Shadow buffer, GR_WIDTH*GR_HEIGHT pixels.
U32 mg_color=WHITE32;	//Current pen color.

U0 MGInit()
{
  image=CAlloc(GR_WIDTH*GR_HEIGHT*sizeof(U32));
}

U0 MGDone()
{
  Free(image);
  image=NULL;
}

U0 MGUpdate()
{//Copy image to the framebuffer, a row at a time.
//The pitch is not always 4*GR_WIDTH, so we cannot do it in one MemCpy.
//For better performance we could only write what's changed.
  I64 y;
  for (y=0; y<GR_HEIGHT; y++)
    MemCpy(text.fb_alias+y*sys_vbe_mode_pitch/4,image+y*GR_WIDTH,
           GR_WIDTH*sizeof(U32));
}

U0 MGPlot(I64 x,I64 y)
{
  if (0<=x<GR_WIDTH && 0<=y<GR_HEIGHT)
    image[y*GR_WIDTH+x]=mg_color;
}

U0 MGHLine(I64 x1,I64 x2,I64 y)
{//Warning!  No clipping
//One MemSetU32.  The planar version needed a leading partial byte,
//then a run of whole bytes, then a trailing partial byte.
  if (x2<x1) SwapI64(&x1,&x2);
  MemSetU32(image+y*GR_WIDTH+x1,mg_color,x2-x1+1);
}

U0 MGLine(I64 x1,I64 y1,I64 x2,I64 y2)
{//Warning!  No clipping
  I64 dx=x2-x1,dy=y2-y1;
  x1<<=32;
  x2<<=32;
  y1<<=32;
  y2<<=32;
  if (AbsI64(dx)>AbsI64(dy))
  {
    dy=dy<<32/AbsI64(dx);
    dx=SignI64(dx)<<32;
    while (x1!=x2)
    {
      MGPlot(x1.i32[1],y1.i32[1]);
      x1+=dx;
      y1+=dy;
    }
  }
  else
  {
    dx=dx<<32/AbsI64(dy);
    dy=SignI64(dy)<<32;
    while (y1!=y2)
    {
      MGPlot(x1.i32[1],y1.i32[1]);
      x1+=dx;
      y1+=dy;
    }
  }
  MGPlot(x1.i32[1],y1.i32[1]);
}

U0 MGCircle(I64 x,I64 y,F64 r)
{
  F64 s,c,x1,y1,x2,y2;
  I64 len;
  if (r<0) return;
  x1=r;
  y1=0;
  c=Cos(1/r);
  s=Sin(1/r);
  len=2*r*ã;
  MGPlot(x+x1,y+y1);
  while (len-->=0)
  {
    //m1@a1 * m2@a2	= m1*m2@(arg1+arg2)
    //(x1+y1i)*(x2+y2i) = x1*x2+(x1*y1+x2*y2)i-y1*y2
    // me$SY,-3$ti$SY,0$=mCos(t)+imSin(t)
    x2=x1;
    y2=y1;
    x1=c*x2-s*y2;
    y1=s*x2+c*y2;
    MGPlot(x+x1,y+y1);
  }
}


U0 MiniGrLibDemo()
{
  I64 i;
  if (!text.fb_alias)
  {//Nothing mapped to write to, so leave before dereferencing it.
    "No framebuffer: this demo writes text.fb_alias directly.\n";
    return;
  }
  MGInit;
  mg_color=WHITE32;
  for (i=0; i<100; i++)
    MGHLine(200+i,400+i,300+i);
  mg_color=0x00FF0000;		//A color per shape costs nothing now.
  for (i=0; i<500; i+=10)
    MGLine(i,0,0,480-i);
  mg_color=0x000080FF;
  for (i=0; i<300; i+=4)
    MGCircle(200,100+i,i);
  /*The window mgr owns the framebuffer and repaints it 30 times a
  second, so it has to be stopped before we can blit there ourselves.
  Under a hypervisor it re-copies the WHOLE frame each refresh
  (use_slower_safe_gfx in $LK,"::/Adam/Gr/GrScrn.HC"$) and would erase this
  instantly; on real hw it only writes the pixels that changed.
  */
  LBts(&sys_winmgr_task->task_flags,TASKf_SUSPENDED);
  MGUpdate;
  Busy(1500000);
  LBtc(&sys_winmgr_task->task_flags,TASKf_SUSPENDED);
  MGDone;
  /*
  We are returning graphics to normal operations under TinkerOS.
  It is not normal to by-pass the TinkerOS graphics routines.
  They do not know the framebuffer has changed.
  This bit tells TinkerOS to update whole scrn.
  */
  //<CTRL-ALT-v> will flush scrn VGA cache.
  VGAFlush;
}

MiniGrLibDemo;

//See $LK,"RawPutChar",A="MN:RawPutChar"$() for text.
//See $LK,"::/Demo/Lectures/ScrnMemory.HC"$ for color.
//See $LK,"::/Demo/Lectures/GraphicsCPULoad.HC"$.
