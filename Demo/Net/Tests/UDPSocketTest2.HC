U0 UDPSockTest()
{
  CUDPSock            *u = UDPSock(AF_INET);
  CSockAddrIPV4    *i = CAlloc(sizeof(CSockAddrIPV4));
  i->port               = EndianU16(64222);
  i->family         = AF_INET;
  i->addr.addr    = INADDR_ANY;
  UDPSockBind(u, i);
  "UDP Socket bound at port %d.\n"
  , EndianU16(i->port);
  "Send UDP data to the VM, then run UDPRep to see received message data in report.\n";
  while (!ScanChar)
    Refresh;
  UDPSockClose(u);
  Free(i);
}

UDPSockTest;
