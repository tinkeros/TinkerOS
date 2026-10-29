// USB Ethernet (CDC-ECM) network driver: the network stack half of the
// kernel driver in ::/Kernel/Usb/EcmK.HC, which owns the USB transfers and
// the receive ring. There is no NIC interrupt: a task moves received frames
// into the NetQue, and transmit is a blocking bulk OUT, which is fine because
// the stack only transmits from tasks (NetHandler is one).

#define USB_ECM_TX_BUFS 8

class CUsbEcmNet
{
  U8 mac[MAC_ADDR_LEN];
  U8 *tx_bufs;
  I64 tx_len[USB_ECM_TX_BUFS], tx_next;
  Bool running;
  CTask *rx_task;
} usb_ecm_net;

U8 *EthMACGet()
{
  return usb_ecm_net.mac;
}

I64 EthFrameAlloc(U8 **pkt_buf_out, U8 *src_addr,
                          U8 *dst_addr, U16 ethertype, I64 pkt_len)
{
  U8 *frame;
  I64 de_index;
  if (pkt_len < ETH_MIN_FRAME_SIZE)
    pkt_len = ETH_MIN_FRAME_SIZE;
  if (ETH_MAC_HDR_LEN + pkt_len > ETH_FRAME_SIZE)
  {
    NetErr("USB ECM: Frame too long (%d).", pkt_len);
    return -1;
  }
  de_index = usb_ecm_net.tx_next;
  usb_ecm_net.tx_next = (de_index + 1) & (USB_ECM_TX_BUFS - 1);
  frame = usb_ecm_net.tx_bufs + de_index * ETH_FRAME_SIZE;
  MemSet(frame, 0, ETH_MAC_HDR_LEN + pkt_len);
  usb_ecm_net.tx_len[de_index] = ETH_MAC_HDR_LEN + pkt_len;
  *pkt_buf_out = EthHdrSet(frame, src_addr, dst_addr, ethertype);
  return de_index;
}

I64 EthFrameFinish(I64 de_index)
{
  U8 *frame = usb_ecm_net.tx_bufs + de_index * ETH_FRAME_SIZE;
  I64 len = usb_ecm_net.tx_len[de_index];
  if (!MemCmp(frame, usb_ecm_net.mac, MAC_ADDR_LEN))
  {//To ourselves: loop it back, the adapter would not deliver it.
    NetQuePush(frame, len);
    return 0;
  }
  if (UsbEcmSend(frame, len) < 0)
  {
    NetErr("USB ECM: Transmit failed.");
    return -1;
  }
  return 0;
}

U0 NetStop()
{//The kernel keeps receiving into its ring; delivery to the NetQue pauses.
  usb_ecm_net.running = FALSE;
}

U0 NetStart()
{
  usb_ecm_net.running = TRUE;
}

U0 UsbEcmNetRxTask(U8 *)
{
  U8 *buf = MAlloc(ETH_FRAME_SIZE);
  I64 len;
  usb_ecm_net.rx_task = Fs;
  while (TRUE)
  {
    len = UsbEcmRecv(buf, ETH_FRAME_SIZE);
    if (len > 0)
    {
      if (usb_ecm_net.running)
        NetQuePush(buf, len);
    }
    else
      Sleep(1);
  }
}

U0 UsbEcmNetInit()
{
  ZeroClass(&usb_ecm_net);
  UsbEcmMAC(usb_ecm_net.mac);
  usb_ecm_net.tx_bufs = CAlloc(ETH_FRAME_SIZE * USB_ECM_TX_BUFS, adam_task);
  usb_ecm_net.running = TRUE;
  "USB Ethernet adapter, MAC address %02X:%02X:%02X:%02X:%02X:%02X\n",
        usb_ecm_net.mac[0], usb_ecm_net.mac[1], usb_ecm_net.mac[2],
        usb_ecm_net.mac[3], usb_ecm_net.mac[4], usb_ecm_net.mac[5];
  Spawn(&UsbEcmNetRxTask, NULL, "USB Ethernet RX");
}

UsbEcmNetInit;
