// Must be in same directory as driver files. (Uses __DIR__)
// Throws if stack has no driver for the PC's hardware.

#define PCIV_PCNET      0x1022
#define PCID_PCNET      0x2000

#define PCIV_E1000      0x8086
#define PCID_82545EM    0x100F


#define PCIV_VIRTIO     0x1AF4
//#define PCID_VIRTIO_NET 0x1000

U0 NetDriverInclude(U8 *driver)
{
  U8 *filename = MStrPrint(__DIR__ "/%s", driver);
  ExeFile(filename);
  Free(filename);
}

CPciDevInfo net_driver_pci;


U0 NetDriverInit()
{
  I64 b, d, f;
//TODOTODOTODO
  Bool   found = FALSE;
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
  if (found)
  {
    PciGetDevInfo(&net_driver_pci,b,d,f);
    ClassRep(&net_driver_pci);
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
      case PCID_82545EM:
        NetDriverInclude("E1000");
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
  {
    "Found no network card!\n";
  }
}

NetDriverInit;
