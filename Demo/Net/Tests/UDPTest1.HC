U0 UDPTest()
{
  CAddrInfo  *result = NULL;
  I64                error;
  U8                *b;
  if (ipv4_globals.local_ip == 0)
  {
    NetCfg;
  }
  error = DNSAddrInfoGet("zenithos.org", NULL, &result);
  if (error < 0)
  {
    NetErr("failed at DNS Get Address Info.");
  }
  else
  {
    CUDPSock          *u = UDPSock(AF_INET);
    CSockAddrIPV4  *ipv4_addr = result->addr;
    ipv4_addr->port = EndianU16(80);
    b = CAlloc(4);
    b[0] = 0xDE;
    b[1] = 0xAD;
    b[2] = 0xBE;
    b[3] = 0xEF;
    while (TRUE)
    {
      UDPSockSendTo(u, b, 4, ipv4_addr);
      Sleep(300);
    }
  }
}

UDPTest;
