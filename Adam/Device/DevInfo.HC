#help_index "PCI;Processor;Devices;Info"

//The file was downloaded from
//http://www.pcidatabase.com/reports.php?type=tab-delimeted

#define PCI_DEV_FILE "::/Misc/PCIDevices.DD.Z"

DefineLstLoad("ST_PCI_CLASS_NAMES","Unclassified\0Mass Storage Controller\0Network Controller\0Display Controller\0Multimedia Controller\0Memory Controller\0Bridge\0Simple Communication Controller\0Base System Peripheral\0Input Device Controller\0Docking Station\0Processor\0Serial Bus Controller\0Wireless Controller\0");

/****
//1) Download http://www.pcidatabase.com/reports.php?type=tab-delimeted
//2) Rename to ::/Misc/PCIDevices.DD.Z
//3) ToDolDoc("::/Misc/PCIDevices.DD.Z");
//4) Edit and remove file header and tail
//5) Text find-and-replace "=0A=" with "". (Doesn't seem necessary anmore.)
//6) Run PCIDevFileGen(). (Doesn't seem necessary anmore.)

public U0 PCIDevFileGen()
{
  Bool first=TRUE,del=FALSE,del2=FALSE,cont=FALSE;
  CDoc *doc=DocRead(PCI_DEV_FILE,
	DOCF_PLAIN_TEXT|DOCF_DBL_DOLLARS|DOCF_NO_CURSOR);
  CDocEntry *doc_e=doc->head.next,*doc_e2;
  while (doc_e!=doc) {
    doc_e2=doc_e->next;
    if (first) {
      if (doc_e->type_u8==DOCT_TEXT) {
	if (doc_e->tag[0]==';')
	  del=TRUE;
      }
      first=FALSE;
    }
    if (doc_e->type_u8==DOCT_TEXT && doc_e->tag[StrLen(doc_e->tag)-1]=='=' &&
	  doc_e2->type_u8==DOCT_NEW_LINE) {
      doc_e->tag[StrLen(doc_e->tag)-1]=CH_SPACE;
      cont=TRUE;
    }
    del2=del;
    if (doc_e->type_u8==DOCT_NEW_LINE) {
      first=TRUE;
      del2=FALSE;
      if (cont) {
	del=TRUE;
	cont=FALSE;
      }
    }
    if (del)
      DocEntryDel(doc,doc_e);
    del=del2;
    doc_e=doc_e2;
  }
  DocWrite(doc);
}
****/

//$LK,"::/Misc/PCIDevices.DD",A="PI:::/Misc/PCIDevices.DD"$
U0 PCILookUpSingle(CDoc *doc,I64 m,I64 d,U8 **_vendor,U8 **_dev)
{
  Bool first=TRUE;
  U8 buf[8],*vendor=NULL,*dev=NULL;
  CDocEntry *doc_e=doc->head.next;
  while (doc_e!=doc)
  {
    if (first)
    {
      if (doc_e->type_u8==DOCT_TEXT && doc_e->tag[0]!=';' &&
          StrLen(doc_e->tag)>=4)
      {
        buf[0](U16)='0x';
        buf[2](U32)=doc_e->tag(U32 *)[0];
        buf[6]=0;
        if (Str2I64(buf)==m)
        {
          doc_e=doc_e->next->next;
          if (doc_e->type_u8==DOCT_TEXT)
          {
            vendor=AStrNew(doc_e->tag);
            first=FALSE;
            break;
          }
        }
      }
      first=FALSE;
    }
    if (doc_e->type_u8==DOCT_NEW_LINE)
      first=TRUE;
    doc_e=doc_e->next;
  }
  if (vendor)
  {
    while (doc_e!=doc)
    {
      if (first)
      {
        if (doc_e->type_u8==DOCT_TAB)
        {
          doc_e=doc_e->next;
          if (doc_e->type_u8==DOCT_TEXT && StrLen(doc_e->tag)>=4)
          {
            buf[0](U16)='0x';
            buf[2](U32)=doc_e->tag(U32 *)[0];
            buf[6]=0;
            if (Str2I64(buf)==d)
            {
              doc_e=doc_e->next->next;
              if (doc_e->type_u8==DOCT_TEXT)
              {
                dev=AStrNew(doc_e->tag);
                break;
              }
            }
          }
        }
        else
          break;
        first=FALSE;
      }
      if (doc_e->type_u8==DOCT_NEW_LINE)
        first=TRUE;
      doc_e=doc_e->next;
    }
  }
  if (vendor)
    *_vendor=vendor;
  else
    *_vendor=AStrNew("Unknown");
  if (dev)
    *_dev=dev;
  else
    *_dev=AStrNew("Unknown");
}

public CPCIDev *GetPCIDevInfo(I64 b, I64 d, I64 f)
{
  CPCIDev *tmppci=ACAlloc(sizeof(CPCIDev));
  tmppci->bus=b;
  tmppci->dev=d;
  tmppci->fun=f;
  tmppci->vendor=PCIReadU16(b,d,f,0);
  tmppci->dev_id=PCIReadU16(b,d,f,2);
  tmppci->progif=PCIReadU8(b,d,f,0x9);
  tmppci->header_type=PCIReadU8(b,d,f,0xe);
  tmppci->sub_code=PCIReadU8(b,d,f,0xA);
  tmppci->base_code=PCIReadU8(b,d,f,0xB);
  if (tmppci->header_type==1)
  {
    tmppci->secondary_bus=PCIReadU8(b,d,f,0x19);
    tmppci->sub_bus=PCIReadU8(b,d,f,0x20);
    tmppci->bridge_io_base=PCIReadU8(b,d,f,0x1c);
    tmppci->bridge_upper_io_base=PCIReadU16(b,d,f,0x30);
  }
  return tmppci;
}

public U0 PCILookUpDevs()
{
  CPCIDev *tmppci;
  I64 w1,w2,b,d,f,timeout=32*8*2;
  CDoc *doc;
  if (dev.pci_head.next!=&dev.pci_head)
    return;
  doc=DocRead(PCI_DEV_FILE,DOCF_PLAIN_TEXT|DOCF_NO_CURSOR);
  for (b=0; b<sys_pci_busses; b++)
    for (d=0; d<32; d++)
      for (f=0; f<8; f++)
      {
        w1=PCIReadU16(b,d,f,0);
        if (w1!=0xFFFF)
        {
          tmppci=GetPCIDevInfo(b, d, f);
          w2=tmppci->dev_id;
          PCILookUpSingle(doc,w1,w2,&tmppci->vendor_str,&tmppci->dev_id_str);
          QueIns(tmppci,dev.pci_head.last);
          timeout=32*8*2;
        }
        else if (sys_pci_busses==256 && --timeout<=0)
          goto lud_done;
      }
lud_done:
  DocDel(doc);
}

public CPCIDev *PCIScanBus(I64 b)
{// Returns a queue of PCI devices attached to a single bus
  CPCIDev *tmppci,*pci_bus_head=ACAlloc(sizeof(CPCIDev));
  QueInit(pci_bus_head);
  I64 w1,w2,d,f;
  CDoc *doc;
  doc=DocRead(PCI_DEV_FILE,DOCF_PLAIN_TEXT|DOCF_NO_CURSOR);
  for (d=0; d<32; d++)
    for (f=0; f<8; f++)
    {
      w1=PCIReadU16(b,d,f,0);
      if (w1!=0xFFFF)
      {
        tmppci=GetPCIDevInfo(b, d, f);
        w2=tmppci->dev_id;
        PCILookUpSingle(doc,w1,w2,&tmppci->vendor_str,&tmppci->dev_id_str);
        QueIns(tmppci,pci_bus_head->last);
      }
    }
  DocDel(doc);
  return pci_bus_head;
}

U0 PCIDumpCmdBits(I64 b, I64 d, I64 f)
{
  U16 command_reg=PCIReadU16(b,d,f,0x4);
    "PCI Command Register Bits:\n";
    "Bit 0 - I/O Space: %d\n", command_reg & 0x1>0;
    "Bit 1 - Memory Space: %d\n", command_reg & 0x2>0;
    "Bit 2 - Bus Master: %d\n", command_reg & 0x4>0;
    "Bit 3 - Special Cycles: %d\n", command_reg & 0x8>0;
    "Bit 4 - Memory Write and Invalidate: %d\n", command_reg & 0x10>0;
    "Bit 5 - VGA Palette Snoop: %d\n", command_reg & 0x20>0;
    "Bit 6 - Parity Error Response: %d\n", command_reg & 0x40>0;
    "Bit 7 - SERR# Enable: %d\n", command_reg & 0x80>0;
    "Bit 8 - Fast Back-to-Back Enable: %d\n", command_reg & 0x100>0;
}

public U0 PCIRep(CPCIDev *pci_dev_queue=0)
{//Report description of PCI devices.
  CPCIDev *tmppci, *pci_queue_head;
  U16 cmd,stat,d,v;
  U32 bar;
  I64 i, bar_max;
  if (!FileFind(PCI_DEV_FILE))
  {
    "You don't have the PCI device file.\n";
    return;
  }
  if (!pci_dev_queue)
  {
    "PCI Busses:%d\n",sys_pci_busses;
    PCILookUpDevs;
    tmppci=dev.pci_head.next;
    pci_queue_head=&dev.pci_head;
  }
  else
  {
    tmppci=pci_dev_queue->next;
    pci_queue_head=pci_dev_queue;
  }
  while (tmppci!=pci_queue_head)
  {
    bar=PCIReadU32(tmppci->bus,tmppci->dev,tmppci->fun,0x0);
    v=bar.u16[0];
    d=bar.u16[1];
    bar=PCIReadU32(tmppci->bus,tmppci->dev,tmppci->fun,0x4);
    cmd=bar.u16[0];
    stat=bar.u16[1];
    if (0<tmppci->base_code<=0x0d)
      "%s\n", DefineSub(tmppci->base_code,"ST_PCI_CLASS_NAMES");
    "bs:dv:f cl:sc v_id:d_id  cmd\n";
    "%02X:%02X:%01X %02X:%02X %04X:%04X %04X $$GREEN$$%s $$CYAN$$%s$$FG$$\n"
    ,
    tmppci->bus,tmppci->dev,tmppci->fun,
    tmppci->base_code,tmppci->sub_code,
    v,d,cmd,
    tmppci->vendor_str,tmppci->dev_id_str;

    if (PCIC_SERIAL_BUS == tmppci->base_code && 0x3 == tmppci->sub_code)
    {
      switch (tmppci->progif)
      {
      case 0x00:
           "USB 1.0 (UHCI)\n";
        break;
      case 0x10:
           "USB 1.0 (OHCI)\n";
        break;
      case 0x20:
           "USB 2.0 (EHCI)\n";
        break;
      case 0x30:
           "USB 3.0 (XHCI)\n";
        break;
      default:
           "USB (unknown)\n";
        break;
      }
    }

    bar_max=6;
    if (tmppci->header_type == 1)
    {
     "PCI Bridge (sec bus %d, sub bus %d)\n",tmppci->secondary_bus,tmppci->sub_bus;
      bar_max=2;
    }

    for (i=0; i<bar_max; i++)
    {
      bar=PCIReadU32(tmppci->bus,tmppci->dev,tmppci->fun,0x10+4*i);
      if (bar&1) "       I/O : 0x%08x\n",bar&0xfffffffc;
      else if (bar&7==0) "32-bit MMIO: 0x%08x\n",bar&0xfffffff0;
      else if (bar&7==4) "64-bit MMIO: 0x%016x\n",(bar&0xfffffff0)(I64)+
        PCIReadU32(tmppci->bus,tmppci->dev,tmppci->fun,0x10+4*(i+1))(I64)<<32;
      else if (bar&7==2) "16-bit MMIO: 0x%04x\n",(bar&0xfff0)(I64);
    }
    tmppci=tmppci->next;
  }
}

U0 PCIRescan()
{
  QueInit(&dev.pci_head);
  PCIRep;
}


#help_index "Info;Memory/Info"
public U0 MemBIOSRep()
{//Report the memory ranges reported by the BIOS at boot.
  U16	*m01=MEM_E801;
  CMemE820	*m20=MEM_E820;
  CMemRange	*tmpmr;
  "Standard Addresses\n"
  "000A0000-000BFFFF VGA\n"
  "FEE00000-FEE00FFF See $$LK,\"APIC\",A=\"MN:LAPIC_BASE\"$$\n\n"
  "32 Bit Device Mem\n";
  while (LBts(&sys_semas[SEMA_DEV_MEM],0))
    Yield;
  tmpmr=dev.mem32_head.next;
  while (tmpmr!=&dev.mem32_head)
  {
    "%02X:%016X-%016X\n",
    tmpmr->type,tmpmr->base,tmpmr->base+tmpmr->size-1;
    tmpmr=tmpmr->next;
  }
  LBtr(&sys_semas[SEMA_DEV_MEM],0);
  "\nBIOS Memory Report 15:E801\n"
  "01:0000000000000000-%016X\n"
  ,0x100000+m01[0]<<10-1;
  "01:0000000001000000-%016X\n"
  ,SYS_16MEG_AREA_LIMIT+m01[1]<<16-1;
  if (m20->type)
  {
    '\n';
    "BIOS Memory Report 15:E820\n";
    while (m20->type)
    {
      "%02X:%016X-%016X\n",m20->type,m20->base,m20->base+m20->len-1;
      m20++;
    }
  }
}

public U0 MemPageRep()
{//Page Table Report.
  "MAPPED\t:%010Xwith",mem_mapped_space;
  if (Bt(&mem_page_size,30))
    "$$RED$$1GIG$$FG$$ pages\n";
  else
    "$$RED$$2MEG$$FG$$ pages\n";
  "PML2\t:%010X2MEG:%08X\n"
  ,
  *MEM_PML2(U64 *),*MEM_2MEG_NUM(U64 *);
  "PML3\t:%010X1GIG:%08X\n"
  ,
  *MEM_PML3(U64 *),*MEM_1GIG_NUM(U64 *);
  "PML4\t:%010X512GIG:%08X\n"
  ,
  *MEM_PML4(U64 *),*MEM_512GIG_NUM(U64 *);
  "FIXED_AREA:%010X\n"
  ,SYS_FIXED_AREA;
  "HEAP_BASE:%010X\nHEAP_LIMIT:%010X\n"
  ,mem_heap_base,mem_heap_limit;
}

public CPCIDev *PCIDevFind(U16 class_code=NULL, U16 sub_code=NULL,
    U16 vendor_id=NULL, U16 device_id=NULL,
    U8 _bus=0xFF, U8 _dev=0xFF, U8 _fun=0xFF)
{//return first device matching class & subcode, vendor & device id, or a specific device.
  PCILookUpDevs;
  CPCIDev *p = dev.pci_head.next;
  while (p != &dev.pci_head)
  {
    if (p->vendor == vendor_id && p->dev_id == device_id ||
        p->base_code == class_code && p->sub_code == sub_code ||
        p->bus == _bus && p->dev == _dev && p->fun == _fun)
      return p;
    p = p->next;
  }
  return NULL;
}

public U0 PCILookUpDev(I64 vendor, I64 dev)
{
  CDoc *doc;
  U8 *vendor_str, *dev_id_str;
  doc=DocRead(PCI_DEV_FILE,DOCF_PLAIN_TEXT|DOCF_NO_CURSOR);
  PCILookUpSingle(doc,vendor,dev,vendor_str,dev_id_str);
  "Vendor: %s\n",vendor_str;
  "Device: %s\n",dev_id_str;
  DocDel(doc);
}

U0 PciDumpInfo(CPciDevInfo* info)
{
  I64 i;
  "vendor_id=%04Xh\tdevice_id=%04Xh\n"
  , info->vendor_id, info->device_id;
  "command=%04Xh\tstatus=%04Xh\n"
  , info->command, info->status;
  "revision_id=%02Xh\tprog_if=%02Xh\n"
  , info->revision_id, info->prog_if;
  "subclass=%02Xh\tclass_=%02Xh\n"
  , info->subclass, info->class_;
  "cache_line_size=%02Xh\tlatency_timer=%02Xh\n"
  , info->cache_line_size, info->latency_timer;
  "header_type=%02Xh\tbist=%02Xh\n"
  , info->header_type, info->bist;
  for (i = 0; i < 6; i++)
    "BAR[%d]=%08X\n", i, info->bar[i];
  "interrupt_line=%02Xh\n"
  , info->interrupt_line;
}

public Bool PciFindByID(U16 vendor_id, U16 device_id, U16 class_code=NULL, U16 sub_code=NULL,
                 I64* bus_out=NULL, I64* dev_out=NULL, I64* fun_out=NULL)
{
  I64 vendor, device, cl, sub, b, d, f, timeout = 32 * 8 * 2;
  for (b = 0; b < sys_pci_busses; b++)
  {
    for (d = 0; d < 32; d++)
    {
      for (f = 0; f < 8; f++)
      {
        vendor = PCIReadU16(b, d, f, PCIR_VENDOR_ID);
        cl = PCIReadU8(b, d, f, PCIR_CLASS_CODE);
        sub = PCIReadU8(b, d, f, PCIR_SUB_CODE);
        if (vendor != 0xFFFF)
        {
          if (class_code && cl!=class_code || sub_code && sub!=sub_code)
            device = 0xffffffff;
          else
            device = PCIReadU16(b, d, f, PCIR_DEVICE_ID);
          if (vendor == vendor_id && device == device_id)
          {
            if (bus_out) *bus_out = b;
            if (dev_out) *dev_out = d;
            if (fun_out) *fun_out = f;
            return TRUE;
          }
          if (vendor == vendor_id && 0 == device_id)
          {
            if (bus_out) *bus_out = b;
            if (dev_out) *dev_out = d;
            if (fun_out) *fun_out = f;
            return TRUE;
          }
          timeout = 32 * 8 * 2;
        }
        else if (sys_pci_busses == 256 && --timeout <= 0)
        {
          break;
        }
      }
    }
  }
  return FALSE;
}

U0 PciGetDevInfo(CPciDevInfo* info_out, I64 bus, I64 dev, I64 fun)
{
  info_out->vendor_id =       PCIReadU16(bus, dev, fun, PCIR_VENDOR_ID);
  info_out->device_id =       PCIReadU16(bus, dev, fun, PCIR_DEVICE_ID);
  info_out->command =         PCIReadU16(bus, dev, fun, PCIR_COMMAND);
  info_out->status =          PCIReadU16(bus, dev, fun, PCIR_STATUS);
  info_out->revision_id =     PCIReadU8(bus, dev, fun, PCIR_REVISION_ID);
  info_out->prog_if =         PCIReadU8(bus, dev, fun, PCIR_PROG_IF);
  info_out->subclass =        PCIReadU8(bus, dev, fun, PCIR_SUB_CODE);
  info_out->class_ =          PCIReadU8(bus, dev, fun, PCIR_CLASS_CODE);
  info_out->cache_line_size = PCIReadU8(bus, dev, fun, PCIR_CACHE_LINE_SIZE);
  info_out->latency_timer =   PCIReadU8(bus, dev, fun, PCIR_LATENCY_TIMER);
  info_out->header_type =     PCIReadU8(bus, dev, fun, PCIR_HEADER_TYPE);
  info_out->bist =            PCIReadU8(bus, dev, fun, PCIR_BIST);
  info_out->bar[0] =          PCIReadU32(bus, dev, fun, PCIR_BASE0);
  info_out->bar[1] =          PCIReadU32(bus, dev, fun, PCIR_BASE1);
  info_out->bar[2] =          PCIReadU32(bus, dev, fun, PCIR_BASE2);
  info_out->bar[3] =          PCIReadU32(bus, dev, fun, PCIR_BASE3);
  info_out->bar[4] =          PCIReadU32(bus, dev, fun, PCIR_BASE4);
  info_out->bar[5] =          PCIReadU32(bus, dev, fun, PCIR_BASE5);
  info_out->interrupt_line =  PCIReadU8(bus, dev, fun, PCIR_INTERRUPT_LINE);
  info_out->bus=bus;
  info_out->dev=dev;
  info_out->fun=fun;
}

U32 PCIGetFirstIOBar(CPciDevInfo* info)
{
  I64 i, bar;
  for (i=0;i<6;i++)
  {
    bar=info->bar[i];
    if (bar&1) return bar&0xfffffffc;
  }
  return 0;
}
