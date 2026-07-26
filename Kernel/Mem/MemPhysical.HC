U0 ApicMemInit()
{
  I64 *pte;
  pte=MemPageTable(IOAPIC_REG);
  *pte=*pte&~0x18 |0x11;
  pte=MemPageTable(LAPIC_BASE);
  *pte=*pte&~0x18 |0x11;
  WBINVD
}

U8 *Mem64DevAlloc(I64 *_pages1Gig)
{//Alloc 64-bit addr space for device.
  U8 *a;
  I64 i=*_pages1Gig,*pte;
  while (LBts(&sys_semas[SEMA_DEV_MEM],0))
    Yield;
  while (i--)
  {
    a=dev.mem64_ptr-=1<<30;
    do
    {
      pte=MemPageTable(a);
      *pte=*pte&~0x18 |0x11; //Uncached and present
      InvlPg(dev.mem64_ptr);
      a+=mem_page_size;
    }
    while (a-dev.mem64_ptr<1<<30);
  }
  LBtr(&sys_semas[SEMA_DEV_MEM],0);
  return dev.mem64_ptr;
}

U0 Mem64DevFree(U8 *base,I64 pages1Gig)
{//Free 64-bit device address space.
  if (!base) return;
  while (LBts(&sys_semas[SEMA_DEV_MEM],0))
    Yield;
  if (base==dev.mem64_ptr)
    dev.mem64_ptr+=pages1Gig*1<<30;
//else not freed
  LBtr(&sys_semas[SEMA_DEV_MEM],0);
}

U0 UncachedAliasAlloc() //Make uncached alias for 4 lowest Gig.
{
  I64 i=4,*pte;
  U8 *a;
  a=dev.uncached_alias=Mem64DevAlloc(&i);
  do
  {
    pte=MemPageTable(a);
    *pte=0x197+a-dev.uncached_alias;
    InvlPg(a);
    a+=mem_page_size;
  }
  while (a-dev.uncached_alias<1<<32);
  WBINVD
}

public I64 BIOSTotalMem()
{
  I64 r01,r20;
  U16		*m01=MEM_E801;
  CMemE820	*m20=MEM_E820;
  r01=0x100000+m01[0]<<10+m01[1]<<16;
  r20=0;
  if (m20->type)
  {
    while (m20->type)
    {
      if (m20->type==1)
        r20+=m20->len;
      m20++;
    }
  }
  return MaxI64(r01,r20);
}

I64 Scale2Mem(I64 min,I64 max,I64 limit=2*1024*1024*1024)
{//Helps pick DiskCache and RAMDisk sizes.
//Can be used in $LK,"BootHDIns",A="MN:BootHDIns"$() config scripts.
  I64 i;
  if (sys_data_bp)
    i=sys_data_bp->alloced_u8s;
  else
    i=sys_code_bp->alloced_u8s;
  if (i>=limit)
    return max;
  else
    return min+(max-min)*i/limit;
}

I64 Seg2Linear(U32 *ptr)
{//Convert 32-bit segmented far pointer to linear address. Modify in place.
  *ptr = *ptr >> 16 << 4 + *ptr & 0xFFFF;
  return *ptr;
}

public U8 MixedInU8(I64 mmio, I64 port)
{//Dual function to support MMIO/IO space reading
  U8 *mmio_ptr=mmio;
  if (mmio)
    return *mmio_ptr;
  else
    return InU8(port);
}

public U0 MixedOutU8(I64 mmio, I64 port, I64 val)
{//Dual function to support MMIO/IO space writing
  U8 *mmio_ptr=mmio;
  if (mmio)
    *mmio_ptr=val;
  else
    OutU8(port,val);
}

public U0 MakeAddrUncached(I64 mmio_addr)
{//Make address uncached
  *MemPageTable(mmio_addr)=*MemPageTable(mmio_addr)&~0x18 |0x11;
  *MemPageTable(mmio_addr+mem_page_size)=*MemPageTable(mmio_addr+mem_page_size)&~0x18 |0x11;
}

