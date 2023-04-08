// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("Default.HC");

// This is an example of a screen saver which
// draws only when called by the window manager
// instead of spawning as task which draws
// continuously.

// This method uses the current target frame rate
// fps_master along with ss_cnts which increments
// once per window manager update to create a
// screen saver which updates approx. once per second

U0 ScreenSaverDefault(CDC *dc, I64 ss_cnts)
{
  I64 rand_x, rand_y;
  if (ss_cnts % fps_master == 0)
  {
    rand_x = RandRange(,GR_WIDTH-100);
    rand_y = RandRange(,GR_HEIGHT-FONT_HEIGHT);
    DCClear(dc);
    dc->color=WHITE;
    GrPrint(dc,rand_x,rand_y,"Screen Saver");
  }
}

gr.fp_draw_ss=&ScreenSaverDefault;

