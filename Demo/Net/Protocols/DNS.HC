// https://www2.cs.duke.edu/courses/fall16/compsci356/DNS/DNS-primer.pdf
// https://en.wikipedia.org/wiki/Domain_Name_Adam

// DNS Cache is a HashTable, similar to ARP Cache

#define DNS_HASHTABLE_SIZE  2048
#define HTT_DNS             0x00100

#define DNS_FLAG_RD     0x0100

#define DNS_OP_QUERY    0

#define DNS_TYPE_A      1

#define DNS_CLASS_IN    1

#define DNS_TIMEOUT     5000

#define DNS_MAX_RETRIES 5

class CDNSHash:CHash
{// store U8 *hostname as CHash->str U8 *
  CAddrInfo info;
};

class CDNSDomainName
{
  U8 **labels;
  I64  num_labels;
};

class CDNSQuestion
{
  CDNSQuestion  *next;
  CDNSDomainName     q_name;
  U16                q_type;
  U16                q_class;
};

class CDNSHdr
{
  U16 id;
  U16 flags;
  U16 q_cnt;
  U16 a_cnt;
  U16 ns_cnt;
  U16 ar_cnt;
};

class CDNSRR
{// RR: Resource Record
  CDNSRR            *next;
  CDNSDomainName     name;
  U16                type;
  U16                rr_class;
  U32                ttl;
  U16                rd_len;
  U8                *r_data;
};

class CDNSGlbls
{
  U16                   addr_family;
  CIPAddrStorage dns_ip;

} dns_globals;

CHashTable *dns_cache = NULL;

I64 dns_cache_lock = 0;

U0 DNSCacheLock()
{
  while (LBts(&dns_cache_lock, 0))
    Yield;
}

U0 DNSCacheUnlock()
{
  LBtr(&dns_cache_lock, 0);
}

U0 DNSCacheInit()
{
  dns_cache = HashTableNew(DNS_HASHTABLE_SIZE);
  dns_cache_lock = 0;
  ZeroClass(&dns_globals.dns_ip);
  dns_globals.addr_family = 0;
}

CDNSHash *DNSCacheFind(U8 *hostname)
{//Caller must not hold dns_cache_lock: it is not re-entrant.
  CDNSHash *ent;
  DNSCacheLock;
  ent = HashFind(hostname, dns_cache, HTT_DNS);
  DNSCacheUnlock;
  if (ent == NULL)
    NetWarn("DNS CACHE FIND: Could not find a hostname in the DNS Cache.");
  return ent;
}

CDNSHash *DNSCachePut(U8 *hostname, CAddrInfo *info)
{
  CDNSHash *ent;
  NetLog("DNS CACHE PUT: Attempting Find DNS Entry in Cache: hostname: %s", hostname);
  DNSCacheLock;
  ent = HashFind(hostname, dns_cache, HTT_DNS);
  if (!ent)
  {
    ent = CAlloc(sizeof(CDNSHash), adam_task);
    ent->str  = StrNew(hostname, adam_task);
    ent->type = HTT_DNS;
    AddrInfoCpy(&ent->info, info, adam_task);
    HashAdd(ent, dns_cache);
  }
  else
  {
    Free(ent->info.addr);
    Free(ent->info.canonical_name);
    AddrInfoCpy(&ent->info, info, adam_task);
  }
  DNSCacheUnlock;
  return ent;
}

I64 DNSQuestionSizeCalculate(CDNSQuestion *q)
{// ??
  I64 i, size = 0;
  for (i = 0; i < q->q_name.num_labels; i++)
  {
    size += 1 + StrLen(q->q_name.labels[i]);
  }
  return size + 1 + 4;
}

U0 DNSQuestionSerialize(U8 *buf, CDNSQuestion *q)
{// ??
  I64 i;
  U8 *label;
  for (i = 0; i < q->q_name.num_labels; i++)
  {
    label = q->q_name.labels[i];
    *buf++ = StrLen(label);
    while (*label)
      *buf++ = *label++;
  }
  *buf++ = 0;
  *buf++ = q->q_type >> 8;
  *buf++ = q->q_type & 0xFF;
  *buf++ = q->q_class >> 8;
  *buf++ = q->q_class & 0xFF;
}

I64 DNSQuestionSend(U16 id, U16 local_port, CDNSQuestion *q)
{
  CIPV4Addr *ipv4_addr;
  U8             *dns_frame;
  U16             flags;
  CDNSHdr     *hdr;
  I64             de_index;
  switch (dns_globals.addr_family)
  {
  case AF_UNSPEC:
    NetErr("DNS SEND QUESTION: Failed, global dns addr family was AF_UNSPEC.");
    return -1;
  case AF_INET6:
    NetErr("DNS SEND QUESTION: Failed, IPV6 not supported yet in DNS.");
    throw('DNS');
  case AF_INET:
    ipv4_addr = &dns_globals.dns_ip;
    if (!*ipv4_addr)
    {
      NetErr("DNS SEND QUESTION: Failed, ipv4_addr had no value set.");
      return -1;
    }
  }
  de_index = UDPPktAlloc(&dns_frame, IPV4AddrGet, local_port, *ipv4_addr,53,sizeof(CDNSHdr) + DNSQuestionSizeCalculate(q));
  if (de_index < 0)
  {
    NetErr("DNS SEND QUESTION: Failed, UDPPacketAllocate returned error.");
    return de_index;
  }
  flags = DNS_OP_QUERY << 11 | DNS_FLAG_RD;
  hdr = dns_frame;
  hdr->id            = EndianU16(id);
  hdr->flags     = EndianU16(flags);
  hdr->q_cnt     = EndianU16(1);
  hdr->a_cnt     = 0;
  hdr->ns_cnt    = 0;
  hdr->ar_cnt    = 0;
  DNSQuestionSerialize(dns_frame + sizeof(CDNSHdr), q);
  UDPPktFinish(de_index);
  return 0;
}


I64 DNSDomainNamePrs(U8 *pkt_data, I64 pkt_len, U8 **data_inout, I64 *len_inout, CDNSDomainName *name_out)
{// these methods look not-so-good, ngl.
  U8  *data = *data_inout;
  U8  *name_buf;
  I64  len = *len_inout;
  I64  label_len;
  Bool jump_taken = FALSE;
  if (len < 1)
  {
    NetErr("DNS PARSE DOMAIN NAME: Length less than one.");
    return -1;
  }
  name_out->labels      = CAlloc(16 * sizeof(U8 *));
  name_out->num_labels  = 0;
  name_buf = CAlloc(256);
  name_out->labels[0] = name_buf;
  while (len)
  {
    label_len = *data++;
    len--;
    if (label_len == 0)
      break;
    else if (label_len >= 192)
    {
      label_len &= 0x3F;
      if (!jump_taken)
      {
        *data_inout     = data   + 1;
        *len_inout   = len - 1;
        jump_taken      = TRUE;
        NetLog("DNS PARSE DOMAIN NAME: Jump taken");
      }
      data  = pkt_data + (label_len << 8 | *data);
      len    = pkt_data + pkt_len - data;
    }
    else
    {
      if (len < label_len)
        return -1;
      MemCpy(name_buf, data, label_len);
      data  += label_len;
      len    -= label_len;
      name_buf[label_len] = 0;
      name_out->labels[name_out->num_labels++] = name_buf;
      name_buf += label_len + 1;
    }
  }
  if (!jump_taken)
  {
    *data_inout     = data;
    *len_inout   = len;
  }
  return 0;
}


I64 DNSQuestionPrs(U8 *pkt_data, I64 pkt_len, U8 **data_inout, I64 *len_inout, CDNSQuestion *q_out)
{
  U8 *data;
  I64 len;
  I64 error = DNSDomainNamePrs(pkt_data, pkt_len, data_inout, len_inout, &q_out->q_name);
  if (error < 0)
    return error;
  data  = *data_inout;
  len    = *len_inout;
  if (len < 4)
    return -1;
  q_out->next       = NULL;
  q_out->q_type = data[1] << 8 | data[0];
  q_out->q_class    = data[3] << 8 | data[2];
  *data_inout       = data   + 4;
  *len_inout = len - 4;
  return 0;
}

I64 DNSRRPrs(U8 *pkt_data, I64 pkt_len, U8 **data_inout, I64 *len_inout, CDNSRR *rr_out)
{
  U8 *data;
  I64 len;
  I64 record_len;
  I64 error = DNSDomainNamePrs(pkt_data, pkt_len, data_inout, len_inout, &rr_out->name);
  if (error < 0)
    return error;
  data  = *data_inout;
  len    = *len_inout;
  if (len < 10)
    return -1;
  rr_out->next = NULL;
  MemCpy(&rr_out->type, data, 10);
  record_len = 10 + EndianU16(rr_out->rd_len);
  if (len < record_len)
    return -1;
  rr_out->r_data = data + 10;
  *data_inout       = data   + record_len;
  *len_inout = len - record_len;
  return 0;
}

I64 DNSResponsePrs(U16 id, U8 *data, I64 len, CDNSHdr **hdr_out, CDNSQuestion **questions_out, CDNSRR **answers_out)
{
  CDNSHdr        *hdr;
  CDNSQuestion  *question;
  CDNSRR            *answer;
  I64                i;
  U8                *pkt_data    = data;
  I64                pkt_len  = len;
  if (len < sizeof(CDNSHdr))
  {
    NetErr("DNS PARSE RESPONSE: Length too short.");
    return -1;
  }
  hdr = data;
  data += sizeof(CDNSHdr);
  if (id != 0 && EndianU16(hdr->id) != id)
  {
    NetErr("DNS PARSE RESPONSE: Header ID mismatch.");
    return -1;
  }
  for (i = 0; i < EndianU16(hdr->q_cnt); i++)
  {
    question = CAlloc(sizeof(CDNSQuestion));
    if (DNSQuestionPrs(pkt_data, pkt_len, &data, &len, question) < 0)
      return -1;
    question->next = *questions_out;
    *questions_out = question;
  }
  for (i = 0; i < EndianU16(hdr->a_cnt); i++)
  {
    answer = CAlloc(sizeof(CDNSRR));
    if (DNSRRPrs(pkt_data, pkt_len, &data, &len, answer) < 0)
      return -1;
    answer->next = *answers_out;
    *answers_out = answer;
  }
  *hdr_out = hdr;
  return 0;
}

U0 DNSQuestionBuild(CDNSQuestion *q, U8 *name)
{
  U8 *copy = StrNew(name);
  U8 *dot;
  q->next                   = NULL;
  q->q_name.labels      = CAlloc(16 * sizeof(U8 *));
  q->q_name.labels[0]       = 0;
  q->q_name.num_labels  = 0;
  q->q_type             = DNS_TYPE_A;
  q->q_class                = DNS_CLASS_IN;
  while (*copy)
  {
    q->q_name.labels[q->q_name.num_labels++] = copy;
    dot = StrFirstOcc(copy, ".");
    if (dot)
    {
      *dot = 0;
      copy = dot + 1;
    }
    else
      break;
  }
}

// these Free methods bother me a bit...
U0 DNSQuestionFree(CDNSQuestion *q)
{
  Free(q->q_name.labels[0]);
}

U0 DNSRRFree(CDNSRR *rr)
{
  Free(rr->name.labels[0]);
}

U0 DNSQuestionChainFree(CDNSQuestion *questions)
{
  CDNSQuestion *next;
  while (questions)
  {
    next = questions->next;
    DNSQuestionFree(questions);
    Free(questions);
    questions = next;
  }
}

U0 DNSRRChainFree(CDNSRR *rrs)
{// Shrine sets rrs->next to a CDNSQuestion when it would be a CDNSRR ... assuming it's wrong and fixing it here..
  CDNSRR *next;
  while (rrs)
  {
    next = rrs->next;
    DNSRRFree(rrs);
    Free(rrs);
    rrs = next;
  }
}


I64 DNSQueryRun(CUDPSock *udp_sock, U8 *name, U16 port, CAddrInfo **result_out)
{// IPV4-UDP-based, TODO: take good look at this method to ensure no floating pointers after.
  // note: UDP Socket created in this method is not closed in this method, gets closed e.g. in DNSAddressInfoGet
  I64  retries  = 0;
  I64    timeout    = DNS_TIMEOUT;
  U16    local_port = MaxI64(1024, RandU16);
  U16  id           = RandU16;
  I64  error        = 0;
  U8   buf[2048];
  I64  cnt;
  Bool have;
  CDNSQuestion   q;
  CDNSHdr        *hdr;
  CDNSQuestion  *questions;
  CDNSRR            *answers;
  CDNSRR            *a;
  CSockAddrIPV4     ipv4_addr;
  CSockAddrIPV4     ipv4_addr_in;
  CSockAddrIPV4    *ipv4_addr_temp;
  CAddrInfo      *res;
  udp_sock->rx_timeout_ms = timeout;
  ipv4_addr.family          = AF_INET;
  ipv4_addr.port                = EndianU16(local_port);
  ipv4_addr.addr.addr = INADDR_ANY;
  if (UDPSockBind(udp_sock, &ipv4_addr))
  {
    NetErr("DNS RUN QUERY: Failed to bind UDP socket.");
    return -1;
  }
  DNSQuestionBuild(&q, name);
  while (TRUE)
  {
    error = DNSQuestionSend(id, local_port, &q);
    if (error < 0)
    {
      NetErr("DNS RUN QUERY: Failed to Send Question.");
      return -1;
    }
    cnt = UDPSockRxFrom(udp_sock, buf, sizeof(buf), &ipv4_addr_in);
    if (cnt > 0)
    {
      NetLog("DNS RUN QUERY: Trying Prs Response.");
      hdr        = NULL;
      questions = NULL;
      answers       = NULL;
      error = DNSResponsePrs(id, buf, cnt, &hdr, &questions, &answers);
      if (error == 0)
      {
        have = FALSE;
        a = answers;
        while (a)
        {
          if (EndianU16(a->type)        == DNS_TYPE_A   &&
              EndianU16(a->rr_class)    == DNS_CLASS_IN &&
              EndianU16(a->rd_len)   == 4)
          {
            res = CAlloc(sizeof(CAddrInfo));
            res->flags          = 0;
            res->family         = AF_INET;
            res->sock_type    = 0;
            res->protocol       = 0;
            res->addr_len = sizeof(CSockAddrIPV4);
            res->addr        = CAlloc(sizeof(CSockAddrIPV4));
            res->canonical_name = 0;
            res->next           = NULL;
            ipv4_addr_temp = res->addr;
            ipv4_addr_temp->family  = AF_INET;
            ipv4_addr_temp->port    = port;
            MemCpy(&ipv4_addr_temp->addr.addr, a->r_data, 4);
            DNSCachePut(name, res);
            *result_out = res;
            have = TRUE;
            break;
          }
          a = a->next;
        }
        DNSQuestionChainFree(questions);
        DNSRRChainFree(answers);
        if (have)
          break;
        NetErr("DNS RUN QUERY: Failed to find suitable answer in reply.");
        error = -1;
      }
      else
      {
        NetErr("DNS RUN QUERY: Failed a DNS Prs Response.");
      }
    }
    if (++retries == DNS_MAX_RETRIES)
    {
      NetErr("DNS RUN QUERY: Failed, max retries reached.");
      error = -1;
      break;
    }
  }
  DNSQuestionFree(&q);
  return error;
}

// Shrine has port arg as U8 *service with a no_warn and says it should be parsed as port, allowing that here
// Also has CAddressInfo *hints with a no_warn, omitting that for now
Bool DNSPrsDottedQuad(U8 *s, U8 *out4)
{//"a.b.c.d" to 4 bytes in network order. FALSE unless purely numeric.
  I64 i, v, digits;
  for (i = 0; i < 4; i++)
  {
    v = 0;
    digits = 0;
    while ('0' <= *s <= '9')
    {
      v = v * 10 + *s++ - '0';
      digits++;
    }
    if (!digits || v > 255)
      return FALSE;
    out4[i] = v;
    if (i < 3 && *s++ != '.')
      return FALSE;
  }
  return !*s;
}

I64 DNSAddrInfoGet(U8 *node_name, U16 port, CAddrInfo **result)
{
  I64            error;
  CUDPSock    *udp_sock;
  CDNSHash  *cached_ent;
  CAddrInfo *res;
  CSockAddrIPV4 *addr;
  U8 quad[4];
  if (DNSPrsDottedQuad(node_name, quad))
  {
    res = CAlloc(sizeof(CAddrInfo));
    res->family = AF_INET;
    res->addr_len = sizeof(CSockAddrIPV4);
    res->addr = addr = CAlloc(sizeof(CSockAddrIPV4));
    addr->family = AF_INET;
    addr->port = port;
    MemCpy(&addr->addr.addr, quad, 4);
    *result = res;
    return 0;
  }
  DNSCacheLock;
  if (cached_ent = HashFind(node_name, dns_cache, HTT_DNS))
  {
    *result = CAlloc(sizeof(CAddrInfo));
    AddrInfoCpy(*result, &cached_ent->info);
  }
  DNSCacheUnlock;
  if (cached_ent)
    return 0;
  udp_sock = UDPSock(AF_INET);
  error = 0;
  if (udp_sock)
  {
    error = DNSQueryRun(udp_sock, node_name, port, result);
    UDPSockClose(udp_sock);
  }
  else
  {
    NetErr("DNS GET ADDRESS INFO: Failed to make UDP Socket.");
    error = -1;
  }
  return error;
}

U0 DNSResolverIPV4Set(U32 ip)
{
  CIPV4Addr *addr = &dns_globals.dns_ip;
  dns_globals.addr_family   = AF_INET;
  addr->addr      = ip;
}

U0 Host(U8 *hostname)
{// getaddrinfo() for whole adam in Shrine ends up as pointer to DNSAddressInfoGet.. should we do something similar?
  CAddrInfo      *current;
  CAddrInfo      *result = NULL;
  I64                    error  = DNSAddrInfoGet(hostname, NULL, &result);
  I64                    i = 0;
  CSockAddrIPV4    *ipv4_addr;
  if (error < 0)
  {
    NetErr("HOST(): Failed at DNS Get Address Info.");
  }
  else
  {
    "Results:\n\n";
    current = result;
    while (current)
    {
      "Result $FG,4$%d$FG$:\n", ++i;
      " flags:          $FG,6$0x%04X$FG$ \n"
      , current->flags;
      " family:         $FG,6$%d$FG$    \n"
      , current->family;
      " socket type:    $FG,6$%d$FG$    \n"
      , current->sock_type;
      " protocol:       $FG,6$%d$FG$    \n"
      , current->protocol;
      " address length: $FG,6$%d$FG$    \n"
      , current->addr_len;
      switch (current->family)
      {
      case AF_INET:
        ipv4_addr = current->addr;
        "   address:        $FG,6$%s$FG$    \n"
        , NetToPres(AF_INET, &ipv4_addr->addr);
        break;
      case AF_INET6:
        "   address:        $FG,6$IPV6$FG$    \n";
        break;
      case AF_UNSPEC:
        "   address:        $FG,6$AF_UNSPEC$FG$    \n"
        ;
        break;
      default:
        "   address:        $FG,6$INVALID$FG$    \n"
        ;
        break;
      }
      current = current->next;
    }
    "\n";
  }
  AddrInfoFree(result);
}

U0 DNSRep()
{
  I64                    i;
  CDNSHash          *temp_hash;
  CSockAddrIPV4    *ipv4_addr;
  "$$LTBLUE$$DNS Report:$$FG$$\n\n";
  for (i = 0; i <= dns_cache->mask; i++)
  {
    temp_hash = dns_cache->body[i];
    while (temp_hash)
    {
      "DNS Hash @ $FG,3$0x%X$FG$:\n", temp_hash;
      " Hostname:       $FG,6$%s$FG$\n"
      , temp_hash->str;
      switch (temp_hash->info.family)
      {
      case AF_INET:
        ipv4_addr = temp_hash->info.addr;
        "   IP Address:     $FG,6$%s$FG$\n"
        ,
        NetToPres(temp_hash->info.family,
                              &ipv4_addr->addr);
        break;
      case AF_INET6:
        "   IP Address:     $FG,6$IPV6$FG$\n";
        break;
      case AF_UNSPEC:
        "   IP Address:     $FG,6$AF_UNSPEC$FG$"
        ;
        break;
      default:
        "   IP Address:     $FG,6$INVALID$FG$"
        ;
        break;
      }
      "\n";
      temp_hash = temp_hash->next;
    }
  }
}

DNSCacheInit;
