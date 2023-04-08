I64 Ping(U8 *hostname, I64 timeout=JIFFY_FREQ)
{
  U32                    addr;
  CAddressInfo      *current;
  CAddressInfo      *result = NULL;
  I64                    error;
  I64                    i = 0, t, delay, sent = 0, min_delay = I64_MAX, max_delay = I64_MIN, sum_delay = 0;
  CSocketAddressIPV4    *ipv4_address;
  U16                    sequence_number = 1, identifier = RandU16, cnt = 0;
  U8                    *payload;
  if (!IPV4AddressPrs(hostname, &addr))
  {
    error = DNSAddressInfoGet(hostname, NULL, &result);
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
        ipv4_address = current->address;
        addr = EndianU32(ipv4_address->address); // why does it need EndianU32
        break;
      }
      current = current->next;
    }
  }
  if (!current)
  {
    NetErr("Ping: Failed to resolve address.");
    return -1;
  }
  "\n";
  while (!ScanChar)
  {
    payload = MAlloc(64);
    for (i = 0; i < 64; i++)
      payload[i] = RandU16;
    "Sending Ping request #%d\n"
    , sequence_number;
    ICMPRequestSend(addr, identifier, EndianU16(sequence_number), payload, 64);
    sent++;
    t = cnts.jiffies;
    while (cnts.jiffies < t + timeout)
    {
      if (icmp_reply.identifier == identifier && icmp_reply.sequence_number == EndianU16(sequence_number))
      {
        delay = cnts.jiffies - t;
        min_delay = MinI64(min_delay, delay);
        max_delay = MaxI64(max_delay, delay);
        sum_delay += delay; // sum up delays, divide through by cnt during stat report to get average
        cnt++;
        "\tReceived reply, delay: %dms\n"
        , delay;
        break;
      }
      Sleep(1);
    }
    while (cnts.jiffies < t + JIFFY_FREQ)
      Sleep(1);
    sequence_number++;
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
