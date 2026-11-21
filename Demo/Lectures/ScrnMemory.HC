//This just shows how scrn memory works.
//See $LK,"::/Demo/Lectures/MiniGrLib.HC"$

/*TinkerOS runs in a linear VBE mode, not planar VGA.  $LK,"text.fb_alias",A="MN:CTextGlbls"$
points at the framebuffer: one U32 per pixel, 0x00RRGGBB, with rows
sys_vbe_mode_pitch BYTES apart.  That pitch is not always 4*GR_WIDTH,
so index with it rather than with GR_WIDTH.

No color planes, no reversed bits, and unlike the old 0xA0000 window
you CAN read it back, so read-modify-write is fine.

text.vga_alias still exists but in a VBE mode it is a dead scratch
buffer that nothing displays.  Writing to it does nothing at all.
*/

#define FB_RED		0x00FF0000
#define FB_GREEN	0x0000FF00
#define FB_BLUE		0x000000FF

U0 PlotXY(I64 x,I64 y,U32 color)
{
  text.fb_alias[y*sys_vbe_mode_pitch/4+x]=color;
}

U0 Main()
{
  I64 i;
  if (!text.fb_alias)
  {//Nothing mapped to write to, so leave before dereferencing it.
    "No framebuffer: this demo writes text.fb_alias directly.\n";
    return;
  }
  /*The window mgr owns the framebuffer and repaints it 30 times a
  second, so it has to be stopped before we can draw there ourselves.
  Under a hypervisor it re-copies the WHOLE frame each refresh
  (use_slower_safe_gfx in $LK,"::/Adam/Gr/GrScrn.HC"$) and would erase this
  instantly; on real hw it only writes the pixels that changed.
  */
  LBts(&sys_winmgr_task->task_flags,TASKf_SUSPENDED);
  MemSetU32(text.fb_alias,BLACK32,FB_HEIGHT*sys_vbe_mode_pitch/4);
  for (i=0; i<200; i++)
    PlotXY(i,i,FB_RED);
  for (i=0; i<200; i++)
    PlotXY(100,i,FB_GREEN);
  for (i=0; i<200; i++)
    PlotXY(200-i,i,FB_BLUE);
  //A mixed color is just an OR.  The planar version had to select
  //several planes at once and keep the unseled ones zeroed.
  for (i=0; i<200; i++)
    PlotXY(300,i,FB_RED|FB_GREEN);
  Busy(4000000);
  LBtc(&sys_winmgr_task->task_flags,TASKf_SUSPENDED);
  //TinkerOS keeps an 8-bit palette copy of the scrn, $LK,"gr.dc",A="MN:CGrGlbls"$, and expands
  //it into the framebuffer, writing only what changed.
  //See $LK,"GrUpdateVGAGraphics",A="MN:GrUpdateVGAGraphics"$().
  //<CTRL-ALT-v> will flush scrn VGA cache.
  VGAFlush;
}

Main;

//See $LK,"::/Demo/Lectures/GraphicsCPULoad.HC"$.
