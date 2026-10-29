U0 PCNetTest()
{
  U8 *pkt_buf;
  I64 de_index;
  while (TRUE)
  {
    de_index = PCNetTxPktAlloc(&pkt_buf, 8);
    *(pkt_buf(U64 *)) = EndianU64(0xDEADBEEFC0DEFADE);
    PCNetTxPktFinish(de_index);
    Sleep(300);
  }
}

PCNetTest;
