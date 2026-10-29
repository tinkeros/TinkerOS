#define USB_PCI_UHCI 0x0C0300
#define USB_PCI_OHCI 0x0C0310
#define USB_PCI_EHCI 0x0C0320
#define USB_PCI_XHCI 0x0C0330

#define USB_REQ_GET_STATUS  0
#define USB_REQ_CLR_FEATURE 1
#define USB_REQ_SET_FEATURE 3
#define USB_REQ_SET_ADDR    5
#define USB_REQ_GET_DESC    6
#define USB_REQ_SET_DESC    7
#define USB_REQ_GET_CFG     8
#define USB_REQ_SET_CFG     9
#define USB_REQ_GET_IF      10
#define USB_REQ_SET_IF      11

#define USB_DT_DEV     1
#define USB_DT_CFG     2
#define USB_DT_STR     3
#define USB_DT_IF      4
#define USB_DT_EP      5
#define USB_DT_HID     0x21
#define USB_DT_REPORT  0x22

#define USB_CLS_AUDIO 1
#define USB_CLS_HID   3
#define USB_CLS_PRN   7
#define USB_CLS_HUB   9
#define USB_CLS_MSD   8
#define USB_CLS_CDC_CTL  2
#define USB_CLS_CDC_DATA 0x0A
#define USB_CLS_VIDEO 0x0E

#define USB_RT_IN     0x80
#define USB_RT_STD    0x00
#define USB_RT_CLS    0x20
#define USB_RT_DEV    0
#define USB_RT_IF     1
#define USB_RT_EP     2

#define USB_EP_IN     0x80
#define USB_EP_CTRL   0
#define USB_EP_INT    3
#define USB_EP_BULK   2

class CUsbSetup
{
  U8 rt, req;
  U16 val, idx, len;
};

class CUsbDev
{
  U8 len, type;
  U16 bcd_usb;
  U8 cls, sub, proto, mps0;
  U16 vid, pid, bcd_dev;
  U8 i_mfr, i_prod, i_ser, cfgs;
};

class CUsbEp
{
  U8 len, type;
  union
  {
    U8 addr;
    U8 ep_num:4;
    U8 rsvd:3;
    U8 ep_in:1;
  }
  union
  {
    U8 attr;
    U8 xfer:2;
  }
  U16 mps;
  U8 interval;
};

class CUsbCfg
{
  U8 len, type;
  U16 total;
  U8 nif, cval, istr, attr, pwr;
};

class CUsbIf
{
  U8 len, type, num, alt, neps, cls, sub, proto, istr;
};

class CUsbCbw
{
  U32 sig, tag, dlen;
  U8 flags, lun, cbl;
  U8 cdb[16];
};

class CUsbCsw
{
  U32 sig, tag, resid;
  U8 status;
};

#define USB_HC_UHCI 1
#define USB_HC_EHCI 2
#define USB_HC_OHCI 3
#define USB_HC_XHCI 4
#define USB_HC_NUM  5

#define USB_SPD_FS 0
#define USB_SPD_LS 1
#define USB_SPD_HS 2
#define USB_SPD_SS 3

#define USB_NFN        16
#define USB_BUF_SETUP  0
#define USB_BUF_DATA   64
#define USB_DATA_MAX   4096
#define USB_BUF_INT    4608	//USB_NFN interrupt-IN slots of USB_INT_SZ
#define USB_INT_SZ     64
#define USB_CBW_SIG    0x43425355
#define USB_CSW_SIG    0x53425355
#define USB_MS_BLKS    8

class CUsbTab
{//HID absolute pointer and relative mouse field bit offsets, -1 if absent.
  I64 rid, btn, x, xs, xmax, y, ys, ymax;
  I64 mrid, mbtn, mnb, mx, mxs, my, mys, mw, mws;
};

class CUsbFn
{//An enumerated device and the interface we drive.
  I64 hc, hci, port, hub, hport, tt_adr, tt_port, speed, adr, mps0, kind, ifn, on;
  I64 ep, mps, tog;
  I64 bin, bout, bmps, btog_i, btog_o;
  I64 nports, chg;
  U8 *hq, *ht;
  U8 prev[8], hpen[16];
  CUsbTab tab;
  I64 vid, pid, cls, gen;
  U8 *hx;
  U8 *bht;
  I64 blen;
  I64 par;
  I64 alt;
  I64 dalt;
  I64 mstr;
  U8 *iso;
};

#define USB_ISO_NFR  32
#define USB_ISO_NU   64
#define USB_ISO_FIFO 128

class CUsbIso
{//An isochronous stream (UsbVenIsoStart).
  I64 ep, dirin, mps, mult, maxlen,
        per_fr, step,
        interval,
        nu, fr_bytes, nxt, next_slot, dci;
  Bool split;
  U8 *td, *buf;
  I64 slot[USB_ISO_NU], ulen[USB_ISO_NU];
  U32 tpa[USB_ISO_NU];
  I64 done[USB_ISO_NU], cc[USB_ISO_NU], res[USB_ISO_NU];
  U8 *fifo;
  I64 flen[USB_ISO_FIFO], fin, fout;
  I64 frames, pkts, errs, missed, resync, under;
};

I64 UsbIsoTake(CUsbIso *s, U8 *dst)
{//The next queued OUT packet into dst: its length, 0 if none (underrun).
  I64 n;
  if (s->fin == s->fout)
  {
    s->under++;
    return 0;
  }
  n = s->flen[s->fout & (USB_ISO_FIFO - 1)];
  MemCpy(dst, s->fifo + (s->fout & (USB_ISO_FIFO - 1)) * s->maxlen, n);
  s->fout++;
  return n;
}

class CUsbHcOps
{//What the shared layer needs from a host controller driver.
  I64 (*ctl)(CUsbFn *f, I64 len, I64 dirin);
  I64 (*bulk)(CUsbFn *f, I64 dirin, U8 *dp, I64 len);
  U0 (*int_init)(I64 k);
  U0 (*int_stop)(CUsbFn *f);
  U0 (*bulk_rst)(CUsbFn *f);
  Bool (*dev_new)(CUsbFn *t);
  U0 (*dev_off)(CUsbFn *f);
  Bool (*bin_arm)(CUsbFn *f, U8 *buf, I64 len);
  I64 (*bin_poll)(CUsbFn *f);
  U0 (*bin_stop)(CUsbFn *f);
  Bool (*iso_start)(CUsbFn *f, CUsbIso *s);
  I64 (*iso_poll)(CUsbFn *f, CUsbIso *s, U8 *dst, I64 *lens, I64 max);
  U0 (*iso_stop)(CUsbFn *f, CUsbIso *s);
};

CUsbHcOps usb_ops[USB_HC_NUM];
U8 *usb_buf = NULL, *usb_bd = NULL;
I64 usb_lock = 0, usb_n = 0;
CUsbFn *usb_fn = NULL, usb_efn;
I64 usb_efail = 0;

U0 UsbIntOn(I64 k)
{//Start the interrupt pipes of device k and of its other interfaces.
  I64 j;
  for (j = 0; j < usb_n; j++)
    if ((j == k || usb_fn[j].par == k + 1) && usb_fn[j].on && usb_fn[j].ep)
      (*usb_ops[usb_fn[j].hc].int_init)(j);
}

U0 DbgS6(U8 *s)
{
  while (*s)
    OutU8(0xE9, *s++);
}

U0 UsbWait(I64 ms)
{//Spin on the TSC during boot, Busy() is too short in a VM.
  I64 end;
  if (Fs != adam_task || Bt(&sys_run_level, RLf_ADAM_SERVER))
    Sleep(ms);
  else
  {
    end = GetTSC + cnts.time_stamp_freq * ms / 1000;
    while (GetTSC < end)
      PAUSE
  }
}

U32 UsbRd(U32 *r)
{//Dword MMIO read: EHCI/xHCI registers need dword access.
  return *r;
}

I64 UsbEnd(I64 ms)
{//Deadline for transfer waits.
  return GetTSC + cnts.time_stamp_freq * ms / 1000;
}

U32 UsbPa(U8 *p)
{
  return p(I64);
}

U0 UsbLock()
{//Yield, never spin: scheduling is cooperative.
  while (LBts(&usb_lock, 0))
    Yield;
}

U0 UsbUnlock()
{
  LBtr(&usb_lock, 0);
}

U0 UsbBufInit()
{
  if (usb_buf) return;
  usb_buf = CAllocAligned(8192, 4096, sys_dma_heap);
  usb_bd = CAllocAligned(16384, 16384, sys_dma_heap);
  usb_fn = CAlloc(USB_NFN * sizeof(CUsbFn));
}

extern I64 UsbEnum(CUsbFn *t);
extern U0 UsbIntRep(CUsbFn *f, U8 *rep);
extern U0 UsbFnOff(I64 k);
extern U0 UsbRep();
extern U0 UsbEvt(I64 k, Bool on);
extern Bool UsbFnFree(I64 k);
