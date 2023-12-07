U0 IPV4Handler(CEthernetFrame *ethernet_frame)
{
  CIPV4Packet packet;
  IPV4PacketPrs(&packet, ethernet_frame);
  ARPCachePut(packet.source_ip_address, ethernet_frame->source_address);

  if (net_log_log) {
    switch (packet.protocol)
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
        NetLog("IPV4 HANDLER: Unrecognized protocol: 0x%X", packet.protocol);
        break;
    }
  }

  switch (packet.protocol)
    {
    case IP_PROTOCOL_ICMP:
      ICMPHandler(&packet);
      break;
    case IP_PROTOCOL_TCP:
      TCPHandler(&packet);
      break;
    case IP_PROTOCOL_UDP:
      UDPHandler(&packet);
      break;
    default:
      break;
  }

  if (net_log_log)
    NetLog("IPV4 HANDLER: Exiting.");
}

U0 NetQueEntryHandle(CNetQueEntry *entry)
{
  CEthernetFrame ethernet_frame;
  EthernetFramePrs(&ethernet_frame, entry->frame, entry->packet_length);

  if (net_log_log)
    {
    switch (ethernet_frame.ethertype)
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
        NetLog("HANDLE NETQUEUE ENTRY: Unrecognized ethertype: 0x%X", ethernet_frame.ethertype);
        break;
    }
  }

  switch (ethernet_frame.ethertype)
    {
    case ETHERTYPE_ARP:
      ARPHandler(&ethernet_frame);
      break;
    case ETHERTYPE_IPV4:
      IPV4Handler(&ethernet_frame);
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
  CNetQueEntry *entry;
  while (1)
    {
    if (entry=NetQuePull)
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
      NetQueEntryHandle(entry);
      Free(entry);
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

