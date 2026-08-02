Cd(__DIR__);;
#include "VBoxLog"

// Uncomment to enable VirtualBox shared clipboard integration.
// The VM's clipboard mode must be set to Bidirectional.
//#define VBOX_CLIPBOARD_ENABLE

#define VBOX_VMMDEV_VERSION 0x00010003
#define VBOX_REQUEST_HEADER_VERSION 0x10001

#define VBOX_REQUEST_GUEST_INFO 50
#define VBOX_REQUEST_SET_GUEST_CAPS 55
#define VBOX_REQUEST_HGCM_CONNECT 60
#define VBOX_REQUEST_HGCM_DISCONNECT 61
#define VBOX_REQUEST_HGCM_CALL 62
#define VBOX_REQUEST_HGCM_CANCEL2 65

#define VBOX_REQUEST_GET_MOUSE 1
#define VBOX_REQUEST_SET_MOUSE 2

// HGCM calls are asynchronous.  The port write comes straight back with
// VINF_HGCM_ASYNC_EXECUTE in hdr.rc; only later does the host write
// VBOX_HGCM_REQ_DONE into hdr.flags (and the real status into hdr.result) by
// poking the request buffer directly.  Reading a reply before DONE is set --
// which is what a bare Sleep() amounts to -- gets you whatever was in the
// buffer beforehand, and rebuilding the buffer while the call is still out
// there gets you a reply landing on top of the next request.
#define VINF_HGCM_ASYNC_EXECUTE 2
#define VBOX_HGCM_REQ_DONE 1

// Parameter types.  Every parameter here is 32bit or LinAddr; note that for a
// 32bit parameter the host only writes back the low dword of value.
#define VBOX_HGCM_PARM_32BIT 1
#define VBOX_HGCM_PARM_LINADDR 4

#define VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT 1
#define VBOX_SHARED_CLIPBOARD_FMT_BITMAP 2

#define VBOX_SHARED_CLIPBOARD_FN_GET_HOST_MSG 1
#define VBOX_SHARED_CLIPBOARD_FN_FMTS 2
#define VBOX_SHARED_CLIPBOARD_FN_READ_DATA 3
#define VBOX_SHARED_CLIPBOARD_FN_WRITE_DATA 4

#define VBOX_SHARED_CLIPBOARD_HOST_MSG_QUIT 1
#define VBOX_SHARED_CLIPBOARD_HOST_MSG_READ_DATA 2
#define VBOX_SHARED_CLIPBOARD_HOST_MSG_FMTS 3

// Character counts, not byte counts.  Buffers are allocated one element
// larger than this so the NUL terminator always has somewhere to go.
#define HOST_CLIP_READ_MAX 32768
#define HOST_CLIP_WRITE_MAX 32768

#define MS_MSG_MS 12

// Budgets for waiting on VBOX_HGCM_REQ_DONE.  An X11 host servicing a read
// has to go negotiate a selection transfer with whichever app owns the
// clipboard, which is routinely 50-200ms, so the old 10ms was hopeless.
#define HGCM_CALL_MS 1000
#define HGCM_HOST_MSG_MS 30000
#define HGCM_CANCEL_MS 500

// Anything we hand VirtualBox has to be addressable in 32 bits: the port is
// written with OutU32, VBOX_REQUEST_HGCM_CALL is VMMDevReq_HGCMCall32 whose
// parameter block only has room for a 32-bit linear address, and HGCMCancel2
// takes a 32-bit physical address.  TinkerOS identity maps low memory so a
// virtual address below this line doubles as its own physical address.
#define VB_ADDR_LIMIT 0x100000000

// DolDoc's command escape character.  Spelled numerically because .HC files
// are themselves DolDoc, so writing it literally here would be an escape.
#define VB_DOLDOC_ESC 0x24

class VBGuestHdr
{
  U32 size;
  U32 ver;
  U32 req_type;
  I32 rc;
  U32 reserved1;
  U32 reserved2;
};

class VBGuestInfo
{
  VBGuestHdr hdr;
  U32 ver;
  U32 ostype;
};

class VBGuestMsAbs
{
  VBGuestHdr hdr;
  U32 features;
  I32 x;
  I32 y;
};

class VBGuest
{
  U32 port;
  U32 vmmdev;
  U32 irq;
};

class VBoxHGCMHdr
{
  U32 size;
  U32 ver;
  U32 req_type;
  I32 rc;
  U32 reserved1;
  U32 reserved2;
  U32 flags;
  I32 result;
};

// VMMDevHGCMConnect: header, service location, client id.  Nothing else --
// this used to carry two spare fields that inflated hdr.size.
class VBoxClipConnect
{
  VBoxHGCMHdr hdr;
  U32 loc_type;
  U8 loc[128];
  U32 client_id;
};

// VMMDevHGCMDisconnect is the header followed immediately by the client id,
// with no service-location block in between, so it cannot share a struct with
// the connect request.
class VBoxClipDisconnect
{
  VBoxHGCMHdr hdr;
  U32 client_id;
};

// VMMDevHGCMCancel2 takes the plain 24-byte request header (not the HGCM one)
// plus the physical address of the request being abandoned.
class VBoxHGCMCancel2
{
  VBGuestHdr hdr;
  U32 phys_req;
};

class VBoxHGCParam
{
  U32 type;
  U64 value;
};

class VBoxHGCPtr
{
  U32 type;
  U32 size;
  U32 ptr;
};

class VBoxClipFmts
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam fmts;
};

class VBoxClipMsg
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam msg;
  VBoxHGCParam fmts;
};

class VBoxClipRead
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam fmt;
  VBoxHGCPtr ptr;
  VBoxHGCParam size;
};

class VBoxClipWrite
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam fmt;
  VBoxHGCPtr ptr;
};

class VBoxCaps
{
  VBGuestHdr hdr;
  U32 caps;
};

static I16 *utf16_host_write_clipboard=NULL;
static I16 *utf16_host_read_clipboard=NULL;
static U8 *utf8_host_read_clipboard=NULL;
static U8 *guest_clip_utf8=NULL;  //staged by Ctrl-C, sent by the service task

static CTask *vb_ms_task=NULL;
static CTask *vb_clip_task=NULL;

static VBoxClipConnect *vbox_clip=NULL;
static VBoxClipDisconnect *vbox_clip_disc=NULL;
static VBoxHGCMCancel2 *vbox_clip_cancel=NULL;
static VBoxClipMsg *vbox_clip_msg=NULL;
static VBoxClipRead *vbox_clip_read=NULL;
static VBoxClipFmts *vbox_clip_fmts=NULL;
static VBoxClipWrite *vbox_clip_write=NULL;
static VBGuest vb_guest;
static VBGuestMsAbs *mouse=NULL;

// vb_clip_op_lock serialises the request buffers owned by the Ctrl-C/Ctrl-V
// paths; vb_clip_data_lock guards guest_clip_utf8, which the service task
// reads.  There is deliberately no lock around the port itself: each request
// type has its own buffer and VMMDev is happy with several outstanding calls,
// so the old global lock only ever served to let the 12ms mouse poll starve
// the clipboard.
static I64 vb_clip_op_lock=0;
static I64 vb_clip_data_lock=0;
static I64 vb_clip_cancel_lock=0;

static Bool vb_clip_run=FALSE;
static Bool vb_clip_up=FALSE;
static Bool vb_clip_broken=FALSE;
static VBoxHGCMHdr *vb_clip_stuck=NULL;
static I64 vb_host_fmts=0;

Bool VBAddrOk(U8 *p)
{//TRUE if p can be handed to VirtualBox as a 32-bit address.
  if (!p)
    return FALSE;
  return p(I64) < VB_ADDR_LIMIT;
}

I64 VBParm32(VBoxHGCParam *p)
{//Read back a VMMDevHGCMParmType_32bit result.
//The host only writes the low dword, so reading the full U64 picks up
//whatever was in the high dword beforehand -- which is how a perfectly good
//host message comes back looking like garbage.
  return p->value & 0xFFFFFFFF;
}

I64 ToUTF16(I16 *dst, U8 *input, I64 max_chars)
{//Latin-1 to UTF-16LE.  Returns bytes written, terminator included.
  I64 i, size;
  size=StrLen(input);
  if (size > max_chars)
    size = max_chars;
  i=0;
  while (i < size)
  {
    dst[i]=input[i];
    i++;
  }
  dst[size]=0;
  return (size+1)*2;
}

I64 ToUTF8(U8 *dst, I16 *src, I64 size_bytes, I64 max_chars)
{//UTF-16LE to Latin-1.  size_bytes is the byte count the host reported.
  I64 i, size;
  size = size_bytes/2;
  if (size > max_chars)
    size = max_chars;
  i=0;
  while (i < size)
  {
    dst[i] = src[i];
    i++;
  }
  dst[size]=0;
  return StrLen(dst);
}

Bool VBSendReq(VBGuestHdr *hdr)
{//Plain (non HGCM) VMMDev request.  These complete on the port write itself,
//so there is nothing to wait for and no reason to hold a lock.
  hdr->rc=0;
  OutU32(vb_guest.port, hdr);
  return hdr->rc >= 0;
}

U0 VBHGCMCancel(VBoxHGCMHdr *hdr)
{//Tell the host to abandon a call we have given up on.  Skipping this leaves
//the host holding a reference to the request buffer, and it will happily
//complete into it later on top of whatever we rebuilt there.
  I64 deadline;

  if (!vbox_clip_cancel)
    return;

  while (LBts(&vb_clip_cancel_lock,0))
    Yield;

  MemSet(vbox_clip_cancel,0,sizeof(VBoxHGCMCancel2));
  vbox_clip_cancel->hdr.size=sizeof(VBoxHGCMCancel2);
  vbox_clip_cancel->hdr.ver=VBOX_REQUEST_HEADER_VERSION;
  vbox_clip_cancel->hdr.req_type=VBOX_REQUEST_HGCM_CANCEL2;
  vbox_clip_cancel->phys_req=hdr(I64);
  OutU32(vb_guest.port, vbox_clip_cancel);

  LBtr(&vb_clip_cancel_lock,0);

  //A cancelled call still completes, with an error, so wait for DONE before
  //letting anybody touch hdr again.
  deadline=cnts.jiffies+HGCM_CANCEL_MS*JIFFY_FREQ/1000;
  while (!(hdr->flags & VBOX_HGCM_REQ_DONE))
  {
    if (cnts.jiffies > deadline)
      return;
    Sleep(1);
  }
}

Bool VBHGCMCall(VBoxHGCMHdr *hdr, I64 timeout_ms)
{//Submit an HGCM request and wait for it to actually finish.
  I64 deadline;

  if (vb_clip_broken)
    return FALSE;

  hdr->flags=0;
  hdr->result=0;
  hdr->rc=0;
  OutU32(vb_guest.port, hdr);

  //Only two things here can be trusted.  A negative rc means VMMDev rejected
  //the request on the spot.  The DONE flag means the call finished.  Do NOT
  //gate on rc==VINF_HGCM_ASYNC_EXECUTE: the host does not reliably write the
  //header back on the postponed path (rc stays whatever we put there), and a
  //call it happens to service synchronously comes back as VINF_SUCCESS.
  if (hdr->rc < 0)
    return FALSE;

  if (hdr->flags & VBOX_HGCM_REQ_DONE)
    return hdr->result >= 0;

  deadline=cnts.jiffies+timeout_ms*JIFFY_FREQ/1000;
  while (!(hdr->flags & VBOX_HGCM_REQ_DONE))
  {
    if (cnts.jiffies > deadline)
    {
      VBHGCMCancel(hdr);
      if (!(hdr->flags & VBOX_HGCM_REQ_DONE))
      {
        //The host still owns this buffer.  Reusing it would corrupt whatever
        //we build in it next, so stop rather than scribble.
        vb_clip_stuck=hdr;
        vb_clip_broken=TRUE;
        AdamLog("VirtualBox clipboard: HGCM request stuck, disabling.\n");
      }
      return FALSE;
    }
    Sleep(1);
  }
  return hdr->result >= 0;
}

U0 VBGuestMsUpdate()
{
  I64 dx,dy,x,y,slop=1;
  U8 ms_buf[4];

  //VMMDevReq_GetMouseStatus is synchronous: mouse->x/y are valid the instant
  //OutU32 returns.
  VBSendReq(&mouse->hdr);

  x = GR_WIDTH * (mouse->x) / 0xFFFF;
  y = GR_HEIGHT * (mouse->y) / 0xFFFF;

  ms_buf[0]=0;
  ms_buf[3]=0;

  dx=x-ms.pos.x;
  dy=y-ms.pos.y;


  if (AbsI64(dx)<slop) dx=0;
  if (AbsI64(dy)<slop) dy=0;
  if (!dx&&!dy) return;

  dx=ClampI64(x-ms.pos.x,-255,255);
  dy=ClampI64(y-ms.pos.y,-255,255);

  if (ms_hard.bttns[0])
    ms_buf[0]|=1;
  if (ms_hard.bttns[1])
    ms_buf[0]|=2;
  if (ms_hard.bttns[2])
    ms_buf[0]|=4;
  if (ms_hard.bttns[3])
    ms_buf[3]|=16;
  if (ms_hard.bttns[4])
    ms_buf[3]|=32;

  if (dx<0)
  {
    ms_buf[0]|=0x10;
    dx=-dx;
    dx=256-dx;
  }
  if (dy<=0)
  {
    dy=-dy;
  }
  else
  {
    ms_buf[0]|=0x20;
    dy=256-dy;
  }

  ms_buf[1]=dx;
  ms_buf[2]=dy;

  MsPktInject(ms_buf);
}

U0 VBMsPollTask()
{
  while (1)
  {
    VBGuestMsUpdate;
    Sleep(MS_MSG_MS);
  }
}

U0 VBClipReqInit(U8 *req, I64 total_size)
{//Zero the request body and refill the HGCM header.
//Note the U8*: HolyC scales pointer arithmetic by the pointed-to type, so
//"vbox_clip_msg + sizeof(VBoxHGCMHdr)" on a VBoxClipMsg* lands 32 whole
//structs downrange and clears somebody else's memory instead of this one's.
  VBoxHGCMHdr *hdr=req;

  MemSet(req+sizeof(VBoxHGCMHdr),0,total_size-sizeof(VBoxHGCMHdr));
  hdr->size=total_size;
  hdr->ver=VBOX_REQUEST_HEADER_VERSION;
  hdr->req_type=VBOX_REQUEST_HGCM_CALL;
  hdr->flags=0;
  hdr->result=0;
  hdr->rc=0;
}

Bool VBHostClipMsgReq(I64 timeout_ms)
{//FN_GET_HOST_MSG does not return until the host has something to say, so
//this is the one call we are supposed to sit on.  Owned by the service task.
  if (vb_clip_broken)
    return FALSE;
  VBClipReqInit(vbox_clip_msg,sizeof(VBoxClipMsg));
  vbox_clip_msg->client_id = vbox_clip->client_id;
  vbox_clip_msg->func_code = VBOX_SHARED_CLIPBOARD_FN_GET_HOST_MSG;
  vbox_clip_msg->param_cnt = 2;
  vbox_clip_msg->msg.type = VBOX_HGCM_PARM_32BIT;
  vbox_clip_msg->fmts.type = VBOX_HGCM_PARM_32BIT;
  return VBHGCMCall(&vbox_clip_msg->hdr,timeout_ms);
}

Bool VBHostClipRead()
{//Pull the host clipboard into utf16_host_read_clipboard.
  if (vb_clip_broken)
    return FALSE;
  VBClipReqInit(vbox_clip_read,sizeof(VBoxClipRead));
  vbox_clip_read->client_id = vbox_clip->client_id;
  vbox_clip_read->func_code = VBOX_SHARED_CLIPBOARD_FN_READ_DATA;
  vbox_clip_read->param_cnt = 3;
  vbox_clip_read->fmt.type = VBOX_HGCM_PARM_32BIT;
  vbox_clip_read->fmt.value = VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT;
  vbox_clip_read->ptr.type = VBOX_HGCM_PARM_LINADDR;
  vbox_clip_read->ptr.size = (HOST_CLIP_READ_MAX+1)*2; //bytes, not chars
  vbox_clip_read->ptr.ptr = utf16_host_read_clipboard(I64);
  vbox_clip_read->size.type = VBOX_HGCM_PARM_32BIT;
  return VBHGCMCall(&vbox_clip_read->hdr,HGCM_CALL_MS);
}

Bool VBHostClipFmts()
{//Announce that the guest now owns text.  The host answers later with
//HOST_MSG_READ_DATA if anything actually pastes.
  if (vb_clip_broken)
    return FALSE;
  VBClipReqInit(vbox_clip_fmts,sizeof(VBoxClipFmts));
  vbox_clip_fmts->client_id = vbox_clip->client_id;
  vbox_clip_fmts->func_code = VBOX_SHARED_CLIPBOARD_FN_FMTS;
  vbox_clip_fmts->param_cnt = 1;
  vbox_clip_fmts->fmts.type = VBOX_HGCM_PARM_32BIT;
  vbox_clip_fmts->fmts.value = VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT;
  return VBHGCMCall(&vbox_clip_fmts->hdr,HGCM_CALL_MS);
}

Bool VBHostClipWrite()
{//Answer a host HOST_MSG_READ_DATA with whatever Ctrl-C last staged.
//Owned by the service task: sending WRITE_DATA unsolicited, as the old
//CopyTextToHost did, only landed when a host read happened to be pending.
  I64 bytes;

  if (vb_clip_broken)
    return FALSE;

  while (LBts(&vb_clip_data_lock,0))
    Yield;
  bytes=ToUTF16(utf16_host_write_clipboard,guest_clip_utf8,HOST_CLIP_WRITE_MAX);
  LBtr(&vb_clip_data_lock,0);

  VBClipReqInit(vbox_clip_write,sizeof(VBoxClipWrite));
  vbox_clip_write->client_id = vbox_clip->client_id;
  vbox_clip_write->func_code = VBOX_SHARED_CLIPBOARD_FN_WRITE_DATA;
  vbox_clip_write->param_cnt = 2;
  vbox_clip_write->fmt.type = VBOX_HGCM_PARM_32BIT;
  vbox_clip_write->fmt.value = VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT;
  vbox_clip_write->ptr.type = VBOX_HGCM_PARM_LINADDR;
  //Announce what we actually wrote.  Claiming the whole 32K buffer made
  //hosts that honour the length paste a wall of padding.
  vbox_clip_write->ptr.size = bytes;
  vbox_clip_write->ptr.ptr = utf16_host_write_clipboard(I64);
  return VBHGCMCall(&vbox_clip_write->hdr,HGCM_CALL_MS);
}

U0 VBClipSrvTask()
{//The shared clipboard protocol is host-driven: the host tells us when it
//wants our data and when it has data of its own.  This task parks in
//FN_GET_HOST_MSG waiting to be told, and owns vbox_clip_msg and
//vbox_clip_write outright so nothing else can rebuild them mid-flight.
  I64 msg,fmts;

  while (vb_clip_run)
  {
    if (!VBHostClipMsgReq(HGCM_HOST_MSG_MS))
    {
      //Nothing to report inside the window, or the link is gone.
      if (vb_clip_broken)
        vb_clip_run=FALSE;
      Sleep(1);
    }
    else
    {
      msg=VBParm32(&vbox_clip_msg->msg);
      fmts=VBParm32(&vbox_clip_msg->fmts);

      if (msg==VBOX_SHARED_CLIPBOARD_HOST_MSG_READ_DATA)
      {
        if (fmts & VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT)
          VBHostClipWrite;
      }
      else if (msg==VBOX_SHARED_CLIPBOARD_HOST_MSG_FMTS)
        vb_host_fmts=fmts;
      else if (msg==VBOX_SHARED_CLIPBOARD_HOST_MSG_QUIT)
        vb_clip_run=FALSE;
    }
  }
  vb_clip_task=NULL;
}

U0 VBClipSrvStart()
{
  if (vb_clip_task)
    return;
  vb_clip_run=TRUE;
  vb_clip_task=Spawn(&VBClipSrvTask,,"VBClipTask",-1);
}

U0 VBClipSrvStop()
{
  I64 deadline;

  if (!vb_clip_task)
    return;
  vb_clip_run=FALSE;
  //The task is parked inside FN_GET_HOST_MSG; cancelling is the only way to
  //get it back without waiting out the whole window.
  VBHGCMCancel(&vbox_clip_msg->hdr);
  deadline=cnts.jiffies+HGCM_CALL_MS*JIFFY_FREQ/1000;
  while (vb_clip_task && cnts.jiffies < deadline)
    Sleep(1);
  if (vb_clip_task)
  {
    Kill(vb_clip_task);
    vb_clip_task=NULL;
  }
}

Bool VBGuestInit()
{
  CPCIDev *vb_dev;
  VBGuestInfo *guest_info;
  Bool res;

  if (!IsHypervisorPresent)
    return FALSE;

  vb_dev = PCIDevFind(,,0x80ee,0xcafe);
  if (!vb_dev)
    return FALSE;
  if (vb_dev->base_code != 8 || vb_dev->sub_code != 128)
    return FALSE;

  vb_guest.port = PCIReadU32(vb_dev->bus,vb_dev->dev,vb_dev->fun, 0x10) & 0xFFFFFFFC;
  vb_guest.vmmdev = PCIReadU32(vb_dev->bus,vb_dev->dev,vb_dev->fun, 0x14) & 0xFFFFFFF0;
  vb_guest.irq = PCIReadU8(vb_dev->bus,vb_dev->dev,vb_dev->fun, 0x3C);

  guest_info = CAllocAligned(sizeof(VBGuestInfo), 16, Fs->code_heap);
  if (!VBAddrOk(guest_info))
  {
    AdamLog("VirtualBox: request buffer above 4Gb, giving up.\n");
    Free(guest_info);
    return FALSE;
  }
  guest_info->hdr.size = sizeof(VBGuestInfo);
  guest_info->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  guest_info->hdr.req_type = VBOX_REQUEST_GUEST_INFO;
  guest_info->ver = VBOX_VMMDEV_VERSION;
  guest_info->ostype=0x00100;

  //There used to be a MemPageTable() poke here marking the page holding the
  //lock variable uncached.  It was aimed at the wrong page (the request
  //buffers live elsewhere), it skipped the &~0x18 mask and the InvlPg that
  //Kernel/Mem/DmaHeap.HC does, and VMMDev traffic is plain coherent guest RAM
  //anyway, so it is gone.

  //The original code ignored the status here, so only warn -- refusing to
  //come up at all over a grumpy guest-info report would be a worse trade.
  res=VBSendReq(&guest_info->hdr);
  if (!res)
    AdamLog("VirtualBox: guest info report returned %d, continuing.\n",
            guest_info->hdr.rc);
  Free(guest_info);
  return TRUE;
}

U0 VBMouseInit()
{
  mouse = CAllocAligned(sizeof(VBGuestMsAbs), 16, Fs->code_heap);
  if (!VBAddrOk(mouse))
  {
    AdamLog("VirtualBox mouse: buffer above 4Gb, giving up.\n");
    Free(mouse);
    mouse=NULL;
    return;
  }
  mouse->hdr.size = sizeof(VBGuestMsAbs);
  mouse->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  mouse->hdr.req_type = VBOX_REQUEST_SET_MOUSE;
  mouse->features = (1 << 0) | (1 << 4);
  VBSendReq(&mouse->hdr);
  mouse->hdr.req_type = VBOX_REQUEST_GET_MOUSE;
  AdamLog("Enabling VirtualBox mouse integration!\n");
  ms_hard.scale.x=0.25;
  ms_hard.scale.y=0.25;
  vb_ms_task=Spawn(&VBMsPollTask,,"VBMsTask",-1);
}

Bool VBClipInit()
{
  Bool ok;

  utf8_host_read_clipboard = CAlloc(HOST_CLIP_READ_MAX+1);
  guest_clip_utf8 = CAlloc(HOST_CLIP_WRITE_MAX+1);
  utf16_host_read_clipboard = CAllocAligned((HOST_CLIP_READ_MAX+1)*2, 16, Fs->code_heap);
  utf16_host_write_clipboard = CAllocAligned((HOST_CLIP_WRITE_MAX+1)*2, 16, Fs->code_heap);

  vbox_clip = CAllocAligned(sizeof(VBoxClipConnect), 16, Fs->code_heap);
  vbox_clip_disc = CAllocAligned(sizeof(VBoxClipDisconnect), 16, Fs->code_heap);
  vbox_clip_cancel = CAllocAligned(sizeof(VBoxHGCMCancel2), 16, Fs->code_heap);
  vbox_clip_msg = CAllocAligned(sizeof(VBoxClipMsg), 16, Fs->code_heap);
  vbox_clip_read = CAllocAligned(sizeof(VBoxClipRead), 16, Fs->code_heap);
  vbox_clip_fmts = CAllocAligned(sizeof(VBoxClipFmts), 16, Fs->code_heap);
  vbox_clip_write = CAllocAligned(sizeof(VBoxClipWrite), 16, Fs->code_heap);

  //Bail loudly rather than silently truncate a pointer into a 32-bit field.
  if (!VBAddrOk(utf16_host_read_clipboard) ||
      !VBAddrOk(utf16_host_write_clipboard) ||
      !VBAddrOk(vbox_clip) || !VBAddrOk(vbox_clip_disc) ||
      !VBAddrOk(vbox_clip_cancel) || !VBAddrOk(vbox_clip_msg) ||
      !VBAddrOk(vbox_clip_read) || !VBAddrOk(vbox_clip_fmts) ||
      !VBAddrOk(vbox_clip_write))
  {
    AdamLog("VirtualBox clipboard: buffers above 4Gb, giving up.\n");
    return FALSE;
  }

  //Buffers are brand new here, so nothing a previous run left in flight can
  //still be pointing at them.
  vb_clip_broken=FALSE;
  vb_clip_stuck=NULL;

  MemSet(vbox_clip,0,sizeof(VBoxClipConnect));
  vbox_clip->hdr.size = sizeof(VBoxClipConnect);
  vbox_clip->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip->hdr.req_type = VBOX_REQUEST_HGCM_CONNECT;
  vbox_clip->loc_type = 2;
  StrPrint(&vbox_clip->loc, "VBoxSharedClipboard");

  //HGCMConnect is async like every other HGCM request.  The old code slept
  //20ms, read client_id out of a buffer the host might not have filled in
  //yet, then decided the clipboard was off because a stale high dword made
  //msg.value compare unequal to 3.
  ok=VBHGCMCall(&vbox_clip->hdr,HGCM_CALL_MS);
  if (!ok || !vbox_clip->client_id)
  {
    AdamLog("VirtualBox shared clipboard NOT enabled! (rc:%d result:%d flags:%X id:%d)\n",
            vbox_clip->hdr.rc,vbox_clip->hdr.result,
            vbox_clip->hdr.flags,vbox_clip->client_id);
    return FALSE;
  }

  vb_clip_up=TRUE;
  VBClipSrvStart;
  AdamLog("Enabling VirtualBox shared clipboard!\n");
  return TRUE;
}

public U0 VBCBReset(Bool log=TRUE)
{//Tear the HGCM client down and build a fresh one.
  if (!vbox_clip)
    return;

  if (vb_clip_stuck)
  {
    //Cannot safely reuse anything while the host still owns a buffer.
    if (!(vb_clip_stuck->flags & VBOX_HGCM_REQ_DONE))
    {
      if (log) AdamLog("VirtualBox clipboard: request still in flight, cannot reset.\n");
      return;
    }
    vb_clip_stuck=NULL;
    vb_clip_broken=FALSE;
  }

  VBClipSrvStop;
  vb_clip_up=FALSE;

  if (vbox_clip->client_id)
  {
    //VMMDevHGCMDisconnect is header plus client id and nothing else.  Reusing
    //VBoxClipConnect here put loc_type where the host reads client_id, so it
    //always asked to disconnect client 2 and the real one leaked.
    MemSet(vbox_clip_disc,0,sizeof(VBoxClipDisconnect));
    vbox_clip_disc->hdr.size = sizeof(VBoxClipDisconnect);
    vbox_clip_disc->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
    vbox_clip_disc->hdr.req_type = VBOX_REQUEST_HGCM_DISCONNECT;
    vbox_clip_disc->client_id = vbox_clip->client_id;
    VBHGCMCall(&vbox_clip_disc->hdr,HGCM_CALL_MS);
  }

  MemSet(vbox_clip,0,sizeof(VBoxClipConnect));
  vbox_clip->hdr.size = sizeof(VBoxClipConnect);
  vbox_clip->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip->hdr.req_type = VBOX_REQUEST_HGCM_CONNECT;
  vbox_clip->loc_type = 2;
  StrPrint(&vbox_clip->loc, "VBoxSharedClipboard");

  if (VBHGCMCall(&vbox_clip->hdr,HGCM_CALL_MS) && vbox_clip->client_id)
  {
    vb_clip_up=TRUE;
    VBClipSrvStart;
    if (log) AdamLog("Reset Virtualbox clipboard!\n");
  }
  else
  {
    if (log) AdamLog("VirtualBox clipboard reset failed!\n");
  }
}

public U0 CopyTextToHost(U8 *str)
{//Stage text and tell the host we own the selection.  The host comes back
//with HOST_MSG_READ_DATA when something actually pastes; the service task
//answers that, so this never blocks on a data transfer.
  I64 n;

  if (!vb_clip_up || vb_clip_broken || !str)
    return;

  while (LBts(&vb_clip_data_lock,0))
    Yield;
  n=StrLen(str);
  if (n > HOST_CLIP_WRITE_MAX)
    n = HOST_CLIP_WRITE_MAX;
  MemCpy(guest_clip_utf8,str,n);
  guest_clip_utf8[n]=0;
  LBtr(&vb_clip_data_lock,0);

  while (LBts(&vb_clip_op_lock,0))
    Yield;
  VBHostClipFmts;
  LBtr(&vb_clip_op_lock,0);
}

U8 *GetTextFromHost()
{//Fetch the host clipboard as a fresh MAlloc'd string, or NULL.
  I64 bytes,n;
  U8 *res=NULL;

  if (!vb_clip_up || vb_clip_broken)
    return NULL;

  while (LBts(&vb_clip_op_lock,0))
    Yield;

  if (VBHostClipRead)
  {
    bytes=VBParm32(&vbox_clip_read->size);
    if (bytes)
    {
      n=ToUTF8(utf8_host_read_clipboard,utf16_host_read_clipboard,
               bytes,HOST_CLIP_READ_MAX);
      if (n)
        res=StrNew(utf8_host_read_clipboard);
    }
  }

  LBtr(&vb_clip_op_lock,0);
  return res;
}

U8 *VBEscapeForDoc(U8 *src)
{//DocPutS() treats VB_DOLDOC_ESC as the DolDoc command introducer, so host
//text containing one gets swallowed (or runs away to the end of the string).
//Doubling it renders a literal one.
  I64 n=0,i=0,j=0;
  U8 *res;

  while (src[i])
  {
    if (src[i]==VB_DOLDOC_ESC)
      n++;
    i++;
  }
  res=MAlloc(i+n+1);
  i=0;
  while (src[i])
  {
    res[j]=src[i];
    j++;
    if (src[i]==VB_DOLDOC_ESC)
    {
      res[j]=VB_DOLDOC_ESC;
      j++;
    }
    i++;
  }
  res[j]=0;
  return res;
}

public U0 PasteTextFromHost()
{
  U8 *str=GetTextFromHost;
  U8 *esc;

  if (str)
  {
    esc=VBEscapeForDoc(str);
    "%s\n",esc;
    Free(esc);
    Free(str);
  }
  else
  {
    "Got no text from host clipboard!\n";
  }
}

U0 CopyCBToHost()
{
  U8 *str=DocDumpToStr(sys_clip_doc);
  if (str) CopyTextToHost(str);
  Free(str);
}

public U0 CopyCBFromHost()
{
  U8 *host_cb=GetTextFromHost;
  U8 *esc;
  Bool unlock;

  if (host_cb)
  {
    esc=VBEscapeForDoc(host_cb);
    unlock=DocLock(sys_clip_doc);
    ClipDel;
    //The "%s" matters: the old code passed host text straight in as the
    //format string, so a stray percent ate garbage varargs.
    DocPrint(sys_clip_doc,"%s",esc);
    if (unlock)
      DocUnlock(sys_clip_doc);
    Free(esc);
    Free(host_cb);
  }
}

U0 ClipHijackInit()
{
  HijackFunc(&ClipCutCB,&CopyCBToHost);
  HijackFunc(&ClipCopyCB,&CopyCBToHost);
  HijackFunc(&ClipPasteCB,&CopyCBFromHost);
}

U0 VBLogInit()
{
  VBoxCaps *caps = CAllocAligned(sizeof(VBoxCaps), 16, Fs->code_heap);

  if (!VBAddrOk(caps))
  {
    Free(caps);
    return;
  }
  caps->hdr.size = sizeof(VBoxCaps); //was sizeof(VBGuestInfo), a different struct
  caps->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  caps->hdr.req_type = VBOX_REQUEST_SET_GUEST_CAPS;
  caps->caps = 0;
  VBSendReq(&caps->hdr);
  Free(caps);
}

U0 VBInitAll()
{
  CTask *old_ms_task=FindTaskByTitle("VBMsTask");
  CTask *old_clip_task=FindTaskByTitle("VBClipTask");
  Bool have_vb;

  if (old_ms_task) Kill(old_ms_task);
  if (old_clip_task) Kill(old_clip_task);
  vb_clip_task=NULL;
  vb_clip_run=FALSE;
  vb_clip_up=FALSE;

  have_vb=VBGuestInit;

  if (have_vb)
  {
    AdamLog("Found VirtualBox!\n");
    VBLogInit;
    VBMouseInit;
#ifdef VBOX_CLIPBOARD_ENABLE
    if (VBClipInit)
      ClipHijackInit;
#endif
    VBLog("Initialized TinkerOS guest additions!\n");
  }
}

U0 DumpCBMsg()
{
  if (!vbox_clip_msg)
  {
    "VirtualBox clipboard not initialized.\n";
    return;
  }
  ClassRep(vbox_clip_msg);
  "Host fmts:%X up:%d broken:%d\n",vb_host_fmts,vb_clip_up,vb_clip_broken;
}

VBInitAll;

