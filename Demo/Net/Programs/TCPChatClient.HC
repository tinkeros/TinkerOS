CTask       *chat_display_task  = NULL;
CTask       *chat_message_task  = NULL;
CTCPSock  *tcp = TCPSock(AF_INET);

U0 ChatDisplayTask(I64)
{// display received messages.
  DocTermNew;
  DocCursor;
  DocPrint(, "$$WW,1$$");
  while (TaskValidate(chat_message_task))
  {
    Refresh;
  }
}

U0 ChatMsgTask(I64)
{// take in text.
  U8    *message;
  DocTermNew;
  DocPrint(, "$$WW,1$$");
  while (message = GetStr("> ",, GSF_SHIFT_ESC_EXIT))
  {
    DocBottom(chat_display_task->put_doc);
    DocPrint(chat_display_task->put_doc,
             "$$BG,BLUE$$$$BLACK$$<local>$$FG$$$$BG$$ %s\n", message);
    TCPSockSendStr(tcp, message);
    DocClear;
    DocPrint(, "$$WW,1$$");
  }
}

U0 ChatInit()
{
  chat_message_task = Spawn(&ChatMsgTask, NULL, "TCP Chat Msg");
  chat_display_task = Spawn(&ChatDisplayTask, NULL, "TCP Chat");
  chat_message_task->win_inhibit = WIG_USER_TASK_DFT;
  chat_display_task->win_inhibit = WIG_USER_TASK_DFT;
  LBts(&chat_message_task->display_flags, DISPLAYf_SHOW);
  LBts(&chat_display_task->display_flags, DISPLAYf_SHOW);
  WinFocus(chat_display_task);
  WinFocus(chat_message_task);
  chat_display_task->win_top        = 2;
  chat_display_task->win_bottom = TEXT_ROWS / 3;
  chat_display_task->win_left       = TEXT_COLS / 3;
  chat_display_task->win_right  = TEXT_COLS / 3 * 2;
  chat_message_task->win_top        = chat_display_task->win_bottom + 2;
  chat_message_task->win_bottom = chat_message_task->win_top + 3;
  chat_message_task->win_left       = chat_display_task->win_left;
  chat_message_task->win_right  = chat_display_task->win_right;
}

U0 Chat()
{
  CSockAddrIPV4     sock_addr;
  CIPV4Addr       ip_addr;
  U8                    *ip_str   = GetStr("Server IPV4: ");
  U8                    *port_str = GetStr("Server Port: ");
  I64                    port        = Str2I64(port_str);
  U8                    *buf[ETH_FRAME_SIZE];
  I64                    rx_val;
  while (PresToNet(AF_INET, ip_str, &ip_addr) == -1)
  {
    "\nERROR: Bad IP entered. Retry.\n";
    ip_str = GetStr("Server IPV4: ");
  }
  Free(ip_str);
  Free(port_str);
  sock_addr.port          = EndianU16(port);
  sock_addr.family            = AF_INET;
  sock_addr.addr.addr   = ip_addr.addr;
  tcp->timeout = TCP_TIMEOUT;
  "\nConnecting to server...\n";
  if (TCPSockConnect(tcp, &sock_addr) != 0)
  {
    "\nFailed to connect to server.\n";
    TCPSockClose(tcp);
    return;
  }
  else
    "\nSuccessfully connected.\n";
  ChatInit;
  tcp->timeout = 0;
  while (TaskValidate(chat_message_task))
  {
    if ((rx_val = TCPSockRx(tcp, buf, ETH_FRAME_SIZE)) != -1)
    {
      if (rx_val == 0)
      {
        "\nServer closed the connection.\n";
        Kill(chat_message_task);
        break;
      }
      else if (rx_val > 0)
      {
        DocBottom(chat_display_task->put_doc);
        DocPrint(chat_display_task->put_doc,
                 "%s\n", buf);
        MemSet(buf, 0, ETH_FRAME_SIZE);
      }
    }
    Refresh;
  }
  tcp->timeout = TCP_TIMEOUT;
  "\nClosing connected socket...\n";
  if (TCPSockClose(tcp) == 0)
    "\nSock closed.\n";
  else
    "\nSock failed to close.\n";
}

Chat;
