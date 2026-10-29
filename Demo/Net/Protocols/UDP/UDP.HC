/***************************************************

UDP Socket Functions

***************************************************/

U0 UDPGlblsInit()
{
  udp_globals.bound_sock_tree = NULL;
  udp_bound_tree_lock = 0;
}

I64 UDPPktAlloc(U8 **frame_out,
                      U32 src_ip,
                      U16 src_port,
                      U32 dst_ip,
                      U16 dst_port,
                      I64 len)
{
  U8            *udp_frame;
  I64            de_index;
  CUDPHdr    *hdr;
  de_index = IPV4PktAlloc(&udp_frame,
                                IP_PROTOCOL_UDP,
                                src_ip,
                                dst_ip,
                                sizeof(CUDPHdr) + len);
  if (de_index < 0)
  {
    NetLog("UDP PACKET ALLOCATE: Ethernet Frame Allocate failed.");
    return de_index;
  }
  hdr = udp_frame;
  hdr->src_port           = EndianU16(src_port);
  hdr->dst_port  = EndianU16(dst_port);
  hdr->len                = EndianU16(sizeof(CUDPHdr) + len);
  hdr->checksum          = 0;
  *frame_out = udp_frame + sizeof(CUDPHdr);
  return de_index;
}

U0 UDPPktFinish(I64 de_index)
{// alias for IPV4PacketFinish, alias for EthFrameFinish, alias for driver send packet
  IPV4PktFinish(de_index);
}

I64 UDPPktPrs(U16 *src_port_out,
                 U16 *dst_port_out,
                 U8 **data_out,
                 I64 *len_out,
                 CIPV4Pkt *pkt)
{// check ip protocol? probably redundant
  CUDPHdr *hdr = pkt->data;
  I64 udp_len;
  if (pkt->len < sizeof(CUDPHdr))
    return -1;
  udp_len = EndianU16(hdr->len);
  if (udp_len < sizeof(CUDPHdr) || udp_len > pkt->len)
    return -1;
  *src_port_out      = EndianU16(hdr->src_port);
  *dst_port_out = EndianU16(hdr->dst_port);
  *data_out = pkt->data   + sizeof(CUDPHdr);
  *len_out   = udp_len - sizeof(CUDPHdr);
  return 0;
}

CUDPSock *UDPSock(U16 domain=AF_UNSPEC)
{//adam_task heap throughout: NetHandler reaches all of it by the bound tree.
  U16           type = SOCK_DATAGRAM;
  CUDPSock *udp_sock = CAlloc(sizeof(CUDPSock), adam_task);
  udp_sock->sock = Sock(domain, type, adam_task);
  udp_sock->rx_addr.family = domain;
  udp_sock->rx_queue = CAlloc(sizeof(CUDPMsgQue), adam_task);
  QueInit(udp_sock->rx_queue);
  return udp_sock;
}

I64 UDPSockBind(CUDPSock *udp_sock, CSockAddrStorage *addr_src)
{
  CUDPTreeNode     *head = udp_globals.bound_sock_tree;
  CUDPTreeNode     *temp_node, *spare;
  CUDPTreeQue      *spare_ent;
  I64                bind_err = 0;
  CSockAddrIPV4 *ipv4_src;
  CSockAddrIPV4 *ipv4_rx;
  CSockAddrIPV6 *ipv6_src;
  CSockAddrIPV6 *ipv6_rx;
  U16                   port;
  if (!SockBind(udp_sock->sock))
  {
    NetErr("UDP SOCKET BIND: Failed, Socket state-machine must be in READY state.");
    return -1;
  }
  if (udp_sock->bound_to)
  {
    NetErr("UDP SOCKET BIND: UDP Socket currently Bound.");
    return -1;
  }
  switch (addr_src->family)
  {
  case AF_INET:
    if (udp_sock->rx_addr.family == AF_INET6)
    {
      NetErr("UDP SOCKET BIND: Incompatible Address type.");
      return -1;
    }
    ipv4_src  = addr_src;
    ipv4_rx = &udp_sock->rx_addr;
    ipv4_rx->addr.addr   = ipv4_src->addr.addr;
    ipv4_rx->port              = ipv4_src->port;
    port = EndianU16(ipv4_src->port);
    break;
  case AF_INET6:
    if (udp_sock->rx_addr.family == AF_INET)
    {
      NetErr("UDP SOCKET BIND: Incompatible Address type.");
      return -1;
    }
    ipv6_src = addr_src;
    ipv6_rx = &udp_sock->rx_addr;
    port = EndianU16(ipv6_src->port);
    NetErr("UDP SOCKET BIND: FIXME, IPV6 UDP BIND");
    break;
  case AF_UNSPEC:
    NetErr("UDP SOCKET BIND: Error, AF_UNSPEC UDP BIND -- param family");
    return -1;
  default:
    NetErr("UDP SOCKET BIND: Error, unknown address family %d.", addr_src->family);
    return -1;
  }
  spare = UDPTreeNodeParamInit(port);
  spare_ent = UDPTreeQueEntInit(udp_sock);
  PUSHFD
  CLI
  while (LBts(&udp_bound_tree_lock, 0))
    PAUSE
  head = udp_globals.bound_sock_tree;
  if (head)
  {
    temp_node = UDPTreeNodeFind(port, head);
    if (temp_node)
    {
      switch (addr_src->family)
      {
      case AF_INET:
        if (UDPTreeNodeQueIPV4Find(ipv4_rx->addr.addr, temp_node, TRUE))
          bind_err = 1;
        else
        {
          QueIns(spare_ent, temp_node->queue->last);
          spare_ent = NULL;
        }
        break;
      case AF_INET6:
        bind_err = 2;
        break;
      }
    }
    else
    {
      UDPTreeNodeAdd(spare, head);
      QueIns(spare_ent, spare->queue->last);
      spare = NULL;
      spare_ent = NULL;
    }
  }
  else
  {
    udp_globals.bound_sock_tree = spare;
    QueIns(spare_ent, spare->queue->last);
    spare = NULL;
    spare_ent = NULL;
  }
  LBtr(&udp_bound_tree_lock, 0);
  POPFD
  if (spare)
  {
    Free(spare->queue);
    Free(spare);
  }
  Free(spare_ent);
  if (bind_err == 1)
  {
    NetErr("UDP SOCKET BIND: Address already in Bound Socket Tree !");
    return -1;
  }
  if (bind_err == 2)
    NetErr("UDP SOCKET BIND: FIXME, IPV6 UDP BIND");
  udp_sock->bound_to = port;
  switch (udp_sock->sock->state)
  {
  case SOCK_STATE_BIND_REQ:
    udp_sock->sock->state = SOCK_STATE_BOUND;
    break;
  default:
    NetErr("UDP SOCKET BIND: Failed, Misconfigured Socket state-machine.");
    return -1;
  }
  return 0;
}

I64 UDPSockClose(CUDPSock *udp_sock)
{// close, pop, and free the socket from the bound tree.
  CUDPTreeNode      *head, *node, *dead_node = NULL;
  CUDPTreeQue       *queue = NULL;
  CUDPMsgQue    *message;
  Bool               stuck = FALSE;
  if (!udp_sock)
    return -1;
  if (LBts(&udp_sock->close_lock, 0))
  {
    NetErr("UDP SOCKET CLOSE: Socket already closing.");
    return -1;
  }
  SockClose(udp_sock->sock);
  PUSHFD
  CLI
  while (LBts(&udp_bound_tree_lock, 0))
    PAUSE
  head = udp_globals.bound_sock_tree;
  node = UDPTreeNodeFind(udp_sock->bound_to, head);
  if (node)
  {
    queue = UDPTreeNodeQueSockFind(udp_sock, node);
    if (queue)
    {
      QueRem(queue);
      if (node->queue == node->queue->next)
      {
        if (node == head)
        {
          if (node->left)
          {
            udp_globals.bound_sock_tree = head = node->left;
            if (node->right)
              UDPTreeNodeAdd(node->right, head);
          }
          else if (node->right)
            udp_globals.bound_sock_tree = node->right;
          else
            udp_globals.bound_sock_tree = NULL;
          dead_node = node;
        }
        else if (UDPTreeNodeSinglePop(node->value, head) == node)
          dead_node = node;
        else
          stuck = TRUE;
      }
    }
  }
  LBtr(&udp_bound_tree_lock, 0);
  POPFD
  if (stuck)
    NetErr("UDP SOCKET CLOSE: Could not unlink node for port %d; left in tree, empty.",
          udp_sock->bound_to);
  while (udp_sock->handler_refs)
    Sleep(1);
  if (dead_node)
  {
    Free(dead_node->queue);
    Free(dead_node);
  }
  if (!queue)
    NetWarn("UDP SOCKET CLOSE: Socket was not bound; freeing anyway.");
  Free(udp_sock->sock);
  message = udp_sock->rx_queue->next;
  while (message != udp_sock->rx_queue)
  {
    QueRem(message);
    Free(message->data);
    Free(message);
    message = udp_sock->rx_queue->next;
  }
  Free(udp_sock->rx_queue);
  Free(udp_sock);
  if (!queue)
    return -1;
  Free(queue);
  return 0;
}

// UDPSockConnect (TODO)

// UDPLsten (Shrine just has no_warns, not implemented)

I64 UDPSockRxFrom(CUDPSock *udp_sock, U8 *buf, I64 len, CSockAddrStorage *addr_out)
{// ommitted I64 addrlen, flags not implemented
  CSockAddrIPV4    *ipv4_sock_addr;
  CSockAddrIPV6    *ipv6_sock_addr;
  CUDPMsgQue    *message;
  if (!SockRxFrom(udp_sock->sock))
  {
    NetErr("UDP SOCKET RECEIVE FROM: Socket state-machine must be in OPEN or BOUND state.");
    return -1;
  }
  if (len < 0)
  {
    NetErr("UDP SOCKET RECEIVE FROM: Invalid length requested.");
    return -1;
  }
  if (udp_sock->rx_timeout_ms != 0)
    udp_sock->rx_max_timeout = cnts.jiffies + udp_sock->rx_timeout_ms * JIFFY_FREQ / 1000;
  message = udp_sock->rx_queue;
  while (message == message->next)
  {
    if (udp_sock->rx_timeout_ms == 0)
      return -1;
    if (cnts.jiffies > udp_sock->rx_max_timeout)
    {
      NetErr("UDP SOCKET RECEIVE FROM: Timed out.");
      return -1;
    }
    Yield;
  }
  PUSHFD
  CLI
  while (LBts(&udp_sock->rx_lock, 0))
    PAUSE
  message = message->next;
  if (addr_out)
  {
    switch (message->from_addr.family)
    {
    case AF_INET:
      ipv4_sock_addr = addr_out;
      ClassCpy(ipv4_sock_addr, &message->from_addr);
      break;
    case AF_INET6:
      ipv6_sock_addr = addr_out;
      ClassCpy(ipv6_sock_addr, &message->from_addr);
      break;
    case AF_UNSPEC:
      NetWarn("UDP Receive From AF_UNSPEC UDPSock Address Family\n");
      break;
    }
  }
  if (len >= message->data_len - message->received_len)
  {// all data pulled, release message
    len = message->data_len - message->received_len;
    MemCpy(buf, message->data + message->received_len, len);
    QueRem(message);
    if (udp_sock->rx_queue_depth > 0)
      udp_sock->rx_queue_depth--;
    LBtr(&udp_sock->rx_lock, 0);
    POPFD
    Free(message->data);
    Free(message);
    return len;
  }
  MemCpy(buf, message->data + message->received_len, len);
  message->received_len += len;
  LBtr(&udp_sock->rx_lock, 0);
  POPFD
  return len;
}

I64 udp_next_ephemeral = 0;

I64 UDPSockSendTo(CUDPSock *udp_sock, U8 *buf, I64 len, CSockAddrStorage *dst_addr)
{//Send to destination_addr (NULL: the bound address), from the bound port.
  CSockAddrStorage *dst = dst_addr;
  CSockAddrIPV4        *ipv4_dst;
  CSockAddrIPV4         local;
  U8                        *payload_frame;
  I64                        de_index, i;
  if (!SockSendTo(udp_sock->sock))
  {
    NetErr("UDP SOCKET SEND TO: Socket state-machine must be in OPEN, BOUND or READY  state.");
    return -1;
  }
  if (udp_sock->sock->state == SOCK_STATE_READY)
  {
    local.family = AF_INET;
    local.addr.addr = INADDR_ANY;
    for (i = 0; i < 16; i++)
    {
      local.port = EndianU16(0xC000 + udp_next_ephemeral++ & 0x3FFF);
      if (UDPSockBind(udp_sock, &local) >= 0)
        break;
      udp_sock->sock->state = SOCK_STATE_READY;
    }
    if (i == 16)
    {
      NetErr("UDP SOCKET SEND TO: No free local port.");
      return -1;
    }
  }
  if (!dst)
    dst = &udp_sock->rx_addr;
  switch (dst->family)
  {
  case AF_INET:
    ipv4_dst = dst;
    de_index = UDPPktAlloc(&payload_frame,
                                 IPV4AddrGet,
                                 udp_sock->bound_to,
                                 EndianU32(ipv4_dst->addr.addr),
                                 EndianU16(ipv4_dst->port),
                                 len);
    break;
  case AF_INET6:
    NetErr("UDP SOCKET SEND TO: FIXME, IPV6 not implemented yet");
    return -1;
  default:
    NetErr("UDP SOCKET SEND TO: Error, UDP Send To AF_UNSPEC\n");
    return -1;
  }
  if (de_index < 0)
    return -1;
  MemCpy(payload_frame, buf, len);
  UDPPktFinish(de_index);
  return 0;
}

// UDPSockSetOpt ?

I64 UDPHandler(CIPV4Pkt *pkt)
{// TODO: Need either two UDP hndlrs for IPv4/IPv6, or logic changes if IPV6 is desired.
  U16                    src_port;
  U16                    dst_port;
  U8                    *data;
  I64                    len;
  CUDPTreeNode      *node;
  CUDPTreeQue       *queue = NULL;
  CUDPMsgQue    *messages_head;
  CUDPMsgQue    *message, *stale;
  CUDPSock            *udp_sock = NULL;
  CSockAddrIPV4    *ipv4_addr;
  I64 error = UDPPktPrs(&src_port, &dst_port, &data, &len, pkt);
  if (error < 0)
  {
    NetErr("UDP HANDLER: Packet Prs Error.");
    return error;
  }
  PUSHFD
  CLI
  while (LBts(&udp_bound_tree_lock, 0))
    PAUSE
  if (udp_globals.bound_sock_tree &&
        (node = UDPTreeNodeFind(dst_port, udp_globals.bound_sock_tree)))
    queue = UDPTreeNodeQueIPV4Find(pkt->src_ip_addr, node);
  if (queue)
  {
    udp_sock = queue->sock;
    udp_sock->handler_refs++;
  }
  LBtr(&udp_bound_tree_lock, 0);
  POPFD
  if (!udp_sock)
  {
    NetWarn("UDP HANDLER: No socket bound for port %d.", dst_port);
    return -1;
  }
  message = CAlloc(sizeof(CUDPMsgQue), adam_task);
  message->data = CAlloc(len, adam_task);
  MemCpy(message->data, data, len);
  message->data_len = len;
  ipv4_addr = &message->from_addr;
  ipv4_addr->family         = AF_INET;
  ipv4_addr->port               = EndianU16(src_port);
  ipv4_addr->addr.addr    = EndianU32(pkt->src_ip_addr);
  messages_head = udp_sock->rx_queue;
  PUSHFD
  CLI
  while (LBts(&udp_sock->rx_lock, 0))
    PAUSE
  stale = NULL;
  if (udp_sock->rx_queue_depth >= UDP_RECV_QUEUE_MAX &&
        messages_head->next != messages_head)
  {
    stale = messages_head->next;
    QueRem(stale);
    udp_sock->rx_queue_depth--;
  }
  QueInsRev(message, messages_head);
  udp_sock->rx_queue_depth++;
  LBtr(&udp_sock->rx_lock, 0);
  POPFD
  if (stale)
  {
    Free(stale->data);
    Free(stale);
  }
  PUSHFD
  CLI
  while (LBts(&udp_bound_tree_lock, 0))
    PAUSE
  udp_sock->handler_refs--;
  LBtr(&udp_bound_tree_lock, 0);
  POPFD
  return error;
}

// the socket functions just act on the socket state machine.
// NetErr and return fail vals if socket FSM improperly used.
// Careful with Free()'s.


U0 UDPTreeNodeRep(CUDPTreeNode *node)
{
  CUDPTreeQue       *queue = node->queue->next;
  CUDPSock            *sock;
  CSockAddrIPV4    *ipv4_addr;
  CSockAddrIPV6    *ipv6_addr;
  U8                    *str;
  CUDPMsgQue    *message;
  "Port $$YELLOW$$%d$$FG$$ (UDP Node @ $$CYAN$$0x%X$$FG$$):\n"
  , node->value, node;
  while (queue != node->queue)
  {
    sock = queue->sock;
    switch (sock->rx_addr.family)
    {
    case AF_UNSPEC:
      break;
    case AF_INET:
      ipv4_addr = &sock->rx_addr;
      str = MStrPrint("%d.%d.%d.%d",
                         ipv4_addr->addr.addr.u8[3],
                         ipv4_addr->addr.addr.u8[2],
                         ipv4_addr->addr.addr.u8[1],
                         ipv4_addr->addr.addr.u8[0]);
      " $$BROWN$$%s$$FG$$ (UDP Tree Que @ $$CYAN$$0x%X$$FG$$):\n"
      , str, queue;
      Free(str);
      break;
    case AF_INET6:
      ipv6_addr = &sock->rx_addr;
      break;
    default:
      break;
    }
    "       Timeout: %dms\n", sock->rx_timeout_ms;
    message = sock->rx_queue->next;
    while (message != sock->rx_queue)
    {
      "     Qued Msg @ $$CYAN$$0x%X$$FG$$:\n", message;
      switch (message->from_addr.family)
      {
      case AF_UNSPEC:
        str = StrNew("AF_UNSPEC");
        break;
      case AF_INET:
        ipv4_addr = &message->from_addr;
        str = NetToPres(ipv4_addr->family, &ipv4_addr->addr);
        break;
      case AF_INET6:
        str = StrNew("IPV6");
        break;
      default:
        str = StrNew("INVALID");
        break;
      }
      "         From Address:           $$BROWN$$%s$$FG$$\n", str;
      "         Data length:            %d\n"
      , message->data_len;
      "         Received data length:   %d\n"
      , message->received_len;
      Free(str);
      message = message->next;
    }
    queue = queue->next;
  }
  "\n";
}

U0 UDPRep()
{
  CUDPTreeNode  *node = udp_globals.bound_sock_tree;
  CUDPRepEnt  *head;
  CUDPRepEnt  *ent;
  CUDPRepEnt  *temp_ent;
  "$$LTBLUE$$UDP Report:$$FG$$\n\n";
  if (node)
  {
    head = CAlloc(sizeof(CUDPRepEnt));
    QueInit(head);
    ent = CAlloc(sizeof(CUDPRepEnt));
    ent->node = node;
    QueIns(ent, head);
    while (ent != head)
    {
      if (ent->node->left)
      {
        temp_ent = CAlloc(sizeof(CUDPRepEnt));
        temp_ent->node = ent->node->left;
        QueInsRev(temp_ent, head);
        if (!ent->node->right)
        {
          QueRem(ent);
          UDPTreeNodeRep(ent->node);
          Free(ent);
        }
        ent = temp_ent;
      }
      else if (ent->node->right)
      {
        temp_ent = CAlloc(sizeof(CUDPRepEnt));
        temp_ent->node = ent->node->right;
        QueInsRev(temp_ent, head);
        QueRem(ent);
        UDPTreeNodeRep(ent->node);
        Free(ent);
        ent = temp_ent;
      }
      else
      {
        QueRem(ent);
        UDPTreeNodeRep(ent->node);
        Free(ent);
        if (head->last != head)
        {
          temp_ent = head->last;
          if (temp_ent->node->right)
          {
            ent = temp_ent;
            temp_ent = CAlloc(sizeof(CUDPRepEnt));
            temp_ent->node = ent->node->right;
            QueInsRev(temp_ent, head);
            QueRem(ent);
            UDPTreeNodeRep(ent->node);
            Free(ent);
            ent = temp_ent;
          }
          else
          {
            QueRem(temp_ent);
            UDPTreeNodeRep(temp_ent->node);
            Free(temp_ent);
            ent = head->last;
          }
        }
        else
          break;
      }
    }
    Free(head);
  }
  else
    "No UDP Sockets currently bound.\n\n";
}

UDPGlblsInit;
