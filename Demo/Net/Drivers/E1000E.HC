#define PCID_E1000E_82579LM 0x1502
#define PCID_E1000E_I217LM  0x153A
#define PCID_E1000E_I217V   0x153B
#define PCID_E1000E_82574L  0x10D3

#define E1000E_CTRL       0x00000
#define E1000E_STATUS     0x00008
#define E1000E_STRAP      0x0000C
#define E1000E_CTRL_EXT   0x00018
#define E1000E_MDIC       0x00020
#define E1000E_FEXTNVM4   0x00024
#define E1000E_FEXTNVM    0x00028
#define E1000E_KMRNCTRLSTA 0x00034
#define E1000E_FEXTNVM3   0x0003C
#define E1000E_ICR        0x000C0
#define E1000E_IMC        0x000D8
#define E1000E_RCTL       0x00100
#define E1000E_TCTL       0x00400
#define E1000E_TIPG       0x00410
#define E1000E_LEDCTL     0x00E00
#define E1000E_EXTCNF_CTRL 0x00F00
#define E1000E_EXTCNF_SIZE 0x00F08
#define E1000E_PHY_CTRL   0x00F10
#define E1000E_RDBAL      0x02800
#define E1000E_RDBAH      0x02804
#define E1000E_RDLEN      0x02808
#define E1000E_RDH        0x02810
#define E1000E_RDT        0x02818
#define E1000E_KABGTXD    0x03004
#define E1000E_TDBAL      0x03800
#define E1000E_TDBAH      0x03804
#define E1000E_TDLEN      0x03808
#define E1000E_TDH        0x03810
#define E1000E_TDT        0x03818
#define E1000E_TXDCTL0    0x03828
#define E1000E_TXDCTL1    0x03928
#define E1000E_TARC0      0x03840
#define E1000E_TARC1      0x03940
#define E1000E_CRCERRS    0x04000
#define E1000E_RXERRC     0x0400C
#define E1000E_MPC        0x04010
#define E1000E_SCC        0x04014
#define E1000E_ECOL       0x04018
#define E1000E_MCC        0x0401C
#define E1000E_LATECOL    0x04020
#define E1000E_COLC       0x04028
#define E1000E_DC         0x04030
#define E1000E_TNCRS      0x04034
#define E1000E_SEC        0x04038
#define E1000E_RLEC       0x04040
#define E1000E_GPRC       0x04074
#define E1000E_BPRC       0x04078
#define E1000E_GPTC       0x04080
#define E1000E_RNBC       0x040A0
#define E1000E_MGTPRC     0x040B4
#define E1000E_MGTPDC     0x040B8
#define E1000E_MGTPTC     0x040BC
#define E1000E_TPR        0x040D0
#define E1000E_TPT        0x040D4
#define E1000E_BPTC       0x040F4
#define E1000E_RFCTL      0x05008
#define E1000E_MTA        0x05200
#define E1000E_RAL0       0x05400
#define E1000E_RAH0       0x05404
#define E1000E_FWSM       0x05B54
#define E1000E_FFLT_DBG   0x05F04

#define E1000E_CTRL_FD            0x00000001
#define E1000E_CTRL_GIO_MASTER_DISABLE 0x00000004
#define E1000E_CTRL_SLU           0x00000040
#define E1000E_CTRL_FRCSPD        0x00000800
#define E1000E_CTRL_FRCDPX        0x00001000
#define E1000E_CTRL_LANPHYPC_OVERRIDE 0x00010000
#define E1000E_CTRL_LANPHYPC_VALUE 0x00020000
#define E1000E_CTRL_RST           0x04000000
#define E1000E_CTRL_PHY_RST       0x80000000
#define E1000E_STATUS_FD          0x00000001
#define E1000E_STATUS_LU          0x00000002
#define E1000E_STATUS_SPEED_100   0x00000040
#define E1000E_STATUS_SPEED_1000  0x00000080
#define E1000E_STATUS_LAN_INIT_DONE 0x00000200
#define E1000E_STATUS_PHYRA       0x00000400
#define E1000E_STATUS_GIO_MASTER_ENABLE 0x00080000
#define E1000E_CTRL_EXT_RO_DIS    0x00020000
#define E1000E_CTRL_EXT_PHYPDEN   0x00100000
#define E1000E_CTRL_EXT_DRV_LOAD  0x10000000
#define E1000E_CTRL_EXT_LPCD      0x00000004
#define E1000E_CTRL_EXT_FORCE_SMBUS 0x00000800
#define E1000E_CTRL_MEHE          0x00080000
#define E1000E_PBECCSTS           0x0100C
#define E1000E_PBECCSTS_ECC_ENABLE 0x00010000
#define E1000E_RCTL_EN            0x00000002
#define E1000E_RCTL_BAM           0x00008000
#define E1000E_RCTL_SECRC         0x04000000
#define E1000E_TCTL_EN            0x00000002
#define E1000E_TCTL_PSP           0x00000008
#define E1000E_TCTL_RTLC          0x01000000
#define E1000E_TCTL_MULR          0x10000000
#define E1000E_TCTL_CT            0x00000FF0
#define E1000E_TCTL_COLD          0x003FF000
#define E1000E_TIPG_IPGT_MASK     0x000003FF
#define E1000E_TXDCTL_WTHRESH     0x003F0000
#define E1000E_TXDCTL_PTHRESH     0x0000003F
#define E1000E_TXDCTL_FULL_TX_DESC_WB 0x01010000
#define E1000E_TXDCTL_MAX_TX_DESC_PREFETCH 0x0100001F
#define E1000E_RFCTL_NFSW_DIS     0x00000040
#define E1000E_RFCTL_NFSR_DIS     0x00000080
#define E1000E_KABGTXD_BGSQLBIAS  0x00050000
#define E1000E_RAH_AV             0x80000000
#define E1000E_FEXTNVM_SW_CONFIG_ICH8M (1 << 27)
#define E1000E_FEXTNVM3_PHY_CFG_COUNTER_MASK  0x0C000000
#define E1000E_FEXTNVM3_PHY_CFG_COUNTER_50MSEC 0x08000000
#define E1000E_FEXTNVM4_BEACON_DURATION_MASK  0x7
#define E1000E_FEXTNVM4_BEACON_DURATION_16USEC 0x3
#define E1000E_FEXTNVM4_BEACON_DURATION_8USEC  0x7
#define E1000E_FWSM_RSPCIPHY      0x00000040
#define E1000E_FWSM_FW_VALID      0x00008000
#define E1000E_PHY_CTRL_D0A_LPLU  0x00000002
#define E1000E_PHY_CTRL_GBE_DISABLE 0x00000040
#define E1000E_STRAP_SMBUS_ADDR_MASK  0x00FE0000
#define E1000E_STRAP_SMBUS_ADDR_SHIFT 17

#define E1000E_KMRN_CTRL_OFFSET   0x1
#define E1000E_KMRN_TIMEOUTS      0x4
#define E1000E_KMRN_INBAND_PARAM  0x9
#define E1000E_KMRN_HD_CTRL       0x10

#define MII_BMCR                  0
#define MII_BMSR                  1
#define MII_PHYSID1               2
#define MII_PHYSID2               3
#define MII_ADVERTISE             4
#define MII_CTRL1000              9
#define BMCR_ANRESTART            0x0200
#define BMCR_ANENABLE             0x1000
#define ADVERTISE_10HALF          0x0020
#define ADVERTISE_10FULL          0x0040
#define ADVERTISE_100HALF         0x0080
#define ADVERTISE_100FULL         0x0100
#define ADVERTISE_PAUSE_CAP       0x0400
#define ADVERTISE_PAUSE_ASYM      0x0800
#define ADVERTISE_1000HALF        0x0100
#define ADVERTISE_1000FULL        0x0200
#define E1000E_PHY_PAGE_SELECT    0x1F
#define HV_INTC_FC_PAGE_START     768
#define I82577_ADDR_REG           16
#define I82577_CFG_REG            22
#define I82577_CFG_ASSERT_CRS_ON_TX 0x8000
#define I82577_CFG_ENABLE_DOWNSHIFT 0x0C00
#define I82577_PHY_CTRL_2         18
#define I82577_PHY_CTRL2_MDIX_CFG_MASK 0x0600
#define I82577_PHY_CTRL2_AUTO_MDI_MDIX 0x0400
#define HV_M_STATUS               26
#define HV_M_STATUS_LINK_UP       0x0040
#define HV_M_STATUS_SPEED_100     0x0100
#define HV_M_STATUS_SPEED_1000    0x0200
#define HV_M_STATUS_AUTONEG_COMPLETE 0x1000
#define HV_OEM_BITS               (768 << 5 | 25)
#define HV_OEM_BITS_LPLU          0x0004
#define HV_OEM_BITS_GBE_DIS       0x0040
#define HV_OEM_BITS_RESTART_AN    0x0400
#define HV_SMB_ADDR               (768 << 5 | 26)
#define HV_SMB_ADDR_MASK          0x007F
#define HV_SMB_ADDR_VALID         0x0080
#define HV_SMB_ADDR_PEC_EN        0x0200
#define HV_LED_CONFIG             (768 << 5 | 30)
#define HV_KMRN_MODE_CTRL         (769 << 5 | 16)
#define HV_KMRN_MDIO_SLOW         0x0400
#define BM_PORT_GEN_CFG           (769 << 5 | 17)
#define BM_WUC_HOST_WU_BIT        0x0010
#define HV_KMRN_FIFO_CTRLSTA      (770 << 5 | 16)
#define HV_KMRN_FIFO_CTRLSTA_PREAMBLE_MASK 0x7000
#define HV_KMRN_FIFO_CTRLSTA_PREAMBLE_SHIFT 12
#define HV_PM_CTRL                (770 << 5 | 17)
#define HV_PM_CTRL_K1_ENABLE      0x4000
#define I82579_EMI_ADDR           0x10
#define I82579_EMI_DATA           0x11
#define I82579_MSE_THRESHOLD      0x084F
#define I82579_MSE_LINK_DOWN      0x2411
#define I82579_RX_CONFIG          0x3412
#define I82579_LPI_UPDATE_TIMER   0x4805
#define HV_PM_CTRL_K1_CLK_REQ     0x0200
#define I217_RX_CONFIG            0xB20C
#define I217_PLL_CLOCK_GATE_REG   (772 << 5 | 28)
#define I217_PLL_CLOCK_GATE_MASK  0x07FF
#define CV_SMB_CTRL               (769 << 5 | 23)
#define CV_SMB_CTRL_FORCE_SMBUS   0x0001

#define ICH_FLASH_GFPREG          0x0000
#define ICH_FLASH_HSFSTS          0x0004
#define ICH_FLASH_HSFCTL          0x0006
#define ICH_FLASH_FADDR           0x0008
#define ICH_FLASH_FDATA0          0x0010
#define ICH_FLASH_LINEAR_ADDR_MASK 0x00FFFFFF
#define ICH_FLASH_CYCLE_REPEAT_CNT 10
#define ICH_CYCLE_READ            0
#define ICH_NVM_SIG_WORD          0x13
#define ICH_NVM_VALID_SIG_MASK    0xC0
#define ICH_NVM_SIG_VALUE         0x80
#define ICH_NVM_ALT_MAC_ADDR_PTR  0x37

#define E1000E_RX_CNT 32
#define E1000E_TX_CNT 8

class CE1000EMdic
{
  union
  {
    U32 raw;
    U32 data:16;
    U32 regadd:5;
    U32 phyadd:5;
    U32 op:2;
    U32 ready:1;
    U32 ie:1;
    U32 error:1;
  }
};
#define E1000E_MDIC_OP_WRITE 1
#define E1000E_MDIC_OP_READ  2

class CE1000EKmrn
{
  union
  {
    U32 raw;
    U32 data:16;
    U32 offset:5;
    U32 ren:1;
  }
};

class CIchFlashStatus
{
  union
  {
    U16 raw;
    U16 flcdone:1;
    U16 flcerr:1;
    U16 dael:1;
    U16 berasesz:2;
    U16 flcinprog:1;
    U16 reserved:8;
    U16 fldesvalid:1;
    U16 flockdn:1;
  }
};

class CIchFlashCtrl
{
  union
  {
    U16 raw;
    U16 flcgo:1;
    U16 flcycle:2;
    U16 reserved:5;
    U16 fldbcount:2;
    U16 reserved2:6;
  }
};

class CE1000ERxDesc
{
  U64 addr;
  U16 len;
  U16 checksum;
  union
  {
    U8 status;
    U8 dd:1;
    U8 eop:1;
    U8 status_rest:6;
  }
  U8 errors;
  U16 special;
};

class CE1000ETxDesc
{
  U64 addr;
  U16 len;
  U8 cso;
  union
  {
    U8 cmd;
    U8 eop:1;
    U8 ifcs:1;
    U8 ic:1;
    U8 rs:1;
    U8 cmd_rest:4;
  }
  union
  {
    U8 status;
    U8 dd:1;
    U8 ec:1;
    U8 lc:1;
    U8 tu:1;
    U8 status_rest:4;
  }
  U8 css;
  U16 special;
};

class CE1000E
{
  CPciDevInfo *pci;
  U8 *mmio, *flash;
  Bool pch,
        pch2,
        lpt;
  Bool link_up, running;
  U8 mac[6];
  I64 flash_base, bank_words;
  CE1000ERxDesc *rx;
  CE1000ETxDesc *tx;
  U8 *rx_bufs, *tx_bufs;
  I64 rx_next, tx_next, tx_len[E1000E_TX_CNT];
  I64 rx_frames, tx_frames, tx_errors;
  Bool mac_ok;
  U8 *mac_src;
  I64 link_status;
} e1000e;

U32 E1000ERead(I64 r)
{
  return *(e1000e.mmio + r)(U32 *);
}

U0 E1000EWrite(I64 r, U32 val)
{
  *(e1000e.mmio + r)(U32 *) = val;
}

U0 E1000EFlush()
{//A read pushes posted writes out to the device (Linux e1e_flush).
  E1000ERead(E1000E_STATUS);
}

Bool E1000EFwValid()
{//Management (ME) firmware is active on the LM part.
  return ToBool(E1000ERead(E1000E_FWSM) & E1000E_FWSM_FW_VALID);
}


#define E1000E_EXTCNF_CTRL_LCD_WRITE_ENABLE 0x00000001
#define E1000E_EXTCNF_CTRL_SWFLAG   0x00000020
#define E1000E_EXTCNF_CTRL_GATE_PHY_CFG 0x00000080

Bool E1000EAcquire()
{//PHY and some MAC registers are shared with the ME firmware.
  I64 t;
  U32 ctrl;
  if (!e1000e.pch)
    return TRUE;
  for (t = 0; t < 100 && E1000ERead(E1000E_EXTCNF_CTRL) & E1000E_EXTCNF_CTRL_SWFLAG; t++)
    Sleep(1);
  if (t == 100)
    return FALSE;
  ctrl = E1000ERead(E1000E_EXTCNF_CTRL) | E1000E_EXTCNF_CTRL_SWFLAG;
  E1000EWrite(E1000E_EXTCNF_CTRL, ctrl);
  for (t = 0; t < 1000; t++)
  {
    if (E1000ERead(E1000E_EXTCNF_CTRL) & E1000E_EXTCNF_CTRL_SWFLAG)
      return TRUE;
    Sleep(1);
  }
  E1000EWrite(E1000E_EXTCNF_CTRL, ctrl & ~E1000E_EXTCNF_CTRL_SWFLAG);
  return FALSE;
}

U0 E1000ERelease()
{
  if (e1000e.pch)
    E1000EWrite(E1000E_EXTCNF_CTRL,
          E1000ERead(E1000E_EXTCNF_CTRL) & ~E1000E_EXTCNF_CTRL_SWFLAG);
}

Bool E1000EResetBlocked()
{//e1000_check_reset_block_ich8lan: the ME may forbid PHY resets.
  I64 i;
  if (!e1000e.pch)
    return FALSE;
  for (i = 0; i < 30; i++)
  {
    if (E1000ERead(E1000E_FWSM) & E1000E_FWSM_RSPCIPHY)
      return FALSE;
    Sleep(10);
  }
  return TRUE;
}

U0 E1000EGatePhyConfig(Bool gate)
{//e1000_gate_hw_phy_config_ich8lan: hardware vs software PHY configuration.
  U32 ctrl;
  if (!e1000e.pch)
    return;
  ctrl = E1000ERead(E1000E_EXTCNF_CTRL);
  if (gate)
    ctrl |= E1000E_EXTCNF_CTRL_GATE_PHY_CFG;
  else
    ctrl &= ~E1000E_EXTCNF_CTRL_GATE_PHY_CFG;
  E1000EWrite(E1000E_EXTCNF_CTRL, ctrl);
}


I64 E1000EMdicIo(I64 phy_addr, I64 reg_num, Bool write, I64 data = 0)
{//e1000e_read/write_phy_reg_mdic. Returns the data, or -1.
  CE1000EMdic mdic;
  I64 i;
  mdic.raw = 0;
  mdic.data = data;
  mdic.regadd = reg_num;
  mdic.phyadd = phy_addr;
  if (write)
    mdic.op = E1000E_MDIC_OP_WRITE;
  else
    mdic.op = E1000E_MDIC_OP_READ;
  E1000EWrite(E1000E_MDIC, mdic.raw);
  for (i = 0; i < 640 * 3; i++)
  {
    Busy(50);
    mdic.raw = E1000ERead(E1000E_MDIC);
    if (mdic.ready)
      break;
  }
  if (e1000e.pch2)
    Busy(100);
  if (!mdic.ready || mdic.error || mdic.regadd != reg_num)
    return -1;
  return mdic.data;
}

I64 E1000EPhyReg(I64 page, I64 r)
{//A PHY register on a page, as Linux's PHY_REG(page, reg) encodes it.
  return page << 5 | r;
}

I64 E1000EPhyIo(I64 offset, Bool write, I64 data = 0)
{//__e1000_read/write_phy_reg_hv: offset is E1000EPhyReg(page, r).
  I64 page = offset >> 5, reg_num = offset & 0x1F, addr = 2;
  if (!e1000e.pch)
    return E1000EMdicIo(1, reg_num, write, data);
  if (page == 800)
    return -1;
  if (0 < page < HV_INTC_FC_PAGE_START)
  {
    if (E1000EMdicIo(2, I82577_ADDR_REG, TRUE, offset & 0x3F) < 0)
      return -1;
    return E1000EMdicIo(2, I82577_ADDR_REG + 1, write, data);
  }
  if (page >= HV_INTC_FC_PAGE_START)
    addr = 1;
  if (page == HV_INTC_FC_PAGE_START)
    page = 0;
  if (reg_num > 0xF && E1000EMdicIo(1, E1000E_PHY_PAGE_SELECT, TRUE, page << 5) < 0)
    return -1;
  return E1000EMdicIo(addr, reg_num, write, data);
}

I64 E1000EPhyRead(I64 offset)
{
  return E1000EPhyIo(offset, FALSE);
}

Bool E1000EPhyWrite(I64 offset, I64 data)
{
  return E1000EPhyIo(offset, TRUE, data) >= 0;
}

Bool E1000EPhyModify(I64 offset, I64 clear, I64 set)
{//Read, clear bits, set bits, write.
  I64 v = E1000EPhyRead(offset);
  if (v < 0)
    return FALSE;
  return E1000EPhyWrite(offset, v & ~clear | set);
}

Bool E1000EEmiWrite(I64 addr, I64 data)
{//e1000_write_emi_reg_locked: Extended Management Interface registers.
  return E1000EPhyWrite(I82579_EMI_ADDR, addr) && E1000EPhyWrite(I82579_EMI_DATA, data);
}

I64 E1000EKmrnRead(I64 offset)
{//__e1000_read_kmrn_reg
  CE1000EKmrn k;
  k.raw = 0;
  k.offset = offset;
  k.ren = 1;
  E1000EWrite(E1000E_KMRNCTRLSTA, k.raw);
  E1000EFlush;
  Busy(2);
  k.raw = E1000ERead(E1000E_KMRNCTRLSTA);
  return k.data;
}

U0 E1000EKmrnWrite(I64 offset, I64 data)
{//__e1000_write_kmrn_reg
  CE1000EKmrn k;
  k.raw = 0;
  k.offset = offset;
  k.data = data;
  E1000EWrite(E1000E_KMRNCTRLSTA, k.raw);
  E1000EFlush;
  Busy(2);
}


U16 E1000EFlashRead16(I64 r)
{
  return *(e1000e.flash + r)(U16 *);
}

U0 E1000EFlashWrite16(I64 r, U16 val)
{
  *(e1000e.flash + r)(U16 *) = val;
}

Bool E1000EFlashCycleInit()
{//e1000_flash_cycle_init_ich8lan
  CIchFlashStatus st;
  I64 i;
  st.raw = E1000EFlashRead16(ICH_FLASH_HSFSTS);
  if (!st.fldesvalid)
    return FALSE;
  st.flcerr = 1;
  st.dael = 1;
  E1000EFlashWrite16(ICH_FLASH_HSFSTS, st.raw);
  for (i = 0; st.flcinprog && i < 10000; i++)
  {
    Busy(1);
    st.raw = E1000EFlashRead16(ICH_FLASH_HSFSTS);
  }
  if (st.flcinprog)
    return FALSE;
  st.flcdone = 1;
  E1000EFlashWrite16(ICH_FLASH_HSFSTS, st.raw);
  return TRUE;
}

I64 E1000EFlashReadData(I64 byte_offset, I64 size)
{//e1000_read_flash_data_ich8lan: a byte or word, or -1.
  CIchFlashStatus st;
  CIchFlashCtrl ctl;
  U32 data;
  I64 i, cnt;
  for (cnt = 0; cnt < ICH_FLASH_CYCLE_REPEAT_CNT; cnt++)
  {
    Busy(1);
    if (!E1000EFlashCycleInit)
      return -1;
    ctl.raw = E1000EFlashRead16(ICH_FLASH_HSFCTL);
    ctl.fldbcount = size - 1;
    ctl.flcycle = ICH_CYCLE_READ;
    E1000EFlashWrite16(ICH_FLASH_HSFCTL, ctl.raw);
    *(e1000e.flash + ICH_FLASH_FADDR)(U32 *) =
          (byte_offset & ICH_FLASH_LINEAR_ADDR_MASK) + e1000e.flash_base;
    ctl.raw = E1000EFlashRead16(ICH_FLASH_HSFCTL);
    ctl.flcgo = 1;
    E1000EFlashWrite16(ICH_FLASH_HSFCTL, ctl.raw);
    for (i = 0; i < 100000; i++)
    {
      st.raw = E1000EFlashRead16(ICH_FLASH_HSFSTS);
      if (st.flcdone)
        break;
      Busy(1);
    }
    if (st.flcdone && !st.flcerr)
    {
      data = *(e1000e.flash + ICH_FLASH_FDATA0)(U32 *);
      if (size == 1)
        return data & 0xFF;
      return data & 0xFFFF;
    }
    if (!st.flcerr)
      return -1;
  }
  return -1;
}

Bool E1000ENvmInit()
{//e1000_init_nvm_params_ich8lan: where the GbE region sits in flash.
  U32 gfpreg;
  I64 base, end;
  if (!e1000e.flash)
    return FALSE;
  gfpreg = *(e1000e.flash + ICH_FLASH_GFPREG)(U32 *);
  base = gfpreg & 0x1FFF;
  end = (gfpreg >> 16 & 0x1FFF) + 1;
  e1000e.flash_base = base << 12;
  e1000e.bank_words = (end - base) << 12 / 2 / 2;
  return TRUE;
}

I64 E1000ENvmRead(I64 word)
{//e1000_read_nvm_ich8lan: reads from the valid NVM bank.
  I64 bank = 0, sig = E1000EFlashReadData(ICH_NVM_SIG_WORD * 2 + 1, 1);
  if (sig < 0 || sig & ICH_NVM_VALID_SIG_MASK != ICH_NVM_SIG_VALUE)
  {
    sig = E1000EFlashReadData(ICH_NVM_SIG_WORD * 2 + 1 + e1000e.bank_words * 2, 1);
    if (sig >= 0 && sig & ICH_NVM_VALID_SIG_MASK == ICH_NVM_SIG_VALUE)
      bank = 1;
  }
  return E1000EFlashReadData((bank * e1000e.bank_words + word) * 2, 2);
}

Bool E1000EMacValid(U8 *mac)
{//A station address is unicast and not all zeroes.
  I64 i, nonzero = 0;
  if (mac[0] & 1)
    return FALSE;
  for (i = 0; i < MAC_ADDR_LEN; i++)
  {
    if (mac[i])
      nonzero++;
  }
  return ToBool(nonzero);
}

Bool E1000ENvmMacAt(I64 base, U8 *mac_out)
{//Three NVM words, low byte first, into a six-byte address.
  I64 i, w;
  for (i = 0; i < 3; i++)
  {
    w = E1000ENvmRead(base + i);
    if (w < 0)
      return FALSE;
    mac_out[i * 2] = w & 0xFF;
    mac_out[i * 2 + 1] = w >> 8;
  }
  return E1000EMacValid(mac_out);
}

Bool E1000EMacFromNvm(U8 *mac_out)
{//e1000_read_mac_addr_ich8lan: the address from NVM words 0-2.
  U8 tmp[6];
  I64 alt;
  if (!E1000ENvmInit)
    return FALSE;
  alt = E1000ENvmRead(ICH_NVM_ALT_MAC_ADDR_PTR);
  if (alt > 0 && alt != 0xFFFF && E1000ENvmMacAt(alt, tmp))
  {
    MemCpy(mac_out, tmp, MAC_ADDR_LEN);
    return TRUE;
  }
  if (E1000ENvmMacAt(0, tmp))
  {
    MemCpy(mac_out, tmp, MAC_ADDR_LEN);
    return TRUE;
  }
  return FALSE;
}


Bool E1000EPhyAccessible()
{//e1000_phy_is_accessible_pchlan: the PHY answers with a valid ID.
  I64 i, id1, id2;
  for (i = 0; i < 2; i++)
  {
    id1 = E1000EPhyRead(MII_PHYSID1);
    id2 = E1000EPhyRead(MII_PHYSID2);
    if (id1 >= 0 && id1 != 0xFFFF && id2 >= 0 && id2 != 0xFFFF)
    {
      if (e1000e.lpt && !E1000EFwValid)
      {
        E1000EPhyModify(CV_SMB_CTRL, CV_SMB_CTRL_FORCE_SMBUS, 0);
        E1000EWrite(E1000E_CTRL_EXT, E1000ERead(E1000E_CTRL_EXT) &
              ~E1000E_CTRL_EXT_FORCE_SMBUS);
      }
      return TRUE;
    }
  }
  if (e1000e.lpt)
    return FALSE;
  if (E1000EPhyModify(HV_KMRN_MODE_CTRL, 0, HV_KMRN_MDIO_SLOW))
  {
    id1 = E1000EPhyRead(MII_PHYSID1);
    return id1 >= 0 && id1 != 0xFFFF;
  }
  return FALSE;
}

U0 E1000EToggleLanPhyPc()
{//e1000_toggle_lanphypc_pch_lpt: fully power-cycle the PHY.
  U32 r = E1000ERead(E1000E_FEXTNVM3);
  r = r & ~E1000E_FEXTNVM3_PHY_CFG_COUNTER_MASK | E1000E_FEXTNVM3_PHY_CFG_COUNTER_50MSEC;
  E1000EWrite(E1000E_FEXTNVM3, r);
  r = E1000ERead(E1000E_CTRL);
  r |= E1000E_CTRL_LANPHYPC_OVERRIDE;
  r &= ~E1000E_CTRL_LANPHYPC_VALUE;
  E1000EWrite(E1000E_CTRL, r);
  E1000EFlush;
  Busy(20);
  r &= ~E1000E_CTRL_LANPHYPC_OVERRIDE;
  E1000EWrite(E1000E_CTRL, r);
  E1000EFlush;
  if (e1000e.lpt)
  {
    for (r = 0; r < 20 && !(E1000ERead(E1000E_CTRL_EXT) & E1000E_CTRL_EXT_LPCD); r++)
      Sleep(5);
    Sleep(30);
  }
  else
    Sleep(50);
}

U0 E1000EGetCfgDone()
{//e1000_get_cfg_done_ich8lan, with e1000_lan_init_done_ich8lan.
  I64 i;
  Sleep(10);
  if (!e1000e.pch)
    return;
  for (i = 0; i < 1500 && !(E1000ERead(E1000E_STATUS) & E1000E_STATUS_LAN_INIT_DONE); i++)
    Busy(150);
  E1000EWrite(E1000E_STATUS, E1000ERead(E1000E_STATUS) & ~E1000E_STATUS_LAN_INIT_DONE);
  if (E1000ERead(E1000E_STATUS) & E1000E_STATUS_PHYRA)
    E1000EWrite(E1000E_STATUS, E1000ERead(E1000E_STATUS) & ~E1000E_STATUS_PHYRA);
}

Bool E1000ESwLcdConfig()
{//e1000_sw_lcd_config_ich8lan: load the PHY's extended config from NVM.
  U32 extcnf = E1000ERead(E1000E_EXTCNF_CTRL);
  I64 size = E1000ERead(E1000E_EXTCNF_SIZE) >> 16 & 0xFF,
        word = (extcnf >> 16 & 0xFFF) << 1, i, data, addr, phy_page = 0;
  if (!(E1000ERead(E1000E_FEXTNVM) & E1000E_FEXTNVM_SW_CONFIG_ICH8M) || !size)
    return TRUE;
  if (!E1000EPhyModify(HV_SMB_ADDR, HV_SMB_ADDR_MASK, (E1000ERead(E1000E_STRAP) &
        E1000E_STRAP_SMBUS_ADDR_MASK) >> E1000E_STRAP_SMBUS_ADDR_SHIFT |
        HV_SMB_ADDR_PEC_EN | HV_SMB_ADDR_VALID) ||
        !E1000EPhyWrite(HV_LED_CONFIG, E1000ERead(E1000E_LEDCTL) & 0xFFFF))
    return FALSE;
  if (!E1000ENvmInit)
    return FALSE;
  for (i = 0; i < size; i++)
  {
    data = E1000ENvmRead(word + i * 2);
    addr = E1000ENvmRead(word + i * 2 + 1);
    if (data < 0 || addr < 0)
      return FALSE;
    if (addr == E1000E_PHY_PAGE_SELECT)
      phy_page = data;
    else if (!E1000EPhyWrite(phy_page | addr & 0x1F, data))
      return FALSE;
  }
  return TRUE;
}

Bool E1000EOemBits()
{//e1000_oem_bits_config_ich8lan (D0): MAC PHY_CTRL link policy into the PHY.
  U32 phy_ctrl = E1000ERead(E1000E_PHY_CTRL);
  I64 set = 0;
  if (!(E1000ERead(E1000E_FEXTNVM) & E1000E_FEXTNVM_SW_CONFIG_ICH8M))
    return TRUE;
  if (phy_ctrl & E1000E_PHY_CTRL_GBE_DISABLE)
    set |= HV_OEM_BITS_GBE_DIS;
  if (phy_ctrl & E1000E_PHY_CTRL_D0A_LPLU)
    set |= HV_OEM_BITS_LPLU;
  if (!E1000EResetBlocked)
    set |= HV_OEM_BITS_RESTART_AN;
  return E1000EPhyModify(HV_OEM_BITS, HV_OEM_BITS_GBE_DIS | HV_OEM_BITS_LPLU, set);
}

Bool E1000EPostPhyReset()
{//e1000_post_phy_reset_ich8lan, with e1000_lv_phy_workarounds_ich8lan.
  Bool ok;
  if (!e1000e.pch || E1000EResetBlocked)
    return TRUE;
  Sleep(10);
  ok = TRUE;
  if (e1000e.pch2)
    ok = E1000EPhyModify(HV_KMRN_MODE_CTRL, 0, HV_KMRN_MDIO_SLOW) &&
          E1000EEmiWrite(I82579_MSE_THRESHOLD, 0x0034) &&
          E1000EEmiWrite(I82579_MSE_LINK_DOWN, 0x0005);
  ok = ok && E1000EPhyModify(BM_PORT_GEN_CFG, BM_WUC_HOST_WU_BIT, 0) &&
        E1000ESwLcdConfig && E1000EOemBits;
  if (!e1000e.pch2)
    return ok;
  if (!E1000EFwValid)
  {
    Sleep(10);
    E1000EGatePhyConfig(FALSE);
  }
  return ok && E1000EEmiWrite(I82579_LPI_UPDATE_TIMER, 0x1387);
}

U0 E1000EPhyHwResetGeneric()
{//e1000e_phy_hw_reset_generic: PHY reset alone (caller holds the semaphore).
  U32 ctrl = E1000ERead(E1000E_CTRL);
  E1000EWrite(E1000E_CTRL, ctrl | E1000E_CTRL_PHY_RST);
  E1000EFlush;
  Busy(100);
  E1000EWrite(E1000E_CTRL, ctrl);
  E1000EFlush;
  Busy(300);
}

Bool E1000EInitPhyWorkarounds()
{//e1000_init_phy_workarounds_pchlan (82579 and I217 paths).
  Bool ok = TRUE, up;
  E1000EGatePhyConfig(TRUE);
  if (!E1000EAcquire)
    return FALSE;
  up = E1000EPhyAccessible;
  if (!up && e1000e.lpt)
  {
    E1000EWrite(E1000E_CTRL_EXT, E1000ERead(E1000E_CTRL_EXT) | E1000E_CTRL_EXT_FORCE_SMBUS);
    Sleep(50);
    up = E1000EPhyAccessible;
  }
  if (!up)
  {
    if (E1000EResetBlocked)
    {
      "E1000E: PHY not accessible and the ME blocks resetting it\n";
      ok = FALSE;
    }
    else
    {
      E1000EToggleLanPhyPc;
      if (e1000e.lpt && !E1000EPhyAccessible)
      {
        E1000EWrite(E1000E_CTRL_EXT, E1000ERead(E1000E_CTRL_EXT) &
              ~E1000E_CTRL_EXT_FORCE_SMBUS);
        if (!E1000EPhyAccessible)
        {
          "E1000E: PHY not accessible after a power cycle\n";
          ok = FALSE;
        }
      }
    }
  }
  E1000ERelease;
  if (ok && !E1000EResetBlocked && E1000EAcquire)
  {
    E1000EPhyHwResetGeneric;
    E1000ERelease;
    E1000EGetCfgDone;
  }
  if (e1000e.pch2 && !E1000EFwValid)
  {
    Sleep(10);
    E1000EGatePhyConfig(FALSE);
  }
  return ok;
}


Bool E1000EResetHw()
{//e1000_reset_hw_ich8lan: full MAC (and, unless blocked, PHY) reset.
  U32 ctrl, r;
  I64 t;
  E1000EWrite(E1000E_CTRL, E1000ERead(E1000E_CTRL) | E1000E_CTRL_GIO_MASTER_DISABLE);
  for (t = 0; t < 800 && E1000ERead(E1000E_STATUS) & E1000E_STATUS_GIO_MASTER_ENABLE; t++)
    Busy(150);
  E1000EWrite(E1000E_IMC, 0xFFFFFFFF);
  E1000EWrite(E1000E_RCTL, 0);
  E1000EWrite(E1000E_TCTL, E1000E_TCTL_PSP);
  E1000EFlush;
  Sleep(10);
  ctrl = E1000ERead(E1000E_CTRL);
  if (e1000e.pch && !E1000EResetBlocked)
  {
    ctrl |= E1000E_CTRL_PHY_RST;
    if (e1000e.pch2 && !E1000EFwValid)
      E1000EGatePhyConfig(TRUE);
  }
  E1000EAcquire;
  E1000EWrite(E1000E_CTRL, ctrl | E1000E_CTRL_RST);
  Sleep(20);
  if (e1000e.pch2)
  {
    r = E1000ERead(E1000E_FEXTNVM3);
    E1000EWrite(E1000E_FEXTNVM3, r & ~E1000E_FEXTNVM3_PHY_CFG_COUNTER_MASK |
          E1000E_FEXTNVM3_PHY_CFG_COUNTER_50MSEC);
  }
  E1000EGetCfgDone;
  if (ctrl & E1000E_CTRL_PHY_RST && E1000EAcquire)
  {
    if (!E1000EPostPhyReset)
      "E1000E: PHY post-reset workarounds failed\n";
    E1000ERelease;
  }
  E1000EWrite(E1000E_IMC, 0xFFFFFFFF);
  E1000ERead(E1000E_ICR);
  E1000EWrite(E1000E_KABGTXD, E1000ERead(E1000E_KABGTXD) | E1000E_KABGTXD_BGSQLBIAS);
  return TRUE;
}

U0 E1000EInitHwBits()
{//e1000_initialize_hw_bits_ich8lan (82579 and I217 settings).
  U32 r;
  if (!e1000e.pch)
    return;
  E1000EWrite(E1000E_CTRL_EXT, E1000ERead(E1000E_CTRL_EXT) | 1 << 22 | E1000E_CTRL_EXT_PHYPDEN);
  E1000EWrite(E1000E_TXDCTL0, E1000ERead(E1000E_TXDCTL0) | 1 << 22);
  E1000EWrite(E1000E_TXDCTL1, E1000ERead(E1000E_TXDCTL1) | 1 << 22);
  E1000EWrite(E1000E_TARC0, E1000ERead(E1000E_TARC0) | 1 << 23 | 1 << 24 | 1 << 26 | 1 << 27);
  r = E1000ERead(E1000E_TARC1);
  if (E1000ERead(E1000E_TCTL) & E1000E_TCTL_MULR)
    r &= ~(1 << 28);
  else
    r |= 1 << 28;
  E1000EWrite(E1000E_TARC1, r | 1 << 24 | 1 << 26 | 1 << 30);
  E1000EWrite(E1000E_RFCTL, E1000ERead(E1000E_RFCTL) | E1000E_RFCTL_NFSW_DIS |
        E1000E_RFCTL_NFSR_DIS);
  if (e1000e.lpt)
  {
    E1000EWrite(E1000E_PBECCSTS, E1000ERead(E1000E_PBECCSTS) | E1000E_PBECCSTS_ECC_ENABLE);
    E1000EWrite(E1000E_CTRL, E1000ERead(E1000E_CTRL) | E1000E_CTRL_MEHE);
  }
}

Bool E1000ESetupLink()
{//e1000_setup_link_ich8lan. No flow control: nothing acts on PAUSE.
  U32 ctrl = E1000ERead(E1000E_CTRL);
  Bool ok = TRUE;
  if (E1000EResetBlocked)
  {
    "E1000E: the ME blocks PHY access; keeping the firmware's link config\n";
    return TRUE;
  }
  ctrl |= E1000E_CTRL_SLU;
  ctrl &= ~(E1000E_CTRL_FRCSPD | E1000E_CTRL_FRCDPX);
  E1000EWrite(E1000E_CTRL, ctrl);
  if (!E1000EAcquire)
    return FALSE;
  if (e1000e.pch)
  {
    if (e1000e.pch2)
    {
      E1000EKmrnWrite(E1000E_KMRN_TIMEOUTS, 0xFFFF);
      E1000EKmrnWrite(E1000E_KMRN_INBAND_PARAM, E1000EKmrnRead(E1000E_KMRN_INBAND_PARAM) | 0x3F);
    }
    ok = E1000EPhyModify(I82577_CFG_REG, 0, I82577_CFG_ASSERT_CRS_ON_TX |
          I82577_CFG_ENABLE_DOWNSHIFT) &&
          E1000EPhyModify(I82577_PHY_CTRL_2, I82577_PHY_CTRL2_MDIX_CFG_MASK,
          I82577_PHY_CTRL2_AUTO_MDI_MDIX);
  }
  ok = ok && E1000EPhyModify(MII_ADVERTISE, ADVERTISE_10HALF | ADVERTISE_10FULL |
        ADVERTISE_100HALF | ADVERTISE_100FULL | ADVERTISE_PAUSE_CAP | ADVERTISE_PAUSE_ASYM,
        ADVERTISE_10HALF | ADVERTISE_10FULL | ADVERTISE_100HALF | ADVERTISE_100FULL) &&
        E1000EPhyModify(MII_CTRL1000, ADVERTISE_1000HALF | ADVERTISE_1000FULL,
        ADVERTISE_1000FULL) &&
        E1000EPhyModify(MII_BMCR, 0, BMCR_ANENABLE | BMCR_ANRESTART);
  E1000ERelease;
  return ok;
}

U0 E1000EJumboWorkaroundOff()
{//e1000_lv_jumbo_workaround_ich8lan(hw, false). Must precede the RCTL write.
  I64 rx_path;
  if (!e1000e.pch || !E1000EAcquire)
    return;
  rx_path = E1000EPhyRead(E1000EPhyReg(769, 20));
  if (rx_path >= 0)
  {
    E1000EPhyWrite(E1000EPhyReg(769, 20), rx_path | 1 << 14);
    E1000EWrite(E1000E_FFLT_DBG, E1000ERead(E1000E_FFLT_DBG) & ~(0xF << 14));
    E1000EWrite(E1000E_RCTL, E1000ERead(E1000E_RCTL) & ~E1000E_RCTL_SECRC);
    E1000EKmrnWrite(E1000E_KMRN_CTRL_OFFSET, E1000EKmrnRead(E1000E_KMRN_CTRL_OFFSET) & ~1);
    E1000EKmrnWrite(E1000E_KMRN_HD_CTRL,
          E1000EKmrnRead(E1000E_KMRN_HD_CTRL) & ~(0xF << 8) | 0xB << 8);
    E1000EPhyModify(E1000EPhyReg(769, 23), 0x7F << 5, 0);
    E1000EPhyModify(E1000EPhyReg(769, 16), 0, 1 << 13);
    E1000EPhyModify(E1000EPhyReg(776, 20), 0x3FF << 2, 0x8 << 2);
    E1000EPhyWrite(E1000EPhyReg(776, 23), 0x7E00);
    E1000EPhyModify(HV_PM_CTRL, 1 << 10, 0);
    E1000EPhyWrite(E1000EPhyReg(769, 20), rx_path & ~(1 << 14));
  }
  E1000ERelease;
}

U0 E1000ELinkUp()
{//e1000_check_for_copper_link_ich8lan's link-up steps.
  U32 status = E1000ERead(E1000E_STATUS), tipg = E1000ERead(E1000E_TIPG);
  Bool half10 = !(status & E1000E_STATUS_FD) &&
        !(status & (E1000E_STATUS_SPEED_100 | E1000E_STATUS_SPEED_1000));
  I64 m_status;
  if (!e1000e.pch)
    return;
  tipg &= ~E1000E_TIPG_IPGT_MASK;
  if (half10)
    tipg |= 0xFF;
  else
    tipg |= 0x08;
  E1000EWrite(E1000E_TIPG, tipg);
  if (!E1000EAcquire)
    return;
  if (e1000e.lpt)
  {
    E1000EEmiWrite(I217_RX_CONFIG, !half10);
    if (status & (E1000E_STATUS_SPEED_100 | E1000E_STATUS_SPEED_1000) ==
          E1000E_STATUS_SPEED_1000)
    {
      E1000EPhyModify(I217_PLL_CLOCK_GATE_REG, I217_PLL_CLOCK_GATE_MASK, 0xFA);
      E1000EPhyModify(HV_PM_CTRL, 0, HV_PM_CTRL_K1_CLK_REQ);
    }
    else
      E1000EPhyModify(I217_PLL_CLOCK_GATE_REG, I217_PLL_CLOCK_GATE_MASK, 0x3E8);
    E1000ERelease;
    E1000EWrite(E1000E_FEXTNVM4, E1000ERead(E1000E_FEXTNVM4) &
          ~E1000E_FEXTNVM4_BEACON_DURATION_MASK | E1000E_FEXTNVM4_BEACON_DURATION_8USEC);
    return;
  }
  E1000EEmiWrite(I82579_RX_CONFIG, !half10);
  m_status = E1000EPhyRead(HV_M_STATUS);
  if (m_status >= 0 && m_status & (HV_M_STATUS_LINK_UP | HV_M_STATUS_AUTONEG_COMPLETE) ==
        HV_M_STATUS_LINK_UP | HV_M_STATUS_AUTONEG_COMPLETE)
  {
    if (m_status & (HV_M_STATUS_SPEED_1000 | HV_M_STATUS_SPEED_100))
      E1000EPhyModify(HV_PM_CTRL, HV_PM_CTRL_K1_ENABLE, 0);
    else
      E1000EWrite(E1000E_FEXTNVM4, E1000ERead(E1000E_FEXTNVM4) &
            ~E1000E_FEXTNVM4_BEACON_DURATION_MASK | E1000E_FEXTNVM4_BEACON_DURATION_16USEC);
  }
  if (status & E1000E_STATUS_FD)
    E1000EPhyModify(HV_KMRN_FIFO_CTRLSTA, HV_KMRN_FIFO_CTRLSTA_PREAMBLE_MASK, 0);
  else
    E1000EPhyModify(HV_KMRN_FIFO_CTRLSTA, HV_KMRN_FIFO_CTRLSTA_PREAMBLE_MASK,
          1 << HV_KMRN_FIFO_CTRLSTA_PREAMBLE_SHIFT);
  E1000ERelease;
}


U0 E1000EInitRings()
{
  I64 i;
  e1000e.rx = CAllocAligned(E1000E_RX_CNT * sizeof(CE1000ERxDesc), 128, sys_dma_heap);
  e1000e.tx = CAllocAligned(E1000E_TX_CNT * sizeof(CE1000ETxDesc), 128, sys_dma_heap);
  e1000e.rx_bufs = CAllocAligned(E1000E_RX_CNT * ETH_FRAME_SIZE, 16, sys_dma_heap);
  e1000e.tx_bufs = CAllocAligned(E1000E_TX_CNT * ETH_FRAME_SIZE, 16, sys_dma_heap);
  for (i = 0; i < E1000E_RX_CNT; i++)
    e1000e.rx[i].addr = e1000e.rx_bufs + i * ETH_FRAME_SIZE;
  E1000EWrite(E1000E_RDBAL, e1000e.rx(I64) & 0xFFFFFFFF);
  E1000EWrite(E1000E_RDBAH, e1000e.rx(I64) >> 32);
  E1000EWrite(E1000E_RDLEN, E1000E_RX_CNT * sizeof(CE1000ERxDesc));
  E1000EWrite(E1000E_RDH, 0);
  E1000EWrite(E1000E_RDT, E1000E_RX_CNT - 1);
  E1000EWrite(E1000E_TDBAL, e1000e.tx(I64) & 0xFFFFFFFF);
  E1000EWrite(E1000E_TDBAH, e1000e.tx(I64) >> 32);
  E1000EWrite(E1000E_TDLEN, E1000E_TX_CNT * sizeof(CE1000ETxDesc));
  E1000EWrite(E1000E_TDH, 0);
  E1000EWrite(E1000E_TDT, 0);
  E1000EWrite(E1000E_RCTL, E1000E_RCTL_EN | E1000E_RCTL_BAM | E1000E_RCTL_SECRC);
  E1000EWrite(E1000E_TCTL, E1000ERead(E1000E_TCTL) & ~(E1000E_TCTL_CT | E1000E_TCTL_COLD) |
        E1000E_TCTL_EN | E1000E_TCTL_PSP | E1000E_TCTL_RTLC | 15 << 4 | 63 << 12);
}

U0 E1000EPoll()
{//Received frames to the NetQue; each descriptor handed straight back.
  CE1000ERxDesc *d = &e1000e.rx[e1000e.rx_next];
  while (d->dd)
  {
    if (d->eop && !d->errors && e1000e.running)
    {
      NetQuePush(d->addr, d->len);
      e1000e.rx_frames++;
    }
    d->status = 0;
    E1000EWrite(E1000E_RDT, e1000e.rx_next);
    e1000e.rx_next = (e1000e.rx_next + 1) & (E1000E_RX_CNT - 1);
    d = &e1000e.rx[e1000e.rx_next];
  }
}

U0 E1000ETask(U8 *)
{//Receive every millisecond; link changes every 100.
  I64 n = 0, sd;
  Bool up;
  while (TRUE)
  {
    E1000EPoll;
    if (!(n++ % 100))
    {
      sd = E1000ERead(E1000E_STATUS) & (E1000E_STATUS_LU | E1000E_STATUS_FD |
            E1000E_STATUS_SPEED_100 | E1000E_STATUS_SPEED_1000);
      up = ToBool(sd & E1000E_STATUS_LU);
      if (up && sd != e1000e.link_status)
        E1000ELinkUp;
      e1000e.link_status = sd;
      e1000e.link_up = up;
    }
    Sleep(1);
  }
}


U8 *EthMACGet()
{
  return e1000e.mac;
}

//One frame at a time, Allocate to end of Finish, as E1000.HC: senders on
//other CPUs (NetHandler ACKs, ElfRun sockets) got the same descriptor.
I64 e1000e_tx_lock = 0;
CTask *e1000e_tx_task = NULL;

I64 EthFrameAlloc(U8 **pkt_buf_out, U8 *src_addr,
                          U8 *dst_addr, U16 ethertype, I64 pkt_len)
{
  I64 i;
  U8 *frame;
  if (pkt_len < ETH_MIN_FRAME_SIZE)
    pkt_len = ETH_MIN_FRAME_SIZE;
  if (ETH_MAC_HDR_LEN + pkt_len > ETH_FRAME_SIZE)
    return -1;
  while (LBts(&e1000e_tx_lock, 0))
  {//Take over from a task that died holding it
    if (e1000e_tx_task && (e1000e_tx_task == Fs || !TaskValidate(e1000e_tx_task)))
      break;
    Yield;
  }
  e1000e_tx_task = Fs;
  i = e1000e.tx_next;
  frame = e1000e.tx_bufs + i * ETH_FRAME_SIZE;
  MemSet(frame, 0, ETH_MAC_HDR_LEN + pkt_len);
  e1000e.tx_len[i] = ETH_MAC_HDR_LEN + pkt_len;
  *pkt_buf_out = EthHdrSet(frame, src_addr, dst_addr,
        ethertype);
  return i;
}

I64 EthFrameFinish(I64 i)
{//Send one frame and wait for the NIC to report it done.
  CE1000ETxDesc *d = &e1000e.tx[i];
  U8 *frame = e1000e.tx_bufs + i * ETH_FRAME_SIZE;
  I64 end;
  if (e1000e.mac_ok && !MemCmp(frame, e1000e.mac, MAC_ADDR_LEN))
  {
    NetQuePush(frame, e1000e.tx_len[i]);
    e1000e_tx_task = NULL;
    LBtr(&e1000e_tx_lock, 0);
    return 0;
  }
  ZeroClass(d);
  d->addr = frame;
  d->len = e1000e.tx_len[i];
  d->eop = 1;
  d->ifcs = 1;
  d->rs = 1;
  e1000e.tx_next = (i + 1) & (E1000E_TX_CNT - 1);
  E1000EWrite(E1000E_TDT, e1000e.tx_next);
  end = cnts.jiffies + JIFFY_FREQ / 10;
  while (!(d->status & 0xF) && cnts.jiffies < end)
    Yield;
  e1000e_tx_task = NULL;
  LBtr(&e1000e_tx_lock, 0);
  if (!d->dd || d->ec || d->lc)
  {
    e1000e.tx_errors++;
    return -1;
  }
  e1000e.tx_frames++;
  return 0;
}

U0 NetStop()
{
  e1000e.running = FALSE;
}

U0 NetStart()
{
  e1000e.running = TRUE;
}

public Bool E1000EMACSet(I64 b0, I64 b1, I64 b2, I64 b3, I64 b4, I64 b5)
{//Force the station address, for when RAR0 is empty and the NVM unreadable.
  U8 mac[6];
  U32 ral, rah;
  I64 i;
  mac[0] = b0;
  mac[1] = b1;
  mac[2] = b2;
  mac[3] = b3;
  mac[4] = b4;
  mac[5] = b5;
  if (!E1000EMacValid(mac))
  {
    "E1000E: %02X:%02X:%02X:%02X:%02X:%02X is not a unicast address\n",
          mac[0], mac[1], mac[2], mac[3], mac[4], mac[5];
    return FALSE;
  }
  for (i = 0; i < MAC_ADDR_LEN; i++)
    e1000e.mac[i] = mac[i];
  e1000e.mac_ok = TRUE;
  e1000e.mac_src = "set by hand";
  ral = mac[0] | mac[1] << 8 | mac[2] << 16 | mac[3] << 24;
  rah = mac[4] | mac[5] << 8;
  E1000EWrite(E1000E_RAL0, ral);
  E1000EWrite(E1000E_RAH0, rah | E1000E_RAH_AV);
  "E1000E: MAC address now %02X:%02X:%02X:%02X:%02X:%02X\n",
        mac[0], mac[1], mac[2], mac[3], mac[4], mac[5];
  return TRUE;
}

public U0 E1000ERep()
{//Link state and counters.
  U32 status = E1000ERead(E1000E_STATUS);
  I64 speed = 10;
  if (status & E1000E_STATUS_SPEED_1000)
    speed = 1000;
  else if (status & E1000E_STATUS_SPEED_100)
    speed = 100;
  "E1000E: link %d", ToBool(status & E1000E_STATUS_LU);
  if (status & E1000E_STATUS_LU)
    " %d Mb/s %s duplex", speed, LstSub(status & E1000E_STATUS_FD, "half\0full\0");
  "\n  MAC %02X:%02X:%02X:%02X:%02X:%02X from %s\n",
        e1000e.mac[0], e1000e.mac[1], e1000e.mac[2],
        e1000e.mac[3], e1000e.mac[4], e1000e.mac[5], e1000e.mac_src;
  if (!e1000e.mac_ok)
    "  That address is UNUSABLE; see E1000EMACSet\n";
  "  BAR0 0x%08X, BAR1 0x%08X, CTRL 0x%08X, STATUS 0x%08X, FWSM 0x%08X\n",
        e1000e.pci->bar[0], e1000e.pci->bar[1], E1000ERead(E1000E_CTRL),
        status, E1000ERead(E1000E_FWSM);
  "  RX %d frames, TX %d frames, %d errors; PHY workarounds %s\n",
        e1000e.rx_frames, e1000e.tx_frames, e1000e.tx_errors,
        LstSub(e1000e.pch, "off (not a PCH part)\0on\0");
}
public U0 E1000EStats()
{//The MAC's own counters, every one clear-on-read.
  "E1000E hardware counters (since last read):\n";
  "  TX  total %d, good %d, bcast %d, no-carrier %d, late-col %d, excess-col %d\n",
        E1000ERead(E1000E_TPT), E1000ERead(E1000E_GPTC), E1000ERead(E1000E_BPTC),
        E1000ERead(E1000E_TNCRS), E1000ERead(E1000E_LATECOL),
        E1000ERead(E1000E_ECOL);
  "  TX  single-col %d, multi-col %d, total-col %d, deferred %d\n",
        E1000ERead(E1000E_SCC), E1000ERead(E1000E_MCC), E1000ERead(E1000E_COLC),
        E1000ERead(E1000E_DC);
  "  RX  total %d, good %d, broadcast %d, crc-err %d, rx-err %d, len-err %d\n",
        E1000ERead(E1000E_TPR), E1000ERead(E1000E_GPRC), E1000ERead(E1000E_BPRC),
        E1000ERead(E1000E_CRCERRS), E1000ERead(E1000E_RXERRC),
        E1000ERead(E1000E_RLEC);
  "  RX  missed %d, no-buffer %d, seq-err %d\n",
        E1000ERead(E1000E_MPC), E1000ERead(E1000E_RNBC), E1000ERead(E1000E_SEC);
  "  ME  mgmt rx %d, mgmt dropped %d, mgmt tx %d\n",
        E1000ERead(E1000E_MGTPRC), E1000ERead(E1000E_MGTPDC),
        E1000ERead(E1000E_MGTPTC);
  "  ring TDH %d TDT %d, RDH %d RDT %d, TCTL 0x%08X, RCTL 0x%08X\n",
        E1000ERead(E1000E_TDH), E1000ERead(E1000E_TDT), E1000ERead(E1000E_RDH),
        E1000ERead(E1000E_RDT), E1000ERead(E1000E_TCTL), E1000ERead(E1000E_RCTL);
}

public U0 E1000ETxTest(I64 cnt=4)
{//Put raw broadcast frames straight on the TX ring, bypassing the IP stack.
  CE1000ETxDesc *d;
  U8 *frame;
  I64 n, i, end;
  if (!e1000e.mac_ok)
    "E1000E: no usable station address; frames will carry a bogus source\n";
  for (n = 0; n < cnt; n++)
  {
    i = e1000e.tx_next;
    frame = e1000e.tx_bufs + i * ETH_FRAME_SIZE;
    MemSet(frame, 0, 64);
    MemSet(frame, 0xFF, MAC_ADDR_LEN);
    MemCpy(frame + MAC_ADDR_LEN, e1000e.mac, MAC_ADDR_LEN);
    frame[12] = 0x88;
    frame[13] = 0xB5;
    frame[14] = 'T';
    frame[15] = 'O';
    frame[16] = 'S';
    frame[17] = n;
    d = &e1000e.tx[i];
    ZeroClass(d);
    d->addr = frame;
    d->len = 64;
    d->eop = 1;
    d->ifcs = 1;
    d->rs = 1;
    e1000e.tx_next = (i + 1) & (E1000E_TX_CNT - 1);
    E1000EWrite(E1000E_TDT, e1000e.tx_next);
    end = cnts.jiffies + JIFFY_FREQ / 10;
    while (!(d->status & 0xF) && cnts.jiffies < end)
      Yield;
    "  frame %d: desc 0x%02X (done %d, excess-col %d, late-col %d), TDH %d TDT %d\n",
          n, d->status, d->dd, d->ec, d->lc,
          E1000ERead(E1000E_TDH), E1000ERead(E1000E_TDT);
  }
  E1000EStats;
}

U0 E1000EInit()
{
  U32 ral, rah;
  I64 i;
  ZeroClass(&e1000e);
  e1000e.pci = &net_driver_pci;
  e1000e.pch2 = e1000e.pci->device_id == PCID_E1000E_82579LM;
  e1000e.lpt = e1000e.pci->device_id == PCID_E1000E_I217LM ||
        e1000e.pci->device_id == PCID_E1000E_I217V;
  e1000e.pch = e1000e.pch2 || e1000e.lpt;
  e1000e.mac_src = "RAR0";
  PCIWriteU16(e1000e.pci->bus, e1000e.pci->dev, e1000e.pci->fun, PCIR_COMMAND,
        1 << 1 | 1 << 2);
  e1000e.mmio = dev.uncached_alias + (e1000e.pci->bar[0] & 0xFFFFFFF0);
  if (e1000e.pch && e1000e.pci->bar[1] && !(e1000e.pci->bar[1] & 1))
    e1000e.flash = dev.uncached_alias + (e1000e.pci->bar[1] & 0xFFFFFFF0);
  "E1000E: %04X:%04X rev %02X at %02X:%02X.%X, BAR0 0x%08X, BAR1 0x%08X\n",
        e1000e.pci->vendor_id, e1000e.pci->device_id, e1000e.pci->revision_id,
        e1000e.pci->bus, e1000e.pci->dev, e1000e.pci->fun,
        e1000e.pci->bar[0], e1000e.pci->bar[1];
  if (E1000ERead(E1000E_STATUS) == 0xFFFFFFFF)
    "E1000E: MMIO reads back all ones; BAR0 is not decoding\n";
  if (e1000e.pch && !e1000e.flash)
    "E1000E: no flash BAR; the NVM cannot be read\n";
  "E1000E: FWSM 0x%08X (fw_valid %d), FEXTNVM 0x%08X, PHY_CTRL 0x%08X\n",
        E1000ERead(E1000E_FWSM), E1000EFwValid,
        E1000ERead(E1000E_FEXTNVM), E1000ERead(E1000E_PHY_CTRL);
  ral = E1000ERead(E1000E_RAL0);
  rah = E1000ERead(E1000E_RAH0);
  if (e1000e.pch && !E1000EInitPhyWorkarounds)
    "E1000E: PHY workarounds failed; trying anyway\n";
  E1000EResetHw;
  E1000EWrite(E1000E_CTRL_EXT, E1000ERead(E1000E_CTRL_EXT) | E1000E_CTRL_EXT_DRV_LOAD);
  if (E1000ERead(E1000E_RAH0) & E1000E_RAH_AV)
  {
    ral = E1000ERead(E1000E_RAL0);
    rah = E1000ERead(E1000E_RAH0);
    e1000e.mac_src = "RAR0";
  }
  else
    e1000e.mac_src = "RAR0 (pre-reset)";
  for (i = 0; i < 4; i++)
    e1000e.mac[i] = ral.u8[i];
  e1000e.mac[4] = rah.u8[0];
  e1000e.mac[5] = rah.u8[1];
  e1000e.mac_ok = E1000EMacValid(e1000e.mac);
  if (!e1000e.mac_ok)
  {
    "E1000E: RAR0 has no address (RAL 0x%08X RAH 0x%08X); reading the NVM\n",
          ral, rah;
    if (E1000EMacFromNvm(e1000e.mac))
    {
      e1000e.mac_ok = TRUE;
      e1000e.mac_src = "NVM";
    }
    else
      e1000e.mac_src = "nowhere";
  }
  if (e1000e.mac_ok)
  {
    ral = e1000e.mac[0] | e1000e.mac[1] << 8 | e1000e.mac[2] << 16 |
          e1000e.mac[3] << 24;
    rah = e1000e.mac[4] | e1000e.mac[5] << 8;
    E1000EWrite(E1000E_RAL0, ral);
    E1000EWrite(E1000E_RAH0, rah | E1000E_RAH_AV);
  }
  E1000EInitHwBits;
  for (i = 0; i < 32; i++)
    E1000EWrite(E1000E_MTA + i * 4, 0);
  if (!E1000ESetupLink)
    "E1000E: link setup failed\n";
  for (i = E1000E_TXDCTL0; i <= E1000E_TXDCTL1; i += E1000E_TXDCTL1 - E1000E_TXDCTL0)
    E1000EWrite(i, E1000ERead(i) & ~(E1000E_TXDCTL_WTHRESH | E1000E_TXDCTL_PTHRESH) |
          E1000E_TXDCTL_FULL_TX_DESC_WB | E1000E_TXDCTL_MAX_TX_DESC_PREFETCH);
  E1000EWrite(E1000E_CTRL_EXT, E1000ERead(E1000E_CTRL_EXT) | E1000E_CTRL_EXT_RO_DIS);
  E1000EJumboWorkaroundOff;
  E1000EInitRings;
  e1000e.running = TRUE;
  "%s, MAC address %02X:%02X:%02X:%02X:%02X:%02X from %s\n",
        LstSub(e1000e.pch2 + 2 * e1000e.lpt, "Intel 82574L (e1000e)\0Intel 82579LM\0Intel I217\0"),
        e1000e.mac[0], e1000e.mac[1], e1000e.mac[2],
        e1000e.mac[3], e1000e.mac[4], e1000e.mac[5], e1000e.mac_src;
  if (!e1000e.mac_ok)
  {
    "E1000E: that is not a usable station address. Frames will go out with a\n";
    "E1000E: bogus source MAC and nothing will answer. Set the one on the\n";
    "E1000E: label before Config Network, e.g.\n";
    "E1000E:   E1000EMACSet(0x00,0x21,0xCC,0x11,0x22,0x33);\n";
  }
  Spawn(&E1000ETask, NULL, "E1000E");
  for (i = 0; i < 30 && !(E1000ERead(E1000E_STATUS) & E1000E_STATUS_LU); i++)
    Sleep(100);
  E1000ERep;
}


E1000EInit;
