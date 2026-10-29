I64 usb_ready = 0;
extern U0 UsbCdcPoll(I64 k);
extern U0 UsbCdcUnplug(I64 k);
extern I64 UsbSerId(I64 vid, I64 pid);
extern U0 UsbEcmAttach(I64 k);
extern U0 UsbEcmPoll(I64 k);
extern U0 UsbEcmUnplug(I64 k);
extern I64 UsbIfSel(I64 kind, U8 *d, I64 total, I64 ifn, I64 *_eb, I64 *_ebo,
      I64 *_bmps, I64 *_alt, I64 *_cls);
extern U0 UsbVenUnplug(I64 k);
extern I64 UsbBulkSel(CUsbFn *t, U8 *d, I64 total, I64 skip1, I64 skip2,
      I64 *bk, I64 *bi, I64 *bin, I64 *bout, I64 *bm, I64 *bc);

CUsbFn *UsbFnAt(I64 k)
{//usb_fn entry k if k is in range and the entry is in use, else NULL.
  if (!(0 <= k < usb_n))
    return NULL;
  if (!usb_fn[k].on)
    return NULL;
  return &usb_fn[k];
}

I64 UsbReq(CUsbFn *f, I64 rt, I64 req, I64 val, I64 idx, I64 len, U8 *dst = NULL)
{//Control transfer. An IN reply is copied to dst while usb_lock is held.
  CUsbSetup su;
  I64 r = -1;
  if (len > USB_DATA_MAX)
    return -1;
  ZeroClass(&su);
  su.rt = rt;
  su.req = req;
  su.val = val;
  su.idx = idx;
  su.len = len;
  UsbLock;
  MemCpy(usb_buf + USB_BUF_SETUP, &su, 8);
  if (usb_ops[f->hc].ctl)
    r = (*usb_ops[f->hc].ctl)(f, len, rt >= USB_RT_IN);
  if (dst && r > 0)
    MemCpy(dst, usb_buf + USB_BUF_DATA, r);
  UsbUnlock;
  return r;
}

I64 UsbReqOut(CUsbFn *f, I64 rt, I64 req, I64 val, I64 idx, U8 *data, I64 len)
{//Like UsbReq, but an OUT request with a data stage.
  CUsbSetup su;
  I64 r = -1;
  if (len > USB_DATA_MAX)
    return -1;
  ZeroClass(&su);
  su.rt = rt;
  su.req = req;
  su.val = val;
  su.idx = idx;
  su.len = len;
  UsbLock;
  MemCpy(usb_buf + USB_BUF_SETUP, &su, 8);
  if (len)
    MemCpy(usb_buf + USB_BUF_DATA, data, len);
  if (usb_ops[f->hc].ctl)
    r = (*usb_ops[f->hc].ctl)(f, len, FALSE);
  UsbUnlock;
  return r;
}

I64 UsbBulk(CUsbFn *f, I64 dirin, U8 *dp, I64 len)
{
  return (*usb_ops[f->hc].bulk)(f, dirin, dp, len);
}

Bool UsbHidParse(CUsbTab *t, U8 *d, I64 len)
{//Find an absolute pointer and/or a relative mouse in a HID report descriptor.
  I64 pos = 0, b, sz, tag, typ, v, page = 0, lmax = 0, rsize = 0, rcnt = 0,
        rid = 0, off = 0, nu = 0, umin = 0, i, u, u_lst[16], bo = -1, bn = 0;
  t->btn = -1;
  t->x = -1;
  t->y = -1;
  t->mbtn = -1;
  t->mx = -1;
  t->my = -1;
  t->mw = -1;
  while (pos < len)
  {
    b = d[pos++];
    if (b == 0xFE)
    {
      pos += d[pos] + 2;
      b = 0;
    }
    sz = b & 3;
    if (sz == 3) sz = 4;
    typ = b >> 2 & 3;
    tag = b >> 4;
    v = 0;
    for (i = sz - 1; i >= 0; i--)
      v = v << 8 | d[pos + i];
    pos += sz;
    if (!b)
      ;
    else if (typ == 1)
    {
      if (tag == 0) page = v;
      else if (tag == 2) lmax = v;
      else if (tag == 7) rsize = v;
      else if (tag == 9) rcnt = v;
      else if (tag == 8)
      {
        rid = v;
        off = 0;
        bo = -1;
      }
    }
    else if (typ == 2)
    {
      if (tag == 0 && nu < 16) u_lst[nu++] = v & 0xFFFF;
      else if (tag == 1) umin = v;
    }
    else if (typ == 0)
    {
      if (tag == 8 && !(v & 1))
        for (i = 0; i < rcnt; i++)
        {
          u = umin + i;
          if (i < nu) u = u_lst[i];
          if (page == 9 && bo < 0)
          {
            bo = off;
            bn = MinI64(rcnt, 5);
          }
          if (page == 1 && u == 0x30 && !(v & 4) && t->x < 0)
          {
            t->x = off;
            t->xs = rsize;
            t->xmax = lmax;
            t->rid = rid;
            t->btn = bo;
          }
          if (page == 1 && u == 0x31 && !(v & 4) && t->y < 0 && t->x >= 0 &&
                rid == t->rid)
          {
            t->y = off;
            t->ys = rsize;
            t->ymax = lmax;
          }
          if (page == 1 && u == 0x30 && v & 4 && t->mx < 0)
          {
            t->mx = off;
            t->mxs = rsize;
            t->mrid = rid;
            t->mbtn = bo;
            t->mnb = bn;
          }
          if (page == 1 && u == 0x31 && v & 4 && t->my < 0 && t->mx >= 0 &&
                rid == t->mrid)
          {
            t->my = off;
            t->mys = rsize;
          }
          if (page == 1 && u == 0x38 && v & 4 && t->mw < 0 && t->mx >= 0 &&
                rid == t->mrid)
          {
            t->mw = off;
            t->mws = rsize;
          }
          off += rsize;
        }
      else if (tag == 8)
        off += rsize * rcnt;
      nu = 0;
      umin = 0;
    }
  }
  if (t->y < 0 || t->xmax <= 0 || t->ymax <= 0)
    t->x = -1;
  if (t->my < 0)
    t->mx = -1;
  return t->x >= 0 || t->mx >= 0;
}

#define USB_HUB_RT_IN  0xA3
#define USB_HUB_RT_OUT 0x23
#define USB_HUB_POWER  8
#define USB_HUB_RESET  4
#define USB_HUB_C_CONN 16
#define USB_HUB_C_RST  20

U0 UsbHubInit(I64 k)
{//Power all ports and scan them once; changes then come by interrupt.
  CUsbFn *f = &usb_fn[k];
  U8 d[8];
  I64 p;
  if (UsbReq(f, 0xA0, USB_REQ_GET_DESC, 0x2900, 0, 8, d) < 7)
    return;
  f->nports = MinI64(d[2], 15);
  for (p = 1; p <= f->nports; p++)
    UsbReq(f, USB_HUB_RT_OUT, USB_REQ_SET_FEATURE, USB_HUB_POWER, p, 0);
  UsbWait(d[5] * 2 + 20);
  f->chg = 1 << (f->nports + 1) - 2;
}

I64 usb_gen_ctr = 0;

I64 UsbEnum(CUsbFn *t)
{//Address, read descriptors and configure a device. Returns its usb_fn index.
  CUsbDev *dv;
  CUsbCfg *cf;
  CUsbIf *ifd;
  CUsbEp *epd;
  CUsbFn *f, *g;
  U8 d[904];
  I64 total, pos, ln, ty, hid, msd, hub, cdc, ecm, kind, ifn,
        cur_ifn, cur_alt, cdc_difn, ea,
        mps, eb, ebo, bmps, rlen, cval, cval0 = 0, idx, cls, cls0 = 0, dalt, mstr,
        ncfg = 1, cfg_i = 0, alt, nalt,
        nx, cx, xi[4], xk[4], xe[4], xm[4], xr[4], xc[4], i, j,
        nb = 0, bk[4], bf[4], bn[4], bo[4], bp[4], bcl[4], has_as, has_ms;
  for (idx = 0; idx < usb_n && !UsbFnFree(idx); idx++);
  if (idx >= USB_NFN) return -1;
  if (usb_ops[t->hc].dev_new && !(*usb_ops[t->hc].dev_new)(t))
  {
    usb_efail++;
    ClassCpy(&usb_efn, t);
    return -1;
  }
  t->adr = 0;
  t->mps0 = 8;
  if (UsbReq(t, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_DEV << 8, 0, 8, d) < 8)
  {
    usb_efail++;
    ClassCpy(&usb_efn, t);
    if (usb_ops[t->hc].dev_off)
      (*usb_ops[t->hc].dev_off)(t);
    return -1;
  }
  dv = d;
  t->mps0 = dv->mps0;
  UsbReq(t, 0, USB_REQ_SET_ADDR, idx + 1, 0, 0);
  UsbWait(5);
  t->adr = idx + 1;
  if (UsbReq(t, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_DEV << 8, 0, 18, d) == 18)
  {
    t->vid = dv->vid;
    t->pid = dv->pid;
    ncfg = MaxI64(dv->cfgs, 1);
  }
usb_enum_cfg:
  hid = msd = hub = cdc = ecm = kind = ifn = ea = eb = ebo = rlen = cls = 0;
  dalt = mstr = nx = cur_alt = alt = nalt = 0;
  cur_ifn = cdc_difn = cx = -1;
  mps = 8;
  bmps = 64;
  cf = d;
  total = 0;
  if (UsbReq(t, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_CFG << 8 | cfg_i, 0, 9, d) == 9)
    total = MaxI64(UsbReq(t, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_CFG << 8 | cfg_i, 0,
          MinI64(cf->total, 900), d), 0);
  cval = cf->cval;
  has_as = has_ms = FALSE;
  pos = 0;
  while (pos + 2 <= total && d[pos] >= 2)
  {
    if (d[pos + 1] == USB_DT_IF && pos + 7 <= total && d[pos + 5] == USB_CLS_AUDIO)
    {
      if (d[pos + 6] == 2) has_as = TRUE;
      if (d[pos + 6] == 3) has_ms = TRUE;
    }
    pos += d[pos];
  }
  pos = 0;
  while (pos + 2 <= total)
  {
    ln = d[pos];
    ty = d[pos + 1];
    if (ln < 2) break;
    if (ty == USB_DT_IF)
    {
      ifd = d + pos;
      cur_ifn = ifd->num;
      cur_alt = ifd->alt;
      cx = -1;
      if (!kind)
      {
        hid = ifd->cls == USB_CLS_HID;
        msd = ifd->cls == USB_CLS_MSD && ifd->sub == 6 && ifd->proto == 0x50;
        hub = ifd->cls == USB_CLS_HUB;
        cdc = ifd->cls == USB_CLS_CDC_CTL && ifd->sub == 2 && ifd->proto != 0xFF;
        ecm = ifd->cls == USB_CLS_CDC_CTL && ifd->sub == 6;
        if (hid && ifd->sub == 1 && ifd->proto == 1) kind = USB_KIND_KBD;
        else if (hid && ifd->sub == 1 && ifd->proto == 2) kind = USB_KIND_MOUSE;
        else if (hid) kind = USB_KIND_TABLET;
        else if (msd) kind = USB_KIND_MSD;
        else if (hub) kind = USB_KIND_HUB;
        else if (cdc) kind = USB_KIND_CDC;
        else if (ecm) kind = USB_KIND_ECM;
        else if (ifd->cls == USB_CLS_AUDIO && ifd->sub == 3) kind = USB_KIND_MIDI;
        else if (ifd->cls == USB_CLS_AUDIO && ifd->sub == 1 && has_as && !has_ms)
          kind = USB_KIND_AUDIO;
        else if (ifd->cls == USB_CLS_PRN && ifd->sub == 1) kind = USB_KIND_LPT;
        else if (ifd->cls == USB_CLS_VIDEO && ifd->sub == 1)
          kind = USB_KIND_VIDEO;
        else if (ifd->cls == 0xFF && UsbSerId(t->vid, t->pid) >= 0)
        {
          kind = USB_KIND_CDC;
          cdc_difn = cur_ifn;
        }
        ifn = cur_ifn;
        cls = ifd->cls << 16 | ifd->sub << 8 | ifd->proto;
      }
      else if ((kind == USB_KIND_CDC || kind == USB_KIND_ECM) && cdc_difn < 0 &&
            ifd->cls == USB_CLS_CDC_DATA)
        cdc_difn = cur_ifn;
      else if (kind != USB_KIND_CDC && kind != USB_KIND_ECM && ifd->cls == USB_CLS_HID &&
            !ifd->alt &&
            cur_ifn != ifn && nx < 4)
      {
        cx = nx++;
        xi[cx] = cur_ifn;
        xc[cx] = ifd->cls << 16 | ifd->sub << 8 | ifd->proto;
        xk[cx] = USB_KIND_TABLET;
        if (ifd->sub == 1 && ifd->proto == 1) xk[cx] = USB_KIND_KBD;
        else if (ifd->sub == 1 && ifd->proto == 2) xk[cx] = USB_KIND_MOUSE;
        xe[cx] = 0;
        xm[cx] = 8;
        xr[cx] = 0;
      }
    }
    else if (ty == USB_DT_HID && cx >= 0)
      xr[cx] = d[pos + 7] | d[pos + 8] << 8;
    else if (ty == USB_DT_HID && hid && cur_ifn == ifn)
      rlen = d[pos + 7] | d[pos + 8] << 8;
    else if (ty == 0x24 && kind == USB_KIND_ECM && cur_ifn == ifn && ln >= 4 &&
          d[pos + 2] == 0x0F)
      mstr = d[pos + 3];
    else if (ty == USB_DT_EP && cx >= 0)
    {
      epd = d + pos;
      if (epd->xfer == USB_EP_INT && epd->ep_in && !xe[cx])
      {
        xe[cx] = epd->ep_num;
        xm[cx] = epd->mps;
      }
    }
    else if (ty == USB_DT_EP && (kind == USB_KIND_CDC || kind == USB_KIND_ECM) &&
          cur_ifn == cdc_difn)
    {
      epd = d + pos;
      if (epd->xfer == USB_EP_BULK && epd->ep_in)
      {
        eb = epd->ep_num;
        bmps = epd->mps;
        dalt = cur_alt;
      }
      else if (epd->xfer == USB_EP_BULK)
        ebo = epd->ep_num;
    }
    else if (ty == USB_DT_EP && kind && kind != USB_KIND_CDC && kind != USB_KIND_ECM)
    {
      epd = d + pos;
      if (epd->xfer == USB_EP_INT && epd->ep_in && !ea)
      {
        ea = epd->ep_num;
        mps = epd->mps;
      }
      else if (epd->xfer == USB_EP_BULK && epd->ep_in)
      {
        eb = epd->ep_num;
        bmps = epd->mps;
      }
      else if (epd->xfer == USB_EP_BULK)
        ebo = epd->ep_num;
    }
    pos += ln;
  }
  if ((kind == USB_KIND_MIDI || kind == USB_KIND_LPT) &&
        !(nalt = UsbIfSel(kind, d, total, ifn, &eb, &ebo, &bmps, &alt, &cls)))
    kind = 0;
  if ((kind == USB_KIND_MSD || kind == USB_KIND_CDC || kind == USB_KIND_ECM) &&
        (!eb || !ebo) ||
        kind != USB_KIND_MSD && kind != USB_KIND_CDC && kind != USB_KIND_ECM &&
        kind != USB_KIND_MIDI && kind != USB_KIND_LPT && kind != USB_KIND_VIDEO &&
        kind != USB_KIND_AUDIO && !ea)
    kind = 0;
  if (!cfg_i)
  {
    i = -1;
    j = -1;
    if (kind)
    {
      i = ifn;
      j = cdc_difn;
    }
    nb = UsbBulkSel(t, d, total, i, j, bk, bf, bn, bo, bp, bcl);
    cval0 = cval;
    cls0 = cls;
  }
  if (cfg_i && kind != USB_KIND_ECM)
    kind = 0;
  if (!kind && ++cfg_i < MinI64(ncfg, 4))
    goto usb_enum_cfg;
  if (kind && cfg_i)
    nb = 0;
  if (!kind)
    cls = cls0;
  if (!kind && nb)
  {
    cval = cval0;
    kind = bk[0];
    ifn = bf[0];
    eb = bn[0];
    ebo = bo[0];
    bmps = bp[0];
    cls = bcl[0];
    nb--;
    for (i = 0; i < nb; i++)
    {
      bk[i] = bk[i + 1];
      bf[i] = bf[i + 1];
      bn[i] = bn[i + 1];
      bo[i] = bo[i + 1];
      bp[i] = bp[i + 1];
      bcl[i] = bcl[i + 1];
    }
  }
  if (kind)
    UsbReq(t, 0, USB_REQ_SET_CFG, cval, 0, 0);
  if (kind == USB_KIND_ECM && dalt)
    UsbReq(t, USB_RT_IF, USB_REQ_SET_IF, dalt, cdc_difn, 0);
  if (kind == USB_KIND_KBD || kind == USB_KIND_MOUSE)
    UsbReq(t, USB_RT_CLS | USB_RT_IF, 0x0B, 0, ifn, 0);
  if (kind == USB_KIND_TABLET)
  {
    if (!rlen) rlen = 256;
    rlen = UsbReq(t, USB_RT_IN | USB_RT_IF, USB_REQ_GET_DESC, USB_DT_REPORT << 8,
        ifn, MinI64(rlen, 900), d);
    if (rlen <= 0 || !UsbHidParse(&t->tab, d, rlen))
      kind = 0;
  }
  if (!kind || kind == USB_KIND_MSD || kind == USB_KIND_CDC || kind == USB_KIND_ECM ||
        kind == USB_KIND_MIDI || kind == USB_KIND_LPT || kind == USB_KIND_VENDOR ||
        kind == USB_KIND_VIDEO || kind == USB_KIND_AUDIO)
    ea = 0;
  f = &usb_fn[idx];
  ClassCpy(f, t);
  f->kind = kind;
  f->ifn = ifn;
  f->cls = cls;
  f->ep = ea;
  f->mps = mps;
  f->bin = eb;
  f->bout = ebo;
  f->bmps = bmps;
  f->alt = alt;
  f->dalt = dalt;
  f->mstr = mstr;
  f->on = 1;
  f->gen = ++usb_gen_ctr;
  if (idx == usb_n)
    usb_n++;
  if (kind == USB_KIND_HUB)
    UsbHubInit(idx);
  if (kind == USB_KIND_LPT && nalt > 1)
    UsbReq(f, USB_RT_IF, USB_REQ_SET_IF, alt, ifn, 0);
  if (kind == USB_KIND_MSD || kind == USB_KIND_CDC || kind == USB_KIND_ECM ||
        kind == USB_KIND_MIDI || kind == USB_KIND_LPT || kind == USB_KIND_VENDOR)
    (*usb_ops[f->hc].bulk_rst)(f);
  if (kind == USB_KIND_ECM)
    UsbEcmAttach(idx);
  UsbEvt(idx, TRUE);
  for (i = 0; i < nx && kind; i++)
    if (xe[i])
    {
      for (j = 0; j < usb_n && !UsbFnFree(j); j++);
      if (j >= USB_NFN) break;
      g = &usb_fn[j];
      ClassCpy(g, f);
      g->on = 0;
      g->hq = NULL;
      g->ht = NULL;
      g->bht = NULL;
      g->tog = 0;
      MemSet(g->prev, 0, 8);
      g->par = idx + 1;
      g->kind = xk[i];
      g->ifn = xi[i];
      g->cls = xc[i];
      g->ep = xe[i];
      g->mps = xm[i];
      g->bin = 0;
      g->bout = 0;
      ln = 1;
      if (g->kind == USB_KIND_TABLET)
      {
        if (!xr[i]) xr[i] = 256;
        ln = UsbReq(f, USB_RT_IN | USB_RT_IF, USB_REQ_GET_DESC, USB_DT_REPORT << 8,
              xi[i], MinI64(xr[i], 900), d);
        if (ln > 0 && !UsbHidParse(&g->tab, d, ln))
          ln = 0;
      }
      else
        UsbReq(f, USB_RT_CLS | USB_RT_IF, 0x0B, 0, xi[i], 0);
      if (ln > 0)
      {
        g->on = 1;
        g->gen = ++usb_gen_ctr;
        if (j == usb_n)
          usb_n++;
        UsbEvt(j, TRUE);
      }
    }
  for (i = 0; i < nb && kind; i++)
  {
    for (j = 0; j < usb_n && !UsbFnFree(j); j++);
    if (j >= USB_NFN) break;
    g = &usb_fn[j];
    ClassCpy(g, f);
    g->hq = NULL;
    g->ht = NULL;
    g->bht = NULL;
    g->tog = 0;
    g->blen = 0;
    MemSet(g->prev, 0, 8);
    g->par = idx + 1;
    g->alt = 0;
    g->kind = bk[i];
    g->ifn = bf[i];
    g->cls = bcl[i];
    g->ep = 0;
    g->bin = bn[i];
    g->bout = bo[i];
    g->bmps = bp[i];
    g->on = 1;
    g->gen = ++usb_gen_ctr;
    if (j == usb_n)
      usb_n++;
    (*usb_ops[g->hc].bulk_rst)(g);
    UsbEvt(j, TRUE);
  }
  return idx;
}

U8 kt[128], kx[128], mc[8], me[8];

U0 UsbKbdTab()
{//HID usage -> PS/2 set 1 scan code (kt), with E0 prefix flag (kx).
  I64 u;
  for (u = 0; u < 128; u++)
  {
    kt[u] = 0;
    kx[u] = 0;
  }
  kt[0x04] = 0x1E; kt[0x05] = 0x30; kt[0x06] = 0x2E; kt[0x07] = 0x20; kt[0x08] = 0x12;
  kt[0x09] = 0x21; kt[0x0A] = 0x22; kt[0x0B] = 0x23; kt[0x0C] = 0x17; kt[0x0D] = 0x24;
  kt[0x0E] = 0x25; kt[0x0F] = 0x26; kt[0x10] = 0x32; kt[0x11] = 0x31; kt[0x12] = 0x18;
  kt[0x13] = 0x19; kt[0x14] = 0x10; kt[0x15] = 0x13; kt[0x16] = 0x1F; kt[0x17] = 0x14;
  kt[0x18] = 0x16; kt[0x19] = 0x2F; kt[0x1A] = 0x11; kt[0x1B] = 0x2D; kt[0x1C] = 0x15;
  kt[0x1D] = 0x2C;
  kt[0x1E] = 0x02; kt[0x1F] = 0x03; kt[0x20] = 0x04; kt[0x21] = 0x05; kt[0x22] = 0x06;
  kt[0x23] = 0x07; kt[0x24] = 0x08; kt[0x25] = 0x09; kt[0x26] = 0x0A; kt[0x27] = 0x0B;
  kt[0x28] = 0x1C; kt[0x29] = 0x01; kt[0x2A] = 0x0E; kt[0x2B] = 0x0F; kt[0x2C] = 0x39;
  kt[0x2D] = 0x0C; kt[0x2E] = 0x0D; kt[0x2F] = 0x1A; kt[0x30] = 0x1B; kt[0x31] = 0x2B;
  kt[0x33] = 0x27; kt[0x34] = 0x28; kt[0x35] = 0x29; kt[0x36] = 0x33; kt[0x37] = 0x34;
  kt[0x38] = 0x35; kt[0x39] = 0x3A;
  kt[0x3A] = 0x3B; kt[0x3B] = 0x3C; kt[0x3C] = 0x3D; kt[0x3D] = 0x3E; kt[0x3E] = 0x3F;
  kt[0x3F] = 0x40; kt[0x40] = 0x41; kt[0x41] = 0x42; kt[0x42] = 0x43; kt[0x43] = 0x44;
  kt[0x49] = 0x52; kt[0x4A] = 0x47; kt[0x4B] = 0x49; kt[0x4C] = 0x53; kt[0x4D] = 0x4F;
  kt[0x4E] = 0x51; kt[0x4F] = 0x4D; kt[0x50] = 0x4B; kt[0x51] = 0x50; kt[0x52] = 0x48;
  kx[0x49] = 1; kx[0x4A] = 1; kx[0x4B] = 1; kx[0x4C] = 1; kx[0x4D] = 1;
  kx[0x4E] = 1; kx[0x4F] = 1; kx[0x50] = 1; kx[0x51] = 1; kx[0x52] = 1;
  mc[0] = 0x1D; mc[1] = 0x2A; mc[2] = 0x38; mc[3] = 0; mc[4] = 0x1D; mc[5] = 0x36; mc[6] = 0x38; mc[7] = 0;
  me[0] = 0; me[1] = 0; me[2] = 0; me[3] = 0; me[4] = 1; me[5] = 0; me[6] = 1; me[7] = 0;
}

U0 UsbKeyInj(I64 sc, I64 ext, I64 down)
{
  U8 pk[2];
  I64 n = 0;
  if (ext)
  {
    pk[n] = 0xE0;
    n++;
  }
  if (!down) sc |= 0x80;
  pk[n] = sc;
  KbdPktInject(pk);
}

I64 UsbHas(U8 *arr, I64 u)
{
  I64 j;
  for (j = 2; j < 8; j++)
    if (arr[j] == u) return 1;
  return 0;
}

CUsbFn *usb_kbd_rep_f = NULL;
I64 usb_kbd_rep_u = 0, usb_kbd_rep_sc = 0, usb_kbd_rep_ext = 0, usb_kbd_rep_t = 0;
public I64 usb_kbd_rep_delay = 400, usb_kbd_rep_rate = 35;

U0 UsbKbdRepStop()
{//Forget the key armed for typematic repeat.
  usb_kbd_rep_f = NULL;
  usb_kbd_rep_u = 0;
}

U0 UsbKbdRepStart(CUsbFn *f, I64 u)
{//Arm typematic repeat on the key that just went down.
  usb_kbd_rep_f = f;
  usb_kbd_rep_u = u;
  usb_kbd_rep_sc = kt[u];
  usb_kbd_rep_ext = kx[u];
  usb_kbd_rep_t = GetTSC + cnts.time_stamp_freq * usb_kbd_rep_delay / 1000;
}

U0 UsbKbdRepTick()
{//A held key sends no further boot reports, so the make code is resent here the
//way a PS/2 keyboard's own typematic does. Core 0, every UsbEvtTask pass.
  if (!usb_kbd_rep_f || !usb_kbd_rep_u) return;
  if (GetTSC < usb_kbd_rep_t) return;
  UsbKeyInj(usb_kbd_rep_sc, usb_kbd_rep_ext, 1);
  usb_kbd_rep_t = GetTSC + cnts.time_stamp_freq * usb_kbd_rep_rate / 1000;
}

U0 UsbKbdRep(CUsbFn *f, U8 *rep)
{
  I64 i, j, u;
  for (i = 0; i < 8; i++)
    if (mc[i] && Bt(rep, i) != Bt(f->prev, i))
      UsbKeyInj(mc[i], me[i], Bt(rep, i));
  for (j = 2; j < 8; j++)
  {
    u = f->prev[j];
    if (u && u < 128 && kt[u] && !UsbHas(rep, u))
    {
      UsbKeyInj(kt[u], kx[u], 0);
      if (usb_kbd_rep_f == f && usb_kbd_rep_u == u)
        UsbKbdRepStop;
    }
  }
  for (j = 2; j < 8; j++)
  {
    u = rep[j];
    if (u && u < 128 && kt[u] && !UsbHas(f->prev, u))
    {
      UsbKeyInj(kt[u], kx[u], 1);
      UsbKbdRepStart(f, u);
    }
  }
  MemCpy(f->prev, rep, 8);
}

U0 UsbMsPkt(U8 *rep, U8 *pk)
{//Boot mouse report -> PS/2 packet. Report byte 3 is the HID wheel, counting up
//away from the user; the PS/2 Z nibble counts up toward the user, so negate it.
//It is 4 bits, and buttons 4 and 5 ride in the same byte.
  I64 dx = rep[1], dy = rep[2], dz = rep[3], fl, z;
  if (dx > 127) dx -= 256;
  if (dy > 127) dy -= 256;
  if (dz > 127) dz -= 256;
  z = 0 - dz;
  if (z > 7) z = 7;
  if (z < -8) z = -8;
  fl = rep[0] & 7 | 0x08;
  if (dx < 0) fl |= 0x10;
  if (dy > 0) fl |= 0x20;
  pk[0] = fl;
  pk[1] = rep[1];
  pk[2] = 0 - rep[2];
  pk[3] = z & 0x0F;
  if (Bt(rep, 3)) pk[3] |= 0x10;
  if (Bt(rep, 4)) pk[3] |= 0x20;
}

I64 UsbHidRel(U8 *rep, I64 off, I64 bits)
{//Signed relative field, clamped to a boot mouse byte.
  I64 v = BFieldExtU32(rep, off, bits);
  if (bits < 32 && Bt(&v, bits - 1))
    v -= 1 << bits;
  return ClampI64(v, -127, 127);
}

U0 UsbTabRep(CUsbFn *f, U8 *rep)
{//Relative mouse as a boot mouse report, absolute pointer scaled to the screen.
  CUsbTab *t = &f->tab;
  I64 x, y;
  U8 m[4], pk[4];
  if (t->mx >= 0 && (!t->mrid || *rep == t->mrid))
  {
    if (t->mrid) rep++;
    m[0] = 0;
    if (t->mbtn >= 0)
      m[0] = BFieldExtU32(rep, t->mbtn, t->mnb);
    m[1] = UsbHidRel(rep, t->mx, t->mxs);
    m[2] = UsbHidRel(rep, t->my, t->mys);
    m[3] = 0;
    if (t->mw >= 0)
      m[3] = UsbHidRel(rep, t->mw, t->mws);
    UsbMsPkt(m, pk);
    MsPktInject(pk);
    return;
  }
  if (t->x < 0) return;
  if (t->rid)
  {
    if (*rep != t->rid) return;
    rep++;
  }
  ms_inject = TRUE;
  x = BFieldExtU32(rep, t->x, t->xs) * GR_WIDTH / (t->xmax + 1);
  y = BFieldExtU32(rep, t->y, t->ys) * GR_HEIGHT / (t->ymax + 1);
  if (t->btn >= 0)
    MsHardSet(x, y, ms.pos.z, Bt(rep, t->btn), Bt(rep, t->btn + 1));
  else
    MsHardSet(x, y, ms.pos.z, 0, 0);
}

U0 UsbHidRep(CUsbFn *f, U8 *rep)
{
  U8 pk[4];
  switch (f->kind)
  {
  case USB_KIND_MOUSE:
    UsbMsPkt(rep, pk);
    MsPktInject(pk);
    break;
  case USB_KIND_KBD:
    UsbKbdRep(f, rep);
    break;
  case USB_KIND_TABLET:
    UsbTabRep(f, rep);
    break;
  }
}

#define USB_EQ 32
I64 usb_eq[USB_EQ], usb_eq_in = 0, usb_eq_out = 0, usb_eq_lock = 0;
U0 (*fp_usb_plug)(I64 k, Bool on, I64 kind) = NULL;
U0 (*fp_usb_poll)() = NULL;

U0 UsbEvt(I64 k, Bool on)
{//Queue a plug (on) or unplug event of usb_fn[k], with its kind, for fp_usb_plug.
  while (LBts(&usb_eq_lock, 0))
    Yield;
  if (usb_eq_in - usb_eq_out < USB_EQ)
    usb_eq[usb_eq_in++ & (USB_EQ - 1)] = k | on << 8 | usb_fn[k].kind << 16;
  LBtr(&usb_eq_lock, 0);
}

#define USB_HQ 64
class CUsbHidQ
{
  CUsbFn *f;
  U8 rep[USB_INT_SZ];
};
CUsbHidQ usb_hq[USB_HQ];
I64 usb_hq_in = 0, usb_hq_out = 0;
Bool usb_hq_on = FALSE;

U0 UsbIntRep(CUsbFn *f, U8 *rep)
{//Interrupt IN data. HID reports are injected on core 0.
  CUsbHidQ *q;
  if (f->kind == USB_KIND_HUB)
    f->chg |= rep[0] | rep[1] << 8;
  else if (!usb_hq_on)
    UsbHidRep(f, rep);
  else if (usb_hq_in - usb_hq_out < USB_HQ)
  {
    q = &usb_hq[usb_hq_in & (USB_HQ - 1)];
    q->f = f;
    MemCpy(q->rep, rep, USB_INT_SZ);
    usb_hq_in++;
  }
}

U0 UsbEvtTask(U8 *)
{//Core 0: queued HID reports, and plug events for fp_usb_plug.
  CUsbHidQ *q;
  I64 e;
  while (TRUE)
  {
    while (usb_hq_out != usb_hq_in)
    {
      q = &usb_hq[usb_hq_out & (USB_HQ - 1)];
      UsbHidRep(q->f, q->rep);
      usb_hq_out++;
    }
    UsbKbdRepTick;
    while (fp_usb_plug && Bt(&sys_run_level, RLf_ADAM_SERVER) &&
          usb_eq_out != usb_eq_in)
    {
      e = usb_eq[usb_eq_out++ & (USB_EQ - 1)];
      try
        (*fp_usb_plug)(e & 0xFF, e >> 8 & 1, e >> 16);
      catch
      {
        PutExcept;
        Fs->catch_except = TRUE;
      }
    }
    Sleep(5);
  }
}

U0 UsbFnOff(I64 k)
{//Device gone: stop its interrupt pipe, then everything behind it.
  CUsbFn *f = &usb_fn[k];
  I64 j;
  if (!f->on) return;
  f->on = 0;
  if (usb_kbd_rep_f == f)
    UsbKbdRepStop;
  MemSet(usb_buf + USB_BUF_INT + k * USB_INT_SZ, 0, USB_INT_SZ);
  UsbEvt(k, FALSE);
  if (f->hq)
    (*usb_ops[f->hc].int_stop)(f);
  if (f->kind == USB_KIND_CDC)
    UsbCdcUnplug(k);
  if (f->kind == USB_KIND_ECM)
    UsbEcmUnplug(k);
  if (f->kind == USB_KIND_MIDI || f->kind == USB_KIND_LPT ||
        f->kind == USB_KIND_VENDOR || f->kind == USB_KIND_VIDEO ||
        f->kind == USB_KIND_AUDIO)
    UsbVenUnplug(k);
  for (j = 0; j < usb_n; j++)
    if (usb_fn[j].par == k + 1)
      UsbFnOff(j);
  if (usb_ops[f->hc].dev_off && !f->par)
    (*usb_ops[f->hc].dev_off)(f);
  for (j = 0; j < usb_n; j++)
    if (usb_fn[j].hub == k)
      UsbFnOff(j);
}

U0 UsbHubPort(I64 k, I64 p)
{
  CUsbFn *f = &usb_fn[k], t;
  U16 st[2];
  I64 j, idx;
  if (UsbReq(f, USB_HUB_RT_IN, USB_REQ_GET_STATUS, 0, p, 4, st) < 4)
    return;
  for (j = 0; j < 5; j++)
    if (Bt(&st[1], j))
      UsbReq(f, USB_HUB_RT_OUT, USB_REQ_CLR_FEATURE, USB_HUB_C_CONN + j, p, 0);
  if (!(st[0] & 1))
  {
    for (j = 0; j < usb_n; j++)
      if (usb_fn[j].hub == k && usb_fn[j].hport == p)
        UsbFnOff(j);
    f->hpen[p] = 0;
    return;
  }
  if (f->hpen[p] == 1 || f->hpen[p] > 4) return;
  UsbReq(f, USB_HUB_RT_OUT, USB_REQ_SET_FEATURE, USB_HUB_RESET, p, 0);
  for (j = 0; j < 50; j++)
  {
    UsbWait(5);
    UsbReq(f, USB_HUB_RT_IN, USB_REQ_GET_STATUS, 0, p, 4, st);
    if (!(st[0] & 0x10)) break;
  }
  UsbReq(f, USB_HUB_RT_OUT, USB_REQ_CLR_FEATURE, USB_HUB_C_RST, p, 0);
  UsbWait(10);
  ZeroClass(&t);
  t.hc = f->hc;
  t.hci = f->hci;
  t.port = f->port;
  t.hub = k;
  t.hport = p;
  t.speed = USB_SPD_FS;
  if (st[0] & 0x200)
    t.speed = USB_SPD_LS;
  else if (st[0] & 0x400)
    t.speed = USB_SPD_HS;
  if (f->speed == USB_SPD_HS)
  {
    t.tt_adr = f->adr;
    t.tt_port = p;
  }
  else
  {
    t.tt_adr = f->tt_adr;
    t.tt_port = f->tt_port;
  }
  idx = UsbEnum(&t);
  if (idx < 0)
  {
    f->hpen[p] = MaxI64(f->hpen[p], 1) + 1;
    Bts(&f->chg, p);
    UsbWait(50);
    return;
  }
  f->hpen[p] = 1;
  UsbIntOn(idx);
}

U0 UsbHubPoll()
{
  I64 k, p;
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].kind == USB_KIND_HUB && usb_fn[k].on && usb_fn[k].chg)
      for (p = 1; p <= usb_fn[k].nports; p++)
        if (Btr(&usb_fn[k].chg, p))
          UsbHubPort(k, p);
}

I64 UsbMsCmd(CUsbFn *f, U8 *cdb, I64 cbl, I64 dirin, I64 dlen)
{//Bulk-only transport: CBW, data at usb_bd+128, CSW. Caller holds usb_lock.
  CUsbCbw *cbw = usb_bd;
  CUsbCsw *csw = usb_bd + 64;
  U8 *dp = usb_bd + 128;
  I64 r, n = 0;
  ZeroClass(cbw);
  cbw->sig = USB_CBW_SIG;
  cbw->tag = f->adr * 256 + f->btog_o;
  cbw->dlen = dlen;
  if (dirin) cbw->flags = 0x80;
  cbw->cbl = cbl;
  MemCpy(cbw->cdb, cdb, cbl);
  r = UsbBulk(f, 0, usb_bd, 31);
  if (r != 31)
    return -1;
  if (dlen > 0 && (n = UsbBulk(f, dirin, dp, dlen)) < 0)
    return -1;
  MemSet(csw, 0, 13);
  r = UsbBulk(f, 1, usb_bd + 64, 13);
  if (r != 13 || csw->sig != USB_CSW_SIG || csw->status != 0)
    return -1;
  return MinI64(n, dlen - csw->resid);
}

U0 UsbBe(U8 *p, I64 v, I64 n)
{
  I64 i;
  for (i = n - 1; i >= 0; i--)
  {
    p[i] = v % 256;
    v /= 256;
  }
}

I64 UsbBeGet(U8 *p, I64 n)
{
  I64 i, v = 0;
  for (i = 0; i < n; i++)
    v = v * 256 + p[i];
  return v;
}

I64 ums_k = -1, ums_gen = -1;
I64 ums_blocks = 0;

U0 UsbMsRst(CUsbFn *f)
{//Bulk-only reset recovery: reset, clear both halts, reset toggles.
  UsbReq(f, USB_RT_CLS | USB_RT_IF, 0xFF, 0, f->ifn, 0);
  UsbReq(f, USB_RT_EP, USB_REQ_CLR_FEATURE, 0, f->bin | USB_EP_IN, 0);
  UsbReq(f, USB_RT_EP, USB_REQ_CLR_FEATURE, 0, f->bout, 0);
  (*usb_ops[f->hc].bulk_rst)(f);
}

Bool UsbMsRw(CUsbFn *f, U8 *buf, I64 blk, I64 cnt, Bool wr)
{//SCSI READ(10)/WRITE(10) in USB_MS_BLKS chunks.
  U8 cdb[16];
  I64 done = 0, n, tries;
  Bool ok;
  while (done < cnt)
  {
    if (!f->on) return FALSE;
    n = cnt - done;
    if (n > USB_MS_BLKS) n = USB_MS_BLKS;
    MemSet(cdb, 0, 16);
    cdb[0] = 0x28;
    if (wr)
      cdb[0] = 0x2A;
    UsbBe(cdb + 2, blk + done, 4);
    UsbBe(cdb + 7, n, 2);
    for (tries = 0; TRUE; tries++)
    {
      UsbLock;
      if (wr)
        MemCpy(usb_bd + 128, buf + done * 512, n * 512);
      ok = UsbMsCmd(f, cdb, 10, !wr, n * 512) == n * 512;
      if (ok && !wr)
        MemCpy(buf + done * 512, usb_bd + 128, n * 512);
      UsbUnlock;
      if (ok)
        break;
      if (tries == 2 || !f->on)
        return FALSE;
      DbgS6("usb ms reset\n");
      UsbMsRst(f);
    }
    done += n;
  }
  return TRUE;
}

Bool UsbMsLive(I64 k, I64 gen)
{//A stale (k,gen) pair fails here instead of writing to the wrong stick.
  CUsbFn *f = UsbFnAt(k);
  if (!f) return FALSE;
  return f->kind == USB_KIND_MSD && f->gen == gen;
}

public I64 UsbMsBlocks()
{//Blocks of the last mounted stick, 0 once that handle has gone stale.
  if (!UsbMsLive(ums_k, ums_gen))
    return 0;
  return ums_blocks;
}

Bool UsbMsWrite(U8 *buf, I64 blk, I64 cnt)
{//fp_usb_blkdev_write, for SD.HC's MkPrtGen.
  if (!UsbMsLive(ums_k, ums_gen))
    return FALSE;
  return UsbMsRw(&usb_fn[ums_k], buf, blk, cnt, TRUE);
}

Bool UsbBlkRw(CBlkDev *bd, U8 *buf, I64 blk, I64 cnt, Bool wr)
{//fp_usb_blk_rw: bd->base0 is the usb_fn index.
  return UsbMsRw(&usb_fn[bd->base0], buf, blk, cnt, wr);
}

public I64 UsbDevKind(I64 k)
{//USB_KIND_* of device k (0 to usb_n-1), -1 if gone.
  CUsbFn *f = UsbFnAt(k);
  if (!f) return -1;
  return f->kind;
}

public I64 UsbDevLets(I64 k)
{//Mounted drive letters of device k: bit let-'A'.
  I64 i, m = 0;
  CDrv *dv;
  for (i = 0; i < DRVS_NUM; i++)
  {
    dv = &blkdev.drvs[i];
    if (dv->dv_signature == DRV_SIGNATURE_VAL && dv->bd &&
          dv->bd->type == BDT_USB && dv->bd->base0 == k)
      Bts(&m, dv->drv_let - 'A');
  }
  return m;
}

Bool UsbFnFree(I64 k)
{//An unplugged entry with nothing mounted or attached can be reused.
  I64 j;
  if (usb_fn[k].on || UsbDevLets(k))
    return FALSE;
  for (j = 0; j < usb_n; j++)
    if (usb_fn[j].hub == k && usb_fn[j].on)
      return FALSE;
  return TRUE;
}

I64 UsbMsCapacity(CUsbFn *f)
{//SCSI READ CAPACITY(10), retried past the wake-up unit-attention.
  U8 cdb[16];
  I64 i, blks;
  for (i = 0; i < 10; i++)
  {
    MemSet(cdb, 0, 16);
    cdb[0] = 0x25;
    UsbLock;
    if (UsbMsCmd(f, cdb, 10, 1, 8) == 8)
    {
      blks = UsbBeGet(usb_bd + 128, 4) + 1;
      UsbUnlock;
      return blks;
    }
    cdb[0] = 0x03;
    cdb[4] = 18;
    UsbMsCmd(f, cdb, 6, 1, 18);
    UsbUnlock;
    UsbWait(100);
  }
  return 0;
}

Bool UsbMsWholeDrv(U8 *b0)
{//Is sector 0 a boot record itself, rather than a partition table?
  return (b0[0] == 0xEB || b0[0] == 0xE9) && b0[11] == 0 && b0[12] == 2 ||
        !b0[0x1C2] && !b0[0x1D2] && !b0[0x1E2] && !b0[0x1F2];
}

public U8 UsbMountAt(I64 k = -1, U8 drv_let = 0)
{//Mount stick k at drv_let, or the first free USB letter. Returns it, or 0.
  U8 b0[BLK_SIZE];
  I64 i, blks, let;
  Bool whole;
  CUsbFn *f;
  CBlkDev *bd;
  if (k < 0)
    for (k = 0; k < usb_n; k++)
      if (UsbDevKind(k) == USB_KIND_MSD && !UsbDevLets(k))
        break;
  if (UsbDevKind(k) != USB_KIND_MSD || UsbDevLets(k))
    return 0;
  if (drv_let)
  {
    let = Let2Let(drv_let);
    if (!('A' <= let <= 'Z') ||
          blkdev.drvs[let - 'A'].dv_signature == DRV_SIGNATURE_VAL)
      return 0;
  }
  else
  {
    for (let = USB_FIRST_DRV_LET; let <= 'Z' &&
          blkdev.drvs[let - 'A'].dv_signature == DRV_SIGNATURE_VAL; let++);
    if (let > 'Z')
      return 0;
  }
  f = &usb_fn[k];
  blks = UsbMsCapacity(f);
  if (!blks)
    return 0;
  if (!UsbMsRw(f, b0, 0, 1, FALSE))
    return 0;
  whole = UsbMsWholeDrv(b0);
  fp_usb_blk_rw = &UsbBlkRw;
  SetDrvLetType(let, BDT_USB);
  bd = BlkDevNextFreeSlot(let, BDT_USB);
  bd->base0 = k;
  bd->max_blk = blks - 1;
  if (!BlkDevAdd(bd, I64_MIN, whole, TRUE))
  {
    DbgS6("msd mount failed\n");
    return 0;
  }
  for (i = 0; i < DRVS_NUM; i++)
    if (blkdev.drvs[i].dv_signature == DRV_SIGNATURE_VAL && blkdev.drvs[i].bd == bd)
      SetDrvLetType(blkdev.drvs[i].drv_let, BDT_USB);
  if (whole && RedSeaValidate(let))
    RedSeaInit(Let2Drv(let));
  ums_k = k;
  ums_gen = f->gen;
  ums_blocks = blks;
  fp_usb_blkdev_write = &UsbMsWrite;
  DbgS6("msd mounted\n");
  return let;
}

public U8 UsbMount(I64 k = -1)
{//Mount USB stick k at the first free letter of U-Z. Returns it, or 0.
  return UsbMountAt(k);
}

U0 UsbPoll(Bool ports = TRUE)
{//Transfers (HID reports, hub changes); root ports if ports.
  I64 k;
  XhciPoll(ports);
  EhciPoll(ports);
  OhciPoll(ports);
  UhciPoll(ports);
  UsbHubPoll;
  for (k = 0; k < usb_n; k++)
    if (usb_fn[k].on && usb_fn[k].kind == USB_KIND_CDC)
      UsbCdcPoll(k);
    else if (usb_fn[k].on && usb_fn[k].kind == USB_KIND_ECM)
      UsbEcmPoll(k);
  if (fp_usb_poll)
    try
      (*fp_usb_poll)();
    catch
    {
      fp_usb_poll = NULL;
      PutExcept;
      Fs->catch_except = TRUE;
    }
}

U0 UsbPollBoot()
{//$LK,"UsbPoll",A="MN:UsbPoll"$() only while no USB task owns the controller rings, as when
//the kernel config streams a $LK,"UsbMountVol",A="MN:UsbMountVol"$() for the boot drive.
  if (!Bt(&sys_run_level, RLf_ADAM_SERVER))
    UsbPoll;
}

U0 UsbInit()
{//EHCI first, so full/low-speed ports are handed to the companions.
  if (usb_ready) return;
  UsbBufInit;
  UsbKbdTab;
  XhciInit;
  EhciInit;
  OhciInit;
  UhciInit;
  usb_ready = 1;
}

I64 usb_cpu = 0, usb_t0 = 0, usb_busy = 0;

U0 UsbTask(U8 *)
{//USB init (if the boot did not), then hot-plug and HID.
  I64 n = 0, t;
  UsbInit;
  usb_cpu = Gs->num;
  usb_t0 = GetTSC;
  while (TRUE)
  {
    t = GetTSC;
    UsbPoll(!(n++ % 20));
    usb_busy += GetTSC - t;
    Sleep(5);
  }
}

U0 UsbTaskStart()
{//Core 0 draws and runs the window manager: poll on core 1 if there is one.
  usb_hq_on = mp_cnt > 1;
  Spawn(&UsbEvtTask, NULL, "USB Events",, Fs);
  if (usb_hq_on)
    Spawn(&UsbTask, NULL, "USB", 1);
  else
    Spawn(&UsbTask, NULL, "USB");
}

U0 UsbBootMark()
{//Shows on debugcon which kernel booted.
  U8 buf[80];
  StrPrint(buf, "kmain: kernel compiled %D %T\n", sys_compile_time, sys_compile_time);
  DbgS6(buf);
}

U0 UsbBootInit()
{//Boot drive missing: mount a USB stick as U: and boot from it.
  I64 t, let = 0;
  U8 buf[120];
  UsbInit;
  for (t = 0; t < 100 && !(let = UsbMount); t++)
  {
    UsbPoll;
    UsbWait(50);
  }
  if (let)
    blkdev.boot_drv_let = let;
  StrPrint(buf, "usb boot: let %c mounted %d\n", let, let != 0);
  DbgS6(buf);
  if (!let)
  {
    "USB boot: no USB stick mounted\n";
    UsbRep;
  }
}

#define USB_STR_LEN  40
#define USB_LBL_LEN  16

I64 UsbStrDesc(CUsbFn *f, I64 idx, U8 *buf, I64 max)
{//String descriptor idx of f, as ASCII in buf. Returns its length. Many
//sticks carry no strings, so 0 is a normal answer.
  U8 *d;
  I64 n, i, j = 0, lang = 0x0409;
  buf[0] = 0;
  if (!idx)
    return 0;
  d = CAlloc(256);
  if (UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_STR << 8, 0, 4, d) >= 4 &&
        d[1] == USB_DT_STR && (d[2] || d[3]))
    lang = d[2] + d[3] << 8;
  n = UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_STR << 8 | idx, lang,
        255, d);
  if (n >= 4 && d[1] == USB_DT_STR)
  {
    if (d[0] < n)
      n = d[0];
    for (i = 2; i + 1 < n && j < max - 1; i += 2)
    {
      if (!d[i] && !d[i + 1])
        break;
      if (d[i + 1] || !(0x20 <= d[i] <= 0x7E))
        buf[j++] = '?';
      else
        buf[j++] = d[i];
    }
  }
  buf[j] = 0;
  while (j && buf[j - 1] == ' ')
    buf[--j] = 0;
  Free(d);
  return j;
}

public I64 UsbDevName(I64 k, U8 *buf, I64 max)
{//"<manufacturer> <product>" of device k into buf ($LK,"STR_LEN",A="MN:STR_LEN"$), 0 if it offers
//neither. On demand, not at enumeration: a stick that stalls a string
//request then only costs whoever asked for the listing.
  U8 *d, mfr[USB_STR_LEN], prod[USB_STR_LEN];
  CUsbFn *f = UsbFnAt(k);
  buf[0] = 0;
  if (!f || max < 2)
    return 0;
  *mfr = 0;
  *prod = 0;
  d = CAlloc(32);
  if (UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_DEV << 8, 0, 18, d) == 18)
  {
    UsbStrDesc(f, d[14], mfr, USB_STR_LEN);
    UsbStrDesc(f, d[15], prod, USB_STR_LEN);
  }
  Free(d);
  if (*mfr && *prod)
    StrPrint(buf, "%s %s", mfr, prod);
  else if (*prod)
    StrPrint(buf, "%s", prod);
  else if (*mfr)
    StrPrint(buf, "%s", mfr);
  return StrLen(buf);
}

U8 UsbVolLet(CBlkDev *bd, I64 ser)
{//Letter of bd's partition whose boot record carries ser.  0 if none does.
  I64 i;
  CDrv *dv;
  if (!bd)
    return 0;
  for (i = 0; i < DRVS_NUM; i++)
  {
    dv = &blkdev.drvs[i];
    if (dv->dv_signature == DRV_SIGNATURE_VAL && dv->bd == bd &&
          DrvVolSerial(Drv2Let(dv)) == ser)
      return Drv2Let(dv);
  }
  return 0;
}

public U8 UsbMountVol(I64 ser, U8 first_drv_let = 0, I64 timeout_ms = 6000)
{//Mount the stick holding this $LK,"BlkVolSerial",A="MN:BlkVolSerial"$() at first_drv_let, returning the
//matching partition's letter or 0. How an installed kernel finds its USB
//drive again: a stick has no port to be named by, so $LK,"Mount",A="MN:Mount"$() records the id
//$LK,"Fmt",A="MN:Fmt"$() put in the partition. Non-matches are mounted and dropped, read-only.
  I64 k, t, m, let, hit;
  CBlkDev *bd;
  if (!ser)
    return 0;
  UsbInit;
  for (t = 0; t < timeout_ms; t += 50)
  {
    UsbPollBoot;
    for (k = 0; k < usb_n; k++)
      if (UsbDevKind(k) == USB_KIND_MSD)
      {
        m = UsbDevLets(k);
        if (m)
        {
          hit = UsbVolLet(Let2BlkDev(Bsf(m) + 'A', FALSE), ser);
          if (hit)
            return hit;
        }
        else
        {
          let = UsbMountAt(k, first_drv_let);
          if (let)
          {
            bd = Let2BlkDev(let, FALSE);
            hit = UsbVolLet(bd, ser);
            if (hit)
              return hit;
            BlkDevDel(bd);
          }
        }
      }
    UsbWait(50);
  }
  return 0;
}

U0 UsbVolRepLine(I64 prt, I64 mbr_type, U8 *br, I64 blks)
{//Listing entry for a boot record: partition, FS, size, label, then the vol
//serial $LK,"Mount",A="MN:Mount"$() would record for $LK,"UsbMountVol",A="MN:UsbMountVol"$().
  U8 lbl[USB_LBL_LEN], *fs = BlkVolFSName(br);
  I64 ser = BlkVolSerial(br);
  if (prt < 0)
    "    whole drv";
  else
    "    prt %d", prt;
  if (fs)
    " %s", fs;
  else
    " type %02X", mbr_type;
  " %dMB", blks >> 11;
  if (BlkVolLabel(br, lbl, USB_LBL_LEN))
    " \"%s\"", lbl;
  '\n';
  if (ser)
    "        vol serial 0x%016X\n", ser;
  else
    "        no vol serial, cannot be named across ports\n";
}

I64 UsbVolScan(I64 k, Bool rep)
{//First $LK,"BlkVolSerial",A="MN:BlkVolSerial"$() among stick k's boot records, 0 if none. Any one
//identifies the stick, since a mount takes the whole device. rep lists all.
  U8 *b0, *br;
  I64 i, res = 0, ser, blks;
  CMasterBoot *mbr;
  CUsbFn *f = UsbFnAt(k);
  if (!f || f->kind != USB_KIND_MSD)
    return 0;
  blks = UsbMsCapacity(f);
  if (!blks)
    return 0;
  b0 = CAlloc(BLK_SIZE);
  br = CAlloc(BLK_SIZE);
  if (UsbMsRw(f, b0, 0, 1, FALSE))
  {
    if (UsbMsWholeDrv(b0))
    {
      res = BlkVolSerial(b0);
      if (rep)
        UsbVolRepLine(-1, 0, b0, blks);
    }
    else
    {
      mbr = b0;
      for (i = 0; i < 4; i++)
        if ((rep || !res) && mbr->p[i].type && mbr->p[i].offset &&
              UsbMsRw(f, br, mbr->p[i].offset, 1, FALSE))
        {
          ser = BlkVolSerial(br);
          if (rep)
            UsbVolRepLine(i, mbr->p[i].type, br, mbr->p[i].size);
          if (ser && !res)
            res = ser;
        }
    }
  }
  Free(br);
  Free(b0);
  return res;
}

public I64 UsbVolSerial(I64 k)
{//Volume serial identifying USB stick k, for $LK,"UsbMountVol",A="MN:UsbMountVol"$().  0 if it has none.
  return UsbVolScan(k, FALSE);
}

public I64 UsbMsdRep()
{//List the USB storage devices so $LK,"Mount",A="MN:Mount"$() and the installer can tell two
//sticks apart: index, VID:PID, size, mounted letters, name, partitions.
  I64 k, p, m, n = 0, blks;
  U8 nm[STR_LEN];
  CUsbFn *f;
  UsbInit;
  UsbPollBoot;
  for (k = 0; k < usb_n; k++)
  {
    f = &usb_fn[k];
    if (f->kind == USB_KIND_MSD && f->on)
    {
      n++;
      blks = UsbMsCapacity(f);
      "$$PURPLE$$%d$$FG$$ %04X:%04X %dMB", k, f->vid, f->pid, blks >> 11;
      m = UsbDevLets(k);
      for (p = 0; p < 26; p++)
        if (Bt(&m, p))
          " %C:", p + 'A';
      '\n';
      if (UsbDevName(k, nm, STR_LEN))
        "    %s\n", nm;
      UsbVolScan(k, TRUE);
    }
  }
  if (!n)
    "No USB storage devices found.\n";
  return n;
}

U0 UsbRepHc(I64 cls, U8 *name, I64 used, I64 *np, I64 step = 0)
{//PCI controllers of one class; the first 'used' of them are driven.
  I64 n, bdf, b, d, f;
  if (PCIClassFind(cls, 0) == -1)
    "%s none\n", name;
  for (n = 0; (bdf = PCIClassFind(cls, n)) != -1; n++)
  {
    b = bdf >> 16;
    d = bdf >> 8 & 0xFF;
    f = bdf & 0xFF;
    "%s%d %02X:%02X.%X %04X:%04X ", name, n, b, d, f,
          PCIReadU16(b, d, f, 0), PCIReadU16(b, d, f, 2);
    if (n < used)
      "%d ports\n", *(np(U8 *) + n * step)(I64 *);
    else
      "no driver\n";
  }
}

public U0 UsbRep()
{//List USB host controllers and the devices found on them.
  I64 k, p, st, m, two = 2, b;
  U16 hs[2];
  CUsbFn *f;
  if (!usb_ready)
  {
    "USB not initialized\n";
    return;
  }
  UsbRepHc(USB_PCI_EHCI, "EHCI", ehn, &ehc[0].nports, sizeof(CEhciHc));
  UsbRepHc(USB_PCI_OHCI, "OHCI", ohn, &ohc[0].nports, sizeof(COhciHc));
  UsbRepHc(USB_PCI_UHCI, "UHCI", uhn, &two);
  UsbRepHc(USB_PCI_XHCI, "XHCI", xhn, &xhc[0].nports, sizeof(CXhciHc));
  if (usb_t0)
  {
    b = usb_busy * 10000 / (GetTSC - usb_t0);
    "USB task: CPU%d, %d.%02d%% busy, XHCI endpoint resets %d\n", usb_cpu,
          b / 100, b % 100, xnrst;
  }
  for (k = 0; k < usb_n; k++)
  {
    f = &usb_fn[k];
    "#%d %s%d port %d", k, LstSub(f->hc, "?\0UHCI\0EHCI\0OHCI\0XHCI\0"), f->hci,
          f->port + 1;
    if (f->hub >= 0)
      " hub #%d.%d", f->hub, f->hport;
    " %s adr %d %04X:%04X class %06X %s", LstSub(f->speed, "FS\0LS\0HS\0SS\0"),
          f->adr, f->vid, f->pid, f->cls,
          LstSub(f->kind, "unsupported\0keyboard\0mouse\0storage\0hub\0tablet\0serial\0ethernet\0midi\0printer\0vendor\0video\0audio\0");
    if (f->par)
      " i/f %d of #%d", f->ifn, f->par - 1;
    if (f->kind == USB_KIND_HUB)
      " %d ports", f->nports;
    if (f->kind == USB_KIND_HUB && f->on)
      for (p = 1; p <= f->nports; p++)
        if (UsbReq(f, USB_HUB_RT_IN, USB_REQ_GET_STATUS, 0, p, 4, hs) == 4 &&
              (st = hs[0]) & 1)
          " p%d:%04X", p, st;
    m = UsbDevLets(k);
    for (p = 0; p < 26; p++)
      if (Bt(&m, p))
        " %c:", p + 'A';
    if (!f->on)
      " (gone)";
    '\n';
  }
  if (usb_n >= USB_NFN)
    "Device table full\n";
  f = &usb_efn;
  if (usb_efail)
    "Enumeration failures: %d, last %s%d port %d hub #%d.%d %s\n", usb_efail,
          LstSub(f->hc, "?\0UHCI\0EHCI\0OHCI\0XHCI\0"), f->hci, f->port + 1,
          f->hub, f->hport, LstSub(f->speed, "FS\0LS\0HS\0SS\0");
}

U8 *UsbDtName(I64 type)
{
  switch (type)
  {
  case 1:    return "DEV";
  case 2:    return "CFG";
  case 4:    return "IF";
  case 5:    return "EP";
  case 0x0B: return "IAD";
  case 0x21: return "HID";
  case 0x24: return "CS_IF";
  case 0x25: return "CS_EP";
  case 0x29: return "HUB";
  case 0x30: return "SS_EPC";
  }
  return "?";
}

public I64 UsbDesc(I64 k, U8 *filename = NULL)
{//Dump device k's device and configuration descriptors.
  U8 *d, *p;
  I64 n = 0, i;
  CUsbFn *f = UsbFnAt(k);
  if (!f)
  {
    "No USB device #%d\n", k;
    return 0;
  }
  d = CAlloc(18 + USB_DATA_MAX);
  if (UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_DEV << 8, 0, 18, d) == 18 &&
        UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_CFG << 8, 0, 9, d + 18) == 9)
    n = 18 + MaxI64(UsbReq(f, USB_RT_IN, USB_REQ_GET_DESC, USB_DT_CFG << 8, 0,
          MinI64(d(U16 *)[9 + 1], USB_DATA_MAX), d + 18), 0);
  if (!n)
    "Reading descriptors of #%d failed\n", k;
  for (p = d; p + 2 <= d + n && *p >= 2; p += *p)
  {
    "%-6s", UsbDtName(p[1]);
    for (i = 0; i < *p && p + i < d + n; i++)
    {
      if (i && !(i & 15))
        "\n      ";
      "%02X ", p[i];
    }
    '\n';
  }
  if (filename && n)
    FileWrite(filename, d, n);
  Free(d);
  return n;
}
