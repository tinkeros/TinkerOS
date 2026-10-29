/*  AMD PCNetII Driver
    Author: TomAwezome

    Driver is based on:
    -   minexew's ShrineOS PCNet implementation
    -   OSDev AMD_PCNET documentation
    -   AMD PCnet(TM)-PCI datasheet
    -   any other useful sources.

    Guidelines:
    -   Magic numbers are bad. #defines are good.
    -   Understandability over LOC.
    -   Clear documentation.
*/

#define PCNET_DEBUG_OUTPUT 0

#define PCNET_CMDf_IOEN 0
#define PCNET_CMDf_BMEN 2

#define PCNET_CMDF_IOEN (1 << PCNET_CMDf_IOEN)
#define PCNET_CMDF_BMEN (1 << PCNET_CMDf_BMEN)

#define PCNET_WD_RESET  0x14

#define PCNET_DW_RDP    0x10
#define PCNET_DW_RAP    0x14
#define PCNET_DW_BDP    0x1c
#define PCNET_DW_RESET  0x18

#define PCNET_CSR_CTRLSTATUS    0
#define PCNET_CSR_INTERRUPTS    3
#define PCNET_CSR_FEATURECTRL   4
#define PCNET_CSR_LADRF0        8
#define PCNET_CSR_LADRF1        9
#define PCNET_CSR_LADRF2        10
#define PCNET_CSR_LADRF3        11
#define PCNET_CSR_PADR0         12
#define PCNET_CSR_PADR1         13
#define PCNET_CSR_PADR2         14
#define PCNET_CSR_MODE          15
#define PCNET_CSR_BADRL         24
#define PCNET_CSR_BADRU         25
#define PCNET_CSR_BADTL         30
#define PCNET_CSR_BADTU         31
#define PCNET_CSR_POLLINT       47
#define PCNET_CSR_SOFTWARESTYLE 58
#define PCNET_CSR_RXRINGLEN     76
#define PCNET_CSR_TXRINGLEN     78

#define PCNET_SWSTYLE_SELECTION 2

#define PCNET_SWSTYLE_SSIZE32   8

// Refer to AMD PCNet datasheet p. 1-954, 1-956, 1-957 for Interrupt Mask details.
#define PCNET_INT_BSWP      2
#define PCNET_INT_IDONM     8
#define PCNET_INT_TINTM     9
#define PCNET_INT_RINTM     10

#define PCNET_FEATURE_APADXMT   11

#define PCNET_CTRL_INIT 0
#define PCNET_CTRL_STRT 1
#define PCNET_CTRL_STOP 2
#define PCNET_CTRL_IENA 6
#define PCNET_CTRL_IDON 8
#define PCNET_CTRL_RINT 10

#define PCNET_RX_BUFF_CNT 64
#define PCNET_TX_BUFF_CNT 64

#define PCNET_DESCRIPTORf_ENP   24
#define PCNET_DESCRIPTORf_STP   25
#define PCNET_DESCRIPTORf_OWN   31

class CPCNet
{
  CPciDevInfo *pci;

  U8    mac_addr[6];

  I64 current_rx_de_index;
  I64 current_tx_de_index;

  // All 4 buffers are allocated straight out of sys_dma_heap, which hands back
  // memory that is already both uncached and directly usable as-is by the
  // card's DMA engine -- there is no separate physical/uncached-alias pair to
  // track (see EthFrameAllocate/PCNetPacketRx: previously these
  // handed around a code_heap physical address and added dev.uncached_alias
  // at the point of CPU access; with sys_dma_heap that same pointer already
  // works for both, so those call sites no longer add the alias).
  U8 *rx_de_buf;
  U8 *tx_de_buf;

  U8 *rx_buf_addr;
  U8 *tx_buf_addr;

} pcnet;

class CPCNetDescEnt
{
  /* AMD PCNet datasheet p.1-991 & p.1-994 NOTE: chart typo  on 1-994, see ONES and BCNT on 1-995.
  TX and RX DE's are the same size (16-Bytes) and structure,
  but have different registers and functions.
  The RX and TX DE buffers of the CPCNet class
  are allocated to a certain amount of these DEs. */

  U32   buf_addr;
  U32 status1;
  U32 status2;
  U32 reserved;
};

class CPCNetBufSetup
{
  U16 mode;
  union
  {
    U8 rlen_byte;
    U8 rlen_rsvd:4;
    U8 rlen:4;
  }
  union
  {
    U8 tlen_byte;
    U8 tlen_rsvd:4;
    U8 tlen:4;
  }
  U8    mac[6];
  U16 reserved;
  U8    ladr[8];
  U32 rxbuf;
  U32 txbuf;
};

U32 PCNetIOBaseGet()
{
  /* Return memory IO base address
  of PCNet card. Bits 0-4 are not
  for the IO base, so an AND with
  ~0x1F ignores those bits. */
  U32 io_base = pcnet.pci->bar[0] & ~0x1F;
  return io_base;
}

U0 PCNetRst()
{
  /* Reads the 32- and 16-bit RESET registers,
  which, regardless of which mode the card is in,
  will reset it back to 16-bit mode. */
  InU32(PCNetIOBaseGet + PCNET_DW_RESET);
  InU16(PCNetIOBaseGet + PCNET_WD_RESET);
  Busy(5);
}

U0 PCNet32BitModeEnable()
{
  /* AMD PCNet datasheet p. 1-930
  Summary: A 32-bit write (while in 16-bit mode)
  to RDP  will cause 16-bit mode exit
  and immediate enter into 32-bit mode. */
  OutU32(PCNetIOBaseGet + PCNET_DW_RDP, 0);
}

U0 PCNetRAPWrite(U32 value)
{
  /* AMD PCNet datasheet p. 1-952
  Summary: Register Address Pointer register
  value will indicate which CSR / BCR register
  we want to access in RDP / BDP. */
  OutU32(PCNetIOBaseGet + PCNET_DW_RAP, value);
}

U0 PCNetBCRWrite(U32 bcr, U32 value)
{
  /* AMD PCNet datasheet p. 1-952
  Summary: Bus Control Registers are
  accessed via the BDP (Bus Data Port).
  Which BCR is selected is based on the value
  in the RAP. */
  PCNetRAPWrite(bcr);
  OutU32(PCNetIOBaseGet + PCNET_DW_BDP, value);
}

U32 PCNetBCRRead(U32 bcr)
{
  /* AMD PCNet datasheet p. 1-952
  Summary: Bus Control Registers are
  accessed via the BDP (Bus Data Port).
  Which BCR is selected is based on the value
  in the RAP. */
  PCNetRAPWrite(bcr);
  return InU32(PCNetIOBaseGet + PCNET_DW_BDP);
}

U0 PCNetCSRWrite(U32 csr, U32 value)
{
  /* AMD PCNet datasheet p. 1-952
  Summary: Control and Status Registers are
  accessed via the RDP (Register Data Port).
  Which CSR is selected is based on the value
  in the RAP. */
  PCNetRAPWrite(csr);
  OutU32(PCNetIOBaseGet + PCNET_DW_RDP, value);
}

U32 PCNetCSRRead(U32 csr)
{
  /* AMD PCNet datasheet p. 1-952
  Summary: Control and Status Registers are
  accessed via the RDP (Register Data Port).
  Which CSR is selected is based on the value
  in the RAP. */
  PCNetRAPWrite(csr);
  return InU32(PCNetIOBaseGet + PCNET_DW_RDP);
}

U0 PCNetSWStyleSet()
{
  /* AMD PCNet datasheet p. 1-968
  In CSR58 (Software Style), the 8-bit
  SWSTYLE register dictates interpretation of certain
  bits in the CSR space, and widths of descriptors and
  initialization block. In PCINet-PCI mode, CSR4 bits
  function as defined in the datasheet , and TMD1[29]
  functions as ADD_FCS. */
  U32 csr = PCNetCSRRead(PCNET_CSR_SOFTWARESTYLE);
  csr &= ~0xFF;
  csr |= PCNET_SWSTYLE_SELECTION;
  Bts(&csr, PCNET_SWSTYLE_SSIZE32);
  PCNetCSRWrite(PCNET_CSR_SOFTWARESTYLE, csr);
}

U0 PCNetMACGet()
{
  /* AMD PCNet datasheet p. 1-887, 1-931, 1-937
  MAC address stored at first 6 bytes of PCNet EEPROM.
  EEPROM addresses shadow-copied to APROM at hardware init.
  APROM accessible at first 16 bytes of PCI IO space. */
  I64 i;
  U64 eeprom_bytes = InU32(PCNetIOBaseGet) | InU32(PCNetIOBaseGet + 4) << 32;
  NetLog("PCNET GET MAC: Getting VM MAC.");
  for (i = 0; i < 6; i++)
  {
    pcnet.mac_addr[i] = eeprom_bytes.u8[i];
    NetLog(" %02X", pcnet.mac_addr[i]);
  }
}

U0 PCNetDescEntInit(CPCNetDescEnt *ent, U32 buf_addr, I64 is_rx)
{
  U16 buf_byte_cnt;
  ent->buf_addr = buf_addr;
  /*    AMD PCNet datasheet p.1-991.
    BCNT is the usable buffer length, expressed as first
    12 bits of 2s-complement of desired length.
    Bits 0-11 of a DE are for the buffer byte cnt (BCNT),
    and bits 12-15 of a DE must be written all ones (ONES) */
  buf_byte_cnt = -ETH_FRAME_SIZE;
  buf_byte_cnt &= 0x0FFF;
  ent->status1 |= buf_byte_cnt;
  ent->status1 |= 0xF000;
  if (is_rx)
    PCIBts(&ent->status1, PCNET_DESCRIPTORf_OWN);
}

U0 PCNetBufsAlloc()
{
  I64 de_index;
  /*    AMD PCNet datasheet p.1-913, p.1-990
    When SSIZE32=1, Descriptor Ring Entry Base Address
    must be on 16-byte boundary. (TDRA[3:0]=0, RDRA[3:0]=0) */
  pcnet.rx_de_buf = CAllocAligned(sizeof(CPCNetDescEnt) * PCNET_RX_BUFF_CNT,
                                     16, sys_dma_heap);
  pcnet.tx_de_buf = CAllocAligned(sizeof(CPCNetDescEnt) * PCNET_TX_BUFF_CNT,
                                     16, sys_dma_heap);
  pcnet.rx_buf_addr = CAllocAligned(ETH_FRAME_SIZE * PCNET_RX_BUFF_CNT, 16, sys_dma_heap);
  pcnet.tx_buf_addr = CAllocAligned(ETH_FRAME_SIZE * PCNET_TX_BUFF_CNT, 16, sys_dma_heap);
  CPCNetDescEnt *ent = pcnet.rx_de_buf;
  for (de_index = 0; de_index < PCNET_RX_BUFF_CNT; de_index++)
  {
    PCNetDescEntInit(&ent[de_index],
                             pcnet.rx_buf_addr + de_index * ETH_FRAME_SIZE,
                             TRUE);
  }
  ent = pcnet.tx_de_buf;
  for (de_index = 0; de_index < PCNET_TX_BUFF_CNT; de_index++)
  {
    PCNetDescEntInit(&ent[de_index],
                             pcnet.tx_buf_addr + de_index * ETH_FRAME_SIZE,
                             FALSE);
  }
}

/*
U0 PCNetDirectInit()
{/* AMD PCNet datasheet p. 1-1021
    Instead of setting up initialization block,
    direct writes to the necessary CSRs can be
    used to manually initialize the PCNet card. */

/*  AMD PCNet datasheet p.1-991
    If Logical Address Filter is set as
    all 0, all incoming logical addresses
    are rejected. Disables multicast. */
PCNetCSRWrite(PCNET_CSR_LADRF0, 0);
PCNetCSRWrite(PCNET_CSR_LADRF1, 0);
PCNetCSRWrite(PCNET_CSR_LADRF2, 0);
PCNetCSRWrite(PCNET_CSR_LADRF3, 0);

/*  The Physical Address is the MAC.
    AMD PCNet datasheet p.1-960, 1-961
    The first 16 bits of CSRs 12-14 are
    for the Physical Address, the upper bits
    are reserved, written 0 read undefined.

    The OR and bit-shift of 8 allows writing
    separate U8 values in the correct locations
    of the CSR. */
NetLog("PCNetDirectInit: Write MAC to CSR: 0x%X ", pcnet.mac_addr[0] | (pcnet.mac_addr[1] << 8));
PCNetCSRWrite(PCNET_CSR_PADR0, pcnet.mac_addr[0] | (pcnet.mac_addr[1] << 8));
NetLog("PCNetDirectInit: Write MAC to CSR: 0x%X ", pcnet.mac_addr[2] | (pcnet.mac_addr[3] << 8));
PCNetCSRWrite(PCNET_CSR_PADR1, pcnet.mac_addr[2] | (pcnet.mac_addr[3] << 8));
NetLog("PCNetDirectInit: Write MAC to CSR: 0x%X ", pcnet.mac_addr[4] | (pcnet.mac_addr[5] << 8));
PCNetCSRWrite(PCNET_CSR_PADR2, pcnet.mac_addr[4] | (pcnet.mac_addr[5] << 8));

/*  AMD PCNet datasheet p.1-961, 1-962, 1-963
    Refer to datasheet for specifics.
    Most relevant, when setting Mode to 0,
    promiscuous mode is is disabled, TX and
    RX enabled, enable RX broadcast and unicast. */
PCNetCSRWrite(PCNET_CSR_MODE, 0);

/*  AMD PCNet datasheet p.1-964
    CSR 24 and 25 need to be filled
    with the lower and upper 16 bits,
    respectively, of the address of
    the RX packet ring. Likewise for
    CSR 30 and 31 for the TX packet ring.

    0xFFFF AND on address will leave
    only lower 16 bits remaining.

    Bitshift right of 16 will replace
    first 16 bits  with upper 16 bits,
    remaining bits cleared.*/
PCNetCSRWrite(PCNET_CSR_BADRL, pcnet.rx_buf_addr & 0xFFFF);
PCNetCSRWrite(PCNET_CSR_BADRU, pcnet.rx_buf_addr >> 16);

PCNetCSRWrite(PCNET_CSR_BADTL, pcnet.tx_buf_addr & 0xFFFF);
PCNetCSRWrite(PCNET_CSR_BADTU, pcnet.tx_buf_addr >> 16);

/*  AMD PCNet datasheet p. 1-967
    Dft value at hardware init is
    all 0. Standard init block process
    sets this, but if doing directly
    it is imperative to manually set it 0. */
PCNetCSRWrite(PCNET_CSR_POLLINT, 0);

/*  AMD PCNet datasheet p. 1-970
    Receive and Transmit Ring Length CSRs
    bits 0-15 need to be set as the 2s complement
    of the ring length. The AND with 0xFFFF clears
    the upper Reserved bits, which are to be written
    as zeroes read undefined. */
PCNetCSRWrite(PCNET_CSR_RXRINGLEN, -PCNET_RX_BUFF_CNT & 0xFFFF);
PCNetCSRWrite(PCNET_CSR_TXRINGLEN, -PCNET_TX_BUFF_CNT & 0xFFFF);
}
*/

U8 *PCNetInitBlockSetup()
{
  U8                    *setup   = CAllocAligned(sizeof(CPCNetBufSetup), 16, sys_dma_heap);
  CPCNetBufSetup *u_setup = setup;
  u_setup->rlen     = Bsf(PCNET_RX_BUFF_CNT);
  u_setup->tlen     = Bsf(PCNET_TX_BUFF_CNT);
  MemCpy(u_setup->mac, pcnet.mac_addr, 6);
  u_setup->rxbuf        = pcnet.rx_de_buf;
  u_setup->txbuf        = pcnet.tx_de_buf;
  PCNetCSRWrite(1, setup & 0xFFFF);
  PCNetCSRWrite(2, setup >> 16);
  return setup;
}

U0 PCNetInterruptCSRSet()
{
  /* AMD PCNet datasheet p.1-952, 1-953, 1-954, 1-955, 1-956, 1-957
  Refer to datasheet for specifics on the Interrupt Masks.
  Most of these, when set 0, allow interrupts to be set in CSR0.
  We set Big-Endian disabled, RX interrupts
  enabled, Init Done interrupt disabled, and TX interrupt
  disabled. */
  U32 csr = PCNetCSRRead(PCNET_CSR_INTERRUPTS);
  Btr(&csr, PCNET_INT_BSWP);
  Btr(&csr, PCNET_INT_RINTM);
  Bts(&csr, PCNET_INT_IDONM);
  Bts(&csr, PCNET_INT_TINTM);
  PCNetCSRWrite(PCNET_CSR_INTERRUPTS, csr);
}

U0 PCNetTXAutoPadEnable()
{
  /* AMD PCNet datasheet p.1-958
  Setting bit 11 (Auto Pad Transmit) allows
  shoft transmit frames to be automatically
  extended to 64 bytes. */
  U32 csr = PCNetCSRRead(PCNET_CSR_FEATURECTRL);
  Bts(&csr, PCNET_FEATURE_APADXMT);
  PCNetCSRWrite(PCNET_CSR_FEATURECTRL, csr);
}

U0 PCNetCfgModeExit()
{
  /* AMD PCNet datasheet p.1-954
  PCNet controller can be started
  after configuring by ensuring INIT
  and STOP are cleared and START bit
  is set, in Status and Control Register
  (CSR0). */
  U32 csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  Btr(&csr, PCNET_CTRL_INIT);
  Btr(&csr, PCNET_CTRL_STOP);
  Bts(&csr, PCNET_CTRL_IENA);
  Bts(&csr, PCNET_CTRL_STRT);
  PCNetCSRWrite(PCNET_CSR_CTRLSTATUS, csr);
}

U0 PCNetUploadCfg()
{
  /* Upload new config and wait for card to acknowlege */
  U32 csr = 0;
  Bts(&csr, PCNET_CTRL_INIT);
  PCNetCSRWrite(PCNET_CSR_CTRLSTATUS, csr);
  Btr(&csr, PCNET_CTRL_IDON);
  while (!Bt(&csr, PCNET_CTRL_IDON))
  {
    Yield;
    csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  }
}


I64 PCNetDriverOwns(CPCNetDescEnt* ent)
{
  /* Returns whether the value of the OWN bit of the
  Descriptor Entry is zero. If 0, driver owns,
  if 1, PCNet card owns it. */
  return !PCIBt(&ent->status1, PCNET_DESCRIPTORf_OWN);
}

I64 PCNetTxPktAlloc(U8 **pkt_buf_out, I64 len)
{
  /* Transmits the packet at the current TX DE index. The packet_buffer_out
  is a pointer, since we modify its value, ending with returning the
  index of the DE we just processed. Length is validated to fit in BCNT.
  The increment of the current TX DE index is done by assigning it the
  value of incrementing it AND the max DE index-1. This will increment it
  as well as wrap back to 0 if we hit the max DE index. */
  U16 buf_byte_cnt;
  I64 de_index = pcnet.current_tx_de_index;
  if (len > 0xFFF)
  {
    NetErr("PCNET ALLOCATE TX PACKET: Invalid TX Packet Length");
    throw('PCNet');
  }
  CPCNetDescEnt *ent = &pcnet.tx_de_buf[de_index * sizeof(CPCNetDescEnt)];
  if (!PCNetDriverOwns(ent))
  {
    NetErr("PCNET ALLOCATE TX PACKET: TX FIFO Full");
    return -1;
  }
  else
  {
    NetLog("PCNET ALLOCATE TX PACKET: Driver owns TX DE at index %d.", de_index);
  }
  PCIBts(&ent->status1, PCNET_DESCRIPTORf_STP);
  PCIBts(&ent->status1, PCNET_DESCRIPTORf_ENP);
  /*    AMD PCNet datasheet p.1-991.
    BCNT is the usable buffer length, expressed as first
    12 bits of 2s-complement of desired length.
    Bits 0-11 of a DE are for the buffer byte cnt (BCNT),
    and bits 12-15 of a DE must be written all ones (ONES) */
  buf_byte_cnt = -len;
  buf_byte_cnt &= 0x0FFF;
  ent->status1 &= 0xFFFFF000;
  ent->status1 |= buf_byte_cnt;
  ent->status1 |= 0xF000;
  pcnet.current_tx_de_index = (pcnet.current_tx_de_index + 1) & (PCNET_TX_BUFF_CNT - 1);
  *pkt_buf_out = pcnet.tx_buf_addr + de_index * ETH_FRAME_SIZE;
  NetLog("PCNET ALLOCATE TX PACKET: de_index: %X.", de_index);
  return de_index;
}

U0 PCNetTxPktFinish(I64 de_index)
{
  /* Release ownership of the packet to the PCNet card
  by setting the OWN bit to 1. */
  CPCNetDescEnt *ent = &pcnet.tx_de_buf[de_index * sizeof(CPCNetDescEnt)];
  PCIBts(&ent->status1, PCNET_DESCRIPTORf_OWN);
  NetLog("PCNET FINISH TX PACKET: TX DE index: %X, OWN bit of entry at entry: %b.",
         de_index, PCIBt(&ent->status1, PCNET_DESCRIPTORf_OWN));
}

U0 EthFrameFinish(I64 de_index)
{//Alias for driver Finish TX function.
  PCNetTxPktFinish(de_index);
}

I64 PCNetPktRx(U8 **pkt_buf_out, U16 *pkt_len_out)
{
  /* Receives the packet at the current RX DE index. Parameters
  are both pointers, since we modify the value at the packet_buffer_out,
  and at the packet_length, ending with returning the index of the DE
  we just processed.
  The MCNT is stored at the first two bytes of the RMD2. We AND with
  0xFFFF to only take in those first two bytes: that is the packet_length.
  The increment of the current RX DE index is done by assigning it the
  value of incrementing it AND the max DE index-1. This will increment it
  as well as wrap back to 0 if we hit the max DE index. */
  I64 de_index = pcnet.current_rx_de_index;
  U16 pkt_len;
  NetLog("PCNET RECEIVE PACKET: Output buffer ptr, output length ptr: %X, %X ", pkt_buf_out, pkt_len_out);
  CPCNetDescEnt *ent = &pcnet.rx_de_buf[de_index * sizeof(CPCNetDescEnt)];
  pkt_len = ent->status2 & 0xFFFF;
  NetDbg("PCNET RECEIVE PACKET: de_index = 0x%0X", de_index);
  pcnet.current_rx_de_index = (pcnet.current_rx_de_index + 1) & (PCNET_RX_BUFF_CNT - 1);
  NetDbg("PCNET RECEIVE PACKET: de_index incremented = 0x%0X", pcnet.current_rx_de_index);
  *pkt_buf_out = pcnet.rx_buf_addr + de_index * ETH_FRAME_SIZE;
  if (pkt_len >= FCS_LEN)
    pkt_len -= FCS_LEN;
  *pkt_len_out = pkt_len;
  return de_index;
}

U0 PCNetRxPktRelease(I64 de_index)
{
  /* Release ownership of the packet to the PCNet card
  by setting the OWN bit to 1. */
  CPCNetDescEnt *ent = &pcnet.rx_de_buf[de_index * sizeof(CPCNetDescEnt)];
  PCIBts(&ent->status1, PCNET_DESCRIPTORf_OWN);
}

interrupt U0 PCNetIRQ()
{// todo: comments explaining process...maybe reimplement interrupt handling altogether.
  U8 *pkt_buf;
  U16 pkt_len;
  I64 de_index;
  U32 csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  CPCNetDescEnt *ent = pcnet.rx_de_buf;
  while (PCNetDriverOwns(&ent[pcnet.current_rx_de_index]))
  {
    if (PCNET_DEBUG_OUTPUT)
    {
      NetLog("$$BG,LTCYAN$$$$FG,WHITE$$"
             "==== PCNET IRQ ===="
             "$$BG$$$$FG$$");
      NetLog("$$BD,CYAN$$$$FD,WHITE$$"
             "PCNET IRQ: Saw owned RX DE index %d.", pcnet.current_rx_de_index);
    }
    de_index = PCNetPktRx(&pkt_buf, &pkt_len);
    if (de_index >= 0)
    {
      if (PCNET_DEBUG_OUTPUT)
      {
        NetLog("PCNET IRQ: Pushing copy into Net Que, releasing receive packet.");
      }
      NetQuePush(pkt_buf, pkt_len);
      PCNetRxPktRelease(de_index);
    }
    Bts(&csr, PCNET_CTRL_RINT);
    PCNetCSRWrite(PCNET_CSR_CTRLSTATUS, csr);
    if (PCNET_DEBUG_OUTPUT)
    {
      NetLog("PCNET IRQ: Exiting.\n"
             "$$BD,WHITE$$$$FD,LTGRAY$$"
             "$$BG,LTCYAN$$$$FG,WHITE$$"
             "==================="
             "$$BG$$$$FG$$");
    }
  }
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

U0 PCNetInterruptsSetup()
{// todo: comments explaining process
  I64 i;
  for (i = 0; i < 4; i++)
    IntEntrySet(0x40+i, &PCNetIRQ);
  PciRerouteInterrupts(0x40);
}

U0 PCNetInit()
{
  U8 *setup;
  ZeroClass(&pcnet);
  pcnet.pci = &net_driver_pci;
  if (!pcnet.pci)
    return;
  /*    Clear command register of PCNet
    PCI device, set IO Enable and Bus
    Master Enable bits of the register. */
  PCIWriteU16(pcnet.pci->bus,
              pcnet.pci->dev,
              pcnet.pci->fun,
              PCIR_COMMAND,
              PCNET_CMDF_IOEN | PCNET_CMDF_BMEN);
  PCNetRst;
  PCNet32BitModeEnable;
  U32 csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  NetLog("PCNET INIT START: what is INIT ?: %d", Bt(&csr, PCNET_CTRL_INIT));
  NetLog("PCNET INIT START: what is STRT ?: %d", Bt(&csr, PCNET_CTRL_STRT));
  NetLog("PCNET INIT START: what is STOP ?: %d", Bt(&csr, PCNET_CTRL_STOP));
  NetLog("PCNET INIT START: what is RINT ?: %d", Bt(&csr, PCNET_CTRL_RINT));
  PCNetSWStyleSet;
  PCNetMACGet;
  PCNetBufsAlloc;
  setup = PCNetInitBlockSetup();
  PCNetInterruptCSRSet;
  PCNetTXAutoPadEnable;
  U32 bcr2=PCNetBCRRead(2);
  bcr2 |= 2;
  PCNetBCRWrite(2,bcr2);
  bcr2 = PCNetBCRRead(9) & ~3;
  bcr2 |= 3;
  PCNetBCRWrite(9,bcr2);
  /*
    PCNetCSRWrite(32,PCNetCSRRead(32)|0x0080);
    bcr2=PCNetCSRRead(32) & ~0x98;
    bcr2 |= 0x20;
    PCNetCSRWrite(32,bcr2);
  */
  PCNetUploadCfg;
  csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  NetLog("PCNET INIT UPLOAD: what is INIT ?: %d", Bt(&csr, PCNET_CTRL_INIT));
  NetLog("PCNET INIT UPLOAD: what is STRT ?: %d", Bt(&csr, PCNET_CTRL_STRT));
  NetLog("PCNET INIT UPLOAD: what is STOP ?: %d", Bt(&csr, PCNET_CTRL_STOP));
  NetLog("PCNET INIT UPLOAD: what is RINT ?: %d", Bt(&csr, PCNET_CTRL_RINT));
  PCNetCfgModeExit;
  Sleep(100);
  csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  NetLog("PCNET INIT END: what is INIT ?: %d", Bt(&csr, PCNET_CTRL_INIT));
  NetLog("PCNET INIT END: what is STRT ?: %d", Bt(&csr, PCNET_CTRL_STRT));
  NetLog("PCNET INIT END: what is STOP ?: %d", Bt(&csr, PCNET_CTRL_STOP));
  NetLog("PCNET INIT END: what is RINT ?: %d", Bt(&csr, PCNET_CTRL_RINT));
  NetLog("PCNET INIT END: what is TXON ?: %d", Bt(&csr, 4));
  NetLog("PCNET INIT END: what is RXON ?: %d", Bt(&csr, 5));
  csr =  PCNetCSRRead(PCNET_CSR_POLLINT);
  NetLog("PCNET INIT END: what is POLLINT ?: %d", Bt(&csr, PCNET_CTRL_RINT));
  NetLog("PCNET INIT END: Redirecting interrupts.");
  PCNetInterruptsSetup;
  Free(setup);
}

I64 EthFrameAlloc(U8 **pkt_buf_out,
                          U8 *src_addr,
                          U8 *dst_addr,
                          U16 ethertype,
                          I64 pkt_len)
{
  /* Allocate an Ethernet Frame for transmit. The source
  and destination addresses are copied to the Frame,
  as well as the ethertype. The packet_buffer_out
  parameter has the value at its pointer set to the
  payload of the Ethernet Frame. */
  U8 *eth_frame;
  I64 de_index;
  if (pkt_len < ETH_MIN_FRAME_SIZE)
  {
    NetWarn("ETHERNET FRAME ALLOCATE: PCNET APAD XMT TRUNCATE ? ...");
    pkt_len = ETH_MIN_FRAME_SIZE;
  }
  de_index = PCNetTxPktAlloc(&eth_frame, ETH_MAC_HDR_LEN + pkt_len);
  if (de_index < 0)
  {
    NetErr("ETHERNET FRAME ALLOCATE: Failure");
    return -1;
  }
  MemSet(eth_frame, 0, ETH_FRAME_SIZE);
  *pkt_buf_out = EthHdrSet(eth_frame, src_addr,
        dst_addr, ethertype);
  return de_index;
}

U8 *EthMACGet()
{
  return pcnet.mac_addr;
}

U0 NetStop()
{// Halt network activity by setting STOP bit on Status CSR.
  U32 csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  Bts(&csr, PCNET_CTRL_STOP);
  PCNetCSRWrite(PCNET_CSR_CTRLSTATUS, csr);
}

U0 NetStart()
{// Continue network activity. Setting START bit clears STOP/INIT.
  U32 csr = PCNetCSRRead(PCNET_CSR_CTRLSTATUS);
  Bts(&csr, PCNET_CTRL_STRT);
  PCNetCSRWrite(PCNET_CSR_CTRLSTATUS, csr);
}

PCNetInit;
