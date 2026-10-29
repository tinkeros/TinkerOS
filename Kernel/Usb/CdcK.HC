#define CDC_RX_RING 4096
#define CDC_RX_XFER 512
#define CDC_TX_BUF  512

#define CDCF_ACM    0
#define CDCF_FTDI   1
#define CDCF_CP210X 2
#define CDCF_CH34X  3
#define CDCF_PL2303 4
#define USB_SER_NFLAVOR 5

class CUsbSerFlavor
{
  Bool (*open)(CUsbFn *f, I64 k);
  Bool (*set_line)(CUsbFn *f, I64 k, I64 baud, I64 bits, I64 parity, I64 stop);
  Bool (*set_ctl)(CUsbFn *f, I64 k, I64 dtr, I64 rts);
  I64 (*rx_fixup)(I64 k, U8 *buf, I64 n, I64 mps);
};
CUsbSerFlavor usb_ser_flavor[USB_SER_NFLAVOR];

class CUsbCdc
{
  I64 flavor, sub, chan;
  I64 baud, bits, parity, stop, dtr, rts;
  U8 *rx_dma, *tx_dma;
  I64 tx_n, tx_t;
  U8 *ring;
  I64 r_in, r_out;
  I64 armed, rx_ovf, rx_err;
  Bool open;
};
CUsbCdc *usb_cdc = NULL;

extern U0 UsbCdcFlavorInit();

U0 UsbCdcBufInit()
{
  if (usb_cdc) return;
  usb_cdc = CAlloc(USB_NFN * sizeof(CUsbCdc));
  UsbCdcFlavorInit;
}

I64 UsbSerId(I64 vid, I64 pid)
{//Vendor USB-serial chip of a VID:PID, -1 if none.
  if (vid == 0x0403)
    return CDCF_FTDI;
  if (vid == 0x10C4 && (pid == 0xEA60 || pid == 0xEA61 || pid == 0xEA70))
    return CDCF_CP210X;
  if (vid == 0x1A86 && (pid == 0x5523 || pid == 0x7522 || pid == 0x7523 || pid == 0xE523) ||
        vid == 0x4348 && pid == 0x5523 || vid == 0x2184 && pid == 0x0057 ||
        vid == 0x9986 && pid == 0x7523)
    return CDCF_CH34X;
  if (vid == 0x067B && (pid == 0x2303 || pid == 0x2304 ||
        pid & 0xFF0F == 0x2303 && pid >= 0x23A3))
    return CDCF_PL2303;
  return -1;
}

U0 UsbLe(U8 *p, I64 v, I64 n)
{
  I64 i;
  for (i = 0; i < n; i++)
  {
    p[i] = v & 0xFF;
    v >>= 8;
  }
}

Bool UsbCdcDevDesc(CUsbFn *f, U8 *d)
{
  return UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_DEV << 8, 0, 18, d) == 18;
}

Bool UsbCdcAcmOpen(CUsbFn *f, I64 k)
{//Nothing to set up: a CDC-ACM device is ready once its interface is picked.
  no_warn f;
  no_warn k;
  return TRUE;
}

Bool UsbCdcAcmSetLine(CUsbFn *f, I64 k, I64 baud, I64 bits, I64 parity, I64 stop)
{//SET_LINE_CODING. A STALL here is not fatal: line coding is optional.
  U8 lc[7];
  no_warn k;
  UsbLe(lc, baud, 4);
  lc[4] = 0;
  if (stop == 2) lc[4] = 2;
  lc[5] = parity;
  lc[6] = bits;
  UsbReqOut(f, 0x21, 0x20, 0, f->ifn, lc, 7);
  return TRUE;
}

Bool UsbCdcAcmSetCtl(CUsbFn *f, I64 k, I64 dtr, I64 rts)
{//SET_CONTROL_LINE_STATE
  I64 v = 0;
  no_warn k;
  if (dtr) v |= 1;
  if (rts) v |= 2;
  UsbReq(f, 0x21, 0x22, v, f->ifn, 0);
  return TRUE;
}

I64 UsbCdcAcmRxFixup(I64 k, U8 *buf, I64 n, I64 mps)
{//ACM has no in-band framing: the payload is the data.
  no_warn k;
  no_warn buf;
  no_warn mps;
  return n;
}

#define FTDI_SIO_RESET       0
#define FTDI_SIO_MODEM_CTRL  1
#define FTDI_SIO_SET_FLOW    2
#define FTDI_SIO_SET_BAUD    3
#define FTDI_SIO_SET_DATA    4
#define FTDI_SIO_SET_LATENCY 9

Bool UsbCdcFtdiOpen(CUsbFn *f, I64 k)
{//bcdDevice: 0x700 and up is the 120 MHz family, except 0x1000 (FT-X).
  CUsbCdc *c = &usb_cdc[k];
  U8 d[18];
  c->sub = 0;
  c->chan = 0;
  if (UsbCdcDevDesc(f, d))
  {
    if (d[13] >= 7 && d[13] != 0x10)
      c->sub = 1;
    if (d[13] == 5 || c->sub)
      c->chan = f->ifn + 1;
  }
  UsbReq(f, 0x40, FTDI_SIO_RESET, 0, c->chan, 0);
  UsbReq(f, 0x40, FTDI_SIO_SET_LATENCY, 2, c->chan, 0);
  UsbReq(f, 0x40, FTDI_SIO_SET_FLOW, 0, c->chan, 0);
  return TRUE;
}

I64 UsbCdcFtdiDiv(I64 baud, Bool hi)
{//Baud divisor with 3 fractional bits (Linux ftdi_sio.c).
  I64 d3, div;
  if (hi && baud >= 1200)
    d3 = (960000000 + baud * 5) / (baud * 10);
  else
    d3 = (48000000 + baud) / (baud * 2);
  div = d3 >> 3 | (0x76514230 >> ((d3 & 7) * 4) & 7) << 14;
  if (div == 1)
    div = 0;
  else if (div == 0x4001)
    div = 1;
  if (hi && baud >= 1200)
    div |= 0x20000;
  return div;
}

Bool UsbCdcFtdiSetLine(CUsbFn *f, I64 k, I64 baud, I64 bits, I64 parity, I64 stop)
{
  CUsbCdc *c = &usb_cdc[k];
  I64 div, idx, data = bits;
  if (baud <= 0) baud = 9600;
  div = UsbCdcFtdiDiv(baud, c->sub);
  idx = div >> 16;
  if (c->chan)
    idx = idx << 8 | c->chan;
  if (stop == 2) data |= 2 << 11;
  data |= parity << 8;
  UsbReq(f, 0x40, FTDI_SIO_SET_BAUD, div & 0xFFFF, idx, 0);
  UsbReq(f, 0x40, FTDI_SIO_SET_DATA, data, c->chan, 0);
  return TRUE;
}

Bool UsbCdcFtdiSetCtl(CUsbFn *f, I64 k, I64 dtr, I64 rts)
{
  I64 v = 0x0300;
  if (dtr) v |= 1;
  if (rts) v |= 2;
  UsbReq(f, 0x40, FTDI_SIO_MODEM_CTRL, v, usb_cdc[k].chan, 0);
  return TRUE;
}

I64 UsbCdcFtdiRxFixup(I64 k, U8 *buf, I64 n, I64 mps)
{//Each bulk-IN packet (up to mps bytes) starts with 2 modem/line-status bytes.
  I64 pos = 0, out = 0, chunk, i;
  no_warn k;
  while (pos < n)
  {
    chunk = n - pos;
    if (chunk > mps) chunk = mps;
    for (i = 2; i < chunk; i++)
    {
      buf[out] = buf[pos + i];
      out++;
    }
    pos += chunk;
  }
  return out;
}

Bool UsbCdcCpOpen(CUsbFn *f, I64 k)
{
  no_warn k;
  UsbReq(f, 0x41, 0x00, 1, f->ifn, 0);
  return TRUE;
}

Bool UsbCdcCpSetLine(CUsbFn *f, I64 k, I64 baud, I64 bits, I64 parity, I64 stop)
{
  U8 b[4];
  I64 st = 0;
  no_warn k;
  if (stop == 2) st = 2;
  UsbLe(b, baud, 4);
  UsbReqOut(f, 0x41, 0x1E, 0, f->ifn, b, 4);
  UsbReq(f, 0x41, 0x03, bits << 8 | parity << 4 | st, f->ifn, 0);
  return TRUE;
}

Bool UsbCdcCpSetCtl(CUsbFn *f, I64 k, I64 dtr, I64 rts)
{
  I64 v = 0x0300;
  no_warn k;
  if (dtr) v |= 1;
  if (rts) v |= 2;
  UsbReq(f, 0x41, 0x07, v, f->ifn, 0);
  return TRUE;
}

I64 UsbCdcChDiv(I64 baud)
{//Register 0x1312 value: divisor << 8 | 0x80 (no buffering) | prescaler.
  I64 a, b, c;
  if (baud == 921600) return 0xF387;
  if (baud == 307200) return 0xD987;
  if (baud <= 0 || baud > 2000000) baud = 9600;
  if (baud > 6000000 / 255)
  {
    b = 3;
    c = 6000000;
  }
  else if (baud > 750000 / 255)
  {
    b = 2;
    c = 750000;
  }
  else if (baud > 93750 / 255)
  {
    b = 1;
    c = 93750;
  }
  else
  {
    b = 0;
    c = 11719;
  }
  a = ClampI64(c / baud, 1, 0xFE);
  if (c / a - baud > baud - c / (a + 1))
    a++;
  return (256 - a) << 8 | 0x80 | b;
}

I64 UsbCdcChLcr(I64 bits, I64 parity, I64 stop)
{//Register 0x2518 value: RX/TX on, data bits, parity, stop bits.
  I64 lcr = 0xC0 | (bits - 5);
  if (parity == 1) lcr |= 0x08;
  else if (parity == 2) lcr |= 0x18;
  else if (parity == 3) lcr |= 0x28;
  else if (parity == 4) lcr |= 0x38;
  if (stop == 2) lcr |= 0x04;
  return lcr;
}

Bool UsbCdcChOpen(CUsbFn *f, I64 k)
{//Version, serial init at 9600 8N1, then no hardware flow control.
  U8 v[2];
  no_warn k;
  UsbReq(f, 0xC0, 0x5F, 0, 0, 2, v);
  UsbReq(f, 0x40, 0xA1, UsbCdcChLcr(8, 0, 1) << 8 | 0x9C, UsbCdcChDiv(9600), 0);
  UsbReq(f, 0x40, 0x9A, 0x0F2C, 0x0007, 0);
  UsbReq(f, 0x40, 0x9A, 0x2727, 0, 0);
  return TRUE;
}

Bool UsbCdcChSetLine(CUsbFn *f, I64 k, I64 baud, I64 bits, I64 parity, I64 stop)
{
  no_warn k;
  UsbReq(f, 0x40, 0x9A, 0x1312, UsbCdcChDiv(baud), 0);
  UsbReq(f, 0x40, 0x9A, 0x2518, UsbCdcChLcr(bits, parity, stop), 0);
  return TRUE;
}

Bool UsbCdcChSetCtl(CUsbFn *f, I64 k, I64 dtr, I64 rts)
{//Modem lines are active low.
  I64 v = 0;
  no_warn k;
  if (dtr) v |= 0x20;
  if (rts) v |= 0x40;
  UsbReq(f, 0x40, 0xA4, ~v & 0xFF, 0, 0);
  return TRUE;
}

#define PL_H   0
#define PL_HX  1
#define PL_HXN 2

I64 UsbCdcPlType(CUsbFn *f)
{
  U8 d[18], b;
  I64 bcd;
  if (!UsbCdcDevDesc(f, d)) return PL_HX;
  if (d[4] == 2 || d[7] != 0x40) return PL_H;
  if (d[2] | d[3] << 8 != 0x200) return PL_HX;
  bcd = d[12] | d[13] << 8;
  if ((bcd == 0x300 || bcd == 0x500) && UsbReq(f, 0xC0, 1, 0x8080, 0, 1, &b) == 1)
    return PL_HX;
  return PL_HXN;
}

Bool UsbCdcPlOpen(CUsbFn *f, I64 k)
{//pl2303_startup + pl2303_open. Baud rates go to the chip directly.
  CUsbCdc *c = &usb_cdc[k];
  U8 b;
  c->sub = UsbCdcPlType(f);
  if (c->sub == PL_HXN)
  {
    UsbReq(f, 0x40, 0x80, 7, 3, 0);
    return TRUE;
  }
  UsbReq(f, 0xC0, 1, 0x8484, 0, 1, &b);
  UsbReq(f, 0x40, 1, 0x0404, 0, 0);
  UsbReq(f, 0xC0, 1, 0x8484, 0, 1, &b);
  UsbReq(f, 0xC0, 1, 0x8383, 0, 1, &b);
  UsbReq(f, 0xC0, 1, 0x8484, 0, 1, &b);
  UsbReq(f, 0x40, 1, 0x0404, 1, 0);
  UsbReq(f, 0xC0, 1, 0x8484, 0, 1, &b);
  UsbReq(f, 0xC0, 1, 0x8383, 0, 1, &b);
  UsbReq(f, 0x40, 1, 0, 1, 0);
  UsbReq(f, 0x40, 1, 1, 0, 0);
  if (c->sub == PL_H)
  {
    UsbReq(f, 0x40, 1, 2, 0x24, 0);
    UsbReq(f, 0x02, USB_REQ_CLR_FEATURE, 0, f->bout, 0);
    UsbReq(f, 0x02, USB_REQ_CLR_FEATURE, 0, f->bin | 0x80, 0);
    (*usb_ops[f->hc].bulk_rst)(f);
  }
  else
  {
    UsbReq(f, 0x40, 1, 2, 0x44, 0);
    UsbReq(f, 0x40, 1, 8, 0, 0);
    UsbReq(f, 0x40, 1, 9, 0, 0);
  }
  return TRUE;
}

U0 UsbCdcFlavorSet(I64 n, U8 *open, U8 *set_line, U8 *set_ctl, U8 *rx_fixup)
{
  usb_ser_flavor[n].open = open;
  usb_ser_flavor[n].set_line = set_line;
  usb_ser_flavor[n].set_ctl = set_ctl;
  usb_ser_flavor[n].rx_fixup = rx_fixup;
}

U0 UsbCdcFlavorInit()
{
  UsbCdcFlavorSet(CDCF_ACM, &UsbCdcAcmOpen, &UsbCdcAcmSetLine, &UsbCdcAcmSetCtl,
        &UsbCdcAcmRxFixup);
  UsbCdcFlavorSet(CDCF_FTDI, &UsbCdcFtdiOpen, &UsbCdcFtdiSetLine, &UsbCdcFtdiSetCtl,
        &UsbCdcFtdiRxFixup);
  UsbCdcFlavorSet(CDCF_CP210X, &UsbCdcCpOpen, &UsbCdcCpSetLine, &UsbCdcCpSetCtl,
        &UsbCdcAcmRxFixup);
  UsbCdcFlavorSet(CDCF_CH34X, &UsbCdcChOpen, &UsbCdcChSetLine, &UsbCdcChSetCtl,
        &UsbCdcAcmRxFixup);
  UsbCdcFlavorSet(CDCF_PL2303, &UsbCdcPlOpen, &UsbCdcAcmSetLine, &UsbCdcAcmSetCtl,
        &UsbCdcAcmRxFixup);
}

I64 UsbCdcFlavor(I64 k)
{
  I64 n = UsbSerId(usb_fn[k].vid, usb_fn[k].pid);
  if (n < 0) return CDCF_ACM;
  return n;
}

Bool UsbCdcLive(I64 k, I64 gen)
{//A stale (k,gen) pair fails here instead of reaching the wrong hardware.
  CUsbFn *f = UsbFnAt(k);
  if (!f) return FALSE;
  return f->kind == USB_KIND_CDC && f->gen == gen;
}

public I64 UsbCdcGen(I64 k)
{
  CUsbFn *f = UsbFnAt(k);
  if (!f) return -1;
  if (f->kind != USB_KIND_CDC) return -1;
  return f->gen;
}

public Bool UsbCdcOpen(I64 k, I64 gen, I64 baud, I64 bits = 8, I64 parity = 0, I64 stop = 1)
{
  CUsbFn *f;
  CUsbCdc *c;
  CUsbSerFlavor *fl;
  UsbCdcBufInit;
  if (!UsbCdcLive(k, gen)) return FALSE;
  f = &usb_fn[k];
  c = &usb_cdc[k];
  if (!c->open)
  {
    c->flavor = UsbCdcFlavor(k);
    if (!c->rx_dma)
    {
      c->rx_dma = CAllocAligned(CDC_RX_XFER, 64, sys_dma_heap);
      c->tx_dma = CAllocAligned(CDC_TX_BUF, 64, sys_dma_heap);
      c->ring = CAlloc(CDC_RX_RING);
    }
    c->r_in = 0;
    c->r_out = 0;
    c->tx_n = 0;
    c->armed = 0;
    c->rx_ovf = 0;
    c->rx_err = 0;
  }
  fl = &usb_ser_flavor[c->flavor];
  (*fl->open)(f, k);
  c->baud = baud;
  c->bits = bits;
  c->parity = parity;
  c->stop = stop;
  (*fl->set_line)(f, k, baud, bits, parity, stop);
  c->open = TRUE;
  return TRUE;
}

public Bool UsbCdcLines(I64 k, I64 gen, I64 dtr, I64 rts)
{
  CUsbCdc *c;
  if (!UsbCdcLive(k, gen)) return FALSE;
  c = &usb_cdc[k];
  if (!c->open) return FALSE;
  c->dtr = dtr;
  c->rts = rts;
  return (*usb_ser_flavor[c->flavor].set_ctl)(&usb_fn[k], k, dtr, rts);
}

Bool UsbCdcSendNow(I64 k)
{//Caller holds usb_lock. Sends tx_dma (tx_n bytes) now and clears tx_n.
  CUsbFn *f = &usb_fn[k];
  CUsbCdc *c = &usb_cdc[k];
  I64 r;
  if (!c->tx_n) return TRUE;
  r = (*usb_ops[f->hc].bulk)(f, 0, c->tx_dma, c->tx_n);
  c->tx_n = 0;
  return r >= 0;
}

public I64 UsbCdcWrite(I64 k, I64 gen, U8 *buf, I64 cnt, I64 timeout_ms = 500)
{//Returns bytes accepted (== cnt on success), -1 if gone or not open.
  CUsbFn *f;
  CUsbCdc *c;
  I64 i = 0, n;
  Bool ok;
  no_warn timeout_ms;
  if (!UsbCdcLive(k, gen)) return -1;
  c = &usb_cdc[k];
  if (!c->open) return -1;
  f = &usb_fn[k];
  while (i < cnt)
  {
    n = CDC_TX_BUF - c->tx_n;
    if (n > cnt - i) n = cnt - i;
    if (!n) return i;
    UsbLock;
    MemCpy(c->tx_dma + c->tx_n, buf + i, n);
    c->tx_n += n;
    c->tx_t = GetTSC;
    i += n;
    ok = TRUE;
    if (c->tx_n >= f->bmps || c->tx_n >= CDC_TX_BUF)
      ok = UsbCdcSendNow(k);
    UsbUnlock;
    if (!ok) return i;
  }
  return i;
}

public Bool UsbCdcFlush(I64 k, I64 gen, I64 timeout_ms = 500)
{
  Bool ok;
  no_warn timeout_ms;
  if (!UsbCdcLive(k, gen) || !usb_cdc[k].open) return FALSE;
  if (!usb_cdc[k].tx_n) return TRUE;
  UsbLock;
  ok = UsbCdcSendNow(k);
  UsbUnlock;
  return ok;
}

public I64 UsbCdcRead(I64 k, I64 gen, U8 *buf, I64 max)
{//Non-blocking: whatever's already in the ring. -1: gone/not open.
  CUsbCdc *c;
  I64 n = 0, avail, in;
  if (!UsbCdcLive(k, gen)) return -1;
  c = &usb_cdc[k];
  if (!c->open) return -1;
  in = c->r_in;
  avail = in - c->r_out;
  if (avail > max) avail = max;
  while (n < avail)
  {
    buf[n] = c->ring[c->r_out & (CDC_RX_RING - 1)];
    c->r_out++;
    n++;
  }
  return n;
}

U0 UsbCdcPoll(I64 k)
{//Called every UsbPoll tick (~5 ms) and inline from Comm's rx_poll op.
  CUsbFn *f = &usb_fn[k];
  CUsbCdc *c;
  I64 n, free, i;
  if (!f->on || f->kind != USB_KIND_CDC) return;
  UsbCdcBufInit;
  c = &usb_cdc[k];
  if (!c->open) return;
  if (!usb_ops[f->hc].bin_arm || !usb_ops[f->hc].bin_poll) return;
  UsbLock;
  if (c->armed)
  {
    n = (*usb_ops[f->hc].bin_poll)(f);
    if (n >= 0)
    {
      n = (*usb_ser_flavor[c->flavor].rx_fixup)(k, c->rx_dma, n, f->bmps);
      free = CDC_RX_RING - (c->r_in - c->r_out);
      if (n > free)
      {
        c->rx_ovf++;
        n = free;
      }
      for (i = 0; i < n; i++)
      {
        c->ring[c->r_in & (CDC_RX_RING - 1)] = c->rx_dma[i];
        c->r_in++;
      }
      c->armed = 0;
    }
    else if (n == -2)
    {
      c->rx_err++;
      c->armed = 0;
    }
  }
  if (!c->armed)
  {
    free = CDC_RX_RING - (c->r_in - c->r_out);
    if (free >= CDC_RX_XFER)
      if ((*usb_ops[f->hc].bin_arm)(f, c->rx_dma, CDC_RX_XFER))
        c->armed = 1;
  }
  if (c->tx_n && GetTSC - c->tx_t > cnts.time_stamp_freq * 2 / 1000)
    UsbCdcSendNow(k);
  UsbUnlock;
}

public U0 UsbCdcClose(I64 k, I64 gen)
{
  CUsbFn *f;
  CUsbCdc *c;
  if (!UsbCdcLive(k, gen)) return;
  f = &usb_fn[k];
  c = &usb_cdc[k];
  if (!c->open) return;
  if (c->tx_n)
  {
    UsbLock;
    UsbCdcSendNow(k);
    UsbUnlock;
  }
  if (c->armed && usb_ops[f->hc].bin_stop)
    (*usb_ops[f->hc].bin_stop)(f);
  c->armed = 0;
  c->open = FALSE;
}

U0 UsbCdcUnplug(I64 k)
{//Called by UsbFnOff when a CDC device is gone: drops our software state.
  CUsbFn *f = &usb_fn[k];
  CUsbCdc *c;
  UsbCdcBufInit;
  c = &usb_cdc[k];
  if (c->armed && usb_ops[f->hc].bin_stop)
    (*usb_ops[f->hc].bin_stop)(f);
  c->armed = 0;
  c->open = FALSE;
  c->tx_n = 0;
}
