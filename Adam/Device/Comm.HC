#help_index "Comm"

#define PCISC_SERIAL 0
#define SERIAL_16550 2

#define MAX_COMM_NUM 12
#define COMM_RX_FIFO_SIZE 2048

#define COMT_NONE 0
#define COMT_UART 1
#define COMT_USB  2
#define COMT_TCP  3
#define COMT_NUM  4

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
        mmio,
        usb_k,
        usb_gen;
  CFifoU8 *RX_fifo;
  U8   *link,
       *name;
  Bool  probe_skip;
};

public CComm comm_ports[MAX_COMM_NUM+1];

class CCommOps
{//What the public Comm API needs from a port type. tx_flush/lines are optional.
  U0   (*init)(CComm *c, I64 baud, I64 lcr);
  Bool (*put)(CComm *c, U8 *buf, I64 cnt, I64 timeout_ms);
  U0   (*rx_poll)(CComm *c);
  U0   (*tx_flush)(CComm *c);
  U0   (*lines)(CComm *c, I64 dtr, I64 rts);
};
CCommOps comm_ops[COMT_NUM];

Bool CommAttached(CComm *c)
{//USB and TCP slots are owned by whatever attached them, not by CommInit.
  return c->type==COMT_USB || c->type==COMT_TCP;
}

I64 CommEffType(CComm *c)
{//A COMT_NONE port with a hand-set base behaves as UART, same as always.
  if (c->type==COMT_NONE && c->base)
    return COMT_UART;
  return c->type;
}

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

U0 UartRxPoll(CComm *c)
{//Move bytes already in the 16550 FIFO into c->RX_fifo (poll-mode LSR check).
  CFifoU8 *f;
  I64 stat, free_size=COMM_RX_FIFO_SIZE;
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

public U0 PollCommHndlr(I64 port)
{// Com port IRQ handler
  UartRxPoll(&comm_ports[port]);
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
  I64 port;
  for (port=5; port<=MAX_COMM_NUM; port++)
    if (Bt(&comm_ports[port].flags,COMf_ENABLED) && comm_ports[port].base>0)
      CommHndlr(port);
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
              while (cur_port<=MAX_COMM_NUM && CommAttached(&comm_ports[cur_port]))
                cur_port++;
              if (cur_port>MAX_COMM_NUM)
                return cur_port;
              comm_ports[cur_port].base=ioport&0xfffffffc;
              comm_ports[cur_port].type=COMT_UART;
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

U0 UartInit(CComm *c, I64 baud, I64 lcr)
{
  PUSHFD
  CLI
  if (!c->RX_fifo)
    c->RX_fifo=FifoU8New(COMM_RX_FIFO_SIZE);
  MixedOutU8(c->mmio,c->base+UART_LCR,0);	//Set for IER
  MixedOutU8(c->mmio,c->base+UART_IER,0);	//Disable all IRQ
  MixedOutU8(c->mmio,c->base+UART_LCR,0x80);	//Enable baud rate control
  MixedOutU8(c->mmio,c->base+UART_BRDL,0x180/(baud/300) & 0xFF);	//LSB
  MixedOutU8(c->mmio,c->base+UART_BRDH,0x180/(baud/300) / 256);	//MSB
  MixedOutU8(c->mmio,c->base+UART_LCR,lcr);
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
}

Bool UartPut(CComm *c, U8 *buf, I64 cnt, I64 timeout_ms)
{//Loops over THR as CommPutChar always did, one byte's timeout per byte.
  I64 i;
  F64 timeout_time;
  for (i=0; i<cnt; i++)
  {
    timeout_time=tS+ToF64(timeout_ms)/1000.0;
    while (!(MixedInU8(c->mmio,c->base+UART_LSR) & 0x20))
    {
      if (tS>timeout_time) return FALSE;
      Yield;
    }
    MixedOutU8(c->mmio,c->base+UART_THR,buf[i]);
    if (!(i&63)) Yield;
  }
  timeout_time=tS+ToF64(timeout_ms)/1000.0;
  while (!(MixedInU8(c->mmio,c->base+UART_LSR) & 0x20))
  {
    if (tS>timeout_time) return FALSE;
    Yield;
  }
  if (Bt(&c->flags,COMf_ENABLED) && c->poll)
    UartRxPoll(c);
  return TRUE;
}

public CComm *CommInit7n1(I64 port,I64 baud)
{// Com port init function
  CComm *c=&comm_ports[port];
  (*comm_ops[CommEffType(c)].init)(c,baud,2);
  return c;
}

public CComm *CommInit8n1(I64 port,I64 baud)
{// Com port init function
  CComm *c=&comm_ports[port];
  (*comm_ops[CommEffType(c)].init)(c,baud,3);
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
  if (!(*comm_ops[CommEffType(c)].put)(c,&b,1,timeout_ms))
    throw('ComErr');
}

public U8 CommGetChar(I64 port, I64 timeout_ms=500)
{// Get 1 byte from com port
  CComm *c=&comm_ports[port];
  I64 ty=CommEffType(c);
  U8 chr;
  F64 timeout_time=tS+ToF64(timeout_ms)/1000.0;
  if (comm_ops[ty].tx_flush)
    (*comm_ops[ty].tx_flush)(c);
  if (Bt(&c->flags,COMf_ENABLED) && c->poll)
  {
    (*comm_ops[ty].rx_poll)(c);
  }
  while (1)
  {
    if (FifoU8Rem(c->RX_fifo, &chr))
      return chr;
    else {
      if (Bt(&c->flags,COMf_ENABLED) && c->poll)
      {
        (*comm_ops[ty].rx_poll)(c);
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
  CComm *c=&comm_ports[port];
  I64 ty=CommEffType(c);
  if (comm_ops[ty].tx_flush)
    (*comm_ops[ty].tx_flush)(c);
  if (FifoU8Rem(c->RX_fifo, byte_out))
  {
    return TRUE;
  }
  if (Bt(&c->flags,COMf_ENABLED) && c->poll)
  {
    (*comm_ops[ty].rx_poll)(c);
    if (FifoU8Rem(c->RX_fifo, byte_out))
    {
      return TRUE;
    }
  }
  return FALSE;
}

public U0 CommFlush(I64 port)
{// Flush com port fifos (and any buffered TX)
  CComm *c=&comm_ports[port];
  I64 ty=CommEffType(c);
  if (comm_ops[ty].tx_flush)
    (*comm_ops[ty].tx_flush)(c);
  if (Bt(&c->flags,COMf_ENABLED) && c->poll)
      (*comm_ops[ty].rx_poll)(c);
  FifoU8Flush(c->RX_fifo);
}

public U0 CommPutS(I64 port,U8 *st)
{// Writes string to com port
  CComm *c=&comm_ports[port];
  if (!(*comm_ops[CommEffType(c)].put)(c,st,StrLen(st),500))
    throw('ComErr');
}

public U0 CommPutBlk(I64 port,U8 *buf,I64 cnt)
{// Writes a block to com port
  CComm *c=&comm_ports[port];
  if (!(*comm_ops[CommEffType(c)].put)(c,buf,cnt,500))
    throw('ComErr');
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


U0 CommNoneInit(CComm *c, I64 baud, I64 lcr)
{
  no_warn c,baud,lcr;
}

Bool CommNonePut(CComm *c, U8 *buf, I64 cnt, I64 timeout_ms)
{//CommPutChar/CommPutS/CommPutBlk turn this into throw('ComErr').
  no_warn c,buf,cnt,timeout_ms;
  return FALSE;
}

U0 CommNoneRxPoll(CComm *c)
{
  no_warn c;
}

ArrayZero(comm_ports,MAX_COMM_NUM+1);
ArrayZero(comm_ops,COMT_NUM);
comm_ops[COMT_NONE].init=&CommNoneInit;
comm_ops[COMT_NONE].put=&CommNonePut;
comm_ops[COMT_NONE].rx_poll=&CommNoneRxPoll;
comm_ops[COMT_UART].init=&UartInit;
comm_ops[COMT_UART].put=&UartPut;
comm_ops[COMT_UART].rx_poll=&UartRxPoll;

public U0 CommInit()
{//Com port base/IRQ init. Safe to recall; leaves USB/TCP slots alone.
  I64 i,next_port=5;
  comm_ports[1].base=0x3F8; comm_ports[1].type=COMT_UART;
  comm_ports[2].base=0x2F8; comm_ports[2].type=COMT_UART;
  comm_ports[3].base=0x3E8; comm_ports[3].type=COMT_UART;
  comm_ports[4].base=0x2E8; comm_ports[4].type=COMT_UART;
  next_port=AddPCIComms(next_port);

  for (i=1; i<=MAX_COMM_NUM; i++)
    if (!CommAttached(&comm_ports[i]))
    {
      if (comm_ports[i].RX_fifo)
      {
        FifoU8Del(comm_ports[i].RX_fifo);
        comm_ports[i].RX_fifo=NULL;
      }
      comm_ports[i].flags=0;
    }
  IntEntrySet(0x23,&IRQComm3);
  IntEntrySet(0x24,&IRQComm4);
  for (i=1; i<=4; i++)
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

// Disable by default for now, user can run if they need/want it.
// Disabling speeds boot on some systems.
//CommInit;

public Bool CommExists(I64 port)
{//TRUE if port is a real/attached COM port (UART with a base, or USB serial).
  if (port<1 || port>MAX_COMM_NUM) return FALSE;
  return CommEffType(&comm_ports[port])!=COMT_NONE;
}

U0 CommRep()
{
  I64 i;
  "COMM 1-4 are standard IO ports, the actual ports themselves may or may not exist.\n";
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    if (CommExists(i))
    {
      if (comm_ports[i].type==COMT_USB)
        "COM %d - USB #%d\n",i,comm_ports[i].usb_k;
      else if (comm_ports[i].type==COMT_TCP)
        "COM %d - TCP %s\n",i,comm_ports[i].name;
      else if (comm_ports[i].poll)
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
