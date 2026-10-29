/*
    VirtIO Net driver ported from alec's Erythros.
*/

//
// PCI virtio I/O registers.
//

#define VIRTIO_PCI_HOST_FEATURES 0
#define VIRTIO_PCI_GUEST_FEATURES 4
#define VIRTIO_PCI_QUEUE_PFN 8
#define VIRTIO_PCI_QUEUE_SIZE 12
#define VIRTIO_PCI_QUEUE_SEL 14
#define VIRTIO_PCI_QUEUE_NOTIFY 16
#define VIRTIO_PCI_STATUS 18
#define VIRTIO_PCI_ISR 19
#define VIRTIO_PCI_CONFIG 20

//
// PCI virtio status register bits
//

#define VIRTIO_CONFIG_S_ACKNOWLEDGE 1
#define VIRTIO_CONFIG_S_DRIVER 2
#define VIRTIO_CONFIG_S_DRIVER_OK 4
#define VIRTIO_CONFIG_S_FAILED 0x80

//
// Ring descriptor flags
//

#define VRING_DESC_F_NEXT 1
#define VRING_DESC_F_WRITE 2
#define VRING_DESC_F_INDIRECT 4

class @virtio_queue_buf
{
  U64 addr;
  U32 len;
  U16 flags;
  U16 next;
};
class @virtio_avail
{
  U16 flags;
  U16 index;
  U16 ring[256];
  U16 int_index;
};
class @virtio_used_item
{
  U32 index;
  U32 len;
};
class @virtio_used
{
  U16 flags;
  U16 index;
  @virtio_used_item ring[256];
  U16 int_index;
};
class @virtio_queue
{
  @virtio_queue_buf bufs[256];
  @virtio_avail available;
  U8 padding[3578];
  @virtio_used used;
};

class @virtio_avail_buf
{
  U32 index;
  U64 addr;
  U32 len;
};

class @virtio_buf_info
{
  U8 *buf;
  U64 size;
  U8 flags;

  // If the user wants to keep same buffer as passed in this struct, use "true".
  // otherwise, the supplied buffer will be copied in the queues' buffer
  Bool copy;
};

"virtio ";

//
// PCI VirtIO Net
//

I64 rx_buf_ptr = 0;
I64 tx_buf_ptr = 0;
I64 rx_buf_cnt = 255;
I64 tx_buf_cnt = 256;
U64 rx_bufs = MAlloc(ETH_FRAME_SIZE * rx_buf_cnt, sys_dma_heap);
U64 tx_bufs = MAlloc(ETH_FRAME_SIZE * tx_buf_cnt, sys_dma_heap);

class @virtio_net
{
  U16 port;
  U8 mac[6];
  @virtio_queue *rq;
  @virtio_queue *sq;
  I64 rq_size;
  I64 rq_index;
  I64 sq_size;
  I64 sq_index;
  I64 rx_pkts;
  I64 rx_bytes;
  I64 tx_pkts;
  I64 tx_bytes;
};

class @virtio_net_hdr
{
  U8 flags;
  U8 gso_type;
  U16 hdr_len;
  U16 gso_size;
  U16 checksum_start;
  U16 checksum_offset;
};

@virtio_net VirtioNet;
ZeroClass(&VirtioNet);

@virtio_net_hdr *def_pkt_hdr = CAlloc(sizeof(@virtio_net_hdr), sys_dma_heap);

static I64 @virtio_net_alloc_tx_pkt(U8 **buf_out, I64 len/*, I64 flags*/)
{// FIXME: validate length
//  flags = flags;
  I64 sq_idx = VirtioNet.sq->available.index % 256;
  I64 sq_idx2 = sq_idx % 128;
  I64 index = tx_buf_ptr;
  tx_buf_ptr = (tx_buf_ptr + 1) & (tx_buf_cnt - 1);
  *buf_out = tx_bufs + index * ETH_FRAME_SIZE;
  VirtioNet.sq->bufs[sq_idx2 * 2].addr = def_pkt_hdr;
  VirtioNet.sq->bufs[sq_idx2 * 2].len = sizeof(@virtio_net_hdr);
  VirtioNet.sq->bufs[sq_idx2 * 2].flags = VRING_DESC_F_NEXT;
  VirtioNet.sq->bufs[sq_idx2 * 2].next = (sq_idx2 * 2) + 1;
  VirtioNet.sq->bufs[(sq_idx2 * 2) + 1].addr = *buf_out;
  VirtioNet.sq->bufs[(sq_idx2 * 2) + 1].len = len;
  VirtioNet.sq->bufs[(sq_idx2 * 2) + 1].flags = NULL;
  VirtioNet.sq->bufs[(sq_idx2 * 2) + 1].next = 0;
  VirtioNet.sq->available.ring[sq_idx] = sq_idx2 * 2;
  VirtioNet.sq->available.index++;
  VirtioNet.tx_pkts++;
  VirtioNet.tx_bytes += len;
  return index;
}

static I64 @virtio_net_finish_tx_pkt(I64)
{
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_NOTIFY, 1);
  return 0;
}

U8 *loopback_frame = MAlloc(ETH_FRAME_SIZE);
I64 loopback_len = 0;

I64 EthFrameAlloc(U8 **buf_out, U8 *src_addr, U8 *dst_addr,
                          U16 ethertype, I64 len/*, I64 flags*/)
{
  U8 *frame;
  if (len < 46)
    len = 46;
  I64 index;
  if (!MemCmp(dst_addr, &VirtioNet.mac, 6))
  {
    frame = loopback_frame;
    loopback_len = len;
    index = I64_MAX;
  }
  else
  {
    index = @virtio_net_alloc_tx_pkt(&frame, 14 + len/*, flags*/);
    if (index < 0)
      return index;
  }
  *buf_out = EthHdrSet(frame, src_addr, dst_addr, ethertype);
  return index;
}

I64 EthFrameFinish(I64 index)
{
  if (index == I64_MAX && loopback_frame && loopback_len)
  {
    NetQuePush(loopback_frame, loopback_len);
    loopback_len = 0;
    return 0;
  }
  return @virtio_net_finish_tx_pkt(index);
}

U8 *EthMACGet()
{
  return &VirtioNet.mac;
}

I64 @virtio_net_init()
{
  I64 i, j;
  j = PCIClassFind(0x020000, 0);
  if (j < 0)
  {
    "\nVirtio-net device not found.\n";
    return -1;
  }
  VirtioNet.port = PCIReadU32(j.u8[2], j.u8[1], j.u8[0], 0x10) & 0xFFFFFFFC;
  for (i = 0; i < 6; i++)
  {
    VirtioNet.mac[i] = InU8(VirtioNet.port + VIRTIO_PCI_CONFIG + i);
  }
  OutU8(VirtioNet.port + VIRTIO_PCI_STATUS, 0);
  OutU8(VirtioNet.port + VIRTIO_PCI_STATUS,
        InU8(VirtioNet.port + VIRTIO_PCI_STATUS) | VIRTIO_CONFIG_S_ACKNOWLEDGE |
        VIRTIO_CONFIG_S_DRIVER);
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SEL, 0);
  VirtioNet.rq_size = InU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SIZE);
  VirtioNet.rq = CAllocAligned(sizeof(@virtio_queue), 4096, sys_dma_heap);
  OutU32(VirtioNet.port + VIRTIO_PCI_QUEUE_PFN, VirtioNet.rq / 4096);
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SEL, 1);
  VirtioNet.sq_size = InU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SIZE);
  VirtioNet.sq = CAllocAligned(sizeof(@virtio_queue), 4096, sys_dma_heap);
  OutU32(VirtioNet.port + VIRTIO_PCI_QUEUE_PFN, VirtioNet.sq / 4096);
  for (i = 0; i < 128; i++)
  {
    VirtioNet.rq->bufs[i * 2].addr = CAlloc(sizeof(@virtio_net_hdr), sys_dma_heap);
    VirtioNet.rq->bufs[i * 2].len = sizeof(@virtio_net_hdr);
    VirtioNet.rq->bufs[i * 2].flags = VRING_DESC_F_NEXT | VRING_DESC_F_WRITE;
    VirtioNet.rq->bufs[i * 2].next = (i * 2) + 1;
    VirtioNet.rq->bufs[(i * 2) + 1].addr = CAlloc(ETH_FRAME_SIZE, sys_dma_heap);
    VirtioNet.rq->bufs[(i * 2) + 1].len = ETH_FRAME_SIZE;
    VirtioNet.rq->bufs[(i * 2) + 1].flags = VRING_DESC_F_WRITE;
    VirtioNet.rq->bufs[(i * 2) + 1].next = 0;
    VirtioNet.rq->available.ring[i] = i * 2;
    VirtioNet.rq->available.ring[i + 128] = i * 2;
  }
  VirtioNet.rq->available.index = 1;
  OutU8(VirtioNet.port + VIRTIO_PCI_STATUS,
        InU8(VirtioNet.port + VIRTIO_PCI_STATUS) | VIRTIO_CONFIG_S_DRIVER_OK);
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);
  "\x1b[33mVirtio-net device detected, MAC address "
  "%02x:%02x:%02x:%02x:%02x:%02x\x1b[0m\n"
  ,
  VirtioNet.mac[0], VirtioNet.mac[1], VirtioNet.mac[2], VirtioNet.mac[3],
  VirtioNet.mac[4], VirtioNet.mac[5];
}

"virtio-net ";
@virtio_net_init;

/*
U0 @virtio_net_handle_net_fifo_ent(CNetFifoEntry *e) {
  CEthFrame l2_frame;

  if (EthFramePrs(&l2_frame, e->frame, e->length) < 0)
    return;

  CL3Protocol *l3 = l3_protocols;

  while (l3) {
    if (l3->ethertype == l2_frame.ethertype) {
      l3->hndlr(&l2_frame);
      break;
    }
    l3 = l3->next;
  }
}
*/
U0 @virtio_net_hndlr_task()
{
  I64 idx_used, idx_rec;
  I64 i, j;
  @virtio_used_item *item;
  U8 *buf;
  I64 len;
  while (1)
  {
    idx_rec = VirtioNet.rq_index;
    idx_used = VirtioNet.rq->used.index;
    if (idx_used < idx_rec)
    {
      idx_used += 0x10000;
    }
    if (idx_rec != idx_used && idx_used)
    {
      j = 0;
      for (i = idx_rec; i < idx_used; i++)
      {
        item = VirtioNet.rq->used.ring;
        buf = VirtioNet.rq->bufs[item[i % 256].index + 1];
        len = item[i % 256].len;
        NetQuePush(buf, len - 10);
        j++;
        VirtioNet.rx_pkts++;
        VirtioNet.rx_bytes += len - 10;
      }
      VirtioNet.rq_index = idx_used % 0x10000;
      VirtioNet.rq->available.index += j;
      OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);
    }
    Sleep(1);
  }
}

if (mp_cnt>1)
  Spawn(&@virtio_net_hndlr_task,, "Virtio-net",1);
else
  Spawn(&@virtio_net_hndlr_task,, "Virtio-net");

