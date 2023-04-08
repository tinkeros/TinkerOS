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
#define CMD_URL_GET 9
#define CMD_HDIR 10
#define CMD_GET_DIR 11
#define CMD_CMP_HASH 12

public I8 SNAIL_COM=-1;
public I64 SNAIL_PORT=-1;

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

public U0 ProbeComm()
{
  I64 i,j;
  U8 tmp_buf[17], tmp_byte;
  MemSet(tmp_buf,0,17);
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    if (comm_ports[i].base)
    {
      "Checking COMM %d - ",i;
      CommInit8n1(i, 115200);
      CommPutChar(i,0xAA);
      Sleep(1);
      if (CommGetCharNoWait(i,&tmp_byte))
      {
        if (tmp_byte==0xAA)
        {
          CommPutChar(i,CMD_ID);
          Sleep(200);
          for (j=0; j<16; j++)
          {
            Sleep(5);
            if (CommGetCharNoWait(i,&tmp_byte))
            {
              tmp_buf[j]=tmp_byte;
            }
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

static U8 ReadByte()
{
  U8 chr;
  while (1)
  {
    if (ClientGetCharNoWait(&chr))
      return chr;
    else
      Yield;
  }
}

static I8 ReadI8()
{
  I8 chr;
  while (1)
  {
    if (ClientGetCharNoWait(&chr))
      return chr;
    else
      Yield;
  }
}

static U0 ReadBlock(U8* buf, I64 count)
{
  while (count)
  {
    if (ClientGetCharNoWait(buf))
    {
      buf++;
      count--;
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
        "$FG,6$Failed to initialize Snail -- wrong hello 0x%02X\n", chr;
        "Are you using the right version of snail.py?\n$FG$";
        throw;
      }
      return chr;
    }
    else
      Yield;
  }
  while (cnts.jiffies < max_time);
  "$FG,6$Failed to initialize Snail -- make sure COM%d "
  "is properly configured & snail.py is running!\n$FG$"
  , SNAIL_COM;
  throw;
}


// TODO add this back when adding network support
// TODO disable other net functions below when real
// net is available also!
/*
if (!HashFind("SocketInit",adam_task->hash_table,HTT_FUN))
{

 Adam("I64 SocketInit(){if (SNAIL_COM>0) SocketInitComm;}\n");
}
*/

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

I64 Fget(U8 *filename, U8 *local_name=NULL)
{//Gets file from another PC over serial
  U8 *data, *basename, *zfile;
  I64 len,lenlen;
  SocketInit;
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


I64 Fput(U8 *filename, U8* remote_name=NULL)
{//Transfers file using to another PC over serial
  U8 *data, *len_str;
  I64 len,lenlen;
  SocketInit;
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
{
  U8 *data=NULL, *len_str;
  I64 len,lenlen;
  SocketInit;
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



I64 Dput2(CDirEntry *tmpde,I64 src_dir_len,I64 dst_dir_len,U8 *dst_dir, Bool sync=FALSE)
{
  U8 *st;
  I64 res=1;
  while (tmpde)
  {
    st=MAlloc(StrLen(tmpde->full_name)+dst_dir_len+2);
    MemCpy(st,dst_dir,dst_dir_len);
    StrCpy(st+dst_dir_len,tmpde->full_name+src_dir_len);
    if (tmpde->attr & RS_ATTR_DIR)
    {
      res+=Dput2(tmpde->sub,src_dir_len,dst_dir_len,dst_dir,sync);
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
        if (StrMatch(".HC",tmpde->full_name) || StrMatch(".DD",tmpde->full_name) || StrMatch(".IN",tmpde->full_name))
          CursorRemFile(tmpde->full_name);
        if (0==FCmpHash(tmpde->full_name,st))
        {
          "%s remote copy is already up to date.\n",tmpde->full_name;
          res++;
        }
        else if (Fput(tmpde->full_name,st))
          res++;
      }
    }
    Free(st);
    tmpde=tmpde->next;
  }
  return res;
}


public I64 Dput(U8 *src_files_find_mask,U8 *remote_dir=NULL, Bool no_mask=TRUE, Bool sync=FALSE)
{//Copy directory tree.
//Returns the count of copied files (not dirs).
  CDirContext *dirc;
  CDirEntry *tmpde=NULL;
  I64 res=0,i1,i2;
  U8 *st1,*st2;
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
    res=Dput2(tmpde,i1,i2,st2,sync);
    DirTreeDel(tmpde);
    Free(st1);
  }
  return res;
}

public I64 Dsync(U8 *src_files_find_mask,U8 *remote_dir=NULL, Bool no_mask=TRUE)
{
  return Dput(src_files_find_mask,remote_dir, no_mask, TRUE);
}


I64 URLget(U8 *url, U8 *filename)
{//Gets URL from another PC over serial
  U8* data;
  I64 len,lenlen;
  SocketInit;
  ClientPutChar(CMD_URL_GET);
  ClientPutChar(StrLen(url));
  ClientPutS(url);
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

I64 Hdir(U8 *dir=".")
{//Gets URL from another PC over serial
  U8* data;
  I64 len,lenlen;
  SocketInit;
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
  for(i=1; i<StrLen(res); i++)
  {
    if (StrOcc(&res[i],'/')==0)
    {
      res[i-1]=0;
      return res;
    }
  }
}


U0 DirMks(U8 *dirs)
{
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


U0 FGetFileList(U8 *list)
{//TODO just get last directory
  I64 ch, res;
  U8 *ptr=list,*buf,*dst, *base;
  buf=dst=MAlloc(512);
  while (StrOcc(ptr,'\n'))
  {
    if (dst)
    {
      while (*ptr != '\n' && (ch=*ptr++))
        *dst++=ch;
      *dst=0;
      *ptr++;
      base=GetBaseDir(buf);
      if (StrLen(base))
      {
        DirMks(base);
        res=IsFile(buf);
        if (res && 0==FCmpHash(buf))
        {
          "%s local copy is already up to date.\n",buf;
        }
        else
          Fget(buf,buf);
      }
      Free(base);
      dst=buf;
    }
  }
  Free(buf);
}


I64 Dget(U8 *dir=".")
{//Gets directory from another PC over serial
  U8* data;
  I64 len,lenlen;
  SocketInit;
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
    FGetFileList(data);
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


// TODO add/create DolDoc web functionality after https added
/*
U0 DDWeb(U8 *url="https://github.com/tinkeros/TinkerOS/raw/main/Doc/HelpIndex.DD")
{//U8 *filename=StrNew("WebTmp.DD");
  URLget(url,"B:/WebTmp.DD");
//Free(filename);
  //User("WinMax;Ed(\"WebTmp.DD\");\n");
}
*/
