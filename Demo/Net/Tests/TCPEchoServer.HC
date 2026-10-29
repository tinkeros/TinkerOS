CTCPSock  *tcp            = TCPSock(AF_INET);
CTCPSock  *new;
U8           buf_size    = TCP_MSS;
U8          *buf         = CAlloc(buf_size);

CSockAddrIPV4 *sock_addr = CAlloc(sizeof(CSockAddrIPV4));

U0 TCPTest()
{
  tcp->timeout = TCP_TIMEOUT * 3;
  ClassRep(tcp);
  sock_addr->port          = EndianU16(0xBEEF);
  sock_addr->family            = AF_INET;
  sock_addr->addr.addr = INADDR_ANY;
  "\nTrying to bind socket.\n";
  if (TCPSockBind(tcp, sock_addr) == 0)
    "\nSock bound.\n";
  else
    "\nFailed to bind socket.\n";
  "\nTrying to listen on socket.\n";
  if (TCPSockLsten(tcp, 5) == 0)
    "\nSock now listening.\n";
  else
    "\nFail to listen on socket.\n";
  "\nTrying to accept a connection\n";
  if ((new = TCPSockAccept(tcp)) != NULL)
    "\nNew socket connected.\n";
  else
  {
    "\nFailed to accept.\n";
    return;
  }
  "\n\nTrying to Receive data\n";
  if (TCPSockRx(new, buf, buf_size) > 0)
    "\nData received\n";
  else
    "\nData not received\n";
  "\n\n";
  Dump(buf, buf_size, FALSE);
  "\n\n";
  "\nTrying to Send data\n";
  if (TCPSockSend(new, buf, buf_size) > 0)
    "\nData sent.\n";
  else
    "\nData not sent\n";
  ClassRep(tcp_globals.bound_sock_tree);
  Sleep(5000);
  "\n\nTrying to close the accepted socket\n";
  if (TCPSockClose(new) == 0)
    "\nSock Closed.";
  else
    "\nSock close failed."
    "\n\nTrying to close the listening socket\n";
  if (TCPSockClose(tcp) == 0)
    "\nSock Closed.";
  else
    "\nSock close failed.";
  Sleep(500);
}

TCPTest;
