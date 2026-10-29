#define ICMP_TYPE_ECHO_REPLY    0
#define ICMP_TYPE_ECHO_REQ  8
#define ICMP_CODE_ECHO          0

class CICMPHdr
{
  U8    type;
  U8    code;
  U16 checksum;

  U16 id;
  U16 seq_num;
};


/*  global variable containing last reply ICMP header received,
    Ping() checks this to make ping report.
*/
CICMPHdr icmp_reply;


U0 ICMPInit()
{
  ZeroClass(&icmp_reply);
}

U16 ICMPChecksum(U8 *buf, I64 size)
{
  U64 i, sum = 0;
  for (i = 0; i < size; i += 2)
  {
    sum += *buf(U16 *);
    buf += 2;
  }
  if (size - i > 0)
    sum += *buf;
  while (sum >> 16 != 0)
    sum = sum & 0xFFFF + sum >> 16;
  return ~sum(U16);
}


U0 ICMPReplySend(U32 dst_ip_addr,
                 U16 id,
                 U16 seq_num,
                 U16 req_checksum,
                 U8 *payload,
                 I64 len)
{
  U8            *icmp_frame;
  I64            de_index;
  CICMPHdr   *hdr;
  de_index = IPV4PktAlloc(&icmp_frame,
                                IP_PROTOCOL_ICMP,
                                IPV4AddrGet,
                                dst_ip_addr,
                                sizeof(CICMPHdr) + len);
  if (de_index < 0)
  {
    NetErr("ICMP SEND REPLY: Failed to allocate IPV4 packet.");
    return;
  }
  hdr = icmp_frame;
  hdr->type              = ICMP_TYPE_ECHO_REPLY;
  hdr->code              = 0;
  hdr->checksum          = EndianU16(EndianU16(req_checksum) + 0x0800);
  hdr->id            = id;
  hdr->seq_num       = seq_num;
  MemCpy(icmp_frame + sizeof(CICMPHdr), payload, len);
  IPV4PktFinish(de_index);
}

U0 ICMPReqSend(U32 dst_ip_addr,
                   U16 id,
                   U16 seq_num,
                   U8 *payload,
                   I64 len)
{
  U8            *icmp_frame;
  I64            de_index;
  CICMPHdr   *hdr;
  de_index = IPV4PktAlloc(&icmp_frame,
                                IP_PROTOCOL_ICMP,
                                IPV4AddrGet,
                                dst_ip_addr,
                                sizeof(CICMPHdr) + len);
  if (de_index < 0)
  {
    NetErr("ICMP SEND REQUEST: Failed to allocate IPV4 packet.");
    return;
  }
  hdr = icmp_frame;
  hdr->type              = ICMP_TYPE_ECHO_REQ;
  hdr->code              = 0;
  hdr->checksum          = 0;
  hdr->id            = id;
  hdr->seq_num       = seq_num;
  MemCpy(icmp_frame + sizeof(CICMPHdr), payload, len);
  hdr->checksum = ICMPChecksum(hdr, sizeof(CICMPHdr) + len);
  IPV4PktFinish(de_index);
}

I64 ICMPHandler(CIPV4Pkt *pkt)
{
  CICMPHdr *hdr;
  if (pkt->len < sizeof(CICMPHdr))
  {
    NetErr("ICMP HANDLER: Caught wrong IPV4 length.");
    return -1;
  }
  hdr = pkt->data;
  if (hdr->type == ICMP_TYPE_ECHO_REQ && hdr->code == ICMP_CODE_ECHO)
  {
    ARPCachePut(pkt->src_ip_addr, pkt->eth_frame->src_addr);
    ICMPReplySend(pkt->src_ip_addr,
                  hdr->id,
                  hdr->seq_num,
                  hdr->checksum,
                  pkt->data   + sizeof(CICMPHdr),
                  pkt->len - sizeof(CICMPHdr));
  }
  else if (hdr->type == ICMP_TYPE_ECHO_REPLY && hdr->code == ICMP_CODE_ECHO)
  {
    ClassCpy(&icmp_reply, hdr);
  }
  else
    NetWarn("ICMP HANDLER: Unhandled ICMP packet. type, code: 0x%X, 0x%X", hdr->type, hdr->code);
  NetLog("ICMP HANDLER: Exiting.");
  return 0;
}

ICMPInit;
