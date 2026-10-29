U8 src[6] = {0xDE, 0xAD, 0xBE, 0xEF, 0xC0, 0xDE};
U8 dst[6] = {0xF0, 0x0D, 0xBE, 0xAD, 0xDE, 0xAF};

U0 DHCPTest()
{
  CUDPSock *udp_sock = UDPSock(AF_INET);
  U32 your_ip;
  U32 dns_ip;
  U32 router_ip;
  U32 subnet_mask;
  U8 *pkt_buf;
  I64 de_index;
  if (ipv4_globals.local_ip != 0)
  {
    "\nThis test will only work on unconfigured network.\n";
    "To force for testing, comment out $$FG,0$$NetCfg;$$FG$$ in $$LK,\"Start.HC\",A=\"FF:::/Demo/Net/Start.HC,NetCfg\"$$.\n\n";
    return;
  }
  DHCPInnerCfg(udp_sock, &your_ip, &dns_ip, &router_ip, &subnet_mask);
  UDPSockClose(udp_sock);
  while (TRUE)
  {
    de_index = EthFrameAlloc(&pkt_buf, src, dst, 0x0000, 8);
    *(pkt_buf(U64 *)) = EndianU64(0xDEADBEEFC0DEFADE);
    EthFrameFinish(de_index);
    Sleep(300);
  }
}

DHCPTest;
