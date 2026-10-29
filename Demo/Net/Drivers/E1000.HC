/*  Intel(R) E1000 Driver
    Author: TomAwezome

    Driver is based on:
    -   01000101's example i825xx driver
    -   OSDev Intel(R) 8254x documentation
    -   Intel(R) PCI/PCI-X Family of Gigabit Ethernet Controllers Software Developer's Manual
    -   Linux E1000 driver
    -   any other useful sources.

    Guidelines:
    -   Magic numbers are bad. #defines are good.
    -   Understandability over LOC.
    -   Clear documentation.
*/

#define E1000_REG_CTRL  0x0000
#define E1000_REG_EERD  0x0014
#define E1000_REG_ICR   0x00C0
#define E1000_REG_IMS   0x00D0
#define E1000_REG_RCTL  0x0100
#define E1000_REG_TCTL  0x0400
#define E1000_REG_RDBAL 0x2800
#define E1000_REG_RDBAH 0x2804
#define E1000_REG_RDLEN 0x2808
#define E1000_REG_RDH   0x2810
#define E1000_REG_RDT   0x2818
#define E1000_REG_TDBAL 0x3800
#define E1000_REG_TDBAH 0x3804
#define E1000_REG_TDLEN 0x3808
#define E1000_REG_TDH   0x3810
#define E1000_REG_TDT   0x3818
#define E1000_REG_MTA   0x5200
#define E1000_REG_RAL0  0x5400
#define E1000_REG_RAH0  0x5404
// RAL0/RAH0 hold the MAC address firmware/BIOS already programmed at reset on
// every e1000/e1000e part. We read the MAC from here rather than via NVM/EEPROM

#define E1000_CTRLf_SLU 6

#define E1000_CTRLF_SLU (1 << E1000_CTRLf_SLU)

#define E1000_RCTLf_EN              1
#define E1000_RCTLf_SBP             2
#define E1000_RCTLf_UPE             3
#define E1000_RCTLf_MPE             4
#define E1000_RCTLf_LPE             5
#define E1000_RCTLf_RDMTS_QUARTER   8
#define E1000_RCTLf_RDMTS_EIGHTH    9
#define E1000_RCTLf_BAM             15
#define E1000_RCTLf_BSIZE_1024      16
#define E1000_RCTLf_BSIZE_512       17
#define E1000_RCTLf_BSIZE_256       18
#define E1000_RCTLf_SECRC           26

#define E1000_RCTLF_EN              (1 << E1000_RCTLf_EN)
#define E1000_RCTLF_SBP             (1 << E1000_RCTLf_SBP)
#define E1000_RCTLF_UPE             (1 << E1000_RCTLf_UPE)
#define E1000_RCTLF_MPE             (1 << E1000_RCTLf_MPE)
#define E1000_RCTLF_LPE             (1 << E1000_RCTLf_LPE)
#define E1000_RCTLF_RDMTS_QUARTER   (1 << E1000_RCTLf_RDMTS_QUARTER)
#define E1000_RCTLF_RDMTS_EIGHTH    (2 << E1000_RCTLf_RDMTS_QUARTER)
#define E1000_RCTLF_BAM             (1 << E1000_RCTLf_BAM)
#define E1000_RCTLF_BSIZE_1024      (1 << E1000_RCTLf_BSIZE_1024)
#define E1000_RCTLF_BSIZE_512       (2 << E1000_RCTLf_BSIZE_1024)
#define E1000_RCTLF_BSIZE_256       (3 << E1000_RCTLf_BSIZE_1024)
#define E1000_RCTLF_SECRC           (1 << E1000_RCTLf_SECRC)

#define E1000_TCTLf_EN    1
#define E1000_TCTLf_PSP   3
#define E1000_TCTLf_CT    4
#define E1000_TCTLf_COLD  12

#define E1000_TCTLF_EN    (1 << E1000_TCTLf_EN)
#define E1000_TCTLF_PSP   (1 << E1000_TCTLf_PSP)
#define E1000_TCTLF_CT    (0x0F << E1000_TCTLf_CT)
#define E1000_TCTLF_COLD  (0x40 << E1000_TCTLf_COLD)

#define PCI_CMDf_MEM  1
#define PCI_CMDf_BM   2

#define PCI_CMDF_MEM  (1 << PCI_CMDf_MEM)
#define PCI_CMDF_BM   (1 << PCI_CMDf_BM)

#define E1000_RDESC_STATUSf_EOP 1

#define E1000_RDESC_STATUSF_EOP (1 << E1000_RDESC_STATUSf_EOP)

#define E1000_EERDf_DONE    4

#define E1000_EERDF_DONE    (1 << E1000_EERDf_DONE)

#define E1000_TDESC_CMDf_EOP    0
#define E1000_TDESC_CMDf_IFCS   1
#define E1000_TDESC_CMDf_RS     3

#define E1000_TDESC_CMDF_EOP    (1 << E1000_TDESC_CMDf_EOP)
#define E1000_TDESC_CMDF_IFCS   (1 << E1000_TDESC_CMDf_IFCS)
#define E1000_TDESC_CMDF_RS     (1 << E1000_TDESC_CMDf_RS)

#define E1000_TDESC_STATUSf_DD  0
#define E1000_TDESC_STATUSf_EC  1
#define E1000_TDESC_STATUSf_LC  2
#define E1000_TDESC_STATUSf_TU  3

#define E1000_TDESC_STATUSF_DD  (1 << E1000_TDESC_STATUSf_DD)
#define E1000_TDESC_STATUSF_EC  (1 << E1000_TDESC_STATUSf_EC)
#define E1000_TDESC_STATUSF_LC  (1 << E1000_TDESC_STATUSf_LC)
#define E1000_TDESC_STATUSF_TU  (1 << E1000_TDESC_STATUSf_TU)

#define E1000_ICRf_TXDW     0
#define E1000_ICRf_TXQE     1
#define E1000_ICRf_LSC      2
#define E1000_ICRf_RXDMT    4
#define E1000_ICRf_RXO      6
#define E1000_ICRf_RXT      7

#define E1000_ICRF_TXDW     (1 << E1000_ICRf_TXDW)
#define E1000_ICRF_TXQE     (1 << E1000_ICRf_TXQE)
#define E1000_ICRF_LSC      (1 << E1000_ICRf_LSC)
#define E1000_ICRF_RXDMT    (1 << E1000_ICRf_RXDMT)
#define E1000_ICRF_RXO      (1 << E1000_ICRf_RXO)
#define E1000_ICRF_RXT      (1 << E1000_ICRf_RXT)

#define E1000_IMSf_TXDW     0
#define E1000_IMSf_TXQE     1
#define E1000_IMSf_LSC      2
#define E1000_IMSf_RXSEQ    3
#define E1000_IMSf_RXDMT    4
#define E1000_IMSf_RXO      6
#define E1000_IMSf_RXT      7
#define E1000_IMSf_MDAC     9
#define E1000_IMSf_RXCFG    10
#define E1000_IMSf_PHYINT   12
#define E1000_IMSf_GPI      13
#define E1000_IMSf_TXDLOW   15
#define E1000_IMSf_SRPD     16

#define E1000_IMSF_TXDW     (1 << E1000_IMSf_TXDW)
#define E1000_IMSF_TXQE     (1 << E1000_IMSf_TXQE)
#define E1000_IMSF_LSC      (1 << E1000_IMSf_LSC)
#define E1000_IMSF_RXSEQ    (1 << E1000_IMSf_RXSEQ)
#define E1000_IMSF_RXDMT    (1 << E1000_IMSf_RXDMT)
#define E1000_IMSF_RXO      (1 << E1000_IMSf_RXO)
#define E1000_IMSF_RXT      (1 << E1000_IMSf_RXT)
#define E1000_IMSF_MDAC     (1 << E1000_IMSf_MDAC)
#define E1000_IMSF_RXCFG    (1 << E1000_IMSf_RXCFG)
#define E1000_IMSF_PHYINT   (1 << E1000_IMSf_PHYINT)
#define E1000_IMSF_GPI      (2 << E1000_IMSf_GPI)
#define E1000_IMSF_TXDLOW   (1 << E1000_IMSf_TXDLOW)
#define E1000_IMSF_SRPD     (1 << E1000_IMSf_SRPD)

#define E1000_RX_BUFF_CNT 32
#define E1000_TX_BUFF_CNT 8

class CE1000DescEntRX
{
  U64   addr;
  U16 len;
  U16 checksum;
  U8    status;
  U8    errors;
  U16   special;
};

class CE1000DescEntTX
{
  U64 addr;
  U16 len;
  U8    cso;
  U8    cmd;
  U8    sta;
  U8    css;
  U16 special;
};

class CE1000
{
  CPciDevInfo *pci;

  U8    mac_addr[6];
  U64   mmio_addr;

  I64 current_rx_de_index;
  I64 current_tx_de_index;

  // All 4 buffers below are allocated straight out of sys_dma_heap, which hands
  // back memory that is already both uncached (safe for the CPU to read/write
  // without stale-cache surprises) and directly usable as-is by the NIC's DMA
  // engine -- unlike the old Fs->code_heap + dev.uncached_alias split, there is
  // no separate "_phys" address to track: this same pointer goes into hardware
  // descriptor/base-address registers AND is what the CPU reads/writes through.
  U8 *rx_de_buf;
  U8 *tx_de_buf;

  U8 *rx_buf_addr;
  U8 *tx_buf_addr;
} e1000;

Bool E1000DeviceIDValid(U16 device_id)
{
  switch (device_id)
  {
  case PCID_82540EM:
  case PCID_82545EM:
    return TRUE;
  }
  return FALSE;
}

U32 E1000MMIORead(U32 offset)
{
  U32 *val = e1000.mmio_addr + offset;
  return *val;
}

U0 E1000MMIOWrite(U32 offset, U32 val)
{
  U32 *addr = e1000.mmio_addr + offset;
  *addr = val;
}

U16 E1000EEPROMRead(U8 word)
{// word arg is which U16 to read
  U16 data;
  U32 temp;
  E1000MMIOWrite(E1000_REG_EERD, 1 | word << 8);
  temp = E1000MMIORead(E1000_REG_EERD);
  while (!PCIBt(&temp, E1000_EERDf_DONE))
  {
    Sleep(1);
    temp = E1000MMIORead(E1000_REG_EERD);
  }
  data = temp.u16[1];
  return data;
}

U0 E1000MACGet()
{// Read the MAC address out of RAL0/RAH0, see E1000_REG_RAL0/RAH0 comment above.
  U32 ral = E1000MMIORead(E1000_REG_RAL0);
  U32 rah = E1000MMIORead(E1000_REG_RAH0);
  NetLog("E1000 MAC GET: Getting MAC Address.");
  e1000.mac_addr[0] = ral.u8[0];
  e1000.mac_addr[1] = ral.u8[1];
  e1000.mac_addr[2] = ral.u8[2];
  e1000.mac_addr[3] = ral.u8[3];
  e1000.mac_addr[4] = rah.u8[0];
  e1000.mac_addr[5] = rah.u8[1];
  NetLog(" %02X %02X %02X %02X %02X %02X",
         e1000.mac_addr[0], e1000.mac_addr[1], e1000.mac_addr[2],
         e1000.mac_addr[3], e1000.mac_addr[4], e1000.mac_addr[5]);
}

I64 E1000PktRx(U8 **pkt_buf_out, U16 *pkt_len_out)
{
  I64 de_index = e1000.current_rx_de_index;
  CE1000DescEntRX *ent = &e1000.rx_de_buf[de_index * sizeof(CE1000DescEntRX)];
  Bool drop = FALSE;
  if (ent->len < 60)
  {
    NetErr("E1000 PACKET RECEIVE: Short Packet");
    drop = TRUE;
  }
  if (!PCIBt(&ent->status, E1000_RDESC_STATUSf_EOP))
  {
    NetErr("E1000 PACKET RECEIVE: No EOP Set");
    drop = TRUE;
  }
  if (ent->errors)
  {
    NetErr("E1000 PACKET RECEIVE: RX DE Error Bits Set");
    drop = TRUE;
  }
  e1000.current_rx_de_index = (e1000.current_rx_de_index + 1) & (E1000_RX_BUFF_CNT - 1);
  *pkt_buf_out = ent->addr;
  if (!drop)
    *pkt_len_out = ent->len;
  else
  {
    NetErr("E1000 PACKET RECEIVE: Dropping packet.");
    *pkt_len_out = 0;
  }
  return de_index;
}

U0 E1000RxPktRelease(I64 de_index)
{
  CE1000DescEntRX *ent = &e1000.rx_de_buf[de_index * sizeof(CE1000DescEntRX)];
  ent->status = 0;
  E1000MMIOWrite(E1000_REG_RDT, de_index);
}

Bool E1000DriverOwnsRX(CE1000DescEntRX *ent)
{
  return PCIBt(&ent->status, 0);
}

//One frame at a time, Allocate to end of Finish: senders on other CPUs
//(NetHandler ACKs, ElfRun sockets) shared a descriptor and stalled TX.
I64 e1000_tx_lock = 0;
CTask *e1000_tx_task = NULL;

I64 E1000TxPktAlloc(U8 **pkt_buf_out, I64 len)
{
  I64 de_index;
  CE1000DescEntTX *ent;
  while (LBts(&e1000_tx_lock, 0))
  {//Take over from a task that died holding it
    if (e1000_tx_task && (e1000_tx_task == Fs || !TaskValidate(e1000_tx_task)))
      break;
    Yield;
  }
  e1000_tx_task = Fs;
  de_index = e1000.current_tx_de_index;
  ent = &e1000.tx_de_buf[de_index * sizeof(CE1000DescEntTX)];
  *pkt_buf_out = e1000.tx_buf_addr + de_index * ETH_FRAME_SIZE;
  MemSet(*pkt_buf_out, 0, ETH_FRAME_SIZE);
  ent->addr    = *pkt_buf_out;
  ent->len = len;
  ent->sta = 0;
  PCIBts(&ent->cmd, E1000_TDESC_CMDf_EOP);
  PCIBts(&ent->cmd, E1000_TDESC_CMDf_IFCS);
  PCIBts(&ent->cmd, E1000_TDESC_CMDf_RS);
  NetLog("E1000 ALLOCATE TX PACKET: de_index: %X.", de_index);
  return de_index;
}

U0 E1000TxPktFinish(I64 de_index)
{
  CE1000DescEntTX *ent = &e1000.tx_de_buf[de_index * sizeof(CE1000DescEntTX)];
  I64 end = cnts.jiffies + JIFFY_FREQ / 10;
  e1000.current_tx_de_index = (de_index + 1) & (E1000_TX_BUFF_CNT - 1);
  E1000MMIOWrite(E1000_REG_TDT, e1000.current_tx_de_index);
  while (!(ent->sta & (E1000_TDESC_STATUSF_DD | E1000_TDESC_STATUSF_EC |
                         E1000_TDESC_STATUSF_LC | E1000_TDESC_STATUSF_TU)) &&
         cnts.jiffies < end)
    Yield;
  e1000_tx_task = NULL;
  LBtr(&e1000_tx_lock, 0);
  NetLog("E1000 FINISH TX PACKET: TX DE index: %X.", de_index);
}

U0 EthFrameFinish(I64 de_index)
{//Alias for driver Finish TX function.
  E1000TxPktFinish(de_index);
}

interrupt U0 E1000IRQ()
{// TODO need #defines
  U32                        icr = E1000MMIORead(E1000_REG_ICR);
  Bool                   poll = FALSE;
  CE1000DescEntRX *ent = e1000.rx_de_buf;
  U8                        *pkt_buf;
  U16                        pkt_len;
  I64                        de_index;
  icr &= ~(E1000_ICRF_TXDW | E1000_ICRF_TXQE);
  if (PCIBt(&icr, E1000_ICRf_LSC))
  {
    PCIBtr(&icr, E1000_ICRf_LSC);
    E1000MMIOWrite(E1000_REG_CTRL, E1000MMIORead(E1000_REG_CTRL) | E1000_CTRLF_SLU);
  }
  if (PCIBt(&icr, E1000_ICRf_RXO) || PCIBt(&icr, E1000_ICRf_RXDMT))
  {
    PCIBtr(&icr, E1000_ICRf_RXO);
    PCIBtr(&icr, E1000_ICRf_RXDMT);
    poll = TRUE;
  }
  if (PCIBt(&icr, E1000_ICRf_RXT))
  {
    PCIBtr(&icr, E1000_ICRf_RXT);
    poll = TRUE;
  }
  if (poll)
  {
    while (E1000DriverOwnsRX(&ent[e1000.current_rx_de_index]))
    {
      NetLog("$$BG,LTCYAN$$$$FG,WHITE$$"
             "==== E1000 IRQ ===="
             "$$BG$$$$FG$$");
      NetLog("$$BD,CYAN$$$$FD,WHITE$$"
             "E1000 IRQ: Saw owned RX DE index %d.", e1000.current_rx_de_index);
      de_index = E1000PktRx(&pkt_buf, &pkt_len);
      if (pkt_len)
        NetQuePush(pkt_buf, pkt_len);
      E1000RxPktRelease(de_index);
      NetLog("E1000 IRQ: Exiting.\n"
             "$$BD,WHITE$$$$FD,LTGRAY$$"
             "$$BG,LTCYAN$$$$FG,WHITE$$"
             "==================="
             "$$BG$$$$FG$$");
    }
  }
  E1000MMIORead(E1000_REG_ICR);
  *(dev.uncached_alias + LAPIC_EOI)(U32*) = 0;
}

U0 PCIInterruptsReroute(I64 base)
{// todo: comments explaining process, maybe better var names
  I64    i;
  U8    *da = dev.uncached_alias + IOAPIC_REG;
  U32 *_d = dev.uncached_alias + IOAPIC_DATA;
  for (i = 0; i < 4; i++)
  {
    *da = IOREDTAB + i * 2 + 1;
    *_d = dev.mp_apic_ids[INT_DEST_CPU] << 24;
    *da = IOREDTAB + i * 2;
    *_d = 0x4000 + base + i;
  }
}


U0 E1000InterruptsSetup()
{//Same vectors as PCNet.
  I64 i;
  for (i = 0; i < 4; i++)
    IntEntrySet(0x40 + i, &E1000IRQ);
  PciRerouteInterrupts(0x40);
}

U0 E1000InitRX()
{
  I64 de_index;
  e1000.rx_de_buf = CAllocAligned(sizeof(CE1000DescEntRX) * E1000_RX_BUFF_CNT,
                                     16,
                                     sys_dma_heap);
  e1000.rx_buf_addr = CAllocAligned(ETH_FRAME_SIZE * E1000_RX_BUFF_CNT, 16, sys_dma_heap);
  CE1000DescEntRX *ent = e1000.rx_de_buf;
  for (de_index = 0; de_index < E1000_RX_BUFF_CNT; de_index++)
  {
    ent->addr = e1000.rx_buf_addr + de_index * ETH_FRAME_SIZE;
    ent++;
  }
  E1000MMIOWrite(E1000_REG_RDBAH, e1000.rx_de_buf >> 32);
  E1000MMIOWrite(E1000_REG_RDBAL, e1000.rx_de_buf & 0xFFFFFFFF);
  E1000MMIOWrite(E1000_REG_RDLEN, E1000_RX_BUFF_CNT * 16);
  E1000MMIOWrite(E1000_REG_RDH, 0);
  E1000MMIOWrite(E1000_REG_RDT, E1000_RX_BUFF_CNT - 1);
  E1000MMIOWrite(E1000_REG_RCTL,    E1000_RCTLF_EN          |
                 E1000_RCTLF_SECRC      |
                 E1000_RCTLF_LPE            |
                 E1000_RCTLF_BAM);
}

U0 E1000InitTX()
{
  e1000.tx_de_buf = CAllocAligned(sizeof(CE1000DescEntTX) * E1000_TX_BUFF_CNT,
                                     16,
                                     sys_dma_heap);
  e1000.tx_buf_addr = CAllocAligned(ETH_FRAME_SIZE * E1000_TX_BUFF_CNT, 16, sys_dma_heap);
  E1000MMIOWrite(E1000_REG_TDBAH, e1000.tx_de_buf >> 32);
  E1000MMIOWrite(E1000_REG_TDBAL, e1000.tx_de_buf & 0xFFFFFFFF);
  E1000MMIOWrite(E1000_REG_TDLEN, E1000_TX_BUFF_CNT * 16);
  E1000MMIOWrite(E1000_REG_TDH, 0);
  E1000MMIOWrite(E1000_REG_TDT, E1000_TX_BUFF_CNT);
  E1000MMIOWrite(E1000_REG_TCTL, E1000_TCTLF_EN   | E1000_TCTLF_PSP |
                 E1000_TCTLF_CT   | E1000_TCTLF_COLD);
}


U0 E1000Init()
{
  I64 i;
  ZeroClass(&e1000);
  e1000.pci = &net_driver_pci;
  if (!E1000DeviceIDValid(e1000.pci->device_id))
    return;
  PCIWriteU16(e1000.pci->bus, e1000.pci->dev, e1000.pci->fun,
              PCIR_COMMAND, PCI_CMDF_MEM | PCI_CMDF_BM);
  e1000.mmio_addr = dev.uncached_alias + PCIGetFirstMMIO32(e1000.pci);
  "\nMMIO address: 0x%0X\n"
  , e1000.mmio_addr;
  E1000MACGet;
  E1000MMIOWrite(E1000_REG_CTRL, E1000MMIORead(E1000_REG_CTRL) | E1000_CTRLF_SLU);
  for (i = 0; i < 128; i++)
    E1000MMIOWrite(E1000_REG_MTA + i*4, 0);
  E1000MMIOWrite(E1000_REG_IMS, E1000_IMSF_LSC      |
                 E1000_IMSF_RXSEQ   |
                 E1000_IMSF_RXDMT   |
                 E1000_IMSF_RXO     |
                 E1000_IMSF_RXT     |
                 E1000_IMSF_MDAC        |
                 E1000_IMSF_RXCFG   |
                 E1000_IMSF_PHYINT  |
                 E1000_IMSF_GPI     |
                 E1000_IMSF_TXDLOW  |
                 E1000_IMSF_SRPD);
  E1000MMIORead(E1000_REG_ICR);
  E1000InitRX;
  E1000InitTX;
  E1000InterruptsSetup;
  "\n";
  ClassRep(&e1000);
}

I64 EthFrameAlloc(U8 **pkt_buf_out,
                          U8 *src_addr,
                          U8 *dst_addr,
                          U16 ethertype,
                          I64 pkt_len)
{
  U8 *eth_frame;
  I64 de_index;
  if (pkt_len < ETH_MIN_FRAME_SIZE)
  {
    NetWarn("ETHERNET FRAME ALLOCATE: Truncating length");
    pkt_len = ETH_MIN_FRAME_SIZE;
  }
  if (ETH_MAC_HDR_LEN + pkt_len > ETH_FRAME_SIZE)
  {//Would overrun into the next descriptor's buffer
    NetErr("ETHERNET FRAME ALLOCATE: Frame too long");
    return -1;
  }
  de_index = E1000TxPktAlloc(&eth_frame, ETH_MAC_HDR_LEN + pkt_len);
  if (de_index < 0)
  {
    NetErr("ETHERNET FRAME ALLOCATE: Failure");
    return -1;
  }
  *pkt_buf_out = EthHdrSet(eth_frame, src_addr,
        dst_addr, ethertype);
  return de_index;
}

U8 *EthMACGet()
{
  return e1000.mac_addr;
}

U0 NetStop()
{
}

U0 NetStart()
{
}

E1000Init;
