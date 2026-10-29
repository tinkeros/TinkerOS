
U0 TCPGlblsInit()
{
  tcp_globals.bound_sock_tree = NULL;
  tcp_globals.next_src_port  = 0;
  tcp_bound_tree_lock = 0;
}

Bool IsTCPStateSync(CTCPSock *tcp_sock)
{
  switch (tcp_sock->state)
  {
  case TCP_STATE_ESTABLISHED:
  case TCP_STATE_FIN_WAIT1:
  case TCP_STATE_FIN_WAIT2:
  case TCP_STATE_CLOSE_WAIT:
  case TCP_STATE_CLOSING:
  case TCP_STATE_LAST_ACK:
  case TCP_STATE_TIME_WAIT:
    return TRUE;
  default:
    return FALSE;
  }
}

// TODO: Merge IPV4Checksum, TCPChecksumPartial, and TCPChecksumFinal into 1.
//       All use same alg.
I64 TCPRxWindow(CTCPSock *tcp_sock)
{//Free octets in the RX ring, clamped to the 16-bit header field.
  I64 used = (tcp_sock->write_position - tcp_sock->read_position) &
        (tcp_sock->rx_buf_size - 1),
      avail = tcp_sock->rx_buf_size - used - 1;
  return ClampI64(avail, 0, 0xFFFF);
}

U16 TCPChecksumPartial(U32 sum, U8 *hdr, I64 len)
{// same algorithm as IPV4Checksum, except sum is arg. First half.
  //todo. make names clearer, and better comments.
  I64  nleft = len;
  U16 *w = hdr;
  while (nleft > 1)
  {
    sum += *w++;
    nleft -= 2;
  }
  return sum;
}

U16 TCPChecksumFinal(U32 sum, U8 *hdr, I64 len)
{// same algorithm as IPV4Checksum, except sum is arg. Both halves.
  //todo. make names clearer, and better comments.
  I64  nleft = len;
  U16 *w = hdr;
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

I64 TCPPktAlloc(U8 **frame_out,
                      U32  src_ip,
                      U16  src_port,
                      U32  dst_ip,
                      U16  dst_port,
                      U32  seq_num,
                      U32  ack_num,
                      U8   flags,
                      I64  len,
                      U16  window)
{
  U8            *tcp_frame;
  I64            de_index;
  CTCPHdr    *hdr;
  de_index = IPV4PktAlloc(&tcp_frame,
                                IP_PROTOCOL_TCP,
                                src_ip,
                                dst_ip,
                                sizeof(CTCPHdr) + len);
  if (de_index < 0)
  {
    NetLog("TCP PACKET ALLOCATE: Ethernet Frame Allocate failed.");
    return de_index;
  }
  hdr = tcp_frame;
  ZeroClass(hdr);
  hdr->src_port           = EndianU16(src_port);
  hdr->dst_port  = EndianU16(dst_port);
  NetDbg("TCP PACKET ALLOCATE: Outputting header port src/dest 0x%0X/0x%0X:",
         hdr->src_port, hdr->dst_port);
  hdr->seq_num               = EndianU32(seq_num);
  hdr->ack_num               = EndianU32(ack_num);
  hdr->data_offset           = sizeof(CTCPHdr) / 4;
  hdr->flags             = flags;
  hdr->window_size           = EndianU16(window);
  hdr->checksum          = 0;
  hdr->urgent_pointer        = 0;
  *frame_out = tcp_frame + sizeof(CTCPHdr);
  return de_index;
}

U0 TCPPktFinish(I64            de_index,
                   U32            src_ip,
                   U32            dst_ip,
                   U8            *frame,
                   I64            len,
                   CTCPAckQue **send_buf_out=NULL)
{
  CTCPHdr         *hdr        = frame - sizeof(CTCPHdr);
  CTCPPseudoHdr  pseudohdr;
  U32                 checksum;
  CTCPAckQue     *send_buf;
  pseudohdr.src_addr      = EndianU32(src_ip);
  pseudohdr.dst_addr = EndianU32(dst_ip);
  pseudohdr.zeros                   = 0;
  pseudohdr.protocol                = IP_PROTOCOL_TCP;
  pseudohdr.tcp_len          = EndianU16(sizeof(CTCPHdr) + len);
  checksum = TCPChecksumPartial(0, &pseudohdr, sizeof(CTCPPseudoHdr));
  hdr->checksum = TCPChecksumFinal(checksum, hdr, sizeof(CTCPHdr) + len);
  if (send_buf_out)
  {
    send_buf = CAlloc(sizeof(CTCPAckQue), adam_task);
    send_buf->time_sent          = tS;
    send_buf->retries            = 0;
    send_buf->start_seq_num      = EndianU32(hdr->seq_num);
    send_buf->end_seq_num        = 0;
    send_buf->tcp_pkt_size    = sizeof(CTCPHdr) + len;
    send_buf->tcp_pkt         = CAlloc(sizeof(CTCPHdr) + len, adam_task);
    MemCpy(send_buf->tcp_pkt, hdr, sizeof(CTCPHdr) + len);
    *send_buf_out = send_buf;
  }
  IPV4PktFinish(de_index);
}

I64 TCPSend(U32 src_ip,
            U16 src_port,
            U32 dst_ip,
            U16 dst_port,
            U32 seq_num,
            U32 ack_num,
            U8  flags)
{// send raw unsocketed TCP packet, flags and/or data. Does not store into ACK Que (Send Buffer).
  U8 *payload_frame;
  I64 de_index = TCPPktAlloc(&payload_frame,
                                   src_ip,
                                   src_port,
                                   dst_ip,
                                   dst_port,
                                   seq_num,
                                   ack_num,
                                   flags,
                                   0,
                                   0);
  if (de_index < 0)
  {
    NetErr("TCP SEND: TCP Packet Allocate failed.");
    return de_index;
  }
  TCPPktFinish(de_index, src_ip, dst_ip, payload_frame, 0, NULL);
  return 0;
}

I64 TCPSendFlags(CTCPSock *tcp_sock, U8 flags)
{// send TCP packet, flags only. Stores into ACK Que (Send Buffer) if flags SYN or FIN.
  U8                        *payload_frame;
  CSockAddrStorage *dst   = &tcp_sock->dst_addr;
  CSockAddrStorage *src = &tcp_sock->src_addr;
  CSockAddrIPV4        *dst_ipv4;
  CSockAddrIPV6        *dst_ipv6;
  CSockAddrIPV4        *src_ipv4;
  CSockAddrIPV6        *src_ipv6;
  I64                        de_index;
  CTCPAckQue            *send_buf     = NULL;
  CTCPAckQue           **send_buf_ptr = NULL;
  I64                        window = TCPRxWindow(tcp_sock);
  NetDbg("TCP SEND FLAGS: Attempting Send using param TCP socket");
  switch (dst->family)
  {
  case AF_INET:
    dst_ipv4 = dst;
    switch (src->family)
    {
    case AF_INET:
      src_ipv4 = src;
      NetDbg("TCP SEND FLAGS: Trying TCP Packet Allocate... port src/dest 0x%0X/0x%0X",
             src_ipv4->port, dst_ipv4->port);
      de_index = TCPPktAlloc(&payload_frame,
                                   src_ipv4->addr.addr,
                                   EndianU16(src_ipv4->port),
                                   dst_ipv4->addr.addr,
                                   EndianU16(dst_ipv4->port),
                                   tcp_sock->next_send_seq_num,
                                   tcp_sock->next_recv_seq_num,
                                   flags,
                                   0,
                                   window);
      if (de_index < 0)
      {
        NetErr("TCP SEND FLAGS: TCP Packet Allocate failed.");
        return de_index;
      }
      break;
    case AF_INET6:
      src_ipv6 = src;
      NetErr("TCP SEND FLAGS: FIXME, IPV6 not implemented yet");
      return -1;
    case AF_UNSPEC:
      NetErr("TCP SEND FLAGS: Error, TCP Send from AF_UNSPEC\n");
      return -1;
    }
    break;
  case AF_INET6:
    dst_ipv6 = dst;
    NetErr("TCP SEND FLAGS: FIXME, IPV6 not implemented yet");
    return -1;
  case AF_UNSPEC:
    NetErr("TCP SEND FLAGS: Error, TCP Send to AF_UNSPEC\n");
    return -1;
  }
  tcp_sock->rx_window = window;
  if (Bt(&flags, TCPf_SYN))
    tcp_sock->next_send_seq_num++;
  if (Bt(&flags, TCPf_FIN))
    tcp_sock->next_send_seq_num++;
  if (Bt(&flags, TCPf_FIN) || Bt(&flags, TCPf_SYN))
  {
    send_buf_ptr = &send_buf;
  }
  switch (dst->family)
  {
  case AF_INET:
    dst_ipv4 = dst;
    switch (src->family)
    {
    case AF_INET:
      src_ipv4 = src;
      TCPPktFinish(de_index,
                      src_ipv4->addr.addr,
                      dst_ipv4->addr.addr,
                      payload_frame,
                      0,
                      send_buf_ptr);
      if (send_buf)
      {
        send_buf->end_seq_num = tcp_sock->next_send_seq_num;
        QueInsRev(send_buf, tcp_sock->ack_queue);
      }
      break;
    case AF_INET6:
      src_ipv6 = src;
      NetErr("TCP SEND FLAGS: FIXME, IPV6 not implemented yet");
      return -1;
    case AF_UNSPEC:
      NetErr("TCP SEND FLAGS: Error, TCP Send from AF_UNSPEC\n");
      return -1;
    }
    break;
  case AF_INET6:
    dst_ipv6 = dst;
    NetErr("TCP SEND FLAGS: FIXME, IPV6 not implemented yet");
    return -1;
  case AF_UNSPEC:
    NetErr("TCP SEND FLAGS: Error, TCP Send to AF_UNSPEC\n");
    return -1;
  }
  return 0;
}

I64 TCPSendData(CTCPSock *tcp_sock, U8 flags, U8 *data, I64 len)
{// send TCP packet, flags and data. Stores into ACK Que (Send Buffer).
  U8                        *payload_frame;
  CSockAddrStorage *dst   = &tcp_sock->dst_addr;
  CSockAddrStorage *src = &tcp_sock->src_addr;
  CSockAddrIPV4        *dst_ipv4;
  CSockAddrIPV6        *dst_ipv6;
  CSockAddrIPV4        *src_ipv4;
  CSockAddrIPV6        *src_ipv6;
  I64                        de_index;
  CTCPAckQue            *send_buf;
  I64                        window = TCPRxWindow(tcp_sock);
  NetDbg("TCP SEND DATA: Attempting Send using param TCP socket");
  switch (dst->family)
  {
  case AF_INET:
    dst_ipv4 = dst;
    switch (src->family)
    {
    case AF_INET:
      src_ipv4 = src;
      NetDbg("TCP SEND DATA: Trying TCP Packet Allocate... port src/dest 0x%0X/0x%0X",
             src_ipv4->port, dst_ipv4->port);
      de_index = TCPPktAlloc(&payload_frame,
                                   src_ipv4->addr.addr,
                                   EndianU16(src_ipv4->port),
                                   dst_ipv4->addr.addr,
                                   EndianU16(dst_ipv4->port),
                                   tcp_sock->next_send_seq_num,
                                   tcp_sock->next_recv_seq_num,
                                   flags,
                                   len,
                                   window);
      if (de_index < 0)
      {
        NetLog("TCP SEND DATA: TCP Packet Allocate failed.");
        return de_index;
      }
      break;
    case AF_INET6:
      src_ipv6 = src;
      NetErr("TCP SEND DATA: FIXME, IPV6 not implemented yet");
      return -1;
    case AF_UNSPEC:
      NetErr("TCP SEND DATA: Error, TCP Send from AF_UNSPEC\n");
      return -1;
    }
    break;
  case AF_INET6:
    dst_ipv6 = dst;
    NetErr("TCP SEND DATA: FIXME, IPV6 not implemented yet");
    return -1;
  case AF_UNSPEC:
    NetErr("TCP SEND DATA: Error, TCP Send to AF_UNSPEC\n");
    return -1;
  }
  tcp_sock->rx_window = window;
  if (len)
    MemCpy(payload_frame, data, len);
  if (Bt(&flags, TCPf_SYN))
    tcp_sock->next_send_seq_num++;
  tcp_sock->next_send_seq_num += len;
  if (Bt(&flags, TCPf_FIN))
    tcp_sock->next_send_seq_num++;
  switch (dst->family)
  {
  case AF_INET:
    dst_ipv4 = dst;
    switch (src->family)
    {
    case AF_INET:
      src_ipv4 = src;
      TCPPktFinish(de_index,
                      src_ipv4->addr.addr,
                      dst_ipv4->addr.addr,
                      payload_frame,
                      len,
                      &send_buf);
      send_buf->end_seq_num = tcp_sock->next_send_seq_num;
      QueInsRev(send_buf, tcp_sock->ack_queue);
      break;
    case AF_INET6:
      src_ipv6 = src;
      NetErr("TCP SEND DATA: FIXME, IPV6 not implemented yet");
      return -1;
    case AF_UNSPEC:
      NetErr("TCP SEND DATA: Error, TCP Send from AF_UNSPEC\n");
      return -1;
    }
    break;
  case AF_INET6:
    dst_ipv6 = dst;
    NetErr("TCP SEND DATA: FIXME, IPV6 not implemented yet");
    return -1;
  case AF_UNSPEC:
    NetErr("TCP SEND DATA: Error, TCP Send to AF_UNSPEC\n");
    return -1;
  }
  return 0;
}

I64 TCPPktPrs(CTCPHdr **hdr_out,
                 U8       **data_out,
                 I64           *len_out,
                 CIPV4Pkt *pkt)
{
  CTCPHdr         *hdr        = pkt->data;
  I64                 hdr_len;
  if (pkt->len < sizeof(CTCPHdr))
    return -1;
  hdr_len = hdr->data_offset * 4;
  if (hdr_len < sizeof(CTCPHdr) || hdr_len > pkt->len)
    return -1;
  /*    NetWarn("DEBUG: TCPPACKETPARSE:     0x%X = checksum from packet, verifying...", EndianU16(header->checksum));
    pseudoheader->source_address        = EndianU32(packet->source_ip_address);
    pseudoheader->destination_address   = EndianU32(packet->destination_ip_address);
    pseudoheader->zeros                 = 0;
    pseudoheader->protocol              = IP_PROTOCOL_TCP;
    pseudoheader->tcp_length            = EndianU16(packet->length);

    checksum = TCPChecksumPartial(0, pseudoheader, sizeof(CTCPPseudoHeader));
    NetWarn("DEBUG: TCPPACKETPARSE:     0x%X = partial checksum", checksum);

    Free(pseudoheader);

    sum = TCPChecksumFinal(checksum, header, packet->length);

    if (sum != EndianU16(header->checksum))
    {
        NetErr("DEBUG: TCPPACKETPARSE:      0x%X = NOT MATCH", sum);
    }
  */
  *hdr_out = hdr;
  *data_out = pkt->data   + hdr_len;
  *len_out   = pkt->len - hdr_len;
  return 0;
}

U0 TCPAcknowledgePkt(CTCPSock *tcp_sock, U32 segment_ack)
{
  F64                time = tS;
  F64                rtt;
  CTCPAckQue    *send_buf = tcp_sock->ack_queue->next;
  CTCPAckQue    *send_buf_temp;
  I64                segment_ack_relative;
  I64                send_next_relative;
  NetDbg("TCP ACKNOWLEDGE PACKET: Looking to see if there are any send buffers");
  while (send_buf != tcp_sock->ack_queue)
  {
    segment_ack_relative    = (segment_ack - send_buf->end_seq_num) & 0xFFFFFFFF;
    send_next_relative      = (tcp_sock->next_send_seq_num - send_buf->end_seq_num) & 0xFFFFFFFF;
    if (segment_ack_relative <= send_next_relative)
    {
      NetDbg("TCP ACKNOWLEDGE PACKET: Saw send buffer entry with ACK <= next relative send ACK, removing.");
      rtt = time - send_buf->time_sent;
      tcp_sock->srtt = (tcp_sock->srtt * TCP_SRTT_ALPHA) + ((1.0 - TCP_SRTT_ALPHA) * rtt);
      QueRem(send_buf);
      Free(send_buf->tcp_pkt);
      send_buf_temp = send_buf->next;
      Free(send_buf);
      send_buf = send_buf_temp;
    }
    else
      send_buf = send_buf->next;
  }
}

U0 TCPCheckACKQue(CTCPSock *tcp_sock)
{
  F64                        time           = tS;
  F64                        rto            = TCP_RTO_BETA * tcp_sock->srtt;
  CTCPAckQue            *send_buf    = tcp_sock->ack_queue->next;
  CTCPAckQue            *first_buf   = send_buf;
  U8                        *tcp_frame;
  I64                        de_index;
  CSockAddrStorage *dst           = &tcp_sock->dst_addr;
  CSockAddrStorage *src         = &tcp_sock->src_addr;
  CSockAddrIPV4        *dst_ipv4;
  CSockAddrIPV6        *dst_ipv6;
  CSockAddrIPV4        *src_ipv4;
  CSockAddrIPV6        *src_ipv6;
  CTCPHdr                *retransmit_hdr;
  CTCPPseudoHdr           pseudohdr;
  U32                        checksum;
  I64                        window;
  if (send_buf == tcp_sock->ack_queue)
  {
    return;
  }
  if (rto < TCP_RTO_MIN)
    rto = TCP_RTO_MIN;
  if (rto > TCP_RTO_MAX)
    rto = TCP_RTO_MAX;
  do
  {
    if (time > send_buf->time_sent + rto)
    {
      NetWarn("TCP CHECK ACK QUEUE: Retransmitting TCP packet in ACK Que.");
      switch (dst->family)
      {
      case AF_INET:
        dst_ipv4 = dst;
        switch (src->family)
        {
        case AF_INET:
          src_ipv4 = src;
          de_index = IPV4PktAlloc(&tcp_frame,
                                        IP_PROTOCOL_TCP,
                                        src_ipv4->addr.addr,
                                        dst_ipv4->addr.addr,
                                        send_buf->tcp_pkt_size);
          if (de_index < 0)
          {
            NetErr("TCP CHECK ACK QUEUE: IPV4 Packet Allocate failed.");
            return;
          }
          MemCpy(tcp_frame, send_buf->tcp_pkt, send_buf->tcp_pkt_size);
          retransmit_hdr = tcp_frame;
          retransmit_hdr->ack_num = EndianU32(tcp_sock->next_recv_seq_num);
          window = TCPRxWindow(tcp_sock);
          retransmit_hdr->window_size = EndianU16(window);
          tcp_sock->rx_window = window;
          retransmit_hdr->checksum = 0;
          pseudohdr.src_addr      = EndianU32(src_ipv4->addr.addr);
          pseudohdr.dst_addr = EndianU32(dst_ipv4->addr.addr);
          pseudohdr.zeros               = 0;
          pseudohdr.protocol            = IP_PROTOCOL_TCP;
          pseudohdr.tcp_len          = EndianU16(send_buf->tcp_pkt_size);
          checksum = TCPChecksumPartial(0, &pseudohdr, sizeof(CTCPPseudoHdr));
          retransmit_hdr->checksum = TCPChecksumFinal(checksum, retransmit_hdr,
                send_buf->tcp_pkt_size);
          IPV4PktFinish(de_index);
          break;
        case AF_INET6:
          src_ipv6 = src;
          NetErr("TCP CHECK ACK QUEUE: FIXME, IPV6 not implemented yet");
          return;
        case AF_UNSPEC:
          NetErr("TCP CHECK ACK QUEUE: Error, TCP Send from AF_UNSPEC\n");
          return;
        }
        break;
      case AF_INET6:
        dst_ipv6 = dst;
        NetErr("TCP CHECK ACK QUEUE: FIXME, IPV6 not implemented yet");
        return;
      case AF_UNSPEC:
        NetErr("TCP CHECK ACK QUEUE: Error, TCP Send to AF_UNSPEC\n");
        return;
      }
      send_buf->time_sent = tS;
      QueRem(send_buf);
      QueInsRev(send_buf, tcp_sock->ack_queue);
      send_buf = tcp_sock->ack_queue->next;
    }
    else
      break;
  }
  while (send_buf != first_buf);
}

CTCPSock TCPSock(U16 domain=AF_UNSPEC)
{//adam_task heap throughout: NetHandler reaches all of it by the bound tree.
  U16                    type           = SOCK_STREAM;
  CTCPSock            *tcp_sock     = CAlloc(sizeof(CTCPSock), adam_task);
  CTCPAckQue        *ack_queue      = CAlloc(sizeof(CTCPAckQue), adam_task);
  CTCPAcceptQue     *accept_queue   = CAlloc(sizeof(CTCPAcceptQue), adam_task);
  CSockAddrIPV4    *ipv4_addr;
  CSockAddrIPV6    *ipv6_addr;
  tcp_sock->sock    = Sock(domain, type, adam_task);
  tcp_sock->state = TCP_STATE_CLOSED;
  tcp_sock->src_addr.family = domain;
  switch (domain)
  {
  case AF_INET:
    ipv4_addr = &tcp_sock->src_addr;
    ipv4_addr->addr.addr = IPV4AddrGet;
    break;
  case AF_INET6:
    ipv6_addr = &tcp_sock->src_addr;
    NetErr("TCP SOCKET: FIXME, IPV6 not implemented yet");
    goto ts_fail;
  case AF_UNSPEC:
    NetErr("TCP SOCKET: Error TCP Socket to AF_UNSPEC");
    goto ts_fail;
  }
  QueInit(ack_queue);
  tcp_sock->ack_queue = ack_queue;
  QueInit(accept_queue);
  tcp_sock->accept_queue = accept_queue;
  tcp_sock->rx_buf_size = TCP_WINDOW_SIZE;
  tcp_sock->rx_buf = CAlloc(TCP_WINDOW_SIZE, adam_task);
  tcp_sock->max_segment_size = TCP_MSS;
  return tcp_sock;
ts_fail:
  Free(tcp_sock->sock);
  Free(accept_queue);
  Free(ack_queue);
  Free(tcp_sock);
  return NULL;
}

I64 TCPSockTreeLink(CTCPSock *tcp_sock, U16 port, U8 *who)
{//Link tcp_sock into the bound tree at port (bind and connect).
  CTCPTreeNode *head, *temp_node, *spare = TCPTreeNodeParamInit(port);
  CTCPTreeQue  *spare_ent = TCPTreeQueEntInit(tcp_sock);
  CSockAddrIPV4 *ipv4_dst = &tcp_sock->dst_addr;
  Bool          in_use = FALSE;
  PUSHFD
  CLI
  while (LBts(&tcp_bound_tree_lock, 0))
    PAUSE
  head = tcp_globals.bound_sock_tree;
  if (!head)
  {// if no bound sockets, we init the tree as a new node
    tcp_globals.bound_sock_tree = spare;
    QueIns(spare_ent, spare->queue->last);
    spare = NULL;
    spare_ent = NULL;
  }
  else if (temp_node = TCPTreeNodeFind(port, head))
  {
    if (TCPTreeNodeQueIPV4Find(ipv4_dst->addr.addr, temp_node, TRUE))
      in_use = TRUE;
    else
    {
      QueIns(spare_ent, temp_node->queue->last);
      spare_ent = NULL;
    }
  }
  else
  {
    TCPTreeNodeAdd(spare, head);
    QueIns(spare_ent, spare->queue->last);
    spare = NULL;
    spare_ent = NULL;
  }
  LBtr(&tcp_bound_tree_lock, 0);
  POPFD
  if (spare)
  {
    Free(spare->queue);
    Free(spare);
  }
  Free(spare_ent);
  if (in_use)
  {
    NetErr("TCP SOCKET %s: Address already in Bound Socket Tree !", who);
    return -1;
  }
  return 0;
}

I64 TCPSockBind(CTCPSock *tcp_sock, CSockAddrStorage *addr)
{// Binds a TCP socket to address, which contains the local port and remote address to use.
  CSockAddrIPV4 *ipv4_addr;
  CSockAddrIPV4 *ipv4_dst;
  CSockAddrIPV4 *ipv4_src;
  CSockAddrIPV6 *ipv6_addr;
  CSockAddrIPV6 *ipv6_dst;
  U16                   port;
  if (!SockBind(tcp_sock->sock))
  {
    NetErr("TCP SOCKET BIND: Failed, Socket state-machine must be in READY state.");
    return -1;
  }
  if (tcp_sock->state != TCP_STATE_CLOSED)
  {
    NetErr("TCP SOCKET BIND: Failed, TCP Socket must be in CLOSED state.");
    return -1;
  }
  switch (addr->family)
  {
  case AF_INET:
    if (tcp_sock->src_addr.family == AF_INET6)
    {
      NetErr("TCP SOCKET BIND: FIXME, IPV6->IPV4 TCP BIND");
      return -1;
    }
    ipv4_addr = addr;
    ipv4_dst = &tcp_sock->dst_addr;
    ipv4_dst->family            = AF_INET;
    ipv4_dst->addr.addr   = ipv4_addr->addr.addr;
    ipv4_src = &tcp_sock->src_addr;
    ipv4_src->port = ipv4_addr->port;
    port = EndianU16(ipv4_addr->port);
    break;
  case AF_INET6:
    if (tcp_sock->src_addr.family == AF_INET)
    {
      NetErr("TCP SOCKET BIND: Incompatible Address type.");
      return -1;
    }
    ipv6_addr = addr;
    ipv6_dst = &tcp_sock->dst_addr;
    port = EndianU16(ipv6_addr->port);
    NetErr("TCP SOCKET BIND: FIXME, IPV6 TCP BIND");
    break;
  case AF_UNSPEC:
    NetErr("TCP SOCKET BIND: Error, AF_UNSPEC TCP BIND -- param family");
    return -1;
  default:
    NetErr("TCP SOCKET BIND: Error, unknown address family %d.", addr->family);
    return -1;
  }
  if (addr->family != AF_INET)
    return -1;
  if (TCPSockTreeLink(tcp_sock, port, "BIND") < 0)
    return -1;
  switch (tcp_sock->sock->state)
  {
  case SOCK_STATE_BIND_REQ:
    tcp_sock->sock->state = SOCK_STATE_BOUND;
    break;
  default:
    NetErr("TCP SOCKET BIND: Failed, Misconfigured Socket state-machine.");
    return -1;
  }
  return 0;
}

U0 TCPSockRelease(CTCPSock *tcp_sock)
{//Free a socket and everything hanging off it. Must be unreachable first.
  CTCPAckQue        *send_buf;
  CTCPAcceptQue     *pending;
  if (!tcp_sock)
    return;
  Free(tcp_sock->sock);
  Free(tcp_sock->rx_buf);
  send_buf = tcp_sock->ack_queue->next;
  while (send_buf != tcp_sock->ack_queue)
  {
    QueRem(send_buf);
    Free(send_buf->tcp_pkt);
    Free(send_buf);
    send_buf = tcp_sock->ack_queue->next;
  }
  Free(tcp_sock->ack_queue);
  pending = tcp_sock->accept_queue->next;
  while (pending != tcp_sock->accept_queue)
  {
    QueRem(pending);
    Free(pending);
    pending = tcp_sock->accept_queue->next;
  }
  Free(tcp_sock->accept_queue);
  Free(tcp_sock);
}

I64 TCPSockClose(CTCPSock *tcp_sock)
{
  CTCPTreeNode      *head, *node, *dead_node = NULL;
  CTCPTreeQue       *queue = NULL;
  CSockAddrIPV4    *addr;
  I64                    timeout;
  Bool                   stuck = FALSE;
  if (!tcp_sock)
    return -1;
  if (LBts(&tcp_sock->close_lock, 0))
  {
    NetErr("TCP SOCKET CLOSE: Socket already closing.");
    return -1;
  }
  addr = &tcp_sock->src_addr;
  SockClose(tcp_sock->sock);
  switch (tcp_sock->state)
  {
  case TCP_STATE_ESTABLISHED:
    while (TCPSendFlags(tcp_sock, TCPF_FIN | TCPF_ACK) < 0)
    {
      TCPCheckACKQue(tcp_sock);
      Sleep(1);
    }
    tcp_sock->state = TCP_STATE_FIN_WAIT1;
    timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
    while (tcp_sock->state == TCP_STATE_FIN_WAIT1 &&
           tcp_sock->first_unacked_seq != tcp_sock->next_send_seq_num &&
           cnts.jiffies < timeout)
    {
      TCPCheckACKQue(tcp_sock);
      Sleep(1);
    }
    if (tcp_sock->state == TCP_STATE_FIN_WAIT1)
      tcp_sock->state = TCP_STATE_FIN_WAIT2;
    timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
    while (tcp_sock->state == TCP_STATE_FIN_WAIT2 && cnts.jiffies < timeout)
      Sleep(1);
    break;
  case TCP_STATE_CLOSE_WAIT:
    while (TCPSendFlags(tcp_sock, TCPF_FIN | TCPF_ACK) < 0)
    {
      TCPCheckACKQue(tcp_sock);
      Sleep(1);
    }
    if (tcp_sock->state == TCP_STATE_CLOSE_WAIT)
      tcp_sock->state = TCP_STATE_LAST_ACK;
    timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
    while (tcp_sock->state == TCP_STATE_LAST_ACK &&
           tcp_sock->first_unacked_seq != tcp_sock->next_send_seq_num &&
           cnts.jiffies < timeout)
    {
      TCPCheckACKQue(tcp_sock);
      Sleep(1);
    }
    break;
  }
  if (IsTCPStateSync(tcp_sock))
    TCPSendFlags(tcp_sock, TCPF_RST);
  PUSHFD
  CLI
  while (LBts(&tcp_bound_tree_lock, 0))
    PAUSE
  head = tcp_globals.bound_sock_tree;
  node = TCPTreeNodeFind(EndianU16(addr->port), head);
  if (node)
  {
    queue = TCPTreeNodeQueSockFind(tcp_sock, node);
    if (queue)
    {
      QueRem(queue);
      if (node->queue == node->queue->next)
      {
        if (node == head)
        {
          if (node->left)
          {
            tcp_globals.bound_sock_tree = head = node->left;
            if (node->right)
              TCPTreeNodeAdd(node->right, head);
          }
          else if (node->right)
            tcp_globals.bound_sock_tree = node->right;
          else
            tcp_globals.bound_sock_tree = NULL;
          dead_node = node;
        }
        else if (TCPTreeNodeSinglePop(node->value, head) == node)
          dead_node = node;
        else
          stuck = TRUE;
      }
    }
  }
  LBtr(&tcp_bound_tree_lock, 0);
  POPFD
  if (stuck)
    NetErr("TCP SOCKET CLOSE: Could not unlink node for port %d; left in tree, empty.",
          EndianU16(addr->port));
  while (tcp_sock->handler_refs)
    Sleep(1);
  if (dead_node)
  {
    Free(dead_node->queue);
    Free(dead_node);
  }
  if (!queue)
    NetWarn("TCP SOCKET CLOSE: Socket was not bound; freeing anyway.");
  TCPSockRelease(tcp_sock);
  if (!queue)
    return -1;
  Free(queue);
  return 0;
}

I64 TCPSockConnect(CTCPSock *tcp_sock, CSockAddrStorage *addr)
{// Bind and connect a socket to the destination address and port in address param, local port automatic.
  U16                   src_port = EndianU16(0x8000 + tcp_globals.next_src_port++ & 0x7FFF);
  CSockAddrIPV4 *ipv4_addr;
  CSockAddrIPV4 *ipv4_dst;
  CSockAddrIPV4 *ipv4_src;
  CSockAddrIPV6 *ipv6_addr;
  CSockAddrIPV6 *ipv6_dst;
  I64                   timeout;
  U16                   port;
  if (!SockConnect(tcp_sock->sock))
  {
    NetErr("TCP SOCKET CONNECT: Failed, Socket state-machine must be in READY state.");
    return -1;
  }
  if (tcp_sock->state != TCP_STATE_CLOSED)
  {
    NetErr("TCP SOCKET CONNECT: TCP Socket must be in CLOSED state.");
    return -1;
  }
  switch (addr->family)
  {
  case AF_INET:
    if (tcp_sock->src_addr.family == AF_INET6)
    {
      NetErr("TCP SOCKET CONNECT: FIXME, IPV6->IPV4 TCP CONNECT");
      return -1;
    }
    ipv4_addr = addr;
    ipv4_dst = &tcp_sock->dst_addr;
    ipv4_dst->family            = AF_INET;
    ipv4_dst->addr.addr   = ipv4_addr->addr.addr;
    ipv4_dst->port              = ipv4_addr->port;
    ipv4_src = &tcp_sock->src_addr;
    ipv4_src->port = src_port;
    port = EndianU16(src_port);
    break;
  case AF_INET6:
    if (tcp_sock->src_addr.family == AF_INET)
    {
      NetErr("TCP SOCKET CONNECT: Incompatible Address type.");
      return -1;
    }
    ipv6_addr = addr;
    ipv6_dst = &tcp_sock->dst_addr;
    port = EndianU16(src_port);
    NetErr("TCP SOCKET CONNECT: FIXME, IPV6 TCP CONNECT");
    break;
  case AF_UNSPEC:
    NetErr("TCP SOCKET CONNECT: Error, AF_UNSPEC TCP CONNECT -- param family");
    return -1;
  default:
    NetErr("TCP SOCKET CONNECT: Error, unknown address family %d.", addr->family);
    return -1;
  }
  if (addr->family != AF_INET)
    return -1;
  if (TCPSockTreeLink(tcp_sock, port, "CONNECT") < 0)
    return -1;
  tcp_sock->connection_time = tS;
  tcp_sock->rx_window    = TCP_WINDOW_SIZE;
  tcp_sock->state = TCP_STATE_SYN_SENT;
  TCPSendFlags(tcp_sock, TCPF_SYN);
  timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
  while (cnts.jiffies < timeout)
  {
    switch (tcp_sock->state)
    {
    case TCP_STATE_ESTABLISHED:
    case TCP_STATE_CLOSED:
      timeout = 0;
      break;
    default:
      Sleep(1);
    }
  }
  if (tcp_sock->state != TCP_STATE_ESTABLISHED)
  {
    NetErr("TCP SOCKET CONNECT: Failed to establish TCP Socket connection.");
    return -1;
  }
  switch (tcp_sock->sock->state)
  {
  case SOCK_STATE_CONNECT_REQ:
    tcp_sock->sock->state = SOCK_STATE_OPEN;
    break;
  default:
    NetErr("TCP SOCKET CONNECT: Failed, Misconfigured Socket state-machine.");
    return -1;
  }
  return 0;
}

I64 TCPSockLsten(CTCPSock *tcp_sock, I64 backlog_size)
{// Set a bound socket to Lsten for incoming connections. Backlog size is max amount of waiting connections allowed
  if (!SockLsten(tcp_sock->sock))
  {
    NetErr("TCP SOCKET LISTEN: Socket state-machine must be in BOUND state.");
    return -1;
  }
  if (tcp_sock->state != TCP_STATE_CLOSED)
  {
    NetErr("TCP SOCKET LISTEN: TCP Socket must be in CLOSED state.");
    return -1;
  }
  tcp_sock->state = TCP_STATE_LISTEN;
  tcp_sock->accept_queue_limit = backlog_size;
  switch (tcp_sock->sock->state)
  {
  case SOCK_STATE_LISTEN_REQ:
    tcp_sock->sock->state = SOCK_STATE_LISTENING;
    break;
  default:
    NetErr("TCP SOCKET BIND: Failed, Misconfigured Socket state-machine.");
    return -1;
  }
  return 0;
}

CTCPSock *TCPSockAccept(CTCPSock *tcp_sock)
{// Accepts & creates a new socket, uses timeout inherited from Lstening socket.
  CTCPAcceptQue     *pending;
  CTCPSock            *new_sock;
  CSockAddrIPV4    *temp_addr;
  CSockAddrIPV4     ipv4_addr;
  I64                    timeout;
  if (!SockAccept(tcp_sock->sock))
  {
    NetErr("TCP SOCKET ACCEPT: Failed, Socket state-machine must be in LISTENING state.");
    return NULL;
  }
  if (tcp_sock->state != TCP_STATE_LISTEN)
  {
    NetErr("TCP SOCKET LISTEN: TCP Socket must be in LISTEN state.");
    return NULL;
  }
  timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
  while ((pending = tcp_sock->accept_queue->next) == tcp_sock->accept_queue)
  {
    if (cnts.jiffies > timeout)
      return NULL;
    else
      Sleep(1);
  }
  QueRem(pending);
  new_sock = TCPSock(AF_INET);
  if (!new_sock)
  {
    Free(pending);
    return NULL;
  }
  new_sock->next_recv_seq_num = ++pending->segment_seq_num;
  new_sock->connection_time       = tS;
  new_sock->rx_window        = TCP_WINDOW_SIZE;
  new_sock->timeout               = tcp_sock->timeout;
  temp_addr = &tcp_sock->src_addr;
  ipv4_addr.family               = AF_INET;
  ipv4_addr.port             = temp_addr->port;
  ipv4_addr.addr.addr  = pending->ipv4_addr;
  NetDbg("TCP SOCKET ACCEPT: Attempting to Bind to pending connection %0X @ src/dst ports %d,%d.",
         pending->ipv4_addr, ipv4_addr.port, pending->port);
  if (TCPSockBind(new_sock, &ipv4_addr) == -1)
  {
    TCPSockRelease(new_sock);
    Free(pending);
    return NULL;
  }
  temp_addr = &new_sock->dst_addr;
  temp_addr->port = pending->port;
  new_sock->state = TCP_STATE_SYN_RECEIVED;
  NetDbg("TCP SOCKET ACCEPT: Attempting Send Flags SYN ACK back to requester.");
  TCPSendFlags(new_sock, TCPF_SYN | TCPF_ACK);
  timeout = cnts.jiffies + new_sock->timeout * JIFFY_FREQ / 1000;
  while (cnts.jiffies < timeout)
  {
    switch (new_sock->state)
    {
    case TCP_STATE_ESTABLISHED:
    case TCP_STATE_CLOSED:
      timeout = 0;
      break;
    default:
      Sleep(1);
    }
  }
  if (new_sock->state != TCP_STATE_ESTABLISHED)
  {
    TCPSockClose(new_sock);
    Free(pending);
    return NULL;
  }
  Free(pending);
  new_sock->sock->state = SOCK_STATE_OPEN;
  return new_sock;
}

I64 TCPSockRx(CTCPSock *tcp_sock, U8 *buf, I64 len)
{
  I64 read_position;
  I64 write_position;
  I64 read_total = 0;
  I64 step;
  I64 timeout;
  I64 threshold;
  if (!SockRx(tcp_sock->sock))
  {
    NetErr("TCP SOCKET RECEIVE: Failed, Socket state-machine must be in OPEN or BOUND state.");
    return NULL;
  }
  timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
  while ((tcp_sock->state == TCP_STATE_ESTABLISHED    ||
          tcp_sock->state == TCP_STATE_FIN_WAIT1  ||
          tcp_sock->state == TCP_STATE_CLOSE_WAIT)    &&
         tcp_sock->read_position == tcp_sock->write_position)
  {
    TCPCheckACKQue(tcp_sock);
    Sleep(1+tcp_sock->timeout/1000);
    if (cnts.jiffies > timeout)
      break;
  }
  if ((tcp_sock->state != TCP_STATE_ESTABLISHED || tcp_sock->state == TCP_STATE_FIN_WAIT1) &&
      tcp_sock->read_position == tcp_sock->write_position || len == 0)
    return 0;
  if (cnts.jiffies > timeout)
  {
    if (tcp_sock->timeout != 0)
      NetWarn("TCP SOCKET RECEIVE: Timed out.");
    return -1;
  }
  read_position = tcp_sock->read_position;
  write_position    = tcp_sock->write_position;
  if (write_position < read_position)
  {
    step = tcp_sock->rx_buf_size - read_position;
    if (step > len)
      step = len;
    MemCpy(buf, tcp_sock->rx_buf + read_position, step);
    buf += step;
    len -= step;
    read_position = (read_position + step) % tcp_sock->rx_buf_size;
    read_total += step;
  }
  if (len > 0)
  {
    step = write_position - read_position;
    if (step > len)
      step = len;
    MemCpy(buf, tcp_sock->rx_buf + read_position, step);
    buf += step;
    len -= step;
    read_position += step;
    read_total += step;
  }
  tcp_sock->read_position = read_position;
  threshold = MinI64(tcp_sock->rx_buf_size / 2, tcp_sock->max_segment_size);
  if (TCPRxWindow(tcp_sock) - tcp_sock->rx_window >= threshold &&
        IsTCPStateSync(tcp_sock))
  {
    if (tcp_sock->rx_drops)
    {
      NetWarn("TCP SOCKET RECEIVE: %d octets were dropped while the receive buffer was full.",
            tcp_sock->rx_drops);
      tcp_sock->rx_drops = 0;
    }
    TCPSendFlags(tcp_sock, TCPF_ACK);
  }
  return read_total;
}

I64 TCPSockRxLine(CTCPSock *tcp_sock, U8 *buf, I64 size)
{
  I64 received = 0;
  while (received + 1 < size)
  {
    if (TCPSockRx(tcp_sock, buf + received, 1) <= 0)
    {
      NetErr("TCP SOCKET RECEIVE LINE: Failed at TCPSockRx.");
      return -1;
    }
    if (buf[received] == '\n')
      break;
    else if (buf[received] != '\r')
      received++;
  }
  buf[received] = 0;
  return received;
}

I64 TCPSockSend(CTCPSock *tcp_sock, U8 *buf, I64 len)
{
  I64 sent_total = 0;
  I64 timeout = cnts.jiffies + tcp_sock->timeout * JIFFY_FREQ / 1000;
  I64 send_len;
  if (!SockSend(tcp_sock->sock))
  {
    NetErr("TCP SOCKET SEND: Failed, Socket state-machine must be in OPEN state.");
    return -1;
  }
  while ((tcp_sock->state == TCP_STATE_ESTABLISHED || tcp_sock->state == TCP_STATE_CLOSE_WAIT) &&
         len)
  {
    send_len = (tcp_sock->first_unacked_seq + tcp_sock->send_window - tcp_sock->next_send_seq_num) & 0xFFFFFFFF;
    if (send_len == 0)
    {
      if (sent_total > 0)
        break;
      else
      {
        TCPCheckACKQue(tcp_sock);
        Sleep(1);
      }
    }
    else
    {
      if (send_len > len)
        send_len = len;
      if (send_len > tcp_sock->max_segment_size)
        send_len = tcp_sock->max_segment_size;
      NetDbg("TCP SOCKET SEND: Trying TCPSendData() of %d bytes.", send_len);
      if (TCPSendData(tcp_sock, TCPF_ACK, buf, send_len) < 0)
      {
        if (sent_total > 0)
          break;
        else
        {
          TCPCheckACKQue(tcp_sock);
          Sleep(1);
        }
      }
      else
      {
        buf      += send_len;
        len      -= send_len;
        sent_total  += send_len;
        Yield;
      }
    }
    if (cnts.jiffies > timeout)
    {
      if (tcp_sock->timeout != 0)
        NetErr("TCP SOCKET SEND: Timed out.");
      break;
    }
  }
  return sent_total;
}

I64 TCPSockSendAll(CTCPSock *tcp_sock, U8 *buf, I64 len)
{
  I64 total = 0;
  I64 sent  = 0;
  while (len)
  {
    sent = TCPSockSend(tcp_sock, buf, len);
    if (sent > 0)
    {
      buf    += sent;
      total += sent;
      len    -= sent;
    }
    else
      break;
  }
  return total;
}

I64 TCPSockSendStr(CTCPSock *tcp_sock, U8 *str)
{
  return TCPSockSendAll(tcp_sock, str, StrLen(str));
}

CTCPSock *TCPConnectionCreate(U8 *hostname, U16 port)
{
  CSockAddrIPV4     sock_addr;
  CAddrInfo      *current;
  CAddrInfo      *info = NULL;
  I64                    error = DNSAddrInfoGet(hostname, NULL, &info);
  CTCPSock            *result;
  if (error < 0)
  {
    NetErr("TCP CONNECTION CREATE: Failed at DNSAddressInfoGet.");
    AddrInfoFree(info);
    return NULL;
  }
  sock_addr.family = AF_INET;
  sock_addr.port = EndianU16(port);
  sock_addr.addr.addr = INADDR_ANY;
  current = info;
  while (current)
  {
    if (current->family == AF_INET && (current->sock_type == 0 || current->sock_type == SOCK_STREAM))
    {
      sock_addr.addr.addr = EndianU32(current->addr(CSockAddrIPV4 *)->addr.addr);
      AddrInfoFree(info);
      result = TCPSock(AF_INET);
      if (!result)
      {
        NetErr("TCP CONNECTION CREATE: Failed to create new TCP Socket.");
        return NULL;
      }
      result->timeout = TCP_TIMEOUT * 3;
      error = TCPSockConnect(result, &sock_addr);
      if (error < 0)
      {
        NetErr("TCP CONNECTION CREATE: Failed to connect TCP Socket to address.");
        TCPSockClose(result);
        return error;
      }
      return result;
    }
    current = current->next;
  }
  NetErr("TCP CONNECTION CREATE: Failed to find a suitable address.");
  AddrInfoFree(info);
  return NULL;
}

U0 TCPTreeNodeRep(CTCPTreeNode *node)
{
  CTCPTreeQue       *queue = node->queue->next;
  CTCPSock            *sock;
  CSockAddrIPV4    *ipv4_addr;
  CSockAddrIPV6    *ipv6_addr;
  U8                    *str;
  CTCPAcceptQue     *pending;
  "Local Port $$YELLOW$$%d$$FG$$ (TCP Node @ $$CYAN$$0x%X$$FG$$):\n"
  , node->value, node;
  while (queue != node->queue)
  {
    sock = queue->sock;
    switch (sock->dst_addr.family)
    {
    case AF_UNSPEC:
      break;
    case AF_INET:
      ipv4_addr = &sock->dst_addr;
      str = MStrPrint("%d.%d.%d.%d",
                         ipv4_addr->addr.addr.u8[3],
                         ipv4_addr->addr.addr.u8[2],
                         ipv4_addr->addr.addr.u8[1],
                         ipv4_addr->addr.addr.u8[0]);
      " $$BROWN$$%s$$FG$$ Destination Port $$YELLOW$$%d$$FG$$ (TCP Tree Que @ $$CYAN$$0x%X$$FG$$):\n"
      ,
      str, EndianU16(ipv4_addr->port), queue;
      Free(str);
      break;
    case AF_INET6:
      ipv6_addr = &sock->dst_addr;
      break;
    default:
      break;
    }
    "       Timeout: %dms\n", sock->timeout;
    pending = sock->accept_queue->next;
    while (pending != sock->accept_queue->next)
    {
      "     Pending connection from $$BROWN$$%d.%d.%d.%d$$FG$$:",
      pending->ipv4_addr.u8[3],
      pending->ipv4_addr.u8[2],
      pending->ipv4_addr.u8[1],
      pending->ipv4_addr.u8[0];
      pending = pending->next;
    }
    queue = queue->next;
  }
  "\n";
}

U0 TCPRep()
{
  CTCPTreeNode  *node = tcp_globals.bound_sock_tree;
  CTCPRepEnt  *head;
  CTCPRepEnt  *ent;
  CTCPRepEnt  *temp_ent;
  "$$LTBLUE$$TCP Report:$$FG$$\n\n";
  if (node)
  {
    head = CAlloc(sizeof(CTCPRepEnt));
    QueInit(head);
    ent = CAlloc(sizeof(CTCPRepEnt));
    ent->node = node;
    QueIns(ent, head);
    while (ent != head)
    {
      if (ent->node->left)
      {
        temp_ent = CAlloc(sizeof(CTCPRepEnt));
        temp_ent->node = ent->node->left;
        QueInsRev(temp_ent, head);
        if (!ent->node->right)
        {
          QueRem(ent);
          TCPTreeNodeRep(ent->node);
          Free(ent);
        }
        ent = temp_ent;
      }
      else if (ent->node->right)
      {
        temp_ent = CAlloc(sizeof(CTCPRepEnt));
        temp_ent->node = ent->node->right;
        QueInsRev(temp_ent, head);
        QueRem(ent);
        TCPTreeNodeRep(ent->node);
        Free(ent);
        ent = temp_ent;
      }
      else
      {
        QueRem(ent);
        TCPTreeNodeRep(ent->node);
        Free(ent);
        if (head->last != head)
        {
          temp_ent = head->last;
          if (temp_ent->node->right)
          {
            ent = temp_ent;
            temp_ent = CAlloc(sizeof(CTCPRepEnt));
            temp_ent->node = ent->node->right;
            QueInsRev(temp_ent, head);
            QueRem(ent);
            TCPTreeNodeRep(ent->node);
            Free(ent);
            ent = temp_ent;
          }
          else
          {
            QueRem(temp_ent);
            TCPTreeNodeRep(temp_ent->node);
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
    "No TCP Sockets currently bound.\n\n";
}


TCPGlblsInit;
