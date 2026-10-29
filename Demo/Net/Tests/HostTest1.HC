U8 dns_mac[6] = {0xF0, 0x0D, 0xBE, 0xAD, 0xDE, 0xAF};

U32 dns_ip = 0x51525354;


U0 HostTest()
{
  if (dns_globals.addr_family == AF_UNSPEC)
  {
    ARPCachePut(dns_ip, dns_mac);
    DNSResolverIPV4Set(dns_ip);
  }
  Host("zenithos.org");
}

HostTest;
