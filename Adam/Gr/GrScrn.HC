#help_index "Graphics/Scrn"

// Change this to have faster graphics in some cases.
// Code below will force QEMU safe even if this is undefined
// because QEMU will have graphics glitches without it.
//
// You might get a decent speedup setting this to FALSE for
// VirtualBox, VMware, and some hardware!
Bool use_slower_safe_gfx=TRUE;

#define I_UPDATE_CACHE 0xfd
#define I_BLOT         0xfe
#define I_REDRAW       0xff

// Fixes/speedups for when pitch!=GR_WIDTH*4 and other scaled modes
// Sprite blinking when partially offscreen ( bug in TOS too )

I64 BlotGlblCnt,CacheGlblCnt,DrawGlblCnt,GrSethHelperSema=0,GrSethHelperCnt=1,*output_dst=text.fb_alias,*output_dst2=text.fb_alias;
U8 *scrn_src=gr.dc2->body;

// This causes issues with some virtualization software/hardware
// but is not a big deal for most.
if (IsHypervisorPresent && Hypervisor == 'QEMU')
  use_slower_safe_gfx=TRUE;

if (use_slower_safe_gfx)
{
  output_dst=text.raw_scrn_image;
  output_dst2=text.raw_scrn_img2;
}

#help_index "Video"
public U0 SetGrSethHelperCnt(I64 cnt=-1)
{//Set number of Seth cores to help render graphics, -1 for default
  while (GrSethHelperSema)
  {
    Yield;
  }
  PUSHFD
  CLI
  if (cnt<0)
  {
    GrSethHelperCnt=mp_cnt/2;
    if (GR_WIDTH==640&&GrSethHelperCnt>2)
    {
      GrSethHelperCnt=2;
    }
    if (GR_WIDTH>800&&GrSethHelperCnt>3)
    {
      GrSethHelperCnt=3;
    }
  }
  else
  {
    GrSethHelperCnt=cnt;
  }
  if (GrSethHelperCnt>mp_cnt-1)
  {
    GrSethHelperCnt=mp_cnt-1;
  }
  lock GrSethHelperSema=0;
  POPFD
}

SetGrSethHelperCnt(0);  // Use default

#help_index "Graphics/Scrn"

U0 GrUpdateTaskODEs(CTask *task)
{
  sys_task_being_scrn_updated=task;
  try
    ODEsUpdate(task);
  catch
  {
    LBts(&task->win_inhibit,WIf_SELF_ODE);
    "Exception in WinMgr: Update Task ODEs\n";
    PutExcept;
    Sleep(3000);
    VGAFlush;
  }
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTaskWin(CTask *task)
{//Draw a win.  Only Core0 tasks have a win.
  CDC *dc;
  CD3I64 saved_scroll;
  sys_task_being_scrn_updated=task;
  try
  {
    if (!Bt(&task->display_flags,DISPLAYf_NO_BORDER))
      TextBorder(Fs,task->win_left,task->win_right,task->win_top,
                 task->win_bottom,task->border_attr,task==sys_focus_task);
    TextRect(task->win_left,task->win_right,
             task->win_top,task->win_bottom,task->text_attr<<8);
    if (task==sys_winmgr_task)
    {
      if (gr.fp_wall_paper)
        (*gr.fp_wall_paper)(task);
    }
    else if (!(task->win_inhibit&WIF_SELF_DOC))
      DocUpdateTaskDocs(task);
    if (TaskValidate(task))
    {
      if (task->draw_it)
      {
        dc=DCAlias(gr.dc2,task);
        (*task->draw_it)(task,dc);
        DCDel(dc);
      }
      if (TaskValidate(task))
      {
        WinScrollNull(task,&saved_scroll);
        DrawCtrls(task);
        WinScrollRestore(task,&saved_scroll);
      }
    }
  }
  catch
  {
    if (task!=Fs && TaskValidate(task))
    {
      LBtr(&task->display_flags,DISPLAYf_SHOW);
      "Exception in WinMgr: Update Task Win\n";
      PutExcept;
      Sleep(3000);
      VGAFlush;
    }
  }
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTasks()
{//Only called by WinMgr
  I64 i;
  CTask *task,*task1;
  try
  {
    winmgr.ode_time=0;
    if (Bt(&sys_semas[SEMA_UPDATE_WIN_Z_BUF],0))
      WinZBufUpdate;
    task1=task=sys_winmgr_task;
    do   //Loop through Core0 tasks.
    {
      if (!TaskValidate(task)) break;
      if (Bt(&task->display_flags,DISPLAYf_SHOW) &&
          Bt(gr.win_uncovered_bitmap,task->win_z_num))
        GrUpdateTaskWin(task);
      if (!TaskValidate(task)) break;
      task=task->next_task;
    }
    while (task!=task1);
    for (i=0; i<mp_cnt; i++) //Loop through all cores.
    {
      task1=task=cpu_structs[i].seth_task;
      do
      {
        if (!TaskValidate(task)) break;
        GrUpdateTaskODEs(task);
        if (!TaskValidate(task)) break;
        task=task->next_task;
      }
      while (task!=task1);
    }
  }
  catch
  {
    PutExcept(FALSE);
    Dbg("Exception in WinMgr");
  }
  winmgr.last_ode_time=winmgr.ode_time;
  ode_alloced_factor=LowPass1(0.1,ode_alloced_factor,
                              Clamp(Gs->idle_factor-0.1,0.2,0.8),1/winmgr.fps);
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTextBG()
{
  I64 reg RSI *dst=gr.dc2->body,reg R13 c,row,col,
               num_rows=TEXT_ROWS,num_cols=TEXT_COLS,i,j,cur_ch,
               reg R12 w1=gr.dc2->width_internal,w2=-7*w1+8,w3=7*w1,w4=0;
  U32 *src=gr.text_base;
  Bool blink_flag=Blink;
  U8 *dst2=dst;
  if (gr.pan_text_x||gr.hide_col)
  {
    gr.pan_text_x=ClampI64(gr.pan_text_x,-7,7);
    j=AbsI64(gr.pan_text_x)/FONT_WIDTH+1;
    num_cols-=j;
    if (gr.pan_text_x<0)
    {
      src+=j;
      i=FONT_WIDTH*j+gr.pan_text_x;
    }
    else
      i=gr.pan_text_x;
    dst2=dst(U8 *)+i;
    w4=j;
    w3+=j*FONT_WIDTH;
    j*=FONT_WIDTH;
    dst(U8 *)=gr.dc2->body;
    for (row=num_rows*FONT_HEIGHT; row--;)
    {
      for (col=i; col--;)
        *dst(U8 *)++=0;
      dst(U8 *)+=w1-i-j;
      for (col=j; col--;)
        *dst(U8 *)++=0;
    }
  }
  dst=dst2;
  if (gr.pan_text_y||gr.hide_row)
  {
    gr.pan_text_y=ClampI64(gr.pan_text_y,-7,7);
    j=AbsI64(gr.pan_text_y)/FONT_HEIGHT+1;
    num_rows-=j;
    if (gr.pan_text_y<0)
    {
      src+=w1/FONT_WIDTH*j;
      i=w1*(FONT_HEIGHT*j+gr.pan_text_y);
    }
    else
      i=w1*gr.pan_text_y;
    dst2=dst(U8 *)+i;
    j*=w1*FONT_HEIGHT;
    dst(U8 *)=gr.dc2->body;
    for (row=i; row--;)
      *dst(U8 *)++=0;
    dst(U8 *)=gr.dc2->body+TEXT_ROWS*TEXT_COLS*FONT_HEIGHT*FONT_WIDTH-j;
    for (row=j; row--;)
      *dst(U8 *)++=0;
  }
  dst=dst2;
  for (row=num_rows; row--;)
  {
    for (col=num_cols; col--;)
    {
      cur_ch=*src++;
      if (cur_ch & (ATTRF_SEL|ATTRF_INVERT|ATTRF_BLINK))
      {
        if (cur_ch & ATTRF_SEL)
          cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
        if (cur_ch & ATTRF_INVERT)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
        if (cur_ch & ATTRF_BLINK && blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      }
      c=gr.to_8_colors[cur_ch.u8[1]>>4];
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      dst(U8 *)+=w2;
    }
    src+=w4;
    dst(U8 *)+=w3;
  }
}

U0 GrUpdateTextFG()
{//See $LK,"TextBase Layer",A="HI:TextBase Layer"$.
  U32 *src=gr.text_base;
  I64 i,j,cur_ch,*dst=gr.dc2->body,
                  w1=gr.dc2->width_internal,w2=7*w1,w4=0,
                  num_rows=TEXT_ROWS,num_cols=TEXT_COLS,row,col;
  U8 *dst_start=gr.dc2->body,*dst_end=dst_start+w1*gr.dc2->height-7*w1-8;
  Bool blink_flag=Blink;
  if (gr.pan_text_x||gr.hide_col)
  {
    gr.pan_text_x=ClampI64(gr.pan_text_x,-7,7);
    j=AbsI64(gr.pan_text_x)/FONT_WIDTH+1;
    num_cols-=j;
    if (gr.pan_text_x<0)
    {
      src+=j;
      dst(U8 *)+=FONT_WIDTH*j;
    }
    w4=j;
    w2+=j*FONT_WIDTH;
  }
  if (gr.pan_text_y||gr.hide_row)
  {
    gr.pan_text_y=ClampI64(gr.pan_text_y,-7,7);
    j=AbsI64(gr.pan_text_y)/FONT_HEIGHT+1;
    num_rows-=j;
    if (gr.pan_text_y<0)
    {
      src+=w1/FONT_WIDTH*j;
      dst(U8 *)+=w1*FONT_HEIGHT*j;
    }
  }
  for (row=num_rows; row--;)
  {
    for (col=num_cols; col--;)
    {
      cur_ch=*src++;
      if (cur_ch & (ATTRF_UNDERLINE|ATTRF_SEL|ATTRF_INVERT|ATTRF_BLINK))
      {
        if (cur_ch & ATTRF_SEL)
          cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
        if (cur_ch & ATTRF_INVERT)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
        if (cur_ch & ATTRF_BLINK && blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      }
      if (i=cur_ch.u16[1]&0x3FF+gr.pan_text_x+gr.pan_text_y<<5)
      {
        j=i&0x1F;
        if (j&0x10) j|=~0x1F;
        i>>=5;
        if (i&0x10) i|=~0x1F;
        i=w1*i+j;
        if (dst_start<=dst(U8 *)+i<dst_end)
          GrRopEquU8NoClipping(cur_ch&(ATTRF_UNDERLINE+0xFFF),dst(U8 *)+i,w1);
      }
      else
        GrRopEquU8NoClipping(cur_ch&(ATTRF_UNDERLINE+0xFFF),dst,w1);
      dst(U8 *)+=8;
    }
    src+=w4;
    dst(U8 *)+=w2;
  }
}

U0 DCBlotColor80(CDC *dc,CDC *img)
{
  U8  *src=img->body,*b0=dc->body;
  I64 j,k,d0=img->width_internal*img->height;
  for (k=0; k<d0; k++)
  {
    j=*src++;
    if (j!=TRANSPARENT)
      *b0++=j;
    else
      b0++;
  }
}

U0 GrUpdateTextModeText()
{
  U32 *src=gr.text_base;
  I64 cur_ch,i=TEXT_COLS*TEXT_ROWS;
  U16 *dst=text.vga_text_alias,*dst2=gr.vga_text_cache;
  Bool blink_flag=Blink;
  if (LBtr(&sys_semas[SEMA_FLUSH_VGA_IMAGE],0))
  {
    while (i--)
    {
      cur_ch=*src++;
      if (cur_ch & ATTRF_SEL)
        cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
      if (cur_ch & ATTRF_INVERT)
        cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      if (cur_ch & ATTRF_BLINK)
        if (blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      *dst++=*dst2++=cur_ch&0x7FFF;
    }
  }
  else
  {
    while (i--)
    {
      cur_ch=*src++;
      if (cur_ch & ATTRF_SEL)
        cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
      if (cur_ch & ATTRF_INVERT)
        cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      if (cur_ch & ATTRF_BLINK)
        if (blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      cur_ch&=0x7FFF;
      if (*dst2!=cur_ch)
        *dst++=*dst2++=cur_ch;
      else
      {
        dst++;
        dst2++;
      }
    }
  }
}


U0 GrPartialUpdateScaling(U8 *screen)
{
  U8 *screen2, *last_screen = gr.screen_cache;
  I64 i,j,k,l,idx,dst_row=0;
  I32 *dst=output_dst2;
  for (i=0; i<GR_HEIGHT; i++)
  {
    k=HEIGHT_SCALE;
    while (k--)
    {
      dst=output_dst2;
      dst=dst+dst_row*gr.pitch/4;
      screen2=screen;
      for (l=0; l<GR_WIDTH; l++)
      {
        idx=i*GR_WIDTH+l;
        if (screen[idx]!=last_screen[idx])
        {
          for (j=0; j<WIDTH_SCALE; j++)
          {
            dst[l*WIDTH_SCALE+j]=gr_palette[screen[idx]];
          }
        }
      }
      dst_row++;
    }
  }
  MemCpy64(last_screen,screen,GR_WIDTH*GR_HEIGHT/8);
}


U0 GrPartialUpdateLetterbox(U8 *screen)
{
  U8 *last_screen = gr.screen_cache;
  I64 i,j,idx;
  U32 *dst;
  for (i=0; i<GR_HEIGHT; i++)
  {
    dst=output_dst2;
    dst=dst+i*gr.pitch/4+LETTER_BOX_BAR_WIDTH;
    for (j=0; j<GR_WIDTH; j++)
    {
      idx=i*GR_WIDTH+j;
      if (screen[idx] != last_screen[idx])
      {
        last_screen[idx] = screen[idx];
        dst[j] = gr_palette[screen[idx]];
      }
    }
  }
}

U0 GrPartialUpdate0(U16 *screen)
{
  U16 *last_screen = gr.screen_cache;
  I64 i,j,idx,*dst;
  for (i=0; i<GR_HEIGHT; i++)
  {
    dst=output_dst;
    dst=dst+i*gr.pitch/8;
    for (j=0; j<GR_WIDTH/2; j++)
    {
      idx=i*GR_WIDTH/2+j;
      if (screen[idx] != last_screen[idx])
      {
        last_screen[idx] = screen[idx];
        dst[j] = gr_palette[screen[idx].u8[0]] | gr_palette[screen[idx].u8[1]] << 32;
      }
    }
  }
}

interrupt U0 GrPartialUpdatePartIrq()
{
  U16 *screen=scrn_src,*last_screen = gr.screen_cache;
  I64 i,j,idx,*dst;
  for (i=(Gs->num-1)*GR_HEIGHT/GrSethHelperCnt; i<Gs->num*GR_HEIGHT/GrSethHelperCnt; i++)
  {
    dst=output_dst;
    dst=dst+i*gr.pitch/8;
    for (j=0; j<GR_WIDTH/2; j++)
    {
      idx=i*GR_WIDTH/2+j;
      if (screen[idx] != last_screen[idx])
      {
        last_screen[idx] = screen[idx];
        dst[j] = gr_palette[screen[idx].u8[0]] | gr_palette[screen[idx].u8[1]] << 32;
      }
    }
  }
  lock DrawGlblCnt++;
  *(dev.uncached_alias+LAPIC_EOI)(U32 *)=0;
}

interrupt U0 GrUpdateCacheIrq()
{
  I64 i,my_rows;
  i=(Gs->num-1)*GR_HEIGHT/GrSethHelperCnt;
  my_rows=Gs->num*GR_HEIGHT/GrSethHelperCnt-i;
  MemCpy(gr.screen_cache+i*GR_WIDTH, scrn_src+i*GR_WIDTH,my_rows*GR_WIDTH);
  lock CacheGlblCnt++;
  *(dev.uncached_alias+LAPIC_EOI)(U32 *)=0;
}

U0 GrDoLetterBox()
{
  I64 i,j,dst_row=0;
  U32 *src, *dst;
  src=text.raw_scrn_image;
  for (i=0; i<GR_HEIGHT; i++)
  {
    dst=output_dst2+dst_row*gr.pitch/4;
    for (j=0; j<LETTER_BOX_BAR_WIDTH; j++)
    {
      *dst++=0;
    }
    for (j=0; j<GR_WIDTH; j++)
    {
      *dst++=*src++;
    }
    for (j=0; j<LETTER_BOX_BAR_WIDTH; j++)
    {
      *dst++=0;
    }
    dst_row++;
  }
}

U0 GrDoFinalScaling()
{
  I64 i,j,k,l,dst_row=0;
  U32 *src, *dst, *src2;
  src=text.raw_scrn_image;
  for (i=0; i<GR_HEIGHT; i++)
  {
    k=HEIGHT_SCALE;
    while (k--)
    {
      dst=output_dst2+dst_row*gr.pitch/8;
      src2=src;
      for (l=0; l<GR_WIDTH; l++)
      {
        for(j=0; j<WIDTH_SCALE-1; j++)
        {
          *dst++=*src2;
        }
        *dst++=*src2++;
      }
      dst_row++;
    }
    src+=GR_WIDTH;
  }
}

U0 DCBlotColor8(CDC *dc,CDC *img)
{
  I64 i,*PBlotGlblCnt=&BlotGlblCnt+dev.uncached_alias;
  if (GrSethHelperCnt>0&&dc==gr.dc2&&img==gr.dc)
  {
    lock BlotGlblCnt=0;
    for (i=1; i<1+GrSethHelperCnt; i++)
      MPInt(I_BLOT,i);
    while (*PBlotGlblCnt != GrSethHelperCnt)
    {
      Yield;
    }
  }
  else
  {
    DCBlotColor80(dc,img);
  }
}


U0 GrPartialUpdate(U64 *screen)
{
  I64 i,*PDrawGlblCnt=&DrawGlblCnt+dev.uncached_alias;
  if (GrSethHelperCnt>0)
  {
    lock DrawGlblCnt=0;
    for (i=1; i<1+GrSethHelperCnt; i++)
      MPInt(I_REDRAW,i);
    while (*PDrawGlblCnt != GrSethHelperCnt)
    {
      Yield;
    }
  }
  else
  {
    GrPartialUpdate0(screen);
  }
  if (output_dst!=text.fb_alias)
    MemCpy64(text.fb_alias, text.raw_scrn_image, text.buffer_size/8);
}

U0 GrUpdateCache(U8 *src_start)
{
  I64 i,*PCacheGlblCnt=&CacheGlblCnt+dev.uncached_alias;
  scrn_src=src_start;
  if (GrSethHelperCnt>0)
  {
    lock CacheGlblCnt=0;
    for (i=1; i<1+GrSethHelperCnt; i++)
      MPInt(I_UPDATE_CACHE,i);
    while (*PCacheGlblCnt != GrSethHelperCnt)
    {
      Yield;
    }
  }
  else
  {
    MemCpy64(gr.screen_cache,src_start, text.buffer_size/32);  //TODO pitch
  }
}


static I64 ss_wait_ticks=0;

U0 GrUpdateVGAGraphics()
{
  U64 size, *dst = text.raw_scrn_image;
  I64 last_event, i,j;
  U8 *src, *src_start = gr.dc2->body;
  U32 *dst2;
  last_event = KbdMsEvtTime;
  if (gr.scrn_saver_timeout && (GetTSC - last_event)/cnts.time_stamp_freq > gr.scrn_saver_timeout)
  {
    ss_wait_ticks++;
  }
  else {
    ss_wait_ticks=0;
  }
  if (ss_wait_ticks>5) {
    if (!gr.scrn_saver)
    {
      VGAFlush;
      gr.scrn_zoom = 1;
      gr.scrn_saver=TRUE;
      gr.scrn_saver_cnts=0;
      if (TaskValidate(gr.scrn_saver_task))
      {
        Kill(gr.scrn_saver_task);
      }
      gr.scrn_saver_task=NULL;
    }
    else if (gr.scrn_saver_cnts<5)
    {
      VGAFlush;
      gr.scrn_saver_cnts++;
    }
    else
    {
      gr.scrn_saver_cnts++;
    }
    (*gr.fp_draw_ss)(gr.ss,gr.scrn_saver_cnts);
    src_start = gr.ss->body;
  }
  else
  {
    if (gr.scrn_saver)
    {
      VGAFlush;
      gr.scrn_zoom = 1;
      gr.scrn_saver=FALSE;
      gr.scrn_saver_cnts=0;
      if (TaskValidate(gr.scrn_saver_task))
      {
        Kill(gr.scrn_saver_task);
      }
      gr.scrn_saver_task=NULL;
    }
    src_start = gr.dc2->body;
  }
  if (gr.scrn_zoom == 1)
  {
    if (!gr.scrn_saver)
      MemCpy64(gr.scrn_image->body,gr.dc1->body,gr.dc1->width_internal*gr.dc1->height/8);
    if (LBtr(&sys_semas[SEMA_FLUSH_VGA_IMAGE],0))
    {
      if (gr.dc2->width_internal == GR_WIDTH)
      {
        size = src_start + gr.dc2->height * gr.dc2->width_internal;
        src = src_start;
        while (src < size)
          *dst++ = gr_palette[*src++ & 0xFF] | gr_palette[*src++ & 0xFF] << 32;
      }
      else
      {
        for (i=0; i<GR_HEIGHT; i++)
        {
          src = src_start + i*gr.dc2->width_internal;
          dst2 = text.raw_scrn_image + i*GR_WIDTH;
          for (j=0; j<GR_WIDTH; j++)
            dst2[j]=gr_palette[src[j] & 0xff];
        }
      }
      GrUpdateCache(src_start);
      if (!DO_SCALING && !LETTER_BOX && FB_WIDTH*4==gr.pitch)
        MemCpy64(text.fb_alias, text.raw_scrn_image, text.buffer_size/8);
      else
      {
        if (DO_SCALING)
          GrDoFinalScaling;
        else
          GrDoLetterBox;
        if (output_dst2!=text.fb_alias)
          MemCpy64(text.fb_alias, text.raw_scrn_img2, sys_vbe_mode_pitch*FB_HEIGHT/8);
      }
    }
    else
    {
      if (!DO_SCALING && !LETTER_BOX && FB_WIDTH*4==gr.pitch)
        GrPartialUpdate(src_start);
      else
      {
        if (DO_SCALING)
          GrPartialUpdateScaling(src_start);
        else
          GrPartialUpdateLetterbox(src_start);
        if (output_dst2!=text.fb_alias)
          MemCpy64(text.fb_alias, text.raw_scrn_img2, sys_vbe_mode_pitch*FB_HEIGHT/8);
      }
    }
  }
  else
  {
    GrZoomInScrn;
    MemCpy64(gr.scrn_image->body,gr.zoomed_dc->body,gr.zoomed_dc->width_internal*gr.zoomed_dc->height/8);
    src = gr.zoomed_dc->body;
    size = src + gr.dc2->height * gr.dc2->width_internal;
    while (src < size)
      *dst++ = gr_palette[*src++ & 0xFF] | gr_palette[*src++ & 0xFF] << 32;
    MemCpy64(gr.screen_cache,gr.zoomed_dc->body, text.buffer_size/32);
    if (!DO_SCALING && !LETTER_BOX && FB_WIDTH*4==gr.pitch)
      MemCpy64(text.fb_alias, text.raw_scrn_image, text.buffer_size/8);
    else
    {
      if (DO_SCALING)
        GrDoFinalScaling;
      else
        GrDoLetterBox;
      if (output_dst2!=text.fb_alias)
        MemCpy64(text.fb_alias, text.raw_scrn_img2, sys_vbe_mode_pitch*FB_HEIGHT/8);
    }
    VGAFlush;
  }
}

U0 GrUpdateScrn()
{//Called by the Window Manager HERE, 30 times a second.
  CDC *dc;
  lock GrSethHelperSema++;
  if (!Bt(&sys_run_level,RLf_VGA)) //if text mode
    GrUpdateTasks;
  else
  {
    GrUpdateTextBG;
    GrUpdateTextFG;
    GrUpdateTasks;
    if (!gr_alt_scrn)
      DCBlotColor8(gr.dc2,gr.dc);
    else
      DCBlotColor8(gr.dc2,gr_alt_scrn);
  }
  dc=DCAlias(gr.dc2,Fs);
  dc->flags|=DCF_ON_TOP;
  if (gr.fp_final_scrn_update)
    (*gr.fp_final_scrn_update)(dc);
  DCDel(dc);
  if (!Bt(&sys_run_level,RLf_VGA)) //if text mode
    GrUpdateTextModeText;
  else
  {
    DCBlotColor4(gr.dc1->body,gr.dc2->body,gr.dc_cache->body,
                 gr.dc2->height*gr.dc2->width_internal>>3);
    GrUpdateVGAGraphics;
  }
  lock GrSethHelperSema=0;
}

public U0 ToggleBlink()
{// Toggles blinking
  blink_master_flag^=1;
}

public U0 ToggleScroll()
{// Toggles scrolling
  scroll_master_flag^=1;
}

interrupt U0 DCBlotColor8Irq()
{
  U64 b,j,*src=gr.dc->body,*b0=gr.dc2->body;
  I64 k,d0=gr.dc->width_internal*gr.dc->height/8;
  for (k=(Gs->num-1)*d0/GrSethHelperCnt; k<Gs->num*d0/GrSethHelperCnt; k++)
  {
    j=*src++;
    if (j!=0xFFFFFFFFFFFFFFFF)
    {
      b=*b0;
      if (j.u8[0]!=TRANSPARENT) b.u8[0]=j.u8[0];
      if (j.u8[1]!=TRANSPARENT) b.u8[1]=j.u8[1];
      if (j.u8[2]!=TRANSPARENT) b.u8[2]=j.u8[2];
      if (j.u8[3]!=TRANSPARENT) b.u8[3]=j.u8[3];
      if (j.u8[4]!=TRANSPARENT) b.u8[4]=j.u8[4];
      if (j.u8[5]!=TRANSPARENT) b.u8[5]=j.u8[5];
      if (j.u8[6]!=TRANSPARENT) b.u8[6]=j.u8[6];
      if (j.u8[7]!=TRANSPARENT) b.u8[7]=j.u8[7];
      b0++;
    }
    else
    {
      b0++;
    }
  }
  lock BlotGlblCnt++;
  *(dev.uncached_alias+LAPIC_EOI)(U32 *)=0;
}

IntEntrySet(I_BLOT,&DCBlotColor8Irq);
IntEntrySet(I_REDRAW,&GrPartialUpdatePartIrq);
IntEntrySet(I_UPDATE_CACHE,&GrUpdateCacheIrq);

#help_index "ScreenSaver"
public U0 SetScreenSaverTimeout(I64 new_timeout)
{//Set timeout value for screen saver in seconds
  if (new_timeout<1)
    gr.scrn_saver_timeout=0;
  else
    gr.scrn_saver_timeout=new_timeout;
}

#help_index "Video"
public U0 SetFPS(I64 new_fps)
{//Sets target frame rate
  if (new_fps<1)
  {
    lock
    {
      fps_master=1;
    }
  }
  else if (new_fps>999)
  {
    lock
    {
      fps_master=999;
    }
  }
  else
  {
    lock
    {
      fps_master=new_fps;
    }
  }
}

public I64 GetFPS()
{//Return current target video FPS
  return fps_master;
}
#help_index ""