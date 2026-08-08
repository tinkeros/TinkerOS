Cd(__DIR__);;

#include "VBoxAdd"

#define VBOX_HGCM_PARM_64BIT 2
#define SHFL_CALL_MS 8000
#define SHFL_FN_MAP_FOLDER      17
#define SHFL_FN_UNMAP_FOLDER    13
#define SHFL_FN_CREATE          3
#define SHFL_FN_CLOSE           4
#define SHFL_FN_READ            5
#define SHFL_FN_WRITE           6
#define SHFL_FN_LIST            8
#define SHFL_FN_SET_UTF8        16
#define SHFL_CPARMS_MAP_FOLDER    4
#define SHFL_CPARMS_UNMAP_FOLDER  1
#define SHFL_CPARMS_CREATE        3
#define SHFL_CPARMS_CLOSE         2
#define SHFL_CPARMS_READ          5
#define SHFL_CPARMS_WRITE         5
#define SHFL_CPARMS_LIST          8
#define SHFL_CF_DIRECTORY               0x00000004
#define SHFL_CF_ACT_OVERWRITE_IF_EXISTS 0x00000030
#define SHFL_CF_ACT_FAIL_IF_NEW         0x00000100
#define SHFL_CF_ACCESS_READ             0x00001000
#define SHFL_CF_ACCESS_WRITE            0x00002000
#define SHFL_CF_ACT_OPEN_IF_EXISTS      0x00000000
#define SHFL_CF_ACT_CREATE_IF_NEW       0x00000000
#define SHFL_MAX_LEN 256
#define SHFL_TYPE_MASK      0xF000
#define SHFL_TYPE_DIRECTORY 0x4000
#define SHFL_ROOT_NIL 0xFFFFFFFF
#define SHFL_HANDLE_NIL (-1)
#define SHFL_LIST_BUF 16384
#define SHFL_XFER_CHUNK 16384

class VBoxSFStrHdr
{
  U16 size;
  U16 length;
};

class VBoxSFObjAttr
{
  U32 mode;
  U32 additional;
  U32 uid;
  U32 gid;
  U32 hardlinks;
  U32 inode_dev;
  U64 inode_id;
  U32 aflags;
  U32 generation;
  U32 device;
};

class VBoxSFTimespec
{
  I64 ns;
};

class VBoxSFObjInfo
{
  I64 obj_size;
  I64 allocated;
  VBoxSFTimespec access_time;
  VBoxSFTimespec modification_time;
  VBoxSFTimespec change_time;
  VBoxSFTimespec birth_time;
  VBoxSFObjAttr attr;
};

class VBoxSFCreateParms
{
  U64 handle;
  U32 result;
  U32 create_flags;
  VBoxSFObjInfo info;
};

class VBoxSFMapFolder
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCPtr path;
  VBoxHGCParam root;
  VBoxHGCParam delimiter;
  VBoxHGCParam case_sensitive;
};

class VBoxSFUnmapFolder
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam root;
};

class VBoxSFCreate
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam root;
  VBoxHGCPtr path;
  VBoxHGCPtr parms;
};

class VBoxSFClose
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam root;
  VBoxHGCParam handle;
};

class VBoxSFRW
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam root;
  VBoxHGCParam handle;
  VBoxHGCParam offset;
  VBoxHGCParam cb;
  VBoxHGCPtr buffer;
};

class VBoxSFList
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
  VBoxHGCParam root;
  VBoxHGCParam handle;
  VBoxHGCParam flags;
  VBoxHGCParam cb;
  VBoxHGCPtr path;
  VBoxHGCPtr buffer;
  VBoxHGCParam resume_point;
  VBoxHGCParam file_count;
};

class VBoxSFSetUtf8
{
  VBoxHGCMHdr hdr;
  U32 client_id;
  U32 func_code;
  U32 param_cnt;
};

static U32 sf_client_id=0;
static U32 sf_root=SHFL_ROOT_NIL;
static Bool sf_up=FALSE;
static VBoxClipConnect *sf_connect=NULL;
static VBoxClipDisconnect *sf_disconnect=NULL;
static VBoxSFMapFolder *sf_map=NULL;
static VBoxSFUnmapFolder *sf_unmap=NULL;
static VBoxSFCreate *sf_create=NULL;
static VBoxSFClose *sf_close=NULL;
static VBoxSFRW *sf_rw=NULL;
static VBoxSFList *sf_list=NULL;
static VBoxSFCreateParms *sf_create_parms=NULL;
static VBoxSFSetUtf8 *sf_utf8=NULL;
static U8 *sf_xfer_buf=NULL;
static U8 *sf_list_buf=NULL;

U8 *VBSFStrNew(U8 *path)
{//Build a SHFLSTRING: header + UTF-8 bytes + NUL, one allocation.
  I64 slen=StrLen(path),total=sizeof(VBoxSFStrHdr)+slen+1;
  U8 *buf=CAllocAligned(total,16,adam_task->code_heap);
  VBoxSFStrHdr *h=buf;

  if (!buf)
    return NULL;
  h->size=slen+1;
  h->length=slen;
  MemCpy(buf+sizeof(VBoxSFStrHdr),path,slen);
  buf[sizeof(VBoxSFStrHdr)+slen]=0;
  return buf;
}

U32 VBSFStrBufSize(U8 *s)
{//Total size to hand VirtualBox for a VBSFStrNew() buffer: header + capacity.
  VBoxSFStrHdr *h=s;
  if (!s)
    return 0;
  return sizeof(VBoxSFStrHdr)+h->size;
}

U0 VBSFReqInit(U8 *req, I64 total_size)
{//Zero the request body and refill the HGCM header.
  VBoxHGCMHdr *hdr=req;

  MemSet(req+sizeof(VBoxHGCMHdr),0,total_size-sizeof(VBoxHGCMHdr));
  hdr->size=total_size;
  hdr->ver=VBOX_REQUEST_HEADER_VERSION;
  hdr->req_type=VBOX_REQUEST_HGCM_CALL;
  hdr->flags=0;
  hdr->result=0;
  hdr->rc=0;
}

static VBoxHGCMCancel2 *sf_cancel=NULL;

U0 VBSFCancel(VBoxHGCMHdr *hdr)
{//Tell the host to abandon a call we've given up on.
  I64 deadline;

  if (!sf_cancel)
    sf_cancel=CAllocAligned(sizeof(VBoxHGCMCancel2),16,adam_task->code_heap);
  if (!VBAddrOk(sf_cancel))
    return;

  ZeroClass(sf_cancel);
  sf_cancel->hdr.size=sizeof(VBoxHGCMCancel2);
  sf_cancel->hdr.ver=VBOX_REQUEST_HEADER_VERSION;
  sf_cancel->hdr.req_type=VBOX_REQUEST_HGCM_CANCEL2;
  sf_cancel->phys_req=hdr(I64);
  OutU32(vb_guest.port,sf_cancel);

  deadline=cnts.jiffies+HGCM_CANCEL_MS*JIFFY_FREQ/1000;
  while (!(hdr->flags & VBOX_HGCM_REQ_DONE))
  {
    if (cnts.jiffies>deadline)
      return;
    Sleep(1);
  }
}

Bool VBSFCall(VBoxHGCMHdr *hdr, I64 timeout_ms)
{//Submit an HGCM request and wait for it to actually finish.
  I64 deadline;

  hdr->flags=0;
  hdr->result=0;
  hdr->rc=0;
  OutU32(vb_guest.port,hdr);

  Sleep(1);

  if (hdr->rc<0)
    return FALSE;
  if (hdr->flags & VBOX_HGCM_REQ_DONE)
    return hdr->result>=0;

  deadline=cnts.jiffies+timeout_ms*JIFFY_FREQ/1000;
  while (!(hdr->flags & VBOX_HGCM_REQ_DONE))
  {
    if (cnts.jiffies>deadline)
    {
      VBSFCancel(hdr);
      if (hdr->flags & VBOX_HGCM_REQ_DONE)
        return hdr->result>=0;
      return FALSE;
    }
    Sleep(1);
  }
  return hdr->result>=0;
}

public Bool VBShareInit(U8 *folder_name=NULL)
{// Setup shared folder default name is "tos_share"
  U8 *name=folder_name,*path_str;
  Bool ok;

  if (sf_up)
    return TRUE;

  if (!name)
    name="tos_share";

  if (!vb_guest.port)
  {
    if (!VBGuestInit)
    {
      AdamLog("VBoxShare: no VirtualBox host found.\n");
      return FALSE;
    }
  }

  if (!sf_connect)
  {
    sf_connect =CAllocAligned(sizeof(VBoxClipConnect),16,adam_task->code_heap);
    sf_disconnect =CAllocAligned(sizeof(VBoxClipDisconnect),16,adam_task->code_heap);
    sf_map =CAllocAligned(sizeof(VBoxSFMapFolder),16,adam_task->code_heap);
    sf_unmap =CAllocAligned(sizeof(VBoxSFUnmapFolder),16,adam_task->code_heap);
    sf_create =CAllocAligned(sizeof(VBoxSFCreate),16,adam_task->code_heap);
    sf_close =CAllocAligned(sizeof(VBoxSFClose),16,adam_task->code_heap);
    sf_rw =CAllocAligned(sizeof(VBoxSFRW),16,adam_task->code_heap);
    sf_list =CAllocAligned(sizeof(VBoxSFList),16,adam_task->code_heap);
    sf_create_parms =CAllocAligned(sizeof(VBoxSFCreateParms),16,adam_task->code_heap);
    sf_utf8 =CAllocAligned(sizeof(VBoxSFSetUtf8),16,adam_task->code_heap);
    sf_xfer_buf =CAllocAligned(SHFL_XFER_CHUNK,16,adam_task->code_heap);
    sf_list_buf =CAllocAligned(SHFL_LIST_BUF,16,adam_task->code_heap);
  }

  if (!VBAddrOk(sf_connect) || !VBAddrOk(sf_disconnect) ||
      !VBAddrOk(sf_map) || !VBAddrOk(sf_unmap) ||
      !VBAddrOk(sf_create) || !VBAddrOk(sf_close) ||
      !VBAddrOk(sf_rw) || !VBAddrOk(sf_list) ||
      !VBAddrOk(sf_create_parms) || !VBAddrOk(sf_utf8) ||
      !VBAddrOk(sf_xfer_buf) || !VBAddrOk(sf_list_buf))
  {
    AdamLog("VBoxShare: buffers above 4Gb, giving up.\n");
    return FALSE;
  }

  ZeroClass(sf_connect);
  sf_connect->hdr.size=sizeof(VBoxClipConnect);
  sf_connect->hdr.ver=VBOX_REQUEST_HEADER_VERSION;
  sf_connect->hdr.req_type=VBOX_REQUEST_HGCM_CONNECT;
  sf_connect->loc_type=2;
  StrPrint(&sf_connect->loc,"VBoxSharedFolders");

  ok=VBSFCall(&sf_connect->hdr,SHFL_CALL_MS);
  if (!ok || !sf_connect->client_id)
  {
    AdamLog("VBoxShare: HGCM connect to VBoxSharedFolders failed "
        "(rc:%d result:%d id:%d) -- is the shared folders service enabled?\n",
        sf_connect->hdr.rc,sf_connect->hdr.result,sf_connect->client_id);
    return FALSE;
  }
  sf_client_id=sf_connect->client_id;

  VBSFReqInit(sf_utf8,sizeof(VBoxSFSetUtf8));
  sf_utf8->client_id=sf_client_id;
  sf_utf8->func_code=SHFL_FN_SET_UTF8;
  sf_utf8->param_cnt=0;
  VBSFCall(&sf_utf8->hdr,SHFL_CALL_MS);

  path_str=VBSFStrNew(name);
  if (!path_str || !VBAddrOk(path_str))
  {
    AdamLog("VBoxShare: could not build folder name string.\n");
    Free(path_str);
    return FALSE;
  }

  VBSFReqInit(sf_map,sizeof(VBoxSFMapFolder));
  sf_map->client_id=sf_client_id;
  sf_map->func_code=SHFL_FN_MAP_FOLDER;
  sf_map->param_cnt=SHFL_CPARMS_MAP_FOLDER;
  sf_map->path.type=VBOX_HGCM_PARM_LINADDR;
  sf_map->path.size=VBSFStrBufSize(path_str);
  sf_map->path.ptr=path_str(I64);
  sf_map->root.type=VBOX_HGCM_PARM_32BIT;
  sf_map->root.value=0;
  sf_map->delimiter.type=VBOX_HGCM_PARM_32BIT;
  sf_map->delimiter.value='/';
  sf_map->case_sensitive.type=VBOX_HGCM_PARM_32BIT;
  sf_map->case_sensitive.value=1;

  ok=VBSFCall(&sf_map->hdr,SHFL_CALL_MS);
  Free(path_str);
  if (!ok)
  {
    AdamLog("VBoxShare: could not map shared folder \"%s\" (rc:%d result:%d) "
        "-- check `VBoxManage sharedfolder add <vm> --name %s --hostpath <dir> "
        "--transient` was run on the host.\n",
        name,sf_map->hdr.rc,sf_map->hdr.result,name);
    return FALSE;
  }

  sf_root=VBParm32(&sf_map->root);
  sf_up=TRUE;
  AdamLog("VBoxShare: mapped shared folder \"%s\" (root=%d)\n",name,sf_root);
  return TRUE;
}

public U0 VBShareDone()
{
  if (!sf_up)
    return;

  VBSFReqInit(sf_unmap,sizeof(VBoxSFUnmapFolder));
  sf_unmap->client_id=sf_client_id;
  sf_unmap->func_code=SHFL_FN_UNMAP_FOLDER;
  sf_unmap->param_cnt=SHFL_CPARMS_UNMAP_FOLDER;
  sf_unmap->root.type=VBOX_HGCM_PARM_32BIT;
  sf_unmap->root.value=sf_root;
  VBSFCall(&sf_unmap->hdr,SHFL_CALL_MS);

  ZeroClass(sf_disconnect);
  sf_disconnect->hdr.size=sizeof(VBoxClipDisconnect);
  sf_disconnect->hdr.ver=VBOX_REQUEST_HEADER_VERSION;
  sf_disconnect->hdr.req_type=VBOX_REQUEST_HGCM_DISCONNECT;
  sf_disconnect->client_id=sf_client_id;
  VBSFCall(&sf_disconnect->hdr,SHFL_CALL_MS);

  sf_up=FALSE;
  sf_root=SHFL_ROOT_NIL;
  AdamLog("VBoxShare: unmapped and disconnected.\n");
}

Bool VBSFOpen(U8 *remote_path, U32 create_flags, U64 *out_handle, I64 *out_size,
    Bool quiet=FALSE)
{
  U8 *path_str=VBSFStrNew(remote_path);
  Bool ok;

  if (!path_str || !VBAddrOk(path_str))
  {
    if (!quiet)
      AdamLog("VBoxShare: could not build path string for \"%s\".\n",remote_path);
    Free(path_str);
    return FALSE;
  }

  ZeroClass(sf_create_parms);
  sf_create_parms->handle=SHFL_HANDLE_NIL;
  sf_create_parms->create_flags=create_flags;

  VBSFReqInit(sf_create,sizeof(VBoxSFCreate));
  sf_create->client_id=sf_client_id;
  sf_create->func_code=SHFL_FN_CREATE;
  sf_create->param_cnt=SHFL_CPARMS_CREATE;
  sf_create->root.type=VBOX_HGCM_PARM_32BIT;
  sf_create->root.value=sf_root;
  sf_create->path.type=VBOX_HGCM_PARM_LINADDR;
  sf_create->path.size=VBSFStrBufSize(path_str);
  sf_create->path.ptr=path_str(I64);
  sf_create->parms.type=VBOX_HGCM_PARM_LINADDR;
  sf_create->parms.size=sizeof(VBoxSFCreateParms);
  sf_create->parms.ptr=sf_create_parms(I64);

  ok=VBSFCall(&sf_create->hdr,SHFL_CALL_MS);
  Free(path_str);

  if (!ok || sf_create_parms->handle==SHFL_HANDLE_NIL)
  {
    if (!quiet)
      AdamLog("VBoxShare: open \"%s\" failed (rc:%d result:%d create-result:%d)\n",
          remote_path,sf_create->hdr.rc,sf_create->hdr.result,
          sf_create_parms->result);
    return FALSE;
  }

  *out_handle=sf_create_parms->handle;
  if (out_size)
    *out_size=sf_create_parms->info.obj_size;
  return TRUE;
}

U0 VBSFClose(U64 handle)
{
  VBSFReqInit(sf_close,sizeof(VBoxSFClose));
  sf_close->client_id=sf_client_id;
  sf_close->func_code=SHFL_FN_CLOSE;
  sf_close->param_cnt=SHFL_CPARMS_CLOSE;
  sf_close->root.type=VBOX_HGCM_PARM_32BIT;
  sf_close->root.value=sf_root;
  sf_close->handle.type=VBOX_HGCM_PARM_64BIT;
  sf_close->handle.value=handle;
  VBSFCall(&sf_close->hdr,SHFL_CALL_MS);
}

public I64 VBGet(U8 *remote_path, U8 *local_path)
{//Pull remote_path (relative to the mapped shared folder) into local_path
  U64 handle;
  I64 remote_size,total=0,got,want;
  U8 *data,*raw;
  CArcCompress *arc;

  if (!sf_up && !VBShareInit)
    return -1;

  if (!VBSFOpen(remote_path,SHFL_CF_ACCESS_READ|SHFL_CF_ACT_FAIL_IF_NEW,
          &handle,&remote_size))
    return -1;

  if (!remote_size)
  {
    VBSFClose(handle);
    "VBoxShare: %s is empty, not writing %s.\n",remote_path,local_path;
    return 0;
  }

  data=MAlloc(remote_size);
  while (total<remote_size)
  {
    want=remote_size-total;
    if (want>SHFL_XFER_CHUNK)
      want=SHFL_XFER_CHUNK;

    VBSFReqInit(sf_rw,sizeof(VBoxSFRW));
    sf_rw->client_id=sf_client_id;
    sf_rw->func_code=SHFL_FN_READ;
    sf_rw->param_cnt=SHFL_CPARMS_READ;
    sf_rw->root.type=VBOX_HGCM_PARM_32BIT;
    sf_rw->root.value=sf_root;
    sf_rw->handle.type=VBOX_HGCM_PARM_64BIT;
    sf_rw->handle.value=handle;
    sf_rw->offset.type=VBOX_HGCM_PARM_64BIT;
    sf_rw->offset.value=total;
    sf_rw->cb.type=VBOX_HGCM_PARM_32BIT;
    sf_rw->cb.value=want;
    sf_rw->buffer.type=VBOX_HGCM_PARM_LINADDR;
    sf_rw->buffer.size=SHFL_XFER_CHUNK;
    sf_rw->buffer.ptr=sf_xfer_buf(I64);

    if (!VBSFCall(&sf_rw->hdr,SHFL_CALL_MS))
    {
      AdamLog("VBoxShare: read of %s failed at offset %d (rc:%d result:%d)\n",
          remote_path,total,sf_rw->hdr.rc,sf_rw->hdr.result);
      Free(data);
      VBSFClose(handle);
      return -1;
    }
    got=VBParm32(&sf_rw->cb);
    if (!got)
      break;
    MemCpy(data+total,sf_xfer_buf,got);
    total+=got;
  }

  VBSFClose(handle);
  arc=data;
  if (IsDotZ(local_path) && total>=sizeof(CArcCompress) &&
      arc->compressed_size==total &&
      CT_NONE<=arc->compression_type<=CT_8_BIT &&
      0<=arc->expanded_size<mem_mapped_space)
  {
    raw=ExpandBuf(arc);
    FileWrite(local_path,raw,arc->expanded_size);
    Free(raw);
  }
  else
    FileWrite(local_path,data,total);
  Free(data);
  "VBoxShare: got %s (%d bytes) -> %s\n",remote_path,total,local_path;
  return total;
}

public I64 VBPut(U8 *local_path, U8 *remote_path)
{//Push local_path (any TinkerOS drive FileRead can see) to remote_path,
  U64 handle;
  I64 len,total=0,want,wrote,attr=0;
  U8 *data;
  CArcCompress *arc;

  if (!sf_up && !VBShareInit)
    return -1;

  data=FileRead(local_path,&len,&attr);
  if (!data)
  {
    "VBoxShare: could not read local file %s.\n",local_path;
    return -1;
  }

  if (attr & RS_ATTR_COMPRESSED)
  {
    arc=CompressBuf(data,len);
    Free(data);
    data=arc;
    len=arc->compressed_size;
  }

  if (!VBSFOpen(remote_path,
          SHFL_CF_ACCESS_WRITE|SHFL_CF_ACT_OVERWRITE_IF_EXISTS,&handle,NULL))
  {
    Free(data);
    return -1;
  }

  while (total<len)
  {
    want=len-total;
    if (want>SHFL_XFER_CHUNK)
      want=SHFL_XFER_CHUNK;
    MemCpy(sf_xfer_buf,data+total,want);

    VBSFReqInit(sf_rw,sizeof(VBoxSFRW));
    sf_rw->client_id=sf_client_id;
    sf_rw->func_code=SHFL_FN_WRITE;
    sf_rw->param_cnt=SHFL_CPARMS_WRITE;
    sf_rw->root.type=VBOX_HGCM_PARM_32BIT;
    sf_rw->root.value=sf_root;
    sf_rw->handle.type=VBOX_HGCM_PARM_64BIT;
    sf_rw->handle.value=handle;
    sf_rw->offset.type=VBOX_HGCM_PARM_64BIT;
    sf_rw->offset.value=total;
    sf_rw->cb.type=VBOX_HGCM_PARM_32BIT;
    sf_rw->cb.value=want;
    sf_rw->buffer.type=VBOX_HGCM_PARM_LINADDR;
    sf_rw->buffer.size=SHFL_XFER_CHUNK;
    sf_rw->buffer.ptr=sf_xfer_buf(I64);

    if (!VBSFCall(&sf_rw->hdr,SHFL_CALL_MS))
    {
      AdamLog("VBoxShare: write to %s failed at offset %d (rc:%d result:%d)\n",
          remote_path,total,sf_rw->hdr.rc,sf_rw->hdr.result);
      Free(data);
      VBSFClose(handle);
      return -1;
    }
    wrote=VBParm32(&sf_rw->cb);
    if (!wrote)
      break;
    total+=wrote;
  }

  VBSFClose(handle);
  Free(data);
  "VBoxShare: put %s -> %s (%d bytes)\n",local_path,remote_path,total;
  return total;
}

class VBEnt
{
  VBEnt *next;
  U8 *name;
  I64 size;
  Bool is_dir;
};

U0 VBEntListDel(VBEnt *e)
{
  VBEnt *next;

  while (e)
  {
    next=e->next;
    Free(e->name);
    Free(e);
    e=next;
  }
}

VBEnt *VBSFDirRead(U8 *rel, Bool *_ok=NULL)
{//Read a whole share-relative directory into a list.  "." and ".." are
  U64 handle;
  VBEnt *head=NULL,*tail=NULL,*e;
  VBoxSFObjInfo *info;
  VBoxSFStrHdr *nh;
  U8 *p,*end,*name;
  I64 n,left,entry_size,namelen,resume=0,rounds=0;
  U8 name_buf[257];

  if (_ok)
    *_ok=FALSE;

  if (!sf_up && !VBShareInit)
    return NULL;

  if (!VBSFOpen(rel,SHFL_CF_DIRECTORY|SHFL_CF_ACCESS_READ|SHFL_CF_ACT_FAIL_IF_NEW,
          &handle,NULL))
    return NULL;

  while (TRUE)
  {
    VBSFReqInit(sf_list,sizeof(VBoxSFList));
    sf_list->client_id=sf_client_id;
    sf_list->func_code=SHFL_FN_LIST;
    sf_list->param_cnt=SHFL_CPARMS_LIST;
    sf_list->root.type=VBOX_HGCM_PARM_32BIT;
    sf_list->root.value=sf_root;
    sf_list->handle.type=VBOX_HGCM_PARM_64BIT;
    sf_list->handle.value=handle;
    sf_list->flags.type=VBOX_HGCM_PARM_32BIT;
    sf_list->flags.value=0;
    sf_list->cb.type=VBOX_HGCM_PARM_32BIT;
    sf_list->cb.value=SHFL_LIST_BUF;
    sf_list->path.type=VBOX_HGCM_PARM_LINADDR;
    sf_list->path.size=0;
    sf_list->path.ptr=0;
    sf_list->buffer.type=VBOX_HGCM_PARM_LINADDR;
    sf_list->buffer.size=SHFL_LIST_BUF;
    sf_list->buffer.ptr=sf_list_buf(I64);
    sf_list->resume_point.type=VBOX_HGCM_PARM_32BIT;
    sf_list->resume_point.value=resume;
    sf_list->file_count.type=VBOX_HGCM_PARM_32BIT;
    sf_list->file_count.value=0;

    if (!VBSFCall(&sf_list->hdr,SHFL_CALL_MS))
    {
      if (!rounds)
      {
        AdamLog("VBoxShare: list \"%s\" failed (rc:%d result:%d)\n",
            rel,sf_list->hdr.rc,sf_list->hdr.result);
        VBSFClose(handle);
        return NULL;
      }
      break;
    }

    n=VBParm32(&sf_list->file_count);
    if (!n)
      break;

    p=sf_list_buf;
    end=sf_list_buf+VBParm32(&sf_list->cb);
    left=n;
    while (left && p<end)
    {
      info=p;
      nh=p+sizeof(VBoxSFObjInfo)+2+28;
      name=nh(U8*)+sizeof(VBoxSFStrHdr);
      namelen=nh->length;
      if (namelen>SHFL_MAX_LEN)
        namelen=SHFL_MAX_LEN;
      MemCpy(name_buf,name,namelen);
      name_buf[namelen]=0;

      e=CAlloc(sizeof(VBEnt));
      e->name=StrNew(name_buf);
      e->size=info->obj_size;
      e->is_dir=(info->attr.mode & SHFL_TYPE_MASK)==SHFL_TYPE_DIRECTORY;
      if (tail)
        tail->next=e;
      else
        head=e;
      tail=e;

      entry_size=sizeof(VBoxSFObjInfo)+2+28+sizeof(VBoxSFStrHdr)+nh->size;
      p+=entry_size;
      left--;
    }

    resume+=n-left;
    if (left==n)
      break;
    rounds++;
  }

  VBSFClose(handle);
  if (_ok)
    *_ok=TRUE;
  return head;
}

public U0 VBDir(U8 *remote_path=NULL)
{//List a directory in the mapped shared folder.
  U8 *rel=remote_path,*disp_name;
  VBEnt *lst,*e;
  I64 n=0;
  Bool ok;

  if (!rel)
    rel="";

  lst=VBSFDirRead(rel,&ok);
  if (!ok)
    return;

  e=lst;
  while (e)
  {
    n++;
    e=e->next;
  }

  disp_name=rel;
  if (!rel[0])
    disp_name="/";
  "VBoxShare: %s (%d entries)\n",disp_name,n;

  e=lst;
  while (e)
  {
    if (e->is_dir)
      "  <DIR>  %s\n",e->name;
    else
      "  %8d %s\n",e->size,e->name;
    e=e->next;
  }

  VBEntListDel(lst);
}

Bool VBSFIsRemote(U8 *path)
{//"VB:/..." names a path inside the mapped shared folder.
  return path && !StrNICmp(path,"VB:",3);
}

U8 *VBSFRemoteRel(U8 *path)
{//MAlloc'd share-relative form of a "VB:/..." path: prefix gone, no leading or trailing '/'.
  U8 *res;
  I64 len;

  if (VBSFIsRemote(path))
    path+=3;
  while (*path=='/')
    path++;
  res=StrNew(path);
  len=StrLen(res);
  while (len && res[len-1]=='/')
  {
    len--;
    res[len]=0;
  }
  return res;
}

U8 *VBSFRemoteCat(U8 *dir, U8 *name)
{//Join two share-relative pieces with exactly one '/'.
  while (*name=='/')
    name++;
  if (!*dir)
    return StrNew(name);
  if (!*name)
    return StrNew(dir);
  return MStrPrint("%s/%s",dir,name);
}

U8 *VBSFLocalCat(U8 *dir, U8 *name)
{//For an absolute local path.  dir comes from DirCur
  U8 *res;
  I64 len=StrLen(dir);

  while (len>2 && dir[len-1]=='/')
    len--;
  res=MAlloc(len+StrLen(name)+2);
  MemCpy(res,dir,len);
  res[len]='/';
  StrCpy(res+len+1,name);
  return res;
}

Bool VBSFDirMk(U8 *rel)
{//Make one share-relative directory, tolerating one that already exists.
  U64 handle;

  if (!rel || !*rel)
    return TRUE;

  if (VBSFOpen(rel,SHFL_CF_DIRECTORY|SHFL_CF_ACCESS_READ|SHFL_CF_ACT_FAIL_IF_NEW,
          &handle,NULL,TRUE))
  {
    VBSFClose(handle);
    return TRUE;
  }

  if (!VBSFOpen(rel,SHFL_CF_DIRECTORY|SHFL_CF_ACCESS_READ|SHFL_CF_ACCESS_WRITE|
          SHFL_CF_ACT_CREATE_IF_NEW|SHFL_CF_ACT_OPEN_IF_EXISTS,&handle,NULL))
    return FALSE;
  VBSFClose(handle);
  return TRUE;
}

Bool VBSFDirMkPath(U8 *rel)
{//mkdir -p for the share side: make every missing component of rel.
  U8 *buf;
  I64 i=0,sep;
  Bool res=TRUE;

  if (!rel || !*rel)
    return TRUE;

  buf=StrNew(rel);
  while (res)
  {
    if (!buf[i] || buf[i]=='/')
    {
      sep=buf[i];
      buf[i]=0;
      if (buf[0])
        res=VBSFDirMk(buf);
      buf[i]=sep;
      if (!sep)
        break;
    }
    i++;
  }
  Free(buf);
  return res;
}

I64 VBSFGetTree(U8 *rsrc, U8 *ldst)
{//Recursive half of the share->TinkerOS direction.
  VBEnt *lst,*e;
  Bool ok;
  I64 res=0,sub,got;
  U8 *rsub,*lsub;

  lst=VBSFDirRead(rsrc,&ok);
  if (!ok)
    return -1;

  e=lst;
  while (e)
  {
    if (StrCmp(e->name,".") && StrCmp(e->name,".."))
    {
      rsub=VBSFRemoteCat(rsrc,e->name);
      lsub=VBSFLocalCat(ldst,e->name);
      if (e->is_dir)
      {
        DirMk(lsub);
        sub=VBSFGetTree(rsub,lsub);
        if (sub>0)
          res+=sub;
      }
      else
      {
        got=VBGet(rsub,lsub);
        if (!got)
          FileWrite(lsub,"",0);
        if (got>=0)
          res++;
      }
      Free(rsub);
      Free(lsub);
    }
    e=e->next;
  }

  VBEntListDel(lst);
  return res;
}

I64 VBSFPutTree(CDirEntry *tmpde, I64 src_dir_len, U8 *rdst)
{//Recursive half of the TinkerOS->share direction
  I64 res=0,sub;
  U8 *rsub;

  while (tmpde)
  {
    rsub=VBSFRemoteCat(rdst,tmpde->full_name+src_dir_len);
    if (tmpde->attr & RS_ATTR_DIR)
    {
      if (VBSFDirMk(rsub))
      {
        sub=VBSFPutTree(tmpde->sub,src_dir_len,rdst);
        if (sub>0)
          res+=sub;
      }
      else
        "VBoxShare: could not make remote directory \"%s\".\n",rsub;
    }
    else if (VBPut(tmpde->full_name,rsub)>=0)
      res++;
    Free(rsub);
    tmpde=tmpde->next;
  }
  return res;
}

public I64 VBCopyTree(U8 *src, U8 *dst, Bool no_mask=TRUE)
{// CopyTree across the VirtualBox shared folder.
  /*
  CopyTree across the VirtualBox shared folder.  Exactly one of src and dst
  names the host side, with a "VB:/" prefix where a local path has its drive
  letter; the other is an ordinary TinkerOS path.  Missing directories are
  made at every level on whichever end is the destination.

   VBCopyTree("B:/Home/Proj","VB:/backup/Proj");  //guest -> host
   VBCopyTree("VB:/incoming","B:/Home/incoming"); //host -> guest

  Returns the count of files copied, directories excluded, or -1 if the copy
  never got started.  Like CopyTree, it copies the *contents* of src into dst
  */
  CDirContext *dirc;
  CDirEntry *tmpde;
  U8 *rel,*st;
  U64 probe;
  I64 res=-1,i1;

  if (!sf_up && !VBShareInit)
    return -1;

  if (VBSFIsRemote(src)==VBSFIsRemote(dst))
  {
    "VBoxShare: one of \"%s\" and \"%s\" must start with VB:/ (and not both) "
        "-- use CopyTree for two local paths.\n",src,dst;
    return -1;
  }

  if (VBSFIsRemote(src))
  {
    rel=VBSFRemoteRel(src);
    if (!VBSFOpen(rel,SHFL_CF_DIRECTORY|SHFL_CF_ACCESS_READ|
            SHFL_CF_ACT_FAIL_IF_NEW,&probe,NULL))
      "VBoxShare: no such directory in the shared folder: \"%s\".\n",src;
    else
    {
      VBSFClose(probe);
      if (dirc=DirContextNew(dst,TRUE,TRUE))
      {
        st=DirCur;
        DirContextDel(dirc);
        res=VBSFGetTree(rel,st);
        Free(st);
      }
      else
        "VBoxShare: could not make local directory \"%s\".\n",dst;
    }
    Free(rel);
  }
  else
  {
    rel=VBSFRemoteRel(dst);
    if (dirc=DirContextNew(src,TRUE,,no_mask))
    {
      tmpde=FilesFind(dirc->mask,FUF_RECURSE);
      st=DirCur;
      DirContextDel(dirc);
      i1=StrLen(st);
      if (i1==3) i1--;
      if (VBSFDirMkPath(rel))
        res=VBSFPutTree(tmpde,i1,rel);
      else
        "VBoxShare: could not make remote directory \"%s\".\n",rel;
      DirTreeDel(tmpde);
      Free(st);
    }
    else
      "VBoxShare: could not find local directory \"%s\".\n",src;
    Free(rel);
  }

  if (res>=0)
    "VBoxShare: copied %d file(s) %s -> %s\n",res,src,dst;
  return res;
}

public U0 VBTest()
{//Round-trip self-test: write a marker to B:, put it to the shared folder,
//list the folder, get it back under a different name, and diff.
  U8 *marker="VBoxShare self-test marker, ping\n",*readback;
  I64 len,rlen;
  Bool ok;

  if (!VBShareInit)
  {
    "VBTest: init failed, see the log above.\n";
    return;
  }

  len=StrLen(marker);
  FileWrite("B:/vbshare_test_out.txt",marker,len);

  if (VBPut("B:/vbshare_test_out.txt","test_roundtrip.txt")<=0)
  {
    "VBTest: put failed.\n";
    return;
  }

  VBDir;

  if (VBGet("test_roundtrip.txt","B:/vbshare_test_in.txt")<=0)
  {
    "VBTest: get failed.\n";
    return;
  }

  readback=FileRead("B:/vbshare_test_in.txt",&rlen);
  ok=readback && rlen==len && MemCmp(readback,marker,len)==0;
  Free(readback);

  if (ok)
    "VBTest: PASS -- round trip matched byte for byte.\n";
  else
    "VBTest: FAIL -- round trip did not match (rlen=%d want=%d).\n",rlen,len;
}

Bool VBTreeChk(U8 *path, U8 *want)
{//One file's worth of VBTreeTest's comparison.
  U8 *got;
  I64 len,wlen=StrLen(want);
  Bool res;

  got=FileRead(path,&len);
  res=got && len==wlen && MemCmp(got,want,wlen)==0;
  Free(got);
  if (!res)
    "VBTreeTest: %s did not come back intact.\n",path;
  return res;
}

public U0 VBTreeTest()
{//Round-trip self-test for VBCopyTree: build a small tree on B:, push
//it to the shared folder, pull it back under a different name, compare
//every file.  Covers what the single-file test cannot -- two levels of
//subdirectory getting created on the host on the way out and on B: on the
//way back.
  U8 *a="tree self-test, top level\n",*b="tree self-test, one down\n",
      *c="tree self-test, two down\n";
  I64 n;
  Bool ok;

  if (!VBShareInit)
  {
    "VBTreeTest: init failed, see the log above.\n";
    return;
  }

  FileWrite("B:/vbshare_tree/a.txt",a,StrLen(a));
  FileWrite("B:/vbshare_tree/sub/b.txt",b,StrLen(b));
  FileWrite("B:/vbshare_tree/sub/deep/c.txt",c,StrLen(c));

  n=VBCopyTree("B:/vbshare_tree","VB:/vbshare_tree_test");
  if (n!=3)
  {
    "VBTreeTest: FAIL -- put copied %d file(s), wanted 3.\n",n;
    return;
  }

  VBDir("vbshare_tree_test/sub");

  n=VBCopyTree("VB:/vbshare_tree_test","B:/vbshare_tree_back");
  if (n!=3)
  {
    "VBTreeTest: FAIL -- get copied %d file(s), wanted 3.\n",n;
    return;
  }

  ok=VBTreeChk("B:/vbshare_tree_back/a.txt",a);
  if (!VBTreeChk("B:/vbshare_tree_back/sub/b.txt",b))
    ok=FALSE;
  if (!VBTreeChk("B:/vbshare_tree_back/sub/deep/c.txt",c))
    ok=FALSE;

  if (ok)
    "VBTreeTest: PASS -- 3 files, 2 levels of subdirectory, both ways.\n";
  else
    "VBTreeTest: FAIL -- see above.\n";
}
