U0 IPV4Handler(CEthFrame *eth_frame)
{
  CIPV4Pkt pkt;
  if (IPV4PktPrs(&pkt, eth_frame) < 0)
    return;
  ARPCachePut(pkt.src_ip_addr, eth_frame->src_addr);

  if (net_log_log) {
    switch (pkt.protocol)
      {
      case IP_PROTOCOL_ICMP:
        NetLog("IPV4 HANDLER: ICMP.");
        break;
      case IP_PROTOCOL_TCP:
        NetLog("IPV4 HANDLER: TCP.");
        break;
      case IP_PROTOCOL_UDP:
        NetLog("IPV4 HANDLER: UDP.");
        break;
      default:
        NetLog("IPV4 HANDLER: Unrecognized protocol: 0x%X", pkt.protocol);
        break;
    }
  }

  switch (pkt.protocol)
    {
    case IP_PROTOCOL_ICMP:
      ICMPHandler(&pkt);
      break;
    case IP_PROTOCOL_TCP:
      TCPHandler(&pkt);
      break;
    case IP_PROTOCOL_UDP:
      UDPHandler(&pkt);
      break;
    default:
      break;
  }

  if (net_log_log)
    NetLog("IPV4 HANDLER: Exiting.");
}

U0 NetQueEntHandle(CNetQueEnt *ent)
{
  CEthFrame eth_frame;
  if (EthFramePrs(&eth_frame, ent->frame, ent->pkt_len) < 0)
    return;
  if (MemCmp(EthMACGet, eth_frame.dst_addr, MAC_ADDR_LEN) &&
        MemCmp(eth_globals.eth_broadcast, eth_frame.dst_addr,
        MAC_ADDR_LEN))
    return;

  if (net_log_log)
    {
    switch (eth_frame.ethertype)
      {
      case ETHERTYPE_ARP:
        NetLog("HANDLE NETQUEUE ENTRY: ARP.");
        break;
      case ETHERTYPE_IPV4:
        NetLog("HANDLE NETQUEUE ENTRY: IPV4.");
        break;
      case ETHERTYPE_IPV6:
        NetLog("HANDLE NETQUEUE ENTRY: IPV6. FIXME");
        break;
      default:
        NetLog("HANDLE NETQUEUE ENTRY: Unrecognized ethertype: 0x%X", eth_frame.ethertype);
        break;
    }
  }

  switch (eth_frame.ethertype)
    {
    case ETHERTYPE_ARP:
      ARPHandler(&eth_frame);
      break;
    case ETHERTYPE_IPV4:
      IPV4Handler(&eth_frame);
      break;
    case ETHERTYPE_IPV6:
      break;
    default:
      break;
  }

  if (net_log_log)
    NetLog("HANDLE NETQUEUE ENTRY: Exiting.");
}

U0 NetHandler()
{
  CNetQueEnt *ent;
  while (1)
    {
    if (ent=NetQuePull)
      {
      if (net_log_log)
        {
        NetLog("$$BG,DKGRAY$$$$FG,BLACK$$"
	      "=== NET HANDLER ==="
	      "$$BG$$$$FG$$");
        NetLog("$$BD,LTGRAY$$$$FD,WHITE$$"
	      "NET HANDLER: Handling entry.");
        NetLog("NET HANDLER: Caught NetQue Entry, handling.");
      }
      NetQueEntHandle(ent);
      Free(ent);
      if (net_log_log)
        {
        NetLog("NET HANDLER: Finished handling NetQue Entry, Freeing.");
        NetLog("NET HANDLER: NetQue empty, exiting interrupt.\n"
	      "$$BD,WHITE$$$$FD,LTGRAY$$"
	      "$$BG,DKGRAY$$$$FG,BLACK$$"
	      "==================="
	      "$$BG$$$$FG$$");
      }
    }
    else
      {
      LBts(&Fs->task_flags, TASKf_IDLE);
      Yield;
    }
  }
}

U0 NetHandlerInit()
{//IntEntrySet(I_NETHANDLER, &NetHandler);
  netfifo_handler_task = Spawn(&NetHandler, NULL, "NetHandler");
}

NetHandlerInit;

