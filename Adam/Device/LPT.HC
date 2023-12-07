#help_index "ParallelPort"

/*
 * TODO add functions for reading
 * Add functions for writing non-data bits
 */

#define PCIC_LPT    7
#define PCISC_PARALLEL 1

#define MAX_LPT_NUM 8

#define OFFSET_LPT_DATA    0
#define OFFSET_LPT_STATUS  1
#define OFFSET_LPT_CONTROL 2

class CLpt
{
  I64   base,
        device,
        flags;
};

public CLpt lpt_ports[MAX_LPT_NUM+1];

I64 AddPCIPP(I64 next_port)
{
  I64 class_code = PCIC_LPT << 8 | PCISC_PARALLEL,
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
              lpt_ports[cur_port].base=ioport&0xfffffffc;
              cur_port++;
              if (cur_port>MAX_LPT_NUM)
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

public U0 LptPutChar(I64 port,U8 b)
{
// Write 1 byte to lpt port
  I64 base=lpt_ports[port].base;
  OutU8(base+OFFSET_LPT_DATA,b);
}

public U0 LptPutS(I64 port,U8 *st)
{// Writes string to lpt port
  I64 b;
  while (b=*st++)
    LptPutChar(port,b);
}

public U0 LptPutBlk(I64 port,U8 *buf,I64 cnt)
{// Writes a block to lpt port
  while (cnt--)
  {
    if (!(cnt%64)) Yield;
    LptPutChar(port,*buf++);
  }
}

public U0 LptPrint(I64 port,U8 *fmt,...)
{// Prints format string to lpt port
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv);
  LptPutS(port,buf);
  Free(buf);
}

public U0 LptInit()
{// LPT port base
  I64 i,next_port=4;
  MemSet(&lpt_ports,0,sizeof(lpt_ports));
  lpt_ports[1].base=0x3BC;
  lpt_ports[2].base=0x378;
  lpt_ports[3].base=0x278;
  next_port=AddPCIPP(next_port);
  for (i=0; i<MAX_LPT_NUM; i++)
  {
    lpt_ports[i].flags=0;
  }
}
LptInit;

U0 LptRep()
{
  I64 i;
  for (i=1; i<=MAX_LPT_NUM; i++)
  {
    "LPT 1-3 are standard IO ports, the actual ports themselves may or may not exist.\n";
    if (lpt_ports[i].base)
    {
      "LPT %d - base 0x%08x\n",i,lpt_ports[i].base;
    }
  }
}
