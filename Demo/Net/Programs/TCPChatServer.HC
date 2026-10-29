CTCPSock      *tcp = TCPSock(AF_INET);
CTCPTreeQue *connections = CAlloc(sizeof(CTCPTreeQue));
U8              *buf = CAlloc(ETH_FRAME_SIZE);

QueInit(connections);

U0 ChatServerKill()
{
  CTCPTreeQue   *conn = connections->next;
  CTCPTreeQue   *next_conn;
  while (conn != connections)
  {
    "\nClosing socket @ 0x%0X\n", conn->sock;
    TCPSockClose(conn->sock);
    next_conn = conn->next;
    Free(conn);
    conn = next_conn;
  }
  "\nClosing listening socket.\n";
  TCPSockClose(tcp);
  return;
}

U0 ChatServerBroadcast(CTCPSock *tcp_sock, I64 len)
{// Broadcast length bytes of msg in buffer to all but original socket.
  CTCPTreeQue   *conn = connections->next;
  CTCPSock        *dst_sock;
  U8                *ip_str;
  CIPV4Addr   addr;
  U8                *message;
  U8                *message_prefix;
  while (conn != connections)
  {
    dst_sock = conn->sock;
    if (dst_sock != tcp_sock)
    {
      addr.addr = EndianU32(dst_sock->dst_addr(CSockAddrIPV4).addr.addr);
      ip_str = NetToPres(AF_INET, &addr);
      "\nBroacasting msg to %s.\n"
      , ip_str;
      addr.addr = EndianU32(tcp_sock->dst_addr(CSockAddrIPV4).addr.addr);
      ip_str = NetToPres(AF_INET, &addr);
      message_prefix = MStrPrint("$$BG,PURPLE$$$$BLACK$$<%s>$$FG$$$$BG$$ %%0%dts", ip_str, len);
      message = MStrPrint(message_prefix, buf);
      TCPSockSendStr(dst_sock, message);
      Free(message);
      Free(message_prefix);
      Free(ip_str);
    }
    conn = conn->next;
  }
  return;
}

U0 ChatServerBroadcastDisconnect()
{
  CTCPTreeQue   *conn = connections->next;
  CTCPSock        *conn_sock;
  U8                *message = MStrPrint("$$BG,LTGRAY$$$$DKGRAY$$Client disconnected. Connected clients: %d$$FG$$$$BG$$",
                                         QueCnt(connections));
  while (conn != connections)
  {
    conn_sock = conn->sock;
    TCPSockSendStr(conn_sock, message);
    conn = conn->next;
  }
  Free(message);
}

U0 ChatServerRx()
{
  CTCPTreeQue   *conn = connections->next;
  CTCPTreeQue   *next_conn;
  CTCPSock        *sock;
  I64                message_len;
  U8                *ip_str;
  CIPV4Addr   addr;
  while (conn != connections)
  {
    sock = conn->sock;
    message_len = TCPSockRx(sock, buf, ETH_FRAME_SIZE);
    if (message_len == 0)
    {
      "\nClosing a connection.\n";
      sock->timeout = TCP_TIMEOUT;
      TCPSockClose(sock);
      next_conn = conn->next;
      QueRem(conn);
      Free(conn);
      conn = next_conn;
      ChatServerBroadcastDisconnect();
    }
    else if (message_len > 0)
    {
      addr.addr = EndianU32(sock->dst_addr(CSockAddrIPV4).addr.addr);
      ip_str = NetToPres(AF_INET, &addr);
      "\nBroadcasting %d byte msg from %s: %Q\n"
      , message_len, ip_str, buf;
      ChatServerBroadcast(sock, message_len);
      MemSet(buf, 0, ETH_FRAME_SIZE);
      conn = conn->next;
    }
    else
    {
      conn = conn->next;
    }
  }
  return;
}

U0 ChatServer()
{
  CSockAddrIPV4     sock_addr;
  U8                    *port_str = GetStr("Server Port: ");
  I64                    port = Str2I64(port_str);
  CTCPSock            *new_sock;
  CTCPTreeQue       *new_conn;
  U8                    *join_msg;
  CTCPTreeQue       *conn;
  CTCPSock            *conn_sock;
  Free(port_str);
  sock_addr.port          = EndianU16(port);
  sock_addr.family            = AF_INET;
  sock_addr.addr.addr   = INADDR_ANY;
  tcp->timeout = 0.3 * JIFFY_FREQ;
  "\nTrying to bind socket.\n";
  if (TCPSockBind(tcp, &sock_addr) == 0)
    "\nSock bound.\n";
  else
  {
    "\nFailed to bind socket.\n";
    ChatServerKill;
    return;
  }
  "\nTrying to listen on socket.\n";
  if (TCPSockLsten(tcp, 5) == 0)
    "\nSock now listening.\n";
  else
  {
    "\nFailed to listen on socket.\n";
    ChatServerKill;
    return;
  }
  while (ScanChar != CH_SHIFT_ESC)
  {
    new_sock = TCPSockAccept(tcp);
    if (new_sock > 0)
    {
      "\nNew connection.\n";
      new_conn = CAlloc(sizeof(CTCPTreeQue));
      new_conn->sock = new_sock;
      new_sock->timeout = 0;
      join_msg = MStrPrint("$$BG,LTGRAY$$$$DKGRAY$$Connected clients: %d$$FG$$$$BG$$", QueCnt(connections) + 1);
      TCPSockSendStr(new_sock, join_msg);
      Free(join_msg);
      join_msg = MStrPrint("$$BG,LTGRAY$$$$DKGRAY$$New connection. Connected clients: %d$$FG$$$$BG$$",
                           QueCnt(connections) + 1);
      conn = connections->next;
      while (conn != connections)
      {
        "\nNotifying clients of new connection.\n";
        conn_sock = conn->sock;
        TCPSockSendStr(conn_sock, join_msg);
        conn = conn->next;
      }
      Free(join_msg);
      QueInsRev(new_conn, connections);
    }
    ChatServerRx;
    Sleep(50);
  }
  ChatServerKill;
}

ChatServer;
