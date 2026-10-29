CTCPSock *tcp = TCPSock(AF_INET);
tcp->timeout = TCP_TIMEOUT;

ClassRep(tcp);

CSockAddrIPV4 *sock_addr = CAlloc(sizeof(CSockAddrIPV4));

CIPV4Addr addr;
PresToNet(AF_INET, "10.0.2.7", &addr);

sock_addr->port = EndianU16(0xBEEF);
sock_addr->family = AF_INET;
sock_addr->addr.addr = addr.addr;

"\nTrying to connect the socket\n";
if (TCPSockConnect(tcp, sock_addr) == 0)
  "\nSock connected.\n";


ClassRep(tcp_globals.bound_sock_tree);

Sleep(5000);

"\nTrying to close the socket\n";
TCPSockClose(tcp);

Sleep(500);

//NetStop;

//NetStart;
