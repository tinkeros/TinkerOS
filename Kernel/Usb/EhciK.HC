#define EHCI_T      1
#define EHCI_QH     2
#define EHCI_PID_OUT   0
#define EHCI_PID_IN    1
#define EHCI_PID_SETUP 2
#define EHCI_TD_CNT 4
#define EHCI_TD_ALIGN  64
#define EHCI_QH_ALIGN  128
#define EHCI_ITD_ALIGN 128
#define EHCI_NPIPE  64
#define EHCI_NPORT  16
#define EHCI_NHC    4

#define EHCI_PORT_CCS 0x0001
#define EHCI_PORT_PE  0x0004
#define EHCI_PORT_RWC 0x002A
#define EHCI_PORT_PR  0x0100
#define EHCI_PORT_LS  0x0C00
#define EHCI_PORT_LS_K 0x0400
#define EHCI_PORT_PP  0x1000
#define EHCI_PORT_PO  0x2000

class CEhciTd
{
  U32 next, alt;
  union
  {
    U32 tok;
    U32 ping:1;
    U32 sts:1;
    U32 mmf:1;
    U32 xact:1;
    U32 babble:1;
    U32 buf_err:1;
    U32 halted:1;
    U32 active:1;
    U32 pid:2;
    U32 c_err:2;
    U32 c_page:3;
    U32 ioc:1;
    U32 len:15;
    U32 tog:1;
  }
  U32 buf[5], xbuf[5], pad[3];
};

class CEhciQh
{
  U32 head;
  union
  {
    U32 ch;
    U32 adr:7;
    U32 inact:1;
    U32 ep:4;
    U32 spd:2;
    U32 dtc:1;
    U32 h:1;
    U32 mpl:11;
    U32 ctl_ep:1;
    U32 nak_rl:4;
  }
  union
  {
    U32 caps;
    U32 s_mask:8;
    U32 c_mask:8;
    U32 hub:7;
    U32 hport:7;
    U32 mult:2;
  }
  U32 cur;
  CEhciTd ov;
};

class CEhciCap
{
  U8 caplen, rsvd;
  U16 hciver;
  union
  {
    U32 hcs;
    U32 n_ports:4;
    U32 ppc:1;
  }
  union
  {
    U32 hcc;
    U32 ac64:1;
    U32 pfl:1;
    U32 asp:1;
    U32 rsvd1:1;
    U32 ist:4;
    U32 eecp:8;
  }
};

class CEhciOp
{
  union
  {
    U32 cmd;
    U32 rs:1;
    U32 hcreset:1;
  }
  union
  {
    U32 sts;
    U32 usbint:1;
    U32 err:1;
    U32 pcd:1;
    U32 flr:1;
    U32 hse:1;
    U32 iaa:1;
    U32 rsvd0:6;
    U32 halted:1;
  }
  U32 intr, frindex, ctrlds, plist, alist, rsvd[9], cfgflag;
  U32 port[15];
};

class CEhciHc
{//qa: async ring anchor, pa: periodic anchor, qp/qk: async pipes by key.
  CEhciOp *op;
  I64 nports, qn;
  U32 *fl;
  CEhciQh *qa, *pa, *qp[EHCI_NPIPE];
  I64 qk[EHCI_NPIPE];
  U8 pen[EHCI_NPORT];
} ehc[EHCI_NHC];
I64 ehn = 0;
CEhciTd *ets;

U0 EhciTdSet(CEhciTd *td, I64 pid, I64 tog, I64 len, U8 *buf)
{
  I64 i, p = UsbPa(buf);
  MemSet(td, 0, sizeof(CEhciTd));
  td->next = EHCI_T;
  td->alt = EHCI_T;
  td->pid = pid;
  td->tog = tog;
  td->len = len;
  td->c_err = 3;
  if (buf)
  {
    td->buf[0] = p;
    for (i = 1; i < 5; i++)
      td->buf[i] = p & ~0xFFF + i * 0x1000;
  }
  td->active = 1;
}

U0 EhciQhDev(CEhciQh *qh, CUsbFn *f, I64 ep)
{//A full/low-speed device behind a HS hub is reached by split transactions.
  qh->adr = f->adr;
  qh->spd = f->speed;
  qh->hub = 0;
  qh->hport = 0;
  qh->ctl_ep = 0;
  if (f->speed != USB_SPD_HS)
  {
    qh->hub = f->tt_adr;
    qh->hport = f->tt_port;
    qh->ctl_ep = !ep;
  }
}

CEhciQh *EhciQhNew(CUsbFn *f, I64 ep, I64 mps)
{
  CEhciQh *qh = CAllocAligned(96, EHCI_QH_ALIGN, sys_dma_heap);
  if (f)
    EhciQhDev(qh, f, ep);
  qh->ep = ep;
  qh->mpl = mps;
  qh->mult = 1;
  qh->head = EHCI_T;
  qh->ov.next = EHCI_T;
  qh->ov.alt = EHCI_T;
  return qh;
}

Bool EhciIdle(CEhciQh *qh)
{//The HC writes a qTD back before the overlay: wait for both.
  I64 end = UsbEnd(10);
  while ((qh->ov.active || !(qh->ov.next & EHCI_T)) && GetTSC < end)
    Yield;
  return !qh->ov.active;
}

CEhciQh *EhciPipe(CUsbFn *f, I64 ep, I64 dirin, I64 mps)
{//One QH per endpoint and direction, kept in the async ring.
  CEhciHc *e = &ehc[f->hci];
  I64 k, key = f->adr << 8 | ep << 1 | dirin;
  CEhciQh *qh;
  for (k = 0; k < e->qn; k++)
    if (e->qk[k] == key)
    {
      qh = e->qp[k];
      if (qh->spd != f->speed || f->speed != USB_SPD_HS &&
            (qh->hub != f->tt_adr || qh->hport != f->tt_port))
      {
        EhciIdle(qh);
        EhciQhDev(qh, f, ep);
      }
      qh->mpl = mps;
      return qh;
    }
  qh = EhciQhNew(f, ep, mps);
  qh->dtc = !ep;
  qh->nak_rl = 5;
  qh->head = e->qa->head;
  e->qa->head = UsbPa(qh) | EHCI_QH;
  e->qk[e->qn] = key;
  e->qp[e->qn++] = qh;
  return qh;
}

Bool EhciRun(CEhciQh *qh, CEhciTd *first, CEhciTd *last)
{
  I64 tog, end;
  EhciIdle(qh);
  tog = qh->ov.tog;
  qh->ov.tok = 0;
  qh->ov.tog = tog;
  qh->ov.next = UsbPa(first);
  end = UsbEnd(300);
  while (last->active && !qh->ov.halted && GetTSC < end)
    Yield;
  if (last->active || qh->ov.halted)
  {
    qh->ov.next = EHCI_T;
    return FALSE;
  }
  EhciIdle(qh);
  return TRUE;
}

I64 EhciCtl(CUsbFn *f, I64 len, I64 dirin)
{
  CEhciQh *qh = EhciPipe(f, 0, 0, f->mps0);
  I64 n = 0, spid = EHCI_PID_IN;
  EhciTdSet(&ets[0], EHCI_PID_SETUP, 0, 8, usb_buf + USB_BUF_SETUP);
  if (len)
  {
    n = 1;
    EhciTdSet(&ets[1], dirin, 1, len, usb_buf + USB_BUF_DATA);
    if (dirin) spid = EHCI_PID_OUT;
  }
  EhciTdSet(&ets[n + 1], spid, 1, 0, NULL);
  ets[0].next = UsbPa(&ets[1]);
  if (n)
  {
    ets[1].next = UsbPa(&ets[2]);
    ets[1].alt = UsbPa(&ets[2]);
  }
  if (!EhciRun(qh, &ets[0], &ets[n + 1]))
    return -1;
  return len - ets[1].len * n;
}

I64 EhciBulk(CUsbFn *f, I64 dirin, U8 *dp, I64 len)
{
  CEhciQh *qh;
  if (len <= 0) return 0;
  if (dirin)
    qh = EhciPipe(f, f->bin, 1, f->bmps);
  else
    qh = EhciPipe(f, f->bout, 0, f->bmps);
  EhciTdSet(&ets[0], dirin, 0, len, dp);
  if (!EhciRun(qh, &ets[0], &ets[0]))
    return -1;
  return len - ets[0].len;
}

U0 EhciArm(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  CEhciQh *qh = f->hq;
  I64 tog = qh->ov.tog;
  EhciTdSet(f->ht, EHCI_PID_IN, 0, MinI64(f->mps, USB_INT_SZ),
      usb_buf + USB_BUF_INT + k * USB_INT_SZ);
  qh->ov.tok = 0;
  qh->ov.tog = tog;
  qh->ov.next = UsbPa(f->ht);
}

U0 EhciIntInit(I64 k)
{//Interrupt QHs hang off the periodic anchor, polled every frame.
  CUsbFn *f = &usb_fn[k];
  CEhciHc *e = &ehc[f->hci];
  CEhciQh *qh = EhciQhNew(f, f->ep, f->mps);
  qh->s_mask = 1;
  if (f->speed != USB_SPD_HS)
    qh->c_mask = 0x1C;
  f->hq = qh;
  f->ht = CAllocAligned(sizeof(CEhciTd), EHCI_TD_ALIGN, sys_dma_heap);
  EhciArm(k);
  qh->head = e->pa->head;
  e->pa->head = UsbPa(qh) | EHCI_QH;
}

U0 EhciBulkRst(CUsbFn *f)
{
  UsbLock;
  if (f->bin)
    EhciPipe(f, f->bin, 1, f->bmps)->ov.tog = 0;
  if (f->bout)
    EhciPipe(f, f->bout, 0, f->bmps)->ov.tog = 0;
  UsbUnlock;
}

U0 EhciIntStop(CUsbFn *f)
{
  f->hq(CEhciQh *)->ov.next = EHCI_T;
}

U0 EhciIntPoll(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  CEhciTd *td = f->ht;
  if (td->active || !EhciIdle(f->hq)) return;
  if (!td->halted)
    UsbIntRep(f, usb_buf + USB_BUF_INT + k * USB_INT_SZ);
  EhciArm(k);
}

Bool EhciBinArm(CUsbFn *f, U8 *buf, I64 len)
{//CDC async bulk-IN on the endpoint's async-ring QH. Caller holds usb_lock.
  CEhciQh *qh = EhciPipe(f, f->bin, 1, f->bmps);
  CEhciTd *td = f->bht;
  I64 tog;
  if (!td)
  {
    td = CAllocAligned(sizeof(CEhciTd), EHCI_TD_ALIGN, sys_dma_heap);
    f->bht = td;
  }
  f->blen = len;
  EhciTdSet(td, EHCI_PID_IN, 0, len, buf);
  tog = qh->ov.tog;
  qh->ov.tok = 0;
  qh->ov.tog = tog;
  qh->ov.next = UsbPa(td);
  return TRUE;
}

I64 EhciBinPoll(CUsbFn *f)
{//-1 pending, -2 error, else bytes transferred. Caller holds usb_lock.
  CEhciTd *td = f->bht;
  CEhciQh *qh;
  if (!td) return -2;
  if (td->active) return -1;
  qh = EhciPipe(f, f->bin, 1, f->bmps);
  if (!EhciIdle(qh)) return -1;
  if (td->halted)
  {
    qh->ov.tok = 0;
    return -2;
  }
  return f->blen - td->len;
}

U0 EhciBinStop(CUsbFn *f)
{//No locking, same as EhciIntStop: EHCI hardware state needs none here.
  if (f->bht)
    f->bht(CEhciTd *)->next = EHCI_T;
}

#define EHCI_ITD_ACT  0x80000000
#define EHCI_ITD_ERR  0x70000000
#define EHCI_SITD_ACT 0x80
#define EHCI_SITD_ERR 0x7C
#define EHCI_TYPE_SITD 4

class CEhciItd
{//EHCI 3.3, plus the 64-bit extension dwords. 128 bytes, 32-aligned.
  U32 next, st[8], bp[7], xbp[7], pad[9];
};

class CEhciSitd
{//EHCI 3.4, plus the 64-bit extension dwords. Uses the first 36 of 128 bytes.
  U32 next, caps, sched, st, bp[2], back, xbp[2], pad[23];
};

I64 EhciFrame(CEhciHc *e)
{
  return UsbRd(&e->op->frindex) >> 3 & 1023;
}

U0 EhciIsoArm(CEhciHc *e, CUsbFn *f, CUsbIso *s, I64 i, I64 slot)
{//Unit i: set it up for its next frame, then link it into frame list slot.
  CEhciItd *td = s->td + i * sizeof(CEhciItd);
  CEhciSitd *sd = td;
  U8 *buf = s->buf + i * s->fr_bytes;
  I64 j, n, off, cnt, pa = UsbPa(buf);
  MemSet(td, 0, sizeof(CEhciItd));
  if (s->split)
  {
    sd->caps = s->dirin << 31 | f->tt_port << 24 | f->tt_adr << 16 |
          s->ep << 8 | f->adr;
    if (s->dirin)
    {
      n = s->maxlen;
      sd->sched = 0xFC << 8 | 1;
      sd->bp[1] = pa + 0x1000;
    }
    else
    {
      n = UsbIsoTake(s, buf);
      cnt = MaxI64((n + 187) / 188, 1);
      sd->sched = 1 << cnt - 1;
      sd->bp[1] = (pa + 0x1000) | cnt;
      if (cnt > 1)
        sd->bp[1] |= 1 << 3;
    }
    s->ulen[i] = n;
    sd->bp[0] = pa;
    sd->back = 1;
    sd->st = n << 16 | EHCI_SITD_ACT;
    td->next = e->fl[slot];
    s->slot[i] = slot;
    e->fl[slot] = UsbPa(td) | EHCI_TYPE_SITD;
    return;
  }
  for (j = 0; j < s->per_fr; j++)
  {
    off = j * s->maxlen;
    if (s->dirin)
      n = s->maxlen;
    else
      n = UsbIsoTake(s, buf + off);
    td->st[j * s->step] = EHCI_ITD_ACT | n << 16 | off;
  }
  for (j = 0; j < 7; j++)
    td->bp[j] = pa + j * 0x1000;
  td->bp[0] |= s->ep << 8 | f->adr;
  td->bp[1] |= s->dirin << 11 | s->mps;
  td->bp[2] |= s->mult;
  td->next = e->fl[slot];
  s->slot[i] = slot;
  e->fl[slot] = UsbPa(td);
}

U0 EhciIsoUnlink(CEhciHc *e, CUsbIso *s, I64 i)
{//Take unit i out of its slot (it may be behind another stream's).
  U8 *td = s->td + i * sizeof(CEhciItd);
  U32 *p, v;
  I64 n;
  if (s->slot[i] < 0) return;
  p = &e->fl[s->slot[i]];
  for (n = 0; n < 16; n++)
  {
    v = *p;
    if (v & 1 || v & 6 && v & 6 != EHCI_TYPE_SITD) break;
    if (v & ~31 == UsbPa(td))
    {
      *p = td(CEhciItd *)->next;
      break;
    }
    p = &(v & ~31)(CEhciItd *)->next;
  }
  s->slot[i] = -1;
}

Bool EhciIsoActive(CUsbIso *s, U8 *td)
{
  I64 j;
  if (s->split)
    return td(CEhciSitd *)->st & EHCI_SITD_ACT;
  for (j = 0; j < s->per_fr; j++)
    if (td(CEhciItd *)->st[j * s->step] & EHCI_ITD_ACT)
      return TRUE;
  return FALSE;
}

Bool EhciIsoStart(CUsbFn *f, CUsbIso *s)
{
  CEhciHc *e = &ehc[f->hci];
  I64 i, base;
  if (f->speed == USB_SPD_HS)
  {
    s->split = FALSE;
    if (s->interval >= 4)
    {
      s->per_fr = 1;
      s->step = 8;
    }
    else
    {
      s->step = 1 << (s->interval - 1);
      s->per_fr = 8 / s->step;
    }
  }
  else
  {
    if (!f->tt_adr || s->maxlen > 1023) return FALSE;
    s->split = TRUE;
    s->per_fr = 1;
    s->step = 8;
  }
  s->nu = USB_ISO_NFR;
  s->fr_bytes = 7 * 0x1000;
  s->td = CAllocAligned(s->nu * sizeof(CEhciItd), EHCI_ITD_ALIGN, sys_dma_heap);
  s->buf = CAllocAligned(s->nu * s->fr_bytes, 0x1000, adam_task->code_heap);
  if (!s->td || !s->buf) return FALSE;
  base = EhciFrame(e) + 8;
  for (i = 0; i < s->nu; i++)
    EhciIsoArm(e, f, s, i, (base + i) & 1023);
  s->nxt = 0;
  s->next_slot = base + s->nu;
  return TRUE;
}

I64 EhciIsoPoll(CUsbFn *f, CUsbIso *s, U8 *dst, I64 *lens, I64 max)
{
  CEhciHc *e = &ehc[f->hci];
  CEhciItd *td;
  CEhciSitd *sd;
  I64 i, j, w, n = 0, ln, slot, ahead;
  while (n + s->per_fr <= max)
  {
    i = s->nxt;
    td = s->td + i * sizeof(CEhciItd);
    sd = td;
    if (EhciIsoActive(s, td))
    {
      ahead = (s->slot[i] - EhciFrame(e)) & 1023;
      if (ahead < 512) break;
    }
    for (j = 0; j < s->per_fr; j++)
    {
      ln = -1;
      if (s->split)
      {
        w = sd->st;
        if (w & EHCI_SITD_ACT)
          s->missed++;
        else if (w & EHCI_SITD_ERR)
          s->errs++;
        else if (s->dirin)
          ln = s->ulen[i] - w >> 16 & 0x3FF;
        else
          ln = s->ulen[i];
      }
      else
      {
        w = td->st[j * s->step];
        if (w & EHCI_ITD_ACT)
          s->missed++;
        else if (w & EHCI_ITD_ERR)
          s->errs++;
        else
          ln = w >> 16 & 0xFFF;
      }
      if (s->dirin)
      {
        if (ln > 0)
        {
          MemCpy(dst, s->buf + i * s->fr_bytes + j * s->maxlen, ln);
          dst += ln;
        }
        lens[n] = ln;
      }
      n++;
      s->pkts++;
    }
    EhciIsoUnlink(e, s, i);
    slot = s->next_slot & 1023;
    ahead = (slot - EhciFrame(e)) & 1023;
    if (ahead < 2 || ahead > s->nu + 16)
    {
      slot = (EhciFrame(e) + 4) & 1023;
      s->resync++;
    }
    EhciIsoArm(e, f, s, i, slot);
    s->next_slot = slot + 1;
    s->nxt = (i + 1) % s->nu;
    s->frames++;
  }
  return n;
}

U0 EhciIsoStop(CUsbFn *f, CUsbIso *s)
{
  CEhciHc *e = &ehc[f->hci];
  I64 i;
  if (!s->td) return;
  for (i = 0; i < s->nu; i++)
    EhciIsoUnlink(e, s, i);
}

Bool EhciPortRst(CEhciOp *eop, I64 p)
{//TRUE: high-speed device enabled. Otherwise the port goes to the companion.
  I64 k;
  U32 sc = eop->port[p];
  if (sc & EHCI_PORT_LS == EHCI_PORT_LS_K)
    goto er_release;
  eop->port[p] = sc & ~(EHCI_PORT_RWC | EHCI_PORT_PE) | EHCI_PORT_PR;
  UsbWait(50);
  eop->port[p] = eop->port[p] & ~(EHCI_PORT_RWC | EHCI_PORT_PR);
  for (k = 0; k < 10 && eop->port[p] & EHCI_PORT_PR; k++)
    UsbWait(1);
  for (k = 0; k < 100 && !(UsbRd(&eop->port[p]) & EHCI_PORT_PE); k++)
    UsbWait(1);
  UsbWait(10);
  if (UsbRd(&eop->port[p]) & EHCI_PORT_PE)
    return TRUE;
er_release:
  eop->port[p] = eop->port[p] & ~EHCI_PORT_RWC | EHCI_PORT_PO;
  return FALSE;
}

U0 EhciPortChk(I64 i, I64 p)
{
  CEhciHc *e = &ehc[i];
  I64 k, idx;
  U32 sc = e->op->port[p];
  CUsbFn t;
  if (!(sc & EHCI_PORT_CCS))
  {
    if (e->pen[p] == 1)
      for (k = 0; k < usb_n; k++)
        if (usb_fn[k].hc == USB_HC_EHCI && usb_fn[k].hci == i &&
              usb_fn[k].port == p && usb_fn[k].hub < 0)
          UsbFnOff(k);
    e->pen[p] = 0;
    return;
  }
  if (e->pen[p]) return;
  e->pen[p] = 2;
  if (!EhciPortRst(e->op, p)) return;
  ZeroClass(&t);
  t.hc = USB_HC_EHCI;
  t.hci = i;
  t.port = p;
  t.hub = -1;
  t.speed = USB_SPD_HS;
  idx = UsbEnum(&t);
  if (idx >= 0)
  {
    e->pen[p] = 1;
    UsbIntOn(idx);
  }
}

U0 EhciPoll(Bool ports = TRUE)
{
  I64 i, k;
  for (i = 0; i < ehn && ports; i++)
    for (k = 0; k < ehc[i].nports; k++)
      EhciPortChk(i, k);
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].hc == USB_HC_EHCI && usb_fn[k].on && usb_fn[k].hq)
      EhciIntPoll(k);
}

U0 EhciHandoff(I64 b, I64 d, I64 f, I64 eecp)
{//Take the controller from the BIOS (USBLEGSUP) and stop its SMIs.
  I64 k;
  U32 legsup;
  if (eecp < 0x40) return;
  PCIWriteU32(b, d, f, eecp, PCIReadU32(b, d, f, eecp) | 1 << 24);
  for (k = 0; k < 1000; k++)
  {
    legsup = PCIReadU32(b, d, f, eecp);
    if (!Bt(&legsup, 16)) break;
    UsbWait(1);
  }
  PCIWriteU32(b, d, f, eecp + 4, 0);
}

Bool EhciStart(I64 bdf)
{
  CEhciHc *e = &ehc[ehn];
  CEhciOp *eop;
  CEhciCap *cap;
  I64 b = bdf >> 16, d = bdf >> 8 & 0xFF, f = bdf & 0xFF, bar, k;
  PCIWriteU16(b, d, f, 4, PCIReadU16(b, d, f, 4) | 6);
  bar = PCIReadU32(b, d, f, 0x10) & ~0xF;
  cap = bar + dev.uncached_alias;
  e->op = eop = bar + cap->caplen + dev.uncached_alias;
  e->nports = MinI64(cap->n_ports, EHCI_NPORT);
  EhciHandoff(b, d, f, cap->eecp);
  eop->rs = 0;
  for (k = 0; k < 20 && !eop->halted; k++)
    UsbWait(1);
  eop->hcreset = 1;
  for (k = 0; k < 50 && eop->hcreset; k++)
    UsbWait(1);
  e->fl = CAllocAligned(4096, 4096, sys_dma_heap);
  e->qa = EhciQhNew(NULL, 0, 64);
  e->qa->head = UsbPa(e->qa) | EHCI_QH;
  e->qa->h = 1;
  e->pa = EhciQhNew(NULL, 0, 64);
  for (k = 0; k < 1024; k++)
    e->fl[k] = UsbPa(e->pa) | EHCI_QH;
  e->qn = 0;
  MemSet(e->pen, 0, EHCI_NPORT);
  eop->intr = 0;
  eop->ctrlds = 0;
  eop->plist = UsbPa(e->fl);
  eop->alist = UsbPa(e->qa);
  eop->sts = 0x3F;
  eop->cmd = 0x080031;
  for (k = 0; k < 20 && eop->halted; k++)
    UsbWait(1);
  if (eop->halted)
    return FALSE;
  eop->cfgflag = 1;
  UsbWait(5);
  if (cap->ppc)
  {
    for (k = 0; k < e->nports; k++)
      eop->port[k] = eop->port[k] & ~EHCI_PORT_RWC | EHCI_PORT_PP;
    UsbWait(20);
  }
  return TRUE;
}

Bool EhciInit()
{//All EHCI controllers (Intel 6/7-series have two, each with a hub on port 1).
  I64 n, bdf;
  if (ehn) return FALSE;
  UsbBufInit;
  usb_ops[USB_HC_EHCI].ctl = &EhciCtl;
  usb_ops[USB_HC_EHCI].bulk = &EhciBulk;
  usb_ops[USB_HC_EHCI].int_init = &EhciIntInit;
  usb_ops[USB_HC_EHCI].int_stop = &EhciIntStop;
  usb_ops[USB_HC_EHCI].bulk_rst = &EhciBulkRst;
  usb_ops[USB_HC_EHCI].bin_arm = &EhciBinArm;
  usb_ops[USB_HC_EHCI].bin_poll = &EhciBinPoll;
  usb_ops[USB_HC_EHCI].bin_stop = &EhciBinStop;
  usb_ops[USB_HC_EHCI].iso_start = &EhciIsoStart;
  usb_ops[USB_HC_EHCI].iso_poll = &EhciIsoPoll;
  usb_ops[USB_HC_EHCI].iso_stop = &EhciIsoStop;
  ets = CAllocAligned(EHCI_TD_CNT * sizeof(CEhciTd), EHCI_TD_ALIGN, sys_dma_heap);
  for (n = 0; ehn < EHCI_NHC && (bdf = PCIClassFind(USB_PCI_EHCI, n)) != -1; n++)
    if (EhciStart(bdf))
      ehn++;
  EhciPoll;
  return ehn > 0;
}
