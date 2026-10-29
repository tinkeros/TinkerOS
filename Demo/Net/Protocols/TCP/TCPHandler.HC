Bool TCPHandleValidSEQ(CTCPSock *tcp_sock, CTCPHdr *hdr, U32 segment_seq_num, I64 len, U8 *data)
{// returns the value of must_ack, used later in TCPHandleSock. Copies data to receive buffer.
  Bool must_ack = FALSE;
  I64  mask, seq_offset;
  I64  write_position;
  I64  next_position;
  I64  i = 0;
  U32  fin_seq;
  tcp_sock->send_window = EndianU16(hdr->window_size);
  switch (tcp_sock->state)
  {
  case TCP_STATE_ESTABLISHED:
  case TCP_STATE_FIN_WAIT1:
  case TCP_STATE_FIN_WAIT2:
  case TCP_STATE_CLOSE_WAIT:
    NetDbg("TCP HANDLE VALID SEQ: Updating data in receive buffer.");
    mask = tcp_sock->rx_buf_size - 1;
    write_position = tcp_sock->write_position;
    fin_seq = (segment_seq_num + len) & 0xFFFFFFFF;
    seq_offset = (tcp_sock->next_recv_seq_num - segment_seq_num) & 0xFFFFFFFF;
    if (seq_offset >= 0x80000000)
    {
      len = 0;
      must_ack = TRUE;
    }
    else if (seq_offset >= len)
    {
      if (seq_offset)
        must_ack = TRUE;
      len = 0;
    }
    else
    {
      data += seq_offset;
      len -= seq_offset;
    }
    for (i = 0; i < len; i++)
    {
      next_position = (write_position + 1) & mask;
      if (next_position == tcp_sock->read_position)
        break;
      tcp_sock->rx_buf[write_position] = data[i];
      write_position = next_position;
    }
    if (i < len)
    {
      if (!tcp_sock->rx_drops)
        NetWarn("TCP HANDLE VALID SEQ: Receive buffer full, dropping %d of %d octets.",
              len - i, len);
      tcp_sock->rx_drops += len - i;
    }
    tcp_sock->write_position = write_position;
    tcp_sock->next_recv_seq_num += i;
    if (i > 0)
      must_ack = TRUE;
    if (hdr->fin && tcp_sock->next_recv_seq_num == fin_seq)
    {
      must_ack = TRUE;
      tcp_sock->next_recv_seq_num++;
      switch (tcp_sock->state)
      {
      case TCP_STATE_ESTABLISHED:
        tcp_sock->state = TCP_STATE_CLOSE_WAIT;
        break;
      case TCP_STATE_FIN_WAIT1:
      case TCP_STATE_FIN_WAIT2:
        tcp_sock->state = TCP_STATE_TIME_WAIT;
        break;
      }
    }
    break;
  default:
    break;
  }
  return must_ack;
}


Bool TCPHandleACK(CTCPSock *tcp_sock, CIPV4Pkt *pkt, CTCPHdr *hdr,
                  U32 segment_seq_num, U32 segment_ack_num, U32 segment_len)
{// returns the value of must_ack, used later in TCPHandleSock
  I64  ack_relative;
  I64  ack_next_relative;
  if (hdr->ack)
  {
    ack_relative = (segment_ack_num - tcp_sock->first_unacked_seq) & 0xFFFFFFFF;
    ack_next_relative = (tcp_sock->next_send_seq_num - tcp_sock->first_unacked_seq) & 0xFFFFFFFF;
    if (ack_relative <= ack_next_relative)
    {
      TCPAcknowledgePkt(tcp_sock, segment_ack_num);
      tcp_sock->first_unacked_seq = segment_ack_num;
      switch (tcp_sock->state)
      {
      case TCP_STATE_SYN_SENT:
        NetDbg("TCP HANDLE ACK: Acceptable ACK; state: SYN_SENT");
        if (!hdr->syn)
          break;
      case TCP_STATE_SYN_RECEIVED:
        tcp_sock->state = TCP_STATE_ESTABLISHED;
        tcp_sock->srtt  = tS - tcp_sock->connection_time;
        break;
      default:
        break;
      }
      NetDbg("TCP HANDLE ACK: Acceptable ACK returning; state: 0x%0X", tcp_sock->state);
    }
    else
    {
      NetWarn("TCP HANDLE SOCKET: Invalid ACK.");
      switch (tcp_sock->state)
      {
      case TCP_STATE_LISTEN:
      case TCP_STATE_SYN_SENT:
      case TCP_STATE_SYN_RECEIVED:
        TCPSend(pkt->dst_ip_addr,
                EndianU16(hdr->dst_port),
                pkt->src_ip_addr,
                EndianU16(hdr->src_port),
                segment_ack_num,
                segment_seq_num + segment_len,
                TCPF_ACK | TCPF_RST);
        break;
      default:
        if (IsTCPStateSync(tcp_sock))
          return TRUE;
        break;
      }
    }
  }
  return FALSE;
}

Bool TCPHandleRst(CTCPSock *tcp_sock, CTCPHdr *hdr, Bool is_seq_valid)
{// returns whether or not to stop overall TCP procedure.
  if (hdr->rst)
  {
    switch (tcp_sock->state)
    {
    case TCP_STATE_SYN_SENT:
      if (tcp_sock->first_unacked_seq == tcp_sock->next_send_seq_num)
      {
        NetWarn("TCP HANDLE SOCKET: Got RST, socket state SYN_SENT. Connection refused.");
        tcp_sock->state = TCP_STATE_CLOSED;
        return TRUE;
      }
      break;
    default:
      if (is_seq_valid)
      {
        NetWarn("TCP HANDLE SOCKET: Got RST, connection refused by remote host.");
        tcp_sock->state = TCP_STATE_CLOSED;
        return TRUE;
      }
    }
  }
  return FALSE;
}

U0 TCPHandleSockLsten(CTCPSock *tcp_sock, CIPV4Pkt *pkt, CTCPHdr *hdr, U32 segment_seq_num)
{// if SYN and socket listening, queue up the connection in the socket's accept queue.
  CTCPAcceptQue *new_connection;
  if (hdr->syn && QueSize(tcp_sock->accept_queue) < tcp_sock->accept_queue_limit)
  {
    NetDbg("TCP HANDLE SOCKET LISTEN: Adding new connection to Socket accept queue");
    new_connection = CAlloc(sizeof(CTCPAcceptQue), adam_task);
    new_connection->segment_seq_num = segment_seq_num;
    new_connection->ipv4_addr    = pkt->src_ip_addr;
    new_connection->port            = hdr->src_port;
    QueInsRev(new_connection, tcp_sock->accept_queue);
  }
  else
  {
    NetDbg("TCP HANDLE SOCKET LISTEN: Header flags not SYN or Que full, REFUSING CONNECTION");
    TCPSend(pkt->dst_ip_addr,
            EndianU16(hdr->dst_port),
            pkt->src_ip_addr,
            EndianU16(hdr->src_port),
            segment_seq_num + 1,
            segment_seq_num + 1,
            TCPF_ACK | TCPF_RST);
  }
}

U0 TCPHandleSock(CTCPSock *tcp_sock, CIPV4Pkt *pkt, CTCPHdr *hdr, U8 *data, I64 len)
{
  U32  segment_len       = len;
  U32  segment_seq_num  = EndianU32(hdr->seq_num);
  U32  segment_ack_num  = EndianU32(hdr->ack_num);
  Bool must_ack         = FALSE;
  Bool is_seq_valid     = FALSE;
  I64  seq_relative;
  I64  seq_end_relative;
  if (hdr->fin)
    segment_len++;
  if (hdr->syn)
    segment_len++;
  switch (tcp_sock->state)
  {
  case TCP_STATE_LISTEN:
    NetDbg("TCP HANDLE SOCKET: Running TCP HANDLE SOCKET LISTEN");
    TCPHandleSockLsten(tcp_sock, pkt, hdr, segment_seq_num);
    return;
  case TCP_STATE_CLOSED:
    NetErr("TCP HANDLE SOCKET: Received packet but TCP Socket is CLOSED.");
    return;
  default:
    if (hdr->syn)
    {
      tcp_sock->next_recv_seq_num = ++segment_seq_num;
      must_ack = TRUE;
    }
    if (segment_len == 0 && tcp_sock->rx_window == 0)
    {
      NetDbg("TCP HANDLE SOCKET: segment length == 0 && receive window == 0, SEQ valid if seq == next recv seq");
      is_seq_valid = (segment_seq_num == tcp_sock->next_recv_seq_num);
    }
    else
    {
      seq_relative = (segment_seq_num - tcp_sock->next_recv_seq_num) & 0xFFFFFFFF;
      seq_end_relative = (segment_seq_num + segment_len - 1 - tcp_sock->next_recv_seq_num) & 0xFFFFFFFF;
      is_seq_valid = (seq_relative < tcp_sock->rx_window ||
                      seq_end_relative < tcp_sock->rx_window);
    }
    if (!is_seq_valid)
      NetWarn("TCP HANDLE SOCKET: Invalid SEQ.");
    must_ack |= TCPHandleACK(tcp_sock, pkt, hdr, segment_seq_num, segment_ack_num, segment_len);
    if (TCPHandleRst(tcp_sock, hdr, is_seq_valid))
      return;
    if (is_seq_valid)
      must_ack |= TCPHandleValidSEQ(tcp_sock, hdr, segment_seq_num, len, data);
    else if (!hdr->rst && IsTCPStateSync(tcp_sock))
      must_ack = TRUE;
    if (must_ack)
      TCPSendFlags(tcp_sock, TCPF_ACK);
  }
}

I64 TCPHandleRefuse(CIPV4Pkt *pkt, CTCPHdr *hdr, I64 len)
{
  I64 de_index;
  U32 ack_num = EndianU32(hdr->ack_num);
  U32 seq_num = EndianU32(hdr->seq_num);
  no_warn len;
  ack_num = ++seq_num;
  seq_num = 0;
  if (hdr->rst)
    return 0;
  de_index = TCPSend(pkt->dst_ip_addr,
                     EndianU16(hdr->dst_port),
                     pkt->src_ip_addr,
                     EndianU16(hdr->src_port),
                     seq_num,
                     ack_num,
                     TCPF_RST | TCPF_ACK);
  if (de_index < 0)
  {
    NetErr("TCP Handler Refuse: TCP Send failed.");
    return de_index;
  }
  return 0;
}

I64 TCPHandler(CIPV4Pkt *pkt)
{
  CTCPHdr        *hdr;
  U16                dst_port;
  U8                *data;
  I64                len;
  CTCPTreeNode  *head, *node = NULL;
  CTCPTreeQue   *queue = NULL;
  CTCPSock        *tcp_sock = NULL;
  I64                error = TCPPktPrs(&hdr, &data, &len, pkt);
  if (error < 0)
  {
    NetErr("TCP HANDLER: Packet Prs Error.");
    return error;
  }
  NetDbg("TCP HANDLER: Caught packet with dest port of %0X (B.E.)", hdr->dst_port);
  dst_port = EndianU16(hdr->dst_port);
  NetDbg("TCP HANDLER: Caught packet with dest port of %0X (L.E.)", dst_port);
  PUSHFD
  CLI
  while (LBts(&tcp_bound_tree_lock, 0))
    PAUSE
  head = tcp_globals.bound_sock_tree;
  if (head && (node = TCPTreeNodeFind(dst_port, head)))
    queue = TCPTreeNodeQueIPV4Find(pkt->src_ip_addr, node);
  if (queue)
  {
    tcp_sock = queue->sock;
    tcp_sock->handler_refs++;
  }
  LBtr(&tcp_bound_tree_lock, 0);
  POPFD
  if (head)
  {
    if (node)
    {
      if (tcp_sock)
        NetLog("TCP HANDLER: Port and Address are in bound tree.");
      else
      {
        NetWarn("TCP HANDLER: Found node for port, but address is not in node queue.");
        NetWarn("             TCP source ip: 0x%0X.", pkt->src_ip_addr);
        NetWarn("TCP HANDLER: Sending TCP RST ACK packet. Refusing connection.");
        TCPHandleRefuse(pkt, hdr, len);
        return -1;
      }
    }
    else
    {
      NetDbg("TCP HANDLER: NODE SEARCH FAILURE: PORT %0X", dst_port);
      NetWarn("TCP HANDLER: Node for Port is not in tree.");
      NetWarn("TCP HANDLER: Sending TCP RST ACK packet. Refusing connection.");
      TCPHandleRefuse(pkt, hdr, len);
      return -1;
    }
  }
  else
  {
    NetWarn("TCP HANDLER: Socket tree is currently empty.");
    NetWarn("TCP HANDLER: Sending TCP RST ACK packet. Refusing connection.");
    TCPHandleRefuse(pkt, hdr, len);
    return -1;
  }
  NetDbg("TCP HANDLER: Running TCP HANDLE SOCKET");
  TCPHandleSock(tcp_sock, pkt, hdr, data, len);
  PUSHFD
  CLI
  while (LBts(&tcp_bound_tree_lock, 0))
    PAUSE
  tcp_sock->handler_refs--;
  LBtr(&tcp_bound_tree_lock, 0);
  POPFD
  return 0;
}
