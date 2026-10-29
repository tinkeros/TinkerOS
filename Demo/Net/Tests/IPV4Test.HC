U8 dst_mac[6]={0xF0, 0x0D, 0xBE, 0xAD, 0xDE, 0xAF};

U32 src_ip = 0x30313233;
U32 dst_ip = 0x01020304;

U0 IPV4Test()
{
  U8 *ipv4_pkt_buf;
  I64 de_index;
  ARPCachePut(dst_ip,
      dst_mac);
  while (TRUE)
  {
    de_index = IPV4PktAlloc(&ipv4_pkt_buf, 0xFF, src_ip, dst_ip, 8);
    *(ipv4_pkt_buf(U64 *)) = EndianU64(0xBEEFDEADFADEC0DE);
    IPV4PktFinish(de_index);
    Sleep(300);
  }
}

IPV4Test;
