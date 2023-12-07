public U8 MOUSE_COM=0;
public I64 MOUSE_BAUD=1200;

public U0 ProbeSerialMouse()
{
  I64 baud=1200,i,tmp_byte;
  U8 tmp_buf[17];
  MemSet(tmp_buf,0,17);
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    if (comm_ports[i].base)
    {
      "Checking COMM %d - ",i;
      CommInit7n1(i, baud);
      Sleep(1);
      OutU8(comm_ports[i].base+UART_MCR,0x8);
      Sleep(1);
      OutU8(comm_ports[i].base+UART_MCR,0xA);
      Sleep(1);
      if (CommGetCharNoWait(i,tmp_byte))
      {
        if (*tmp_byte=='M')
        {
          Sleep(2);
          if (CommGetCharNoWait(i,tmp_byte) && tmp_byte=='3')
          {
            "Found Microsoft Serial Mouse on COMM %d using 7n1 baud %d\n",i,baud;
            MOUSE_COM=i;
            goto probe_end;
          }
          else {
            "Found Serial Mouse on COMM %d using 7n1 baud %d\n",i,baud;
            MOUSE_COM=i;
          }
        }
      }
      " No device detected!\n";
    }
  }
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    if (comm_ports[i].base)
    {
      "Checking COMM %d - ",i;
      for (baud=1200; baud<=115200; baud*=2)
      {
        CommInit8n1(i, baud);
        Sleep(1);
        OutU8(comm_ports[i].base+UART_MCR,0x8);
        Sleep(1);
        OutU8(comm_ports[i].base+UART_MCR,0xA);
        Sleep(1);
        if (CommGetCharNoWait(i,tmp_byte))
        {
          if (*tmp_byte=='M')
          {
            Sleep(2);
            if (CommGetCharNoWait(i,tmp_byte) && tmp_byte=='3')
            {
              "Found Microsoft Serial Mouse on COMM %d 8n1 baud %d\n",i,baud;
              MOUSE_COM=i;
              MOUSE_BAUD=baud;
              goto probe_end;
            }
            else {
              "Found Serial Mouse on COMM %d 8n1 baud %d\n",i,baud;
              MOUSE_COM=i;
              MOUSE_BAUD=baud;
            }
          }
        }
      }
      " No device detected!\n";
    }
  }
probe_end:
}


U0 Test7n1Mouse(I64 port=2, I64 msg_size=4)
{
  U8 tmp_byte, bytes[6];
  I64 idx=0;
  CommInit7n1(port, 1200);
  // flush
  while (CommGetCharNoWait(port,&tmp_byte))
  {
    //Nothing
  };
  // try mouse
  Sleep(1);
  OutU8(comm_ports[port].base+UART_MCR,0x8);
  Sleep(1);
  OutU8(comm_ports[port].base+UART_MCR,0xA);
  Sleep(2);
  while (TRUE)
  {
    Yield;
    if (CommGetCharNoWait(port,&bytes[idx++]))
      if (idx==msg_size)
      {
        "Got %d bytes!\n",msg_size;
        idx=0;
      }
  }
  "Done\n";
}
