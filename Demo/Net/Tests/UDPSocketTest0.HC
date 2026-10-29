U0 UDPSockTest()
{
  CUDPSock            *u0 = UDPSock(AF_INET);
  CUDPSock            *u1 = UDPSock(AF_INET);
  CSockAddrIPV4    *i0 = CAlloc(sizeof(CSockAddrIPV4));
  CSockAddrIPV4    *i1 = CAlloc(sizeof(CSockAddrIPV4));
  i0->port          = EndianU16(80);
  i0->family            = AF_INET;
  i0->addr.addr   = 0xDEADBEEF;
  i1->port          = EndianU16(68);
  i1->family            = AF_INET;
  i1->addr.addr = 0xF00DBABE;
  UDPSockBind(u0, i0);
  ClassRep(udp_globals.bound_sock_tree);
  UDPSockBind(u1, i1);
  "Before remove first socket\n";
  UDPRep;
  "\n";
  UDPSockClose(u0);
  "After remove first socket\n";
  UDPRep;
  "\n";
  UDPSockClose(u1);
  "After both sockets removed\n";
  UDPRep;
  "\n";
  Free(i0);
  Free(i1);
}

UDPSockTest;
