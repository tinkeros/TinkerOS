#help_index "Comm"

#define PCISC_SERIAL 0
#define SERIAL_16550 2

#define MAX_COMM_NUM 12
#define COMM_RX_FIFO_SIZE 2048

#define UART_THR		0
#define UART_RDR		0
#define UART_BRDL		0
#define UART_IER		1
#define UART_BRDH		1
#define UART_IIR		2
#define UART_LCR		3
#define UART_MCR		4
#define UART_LSR		5
#define UART_MSR		6

#define COMf_ENABLED	0

#define COM_DEVICE_NONE 0
#define COM_DEVICE_TOS_SERVER 1
#define COM_DEVICE_REPL 2
#define COM_DEVICE_MOUSE 3
#define COM_DEVICE_SERIAL_MOUSE 4
#define COM_DEVICE_SERIAL_MS_MOUSE 5

class CComm
{
  I64   base,
        device,
        flags,
        poll,
        type,
        mmio;
  CFifoU8 *RX_fifo;
};

public CComm comm_ports[MAX_COMM_NUM+1];

public U0 CommHndlr(I64 port)
{// Com port IRQ handler
  CComm *c;
  CFifoU8 *f;
  I64 stat, free_size=COMM_RX_FIFO_SIZE;
  c=&comm_ports[port];
  if (Bt(&c->flags,COMf_ENABLED))
  {
    f=c->RX_fifo;
    if (f->out_ptr>f->in_ptr)
      free_size-=f->mask+1-(f->out_ptr-f->in_ptr);
    else
      free_size-=f->in_ptr-f->out_ptr;
    while (free_size>0)
    {
      stat=MixedInU8(c->mmio,c->base+UART_IIR);
      if (stat & 4)	//RX
      {
        FifoU8Ins(c->RX_fifo,MixedInU8(c->mmio,c->base+UART_RDR));
        free_size--;
      }
      else
        break;
    }
  }
}

public U0 PollCommHndlr(I64 port)
{// Com port IRQ handler
  CComm *c;
  CFifoU8 *f;
  I64 stat, free_size=COMM_RX_FIFO_SIZE;
  c=&comm_ports[port];
  if (Bt(&c->flags,COMf_ENABLED))
  {
    f=c->RX_fifo;
    if (f->out_ptr>f->in_ptr)
      free_size-=f->mask+1-(f->out_ptr-f->in_ptr);
    else
      free_size-=f->in_ptr-f->out_ptr;
    while (free_size>0)
    {
      stat=MixedInU8(c->mmio,c->base+UART_LSR);
      if (stat & 1)	//RX
      {
        FifoU8Ins(c->RX_fifo,MixedInU8(c->mmio,c->base+UART_RDR));
        free_size--;
      }
      else
        break;
    }
  }
}

interrupt U0 IRQComm3()
{// Com 2/4 IRQ handler
  CommHndlr(2);
  CommHndlr(4);
  OutU8(0x20,0x20);
}

interrupt U0 IRQComm4()
{// Com 1/3 IRQ handler
  CommHndlr(1);
  CommHndlr(3);
  OutU8(0x20,0x20);
}

interrupt U0 IRQCommPCI()
{// Com 5+ IRQ handler
  I64 port=5;
  while (port<=MAX_COMM_NUM)
  {
    if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].base>0)
      CommHndlr(port++);
  }
  *(dev.uncached_alias + LAPIC_EOI)(U32*)=0;
}

// TODO add other PCIE, common PCI/PCIE function

I64 AddPCIComms(I64 next_port)
{
  I64 class_code = PCIC_COM_CONTRL << 8 | PCISC_SERIAL,
      ioport,bdf,cur_port=next_port,
                 b, d, f, bar;
  for (b = 0; b < sys_pci_busses; b++)
    for (d = 0; d < 32; d++)
      for (f = 0; f < 8; f++)
      {
        if (class_code == PCIReadU16(b, d, f, PCIR_SUB_CODE) & 0xFFFF)
        {
          for (bar=PCIR_BASE0; bar<=PCIR_BASE5; bar+=4)
          {
            bdf = b << 16 | d << 8 | f;
            ioport = PCIReadU32(bdf.u8[2], bdf.u8[1], bdf.u8[0], bar);
            if (ioport&1)
            {
              comm_ports[cur_port].base=ioport&0xfffffffc;
              cur_port++;
              if (cur_port>MAX_COMM_NUM)
              {
                return cur_port;
              }
              break;
            }
          }
        }
      }
  return cur_port;
}

public CComm *CommInit7n1(I64 port,I64 baud)
{// Com port init function
  CComm *c=&comm_ports[port];
  PUSHFD
  CLI
  if (!c->RX_fifo)
    c->RX_fifo=FifoU8New(COMM_RX_FIFO_SIZE);
  MixedOutU8(c->mmio,c->base+UART_LCR,0);	//Set for IER
  MixedOutU8(c->mmio,c->base+UART_IER,0);	//Disable all IRQ
  MixedOutU8(c->mmio,c->base+UART_LCR,0x80);	//Enable baud rate control
  MixedOutU8(c->mmio,c->base+UART_BRDL,0x180/(baud/300) & 0xFF);	//LSB
  MixedOutU8(c->mmio,c->base+UART_BRDH,0x180/(baud/300) / 256);	//MSB
  MixedOutU8(c->mmio,c->base+UART_LCR,2);	//7-none-1
  MixedInU8(c->mmio,c->base+UART_RDR);	//read garbage
  MixedInU8(c->mmio,c->base+UART_LSR);
  MixedOutU8(c->mmio,c->base+UART_MCR,4);
  MixedOutU8(c->mmio,c->base+UART_IER,0);	//Disable all IRQ
  MixedOutU8(c->mmio,c->base+UART_MCR,0xA);	//out2 and rts
  if (!c->poll) {
    OutU8(0x21,InU8(0x21) & (0xFF-0x18));	//Enable 8259 IRQ 3 & 4
    MixedOutU8(c->mmio,c->base+UART_IER,1);	//RX but no THR empty
  }
  else 
    MixedOutU8(c->mmio,c->base+UART_IIR,0xC7);
  LBts(&c->flags,COMf_ENABLED);
  POPFD
  return c;
}

public CComm *CommInit8n1(I64 port,I64 baud)
{// Com port init function
  CComm *c=&comm_ports[port];
  PUSHFD
  CLI
  if (!c->RX_fifo)
    c->RX_fifo=FifoU8New(COMM_RX_FIFO_SIZE);
  MixedOutU8(c->mmio,c->base+UART_LCR,0);	//Set for IER
  MixedOutU8(c->mmio,c->base+UART_IER,0);	//Disable all IRQ
  MixedOutU8(c->mmio,c->base+UART_LCR,0x80);	//Enable baud rate control
  MixedOutU8(c->mmio,c->base+UART_BRDL,0x180/(baud/300) & 0xFF);	//LSB
  MixedOutU8(c->mmio,c->base+UART_BRDH,0x180/(baud/300) / 256);	//MSB
  MixedOutU8(c->mmio,c->base+UART_LCR,3);	//8-none-1
  MixedInU8(c->mmio,c->base+UART_RDR);	//read garbage
  MixedInU8(c->mmio,c->base+UART_LSR);
  MixedOutU8(c->mmio,c->base+UART_MCR,4);
  MixedOutU8(c->mmio,c->base+UART_IER,0);	//Disable all IRQ
  MixedOutU8(c->mmio,c->base+UART_MCR,0xA);	//out2 and rts
  if (!c->poll) {
    OutU8(0x21,InU8(0x21) & (0xFF-0x18));	//Enable 8259 IRQ 3 & 4
    MixedOutU8(c->mmio,c->base+UART_IER,1);	//RX but no THR empty
  }
  else
    MixedOutU8(c->mmio,c->base+UART_IIR,0xC7);
  LBts(&c->flags,COMf_ENABLED);
  POPFD
  return c;
}

public U0 PollComm(U8 *data)
{// Polls a serial port
  PUSHFD
  CLI
  PollCommHndlr(data);
  POPFD
}

public U0 CommPutChar(I64 port,U8 b, I64 timeout_ms=500)
{// Write 1 byte to com port
  CComm *c=&comm_ports[port];
  F64 timeout_time=tS+ToF64(timeout_ms)/1000.0;
  while (!(MixedInU8(c->mmio,c->base+UART_LSR) & 0x20))
  {
    if (tS>timeout_time) throw('ComErr');
    Yield;
  }
  MixedOutU8(c->mmio,c->base+UART_THR,b);
  while (!(MixedInU8(c->mmio,c->base+UART_LSR) & 0x20))
  {
    if (tS>timeout_time) throw('ComErr');
    Yield;
  }
  if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].poll)
  {
    Spawn(&PollComm, port);
    if (tS>timeout_time) throw('ComErr');
    Yield;
  }
}

public U8 CommGetChar(I64 port, I64 timeout_ms=500)
{// Get 1 byte from com port
  U8 chr;
  F64 timeout_time=tS+ToF64(timeout_ms)/1000.0;
  if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].poll)
  {
    PollCommHndlr(port);
  }
  while (1)
  {
    if (FifoU8Rem(comm_ports[port].RX_fifo, &chr))
      return chr;
    else {
      if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].poll)
      {
        PollCommHndlr(port);
        Yield;
      }
      else
        Yield;
    }
    if (tS>timeout_time) throw('ComErr');
  }
}

public Bool CommGetCharNoWait(I64 port, U8 *byte_out)
{// Try to get 1 byte from com port
  if (FifoU8Rem(comm_ports[port].RX_fifo, byte_out))
  {
    return TRUE;
  }
  if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].poll)
  {
    PollCommHndlr(port);
    if (FifoU8Rem(comm_ports[port].RX_fifo, byte_out))
    {
      return TRUE;
    }
  }
  return FALSE;
}

public U0 CommFlush(I64 port)
{// Flush com port fifos
  if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].poll)
      PollCommHndlr(port);
  FifoU8Flush(comm_ports[port].RX_fifo);
}

public U0 CommPutS(I64 port,U8 *st)
{// Writes string to com port
  I64 b;
  while (b=*st++)
    CommPutChar(port,b);
}

public U0 CommPutBlk(I64 port,U8 *buf,I64 cnt)
{// Writes a block to com port
  while (cnt--)
  {
    if (!(cnt%64)) Yield;
    CommPutChar(port,*buf++);
  }
}

public U0 CommPrint(I64 port,U8 *fmt,...)
{// Prints format string to com port
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv);
  CommPutS(port,buf);
  Free(buf);
}

U0 PciRerouteInterrupts(I64 base, I64 cpu=0)
{
  I64 i;
  U8 *da = dev.uncached_alias + IOAPIC_REG;
  U32 *_d = dev.uncached_alias + IOAPIC_DATA;
  for(i=0; i<4; i++)
  {
    *da=IOREDTAB +i*2 +1;
    *_d=dev.mp_apic_ids[cpu] << 24;
    *da=IOREDTAB+i*2;
    *_d=0x4000+base+i;
  }
}

U0 DisablePciInterrupts(I64 cpu=0)
{
  I64 i, base=0x40;
  U8 *da = dev.uncached_alias + IOAPIC_REG;
  U32 *_d = dev.uncached_alias + IOAPIC_DATA;
  for(i=0; i<4; i++)
  {
    *da=IOREDTAB +i*2 +1;
    *_d=dev.mp_apic_ids[cpu] << 24;
    *da=IOREDTAB+i*2;
    *_d=0x14000+base+i;
  }
}

U0 EnablePCIComms()
{
  I64 i=5;
 
  if (comm_ports[5].base)
  {
    while (comm_ports[i].base) {
      comm_ports[i++].poll=0;
    }
    IntEntrySet(0x40, &IRQCommPCI, IDTET_IRQ);
    IntEntrySet(0x41, &IRQCommPCI, IDTET_IRQ);
    IntEntrySet(0x42, &IRQCommPCI, IDTET_IRQ);
    IntEntrySet(0x43, &IRQCommPCI, IDTET_IRQ);
    if (mp_cnt>2)
    {
      PciRerouteInterrupts(0x40,2);
    }
    else if (mp_cnt>1)
    {
      PciRerouteInterrupts(0x40,1);
    }
    else
    {
      PciRerouteInterrupts(0x40,0);
    }
  }
}

public U0 CommInit()
{// Com port base/IRQ init function
  I64 i,next_port=5;
  MemSet(&comm_ports,0,sizeof(comm_ports));
  comm_ports[1].base=0x3F8;
  comm_ports[2].base=0x2F8;
  comm_ports[3].base=0x3E8;
  comm_ports[4].base=0x2E8;
  next_port=AddPCIComms(next_port);
  //TODOadd from more sources?
  for (i=0; i<MAX_COMM_NUM; i++)
  {
    comm_ports[i].flags=0;
    comm_ports[i].RX_fifo=NULL;
  }
  IntEntrySet(0x23,&IRQComm3);
  IntEntrySet(0x24,&IRQComm4);
  for (i=0; i<4; i++)
  {
    comm_ports[i].poll=0;
  }
  if (next_port>5)
  {
    for (i=5; i<next_port; i++)
    {
      comm_ports[i].poll=1;
    }
  }
}
CommInit;

U0 CommRep()
{
  I64 i;
  "COMM 1-4 are standard IO ports, the actual ports themselves may or may not exist.\n";
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    if (comm_ports[i].base)
    {
      if (comm_ports[i].poll)
        "COM %d - base 0x%08x (polled)\n",i,comm_ports[i].base;
      else
        "COM %d - base 0x%08x\n",i,comm_ports[i].base;
    }
  }
}

I64 CommGetFifoCnt(I64 port)
{
  CComm *c;
  CFifoU8 *f;
  I64 cnt=0;
  c=&comm_ports[port];
  if (Bt(&c->flags,COMf_ENABLED))
  {
    f=c->RX_fifo;
    if (f->out_ptr>f->in_ptr)
      cnt+=f->mask+1-(f->out_ptr-f->in_ptr);
    else
      cnt+=f->in_ptr-f->out_ptr;
  }
  return cnt;
}
