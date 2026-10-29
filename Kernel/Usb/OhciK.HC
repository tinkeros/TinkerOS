#define OHCI_DP_SETUP 0
#define OHCI_DP_OUT   1
#define OHCI_DP_IN    2
#define OHCI_TD_CNT 4
#define OHCI_NPIPE  64
#define OHCI_NPORT  16
#define OHCI_NHC    4

#define OHCI_CMD_HCR 1
#define OHCI_CMD_CLF 2
#define OHCI_CMD_BLF 4
#define OHCI_CMD_OCR 8

#define OHCI_PORT_CCS  0x00001
#define OHCI_PORT_PRS  0x00010
#define OHCI_PORT_PPS  0x00100
#define OHCI_PORT_LSDA 0x00200
#define OHCI_PORT_CSC  0x10000
#define OHCI_PORT_PRSC 0x100000

class COhciTd
{
  union
  {
    U32 ctl;
    U32 rsvd:18;
    U32 round:1;
    U32 dp:2;
    U32 di:3;
    U32 tog:2;
    U32 ec:2;
    U32 cc:4;
  }
  U32 cbp, next, be;
};

class COhciEd
{
  union
  {
    U32 ctl;
    U32 adr:7;
    U32 ep:4;
    U32 dir:2;
    U32 ls:1;
    U32 skip:1;
    U32 iso:1;
    U32 mps:11;
  }
  U32 tail;
  union
  {
    U32 head;
    U32 halted:1;
    U32 carry:1;
  }
  U32 next;
  COhciTd td[2];
};

class COhciOp
{
  U32 rev;
  union
  {
    U32 ctl;
    U32 cbsr:2;
    U32 ple:1;
    U32 ie:1;
    U32 cle:1;
    U32 ble:1;
    U32 hcfs:2;
    U32 ir:1;
  }
  U32 cmd, intsts, inten, intdis, hcca, pcur, chead, ccur, bhead, bcur, done;
  U32 fmi, fmr, fmn, pstart, lsth, rha, rhb, rhs;
  U32 port[15];
};

class COhciHc
{//ia: anchor every HCCA slot points to, qp/qk: control+bulk EDs by key.
  COhciOp *op;
  I64 nports, qn;
  U32 *hcca;
  COhciEd *ia, *qp[OHCI_NPIPE];
  I64 qk[OHCI_NPIPE];
  U8 pen[OHCI_NPORT];
} ohc[OHCI_NHC];
I64 ohn = 0;
COhciTd *ots;

U0 OhciTdSet(COhciTd *td, I64 dp, I64 tog, I64 len, U8 *buf)
{//tog 0: from the ED carry, 2/3: DATA0/DATA1.
  td->ctl = 0;
  td->round = 1;
  td->dp = dp;
  td->di = 7;
  td->tog = tog;
  td->cc = 0xF;
  td->cbp = 0;
  td->be = 0;
  if (len)
  {
    td->cbp = UsbPa(buf);
    td->be = UsbPa(buf) + len - 1;
  }
  td->next = 0;
}

I64 OhciTdLen(COhciTd *td, U8 *buf, I64 len)
{//Bytes moved: cbp is 0 when the whole buffer was used.
  if (!td->cbp)
    return len;
  return td->cbp - UsbPa(buf);
}

COhciEd *OhciEdNew(CUsbFn *f, I64 ep, I64 dir, I64 mps)
{
  COhciEd *ed = CAllocAligned(sizeof(COhciEd), 16, sys_dma_heap);
  ed->adr = f->adr;
  ed->ep = ep;
  ed->dir = dir;
  ed->ls = f->speed == USB_SPD_LS;
  ed->mps = mps;
  ed->tail = UsbPa(&ed->td[0]);
  ed->head = ed->tail;
  return ed;
}

U0 OhciEdHold(COhciEd *ed)
{//Skip the ED and let a frame pass, so the HC no longer holds a copy of it.
  ed->skip = 1;
  UsbWait(2);
}

COhciTd *OhciQueue(COhciEd *ed, COhciTd *tds, I64 n)
{//Append tds[0..n-1] at the tail. Writing ED.tail hands them to the HC.
  COhciTd *first = ed->tail, *nt = &ed->td[0];
  I64 k;
  if (first == nt) nt = &ed->td[1];
  MemSet(nt, 0, sizeof(COhciTd));
  ClassCpy(first, tds);
  for (k = 1; k < n - 1; k++)
    tds[k].next = UsbPa(&tds[k + 1]);
  if (n > 1)
  {
    first->next = UsbPa(&tds[1]);
    tds[n - 1].next = UsbPa(nt);
  }
  else
    first->next = UsbPa(nt);
  ed->tail = UsbPa(nt);
  return first;
}

Bool OhciDone(COhciEd *ed)
{
  return ed->head & ~0xF == ed->tail || ed->halted;
}

U0 OhciFlush(COhciEd *ed)
{//Drop whatever is still queued and clear a halt, keeping the toggle.
  OhciEdHold(ed);
  ed->head = ed->tail | ed->head & 2;
  ed->skip = 0;
}

COhciEd *OhciPipe(CUsbFn *f, I64 ep, I64 dirin, I64 mps)
{//One ED per endpoint and direction on the control or bulk list.
  COhciHc *o = &ohc[f->hci];
  I64 k, key = f->adr << 8 | ep << 1 | dirin, dir = 0,
        ls = f->speed == USB_SPD_LS;
  COhciEd *ed;
  for (k = 0; k < o->qn; k++)
    if (o->qk[k] == key)
    {
      if (o->qp[k]->mps != mps || o->qp[k]->ls != ls)
      {
        OhciEdHold(o->qp[k]);
        o->qp[k]->mps = mps;
        o->qp[k]->ls = ls;
        o->qp[k]->skip = 0;
      }
      return o->qp[k];
    }
  if (ep)
  {
    dir = OHCI_DP_OUT;
    if (dirin) dir = OHCI_DP_IN;
  }
  ed = OhciEdNew(f, ep, dir, mps);
  if (ep)
  {
    ed->next = o->op->bhead;
    o->op->bhead = UsbPa(ed);
  }
  else
  {
    ed->next = o->op->chead;
    o->op->chead = UsbPa(ed);
  }
  o->qk[o->qn] = key;
  o->qp[o->qn++] = ed;
  return ed;
}

Bool OhciRun(COhciHc *o, COhciEd *ed, I64 n, I64 cmd)
{//Queue ots[0..n-1] and wait until the ED is idle again.
  COhciTd *first = OhciQueue(ed, ots, n);
  I64 k, end = UsbEnd(300);
  o->op->cmd = cmd;
  while (!OhciDone(ed) && GetTSC < end)
    Yield;
  ClassCpy(ots, first);
  for (k = 0; k < n; k++)
    if (ots[k].cc || !OhciDone(ed))
    {
      OhciFlush(ed);
      return FALSE;
    }
  return TRUE;
}

I64 OhciCtl(CUsbFn *f, I64 len, I64 dirin)
{
  COhciEd *ed = OhciPipe(f, 0, 0, f->mps0);
  I64 n = 1, sdp = OHCI_DP_IN;
  COhciHc *o = &ohc[f->hci];
  OhciTdSet(&ots[0], OHCI_DP_SETUP, 2, 8, usb_buf + USB_BUF_SETUP);
  if (len)
  {
    OhciTdSet(&ots[1], OHCI_DP_OUT, 3, len, usb_buf + USB_BUF_DATA);
    if (dirin)
    {
      ots[1].dp = OHCI_DP_IN;
      sdp = OHCI_DP_OUT;
    }
    n = 2;
  }
  OhciTdSet(&ots[n], sdp, 3, 0, NULL);
  if (!OhciRun(o, ed, n + 1, OHCI_CMD_CLF))
    return -1;
  if (len)
    return OhciTdLen(&ots[1], usb_buf + USB_BUF_DATA, len);
  return 0;
}

I64 OhciBulk(CUsbFn *f, I64 dirin, U8 *dp, I64 len)
{
  COhciEd *ed;
  COhciHc *o = &ohc[f->hci];
  if (len <= 0) return 0;
  if (dirin)
    ed = OhciPipe(f, f->bin, 1, f->bmps);
  else
    ed = OhciPipe(f, f->bout, 0, f->bmps);
  OhciTdSet(&ots[0], ed->dir, 0, len, dp);
  if (!OhciRun(o, ed, 1, OHCI_CMD_BLF))
    return -1;
  return OhciTdLen(&ots[0], dp, len);
}

U0 OhciArm(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  COhciTd td;
  OhciTdSet(&td, OHCI_DP_IN, 0, MinI64(f->mps, USB_INT_SZ),
      usb_buf + USB_BUF_INT + k * USB_INT_SZ);
  f->ht = OhciQueue(f->hq, &td, 1);
}

U0 OhciIntInit(I64 k)
{//Interrupt EDs hang off the anchor that every HCCA slot points to.
  CUsbFn *f = &usb_fn[k];
  COhciHc *o = &ohc[f->hci];
  COhciEd *ed = OhciEdNew(f, f->ep, OHCI_DP_IN, f->mps);
  f->hq = ed;
  OhciArm(k);
  ed->next = o->ia->next;
  o->ia->next = UsbPa(ed);
}

U0 OhciBulkRst(CUsbFn *f)
{
  COhciEd *ed;
  I64 dirin;
  UsbLock;
  for (dirin = 0; dirin < 2; dirin++)
  {
    ed = NULL;
    if (dirin && f->bin)
      ed = OhciPipe(f, f->bin, 1, f->bmps);
    else if (!dirin && f->bout)
      ed = OhciPipe(f, f->bout, 0, f->bmps);
    if (ed)
    {
      OhciFlush(ed);
      ed->head = ed->tail;
    }
  }
  UsbUnlock;
}

U0 OhciIntStop(CUsbFn *f)
{
  f->hq(COhciEd *)->skip = 1;
}

U0 OhciIntPoll(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  COhciEd *ed = f->hq;
  COhciTd *td = f->ht;
  if (!OhciDone(ed)) return;
  if (!td->cc)
    UsbIntRep(f, usb_buf + USB_BUF_INT + k * USB_INT_SZ);
  if (ed->halted)
    OhciFlush(ed);
  OhciArm(k);
}

U0 OhciPortChk(I64 i, I64 p)
{
  COhciHc *o = &ohc[i];
  I64 k, idx;
  U32 sc = o->op->port[p];
  CUsbFn t;
  if (sc & OHCI_PORT_CSC)
    o->op->port[p] = OHCI_PORT_CSC;
  if (!(sc & OHCI_PORT_CCS))
  {
    if (o->pen[p] == 1)
      for (k = 0; k < usb_n; k++)
        if (usb_fn[k].hc == USB_HC_OHCI && usb_fn[k].hci == i &&
              usb_fn[k].port == p && usb_fn[k].hub < 0)
          UsbFnOff(k);
    o->pen[p] = 0;
    return;
  }
  if (o->pen[p]) return;
  o->pen[p] = 2;
  o->op->port[p] = OHCI_PORT_PRS;
  for (k = 0; k < 50 && !(o->op->port[p] & OHCI_PORT_PRSC); k++)
    UsbWait(1);
  o->op->port[p] = OHCI_PORT_PRSC | OHCI_PORT_CSC;
  UsbWait(10);
  ZeroClass(&t);
  t.hc = USB_HC_OHCI;
  t.hci = i;
  t.port = p;
  t.hub = -1;
  t.speed = USB_SPD_FS;
  if (o->op->port[p] & OHCI_PORT_LSDA)
    t.speed = USB_SPD_LS;
  idx = UsbEnum(&t);
  if (idx >= 0)
  {
    o->pen[p] = 1;
    UsbIntOn(idx);
  }
}

U0 OhciPoll(Bool ports = TRUE)
{
  I64 i, k;
  for (i = 0; i < ohn && ports; i++)
    for (k = 0; k < ohc[i].nports; k++)
      OhciPortChk(i, k);
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].hc == USB_HC_OHCI && usb_fn[k].on && usb_fn[k].hq)
      OhciIntPoll(k);
}

Bool OhciStart(I64 bdf)
{
  COhciHc *o = &ohc[ohn];
  COhciOp *op;
  I64 b = bdf >> 16, d = bdf >> 8 & 0xFF, f = bdf & 0xFF, bar, k, fi;
  PCIWriteU16(b, d, f, 4, PCIReadU16(b, d, f, 4) | 6);
  bar = PCIReadU32(b, d, f, 0x10) & ~0xF;
  o->op = op = bar + dev.uncached_alias;
  if (op->ir)
  {
    op->cmd = OHCI_CMD_OCR;
    for (k = 0; k < 1000 && op->ir; k++)
      UsbWait(1);
  }
  op->intdis = 0x8000007F;
  fi = op->fmi & 0x3FFF;
  if (!fi) fi = 0x2EDF;
  op->cmd = OHCI_CMD_HCR;
  for (k = 0; k < 10 && UsbRd(&op->cmd) & OHCI_CMD_HCR; k++)
    UsbWait(1);
  op->fmi = op->fmi & 0x80000000 ^ 0x80000000 | ((fi - 210) * 6 / 7) << 16 | fi;
  op->pstart = fi * 9 / 10;
  op->lsth = 0x628;
  o->hcca = CAllocAligned(256, 256, sys_dma_heap);
  o->ia = CAllocAligned(sizeof(COhciEd), 16, sys_dma_heap);
  o->ia->skip = 1;
  for (k = 0; k < 32; k++)
    o->hcca[k] = UsbPa(o->ia);
  o->qn = 0;
  MemSet(o->pen, 0, OHCI_NPORT);
  op->hcca = UsbPa(o->hcca);
  op->chead = 0;
  op->bhead = 0;
  op->intsts = 0xFFFFFFFF;
  op->ctl = 0xB7;
  o->nports = MinI64(UsbRd(&op->rha) & 0xFF, OHCI_NPORT);
  op->rhs = 0x10000;
  for (k = 0; k < o->nports; k++)
    op->port[k] = OHCI_PORT_PPS;
  UsbWait(MaxI64(op->rha >> 24 & 0xFF, 10) * 2);
  return TRUE;
}

Bool OhciInit()
{//All OHCI controllers (a south bridge can have two companions).
  I64 n, bdf;
  if (ohn) return FALSE;
  UsbBufInit;
  usb_ops[USB_HC_OHCI].ctl = &OhciCtl;
  usb_ops[USB_HC_OHCI].bulk = &OhciBulk;
  usb_ops[USB_HC_OHCI].int_init = &OhciIntInit;
  usb_ops[USB_HC_OHCI].int_stop = &OhciIntStop;
  usb_ops[USB_HC_OHCI].bulk_rst = &OhciBulkRst;
  ots = CAllocAligned(OHCI_TD_CNT * sizeof(COhciTd), 16, sys_dma_heap);
  for (n = 0; ohn < OHCI_NHC && (bdf = PCIClassFind(USB_PCI_OHCI, n)) != -1; n++)
    if (OhciStart(bdf))
      ohn++;
  OhciPoll;
  return ohn > 0;
}
