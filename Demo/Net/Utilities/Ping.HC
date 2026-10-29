I64 Ping(U8 *hostname, I64 timeout=JIFFY_FREQ)
{
  U32                    addr;
  CAddrInfo      *current;
  CAddrInfo      *result = NULL;
  I64                    error;
  I64                    i = 0, t, delay, sent = 0, min_delay = I64_MAX, max_delay = I64_MIN, sum_delay = 0;
  CSockAddrIPV4    *ipv4_addr;
  U16                    seq_num = 1, id = RandU16, cnt = 0;
  U8                    *payload;
  if (!IPV4AddrPrs(hostname, &addr))
  {
    error = DNSAddrInfoGet(hostname, NULL, &result);
    if (error < 0)
    {
      NetErr("Ping: Failed at DNS Get Address Info.");
      return -1;
    }
    current = result;
    while (current)
    {
      if (current->family == AF_INET)
      {
        ipv4_addr = current->addr;
        addr = EndianU32(ipv4_addr->addr);
        break;
      }
      current = current->next;
    }
    if (!current)
    {
      NetErr("Ping: Failed to resolve address.");
      return -1;
    }
  }
  "\n";
  while (!ScanChar)
  {
    payload = MAlloc(64);
    for (i = 0; i < 64; i++)
      payload[i] = RandU16;
    "Sending Ping request #%d\n"
    , seq_num;
    ICMPReqSend(addr, id, EndianU16(seq_num), payload, 64);
    sent++;
    t = cnts.jiffies;
    while (cnts.jiffies < t + timeout)
    {
      if (icmp_reply.id == id && icmp_reply.seq_num == EndianU16(seq_num))
      {
        delay = cnts.jiffies - t;
        min_delay = MinI64(min_delay, delay);
        max_delay = MaxI64(max_delay, delay);
        sum_delay += delay;
        cnt++;
        "\tReceived reply, delay: %dms\n"
        , delay;
        break;
      }
      Sleep(1);
    }
    while (cnts.jiffies < t + JIFFY_FREQ)
      Sleep(1);
    seq_num++;
    Free(payload);
  }
  "\nPing Statistics:\n";
  "\tSent: %d, Received: %d, Lost: %d (%0.02f %%)\n"
  , sent, cnt, sent - cnt, 100.0 - 100.0 * cnt / sent;
  if (min_delay != I64_MAX && max_delay != I64_MIN && sum_delay != 0)
    "\tMin: %dms, Max: %dms, Avg: %dms\n", min_delay, max_delay, sum_delay / cnt;
  "\n";
  return cnt;
}
