
U8 src[6] = {0xDE, 0xAD, 0xBE, 0xEF, 0xC0, 0xDE};
U8 dst[6] = {0xF0, 0x0D, 0xBE, 0xAD, 0xDE, 0xAF};

U0 EthTest()
{
  U8 *pkt_buf;
  I64 de_index;
  while (TRUE)
  {
    de_index = EthFrameAlloc(&pkt_buf, src, dst, 0x0000, 8);
    *(pkt_buf(U64 *)) = EndianU64(0xC0DEFADEDEADBEEF);
    EthFrameFinish(de_index);
    Sleep(300);
  }
}

EthTest;
