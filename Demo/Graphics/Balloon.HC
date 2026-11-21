// Classic Commodore 64 Sprite

#define BALLOON_W	24
#define BALLOON_H	20
#define BALLOON_X	128

U8 a[60]= {0,127,0,1,255,192,3,255,224,3,231,224,
           7,217,240,7,223,240,7,217,240,3,231,224,
           3,255,224,3,255,224,2,255,160,1,127,64,
           1,62,64,0,156,128,0,156,128,0,73,0,0,73,0,
           0,62,0,0,62,0,0,28,0
          };

U0 BalloonDraw(CDC *dc,I64 y0)
{//Three bytes per row, bit 7 is the leftmost pixel, as on the C64.
  I64 i,j;
  for (i=0; i<BALLOON_H; i++)
    for (j=0; j<BALLOON_W; j++)
      if (Bt(&a[i*3+(j>>3)],7-(j&7)))
        GrPlot(dc,BALLOON_X+j,y0+i);
}

U0 Balloon()
{/*This used to poke 1-bit VGA planes at 0xA0000 through text.vga_alias.
In a VBE mode that is a dead buffer, so we draw into $LK,"gr.dc",A="MN:CGrGlbls"$, the
persistent layer the window mgr composites into the framebuffer.
See $LK,"::/Demo/Lectures/ScrnMemory.HC"$ for the framebuffer itself.
*/
  if (!text.fb_alias)
  {//No screen, so no window mgr, so the Refresh below would never return.
    "No framebuffer: this demo draws to the screen and refreshes it.\n";
    return;
  }
  CDC *dc=DCAlias;
  I64 k;
  AutoComplete;	//AutoComplete Off
  WinBorder;	//No Border
  WinMax;	//Maximize window
  DocClear;	//Clear command-line text
  dc->color=YELLOW;
  for (k=151; k<201; k++)
  {
    DCFill(dc,BLACK);
    BalloonDraw(dc,k);
    Refresh;	//Typically 30 fps
  }
  DCFill(dc);	//TRANSPARENT, give the desktop back
  DCDel(dc);
}

Balloon;
