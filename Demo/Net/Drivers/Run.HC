// Throws if stack has no driver for the PC's hardware.

#define PCIV_PCNET      0x1022
#define PCID_PCNET      0x2000

#define PCIV_E1000      0x8086
#define PCID_82540EM    0x100E
#define PCID_82545EM    0x100F
#define PCID_82579LM    0x1502
#define PCID_82574L     0x10D3
#define PCID_I217LM     0x153A
#define PCID_I217V      0x153B
#define PCIV_VIRTIO     0x1AF4

U0 NetDriverInclude(U8 *driver)
{
  U8 *filename = MStrPrint(__DIR__ "/%s", driver);
  ExeFile(filename);
  Free(filename);
}

CPciDevInfo net_driver_pci;

Bool NetUsbEcmPresent()
{//Check kernel's USB Ethernet driver for an adapter.
  CHashFun *h = HashFind("UsbEcmPresent", Fs->hash_table, HTT_FUN);
  Bool (*fp)();
  if (!h)
    return FALSE;
  fp = h->exe_addr;
  return (*fp)();
}

U0 NetDriverInit()
{
  I64 b, d, f, i;
  Bool   found = FALSE;
  if (NetUsbEcmPresent)
  {//A USB Ethernet adapter takes priority over a PCI NIC.
    "Found USB Ethernet adapter\n";
    NetDriverInclude("UsbEcm");
    return;
  }
  if(PciFindByID(PCIV_PCNET,PCID_PCNET, NULL, NULL, &b, &d, &f))
  {
    "Found PCNet network card\n";
    found=TRUE;
  }
  if (PciFindByID(PCIV_VIRTIO,0, NULL, NULL, &b, &d, &f))
  {
    "Found Virtio network card\n";
    found=TRUE;
  }
  if (PciFindByID(PCIV_E1000,0, PCIC_NETWORK,NULL, &b, &d, &f))
  {
    "Found E1000 network card\n";
    found=TRUE;
  }
  if (found)
  {
    PciGetDevInfo(&net_driver_pci,b,d,f);
    ClassRep(&net_driver_pci);
    found=FALSE;
    switch (net_driver_pci.vendor_id)
    {
    case PCIV_PCNET:
      switch (net_driver_pci.device_id)
      {
      case PCID_PCNET:
        NetDriverInclude("PCNet");
        found = TRUE;
        break;
      }
      break;
    case PCIV_E1000:
      switch (net_driver_pci.device_id)
      {
      case PCID_82540EM:
      case PCID_82545EM:
        NetDriverInclude("E1000");
        found = TRUE;
        break;
      case PCID_82579LM:
      case PCID_82574L:
      case PCID_I217LM:
      case PCID_I217V:
        NetDriverInclude("E1000E");
        found = TRUE;
        break;
      }
      break;
    case PCIV_VIRTIO:
      NetDriverInclude("VirtIONet");
      found = TRUE;
      break;
    }
    if (!found)
    {
      ClassRep(net_driver_pci);
      throw('NODRIVER');
    }
  }
  else
  {//No PCI NIC: a USB Ethernet adapter, given time to enumerate.
    for (i = 0; i < 300 && !NetUsbEcmPresent; i++)
      Sleep(10);
    if (NetUsbEcmPresent)
    {
      "Found USB Ethernet adapter\n";
      NetDriverInclude("UsbEcm");
    }
    else
    {
      "Found no network card!\n";
      throw('NODRIVER');
    }
  }
}

NetDriverInit;
