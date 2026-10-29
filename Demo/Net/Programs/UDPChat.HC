/*
    Chat program proof-of-concept using UDP.

    Tested on Bridged Mode with two VMs under the same router (same and different computers),
    and on NAT Network Mode with two VMs using the same virtualized NAT.

*/

U8              *dst_ip_str     = GetStr("Destination IPV4: "),
                 *port_str        = GetStr("RX & TX UDP Port: ");
CIPV4Addr    *dst_addr       = CAlloc(sizeof(CIPV4Addr));

I64              port               = Str2I64(port_str);
CTask           *chat_display_task  = NULL;
CTask           *chat_message_task  = NULL;

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
  I64  de_index;
  U8    *payload;
  DocTermNew;
  DocPrint(, "$$WW,1$$");
  while (message = GetStr("> ",, GSF_SHIFT_ESC_EXIT))
  {
    DocBottom(chat_display_task->put_doc);
    DocPrint(chat_display_task->put_doc, "$$BG,BLUE$$$$BLACK$$<local>$$FG$$$$BG$$ %s\n", message);
    de_index = UDPPktAlloc(&payload, ipv4_globals.local_ip, port, dst_addr->addr, port, StrLen(message));
    MemCpy(payload, message, StrLen(message));
    UDPPktFinish(de_index);
    DocClear;
    DocPrint(, "$$WW,1$$");
  }
}

U0 ChatInit()
{
  chat_message_task = Spawn(&ChatMsgTask, NULL, "UDP Chat Msg");
  chat_display_task = Spawn(&ChatDisplayTask, NULL, "UDP Chat");
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
  CUDPSock            *udp_sock = UDPSock(AF_INET);
  CSockAddrIPV4    *sock_addr = CAlloc(sizeof(CSockAddrIPV4));
  U8                    *buf[ETH_FRAME_SIZE];
  "\nIP entered: %s\n"
  , dst_ip_str;
  while (PresToNet(AF_INET, dst_ip_str, dst_addr) == -1)
  {
    "ERROR: Bad IP entered. Retry.\n";
    dst_ip_str = GetStr("Destination IPV4: ");
  }
  ChatInit;
  sock_addr->port               = EndianU16(port);
  sock_addr->family         = AF_INET;
  sock_addr->addr.addr    = dst_addr->addr;
  UDPSockBind(udp_sock, sock_addr);
  "\nIP entered: %s\n"
  , dst_ip_str;
  while (TaskValidate(chat_message_task))
  {
    if (UDPSockRxFrom(udp_sock, buf, ETH_FRAME_SIZE, NULL) != -1)
    {
      DocBottom(chat_display_task->put_doc);
      DocPrint(chat_display_task->put_doc, "$$BG,PURPLE$$$$BLACK$$<%s>$$FG$$$$BG$$  %s\n", dst_ip_str, buf);
      MemSet(buf, 0, ETH_FRAME_SIZE);
    }
    Refresh;
  }
  Free(sock_addr);
  UDPSockClose(udp_sock);
}

Chat;
