#define ARP_HASHTABLE_SIZE  1024

#define HTT_ARP 0x00100

#define ARP_REQ 0x01
#define ARP_REPLY   0x02

class CARPHdr
{
  U16 hardware_type;
  U16 protocol_type;

  U8 hardware_addr_len;
  U8 protocol_addr_len;

  U16 operation;

  U8 sender_hardware_addr[MAC_ADDR_LEN];
  U32 sender_protocol_addr;

  U8 target_hardware_addr[MAC_ADDR_LEN];
  U32 target_protocol_addr;

};

class CARPHash:CHash
{//store U32 ip_address as CHash->str U8*, MStrPrint("%X")
// U32 ip_address;
  U8 mac_addr[MAC_ADDR_LEN];
};

class CARPGlbls
{
  U32 local_ipv4;

} arp_globals;

CHashTable *arp_cache = NULL;

I64 arp_cache_lock = 0;

U0 ARPCacheInit()
{
  arp_cache = HashTableNew(ARP_HASHTABLE_SIZE);
  arp_cache_lock = 0;
  arp_globals.local_ipv4 = 0;
}

I64 ARPSend(U16 operation,
    U8 *dst_mac_addr,
    U8 *send_mac_addr,
    U32 send_ip,
    U8 *target_mac_addr,
    U32 target_ip)
{//method currently assumes send_ and target_ip EndianU16 already...
  U8 *arp_frame;
  CARPHdr *hdr;
  I64 de_index = EthFrameAlloc(&arp_frame,send_mac_addr, dst_mac_addr,
          ETHERTYPE_ARP,
          sizeof(CARPHdr));
  if (de_index < 0)
    return de_index;
  hdr = arp_frame;
  hdr->hardware_type = EndianU16(HTYPE_ETH);
  hdr->protocol_type = EndianU16(ETHERTYPE_IPV4);
  hdr->hardware_addr_len = MAC_ADDR_LEN;
  hdr->protocol_addr_len = IP_ADDR_LEN;
  hdr->operation = EndianU16(operation);
  MemCpy(hdr->sender_hardware_addr, send_mac_addr, MAC_ADDR_LEN);
  hdr->sender_protocol_addr = send_ip;
  MemCpy(hdr->target_hardware_addr, target_mac_addr, MAC_ADDR_LEN);
  hdr->target_protocol_addr = target_ip;
  EthFrameFinish(de_index);
  return 0;
}

CARPHash *ARPCacheFind(U32 ip_addr)
{
  U8 *ip_str = MStrPrint("%X", ip_addr);
  CARPHash *ent;
  PUSHFD
  CLI
  while (LBts(&arp_cache_lock, 0))
    PAUSE
  ent = HashFind(ip_str, arp_cache, HTT_ARP);
  LBtr(&arp_cache_lock, 0);
  POPFD
  if (ent == NULL)
  {
    NetLog("ARP CACHE FIND BY IP: Could not find an IP in ARP cache.");
  }
  Free(ip_str);
  return ent;
}

CARPHash *ARPCachePut(U32 ip_addr, U8 *mac_addr)
{
  CARPHash *ent, *fresh;
  U8 *ip_str = MStrPrint("%X", ip_addr);
  fresh = CAlloc(sizeof(CARPHash), adam_task);
  fresh->str = StrNew(ip_str, adam_task);
  fresh->type = HTT_ARP;
  MemCpy(fresh->mac_addr, mac_addr, MAC_ADDR_LEN);
  PUSHFD
  CLI
  while (LBts(&arp_cache_lock, 0))
    PAUSE
  ent = HashFind(ip_str, arp_cache, HTT_ARP);
  if (ent)
    MemCpy(ent->mac_addr, mac_addr, MAC_ADDR_LEN);
  else
  {
    HashAdd(fresh, arp_cache);
    ent = fresh;
    fresh = NULL;
  }
  LBtr(&arp_cache_lock, 0);
  POPFD
  if (fresh)
  {
    Free(fresh->str);
    Free(fresh);
  }
  Free(ip_str);
  NetLog("ARP CACHE PUT: 0x%0X is %02X:%02X:%02X:%02X:%02X:%02X", ip_addr,
      mac_addr[0], mac_addr[1], mac_addr[2],
      mac_addr[3], mac_addr[4], mac_addr[5]);
  return ent;
}

U0 ARPLocalIPV4Set(U32 ip_addr)
{// takes in little endian IP, stores into globals as Big Endian
  arp_globals.local_ipv4 = EndianU32(ip_addr);
  ARPCachePut(ip_addr, EthMACGet);
  ARPSend(ARP_REPLY,
      eth_globals.eth_broadcast,
      EthMACGet,
      arp_globals.local_ipv4,
      eth_globals.eth_broadcast,
      arp_globals.local_ipv4);
}

I64 ARPHandler(CEthFrame *eth_frame)
{// Use of ARPHandler must accnt for -1 error codes.
  CARPHdr *hdr;
  U16 operation;
  U32 sender_ip;
  if (eth_frame->ethertype != ETHERTYPE_ARP)
  {
    NetErr("ARP HANDLER: Caught wrong frame ethertype.");
    return -1;
  }
  if (eth_frame->len < sizeof(CARPHdr))
  {
    NetErr("ARP HANDLER: Caught wrong frame length.");
    return -1;
  }
  hdr = eth_frame->data;
  if (EndianU16(hdr->hardware_type) != HTYPE_ETH)
  {
    NetErr("ARP HANDLER: Caught wrong frame hardware type.");
    return -1;
  }
  if (EndianU16(hdr->protocol_type) != ETHERTYPE_IPV4)
  {
    NetErr("ARP HANDLER: Caught wrong frame protocol type.");
    return -1;
  }
  if (hdr->hardware_addr_len != HLEN_ETH)
  {
    NetErr("ARP HANDLER: Caught wrong frame hardware address length.");
    return -1;
  }
  if (hdr->protocol_addr_len != PLEN_IPV4)
  {
    NetErr("ARP HANDLER: Caught wrong frame protocol address length.");
    return -1;
  }
  operation = EndianU16(hdr->operation);
  sender_ip = EndianU32(hdr->sender_protocol_addr);
  if (operation == ARP_REQ && hdr->target_protocol_addr != arp_globals.local_ipv4)
  {
    if (sender_ip && ARPCacheFind(sender_ip))
      ARPCachePut(sender_ip, hdr->sender_hardware_addr);
    return 0;
  }
  NetLog("ARP HANDLER: Entering ARP Handler.");
  switch (operation)
  {
  case ARP_REQ:
    if (sender_ip)
      ARPCachePut(sender_ip, hdr->sender_hardware_addr);
    if (hdr->target_protocol_addr == arp_globals.local_ipv4)
    {
      NetLog("ARP HANDLER: Saw request, sending back reply.");
      ARPSend(ARP_REPLY,
          hdr->sender_hardware_addr,
          EthMACGet,
          arp_globals.local_ipv4,
          hdr->sender_hardware_addr,
          hdr->sender_protocol_addr);
    }
    else
      NetWarn("ARP HANDLER: Saw request, target IP address is not this machine.");
    break;
  case ARP_REPLY:
    NetLog("ARP HANDLER: Saw reply, putting into ARP Cache.");
    ARPCachePut(EndianU32(hdr->sender_protocol_addr), hdr->sender_hardware_addr);
    break;
  default:
    NetErr("ARP HANDLER: Unrecognized operation: 0x%X", operation);
    break;
  }
  NetLog("ARP HANDLER: Exiting.");
  return 0;
}

U0 ARPRep()
{
  I64 i, j;
  CARPHash *temp_hash;
  U32 addr;
  "$$LTBLUE$$ARP Report:$$FG$$\n\n";
  "ARP Local Address: $FG,6$%d.%d.%d.%d$FG$\n\n"
  ,
  arp_globals.local_ipv4.u8[0],
  arp_globals.local_ipv4.u8[1],
  arp_globals.local_ipv4.u8[2],
  arp_globals.local_ipv4.u8[3];
  for (i = 0; i <= arp_cache->mask; i++)
  {
    temp_hash = arp_cache->body[i];
    while (temp_hash)
    {
      "ARP Hash @ $FG,3$0x%X$FG$:\n", temp_hash;
      addr = EndianU32(Str2I64(temp_hash->str, 16)(U32));
      " IP Address:     $FG,6$%d.%d.%d.%d$FG$\n"
      ,
      addr.u8[0], addr.u8[1], addr.u8[2], addr.u8[3];
      " MAC Address:    $FG,6$";
      $FG$
      for (j = 0; j < MAC_ADDR_LEN; j++)
        "%02X ", temp_hash->mac_addr[j];
      "$FG$\n\n";
      temp_hash = temp_hash->next;
    }
  }
  "\n";
}

ARPCacheInit;
