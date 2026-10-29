#help_index "Comm"

U0 CommUsbInit(CComm *c, I64 baud, I64 lcr)
{
  I64 bits = 8;
  if (lcr == 2) bits = 7;
  if (!c->RX_fifo)
    c->RX_fifo = FifoU8New(COMM_RX_FIFO_SIZE);
  if (UsbCdcOpen(c->usb_k, c->usb_gen, baud, bits))
  {
    UsbCdcLines(c->usb_k, c->usb_gen, 1, 1);
    LBts(&c->flags, COMf_ENABLED);
  }
}

Bool CommUsbPut(CComm *c, U8 *buf, I64 cnt, I64 timeout_ms)
{
  return UsbCdcWrite(c->usb_k, c->usb_gen, buf, cnt, timeout_ms) == cnt;
}

U0 CommUsbRxPoll(CComm *c)
{
  U8 buf[128];
  I64 n, i;
  n = UsbCdcRead(c->usb_k, c->usb_gen, buf, 128);
  if (n < 0) return;
  for (i = 0; i < n; i++)
    FifoU8Ins(c->RX_fifo, buf[i]);
}

U0 CommUsbTxFlush(CComm *c)
{
  UsbCdcFlush(c->usb_k, c->usb_gen, 500);
}

U0 CommUsbLines(CComm *c, I64 dtr, I64 rts)
{
  UsbCdcLines(c->usb_k, c->usb_gen, dtr, rts);
}

comm_ops[COMT_USB].init = &CommUsbInit;
comm_ops[COMT_USB].put = &CommUsbPut;
comm_ops[COMT_USB].rx_poll = &CommUsbRxPoll;
comm_ops[COMT_USB].tx_flush = &CommUsbTxFlush;
comm_ops[COMT_USB].lines = &CommUsbLines;

I64 CommUsbPick()
{//First COM slot >= 5 this CDC attach can use.
  I64 i;
  for (i = 5; i <= MAX_COMM_NUM; i++)
    if (comm_ports[i].type == COMT_NONE)
      return i;
  return 0;
}

public I64 CommUsbAttach(I64 k)
{//Give CDC device k the first free COM port >= 5. Returns the port, 0 if none.
  I64 port = CommUsbPick();
  CComm *c;
  if (!port) return 0;
  c = &comm_ports[port];
  c->type = COMT_USB;
  c->usb_k = k;
  c->usb_gen = UsbCdcGen(k);
  c->base = 1;
  c->poll = 1;
  return port;
}

public I64 CommUsbDetach(I64 k)
{//Free the COM port of CDC device k. Returns the port, 0 if it had none.
  I64 i, port = 0;
  for (i = 5; i <= MAX_COMM_NUM; i++)
    if (comm_ports[i].type == COMT_USB && comm_ports[i].usb_k == k)
    {
      comm_ports[i].flags = 0;
      comm_ports[i].type = COMT_NONE;
      comm_ports[i].base = 0;
      comm_ports[i].usb_k = 0;
      comm_ports[i].usb_gen = 0;
      if (comm_ports[i].RX_fifo)
        FifoU8Flush(comm_ports[i].RX_fifo);
      port = i;
    }
  return port;
}
