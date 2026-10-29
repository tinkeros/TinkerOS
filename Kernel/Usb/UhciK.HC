#define UHCI_CMD     0x00
#define UHCI_STS     0x02
#define UHCI_FRNUM   0x06
#define UHCI_FRBASE  0x08
#define UHCI_SOFMOD  0x0C
#define UHCI_PORT1   0x10
#define UHCI_BAR4    0x20
#define UHCI_RS      0x01
#define UHCI_HCRESET 0x02
#define UHCI_GRESET  0x04
#define UHCI_MAXP    0x80
#define UHCI_PORT_PR     0x0200
#define UHCI_PORT_CSCPED 0x000A
#define UHCI_PORT_PED    0x0004
#define UHCI_QH 2
#define UHCI_T  1
#define UHCI_PID_SETUP 0x2D
#define UHCI_PID_IN    0x69
#define UHCI_PID_OUT   0xE1
#define UHCI_TD_CNT 68
#define UHCI_BULK_CHUNK 512
#define UHCI_NHC 4

class CUhciTd
{
  U32 link;
  union
  {
    U32 ctrl;
    U32 actlen:11;
    U32 rsvd0:6;
    U32 bitstuff:1;
    U32 crc_to:1;
    U32 nak:1;
    U32 babble:1;
    U32 buf_err:1;
    U32 stall:1;
    U32 active:1;
    U32 ioc:1;
    U32 ios:1;
    U32 ls:1;
    U32 c_err:2;
  }
  union
  {
    U32 tok;
    U32 pid:8;
    U32 adr:7;
    U32 ep:4;
    U32 tog:1;
    U32 rsvd1:1;
    U32 maxlen:11;
  }
  U32 buf;
};

class CUhciQh
{
  U32 head;
  union
  {
    U32 elem;
    U32 elem_t:1;
  }
  U32 sw0, sw1;
};

class CUhciHc
{
  I64 io;
  U32 *fl;
  CUhciQh *qh;
  CUhciTd *ts;
  U8 pen[2];
};

CUhciHc uhc[UHCI_NHC];
I64 uhn = 0;

U0 UhciRst(CUhciHc *u)
{
  I64 k;
  OutU16(u->io + UHCI_CMD, UHCI_GRESET);
  UsbWait(50);
  OutU16(u->io + UHCI_CMD, 0);
  UsbWait(10);
  OutU16(u->io + UHCI_CMD, UHCI_HCRESET);
  for (k = 0; k < 100 && InU16(u->io + UHCI_CMD) & UHCI_HCRESET; k++)
    UsbWait(1);
}

U0 UhciPortRst(CUhciHc *u, I64 p)
{
  I64 prt = u->io + UHCI_PORT1 + p * 2;
  OutU16(prt, UHCI_PORT_PR);
  UsbWait(50);
  OutU16(prt, 0);
  UsbWait(10);
  OutU16(prt, UHCI_PORT_PED | UHCI_PORT_CSCPED);
  UsbWait(10);
}

U0 UhciTdSet(CUhciTd *td, I64 pd, CUsbFn *f, I64 ep, I64 tog, I64 maxlen, U32 buf)
{
  td->tok = 0;
  td->pid = pd;
  td->adr = f->adr;
  td->ep = ep;
  td->tog = tog;
  td->maxlen = maxlen;
  td->ctrl = 0;
  td->ls = f->speed == USB_SPD_LS;
  td->active = 1;
  td->c_err = 3;
  td->buf = buf;
  td->link = UHCI_T;
}

Bool UhciTdErr(CUhciTd *td)
{
  return td->active || td->stall || td->babble || td->buf_err ||
      td->crc_to || td->bitstuff;
}

U0 UhciLink(I64 i)
{//Frame list -> each interrupt QH -> control/bulk QH.
  CUhciHc *u = &uhc[i];
  I64 k;
  U32 nxt = UsbPa(u->qh) | UHCI_QH;
  for (k = usb_n - 1; k >= 0; k--)
    if (usb_fn[k].hc == USB_HC_UHCI && usb_fn[k].hci == i && usb_fn[k].hq)
    {
      usb_fn[k].hq(CUhciQh *)->head = nxt;
      nxt = UsbPa(usb_fn[k].hq) | UHCI_QH;
    }
  u->qh->head = UHCI_T;
  for (k = 0; k < 1024; k++)
    u->fl[k] = nxt;
}

U0 UhciSetup(I64 i)
{
  CUhciHc *u = &uhc[i];
  u->qh = CAllocAligned(sizeof(CUhciQh), 16, sys_dma_heap);
  u->ts = CAllocAligned(UHCI_TD_CNT * sizeof(CUhciTd), 16, sys_dma_heap);
  u->fl = CAllocAligned(4096, 4096, sys_dma_heap);
  u->pen[0] = 0;
  u->pen[1] = 0;
  u->qh->head = UHCI_T;
  u->qh->elem = UHCI_T;
  UhciLink(i);
  OutU32(u->io + UHCI_FRBASE, UsbPa(u->fl));
  OutU8(u->io + UHCI_SOFMOD, 0x40);
  OutU16(u->io + UHCI_FRNUM, 0);
  OutU16(u->io + UHCI_STS, 0x3F);
  OutU16(u->io + UHCI_CMD, UHCI_RS | UHCI_MAXP);
  UsbWait(2);
}

I64 UhciGo(CUhciHc *u, CUhciTd *first)
{
  I64 end = UsbEnd(300);
  u->qh->elem = UsbPa(first);
  while (!u->qh->elem_t && GetTSC < end)
    Yield;
  if (!u->qh->elem_t)
  {
    u->qh->elem = UHCI_T;
    UsbWait(40);
    return 0;
  }
  return 1;
}

I64 UhciCtl(CUsbFn *f, I64 len, I64 dirin)
{
  CUhciHc *u = &uhc[f->hci];
  CUhciTd *ts = u->ts;
  I64 n = 1, off = 0, ln, k, got = 0, last, tg = 1, spid, dpid;
  spid = UHCI_PID_IN;
  if (dirin && len > 0) spid = UHCI_PID_OUT;
  UhciTdSet(&ts[0], UHCI_PID_SETUP, f, 0, 0, 7, UsbPa(usb_buf + USB_BUF_SETUP));
  while (off < len && n < UHCI_TD_CNT - 1)
  {
    ln = len - off;
    if (ln > f->mps0) ln = f->mps0;
    dpid = UHCI_PID_OUT;
    if (dirin) dpid = UHCI_PID_IN;
    UhciTdSet(&ts[n], dpid, f, 0, tg, ln - 1, UsbPa(usb_buf + USB_BUF_DATA + off));
    tg = 1 - tg;
    off += ln;
    n++;
  }
  last = n;
  UhciTdSet(&ts[last], spid, f, 0, 1, 0x7FF, 0);
  for (k = 0; k < last; k++)
    ts[k].link = UsbPa(&ts[k + 1]);
  if (!UhciGo(u, &ts[0]))
    return -1;
  for (k = 0; k <= last; k++)
  {
    if (UhciTdErr(&ts[k]))
      return -1;
    if (k > 0 && k < last && ts[k].actlen != 0x7FF)
      got += ts[k].actlen + 1;
  }
  return got;
}

I64 UhciBulk(CUsbFn *f, I64 dirin, U8 *dp, I64 len)
{
  CUhciHc *u = &uhc[f->hci];
  CUhciTd *ts = u->ts;
  I64 n = 0, off = 0, ln, k, tg, ep, got = 0, last, dpid;
  if (len <= 0) return 0;
  if (dirin)
  {
    tg = f->btog_i;
    ep = f->bin;
    dpid = UHCI_PID_IN;
  }
  else
  {
    tg = f->btog_o;
    ep = f->bout;
    dpid = UHCI_PID_OUT;
  }
  while (off < len && n < UHCI_TD_CNT - 1)
  {
    ln = len - off;
    if (ln > UHCI_BULK_CHUNK) ln = UHCI_BULK_CHUNK;
    UhciTdSet(&ts[n], dpid, f, ep, tg, ln - 1, UsbPa(dp + off));
    tg = 1 - tg;
    off += ln;
    n++;
  }
  last = n;
  for (k = 0; k < last - 1; k++)
    ts[k].link = UsbPa(&ts[k + 1]);
  if (!UhciGo(u, &ts[0]))
    return -1;
  for (k = 0; k < last; k++)
  {
    if (UhciTdErr(&ts[k]))
      return -1;
    got += ts[k].actlen + 1;
  }
  if (dirin) f->btog_i = tg;
  else f->btog_o = tg;
  return got;
}

U0 UhciArm(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  UhciTdSet(f->ht, UHCI_PID_IN, f, f->ep, f->tog, MinI64(f->mps, USB_INT_SZ) - 1,
      UsbPa(usb_buf + USB_BUF_INT + k * USB_INT_SZ));
  f->hq(CUhciQh *)->elem = UsbPa(f->ht);
}

U0 UhciIntInit(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  f->hq = CAllocAligned(sizeof(CUhciQh), 16, sys_dma_heap);
  f->ht = CAllocAligned(sizeof(CUhciTd), 16, sys_dma_heap);
  UhciArm(k);
  UsbLock;
  UhciLink(f->hci);
  UsbUnlock;
}

U0 UhciBulkRst(CUsbFn *f)
{
  f->btog_i = 0;
  f->btog_o = 0;
}

U0 UhciIntStop(CUsbFn *f)
{
  f->hq(CUhciQh *)->elem = UHCI_T;
}

U0 UhciIntPoll(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  CUhciTd *td = f->ht;
  if (td->active || !f->hq(CUhciQh *)->elem_t) return;
  if (!UhciTdErr(td))
    UsbIntRep(f, usb_buf + USB_BUF_INT + k * USB_INT_SZ);
  f->tog = 1 - f->tog;
  UhciArm(k);
}

U0 UhciPortChk(I64 i, I64 p)
{
  CUhciHc *u = &uhc[i];
  I64 prt = u->io + UHCI_PORT1 + p * 2, k, idx;
  U32 sc = InU16(prt);
  CUsbFn t;
  if (!Bt(&sc, 0))
  {
    if (u->pen[p] == 1)
    {
      for (k = 0; k < usb_n; k++)
        if (usb_fn[k].hc == USB_HC_UHCI && usb_fn[k].hci == i &&
              usb_fn[k].port == p && usb_fn[k].hub < 0)
          UsbFnOff(k);
      u->pen[p] = 0;
      OutU16(prt, sc & UHCI_PORT_PED | UHCI_PORT_CSCPED);
    }
    return;
  }
  if (u->pen[p]) return;
  u->pen[p] = 2;
  UhciPortRst(u, p);
  ZeroClass(&t);
  t.hc = USB_HC_UHCI;
  t.hci = i;
  t.port = p;
  t.hub = -1;
  t.speed = USB_SPD_FS;
  if (Bt(&sc, 8))
    t.speed = USB_SPD_LS;
  idx = UsbEnum(&t);
  if (idx >= 0)
  {
    u->pen[p] = 1;
    UsbIntOn(idx);
  }
}

U0 UhciPoll(Bool ports = TRUE)
{
  I64 i, k;
  for (i = 0; i < uhn && ports; i++)
  {
    UhciPortChk(i, 0);
    UhciPortChk(i, 1);
  }
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].hc == USB_HC_UHCI && usb_fn[k].on && usb_fn[k].hq)
      UhciIntPoll(k);
}

Bool UhciInit()
{//All UHCI controllers (ICH companions included). Call after EhciInit.
  I64 bdf, b, d, f;
  if (uhn) return FALSE;
  UsbBufInit;
  usb_ops[USB_HC_UHCI].ctl = &UhciCtl;
  usb_ops[USB_HC_UHCI].bulk = &UhciBulk;
  usb_ops[USB_HC_UHCI].int_init = &UhciIntInit;
  usb_ops[USB_HC_UHCI].int_stop = &UhciIntStop;
  usb_ops[USB_HC_UHCI].bulk_rst = &UhciBulkRst;
  while (uhn < UHCI_NHC && (bdf = PCIClassFind(USB_PCI_UHCI, uhn)) != -1)
  {
    b = bdf >> 16;
    d = bdf >> 8 & 0xFF;
    f = bdf & 0xFF;
    PCIWriteU16(b, d, f, 0xC0, 0x8F00);
    PCIWriteU16(b, d, f, 4, PCIReadU16(b, d, f, 4) | 5);
    uhc[uhn].io = PCIReadU32(b, d, f, UHCI_BAR4) & 0xFFE0;
    UhciRst(&uhc[uhn]);
    UhciSetup(uhn);
    uhn++;
  }
  UhciPoll;
  return uhn > 0;
}
