U0 GrFixZoomScale()
{
  gr.scrn_zoom=ClampI64(gr.scrn_zoom,1,GR_SCRN_ZOOM_MAX);
  if (gr.scrn_zoom==1)
  {
    gr.sx=0;
    gr.sy=0;
  }
  else
  {
    gr.sx=ClampI64(gr.sx,0,GR_WIDTH-GR_WIDTH/gr.scrn_zoom)&~7;
    gr.sy=ClampI64(gr.sy,0,GR_HEIGHT-GR_HEIGHT/gr.scrn_zoom);
  }
}

public U0 GrScaleZoom(F64 scale)
{//Multiply zoom factor larger or smaller.
  F64 s=gr.scrn_zoom;
  gr.scrn_zoom=gr.scrn_zoom*scale;
  GrFixZoomScale;
  s/=gr.scrn_zoom;
  ms.scale.x*=s;
  ms.scale.y*=s;
  ms.scale.z*=s;
  ms.offset.x=ms.pos.x-(ms.pos.x-ms.offset.x)*s;
  ms.offset.y=ms.pos.y-(ms.pos.y-ms.offset.y)*s;
  ms.offset.z=ms.pos.z-(ms.pos.z-ms.offset.z)*s;
  gr.sx=ms.pos.x-gr.zoomed_dc->width >>1/gr.scrn_zoom;
  gr.sy=ms.pos.y-gr.zoomed_dc->height>>1/gr.scrn_zoom;
  GrFixZoomScale;
}

U0 GrZoomInScrn()
{
  GrFixZoomScale;
  I64 i,j,k,l;
  U8 *src,*src2,*dst;
  src=gr.dc2->body+gr.sx+gr.sy*gr.dc2->width_internal;
  dst=gr.zoomed_dc->body;
  for (i=0; i<GR_HEIGHT/gr.scrn_zoom; i++)
  {
    k=gr.scrn_zoom;
    while (k--)
    {
      src2=src;
      for (l=0; l<GR_WIDTH/gr.scrn_zoom; l++)
      {
        for(j=0; j<gr.scrn_zoom-1; j++)
        {
          *dst++=*src2;
        }
        *dst++=*src2++;
      }
    }
    src+=GR_WIDTH;
  }
}
