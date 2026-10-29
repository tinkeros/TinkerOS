#define IPV4_ERR_ADDR_INVALID       -200001
#define IPV4_ERR_HOST_UNREACHABLE   -200002

#define IPV4_TTL    64

//Look up IP Protocol Numbers online to see many more.
#define IP_PROTOCOL_ICMP    0x01
#define IP_PROTOCOL_TCP     0x06
#define IP_PROTOCOL_UDP     0x11

class CIPV4Pkt
{
  CEthFrame    *eth_frame;

  U32                src_ip_addr;
  U32                dst_ip_addr;

  U8                 protocol;
  U8                 padding[7];

  U8                *data;
  I64                len;
};

class CIPV4Hdr
{// note: U4's in some U8s.
  union
  {
    U8 ver_ihl;
    U8 ihl:4;
    U8 ver:4;
  }
  U8    dscp_ecn;

  U16 total_len;
  U16 id;
  U16 flags_frag_offset;
  // flag: bit 0: reserved must be 0. bit 1: don't fragment. bit 2: more fragments

  U8    time_to_live;
  U8    protocol;

  U16 hdr_checksum;

  U32 src_ip_addr;
  U32 dst_ip_addr;
};

class CIPV4Glbls
{// _be indicates Big Endian
  U32 local_ip;
  U32 local_ip_be;

  U32 ipv4_router_addr;
  U32 ipv4_subnet_mask;

} ipv4_globals;

U0 IPV4GlblsInit()
{
  ipv4_globals.local_ip          = 0;
  ipv4_globals.local_ip_be       = 0;
  ipv4_globals.ipv4_router_addr = 0;
  ipv4_globals.ipv4_subnet_mask  = 0;
};

// For now, trusting Shrine's implement
// of checksum. Shrine links back to
// http://stackoverflow.com/q/26774761/2524350

U16 IPV4Checksum(U8 *hdr, I64 len)
{//todo. make names clearer, and better comments.
  I64  nleft = len;
  U16 *w = hdr;
  I64  sum = 0;
  while (nleft > 1)
  {
    sum += *w++;
    nleft -= 2;
  }
  if (nleft == 1)
  {
    sum += *w & 0x00FF;
  }
  sum = sum >> 16 + sum & 0xFFFF;
  sum += sum >> 16;
  return ~sum & 0xFFFF;
}

I64 IPV4AddrMACGet(U32 ip_addr, U8 **mac_out)
{
  CARPHash  *ent;
  I64            retries;
  I64            attempt;
  if (ip_addr == 0)
  {
    NetErr("GET MAC FOR IP: Failed. Address = 0");
    return IPV4_ERR_ADDR_INVALID;
  }
  if (ip_addr == 0xFFFFFFFF)
  {
    NetLog("GET MAC FOR IP: Returning ethernet broadcast");
    *mac_out = eth_globals.eth_broadcast;
    return 0;
  }
  if (ip_addr & ipv4_globals.ipv4_subnet_mask != ipv4_globals.local_ip & ipv4_globals.ipv4_subnet_mask)
  {
    if (!ipv4_globals.ipv4_router_addr)
    {
      NetErr("GET MAC FOR IP: %0X is off-subnet and no default gateway is set.", ip_addr);
      return IPV4_ERR_HOST_UNREACHABLE;
    }
    if (ipv4_globals.ipv4_router_addr & ipv4_globals.ipv4_subnet_mask !=
          ipv4_globals.local_ip & ipv4_globals.ipv4_subnet_mask)
    {
      NetErr("GET MAC FOR IP: gateway %0X is itself off-subnet.", ipv4_globals.ipv4_router_addr);
      return IPV4_ERR_HOST_UNREACHABLE;
    }
    ip_addr = ipv4_globals.ipv4_router_addr;
  }
  {
    NetLog("GET MAC FOR IP: Attempting ARP Find by IP for address: %0X.", ip_addr);
    ent = ARPCacheFind(ip_addr);
    if (ent)
    {
      *mac_out = ent->mac_addr;
      return 0;
    }
    retries = 4;
    while (retries)
    {
      ARPSend(ARP_REQ,
              eth_globals.eth_broadcast,
              EthMACGet,
              ipv4_globals.local_ip_be,
              eth_globals.eth_null,
              EndianU32(ip_addr));
      attempt = 0;
      for (attempt = 0; attempt < 50; attempt++)
      {
        Sleep(10);
        ent = ARPCacheFind(ip_addr);
        if (ent)
          break;
      }
      if (ent)
      {
        *mac_out = ent->mac_addr;
        return 0;
      }
      retries--;
    }
    NetErr("GET MAC FOR IP: Failed to resolve address %d", ip_addr);
    return IPV4_ERR_HOST_UNREACHABLE;
  }
}

I64 IPV4PktAlloc(U8 **frame_out,
                       U8 protocol,
                       U32 src_ip_addr,
                       U32 dst_ip_addr,
                       I64 len)
{
  U8            *ipv4_frame;
  U8            *dst_mac_addr;
  I64            error;
  I64            de_index;
  I64            internet_hdr_len;
  CIPV4Hdr *hdr;
  error = IPV4AddrMACGet(dst_ip_addr, &dst_mac_addr);
  if (error < 0)
  {
    NetLog("IPV4 PACKET ALLOCATE: Failed to get MAC for destination.");
    return error;
  }
  de_index = EthFrameAlloc(&ipv4_frame,
                                   EthMACGet,
                                   dst_mac_addr,
                                   ETHERTYPE_IPV4,
                                   sizeof(CIPV4Hdr) + len);
  if (de_index < 0)
  {
    NetLog("IPV4 PACKET ALLOCATE: Ethernet Frame Allocate failed.");
    return de_index;
  }
  internet_hdr_len = sizeof(CIPV4Hdr) / 4;
  hdr = ipv4_frame;
  ZeroClass(hdr);
  hdr->ihl                       = internet_hdr_len;
  hdr->ver                   = 4;
  hdr->dscp_ecn              = 0;
  hdr->total_len          = EndianU16(internet_hdr_len * 4 + len);
  hdr->id            = 0;
  hdr->flags_frag_offset = 0;
  hdr->time_to_live          = IPV4_TTL;
  hdr->protocol              = protocol;
  hdr->hdr_checksum           = 0;
  hdr->src_ip_addr     = EndianU32(src_ip_addr);
  hdr->dst_ip_addr    = EndianU32(dst_ip_addr);
  hdr->hdr_checksum           = IPV4Checksum(hdr, internet_hdr_len * 4);
  *frame_out = ipv4_frame + sizeof(CIPV4Hdr);
  return de_index;
}

U0 IPV4PktFinish(I64 de_index)
{
  EthFrameFinish(de_index);
}

U32 IPV4AddrGet()
{
  return ipv4_globals.local_ip;
}

U0 IPV4AddrSet(U32 ip_addr)
{
  ipv4_globals.local_ip  = ip_addr;
  ipv4_globals.local_ip_be = EndianU32(ip_addr);
  ARPLocalIPV4Set(ip_addr);
}

U0 IPV4SubnetSet(U32 router_addr, U32 subnet_mask)
{
  ipv4_globals.ipv4_router_addr = router_addr;
  ipv4_globals.ipv4_subnet_mask  = subnet_mask;
}

I64 IPV4PktPrs(CIPV4Pkt *pkt_out, CEthFrame *eth_frame)
{//...if ethertype not ipv4 error?
  CIPV4Hdr *hdr = eth_frame->data;
  I64            hdr_len, total_len;
  if (eth_frame->len < sizeof(CIPV4Hdr))
    return -1;
  hdr_len = hdr->ihl * 4;
  total_len = EndianU16(hdr->total_len);
  if (hdr_len < sizeof(CIPV4Hdr) || total_len < hdr_len ||
        total_len > eth_frame->len)
    return -1;
  pkt_out->eth_frame            = eth_frame;
  pkt_out->src_ip_addr     = EndianU32(hdr->src_ip_addr);
  pkt_out->dst_ip_addr    = EndianU32(hdr->dst_ip_addr);
  pkt_out->protocol              = hdr->protocol;
  pkt_out->data                  = eth_frame->data + hdr_len;
  pkt_out->len                    = total_len - hdr_len;
  return 0;
}

U0 IPV4Rep()
{
  "$$LTBLUE$$IPV4 Report:$$FG$$\n\n";
  "Local IPV4:$FG,6$ %d.%d.%d.%d$FG$\n"
  ,
  ipv4_globals.local_ip.u8[3],
  ipv4_globals.local_ip.u8[2],
  ipv4_globals.local_ip.u8[1],
  ipv4_globals.local_ip.u8[0];
  "Router IPV4:$FG,6$ %d.%d.%d.%d$FG$\n"
  ,
  ipv4_globals.ipv4_router_addr.u8[3],
  ipv4_globals.ipv4_router_addr.u8[2],
  ipv4_globals.ipv4_router_addr.u8[1],
  ipv4_globals.ipv4_router_addr.u8[0];
  "Subnet IPV4:$FG,6$ %d.%d.%d.%d$FG$\n"
  ,
  ipv4_globals.ipv4_subnet_mask.u8[3],
  ipv4_globals.ipv4_subnet_mask.u8[2],
  ipv4_globals.ipv4_subnet_mask.u8[1],
  ipv4_globals.ipv4_subnet_mask.u8[0];
  "\n";
}

// IPV4 hndlr moved to NetHandlerTask file.
IPV4GlblsInit;
