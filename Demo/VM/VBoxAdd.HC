#define VBOX_VMMDEV_VERSION 0x00010003
#define VBOX_REQUEST_HEADER_VERSION 0x10001

#define VBOX_REQUEST_GUEST_INFO 50
#define VBOX_REQUEST_SET_GUEST_CAPS 55
#define VBOX_REQUEST_HGCM_CONNECT 60
#define VBOX_REQUEST_HGCM_DISCONNECT 61
#define VBOX_REQUEST_HGCM_CALL 62

#define VBOX_REQUEST_GET_MOUSE 1
#define VBOX_REQUEST_SET_MOUSE 2

#define VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT 1
#define VBOX_SHARED_CLIPBOARD_FMT_BITMAP 2

#define VBOX_SHARED_CLIPBOARD_FN_GET_HOST_MSG 1
#define VBOX_SHARED_CLIPBOARD_FN_FMTS 2
#define VBOX_SHARED_CLIPBOARD_FN_READ_DATA 3
#define VBOX_SHARED_CLIPBOARD_FN_WRITE_DATA 4

#define VBOX_SHARED_CLIPBOARD_HOST_MSG_READ_DATA 2
#define VBOX_SHARED_CLIPBOARD_HOST_MSG_FMTS 3

#define HOST_CLIP_READ_MAX 32768
#define HOST_CLIP_WRITE_MAX 32768

#define MS_MSG_MS 12
#define CLIP_MSG_MS 10
#define MSG_REQ_MS 20

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

class VBoxClipConnect
{
  VBoxHGCMHdr hdr;
  U32 loc_type;
  U8 loc[128];
  U32 client_id;
  U32 msg;
  U32 fmts;
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
static U8 *utf8_host_read_clipboard=NULL;
static I16 *utf16_host_read_clipboard=NULL;
static CTask *vb_ms_task=NULL;
static VBoxClipConnect *vbox_clip=NULL;
static VBoxClipMsg *vbox_clip_msg=NULL;
static VBoxClipRead *vbox_clip_read=NULL;
static VBoxClipFmts *vbox_clip_fmts=NULL;
static VBoxClipWrite *vbox_clip_write=NULL;
static VBGuest vb_guest;
static VBGuestMsAbs *mouse=NULL;
static I64 vb_msg_lock=0;

U0 ToUTF16(U8 *input)
{
  I64 i, size;
  size=StrLen(input);
  if (size > HOST_CLIP_WRITE_MAX)
    size = HOST_CLIP_WRITE_MAX;
  for (i = 0; i < size; i++)
  {
    utf16_host_write_clipboard[i]=input[i];
  }
  utf16_host_write_clipboard[size]=0;
}

U0 ToUTF8(I16 *input, I64 size)
{
  I64 i;
  size = size/2;
  if (size>HOST_CLIP_READ_MAX)
    size=HOST_CLIP_READ_MAX-1;
  for (i = 0; i < size; i++)
  {
    utf8_host_read_clipboard[i] = input[i];
  }
  utf8_host_read_clipboard[size]=0;
}

U0 VBSendMsg(U8 *msg, I64 sleep=CLIP_MSG_MS)
{
  while (Bt(&vb_msg_lock,0))
  {
    Yield;
  }
  LBts(&vb_msg_lock, 0);
  OutU32(vb_guest.port, msg);
  Sleep(sleep);
  LBtr(&vb_msg_lock, 0);
}

U0 VBGuestMsUpdate()
{
  I64 dx,dy,x,y,slop=1;
  U8 ms_buf[4];

  VBSendMsg(mouse, MS_MSG_MS);

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
    if (vb_msg_lock)
      Yield;
    else
      VBGuestMsUpdate;
    Yield;
  }
}

U0 VBHostClipMsgReq()
{
  MemSet(vbox_clip_msg+sizeof(VBoxHGCMHdr),0,sizeof(VBoxClipMsg)-sizeof(VBoxHGCMHdr));
  vbox_clip_msg->client_id = vbox_clip->client_id;
  vbox_clip_msg->func_code = VBOX_SHARED_CLIPBOARD_FN_GET_HOST_MSG;
  vbox_clip_msg->param_cnt = 2;
  vbox_clip_msg->msg.type = 1;
  vbox_clip_msg->fmts.type = 1;
  VBSendMsg(vbox_clip_msg,MSG_REQ_MS);
}

U0 VBHostClipRead()
{
  MemSet(vbox_clip_read+sizeof(VBoxHGCMHdr),0,sizeof(VBoxClipRead)-sizeof(VBoxHGCMHdr));
  vbox_clip_read->client_id = vbox_clip->client_id;
  vbox_clip_read->func_code = VBOX_SHARED_CLIPBOARD_FN_READ_DATA;
  vbox_clip_read->param_cnt = 3;
  vbox_clip_read->fmt.type = 1;
  vbox_clip_read->fmt.value = VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT;
  vbox_clip_read->ptr.type = 4;
  vbox_clip_read->ptr.size = HOST_CLIP_READ_MAX;
  vbox_clip_read->ptr.ptr = utf16_host_read_clipboard;
  vbox_clip_read->size.type = 1;
  VBSendMsg(vbox_clip_read);
}

U0 VBHostClipFmts()
{
  MemSet(vbox_clip_fmts+sizeof(VBoxHGCMHdr),0,sizeof(VBoxClipFmts)-sizeof(VBoxHGCMHdr));
  vbox_clip_fmts->client_id = vbox_clip->client_id;
  vbox_clip_fmts->func_code = VBOX_SHARED_CLIPBOARD_FN_FMTS;
  vbox_clip_fmts->param_cnt = 1;
  vbox_clip_fmts->fmts.type = 1;
  vbox_clip_fmts->fmts.value = VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT;
  VBSendMsg(vbox_clip_fmts);
}

U0 VBHostClipWrite(U8 *str)
{
  MemSet(vbox_clip_write+sizeof(VBoxHGCMHdr),0,sizeof(VBoxClipWrite)-sizeof(VBoxHGCMHdr));
  ToUTF16(str);
  vbox_clip_write->client_id = vbox_clip->client_id;
  vbox_clip_write->func_code = VBOX_SHARED_CLIPBOARD_FN_WRITE_DATA;
  vbox_clip_write->param_cnt = 2;
  vbox_clip_write->fmt.type = 1;
  vbox_clip_write->fmt.value = VBOX_SHARED_CLIPBOARD_FMT_UNICODETEXT;
  vbox_clip_write->ptr.type = 4;
  vbox_clip_write->ptr.size = HOST_CLIP_WRITE_MAX;
  vbox_clip_write->ptr.ptr = utf16_host_write_clipboard;
  VBSendMsg(vbox_clip_write);
}

Bool VBGuestInit()
{
  CPCIDev *vb_dev;

  if (!IsHypervisorPresent)
    return FALSE;

  vb_dev = PCIDevFind(,,0x80ee,0xcafe);
  if (vb_dev->base_code != 8 || vb_dev->sub_code != 128)
    return FALSE;

  vb_guest.port = PCIReadU32(vb_dev->bus,vb_dev->dev,vb_dev->fun, 0x10) & 0xFFFFFFFC;
  vb_guest.vmmdev = PCIReadU32(vb_dev->bus,vb_dev->dev,vb_dev->fun, 0x14) & 0xFFFFFFF0;
  vb_guest.irq = PCIReadU8(vb_dev->bus,vb_dev->dev,vb_dev->fun, 0x3C);

  VBGuestInfo *guest_info =
      CAllocAligned(sizeof(VBGuestInfo), 16, Fs->code_heap);
  guest_info->hdr.size = sizeof(VBGuestInfo);
  guest_info->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  guest_info->hdr.req_type = VBOX_REQUEST_GUEST_INFO;
  guest_info->ver = VBOX_VMMDEV_VERSION;
  guest_info->ostype=0x00100;

  vb_msg_lock=MemPageTable(&vb_msg_lock);
  *(vb_msg_lock(I64*))|=0x11;
  vb_msg_lock=0;

  OutU32(vb_guest.port, guest_info);
  Sleep(20);
  Free(guest_info);
  return TRUE;
}

U0 VBMouseInit()
{
  mouse =
      CAllocAligned(sizeof(VBGuestMsAbs), 16, Fs->code_heap);
  mouse->hdr.size = sizeof(VBGuestMsAbs);
  mouse->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  mouse->hdr.req_type = VBOX_REQUEST_SET_MOUSE;
  mouse->features = (1 << 0) | (1 << 4);
  OutU32(vb_guest.port, mouse);
  Sleep(20);
  mouse->hdr.req_type = VBOX_REQUEST_GET_MOUSE;
  AdamLog("Enabling VirtualBox mouse integration!\n");
  ms_hard.scale.x=0.25;
  ms_hard.scale.y=0.25;
  vb_ms_task=Spawn(&VBMsPollTask,,"VBMsTask",-1);
}

Bool VBClipInit()
{
  utf8_host_read_clipboard = CAlloc(HOST_CLIP_READ_MAX);
  utf16_host_read_clipboard = CAllocAligned(HOST_CLIP_READ_MAX*2, 16, Fs->code_heap);
  utf16_host_write_clipboard = CAllocAligned(HOST_CLIP_WRITE_MAX*2, 16, Fs->code_heap);

  vbox_clip = CAllocAligned(sizeof(VBoxClipConnect), 16, Fs->code_heap);
  vbox_clip_msg = CAllocAligned(sizeof(VBoxClipMsg), 16, Fs->code_heap);
  vbox_clip_read = CAllocAligned(sizeof(VBoxClipRead), 16, Fs->code_heap);
  vbox_clip_fmts = CAllocAligned(sizeof(VBoxClipFmts), 16, Fs->code_heap);
  vbox_clip_write = CAllocAligned(sizeof(VBoxClipWrite), 16, Fs->code_heap);

  vbox_clip_write->hdr.size = sizeof(VBoxClipWrite);
  vbox_clip_write->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip_write->hdr.req_type = VBOX_REQUEST_HGCM_CALL;
  vbox_clip_fmts->hdr.size = sizeof(VBoxClipFmts);
  vbox_clip_fmts->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip_fmts->hdr.req_type = VBOX_REQUEST_HGCM_CALL;
  vbox_clip_read->hdr.size = sizeof(VBoxClipRead);
  vbox_clip_read->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip_read->hdr.req_type = VBOX_REQUEST_HGCM_CALL;
  vbox_clip_msg->hdr.size = sizeof(VBoxClipMsg);
  vbox_clip_msg->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip_msg->hdr.req_type = VBOX_REQUEST_HGCM_CALL;

  vbox_clip->hdr.size = sizeof(VBoxClipConnect);
  vbox_clip->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip->hdr.req_type = VBOX_REQUEST_HGCM_CONNECT;
  vbox_clip->loc_type = 2;
  StrPrint(&vbox_clip->loc, "VBoxSharedClipboard");
  OutU32(vb_guest.port, vbox_clip);
  Sleep(20);
  VBHostClipMsgReq;
  if (vbox_clip_msg->msg.value == 3)
  {
    AdamLog("Enabling VirtualBox shared clipboard!\n");
    return TRUE;
  }
  AdamLog("VirtualBox shared clipboard NOT enabled!\n");
  return FALSE;
}


U0 VBCBReset(Bool log=TRUE)
{
  vbox_clip->hdr.size = sizeof(VBoxClipConnect);
  vbox_clip->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip->hdr.req_type = VBOX_REQUEST_HGCM_DISCONNECT;
  vbox_clip->loc_type = 2;
  StrPrint(&vbox_clip->loc, "VBoxSharedClipboard");
  VBSendMsg(vbox_clip);

  VBHostClipMsgReq;

  MemSet(vbox_clip,0,sizeof(VBoxClipConnect));
  vbox_clip->hdr.size = sizeof(VBoxClipConnect);
  vbox_clip->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  vbox_clip->hdr.req_type = VBOX_REQUEST_HGCM_CONNECT;
  vbox_clip->loc_type = 2;
  StrPrint(&vbox_clip->loc, "VBoxSharedClipboard");
  VBSendMsg(vbox_clip);
  VBHostClipMsgReq;

  if (log) AdamLog("Reset Virtualbox clipboard!\n");
}



public U0 CopyTextToHost(U8 *str)
{
  VBHostClipFmts;
  VBHostClipWrite(str);
  VBHostClipMsgReq;
}

U8 *GetTextFromHost()
{
  I64 timeout=2;

  vbox_clip_read->size.value = 0;

  while (timeout>0)
  {
    if (vbox_clip_msg->msg.value==VBOX_SHARED_CLIPBOARD_HOST_MSG_FMTS)
    {
      VBHostClipRead;
    }
    VBHostClipMsgReq;

    if (timeout==5) VBCBReset(0);


    if (vbox_clip_read->size.value)
    {
      ToUTF8(utf16_host_read_clipboard, vbox_clip_read->size.value);
      vbox_clip_read->size.value = 0;
      return MStrPrint("%s",utf8_host_read_clipboard);
    }
    Sleep(10);
    timeout--;
  }
  return NULL;
}

public U0 PasteTextFromHost()
{
  U8 *str=GetTextFromHost;
  if (str)
  {
    "%s\n",str;
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
  if (host_cb)
  {
    ClipDel;
    DocPrint(sys_clip_doc,host_cb);
  }
  Free(host_cb);
}

U0 ClipHijackInit()
{
  HijackFunc(&ClipCutCB,&CopyCBToHost);
  HijackFunc(&ClipCopyCB,&CopyCBToHost);
  HijackFunc(&ClipPasteCB,&CopyCBFromHost);
}

U0 VBLog(U8 *str)
{
  while (*str)
  {
    PortNop;
    OutU8(0x504,*str++);
  }
}

U0 VBLogInit()
{
  VBoxCaps *caps =
      CAllocAligned(sizeof(VBoxCaps), 16, Fs->code_heap);
  caps->hdr.size = sizeof(VBGuestInfo);
  caps->hdr.ver = VBOX_REQUEST_HEADER_VERSION;
  caps->hdr.req_type = VBOX_REQUEST_SET_GUEST_CAPS;
  OutU32(vb_guest.port, caps);
  Sleep(20);
}

U0 VBInitAll()
{
  CTask *old_ms_task=FindTaskByTitle("VBMsTask");

  if (old_ms_task) Kill(old_ms_task);

  Bool have_vb=VBGuestInit;

  if (have_vb)
  {
    AdamLog("Found VirtualBox!\n");
    VBLogInit;
    VBMouseInit;
    // Uncomment if you want experimental clipboard integration
    // must be enabled as bidirectional and is WIP might stop
    // working randomly though I've had luck moving entire
    // files of text in and out with it.
    /*
    if (VBClipInit)
      ClipHijackInit;
    */
    VBLog("Initialized TinkerOS guest additions!\n");
  }
}

U0 DumpCBMsg()
{
  ClassRep(vbox_clip_msg);
}

VBInitAll;


