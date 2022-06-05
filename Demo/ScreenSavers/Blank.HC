// To use this screen saver do NOT include it.
//
// Instead run:
//
// AdamFile("Blank.HC");

// This is an example of a screen saver which
// draws only once.
//
// Though the function below is called by the
// window manager with every update, it only
// draws to gr.ss once.

U0 ScreenSaverBlank(CDC *dc, I64 ss_cnts)
{// draw a blank image once on the first
// call when ss_cnts == 0
  if (!ss_cnts)
    DCClear(dc);
}

gr.fp_draw_ss=&ScreenSaverBlank;

