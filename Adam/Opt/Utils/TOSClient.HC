#define CMD_SOCKET        1
#define CMD_CLOSE         2
#define CMD_CONNECT_TCP   3
#define CMD_SEND          4
#define CMD_RECV          5
#define CMD_HELLO         0xAA

#define SOCK_STREAM 1
#define SOCK_DGRAM  2
#define SOCK_RAW    3

#define AF_UNSPEC   0
#define AF_INET     2
#define AF_INET6    10

#define SNAIL_TIMEOUT     500
#define SNAIL_FRAME_SIZE  112

// starting at 6 since SnailLib uses < 6
#define CMD_FILE_RECV     6
#define CMD_FILE_SEND     7
#define CMD_ID 8
#define CMD_URL_GET_RAW 9
#define CMD_HDIR 10
#define CMD_GET_DIR 11
#define CMD_CMP_HASH 12
#define CMD_GET_CB_TEXT 13
#define CMD_SET_CB_TEXT 14
#define CMD_HOST_EXEC 15
#define CMD_URL_GET_TEXT 16

public I8 SNAIL_COM=-1;
public I64 SNAIL_PORT=-1;

// This is prep for possibly doing TOSClient
// over network instead of over serial/virtual serial
public U0 StartTOSServer(I16 port)
{// TODO
  SNAIL_PORT=port;
}

U0 NetPutChar(I64 port, U8 ch)
{
  no_warn ch;
  no_warn port;
  // TODO
}

U0 NetPutS(I64 port, U8 *data)
{
  no_warn data;
  no_warn port;
  // TODO
}

Bool NetGetCharNoWait(I64 port, U8 *ch)
{
  no_warn ch;
  no_warn port;
  //TODO
  return FALSE;
}
U0 NetPutBlk(I64 port, U8 *data,I64 len)
{
  no_warn data;
  no_warn len;
  no_warn port;
  //TODO
}

static I64 ClientGetCharNoWait(U8 *ch)
{
  if (SNAIL_COM>0)
    return CommGetCharNoWait(SNAIL_COM,ch);
  else if (SNAIL_PORT>0)
    return NetGetCharNoWait(SNAIL_PORT,ch);
  return FALSE;
}

static U0 ClientPutChar(U8 ch)
{
  if (SNAIL_COM>0)
    CommPutChar(SNAIL_COM,ch);
  else if (SNAIL_PORT>0)
    NetPutChar(SNAIL_PORT,ch);
}

static U0 ClientPutS(U8 *data)
{
  if (SNAIL_COM>0)
    CommPutS(SNAIL_COM,data);
  else if (SNAIL_PORT>0)
    NetPutS(SNAIL_PORT,data);
}

static U0 ClientPutBlk(U8 *data, I64 len)
{
  if (SNAIL_COM>0)
    CommPutBlk(SNAIL_COM,data,len);
  else if (SNAIL_PORT>0)
    NetPutBlk(SNAIL_PORT,data,len);
}

static U8 ReadByte(I64 timeout_ms=750)
{
  U8 chr;
  F64 timeout_time=tS+ToF64(timeout_ms)/1000.0;
  while (1)
  {
    if (tS>timeout_time) throw('ComErr');
    if (ClientGetCharNoWait(&chr))
      return chr;
    else
      Yield;
  }
}

static I8 ReadI8(I64 timeout_ms=750)
{
  I8 chr;
  F64 timeout_time=tS+ToF64(timeout_ms)/1000.0;
  while (1)
  {
    if (tS>timeout_time) throw('ComErr');
    if (ClientGetCharNoWait(&chr))
      return chr;
    else
      Yield;
  }
}

static U0 ReadBlock(U8* buf, I64 count, I64 timeout_ms=750)
{
  F64 timeout_time=tS+ToF64(timeout_ms)/1000.0;
  while (count)
  {
    if (tS>timeout_time) throw('ComErr');
    if (ClientGetCharNoWait(buf))
    {
      buf++;
      count--;
      timeout_time=tS+ToF64(timeout_ms)/1000.0;
    }
    else
      Yield;
  }
}


I64 SocketInit()
{
  U8 chr;
  CommInit8n1(SNAIL_COM, 115200);
  CommFlush(SNAIL_COM);
  ClientPutChar(CMD_HELLO);
  I64 max_time = cnts.jiffies + SNAIL_TIMEOUT * JIFFY_FREQ / 1000;
  do
  {
    if (ClientGetCharNoWait(&chr))
    {
      if (chr == CMD_HELLO)
      {
        return 0;
      }
      else
      {
        "$FG,6$Failed to connect!\n";
        "Did you run InitTOSClient; and check if server is running?\n$FG$";
        throw;
      }
      return chr;
    }
    else
      Yield;
  }
  while (cnts.jiffies < max_time);
  "$FG,6$Failed to connect on COM%d!\n",SNAIL_COM;
  "Did you run InitTOSClient; and check if server is running?\n$FG$";
  throw;
}


I64 socket(I64 domain, I64 type)
{
  ClientPutChar(CMD_SOCKET);
  ClientPutChar(domain);
  ClientPutChar(type);
  return ReadI8();
}

I64 close(I64 sockfd)
{
  ClientPutChar(CMD_CLOSE);
  ClientPutChar(sockfd);
  return ReadI8();
}

I64 create_connection(U8* addr, U16 port)
{
  I64 error, sockfd;
  sockfd = socket(AF_INET, SOCK_STREAM);
  if (sockfd < 0)
    return sockfd;
  ClientPutChar(CMD_CONNECT_TCP);
  ClientPutChar(sockfd);
  ClientPutChar(StrLen(addr));
  ClientPutS(addr);
  ClientPutChar(port & 0xff);
  ClientPutChar(port >> 8);
  error = ReadI8();
  if (error < 0)
  {
    close(sockfd);
    return error;
  }
  return sockfd;
}

I64 recv(I64 sockfd, U8* buf, I64 len, I64 flags)
{// This will be problematic for UDP
  if (len > SNAIL_FRAME_SIZE)
    len = SNAIL_FRAME_SIZE;
  ClientPutChar(CMD_RECV);
  ClientPutChar(sockfd);
  ClientPutChar(len);
  ClientPutChar(flags);
  I64 got = ReadI8();
  if (got > 0)
    ReadBlock(buf, got);
  return got;
}

I64 send(I64 sockfd, U8* buf, I64 len, I64 flags)
{// FIXME: use frames
  ClientPutChar(CMD_SEND);
  ClientPutChar(sockfd);
  ClientPutChar(len);
  ClientPutChar(flags);
  ClientPutBlk(buf, len);
  return ReadI8();
}

#help_index "TOSClient"

Bool ProbeComm()
{//Search COM ports for TOS server
  I64 i,j;
  U8 tmp_buf[17], tmp_byte;
  MemSet(tmp_buf,0,17);
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    if (comm_ports[i].base)
    {
      "Checking COMM %d - ",i;
      CommInit8n1(i, 115200);
      CommFlush(i);
      CommPutChar(i,0xAA);
      Sleep(5);
      if (CommGetCharNoWait(i,&tmp_byte))
      {
        if (tmp_byte==0xAA)
        {
          CommPutChar(i,CMD_ID);
          Sleep(200);
          for (j=0; j<16; j++)
          {
            if (CommGetCharNoWait(i,&tmp_byte))
            {
              tmp_buf[j]=tmp_byte;
            }
            else Sleep(50);
          }
          if (!StrCmp("TOSSERVER",tmp_buf))
          {
            "Found TOS Server on COMM %d\n",i;
            SNAIL_COM=i;
            goto probe_end;
          }
        }
      }
      " No device detected!\n";
    }
  }
probe_end:
if (SNAIL_COM>0)
  return TRUE;
else
  return FALSE;
}

public Bool InitTOSClient()
{// Find server COM port (if exists)
  Bool have_server=ProbeComm;

  if (have_server)
  {
    "Found server on COM %d\n",SNAIL_COM;
    return TRUE;
  }
  else
    "Could not find server to connect to!\n";
  return FALSE;
}

public Bool TOSServerCheck()
{//Checks if InitTOSClient setup serial port
  if (SNAIL_COM<0)
  {
    "Server not yet setup, calling InitTOSClient;\n\n";

    if (InitTOSClient) return TRUE;

    "Failed to connect to server!\n";

    return FALSE;
  }
  CommFlush(SNAIL_COM);
  return TRUE;
}

public I64 Fget(U8 *filename, U8 *local_name=NULL)
{//Gets file from remote
  U8 *data, *basename, *zfile;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  ClientPutChar(CMD_FILE_SEND);
  ClientPutChar(StrLen(filename));
  ClientPutS(filename);
  lenlen=ReadI8;
  if (lenlen > 0)
  {
    data=CAlloc(lenlen+1);
    ReadBlock(data,lenlen);
    len=Str2I64(data);
    Free(data);
  }
  else
  {
    "Failed to read file %s (or file size is zero)!\n",filename;
    ClientPutChar(0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    ClientPutChar(lenlen);
    ReadBlock(data,len);
    "Got file: %s\n"
    , filename;
    if (local_name)
    {
      zfile=MStrPrint("%s.Z",local_name);
      if (IsFile(zfile))
      {
        FileWrite(zfile,data,len);
      }
      else
      {
        FileWrite(local_name,data,len);
      }
      Free(zfile);
    }
    else
    {
      basename = FileBaseName(filename);
      zfile=MStrPrint("%s.Z",local_name);
      if (IsFile(zfile))
      {
        FileWrite(zfile,data,len);
      }
      else
      {
        FileWrite(basename,data,len);
      }
      Free(basename);
      Free(zfile);
    }
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for file %s!\n",filename;
    ClientPutChar(0);
    return 0;
  }
}

public I64 Fput(U8 *filename, U8* remote_name=NULL)
{//Transfers file to remote
  U8 *data, *len_str;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  CDirEntry *de = FilesFind(filename);
  if (!de)
  {
    "Failed to find file %s?\n",filename;
    return 0;
  }
  data = FileRead(de->full_name, &len);
  Free(de);
  if (!len)
  {
    "File %s is empty? Not transferring.\n",filename;
    return 0;
  }
  len_str = MStrPrint("%d",len);
  lenlen = StrLen(len_str);
  ClientPutChar(CMD_FILE_RECV);
  ClientPutChar(lenlen);
  ClientPutS(len_str);
  Free(len_str);
  if (remote_name)
  {
    lenlen = StrLen(remote_name);
    ClientPutChar(lenlen);
    ClientPutS(remote_name);
  }
  else
  {
    lenlen = StrLen(filename);
    ClientPutChar(lenlen);
    ClientPutS(filename);
  }
  ClientPutBlk(data,len);
  if (lenlen == ReadI8)
  {
    "File %s was transferred!\n",filename;
    return len;
  }
  else
    "File %s was not transferred! An unknown error occurred in transfer!\n",filename;
  Free(data);
  return 0;
}

I64 FCmpHash(U8 *filename, U8* remote_name=NULL, Bool silent=TRUE)
{//Compares local file hash to remote hash
  U8 *data=NULL, *len_str;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  CDirEntry *de = FilesFind(filename);
  if (!de)
  {
    "Failed to find file %s?\n",filename;
    return -1;
  }
  md5(de->full_name,&data);
  len=32;
  Free(de);
  if (!len)
  {
    "File %s is empty? Not transferring.\n",filename;
    return -1;
  }
  len_str = MStrPrint("32");
  lenlen = StrLen(len_str);
  ClientPutChar(CMD_CMP_HASH);
  ClientPutChar(lenlen);
  ClientPutS(len_str);
  Free(len_str);
  if (remote_name)
  {
    lenlen = StrLen(remote_name);
    ClientPutChar(lenlen);
    ClientPutS(remote_name);
  }
  else
  {
    lenlen = StrLen(filename);
    ClientPutChar(lenlen);
    ClientPutS(filename);
  }
  ClientPutBlk(data,len);
  Free(data);
  if (lenlen == ReadI8)
  {
    if (!silent)
      "File %s remote hash is the same!\n",filename;
    return 0;
  }
  else if (!silent)
    "File %s remote hash differs or an unknown error occurred in transfer!\n",filename;
  return -1;
}

I64 Dput2(CDirEntry *tmpde,I64 src_dir_len,I64 dst_dir_len,U8 *dst_dir, Bool sync=FALSE, Bool bin_files=TRUE)
{//Used by Dput not for user use.
  U8 *st;
  I64 res=1;

  if (!TOSServerCheck) return -1;

  while (tmpde)
  {
    st=MAlloc(StrLen(tmpde->full_name)+dst_dir_len+2);
    MemCpy(st,dst_dir,dst_dir_len);
    StrCpy(st+dst_dir_len,tmpde->full_name+src_dir_len);
    if (tmpde->attr & RS_ATTR_DIR)
    {
      res+=Dput2(tmpde->sub,src_dir_len,dst_dir_len,dst_dir,sync,bin_files);
    }
    else
    {
      if (!sync)
      {
        if (Fput(tmpde->full_name,st))
          res++;
      }
      else
      {
        // TODO remove this cleanup in Linux instead eventually?
        // Disabling for now, it can fragment the filesystem too much
        /*
        if (StrMatch(".HC",tmpde->full_name) || StrMatch(".DD",tmpde->full_name)
            || StrMatch(".IN",tmpde->full_name))
          CursorRemFile(tmpde->full_name);
        */

        if ((StrMatch("Downloads/Linux",tmpde->full_name) || StrMatch(".DATA",tmpde->full_name) || StrMatch(".ISO",tmpde->full_name) || StrMatch(".BIN",tmpde->full_name)) && !bin_files)
        {
          "Skipping binary/data file %s\n",tmpde->full_name;
          res++;
        }
        else {
          if (0==FCmpHash(tmpde->full_name,st))
          {
            "%s remote copy is already up to date.\n",tmpde->full_name;
            res++;
          }
          else if (Fput(tmpde->full_name,st))
            res++;
        }
      }
    }
    Free(st);
    tmpde=tmpde->next;
  }
  return res;
}

public I64 Dput(U8 *src_files_find_mask,U8 *remote_dir=NULL, Bool no_mask=TRUE,
    Bool sync=FALSE, Bool bin_files=TRUE)
{//Copy directory tree to remote machine.
//Returns the count of copied files (not dirs).
  CDirContext *dirc;
  CDirEntry *tmpde=NULL;
  I64 res=0,i1,i2;
  U8 *st1,*st2;

  if (!TOSServerCheck) return -1;

  st1=DirNameAbs(src_files_find_mask);
  i1=StrLen(st1);
  if (remote_dir)
  {
    i2=StrLen(remote_dir);
    st2=remote_dir;
  }
  else
  {
    i2=StrLen(src_files_find_mask);
    st2=src_files_find_mask;
  }
  if (dirc=DirContextNew(src_files_find_mask,TRUE,,no_mask))
  {
    tmpde=FilesFind(dirc->mask,FUF_RECURSE);
    st1=DirCur;
    DirContextDel(dirc);
    i1=StrLen(st1);
    if (i1==3) i1--;
    res=Dput2(tmpde,i1,i2,st2,sync,bin_files);
    DirTreeDel(tmpde);
    Free(st1);
  }
  return res;
}

public I64 Dsync(U8 *src_files_find_mask,U8 *remote_dir=NULL, Bool no_mask=TRUE, Bool bin_files=FALSE)
{//Sync directory tree to remote (ignores binary by default)
  if (!TOSServerCheck) return -1;

  return Dput(src_files_find_mask,remote_dir, no_mask, TRUE, bin_files);
}

public I64 URLGet(U8 *url, U8 *filename)
{//Gets URL (raw file) to a file from remote
  U8* data;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  ClientPutChar(CMD_URL_GET_RAW);
  ClientPutChar(StrLen(url));
  ClientPutS(url);
  lenlen=ReadI8(2500);
  if (lenlen > 0)
  {
    data=CAlloc(lenlen+1);
    ReadBlock(data,lenlen,2500);
    len=Str2I64(data);
    Free(data);
  }
  else
  {
    "Failed to data (or size is zero)!\n";
    ClientPutChar(0);
    return 0;
  }
  "Fetching %d bytes from URL\n",len;
  data=MAlloc(len+1);
  if (data)
  {
    ClientPutChar(lenlen);
    ReadBlock(data,len);
    FileWrite(filename,data,len);
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for file %s!\n",filename;
    ClientPutChar(0);
    return 0;
  }
}

public U8 *URLGetTextStr(U8 *url)
{//Gets URL (text only) from remote as string
  U8* data;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  ClientPutChar(CMD_URL_GET_TEXT);
  ClientPutChar(StrLen(url));
  ClientPutS(url);
  lenlen=ReadI8(2500);
  if (lenlen > 0)
  {
    data=CAlloc(lenlen+1);
    ReadBlock(data,lenlen,2500);
    len=Str2I64(data);
    Free(data);
  }
  else
  {
    "Failed to read data (or size is zero)!\n";
    ClientPutChar(0);
    return 0;
  }
  "Fetching %d bytes from URL\n",len;
  data=MAlloc(len+1);
  if (data)
  {
    ClientPutChar(lenlen);
    ReadBlock(data,len);
    return data;
  }
  else
  {
    "Failed to malloc space!\n";
    ClientPutChar(0);
    return 0;
  }
}

public U0 URLGetText(U8 *url)
{//Gets URL (text only) and prints result
  U8 *str=URLGetTextStr(url);
  "%s\n",str;
  Free(str);
}

public I64 Hdir(U8 *dir=".")
{//List remote directory contents
  U8* data;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  ClientPutChar(CMD_HDIR);
  ClientPutChar(StrLen(dir));
  ClientPutS(dir);
  lenlen=ReadI8;
  if (lenlen > 0)
  {
    data=CAlloc(lenlen+1);
    ReadBlock(data,lenlen);
    len=Str2I64(data);
    Free(data);
  }
  else
  {
    ClientPutChar(0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    ClientPutChar(lenlen);
    ReadBlock(data,len);
    "%s\n"
    ,data;
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for directory listing!\n";
    ClientPutChar(0);
    return 0;
  }
}

U8 *GetBaseDir(U8 *filename)
{
  U8 *res;
  I64 i,cnt=StrOcc(filename,'/');
  if (!cnt)
    return StrNew("");
  res=StrNew(filename);
  for (i=1; i<StrLen(res); i++)
  {
    if (StrOcc(&res[i],'/')==0)
    {
      res[i-1]=0;
      return res;
    }
  }
}

public U0 DirMks(U8 *dirs)
{//Make an entire directory tree
  Bool s;
  U8 *tmpdir,*ptr;
  if (!StrOcc(dirs,'/'))
  {
    DirMk(dirs);
  }
  else
  {
    s=Silent(1);
    tmpdir=StrNew(dirs);
    ptr=dirs;
    while (StrOcc(ptr,'/'))
    {
      while (*ptr != '/')
      {
        ptr++;
      }
      *ptr=0;
      "Making directory: %s\n"
      ,dirs;
      DirMk(dirs);
      *ptr='/';
      ptr++;
    }
    Silent(s);
    DirMk(dirs);
    Free(tmpdir);
  }
}

U0 FGetFileList(U8 *list, I64 strip=0)
{//TODO just get last directory
  I64 ch, res;
  U8 *ptr=list,*buf,*dst, *base, *local;
  buf=dst=MAlloc(512);
  while (StrOcc(ptr,'\n'))
  {
    if (dst)
    {
      while (*ptr != '\n' && (ch=*ptr++))
        *dst++=ch;
      *dst=0;
      *ptr++;
      local=buf;
      res=strip;
      while (*local && res>0) {
        if (*local=='/') res--;
        local++;
      }
      base=GetBaseDir(local);
      if (StrLen(base))
      {
        DirMks(base);
        res=IsFile(local);
        if (res && 0==FCmpHash(local,buf))
        {
          "%s local copy is already up to date.\n",buf;
        }
        else
          Fget(buf,local);
      }
      else if (StrLen(local))
      {
        res=IsFile(local);
        if (res && 0==FCmpHash(local,buf))
        {
          "%s local copy is already up to date.\n",buf;
        }
        else
          Fget(buf,local);
      }
      Free(base);
      dst=buf;
    }
  }
  Free(buf);
}

public I64 Dget(U8 *dir=".", I64 strip=0)
{//Gets directory from remote
  U8* data;
  I64 len,lenlen;

  if (!TOSServerCheck) return -1;

  ClientPutChar(CMD_GET_DIR);
  ClientPutChar(StrLen(dir));
  ClientPutS(dir);
  lenlen=ReadI8;
  if (lenlen > 0)
  {
    data=CAlloc(lenlen+1);
    ReadBlock(data,lenlen);
    len=Str2I64(data);
    Free(data);
  }
  else
  {
    ClientPutChar(0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    ClientPutChar(lenlen);
    ReadBlock(data,len);
    FGetFileList(data,strip);
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for directory listing!\n";
    ClientPutChar(0);
    return 0;
  }
}

public U8 *ClipGetStr()
{//Get clipboard text from remote as string
  U8 *data;
  I64 len,lenlen;

  if (!TOSServerCheck) return 0;

  ClientPutChar(CMD_GET_CB_TEXT);
  lenlen=ReadI8;
  if (lenlen > 0)
  {
    data=CAlloc(lenlen+1);
    ReadBlock(data,lenlen);
    len=Str2I64(data);
    Free(data);
  }
  else
  {
    "Failed to get clipboard text (or size is zero)!\n";
    ClientPutChar(0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    ClientPutChar(lenlen);
    ReadBlock(data,len);
    return data;
  }
  return 0;
}

public U0 ClipGet()
{//Get clipboard text from remote and print
  if (!TOSServerCheck) return;

  U8 *clip=ClipGetStr;
  "%s\n",clip;
  Free(clip);
}

public U0 ClipPutStr(U8 *send_text)
{//Put text string into clipboard of remote
  if (!TOSServerCheck) return;

  U8 *len_str;
  I64 lenlen,len=StrLen(send_text);
  if (len)
  {
    len_str = MStrPrint("%d",len);
    lenlen = StrLen(len_str);
    ClientPutChar(CMD_SET_CB_TEXT);
    ClientPutChar(lenlen);
    ClientPutS(len_str);
    Free(len_str);
    ClientPutS(send_text);
  }
}

public U8 *HExecToStr(U8 *cmd)
{// Send NON-INTERACTIVE cmd to another PC over serial, execute, return string output
  U8 *len_str, *data;
  I64 lenlen,len=StrLen(cmd);

  if (!TOSServerCheck) return 0;

  if (len)
  {
    len_str = MStrPrint("%d",len);
    lenlen = StrLen(len_str);
    ClientPutChar(CMD_HOST_EXEC);
    ClientPutChar(lenlen);
    ClientPutS(len_str);
    Free(len_str);
    ClientPutS(cmd);
    lenlen=ReadI8;
    if (lenlen > 0)
    {
      data=CAlloc(lenlen+1);
      ReadBlock(data,lenlen);
      len=Str2I64(data);
      Free(data);
    }
    else
    {
      "Failed to get result string (or got 0 bytes)!\n";
      ClientPutChar(0);
      return 0;
    }
    data=MAlloc(len+1);
    if (data)
    {
      ClientPutChar(lenlen);
      ReadBlock(data,len);
      data[len]=0;
      return data;
    }
  }
}

public U0 HExec(U8 *cmd)
{// Send NON-INTERACTIVE cmd to another PC over serial, execute, print output
  if (!TOSServerCheck) return;

  U8 *res=HExecToStr(cmd);
  "%s\n",res;
  Free(res);
}

U0 ClientCopyCBToHost()
{
  U8 *str=DocDumpToStr(sys_clip_doc);
  if (str) ClipPutStr(str);
  Free(str);
}

U0 ClientCopyCBFromHost()
{
  U8 *host_cb=ClipGetStr;
  if (host_cb)
  {
    ClipDel;
    DocPrint(sys_clip_doc,host_cb);
  }
  Free(host_cb);
}

public U0 ClientClipHijack()
{// Send/get clipboard to/from remote machine automatically
  Bool have_server=ProbeComm;

  if (have_server)
  {
    HijackFunc(&ClipCutCB,&ClientCopyCBToHost);
    HijackFunc(&ClipCopyCB,&ClientCopyCBToHost);
    HijackFunc(&ClipPasteCB,&ClientCopyCBFromHost);
  }
  else
    "Could not find server to connect to!\n";
}

public U0 ClipPut()
{//Put clipboard text to remote clipboard
  ClientCopyCBToHost;
}

// TODO add/create DolDoc web surf functionality after https added (if ever?)
#help_index ""
