CTCPSock  *tcp            = TCPSock(AF_INET);
U8          *buf         = "Hello world";
U8           buf_size    = StrLen(buf);

CSockAddrIPV4 *sock_addr = CAlloc(sizeof(CSockAddrIPV4));

//*buffer = EndianU64(0xDEADBEEFC0DEFADE);

U0 TCPTest()
{
  tcp->timeout = TCP_TIMEOUT * 3;
  CIPV4Addr addr;
  PresToNet(AF_INET, "10.0.2.7", &addr);
  sock_addr->port          = EndianU16(0xBEEF);
  sock_addr->family            = AF_INET;
  sock_addr->addr.addr = addr.addr;
  ClassRep(tcp);
  "\nTrying to connect the socket\n";
  if (TCPSockConnect(tcp, sock_addr) == 0)
    "\nSock connected.\n";
  else
    "\nFailed to connect.\n";
  ClassRep(tcp);
  "\n\nTrying to Send data\n";
  if (TCPSockSend(tcp, buf, buf_size) > 0)
    "\nData sent\n";
  else
    "\nData not sent\n";
  "\n\nTrying to Receive data\n";
  if (TCPSockRx(tcp, buf, buf_size) > 0)
    "\nData received\n";
  else
    "\nData not received\n";
  "\n\n";
  DumpMem(buf, buf_size);
  ClassRep(tcp_globals.bound_sock_tree);
  Sleep(5000);
  "\n\nTrying to close the connected socket\n";
  if (TCPSockClose(tcp) == 0)
    "\nSock closed.";
  else
    "\nSock close failed.";
  Sleep(500);
}


TCPTest;
