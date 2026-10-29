//USB CDC-ECM Ethernet driver, kernel half. UsbEnum binds a CDC-ECM function
//(class 2, subclass 6) as USB_KIND_ECM and calls UsbEcmAttach. The network
//stack half is Demo/Net/Drivers/UsbEcm.HC, which calls the public UsbEcm*
//API below. The first attached adapter is the NIC.
//
//RX uses the async bulk-IN ops CDC-ACM uses (bin_arm/bin_poll, Usb.HH): one
//armed ECM_RX_XFER-byte transfer per adapter. A short packet ends every ECM
//frame, so one completion is one Ethernet frame. UsbEcmPoll reaps it into a
//ring of frames and re-arms; it runs every UsbPoll tick (5 ms) and inline
//from UsbEcmRecv, so a reader that polls every millisecond gets frames at
//that rate. EHCI and xHCI only: UHCI/OHCI have no bin_arm yet.
//
//TX is a synchronous bulk OUT under usb_lock. The stack transmits only from
//task context (NetHandler is a task), so blocking for one transfer is fine.

#define ECM_RX_XFER 2048
#define ECM_FRAME   2048
#define ECM_RXQ     32

class CUsbEcmFrame
{
  I64 len;
  U8 data[ECM_FRAME];
};

class CUsbEcm
{
  U8 *rx_dma, *tx_dma;
  CUsbEcmFrame *rxq;
  I64 r_in, r_out;
  I64 armed, rx_frames, rx_drops, rx_err, tx_frames, tx_err;
  U8 mac[6];
  Bool up;
};
CUsbEcm *usb_ecm = NULL;

U0 UsbEcmBufInit()
{
  if (usb_ecm) return;
  usb_ecm = CAlloc(USB_NFN * sizeof(CUsbEcm));
}

I64 UsbEcmFirst()
{//usb_fn index of the first live, attached adapter, else -1.
  I64 k;
  if (!usb_ecm) return -1;
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].on && usb_fn[k].kind == USB_KIND_ECM && usb_ecm[k].up)
      return k;
  return -1;
}

I64 UsbEcmHex(U8 c)
{
  if ('0' <= c <= '9') return c - '0';
  if ('A' <= c <= 'F') return c - 'A' + 10;
  if ('a' <= c <= 'f') return c - 'a' + 10;
  return -1;
}

Bool UsbEcmMACRead(CUsbFn *f, U8 *mac)
{//iMACAddress: 12 hex digits as a UTF-16LE string descriptor, "0011223344AA".
  U8 s[64];
  I64 i, hi, lo;
  if (!f->mstr || UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_STR << 8 | f->mstr,
        0x0409, 64, s) < 2 + 12 * 2)
    return FALSE;
  for (i = 0; i < 6; i++)
  {
    hi = UsbEcmHex(s[2 + 4 * i]);
    lo = UsbEcmHex(s[4 + 4 * i]);
    if (hi < 0 || lo < 0)
      return FALSE;
    mac[i] = hi << 4 | lo;
  }
  return TRUE;
}

U0 UsbEcmAttach(I64 k)
{//From UsbEnum, configured with the data i/f's alternate setting selected.
//Not usb_lock-held: UsbReq takes it.
  CUsbFn *f = &usb_fn[k];
  CUsbEcm *e;
  UsbEcmBufInit;
  e = &usb_ecm[k];
  if (!e->rx_dma)
  {//Kept for the slot's later devices: a reattach doesn't allocate again.
    e->rx_dma = CAllocAligned(ECM_RX_XFER, ECM_RX_XFER, sys_dma_heap);
    e->tx_dma = CAllocAligned(ECM_FRAME, ECM_FRAME, sys_dma_heap);
    e->rxq = CAlloc(ECM_RXQ * sizeof(CUsbEcmFrame));
  }
  e->r_in = 0;
  e->r_out = 0;
  e->armed = 0;
  e->rx_frames = 0;
  e->rx_drops = 0;
  e->rx_err = 0;
  e->tx_frames = 0;
  e->tx_err = 0;
  if (!UsbEcmMACRead(f, e->mac))
  {//None given: a locally administered address ("TOS" + product ID).
    e->mac[0] = 0x02;
    e->mac[1] = 'T';
    e->mac[2] = 'O';
    e->mac[3] = 'S';
    e->mac[4] = f->pid >> 8;
    e->mac[5] = f->pid;
  }
  UsbReq(f, USB_RT_CLS | USB_RT_IF, 0x43, 0x0C, f->ifn, 0);
  e->up = TRUE;
}

U0 UsbEcmPoll(I64 k)
{//Every UsbPoll tick for every live adapter, and inline from UsbEcmRecv
//(both serialized by usb_lock, so the ring stays single-producer).
  CUsbFn *f = &usb_fn[k];
  CUsbEcm *e;
  CUsbEcmFrame *fr;
  I64 n;
  if (!f->on || f->kind != USB_KIND_ECM || !usb_ecm) return;
  e = &usb_ecm[k];
  if (!e->up || !usb_ops[f->hc].bin_arm || !usb_ops[f->hc].bin_poll) return;
  UsbLock;
  if (e->armed)
  {
    n = (*usb_ops[f->hc].bin_poll)(f);
    if (n >= 0)
    {
      e->armed = 0;
      if (n > 0)
      {
        if (e->r_in - e->r_out < ECM_RXQ)
        {
          fr = &e->rxq[e->r_in & (ECM_RXQ - 1)];
          MemCpy(fr->data, e->rx_dma, n);
          fr->len = n;
          e->r_in++;
          e->rx_frames++;
        }
        else
          e->rx_drops++;
      }
    }
    else if (n == -2)
    {
      e->rx_err++;
      e->armed = 0;
    }
  }
  if (!e->armed && (*usb_ops[f->hc].bin_arm)(f, e->rx_dma, ECM_RX_XFER))
    e->armed = 1;
  UsbUnlock;
}

U0 UsbEcmUnplug(I64 k)
{//Called by UsbFnOff (not usb_lock-held) when an adapter is gone.
  CUsbFn *f = &usb_fn[k];
  CUsbEcm *e;
  if (!usb_ecm) return;
  e = &usb_ecm[k];
  if (e->armed && usb_ops[f->hc].bin_stop)
    (*usb_ops[f->hc].bin_stop)(f);
  e->armed = 0;
  e->up = FALSE;
}

public Bool UsbEcmPresent()
{//An attached USB Ethernet adapter that can receive (EHCI or xHCI).
  I64 k = UsbEcmFirst;
  if (k < 0)
    return FALSE;
  return usb_ops[usb_fn[k].hc].bin_arm;
}

public U0 UsbEcmMAC(U8 *out6)
{
  I64 k = UsbEcmFirst;
  if (k >= 0)
    MemCpy(out6, usb_ecm[k].mac, 6);
  else
    MemSet(out6, 0, 6);
}

public I64 UsbEcmSend(U8 *frame, I64 len)
{//0 if sent, -1 if no adapter, a bad length or a failed transfer. Task
//context only: blocks for one bulk OUT.
  I64 k = UsbEcmFirst, r;
  CUsbFn *f;
  CUsbEcm *e;
  if (k < 0 || len <= 0 || len >= ECM_FRAME)
    return -1;
  f = &usb_fn[k];
  e = &usb_ecm[k];
  UsbLock;
  MemCpy(e->tx_dma, frame, len);
  if (f->bmps && !(len % f->bmps))
    e->tx_dma[len++] = 0;
  r = (*usb_ops[f->hc].bulk)(f, 0, e->tx_dma, len);
  UsbUnlock;
  if (r != len)
  {
    e->tx_err++;
    return -1;
  }
  e->tx_frames++;
  return 0;
}

public I64 UsbEcmRecv(U8 *dst, I64 max)
{//Copies the next received frame to dst: bytes, 0 if none, -1 if no adapter.
  I64 k = UsbEcmFirst, n;
  CUsbEcm *e;
  CUsbEcmFrame *fr;
  if (k < 0) return -1;
  e = &usb_ecm[k];
  if (e->r_in == e->r_out)
    UsbEcmPoll(k);
  if (e->r_in == e->r_out)
    return 0;
  fr = &e->rxq[e->r_out & (ECM_RXQ - 1)];
  n = MinI64(fr->len, max);
  MemCpy(dst, fr->data, n);
  e->r_out++;
  return n;
}

public U0 UsbEcmRep()
{//USB Ethernet adapters and their counters.
  I64 k, any = FALSE;
  CUsbEcm *e;
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].on && usb_fn[k].kind == USB_KIND_ECM)
    {
      any = TRUE;
      "#%d ", k;
      e = NULL;
      if (usb_ecm)
        e = &usb_ecm[k];
      if (!e || !e->up)
      {
        "not attached\n";
        goto ecm_rep_next;
      }
      "MAC %02X:%02X:%02X:%02X:%02X:%02X data i/f alt %d bulk in %d out %d mps %d%s\n",
            e->mac[0], e->mac[1], e->mac[2], e->mac[3], e->mac[4], e->mac[5],
            usb_fn[k].dalt, usb_fn[k].bin, usb_fn[k].bout, usb_fn[k].bmps,
            LstSub(!usb_ops[usb_fn[k].hc].bin_arm, "\0 (no RX on this controller)\0");
      "  RX %d frames, %d dropped, %d errors, %d queued; TX %d frames, %d errors\n",
            e->rx_frames, e->rx_drops, e->rx_err, e->r_in - e->r_out,
            e->tx_frames, e->tx_err;
ecm_rep_next:;
    }
  if (!any)
    "No USB Ethernet adapter\n";
}
