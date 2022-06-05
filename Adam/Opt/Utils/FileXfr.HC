#include "::/Adam/Net/SnailLite"

I64 Fget(U8 *filename, U8 *local_name=NULL)
{//Gets file from another PC over serial
  U8 *data, *basename, *zfile;
  I64 len,lenlen;
  SocketInit;
  CommPutChar(SNAIL_COM, CMD_FILE_SEND);
  CommPutChar(SNAIL_COM, StrLen(filename));
  CommPutS(SNAIL_COM,filename);
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
    CommPutChar(SNAIL_COM, 0);
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
  CommPutChar(SNAIL_COM, CMD_FILE_RECV);
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


