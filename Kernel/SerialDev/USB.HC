U0 USBInitOne(I64 b,I64 d,I64 f)
{
  CUSB *u;
  if (sys_num_usb<USB_NUM &&
      PCIReadU16(b,d,f,0)==0x8086)
  {
    u=&sys_usb_devs[sys_num_usb++];
    u->num=sys_num_usb;
    u->bus=b;
    u->dev=d;
    u->fun=f;
    u->ports=PCIReadU32(b,d,f,0x20)&~0x1F;
  }
}

U0 USBEndAll()
{
  sys_num_usb=0;
}

U0 USBInitAll() //This is only valid for my ICH10 dev
{
  if (sys_num_usb)
    USBEndAll;
  USBInitOne(0,29,0);
  USBInitOne(0,29,1);
  USBInitOne(0,29,2);
  USBInitOne(0,29,3);
  USBInitOne(0,26,0);
  USBInitOne(0,26,1);
  USBInitOne(0,26,2);
}

CUSBTD *USBAllocTD()
{
  return MAllocAligned(sizeof(CUSBTD),0x10,Fs->code_heap)+dev.uncached_alias;
}

U0 USBFreeTD(CUSBTD *tmptd)
{
  Free(tmptd-dev.uncached_alias);
}

U32 *USBAllocFrameLst(I64 usb_num,I64 size)
{//aligned to 0x1000
  CUSB *u;
  if (0<=usb_num<sys_num_usb)
  {
    u=&sys_usb_devs[usb_num];
    Free(u->frame_lst);
    u->frame_lst=MAllocAligned(size*sizeof(U32),0x1000,Fs->code_heap) + dev.uncached_alias;
    OutU16(u->ports+USBP_CMD,0); //Stop
    OutU16(u->ports+USBP_FRNUM,0);
    OutU32(u->ports+USBP_FRBASEADD,u->frame_lst);
    return u->frame_lst;
  }
  return NULL;
}
