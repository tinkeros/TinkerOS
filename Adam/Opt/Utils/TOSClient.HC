#define CMD_URL_GET 9
#define CMD_HDIR 10
#define CMD_GET_DIR 11
#define CMD_CMP_HASH 12

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
  CommPutChar(SNAIL_COM, CMD_CMP_HASH);
  CommPutChar(SNAIL_COM, lenlen);
  CommPutS(SNAIL_COM,len_str);
  Free(len_str);
  if (remote_name)
  {
    lenlen = StrLen(remote_name);
    CommPutChar(SNAIL_COM, lenlen);
    CommPutS(SNAIL_COM,remote_name);
  }
  else
  {
    lenlen = StrLen(filename);
    CommPutChar(SNAIL_COM, lenlen);
    CommPutS(SNAIL_COM,filename);
  }
  CommPutBlk(SNAIL_COM,data,len);
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
        if ((StrMatch(".HC",tmpde->full_name)) || (StrMatch(".DD",tmpde->full_name)) || (StrMatch(".IN",tmpde->full_name)))
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
  CommPutChar(SNAIL_COM, CMD_URL_GET);
  CommPutChar(SNAIL_COM, StrLen(url));
  CommPutS(SNAIL_COM,url);
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
    CommPutChar(SNAIL_COM, 0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    CommPutChar(SNAIL_COM, lenlen);
    ReadBlock(data,len);
    FileWrite(filename,data,len);
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for file %s!\n",filename;
    CommPutChar(SNAIL_COM, 0);
    return 0;
  }
}

I64 Hdir(U8 *dir=".")
{//Gets URL from another PC over serial
  U8* data;
  I64 len,lenlen;
  SocketInit;
  CommPutChar(SNAIL_COM, CMD_HDIR);
  CommPutChar(SNAIL_COM, StrLen(dir));
  CommPutS(SNAIL_COM,dir);
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
    CommPutChar(SNAIL_COM, 0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    CommPutChar(SNAIL_COM, lenlen);
    ReadBlock(data,len);
    "%s\n"
    ,data;
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for directory listing!\n";
    CommPutChar(SNAIL_COM, 0);
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
      while ((*ptr != '\n') && (ch=*ptr++))
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
  CommPutChar(SNAIL_COM, CMD_GET_DIR);
  CommPutChar(SNAIL_COM, StrLen(dir));
  CommPutS(SNAIL_COM,dir);
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
    CommPutChar(SNAIL_COM, 0);
    return 0;
  }
  data=MAlloc(len);
  if (data)
  {
    CommPutChar(SNAIL_COM, lenlen);
    ReadBlock(data,len);
    FGetFileList(data);
    Free(data);
    return len;
  }
  else
  {
    "Failed to malloc space for directory listing!\n";
    CommPutChar(SNAIL_COM, 0);
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