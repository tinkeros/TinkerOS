
U32 PCIReadU32(I64 bus, I64 dev, I64 fun, I64 rg)
{//Read U32 in PCI configspace at bus, dev, fun, reg.
  I64 res, addr, offset;
  if (sys_pci_services)
    res = PCIBIOSReadU32(bus, dev, fun, rg);
  else
  {
    addr =	bus << 16	|
        dev << 11	|
        fun << 8	|
        rg & 0xFC	|
        0x80000000;
    offset = rg - rg & 0xFC;
    OutU32(PCI_ADDR, addr);
    res = InU32(PCI_DATA) >> (offset * 8);
  }
  return res;
}

U8 PCIReadU8(I64 bus, I64 dev, I64 fun, I64 rg)
{//Read U8 in PCI configspace at bus, dev, fun, reg.
  I64 res;
  if (sys_pci_services)
    res = PCIBIOSReadU8(bus, dev, fun, rg);
  else
  {
    res = PCIReadU32(bus, dev, fun, rg) & 0xFF;
  }
  return res;
}

U16 PCIReadU16(I64 bus, I64 dev, I64 fun, I64 rg)
{//Read U16 in PCI configspace at bus, dev, fun, reg.
  I64 res;
  if (sys_pci_services)
    res = PCIBIOSReadU16(bus, dev, fun, rg);
  else
  {
    res = PCIReadU32(bus, dev, fun, rg) & 0xFFFF;
  }
  return res;
}

U0 PCIWriteU32(I64 bus, I64 dev, I64 fun, I64 rg, I64 val)
{//Write U32 in PCI configspace at bus, dev, fun, reg.
  I64 addr, offset;
  if (sys_pci_services)
    PCIBIOSWriteU32(bus, dev, fun, rg, val);
  else
  {
    addr =	bus << 16	|
        dev << 11	|
        fun << 8	|
        rg & 0xFC	|
        0x80000000;
    offset = rg - rg & 0xFC;
    OutU32(PCI_ADDR, addr);
    OutU32(PCI_DATA, val << (offset * 8));
  }
}


U0 PCIWriteU8(I64 bus, I64 dev, I64 fun, I64 rg, I64 val)
{//Write U8 in PCI configspace at bus, dev, fun, reg.
  if (sys_pci_services)
    PCIBIOSWriteU8(bus, dev, fun, rg, val);
  else
  {
    PCIWriteU32(bus, dev, fun, rg, val & 0xFF);
  }
}

U0 PCIWriteU16(I64 bus, I64 dev, I64 fun, I64 rg, I64 val)
{//Write U16 in PCI configspace at bus, dev, fun, reg.
  if (sys_pci_services)
    PCIBIOSWriteU16(bus, dev, fun, rg, val);
  else
  {
    PCIWriteU32(bus, dev, fun, rg, val & 0xFFFF);
  }
}

I64 PCIClassFind(I64 class_code, I64 n)
{
  /*Find bus, dev, fun of Nth class_code dev.

  class_code is low three bytes
  n is index starting at zero
  Return: -1 not found
  else bus, dev, fun.
  */
  I64 res = -1, cur = 0, b, d, f;
  if (sys_pci_services)
  {
    res = PCIBIOSClassFind(class_code, n);
  }
  else
  {
    for (b = 0; b < sys_pci_busses; b++)
      for (d = 0; d < 32; d++)
        for (f = 0; f < 8; f++)
        {
          if (class_code == PCIReadU32(b, d, f, PCIR_PROG_IF) & 0xFFFFFF)
          {
            if (n == cur++)
            {
              res = b << 16 | d << 8 | f;
              goto pci_end;
            }
          }
        }
  }
pci_end:
  return res;
}

Bool PCIBt(U8 reg RBX *bit_field, I64 reg RDX bit)
{ // MOV-based Bt for use in PCI device MMIO areas.  See $LK+PU,"Bt()",A="FF:::/Kernel/KernelB.HH,Bt("$.
  bit_field += bit / 8;
  bit &= 7;
  return (*bit_field & 1 << bit) >> bit;
}

Bool PCIBtr(U8 reg RDX *bit_field, I64 reg RBX bit)
{ // MOV-based Btr for use in PCI device MMIO areas.  See $LK+PU,"Btr()",A="FF:::/Kernel/KernelB.HH,Btr("$.
  U64 reg R9 chunk_mod = bit & 31, chunk_bit = 1 << chunk_mod;
  bit_field(U32 *) += bit / 32;
  Bool reg R8 result = (*bit_field(U32 *) & chunk_bit) >> chunk_mod;

  *bit_field(U32 *) &= ~chunk_bit;

  return result;
}

Bool PCIBts(U8 reg RDX *bit_field, I64 reg RBX bit)
{ // MOV-based Bts for use in PCI device MMIO areas.  See $LK+PU,"Bts()",A="FF:::/Kernel/KernelB.HH,Bts("$.
  U64 reg R9 chunk_mod = bit & 31, chunk_bit = 1 << chunk_mod;
  bit_field(U32 *) += bit / 32;
  Bool reg R8 result = (*bit_field(U32 *) & chunk_bit) >> chunk_mod;

  *bit_field(U32 *) |= chunk_bit;

  return result;
}

public Bool PciFindByIDNoCC(U16 vendor_id, U16 device_id, 
                 I64* bus_out=NULL, I64* dev_out=NULL, I64* fun_out=NULL, I64 cnt=0)
{
  I64 vendor, device, b, d, f, timeout = 32 * 8 * 2;
  for (b = 0; b < sys_pci_busses; b++)
  {
    for (d = 0; d < 32; d++)
    {
      for (f = 0; f < 8; f++)
      {
        vendor = PCIReadU16(b, d, f, PCIR_VENDOR_ID);
        if (vendor == vendor_id)
        {
          device = PCIReadU16(b, d, f, PCIR_DEVICE_ID);
          if (device == device_id)
          {
            if (bus_out) *bus_out = b;
            if (dev_out) *dev_out = d;
            if (fun_out) *fun_out = f;
            if (!cnt)
              return TRUE;
            else cnt--;
          }
          if (0 == device_id)
          {
            if (bus_out) *bus_out = b;
            if (dev_out) *dev_out = d;
            if (fun_out) *fun_out = f;
            if (!cnt)
              return TRUE;
            else cnt--;
          }
          timeout = 32 * 8 * 2;
        }
        else if (sys_pci_busses == 256 && --timeout <= 0)
        {
          break;
        }
      }
      Yield;
    }
  }
  return FALSE;
}

public Bool PciFindByID(U16 vendor_id, U16 device_id, U16 class_code=NULL, U16 sub_code=NULL,
                 I64* bus_out=NULL, I64* dev_out=NULL, I64* fun_out=NULL, I64 cnt=0)
{// Find PCI device, use cnt to find more than one instance
  I64 vendor, device, cl, sub, b, d, f, timeout = 32 * 8 * 2;
  if (class_code==NULL && sub_code==NULL)
    return PciFindByIDNoCC(vendor_id, device_id, bus_out, dev_out, fun_out, cnt);
  for (b = 0; b < sys_pci_busses; b++)
  {
    for (d = 0; d < 32; d++)
    {
      for (f = 0; f < 8; f++)
      {
        vendor = PCIReadU16(b, d, f, PCIR_VENDOR_ID);
        if (vendor != 0xFFFF)
        {
          cl = PCIReadU8(b, d, f, PCIR_CLASS_CODE);
          sub = PCIReadU8(b, d, f, PCIR_SUB_CODE);
          if (class_code && cl!=class_code || sub_code && sub!=sub_code)
            device = 0xffffffff;
          else {
           device = PCIReadU16(b, d, f, PCIR_DEVICE_ID);
           if (vendor == vendor_id && device == device_id)
           {
            if (bus_out) *bus_out = b;
            if (dev_out) *dev_out = d;
            if (fun_out) *fun_out = f;
            if (!cnt)
              return TRUE;
            else cnt--;
           }
           if (vendor == vendor_id && 0 == device_id)
           {
            if (bus_out) *bus_out = b;
            if (dev_out) *dev_out = d;
            if (fun_out) *fun_out = f;
            if (!cnt)
              return TRUE;
            else cnt--;
           }
          }
          timeout = 32 * 8 * 2;
        }
        else if (sys_pci_busses == 256 && --timeout <= 0)
        {
          break;
        }
      }
      Yield;
    }
  }
  return FALSE;
}

public U0 PciGetDevInfo(CPciDevInfo* info_out, I64 bus, I64 dev, I64 fun)
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

public U32 PCIGetFirstIOBar(CPciDevInfo* info)
{
  I64 i, bar;
  for (i=0;i<6;i++)
  {
    bar=info->bar[i];
    if (bar&1) return bar&0xfffffffc;
  }
  return 0;
}

public U32 PCIGetFirstMMIO32(CPciDevInfo* info)
{
  I64 i, bar;
  for (i=0;i<6;i++)
  {
    bar=info->bar[i];
    if (!(bar&1)) return bar&0xFFFFFFF0;
  }
  return 0;
}
