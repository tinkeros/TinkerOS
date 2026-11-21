//This is the fastest you can update the whole scrn.
//See $LK,"::/Demo/Lectures/MiniGrLib.HC"$ if this interests you.

/*A VBE mode is 32 bits per pixel, so a whole-scrn update moves
GR_WIDTH*GR_HEIGHT*4 bytes where the old 4 x 1-bit VGA planes moved
GR_WIDTH*GR_HEIGHT/2, i.e. 8x the traffic.  Expect the FPS below to
be well under what the planar version reported.  Both are honest.
*/

F64 FBPattern(I64 p)
{//This returns the time to update in seconds.
//text.fb_alias is the VBE linear framebuffer, rows sys_vbe_mode_pitch apart.
  F64 start=tS;
  MemSetI64(text.fb_alias,p,FB_HEIGHT*sys_vbe_mode_pitch/8);
  return tS-start;
}


U0 GrDemo()
{
  I64 i;
  F64 t;
  if (!text.fb_alias)
  {//Nothing mapped to write to, so leave before dereferencing it.
    "No framebuffer: this demo writes text.fb_alias directly.\n";
    return;
  }
  CPURep;
//Two solid grays, not a dither.  At 32bpp each U32 is one 0x00RRGGBB pixel.
  for (i=0; i<16; i++)
  {
    t=FBPattern(0x0055555500555555);
    "$$GREEN$$Rate:$$RED$$%5.1f FPS$$FG$$"
    "$$GREEN$$Load@30Hz:$$RED$$%5.1f%%$$FG$$\n"
    ,1/t,100*t*30.0;
    t=FBPattern(0x0033333300333333);
    "$$GREEN$$Rate:$$RED$$%5.1f FPS$$FG$$"
    "$$GREEN$$Load@30Hz:$$RED$$%5.1f%%$$FG$$\n"
    ,1/t,100*t*30.0;
  }
/*Under a hypervisor the window mgr re-copies the whole frame every
refresh (use_slower_safe_gfx in $LK,"::/Adam/Gr/GrScrn.HC"$), so you may not
see the fills at all; on real hw it writes only the pixels that
changed and you will.  The timings are real either way.
*/
//<CTRL-ALT-v> will flush scrn VGA cache.
  VGAFlush;
}

GrDemo;
