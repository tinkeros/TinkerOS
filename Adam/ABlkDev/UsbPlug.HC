#help_index "USB"
U8 *UsbLetsStr(U8 *buf,I64 m)
{//Drive letters of a $LK,"UsbDevLets",A="MN:UsbDevLets"$ mask, e.g. "VW".
  I64 i,j=0;
  for (i=0; i<26; i++)
    if (Bt(&m,i))
      buf[j++]=i+'A';
  buf[j]=0;
  return buf;
}

//Mount a stick on plug-in and open a terminal on it, set TRUE in MakeHome.HC
public Bool usb_automount=FALSE;

U0 UsbMountTask(U8 *data)
{//Mount stick data (usb_fn index), tell in the top bar, open a terminal on it.
  I64 k=data;
  U8 let,buf[STR_LEN];
  if (!UsbDevLets(k) && (let=UsbMount(k)))
  {
    TopBarMsg("+USB DRV %s",UsbLetsStr(buf,UsbDevLets(k)));
    User("Cd(\"%c:/\");Dir;\n",let);
  }
}

public U0 UsbPlugDft(I64 k,Bool on,I64 kind)
{//Default fp_usb_plug: mount a plugged-in USB stick, open a terminal on it.
  U8 buf[STR_LEN],*pm;
  I64 m;
  if (on) pm="+";
  else pm="-";
  switch (kind)
  {
  case USB_KIND_KBD:
    TopBarMsg("%sUSB KB",pm);
    break;
  case USB_KIND_MOUSE:
    TopBarMsg("%sUSB MS",pm);
    break;
  case USB_KIND_TABLET:
    TopBarMsg("%sUSB TAB",pm);
    break;
  case USB_KIND_MSD:
    if (on)
    {
      if (usb_automount)
        Spawn(&UsbMountTask,k(U8 *),"USB Mount");
      else
        TopBarMsg("+USB MSD");
    }
    else if (m=UsbDevLets(k))
    {
      TopBarMsg("-USB DRV %s",UsbLetsStr(buf,m));
      Unmount(Bsf(m)+'A');
    }
    break;
  case USB_KIND_CDC:
    if (on)
      m=CommUsbAttach(k);
    else
      m=CommUsbDetach(k);
    if (m)
      TopBarMsg("%sUSB COM%d",pm,m);
    break;
  case USB_KIND_VIDEO:
    TopBarMsg("%sUSB CAM",pm);
    break;
  }
}
#help_index ""
