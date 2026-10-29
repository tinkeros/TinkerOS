#define USB_VEN_BUF 4096

U8 **usb_ven_dma = NULL;
U8 **usb_ven_rx = NULL;
I64 usb_ven_armed = 0;

I64 UsbIfSel(I64 kind, U8 *d, I64 total, I64 ifn, I64 *_eb, I64 *_ebo,
      I64 *_bmps, I64 *_alt, I64 *_cls)
{//Endpoints of the alternate setting to use for MIDI or printer i/f ifn.
  CUsbIf *ifd = NULL;
  CUsbEp *epd;
  I64 pos = 0, ln, ty, in = 0, out = 0, mi = 64, mo = 64, rank, best = 0,
        nalt = 0, proto = 0;
  while (TRUE)
  {
    ln = 0;
    ty = 0;
    if (pos + 2 <= total)
    {
      ln = d[pos];
      ty = d[pos + 1];
    }
    if (ln < 2 || ty == USB_DT_IF)
    {
      if (ifd && ifd->num == ifn)
      {
        rank = 0;
        if (kind == USB_KIND_MIDI)
        {
          if (!ifd->alt && (in || out)) rank = 1;
        }
        else if (out && proto == 2 && in) rank = 3;
        else if (out && proto == 1) rank = 2;
        else if (out && proto == 3 && in) rank = 1;
        if (rank > best)
        {
          best = rank;
          *_alt = ifd->alt;
          *_eb = in;
          *_ebo = out;
          if (out) *_bmps = mo;
          else *_bmps = mi;
          if (kind == USB_KIND_LPT)
            *_cls = 7 << 16 | 1 << 8 | proto;
        }
      }
      if (ln < 2) break;
      ifd = d + pos;
      in = 0;
      out = 0;
      mi = 64;
      mo = 64;
      proto = 0;
      if (ifd->num == ifn)
      {
        nalt++;
        if (ifd->cls == 7 && ifd->sub == 1)
          proto = ifd->proto;
      }
    }
    else if (ty == USB_DT_EP && ifd && ifd->num == ifn)
    {
      epd = d + pos;
      if (epd->xfer == USB_EP_BULK && epd->ep_in && !in)
      {
        in = epd->ep_num;
        mi = epd->mps;
      }
      else if (epd->xfer == USB_EP_BULK && !epd->ep_in && !out)
      {
        out = epd->ep_num;
        mo = epd->mps;
      }
    }
    pos += ln;
  }
  if (!best)
    return 0;
  return nalt;
}

I64 UsbBulkSel(CUsbFn *t, U8 *d, I64 total, I64 skip1, I64 skip2,
      I64 *bk, I64 *bi, I64 *bin, I64 *bout, I64 *bm, I64 *bc)
{//Bulk functions of descriptor d other than interfaces skip1 and skip2.
  CUsbIf *ifd;
  CUsbEp *epd;
  I64 pos = 0, ln, ty, n = 0, cur = 0, cur_if = -1, cur_cls = 0, pend = -1,
        pend_cls = 0, in = 0, out = 0, mps = 64;
  Bool ser = UsbSerId(t->vid, t->pid) >= 0;
  while (TRUE)
  {
    ln = 0;
    ty = 0;
    if (pos + 2 <= total)
    {
      ln = d[pos];
      ty = d[pos + 1];
    }
    if (ln < 2 || ty == USB_DT_IF)
    {
      if (cur && in && out && n < 4)
      {
        bk[n] = cur;
        bi[n] = cur_if;
        bin[n] = in;
        bout[n] = out;
        bm[n] = mps;
        bc[n] = cur_cls;
        n++;
      }
      cur = 0;
      if (ln < 2) break;
      ifd = d + pos;
      in = 0;
      out = 0;
      mps = 64;
      if (!ifd->alt && ifd->num != skip1 && ifd->num != skip2)
      {
        if (ifd->cls == USB_CLS_CDC_CTL && ifd->sub == 2 && ifd->proto != 0xFF)
        {
          pend = ifd->num;
          pend_cls = ifd->cls << 16 | ifd->sub << 8 | ifd->proto;
        }
        else if (ifd->cls == USB_CLS_CDC_DATA && pend >= 0)
        {
          cur = USB_KIND_CDC;
          cur_if = pend;
          cur_cls = pend_cls;
          pend = -1;
        }
        else if (ifd->cls == 0xFF && !ser)
        {
          cur = USB_KIND_VENDOR;
          cur_if = ifd->num;
          cur_cls = ifd->cls << 16 | ifd->sub << 8 | ifd->proto;
        }
      }
    }
    else if (ty == USB_DT_EP && cur)
    {
      epd = d + pos;
      if (epd->xfer == USB_EP_BULK && epd->ep_in && !in)
      {
        in = epd->ep_num;
        mps = epd->mps;
      }
      else if (epd->xfer == USB_EP_BULK && !epd->ep_in && !out)
        out = epd->ep_num;
    }
    pos += ln;
  }
  return n;
}

Bool UsbVenKind(I64 kind)
{//Kinds driven from Adam through these calls.
  return kind == USB_KIND_VENDOR || kind == USB_KIND_MIDI || kind == USB_KIND_LPT ||
        kind == USB_KIND_CDC || kind == USB_KIND_VIDEO || kind == USB_KIND_AUDIO;
}

Bool UsbVenLive(I64 k, I64 gen)
{
  CUsbFn *f = UsbFnAt(k);
  if (!f) return FALSE;
  return UsbVenKind(f->kind) && f->gen == gen;
}

public I64 UsbVenGen(I64 k)
{//Generation of function k if it is a vendor, MIDI or printer function.
  CUsbFn *f = UsbFnAt(k);
  if (!f) return -1;
  if (!UsbVenKind(f->kind)) return -1;
  return f->gen;
}

public I64 UsbVenId(I64 k)
{//VID << 16 | PID of function k, -1 if UsbVenGen fails.
  if (UsbVenGen(k) < 0) return -1;
  return usb_fn[k].vid << 16 | usb_fn[k].pid;
}

public I64 UsbVenIf(I64 k)
{//Interface number of function k, -1 if UsbVenGen fails.
  if (UsbVenGen(k) < 0) return -1;
  return usb_fn[k].ifn;
}

public I64 UsbVenCls(I64 k)
{//Interface class << 16 | subclass << 8 | protocol of function k.
  if (UsbVenGen(k) < 0) return -1;
  return usb_fn[k].cls;
}

public I64 UsbVenAlt(I64 k)
{//Alternate setting in use on function k, -1 if UsbVenGen fails.
  if (UsbVenGen(k) < 0) return -1;
  return usb_fn[k].alt;
}

public I64 UsbVenEp(I64 k, Bool dirin)
{//Bulk IN (dirin) or OUT endpoint number of function k, 0 if it has none.
  if (UsbVenGen(k) < 0) return -1;
  if (dirin) return usb_fn[k].bin;
  return usb_fn[k].bout;
}

public I64 UsbVenSpeed(I64 k)
{//Speed of function k's device (USB_SPD_* in Kernel/Usb/Usb.HH).
  if (UsbVenGen(k) < 0) return -1;
  return usb_fn[k].speed;
}

public I64 UsbVenMps(I64 k)
{//Max packet size of function k's bulk IN endpoint, -1 if UsbVenGen fails.
  if (UsbVenGen(k) < 0) return -1;
  return usb_fn[k].bmps;
}

public I64 UsbVenFind(I64 vid = -1, I64 pid = -1, I64 n = 0,
      I64 kind = USB_KIND_VENDOR)
{//UsbRep number of the n-th function of this kind with this VID and PID.
  I64 k;
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].on && usb_fn[k].kind == kind &&
          (vid < 0 || usb_fn[k].vid == vid) && (pid < 0 || usb_fn[k].pid == pid) &&
          !n--)
      return k;
  return -1;
}

U8 *UsbVenBuf(U8 ***_tab, I64 k)
{//Lives as long as the system: not on the calling task's heap.
  if (!*_tab)
    *_tab = CAlloc(USB_NFN * sizeof(U8 *), adam_task->code_heap);
  if (!(*_tab)[k])
    (*_tab)[k] = CAllocAligned(USB_VEN_BUF, USB_VEN_BUF, sys_dma_heap);
  return (*_tab)[k];
}

public I64 UsbVenXfer(I64 k, I64 gen, Bool dirin, U8 *buf, I64 len)
{//Synchronous bulk transfer on function k: IN if dirin, else OUT.
  CUsbFn *f;
  U8 *dma;
  I64 i = 0, n, r;
  if (!UsbVenLive(k, gen)) return -1;
  f = &usb_fn[k];
  dma = UsbVenBuf(&usb_ven_dma, k);
  while (i < len)
  {
    n = MinI64(len - i, USB_VEN_BUF);
    UsbLock;
    r = -1;
    if (UsbVenLive(k, gen))
    {
      if (!dirin)
        MemCpy(dma, buf + i, n);
      r = (*usb_ops[f->hc].bulk)(f, dirin, dma, n);
      if (dirin && r > 0)
        MemCpy(buf + i, dma, r);
    }
    UsbUnlock;
    if (r < 0)
      return -1;
    i += r;
    if (r < n) break;
  }
  return i;
}

public I64 UsbVenCtl(I64 k, I64 gen, I64 rt, I64 req, I64 val, I64 idx,
      I64 len = 0, U8 *buf = NULL)
{//Control request to function k's device. Returns the bytes transferred.
  if (!UsbVenLive(k, gen) || !(rt & USB_RT_IN) && len) return -1;
  return UsbReq(&usb_fn[k], rt, req, val, idx, len, buf);
}

public I64 UsbVenCtlOut(I64 k, I64 gen, I64 rt, I64 req, I64 val, I64 idx,
      U8 *buf, I64 len)
{//OUT control request with a data stage of len bytes from buf.
  if (!UsbVenLive(k, gen) || rt & USB_RT_IN) return -1;
  return UsbReqOut(&usb_fn[k], rt, req, val, idx, buf, len);
}

public Bool UsbVenRst(I64 k, I64 gen)
{//Reset the data toggles of function k's bulk endpoints.
  if (!UsbVenLive(k, gen)) return FALSE;
  (*usb_ops[usb_fn[k].hc].bulk_rst)(&usb_fn[k]);
  return TRUE;
}

public Bool UsbVenBinArm(I64 k, I64 gen, I64 len)
{//Queue one async bulk-IN transfer on function k, for UsbVenBinPoll.
  CUsbFn *f;
  U8 *dma;
  Bool res = FALSE;
  if (!UsbVenLive(k, gen) || !usb_fn[k].bin) return FALSE;
  f = &usb_fn[k];
  if (!usb_ops[f->hc].bin_arm || !usb_ops[f->hc].bin_poll) return FALSE;
  dma = UsbVenBuf(&usb_ven_rx, k);
  UsbLock;
  if (Bt(&usb_ven_armed, k))
    res = TRUE;
  else if (UsbVenLive(k, gen) &&
        (*usb_ops[f->hc].bin_arm)(f, dma, ClampI64(len, 1, USB_VEN_BUF)))
  {
    LBts(&usb_ven_armed, k);
    res = TRUE;
  }
  UsbUnlock;
  return res;
}

public I64 UsbVenBinPoll(I64 k, I64 gen, U8 *buf)
{//Non-blocking: the transfer UsbVenBinArm queued.
  CUsbFn *f;
  I64 n = -3;
  if (!UsbVenLive(k, gen)) return -3;
  f = &usb_fn[k];
  UsbLock;
  if (UsbVenLive(k, gen) && Bt(&usb_ven_armed, k))
  {
    n = (*usb_ops[f->hc].bin_poll)(f);
    if (n >= 0)
      MemCpy(buf, usb_ven_rx[k], n);
    if (n != -1)
      LBtr(&usb_ven_armed, k);
  }
  UsbUnlock;
  return n;
}

U0 UsbVenBinStop(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  if (LBtr(&usb_ven_armed, k) && usb_ops[f->hc].bin_stop)
    (*usb_ops[f->hc].bin_stop)(f);
}

public U0 UsbVenBinCancel(I64 k, I64 gen)
{//Cancel the async bulk-IN UsbVenBinArm queued, if any.
  if (UsbVenLive(k, gen))
    UsbVenBinStop(k);
}

U0 UsbVenIsoKill(I64 k)
{
  CUsbFn *f = &usb_fn[k];
  CUsbIso *s = f->iso;
  if (!s) return;
  UsbLock;
  f->iso = NULL;
  (*usb_ops[f->hc].iso_stop)(f, s);
  UsbUnlock;
  UsbWait(2);
  Free(s->td);
  Free(s->buf);
  Free(s->fifo);
  Free(s);
}

U0 UsbVenUnplug(I64 k)
{//Called by UsbFnOff for vendor, MIDI, printer and video functions.
  UsbVenBinStop(k);
  UsbVenIsoKill(k);
}

public I64 UsbVenIsoStart(I64 k, I64 gen, I64 ep, I64 mps, I64 interval)
{//Start isochronous endpoint ep of function k. Returns the max packet bytes.
  CUsbFn *f;
  CUsbIso *s;
  Bool ok = FALSE;
  if (!UsbVenLive(k, gen)) return -1;
  f = &usb_fn[k];
  if (!usb_ops[f->hc].iso_start) return -1;
  UsbVenIsoKill(k);
  s = CAlloc(sizeof(CUsbIso), adam_task->code_heap);
  s->ep = ep & 15;
  s->dirin = ep >> 7 & 1;
  s->mps = mps & 0x7FF;
  s->mult = mps >> 11 & 3 + 1;
  s->maxlen = s->mps * s->mult;
  s->interval = ClampI64(interval, 1, 16);
  if (!s->dirin)
    s->fifo = CAlloc(USB_ISO_FIFO * s->maxlen, adam_task->code_heap);
  UsbLock;
  if (UsbVenLive(k, gen) && s->maxlen && (*usb_ops[f->hc].iso_start)(f, s))
  {
    f->iso = s;
    ok = TRUE;
  }
  UsbUnlock;
  if (!ok)
  {
    Free(s->td);
    Free(s->buf);
    Free(s->fifo);
    Free(s);
    return -1;
  }
  return s->maxlen;
}

public I64 UsbVenIsoRead(I64 k, I64 gen, U8 *dst, I64 *lens, I64 max)
{//IN stream: the packets of the units done since the last call, oldest first.
  CUsbFn *f;
  CUsbIso *s;
  I64 n = -1;
  if (!UsbVenLive(k, gen)) return -1;
  f = &usb_fn[k];
  UsbLock;
  if (UsbVenLive(k, gen) && (s = f->iso))
    if (s->dirin)
      n = (*usb_ops[f->hc].iso_poll)(f, s, dst, lens, max);
  UsbUnlock;
  return n;
}

public I64 UsbVenIsoWrite(I64 k, I64 gen, U8 *src, I64 *lens, I64 n)
{//OUT stream: queue up to n packets behind the ones still waiting.
  CUsbFn *f;
  CUsbIso *s;
  I64 i = -1, ln;
  if (!UsbVenLive(k, gen)) return -1;
  f = &usb_fn[k];
  UsbLock;
  s = NULL;
  if (UsbVenLive(k, gen))
    s = f->iso;
  if (s)
    if (s->dirin)
      s = NULL;
  if (s)
  {
    for (i = 0; i < n && s->fin - s->fout < USB_ISO_FIFO; i++)
    {
      ln = ClampI64(lens[i], 0, s->maxlen);
      MemCpy(s->fifo + (s->fin & (USB_ISO_FIFO - 1)) * s->maxlen, src, ln);
      s->flen[s->fin & (USB_ISO_FIFO - 1)] = ln;
      s->fin++;
      src += lens[i];
    }
    (*usb_ops[f->hc].iso_poll)(f, s, NULL, NULL, USB_ISO_NU * 8);
  }
  UsbUnlock;
  return i;
}

public I64 UsbVenIsoStat(I64 k, I64 gen, I64 which)
{//Counters of function k's stream, -1 if none.
  CUsbIso *s;
  if (!UsbVenLive(k, gen)) return -1;
  if (!(s = usb_fn[k].iso)) return -1;
  switch (which)
  {
  case 0: return s->frames;
  case 1: return s->pkts;
  case 2: return s->errs;
  case 3: return s->missed;
  case 4: return s->resync;
  case 5: return s->fin - s->fout;
  case 6: return s->under;
  }
  return -1;
}

public U0 UsbVenIsoStop(I64 k, I64 gen)
{//Stop function k's isochronous stream, if any.
  if (UsbVenLive(k, gen))
    UsbVenIsoKill(k);
}
