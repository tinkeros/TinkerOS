//www.networksorcery.com/enp/protocol/dhcp.htm

#define DHCP_OPCODE_BOOTREQUEST     0x01

#define DHCP_OPTION_SUBNET_MASK     1
#define DHCP_OPTION_ROUTER          3
#define DHCP_OPTION_DNS             6
#define DHCP_OPTION_DOMAIN_NAME     15

#define DHCP_OPTION_REQUESTED_IP    50
#define DHCP_OPTION_MESSAGETYPE     53
#define DHCP_OPTION_SERVER_ID       54
#define DHCP_OPTION_PARAMLIST       55

#define DHCP_MESSAGETYPE_DISCOVER   0x01
#define DHCP_MESSAGETYPE_OFFER      0x02
#define DHCP_MESSAGETYPE_REQ    0x03
#define DHCP_MESSAGETYPE_ACK        0x05

#define DHCP_COOKIE 0x63825363

#define DHCP_STATE_CLIENT_START         0
#define DHCP_STATE_CLIENT_DISCOVER      1
#define DHCP_STATE_CLIENT_REQ       2
#define DHCP_STATE_CLIENT_REQ_ACCEPTED  3

#define DHCP_TIMEOUT        3000
#define DHCP_MAX_RETRIES    5

class CDHCPHdr
{
  U8    opcode;
  U8    hw_type;
  U8    hw_addr_len;
  U8    hops;
  U32 xid;
  U16   seconds;
  U16 flags;
  U32 client_ip;
  U32 your_ip;
  U32 server_ip;
  U32 gateway_ip;
  U8    client_hw_addr[16];
  U8    server_name[64];
  U8    boot_file[128];
};

class CDHCPDiscoverOptions
{
  U32 cookie;
  U8    message_type;
  U8    message_len;
  U8    message;
  U8    param_req_lst_type;
  U8    param_req_lst_len;
  U8    param_req_lst[4];
  U8    end;
};

class CDHCPReqOptions
{
  U32 cookie;
  U8    message_type;
  U8    message_len;
  U8    message;
  U8    requested_ip_type;
  U8    requested_ip_len;
  U32 requested_ip;
  U8    server_id_type;
  U8    server_id_len;
  U32   server_id;
  U8    end;
};

U32 DHCPTransactionBegin()
{
  return RandU32;
}

I64 DHCPDiscoverSend(U32 xid)
{
  U8                        *dhcp_frame;
  I64                        de_index;
  CDHCPHdr               *dhcp;
  CDHCPDiscoverOptions  *opts;
  de_index = UDPPktAlloc(&dhcp_frame,
                               0x00000000,
                               68,
                               0xFFFFFFFF,
                               67,
                               sizeof(CDHCPHdr) + sizeof(CDHCPDiscoverOptions));
  if (de_index < 0)
  {
    NetErr("DHCP SEND DISCOVER: Failed, UDP Packet Allocate error.");
    return de_index;
  }
  dhcp = dhcp_frame;
  ZeroClass(dhcp);
  dhcp->opcode      = DHCP_OPCODE_BOOTREQUEST;
  dhcp->hw_type     = HTYPE_ETH;
  dhcp->hw_addr_len = HLEN_ETH;
  dhcp->hops            = 0;
  dhcp->xid         = EndianU32(xid);
  dhcp->seconds     = 0;
  dhcp->flags           = EndianU16(0x8000);
  dhcp->client_ip       = 0;
  dhcp->your_ip     = 0;
  dhcp->server_ip       = 0;
  dhcp->gateway_ip  = 0;
  MemCpy(dhcp->client_hw_addr, EthMACGet, MAC_ADDR_LEN);
  opts = dhcp_frame + sizeof(CDHCPHdr);
  opts->cookie              = EndianU32(DHCP_COOKIE);
  opts->message_type            = DHCP_OPTION_MESSAGETYPE;
  opts->message_len      = 1;
  opts->message             = DHCP_MESSAGETYPE_DISCOVER;
  opts->param_req_lst_type  = DHCP_OPTION_PARAMLIST;
  opts->param_req_lst_len    = 4;
  opts->param_req_lst[0]        = DHCP_OPTION_SUBNET_MASK;
  opts->param_req_lst[1]        = DHCP_OPTION_ROUTER;
  opts->param_req_lst[2]        = DHCP_OPTION_DNS;
  opts->param_req_lst[3]        = DHCP_OPTION_DOMAIN_NAME;
  opts->end                 = 0xFF;
  UDPPktFinish(de_index);
  return de_index;
}

I64 DHCPReqSend(U32 xid, U32 requested_ip, U32 server_ip)
{
  U8                    *dhcp_frame;
  I64                    de_index;
  CDHCPHdr           *dhcp;
  CDHCPReqOptions   *opts;
  de_index = UDPPktAlloc(&dhcp_frame,
                               0x00000000,
                               68,
                               0xFFFFFFFF,
                               67,
                               sizeof(CDHCPHdr) + sizeof(CDHCPReqOptions));
  if (de_index < 0)
  {
    NetErr("DHCP SEND REQUEST: Failed, UDP Packet Allocate error.");
  }
  dhcp = dhcp_frame;
  ZeroClass(dhcp);
  dhcp->opcode      = DHCP_OPCODE_BOOTREQUEST;
  dhcp->hw_type     = HTYPE_ETH;
  dhcp->hw_addr_len = HLEN_ETH;
  dhcp->hops            = 0;
  dhcp->xid         = EndianU32(xid);
  dhcp->seconds     = 0;
  dhcp->flags           = EndianU16(0x0000);
  dhcp->client_ip       = 0;
  dhcp->your_ip     = 0;
  dhcp->server_ip       = EndianU32(server_ip);
  dhcp->gateway_ip  = 0;
  MemCpy(dhcp->client_hw_addr, EthMACGet, MAC_ADDR_LEN);
  opts = dhcp_frame + sizeof(CDHCPHdr);
  opts->cookie              = EndianU32(DHCP_COOKIE);
  opts->message_type            = DHCP_OPTION_MESSAGETYPE;
  opts->message_len      = 1;
  opts->message             = DHCP_MESSAGETYPE_REQ;
  opts->requested_ip_type       = DHCP_OPTION_REQUESTED_IP;
  opts->requested_ip_len = 4;
  opts->requested_ip            = EndianU32(requested_ip);
  opts->server_id_type      = DHCP_OPTION_SERVER_ID;
  opts->server_id_len        = 4;
  opts->server_id               = EndianU32(server_ip);
  opts->end                 = 0xFF;
  UDPPktFinish(de_index);
  return 0;
}

I64 DHCPBeginPrs(U8 **data_inout, I64 *len_inout, CDHCPHdr **hdr_out)
{
  U8    *data   = *data_inout;
  I64  len   = *len_inout;
  U32 *cookie;
  if (len < sizeof(CDHCPHdr) + 4)
  {
    NetErr("DHCP PARSE BEGIN: Failed, length too short.");
    return -1;
  }
  cookie = data + sizeof(CDHCPHdr);
  if (EndianU32(*cookie) != DHCP_COOKIE)
  {
    NetErr("DHCP PARSE BEGIN: Failed, cookie doesn't match DHCP-cookie.");
    return -1;
  }
  *hdr_out       = data;
  *data_inout       = data   + sizeof(CDHCPHdr) + 4;
  *len_inout = len - (sizeof(CDHCPHdr) + 4);
  return 0;
}

I64 DHCPOptionPrs(U8 **data_inout, I64 *len_inout, U8 *type_out, U8 *value_len_out, U8 **value_out)
{
  U8 *data  = *data_inout;
  I64 len    = *len_inout;
  while (len > 0 && !data[0])
  {
    data++;
    len--;
  }
  if (len < 1 || data[0] == 0xFF)
  {
    NetLog("DHCP PARSE OPTION: Saw END, returning 0.");
    return 0;
  }
  if (len < 2 || len < 2 + data[1])
  {
    NetErr("DHCP PARSE OPTION: Failed, length too short.");
    return -1;
  }
  *type_out         = data[0];
  *value_len_out = data[1];
  *value_out            = data + 2;
  *data_inout       = data   + 2 + *value_len_out;
  *len_inout = len - (2 + *value_len_out);
  return data[0];
}

I64 DHCPOfferPrs(U32 xid, U8 *data, I64 len,
                 U32 *your_ip_out,
                 U32 *dns_ip_out,
                 U32 *router_ip_out,
                 U32 *subnet_mask_out)
{
  CDHCPHdr *hdr;
  I64            error       = DHCPBeginPrs(&data, &len, &hdr);
  Bool       have_type   = FALSE;
  Bool       have_dns    = FALSE;
  Bool       have_router = FALSE;
  Bool       have_subnet = FALSE;
  U8             type;
  U8             value_len;
  U8            *value;
  U32            addr;
  if (error < 0)
    return error;
  if (EndianU32(hdr->xid) != xid)
  {
    NetErr("DHCP PARSE OFFER: Failed, parsed and parameter Transaction IDs do not match.");
    return -1;
  }
  while (len)
  {
    error = DHCPOptionPrs(&data, &len, &type, &value_len, &value);
    if (error < 0)
    {
      NetErr("DHCP PARSE OFFER: Failed at DHCP Prs Option.");
      return error;
    }
    if (error == 0)
    {
      break;
    }
    addr = EndianU32(*value(U32 *));
    switch (type)
    {
    case DHCP_OPTION_MESSAGETYPE:
      NetLog("DHCP PARSE OFFER: Prsd Option, Type MESSAGETYPE.");
      if (value_len == 1 && value[0] == DHCP_MESSAGETYPE_OFFER)
        have_type = TRUE;
      break;
    case DHCP_OPTION_DNS:
      NetLog("DHCP PARSE OFFER: Prsd Option, Type DNS.");
      if (value_len == 4)
      {
        *dns_ip_out = addr;
        have_dns    = TRUE;
      }
      break;
    case DHCP_OPTION_ROUTER:
      NetLog("DHCP PARSE OFFER: Prsd Option, Type ROUTER.");
      if (value_len == 4)
      {
        *router_ip_out  = addr;
        have_router     = TRUE;
      }
      break;
    case DHCP_OPTION_SUBNET_MASK:
      NetLog("DHCP PARSE OFFER: Prsd Option, Type SUBNET MASK.");
      if (value_len == 4)
      {
        *subnet_mask_out = addr;
        have_subnet      = TRUE;
      }
      break;
    }
  }
  if (have_type && have_dns && have_subnet && have_router)
  {
    *your_ip_out = EndianU32(hdr->your_ip);
    NetLog("DHCP PARSE OFFER: Success, got your-ip from DHCP Header.");
    return 0;
  }
  else
  {
    NetErr("DHCP PARSE OFFER: Failed, did not have needed Options.");
    NetErr("                  have_type: %Z", have_type, "ST_FALSE_TRUE");
    NetErr("                  have_dns: %Z", have_dns, "ST_FALSE_TRUE");
    NetErr("                  have_router: %Z", have_router, "ST_FALSE_TRUE");
    NetErr("                  have_subnet: %Z", have_subnet, "ST_FALSE_TRUE");
    return -1;
  }
}

I64 DHCPAckPrs(U32 xid, U8 *data, I64 len)
{
  CDHCPHdr *hdr;
  I64            error = DHCPBeginPrs(&data, &len, &hdr);
  U8             type;
  U8             value_len;
  U8            *value;
  if (error < 0)
    return error;
  if (EndianU32(hdr->xid) != xid)
  {
    NetErr("DHCP PARSE ACK: Failed, parsed and parameter Transaction IDs do not match.");
    return -1;
  }
  while (len)
  {
    error = DHCPOptionPrs(&data, &len, &type, &value_len, &value);
    if (error < 0)
    {
      NetErr("DHCP PARSE ACK: Failed at DHCP Prs Option.");
      return error;
    }
    if (error == 0)
    {
      break;
    }
    switch (type)
    {
    case DHCP_OPTION_MESSAGETYPE:
      if (value_len == 1 && value[0] == DHCP_MESSAGETYPE_ACK)
        return 0;
      break;
    }
  }
  NetErr("DHCP PARSE ACK: Failed.");
  return -1;
}

I64 DHCPInnerCfg(CUDPSock *udp_sock,
                 U32 *your_ip_out,
                 U32 *dns_ip_out,
                 U32 *router_ip_out,
                 U32 *subnet_mask_out)
{
  I64   state   = DHCP_STATE_CLIENT_START;
  I64   retries = 0;
  I64   timeout = DHCP_TIMEOUT;
  I64 error = 0;
  U32 xid;
  U32 dhcp_addr;
  U8    buf[2048];
  I64 cnt;
  CSockAddrIPV4    ipv4_addr;
  CSockAddrIPV4    ipv4_addr_in;
  udp_sock->rx_timeout_ms = timeout;
  ipv4_addr.family          = AF_INET;
  ipv4_addr.port                = EndianU16(68);
  ipv4_addr.addr.addr = INADDR_ANY;
  if (UDPSockBind(udp_sock, &ipv4_addr) < 0)
  {
    NetErr("DHCP CONFIGURE INNER: Failed to Bind UDP Socket.");
    return -1;
  }
  xid = DHCPTransactionBegin;
  while (state != DHCP_STATE_CLIENT_REQ_ACCEPTED)
  {
    switch (state)
    {
    case DHCP_STATE_CLIENT_START:
      state = DHCP_STATE_CLIENT_DISCOVER;
      retries = 0;
      break;
    case DHCP_STATE_CLIENT_DISCOVER:
      NetLog("DHCP CONFIGURE INNER: Trying Discover.");
      error = DHCPDiscoverSend(xid);
      if (error < 0)
      {
        NetErr("DHCP CONFIGURE INNER: Failed, DHCP Send Discover error.");
        return error;
      }
      cnt = UDPSockRxFrom(udp_sock, buf, sizeof(buf), &ipv4_addr_in);
      if (cnt > 0)
      {
        NetLog("DHCP CONFIGURE INNER: Trying Prs Offer.");
        error = DHCPOfferPrs(xid, buf, cnt, your_ip_out, dns_ip_out, router_ip_out, subnet_mask_out);
        if (error < 0)
          NetWarn("DHCP CONFIGURE INNER: Unsuccessful DHCP Prs Offer.");
      }
      if (cnt > 0 && error >= 0)
      {
        dhcp_addr   = EndianU32(ipv4_addr_in.addr.addr);
        state       = DHCP_STATE_CLIENT_REQ;
        retries     = 0;
      }
      else if (++retries == DHCP_MAX_RETRIES)
      {
        NetErr("DHCP CONFIGURE INNER: Failed, hit max retries in DHCP DISCOVER state.");
        return -1;
      }
      break;
    case DHCP_STATE_CLIENT_REQ:
      NetLog("DHCP CONFIGURE INNER: Trying Send Request.");
      error = DHCPReqSend(xid, *your_ip_out, dhcp_addr);
      if (error < 0)
      {
        NetErr("DHCP CONFIGURE INNER: Failed, unsuccessful DHCP Send Request.");
        return error;
      }
      cnt = UDPSockRxFrom(udp_sock, buf, sizeof(buf), &ipv4_addr_in);
      if (cnt > 0)
      {
        error = DHCPAckPrs(xid, buf, cnt);
        if (error < 0)
          NetWarn("DHCP CONFIGURE INNER: Unsuccessful DHCP Prs Ack.");
      }
      if (cnt > 0 && error >= 0)
      {
        dhcp_addr   = EndianU32(ipv4_addr_in.addr.addr);
        state       = DHCP_STATE_CLIENT_REQ_ACCEPTED;
      }
      else if (++retries == DHCP_MAX_RETRIES)
      {
        NetErr("DHCP CONFIGURE INNER: Failed, hit max retries in DHCP REQUEST state.");
        return -1;
      }
      break;
    }
  }
  return state;
}

I64 DHCPCfg()
{
  CUDPSock        *udp_sock = UDPSock(AF_INET);
  CIPV4Addr   addr;
  U32                your_ip;
  U32                dns_ip;
  U32                router_ip;
  U32                subnet_mask;
  I64                state = DHCPInnerCfg(udp_sock, &your_ip, &dns_ip, &router_ip, &subnet_mask);
  UDPSockClose(udp_sock);
  if (state == DHCP_STATE_CLIENT_REQ_ACCEPTED)
  {
    addr.addr = EndianU32(your_ip);
    NetLog("$$BG,2$$$$FG,15$$DHCP CONFIGURE: Obtained IPV4 Address! : %s $$BG$$$$FG$$", NetToPres(AF_INET, &addr));
    IPV4AddrSet(your_ip);
    IPV4SubnetSet(router_ip, subnet_mask);
    DNSResolverIPV4Set(dns_ip);
    return 0;
  }
  else
  {
    NetErr("$$BG,4$$DHCP CONFIGURE: Failed, incorrect state.$$BG$$");
    return -1;
  }
}


U0 NetCfg()
{
  I64 error;
  NetLog("\n==== Config Network. ====\n");
  error = DHCPCfg;
  if (error < 0)
    NetErr("==== Network Config Failed ====");
  else
    NetLog("$$BG,2$$$$FG,15$$==== Network Config Success ====$$FG$$$$BG$$");
}

U0 NetRep()
{
  "\n$$LTGREEN$$Network Report:$$FG$$\n\n";
  UDPRep;
  TCPRep;
  DNSRep;
  ARPRep;
  IPV4Rep;
}
