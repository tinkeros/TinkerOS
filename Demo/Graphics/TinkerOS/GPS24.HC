// Grand prismatic spring shown in 24-bit color
// Assumes 640x480 display buffer
//
// Made by exporting a RAW RGBA8888 image from GIMP
// (alpha channel is unused)

U0 GPSpring24BitColor(I64 seconds)
{
  I64 tmp;
  I64 size,i;
  U32 *image_buffer=FileRead("GPS24.BIN.Z",&size);

  for (i=0;i<640*480;i++)
  {
    tmp=image_buffer[i].u8[2];
    image_buffer[i].u8[2]=image_buffer[i].u8[0];
    image_buffer[i].u8[0]=tmp;
  }

  LBts(&sys_winmgr_task->task_flags,TASKf_SUSPENDED);
  MemCpy(text.fb_alias, image_buffer, size);
  Sleep(seconds*1000);
  LBtr(&sys_winmgr_task->task_flags,TASKf_SUSPENDED);
  VGAFlush;
  Free(image_buffer);
}

GPSpring24BitColor(5);

