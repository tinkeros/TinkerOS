class CEthFrame
{
  U8 src_addr[6];
  U8 padding[2];
  U8 dst_addr[6];
  U16 ethertype;

  U8 *data;

  I64 len;
};

class CEthGlbls
{
  U8 eth_null[6];
  U8 eth_broadcast[6];
} eth_globals;


U0 EthGlblsInit()
{
  I64 i;
  for (i = 0; i < 6; i++)
  {
    eth_globals.eth_null[i] = 0;
    eth_globals.eth_broadcast[i] = 0xFF;
  }
}

I64 EthFramePrs(CEthFrame *frame_out, U8 *frame, U16 len)
{//length must NOT include the FCS: PCNet strips it before NetQuePush.
  //Shrine also says MemCpy has a
  //high overhead. Almost tempted to say that means that a lot
  //of the current adam should be done with less extra allocation
  //altogether, more passing.
  //In practice, MemCpy causes the most slowdown on bare-metal.
  if (len < ETH_MAC_HDR_LEN)
    return -1;
  MemCpy(frame_out->dst_addr, frame, MAC_ADDR_LEN);
  MemCpy(frame_out->src_addr, frame + MAC_ADDR_LEN, MAC_ADDR_LEN);
  frame_out->ethertype = frame[ETH_ETHERTYPE_OFFSET + 1] |
      frame[ETH_ETHERTYPE_OFFSET] << 8;
  frame_out->data = frame + ETH_DATA_OFFSET;
  frame_out->len = len - ETH_MAC_HDR_LEN;
  return 0;
}

EthGlblsInit;
