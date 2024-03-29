/*
    VirtIO Net driver ported from alec's Erythros.
*/

//
// PCI virtio I/O registers.
//

#define VIRTIO_PCI_HOST_FEATURES 0  // Features supported by the host
#define VIRTIO_PCI_GUEST_FEATURES 4 // Features activated by the guest
#define VIRTIO_PCI_QUEUE_PFN 8      // PFN for the currently selected queue
#define VIRTIO_PCI_QUEUE_SIZE 12 // Que size for the currently selected queue
#define VIRTIO_PCI_QUEUE_SEL 14  // Que selector
#define VIRTIO_PCI_QUEUE_NOTIFY 16 // Que notifier
#define VIRTIO_PCI_STATUS 18       // Device status register
#define VIRTIO_PCI_ISR 19          // Interrupt status register
#define VIRTIO_PCI_CONFIG 20       // Cfguration data block

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

#define VRING_DESC_F_NEXT 1     // Buffer continues via the next field
#define VRING_DESC_F_WRITE 2    // Buffer is write-only (otherwise read-only)
#define VRING_DESC_F_INDIRECT 4 // Buffer contains a list of buffer descriptors

class @virtio_queue_buf
{
  U64 address;
  U32 length;
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
  U32 length;
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
  @virtio_queue_buf buffers[256];
  @virtio_avail available;
  U8 padding[3578];
  @virtio_used used;
};

class @virtio_avail_buf
{
  U32 index;
  U64 address;
  U32 length;
};

class @virtio_buf_info
{
  U8 *buffer;
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

I64 rx_buffer_ptr = 0;
I64 tx_buffer_ptr = 0;
I64 rx_buffer_cnt = 255;
I64 tx_buffer_cnt = 256;
U64 rx_buffers = MAlloc(ETHERNET_FRAME_SIZE * rx_buffer_cnt);
U64 tx_buffers = MAlloc(ETHERNET_FRAME_SIZE * tx_buffer_cnt);

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
  I64 rx_packets;
  I64 rx_bytes;
  I64 tx_packets;
  I64 tx_bytes;
};

class @virtio_net_header
{
  U8 flags;
  U8 gso_type;
  U16 header_length;
  U16 gso_size;
  U16 checksum_start;
  U16 checksum_offset;
};

@virtio_net VirtioNet;
MemSet(&VirtioNet, 0, sizeof(@virtio_net));

@virtio_net_header *def_pkt_hdr = CAlloc(sizeof(@virtio_net_header));

static I64 @virtio_net_alloc_tx_packet(U8 **buffer_out, I64 length/*, I64 flags*/)
{// FIXME: validate length
//  flags = flags;
  I64 sq_idx = VirtioNet.sq->available.index % 256;
  I64 sq_idx2 = sq_idx % 128;
  I64 index = tx_buffer_ptr;
  tx_buffer_ptr = (tx_buffer_ptr + 1) & (tx_buffer_cnt - 1);
  *buffer_out = tx_buffers + index * ETHERNET_FRAME_SIZE;
  VirtioNet.sq->buffers[sq_idx2 * 2].address = def_pkt_hdr;
  VirtioNet.sq->buffers[sq_idx2 * 2].length = sizeof(@virtio_net_header);
  VirtioNet.sq->buffers[sq_idx2 * 2].flags = VRING_DESC_F_NEXT;
  VirtioNet.sq->buffers[sq_idx2 * 2].next = (sq_idx2 * 2) + 1;
  VirtioNet.sq->buffers[(sq_idx2 * 2) + 1].address = *buffer_out;
  VirtioNet.sq->buffers[(sq_idx2 * 2) + 1].length = length;
  VirtioNet.sq->buffers[(sq_idx2 * 2) + 1].flags = NULL;
  VirtioNet.sq->buffers[(sq_idx2 * 2) + 1].next = 0;
  VirtioNet.sq->available.ring[sq_idx] = sq_idx2 * 2;
  VirtioNet.sq->available.index++;
  VirtioNet.tx_packets++;
  VirtioNet.tx_bytes += length;
  return index;
}

static I64 @virtio_net_finish_tx_packet(I64)
{
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_NOTIFY, 1);
  return 0;
}

U8 *loopback_frame = MAlloc(ETHERNET_FRAME_SIZE);
I64 loopback_length = 0;

I64 EthernetFrameAllocate(U8 **buffer_out, U8 *src_addr, U8 *dst_addr,
                          U16 ethertype, I64 length/*, I64 flags*/)
{
  U8 *frame;
  // APAD_XMT doesn't seem to work in VirtualBox, so we have to pad the frame
  // ourselves
  if (length < 46)
    length = 46;
  I64 index;
  if (!MemCmp(dst_addr, &VirtioNet.mac, 6))
  {
    frame = loopback_frame;
    loopback_length = length;
    index = I64_MAX;
  }
  else
  {
    index = @virtio_net_alloc_tx_packet(&frame, 14 + length/*, flags*/);
    if (index < 0)
      return index;
  }
  MemCpy(frame + 0, dst_addr, 6);
  MemCpy(frame + 6, src_addr, 6);
  frame[12] = (ethertype >> 8);
  frame[13] = (ethertype & 0xff);
  *buffer_out = frame + 14;
  return index;
}

I64 EthernetFrameFinish(I64 index)
{
  if (index == I64_MAX && loopback_frame && loopback_length)
  {
    NetQuePush(loopback_frame, loopback_length);
    loopback_length = 0;
    return 0;
  }
  return @virtio_net_finish_tx_packet(index);
}

U8 *EthernetMACGet()
{
  return &VirtioNet.mac;
}

I64 @virtio_net_init()
{
  I64 i, j;
  // Scan for device
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
  // Rst Device
  OutU8(VirtioNet.port + VIRTIO_PCI_STATUS, 0);
  // Found Driver
  OutU8(VirtioNet.port + VIRTIO_PCI_STATUS,
        InU8(VirtioNet.port + VIRTIO_PCI_STATUS) | VIRTIO_CONFIG_S_ACKNOWLEDGE |
        VIRTIO_CONFIG_S_DRIVER);
  // Set up receive queue
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SEL, 0);
  VirtioNet.rq_size = InU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SIZE); // 256
  VirtioNet.rq = CAllocAligned(sizeof(@virtio_queue), 4096, Fs->code_heap);
  OutU32(VirtioNet.port + VIRTIO_PCI_QUEUE_PFN, VirtioNet.rq / 4096);
  // Set up send queue
  OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SEL, 1);
  VirtioNet.sq_size = InU16(VirtioNet.port + VIRTIO_PCI_QUEUE_SIZE); // 256
  VirtioNet.sq = CAllocAligned(sizeof(@virtio_queue), 4096, Fs->code_heap);
  OutU32(VirtioNet.port + VIRTIO_PCI_QUEUE_PFN, VirtioNet.sq / 4096);
  for (i = 0; i < 128; i++)
  {
    VirtioNet.rq->buffers[i * 2].address = CAlloc(sizeof(@virtio_net_header));
    VirtioNet.rq->buffers[i * 2].length = sizeof(@virtio_net_header);
    VirtioNet.rq->buffers[i * 2].flags = VRING_DESC_F_NEXT | VRING_DESC_F_WRITE;
    VirtioNet.rq->buffers[i * 2].next = (i * 2) + 1;
    VirtioNet.rq->buffers[(i * 2) + 1].address = CAlloc(ETHERNET_FRAME_SIZE);
    VirtioNet.rq->buffers[(i * 2) + 1].length = ETHERNET_FRAME_SIZE;
    VirtioNet.rq->buffers[(i * 2) + 1].flags = VRING_DESC_F_WRITE;
    VirtioNet.rq->buffers[(i * 2) + 1].next = 0;
    VirtioNet.rq->available.ring[i] = i * 2;
    VirtioNet.rq->available.ring[i + 128] = i * 2;
  }
  VirtioNet.rq->available.index = 1;
  // Init OK
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
U0 @virtio_net_handle_net_fifo_entry(CNetFifoEntry *e) {
  CEthFrame l2_frame;

  if (EthernetFramePrs(&l2_frame, e->frame, e->length) < 0)
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
  U8 *buffer;
  I64 length;
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
        buffer = VirtioNet.rq->buffers[item[i % 256].index + 1];
        length = item[i % 256].length;
        NetQuePush(buffer, length - 10);
        j++;
        VirtioNet.rx_packets++;
        VirtioNet.rx_bytes += length - 10;
      }
      VirtioNet.rq_index = idx_used % 0x10000;
      VirtioNet.rq->available.index += j;
      OutU16(VirtioNet.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);
    }
    if (Gs->num)
      Sleep(10);
    else
      Sleep(30);
  }
}

if (mp_cnt>1)
  Spawn(&@virtio_net_hndlr_task,, "Virtio-net",1);
else
  Spawn(&@virtio_net_hndlr_task,, "Virtio-net");

