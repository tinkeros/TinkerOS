#define XHCI_RING   256
#define XHCI_NSLOT  64
#define XHCI_NPORT  32
#define XHCI_NHC    4

#define XHCI_TRB_NORMAL  1
#define XHCI_TRB_SETUP   2
#define XHCI_TRB_DATA    3
#define XHCI_TRB_STATUS  4
#define XHCI_TRB_ISOCH   5
#define XHCI_TRB_LINK    6
#define XHCI_TRB_SLOT_ON 9
#define XHCI_TRB_SLOT_OFF 10
#define XHCI_TRB_ADDR    11
#define XHCI_TRB_CFG_EP  12
#define XHCI_TRB_EVAL    13
#define XHCI_TRB_RST_EP  14
#define XHCI_TRB_STOP_EP 15
#define XHCI_TRB_SET_DEQ 16
#define XHCI_TRB_EV_XFER 32
#define XHCI_TRB_EV_CMD  33

#define XHCI_TRBF_ISP 0x04
#define XHCI_TRBF_IOC 0x20
#define XHCI_TRBF_IDT 0x40
#define XHCI_TRBF_IN  0x10000
#define XHCI_TRBF_SIA 0x80000000

#define XHCI_CC_OK    1
#define XHCI_CC_SHORT 13

#define XHCI_EP_ISO_OUT  1
#define XHCI_EP_BULK_OUT 2
#define XHCI_EP_ISO_IN   5
#define XHCI_EP_CTL      4
#define XHCI_EP_BULK_IN  6
#define XHCI_EP_INT_IN   7

#define XHCI_PORT_CCS  0x00000001
#define XHCI_PORT_PED  0x00000002
#define XHCI_PORT_PR   0x00000010
#define XHCI_PORT_PP   0x00000200
#define XHCI_PORT_PRC  0x00200000
#define XHCI_PORT_CHG  0x00FE0000
#define XHCI_PORT_KEEP 0x0E00C3E0

class CXhciTrb
{
  U32 lo, hi, sts, ctl;
};

class CXhciRing
{
  CXhciTrb *t;
  I64 enq, cyc;
};

class CXhciDev
{//One slot. Per DCI: last transfer event TRB, its code and residue.
  I64 hci;
  I64 slot, route, depth, rport, tt_slot, tt_port, mps0, cfg;
  U32 *ctx, *in;
  CXhciRing r[32];
  I64 ev[32], cc[32], res[32], sres[32], pend[32], blen[32];
  CUsbIso *iso;
  I64 iso_dci;
};

class CXhciOp
{
  U32 cmd, sts, pgsz, pad0[2], dnctrl;
  U64 crcr;
  U32 pad1[4];
  U64 dcbaap;
  U32 config, pad2[241];
  U32 port[4 * XHCI_NPORT];
};

class CXhciRt
{
  U32 mfindex, pad[7];
  U32 iman, imod, erstsz, pad1;
  U64 erstba, erdp;
};

class CXhciHc
{//One controller: MMIO windows, command and event rings, slots, ports.
  U8 *cap;
  CXhciOp *op;
  CXhciRt *rt;
  U32 *db;
  U64 *dcbaa, *erst;
  CXhciTrb *ev;
  CXhciRing cmd;
  I64 nports, ctx, evq, evc, cmd_ev, cmd_cc, cmd_slot;
  CXhciDev *dv[XHCI_NSLOT];
  U8 pen[XHCI_NPORT];
} xhc[XHCI_NHC];
I64 xhn = 0, xnrst = 0;

U0 XhciRingInit(CXhciRing *r)
{
  if (!r->t)
    r->t = CAllocAligned(XHCI_RING * sizeof(CXhciTrb), 4096, sys_dma_heap);
  else
    MemSet(r->t, 0, XHCI_RING * sizeof(CXhciTrb));
  r->enq = 0;
  r->cyc = 1;
}

CXhciTrb *XhciEnq(CXhciRing *r, I64 lo, I64 hi, I64 sts, I64 ctl)
{//ctl without the cycle bit.
  CXhciTrb *t = &r->t[r->enq], *lk;
  t->lo = lo;
  t->hi = hi;
  t->sts = sts;
  t->ctl = ctl | r->cyc;
  if (++r->enq == XHCI_RING - 1)
  {
    lk = &r->t[XHCI_RING - 1];
    lk->lo = UsbPa(r->t);
    lk->hi = 0;
    lk->sts = 0;
    lk->ctl = XHCI_TRB_LINK << 10 | 2 | r->cyc;
    r->enq = 0;
    r->cyc ^= 1;
  }
  return t;
}

U0 XhciIsoEv(CUsbIso *s, CXhciTrb *e)
{//A transfer event for the isochronous endpoint: which unit, how it went.
  I64 i;
  for (i = 0; i < s->nu; i++)
    if (s->tpa[i] == e->lo)
    {
      s->cc[i] = e->sts >> 24;
      s->res[i] = e->sts & 0xFFFFFF;
      s->done[i] = TRUE;
      return;
    }
}

U0 XhciEvents(CXhciHc *x)
{//Record completions; callers hold usb_lock.
  CXhciTrb *e;
  CXhciDev *dv;
  I64 ty, dci, n = 0;
  while (TRUE)
  {
    e = &x->ev[x->evq];
    if (e->ctl & 1 != x->evc) break;
    ty = e->ctl >> 10 & 63;
    if (ty == XHCI_TRB_EV_CMD)
    {
      x->cmd_cc = e->sts >> 24;
      x->cmd_slot = e->ctl >> 24;
      x->cmd_ev = e->lo;
    }
    else if (ty == XHCI_TRB_EV_XFER && (dv = x->dv[e->ctl >> 24 & (XHCI_NSLOT - 1)]))
    {
      dci = e->ctl >> 16 & 31;
      dv->cc[dci] = e->sts >> 24;
      dv->res[dci] = e->sts & 0xFFFFFF;
      if (dv->cc[dci] == XHCI_CC_SHORT)
        dv->sres[dci] = dv->res[dci];
      dv->ev[dci] = e->lo;
      if (dv->iso && dci == dv->iso_dci)
        XhciIsoEv(dv->iso, e);
    }
    if (++x->evq == XHCI_RING)
    {
      x->evq = 0;
      x->evc ^= 1;
    }
    n++;
  }
  if (n)
    x->rt->erdp = UsbPa(&x->ev[x->evq]) | 8;
}

I64 XhciCmd(CXhciHc *x, I64 lo, I64 ctl)
{//Returns the completion code.
  CXhciTrb *t;
  I64 end = UsbEnd(500);
  x->cmd_ev = 0;
  t = XhciEnq(&x->cmd, lo, 0, 0, ctl);
  x->db[0] = 0;
  while (GetTSC < end)
  {
    XhciEvents(x);
    if (x->cmd_ev == UsbPa(t))
      return x->cmd_cc;
    Yield;
  }
  return 0;
}

U32 *XhciIn(CXhciDev *dv, I64 i)
{//0 input control, 1 slot, 1 + dci endpoint.
  return dv->in(U8 *) + i * xhc[dv->hci].ctx;
}

U32 *XhciOut(CXhciDev *dv, I64 i)
{//0 slot, dci endpoint.
  return dv->ctx(U8 *) + i * xhc[dv->hci].ctx;
}

U0 XhciEpCtx(CXhciDev *dv, I64 dci, I64 type, I64 mps, I64 ival)
{
  U32 *c = XhciIn(dv, 1 + dci);
  XhciRingInit(&dv->r[dci]);
  c[0] = ival << 16;
  c[1] = 3 << 1 | type << 3 | mps << 16;
  c[2] = UsbPa(dv->r[dci].t) | 1;
  c[3] = 0;
  c[4] = mps | mps << 16;
  if (type == XHCI_EP_CTL)
    c[4] = 8;
}

Bool XhciAddr(CXhciDev *dv, I64 spd)
{//Slot and EP0 contexts, then Address Device (sends SET_ADDRESS).
  CXhciHc *x = &xhc[dv->hci];
  U32 *c;
  MemSet(dv->in, 0, 33 * x->ctx);
  MemSet(dv->ctx, 0, 32 * x->ctx);
  c = XhciIn(dv, 0);
  c[1] = 3;
  c = XhciIn(dv, 1);
  c[0] = 1 << 27 | (spd + 1) << 20 | dv->route;
  c[1] = (dv->rport + 1) << 16;
  c[2] = dv->tt_slot | dv->tt_port << 8;
  dv->mps0 = 8;
  if (spd == USB_SPD_HS) dv->mps0 = 64;
  if (spd == USB_SPD_SS) dv->mps0 = 512;
  XhciEpCtx(dv, 1, XHCI_EP_CTL, dv->mps0, 0);
  x->dcbaa[dv->slot] = UsbPa(dv->ctx);
  return XhciCmd(x, UsbPa(dv->in),
        XHCI_TRB_ADDR << 10 | dv->slot << 24) == XHCI_CC_OK;
}

Bool XhciDevNew(CUsbFn *t)
{//Enable a slot and address the device. Hub children route via their hub.
  CXhciHc *x = &xhc[t->hci];
  CXhciDev *dv, *hd;
  CUsbFn *h;
  I64 slot;
  Bool res = FALSE;
  UsbLock;
  if (XhciCmd(x, 0, XHCI_TRB_SLOT_ON << 10) != XHCI_CC_OK ||
        !(slot = x->cmd_slot) || slot >= XHCI_NSLOT)
    goto xd_done;
  if (!(dv = x->dv[slot]))
  {
    dv = CAlloc(sizeof(CXhciDev), sys_dma_heap);
    dv->ctx = CAllocAligned(32 * x->ctx, 4096, sys_dma_heap);
    dv->in = CAllocAligned(33 * x->ctx, 4096, sys_dma_heap);
    x->dv[slot] = dv;
  }
  dv->hci = t->hci;
  dv->slot = slot;
  dv->route = 0;
  dv->depth = 0;
  dv->rport = t->port;
  dv->tt_slot = 0;
  dv->tt_port = 0;
  dv->cfg = 0;
  dv->iso = NULL;
  MemSet(dv->ev, 0, sizeof(I64) * 32 * 6);
  if (t->hub >= 0)
  {
    h = &usb_fn[t->hub];
    hd = h->hx;
    dv->depth = hd->depth + 1;
    dv->route = hd->route | MinI64(t->hport, 15) << (4 * hd->depth);
    dv->rport = hd->rport;
    if (t->speed == USB_SPD_FS || t->speed == USB_SPD_LS)
    {
      if (h->speed == USB_SPD_HS)
      {
        dv->tt_slot = hd->slot;
        dv->tt_port = t->hport;
      }
      else
      {
        dv->tt_slot = hd->tt_slot;
        dv->tt_port = hd->tt_port;
      }
    }
  }
  t->hx = dv;
  if (XhciAddr(dv, t->speed))
    res = TRUE;
  else
  {
    XhciCmd(x, 0, XHCI_TRB_SLOT_OFF << 10 | slot << 24);
    t->hx = NULL;
  }
xd_done:
  UsbUnlock;
  return res;
}

U0 XhciDevOff(CUsbFn *f)
{
  CXhciDev *dv = f->hx;
  CXhciHc *x;
  if (!dv) return;
  x = &xhc[dv->hci];
  UsbLock;
  XhciCmd(x, 0, XHCI_TRB_SLOT_OFF << 10 | dv->slot << 24);
  x->dcbaa[dv->slot] = 0;
  f->hx = NULL;
  UsbUnlock;
}

I64 XhciEpOn(CUsbFn *f, I64 dci, I64 type, I64 mps)
{//Configure Endpoint for one more endpoint (and the hub fields of a hub).
  CXhciDev *dv = f->hx;
  CXhciHc *x = &xhc[dv->hci];
  U32 *c;
  if (dv->r[dci].t && Bt(&dv->cfg, dci))
    return XHCI_CC_OK;
  MemSet(dv->in, 0, 33 * x->ctx);
  c = XhciIn(dv, 0);
  c[1] = 1 | 1 << dci;
  c = XhciIn(dv, 1);
  MemCpy(c, XhciOut(dv, 0), x->ctx);
  if (dci > c[0] >> 27)
    c[0] = c[0] & 0x07FFFFFF | dci << 27;
  if (f->kind == USB_KIND_HUB)
  {
    c[0] |= 1 << 26;
    c[1] = c[1] & 0x00FFFFFF | f->nports << 24;
  }
  XhciEpCtx(dv, dci, type, mps, 6);
  Bts(&dv->cfg, dci);
  return XhciCmd(x, UsbPa(dv->in), XHCI_TRB_CFG_EP << 10 | dv->slot << 24);
}

U0 XhciEpRst(CXhciDev *dv, I64 dci)
{//Stop or un-halt an endpoint and restart it on an empty ring.
  CXhciHc *x = &xhc[dv->hci];
  xnrst++;
  XhciCmd(x, 0, XHCI_TRB_STOP_EP << 10 | dci << 16 | dv->slot << 24);
  XhciCmd(x, 0, XHCI_TRB_RST_EP << 10 | dci << 16 | dv->slot << 24);
  XhciRingInit(&dv->r[dci]);
  XhciCmd(x, UsbPa(dv->r[dci].t) | 1,
        XHCI_TRB_SET_DEQ << 10 | dci << 16 | dv->slot << 24);
  dv->ev[dci] = 0;
}

Bool XhciWait(CXhciDev *dv, I64 dci, CXhciTrb *last, I64 ms)
{//Until the TD's last TRB completes. A short data stage is not the end.
  CXhciHc *x = &xhc[dv->hci];
  I64 cc, end = UsbEnd(ms);
  while (GetTSC < end)
  {
    XhciEvents(x);
    cc = dv->cc[dci];
    if (dv->ev[dci] == UsbPa(last) && (cc == XHCI_CC_OK || cc == XHCI_CC_SHORT))
      return TRUE;
    if (dv->ev[dci] && cc != XHCI_CC_OK && cc != XHCI_CC_SHORT)
      break;
    Yield;
  }
  XhciEpRst(dv, dci);
  return FALSE;
}

I64 XhciCtl(CUsbFn *f, I64 len, I64 dirin)
{
  CXhciDev *dv = f->hx;
  CUsbSetup *su = usb_buf + USB_BUF_SETUP;
  CXhciHc *x;
  CXhciRing *r;
  CXhciTrb *last;
  U32 *c;
  I64 mps, trt = 0;
  if (!dv) return -1;
  x = &xhc[dv->hci];
  if (su->req == USB_REQ_SET_ADDR && !su->rt)
    return 0;
  mps = f->mps0;
  if (f->speed == USB_SPD_SS) mps = 1 << f->mps0;
  if (f->adr && mps != dv->mps0)
  {
    MemSet(dv->in, 0, 33 * x->ctx);
    XhciIn(dv, 0)[1] = 2;
    c = XhciIn(dv, 2);
    MemCpy(c, XhciOut(dv, 1), x->ctx);
    c[1] = c[1] & 0xFFFF | mps << 16;
    if (XhciCmd(x, UsbPa(dv->in),
          XHCI_TRB_EVAL << 10 | dv->slot << 24) == XHCI_CC_OK)
      dv->mps0 = mps;
  }
  r = &dv->r[1];
  if (len)
  {
    trt = 2;
    if (dirin) trt = 3;
  }
  dv->ev[1] = 0;
  dv->sres[1] = 0;
  XhciEnq(r, su(U32 *)[0], su(U32 *)[1], 8,
        XHCI_TRB_SETUP << 10 | XHCI_TRBF_IDT | trt << 16);
  if (len)
    XhciEnq(r, UsbPa(usb_buf + USB_BUF_DATA), 0, len,
          XHCI_TRB_DATA << 10 | XHCI_TRBF_ISP | dirin * XHCI_TRBF_IN);
  last = XhciEnq(r, 0, 0, 0, XHCI_TRB_STATUS << 10 | XHCI_TRBF_IOC |
        (!len || !dirin) * XHCI_TRBF_IN);
  x->db[dv->slot] = 1;
  if (!XhciWait(dv, 1, last, 500))
    return -1;
  return len - dv->sres[1];
}

I64 XhciBulk(CUsbFn *f, I64 dirin, U8 *dp, I64 len)
{//One TRB: buffers are in usb_bd, which never crosses 64K.
  CXhciDev *dv = f->hx;
  CXhciHc *x;
  CXhciTrb *t;
  I64 dci;
  if (len <= 0) return 0;
  if (!dv) return -1;
  x = &xhc[dv->hci];
  if (dirin)
  {
    dci = f->bin * 2 + 1;
    XhciEpOn(f, dci, XHCI_EP_BULK_IN, f->bmps);
  }
  else
  {
    dci = f->bout * 2;
    XhciEpOn(f, dci, XHCI_EP_BULK_OUT, f->bmps);
  }
  dv->ev[dci] = 0;
  dv->sres[dci] = 0;
  t = XhciEnq(&dv->r[dci], UsbPa(dp), 0, len,
        XHCI_TRB_NORMAL << 10 | XHCI_TRBF_IOC | XHCI_TRBF_ISP);
  x->db[dv->slot] = dci;
  if (!XhciWait(dv, dci, t, 2000))
    return -1;
  return len - dv->sres[dci];
}

U0 XhciArm(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  CXhciDev *dv = f->hx;
  I64 dci = f->ep * 2 + 1;
  dv->ev[dci] = 0;
  dv->pend[dci] = UsbPa(XhciEnq(&dv->r[dci],
        UsbPa(usb_buf + USB_BUF_INT + k * USB_INT_SZ), 0, MinI64(f->mps, USB_INT_SZ),
        XHCI_TRB_NORMAL << 10 | XHCI_TRBF_IOC | XHCI_TRBF_ISP));
  xhc[dv->hci].db[dv->slot] = dci;
}

U0 XhciIntInit(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  UsbLock;
  if (f->hx && XhciEpOn(f, f->ep * 2 + 1, XHCI_EP_INT_IN, f->mps) == XHCI_CC_OK)
  {
    f->hq = f->hx;
    XhciArm(k);
  }
  UsbUnlock;
}

U0 XhciIntStop(CUsbFn *f)
{
  CXhciDev *dv = f->hx;
  if (!dv) return;
  UsbLock;
  XhciCmd(&xhc[dv->hci], 0, XHCI_TRB_STOP_EP << 10 |
        (f->ep * 2 + 1) << 16 | dv->slot << 24);
  UsbUnlock;
}

U0 XhciBulkRst(CUsbFn *f)
{
  CXhciDev *dv = f->hx;
  if (!dv) return;
  UsbLock;
  if (f->bin && dv->r[f->bin * 2 + 1].t)
    XhciEpRst(dv, f->bin * 2 + 1);
  if (f->bout && dv->r[f->bout * 2].t)
    XhciEpRst(dv, f->bout * 2);
  UsbUnlock;
}

Bool XhciBinArm(CUsbFn *f, U8 *buf, I64 len)
{//CDC async bulk-IN. Caller holds usb_lock.
  CXhciDev *dv = f->hx;
  I64 dci;
  if (!dv) return FALSE;
  dci = f->bin * 2 + 1;
  if (XhciEpOn(f, dci, XHCI_EP_BULK_IN, f->bmps) != XHCI_CC_OK)
    return FALSE;
  dv->ev[dci] = 0;
  dv->sres[dci] = 0;
  dv->blen[dci] = len;
  dv->pend[dci] = UsbPa(XhciEnq(&dv->r[dci], UsbPa(buf), 0, len,
        XHCI_TRB_NORMAL << 10 | XHCI_TRBF_IOC | XHCI_TRBF_ISP));
  xhc[dv->hci].db[dv->slot] = dci;
  return TRUE;
}

I64 XhciBinPoll(CUsbFn *f)
{//-1 pending, -2 error (endpoint reset done), else bytes transferred.
  CXhciDev *dv = f->hx;
  I64 dci, cc;
  if (!dv) return -2;
  XhciEvents(&xhc[dv->hci]);
  dci = f->bin * 2 + 1;
  if (dv->ev[dci] != dv->pend[dci]) return -1;
  cc = dv->cc[dci];
  if (cc == XHCI_CC_OK || cc == XHCI_CC_SHORT)
    return dv->blen[dci] - dv->sres[dci];
  XhciEpRst(dv, dci);
  return -2;
}

U0 XhciBinStop(CUsbFn *f)
{//Self-locks: called both from usb_lock-held and unlocked contexts.
  CXhciDev *dv = f->hx;
  if (!dv) return;
  UsbLock;
  XhciCmd(&xhc[dv->hci], 0, XHCI_TRB_STOP_EP << 10 |
        (f->bin * 2 + 1) << 16 | dv->slot << 24);
  UsbUnlock;
}

I64 XhciIsoCfg(CUsbFn *f, CUsbIso *s, Bool add)
{//Configure Endpoint: drop the endpoint, and add it as isochronous.
  CXhciDev *dv = f->hx;
  CXhciHc *x = &xhc[dv->hci];
  U32 *c;
  I64 dci = s->dci, ival = s->interval - 1;
  MemSet(dv->in, 0, 33 * x->ctx);
  c = XhciIn(dv, 0);
  if (Bt(&dv->cfg, dci))
    c[0] = 1 << dci;
  c[1] = 1;
  c = XhciIn(dv, 1);
  MemCpy(c, XhciOut(dv, 0), x->ctx);
  if (add)
  {
    if (dci > c[0] >> 27)
      c[0] = c[0] & 0x07FFFFFF | dci << 27;
    XhciIn(dv, 0)[1] |= 1 << dci;
    if (f->speed == USB_SPD_FS || f->speed == USB_SPD_LS)
      ival += 3;
    XhciRingInit(&dv->r[dci]);
    c = XhciIn(dv, 1 + dci);
    c[0] = ival << 16 | s->maxlen >> 16 << 24;
    c[1] = (s->dirin * 4 + XHCI_EP_ISO_OUT) << 3 | (s->mult - 1) << 8 | s->mps << 16;
    c[2] = UsbPa(dv->r[dci].t) | 1;
    c[3] = 0;
    c[4] = s->maxlen | (s->maxlen & 0xFFFF) << 16;
    Bts(&dv->cfg, dci);
  }
  else
    Btr(&dv->cfg, dci);
  return XhciCmd(x, UsbPa(dv->in), XHCI_TRB_CFG_EP << 10 | dv->slot << 24);
}

U0 XhciIsoQ(CXhciDev *dv, CUsbIso *s, I64 i)
{//Queue unit i: an IN buffer, or the next OUT packet.
  U8 *buf = s->buf + i * s->maxlen;
  I64 len, pk, tbc, tlbpc, ctl;
  if (s->dirin)
    len = s->maxlen;
  else
    len = UsbIsoTake(s, buf);
  s->ulen[i] = len;
  pk = MaxI64((len + s->mps - 1) / s->mps, 1);
  tbc = (pk + s->mult - 1) / s->mult - 1;
  tlbpc = (pk - 1) % s->mult;
  ctl = XHCI_TRB_ISOCH << 10 | XHCI_TRBF_IOC | XHCI_TRBF_SIA | tbc << 7 | tlbpc << 16;
  if (s->dirin)
    ctl |= XHCI_TRBF_ISP;
  s->done[i] = FALSE;
  s->tpa[i] = UsbPa(XhciEnq(&dv->r[s->dci], UsbPa(buf), 0, len, ctl));
}

Bool XhciIsoStart(CUsbFn *f, CUsbIso *s)
{
  CXhciDev *dv = f->hx;
  I64 i;
  if (!dv || dv->iso) return FALSE;
  s->dci = s->ep * 2 + s->dirin;
  if (f->speed == USB_SPD_FS || f->speed == USB_SPD_LS)
    s->nu = 64;
  else
    s->nu = USB_ISO_NU;
  s->buf = CAllocAligned(s->nu * s->maxlen, 0x1000, adam_task->code_heap);
  if (!s->buf || s->maxlen > 0x10000) return FALSE;
  if (XhciIsoCfg(f, s, TRUE) != XHCI_CC_OK) return FALSE;
  for (i = 0; i < s->nu; i++)
    XhciIsoQ(dv, s, i);
  s->nxt = 0;
  dv->iso_dci = s->dci;
  dv->iso = s;
  xhc[dv->hci].db[dv->slot] = s->dci;
  return TRUE;
}

I64 XhciIsoPoll(CUsbFn *f, CUsbIso *s, U8 *dst, I64 *lens, I64 max)
{
  CXhciDev *dv = f->hx;
  I64 i, j, n = 0, ln, cc;
  Bool later;
  if (!dv) return 0;
  XhciEvents(&xhc[dv->hci]);
  while (n < max)
  {
    i = s->nxt;
    ln = -1;
    if (!s->done[i])
    {
      later = FALSE;
      for (j = 1; j < s->nu && !later; j++)
        if (s->done[(i + j) % s->nu])
          later = TRUE;
      if (!later) break;
      s->missed++;
    }
    else
    {
      cc = s->cc[i];
      if (cc == XHCI_CC_OK || cc == XHCI_CC_SHORT)
        ln = MaxI64(s->ulen[i] - s->res[i], 0);
      else
        s->errs++;
    }
    if (s->dirin)
    {
      if (ln > 0)
      {
        MemCpy(dst, s->buf + i * s->maxlen, ln);
        dst += ln;
      }
      lens[n] = ln;
    }
    n++;
    s->pkts++;
    s->frames++;
    XhciIsoQ(dv, s, i);
    s->nxt = (i + 1) % s->nu;
  }
  if (n)
    xhc[dv->hci].db[dv->slot] = s->dci;
  return n;
}

U0 XhciIsoStop(CUsbFn *f, CUsbIso *s)
{//Caller holds usb_lock.
  CXhciDev *dv = f->hx;
  if (!dv || dv->iso != s) return;
  dv->iso = NULL;
  XhciCmd(&xhc[dv->hci], 0, XHCI_TRB_STOP_EP << 10 | s->dci << 16 | dv->slot << 24);
  XhciIsoCfg(f, s, FALSE);
}

U0 XhciIntPoll(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  CXhciDev *dv = f->hx;
  I64 dci = f->ep * 2 + 1, cc;
  if (!dv || dv->ev[dci] != dv->pend[dci]) return;
  cc = dv->cc[dci];
  if (cc == XHCI_CC_OK || cc == XHCI_CC_SHORT)
    UsbIntRep(f, usb_buf + USB_BUF_INT + k * USB_INT_SZ);
  else
    XhciEpRst(dv, dci);
  XhciArm(k);
}

U32 XhciPortKeep(CXhciHc *x, I64 p)
{//PORTSC value that changes nothing when written back.
  return x->op->port[p * 4] & XHCI_PORT_KEEP;
}

U0 XhciPortChk(I64 i, I64 p)
{
  CXhciHc *x = &xhc[i];
  I64 k, idx;
  U32 sc = x->op->port[p * 4];
  CUsbFn t;
  if (sc & XHCI_PORT_CHG)
    x->op->port[p * 4] = XhciPortKeep(x, p) | sc & XHCI_PORT_CHG;
  if (!(sc & XHCI_PORT_CCS))
  {
    if (x->pen[p] == 1)
      for (k = 0; k < usb_n; k++)
        if (usb_fn[k].hc == USB_HC_XHCI && usb_fn[k].hci == i &&
              usb_fn[k].port == p && usb_fn[k].hub < 0)
          UsbFnOff(k);
    x->pen[p] = 0;
    return;
  }
  if (x->pen[p] == 1 || x->pen[p] > 4) return;
  x->pen[p] = MaxI64(x->pen[p], 1) + 1;
  if (!(sc & XHCI_PORT_PED))
  {
    x->op->port[p * 4] = XhciPortKeep(x, p) | XHCI_PORT_PR;
    for (k = 0; k < 100 && !(x->op->port[p * 4] & XHCI_PORT_PRC); k++)
      UsbWait(1);
    x->op->port[p * 4] = XhciPortKeep(x, p) | XHCI_PORT_CHG;
    UsbWait(10);
    sc = x->op->port[p * 4];
    if (!(sc & XHCI_PORT_PED))
      return;
  }
  ZeroClass(&t);
  t.hc = USB_HC_XHCI;
  t.hci = i;
  t.port = p;
  t.hub = -1;
  t.speed = sc >> 10 & 15 - 1;
  idx = UsbEnum(&t);
  if (idx >= 0)
  {
    x->pen[p] = 1;
    UsbIntOn(idx);
  }
}

U0 XhciPoll(Bool ports = TRUE)
{
  I64 i, k;
  if (!xhn) return;
  UsbLock;
  for (i = 0; i < xhn; i++)
    XhciEvents(&xhc[i]);
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].hc == USB_HC_XHCI && usb_fn[k].on && usb_fn[k].hq)
      XhciIntPoll(k);
  UsbUnlock;
  for (i = 0; i < xhn && ports; i++)
    for (k = 0; k < xhc[i].nports; k++)
      XhciPortChk(i, k);
}

U0 XhciHandoff(U8 *cap)
{//Take the controller from the BIOS (USB Legacy Support capability).
  U32 *c;
  I64 off = cap(U32 *)[4] >> 16 * 4, k;
  while (off)
  {
    c = cap + off;
    if (UsbRd(c) & 0xFF == 1)
    {
      *c |= 1 << 24;
      for (k = 0; k < 1000 && *c & 1 << 16; k++)
        UsbWait(1);
      c[1] = c[1] & 0x000E1FEE | 0xE0000000;
      return;
    }
    if (!(*c >> 8 & 0xFF)) return;
    off += (*c >> 8 & 0xFF) * 4;
  }
}

Bool XhciStart(I64 bdf)
{
  CXhciHc *x = &xhc[xhn];
  CXhciOp *op;
  U8 *cap;
  I64 b = bdf >> 16, d = bdf >> 8 & 0xFF, f = bdf & 0xFF, bar, k, n;
  U64 *sp;
  bar = PCIReadU32(b, d, f, 0x10);
  if (bar & 6 == 4 && PCIReadU32(b, d, f, 0x14))
    return FALSE;
  bar &= ~0xF;
  PCIWriteU16(b, d, f, 4, PCIReadU16(b, d, f, 4) | 6);
  x->cap = cap = bar + dev.uncached_alias;
  XhciHandoff(cap);
  x->op = op = cap + *cap;
  x->rt = cap + cap(U32 *)[6] & ~0x1F;
  x->db = cap + cap(U32 *)[5] & ~3;
  x->ctx = 32;
  if (UsbRd(cap + 0x10) & 4) x->ctx = 64;
  x->nports = MinI64(cap(U32 *)[1] >> 24, XHCI_NPORT);
  op->cmd &= ~1;
  for (k = 0; k < 20 && !(UsbRd(&op->sts) & 1); k++)
    UsbWait(1);
  op->cmd = 2;
  for (k = 0; k < 100 && (UsbRd(&op->cmd) & 2 || op->sts & 0x800); k++)
    UsbWait(1);
  op->config = MinI64(UsbRd(cap + 4) & 0xFF, XHCI_NSLOT - 1);
  x->dcbaa = CAllocAligned(XHCI_NSLOT * 8, 4096, sys_dma_heap);
  k = cap(U32 *)[2];
  if (n = (k >> 21 & 0x1F) << 5 | k >> 27)
  {
    sp = CAllocAligned(n * 8, 4096, sys_dma_heap);
    for (k = 0; k < n; k++)
      sp[k] = UsbPa(CAllocAligned(4096, 4096, sys_dma_heap));
    x->dcbaa[0] = UsbPa(sp);
  }
  op->dcbaap = UsbPa(x->dcbaa);
  XhciRingInit(&x->cmd);
  op->crcr = UsbPa(x->cmd.t) | 1;
  x->ev = CAllocAligned(XHCI_RING * sizeof(CXhciTrb), 4096, sys_dma_heap);
  x->evq = 0;
  x->evc = 1;
  x->erst = CAllocAligned(16, 64, sys_dma_heap);
  x->erst[0] = UsbPa(x->ev);
  x->erst[1] = XHCI_RING;
  x->rt->erstsz = 1;
  x->rt->erdp = UsbPa(x->ev);
  x->rt->erstba = UsbPa(x->erst);
  op->cmd = 1;
  for (k = 0; k < 20 && UsbRd(&op->sts) & 1; k++)
    UsbWait(1);
  MemSet(x->pen, 0, XHCI_NPORT);
  for (k = 0; k < x->nports; k++)
    if (!(op->port[k * 4] & XHCI_PORT_PP))
      op->port[k * 4] = XHCI_PORT_PP;
  UsbWait(100);
  return TRUE;
}

Bool XhciInit()
{//All xHCI controllers (a chipset one plus an add-in card, say).
  I64 n, bdf;
  if (xhn) return FALSE;
  UsbBufInit;
  usb_ops[USB_HC_XHCI].ctl = &XhciCtl;
  usb_ops[USB_HC_XHCI].bulk = &XhciBulk;
  usb_ops[USB_HC_XHCI].int_init = &XhciIntInit;
  usb_ops[USB_HC_XHCI].int_stop = &XhciIntStop;
  usb_ops[USB_HC_XHCI].bulk_rst = &XhciBulkRst;
  usb_ops[USB_HC_XHCI].dev_new = &XhciDevNew;
  usb_ops[USB_HC_XHCI].dev_off = &XhciDevOff;
  usb_ops[USB_HC_XHCI].bin_arm = &XhciBinArm;
  usb_ops[USB_HC_XHCI].bin_poll = &XhciBinPoll;
  usb_ops[USB_HC_XHCI].bin_stop = &XhciBinStop;
  usb_ops[USB_HC_XHCI].iso_start = &XhciIsoStart;
  usb_ops[USB_HC_XHCI].iso_poll = &XhciIsoPoll;
  usb_ops[USB_HC_XHCI].iso_stop = &XhciIsoStop;
  for (n = 0; xhn < XHCI_NHC && (bdf = PCIClassFind(USB_PCI_XHCI, n)) != -1; n++)
    if (XhciStart(bdf))
      xhn++;
  XhciPoll;
  return xhn > 0;
}
