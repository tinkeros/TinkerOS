#help_index "TOSClient/TOSServer"

#ifndef md5buf
#include "::/Adam/Opt/Utils/MD5"
#endif

#define TSS_SOCKET	1
#define TSS_CLOSE	2
#define TSS_CONNECT_TCP	3
#define TSS_SEND	4
#define TSS_RECV	5
#define TSS_RECV_FILE	6
#define TSS_SEND_FILE	7
#define TSS_ID		8
#define TSS_URL_RAW	9
#define TSS_HDIR	10
#define TSS_GET_DIR	11
#define TSS_CMP_HASH	12
#define TSS_GET_CB	13
#define TSS_SET_CB	14
#define TSS_HOST_EXEC	15
#define TSS_URL_TEXT	16
#define TSS_GET_OS	17
#define TSS_HELLO	0xAA

#define TSS_BYTE_MS	2000
#define TSS_TX_CHUNK	1024
#define TSS_MAX_LEN	0x8000000
#define TSS_SOCKS	16
#define TSS_STOP_MS	3000

class CTOSSrv
{
  I64	com;
  CTask	*task;
  U8	*root;
  Bool	stop,
	exec,
	fg,
	own_com;
  I64	cmds,files_in,files_out,bytes_in,bytes_out,errs;
  I64	socks[TSS_SOCKS];
  Bool	sock_used[TSS_SOCKS];
  U8	last[80];
};

CTOSSrv *tos_srvs[MAX_COMM_NUM+1];
MemSet(tos_srvs,0,(MAX_COMM_NUM+1)*sizeof(CTOSSrv *));

I64 (*fp_tss_connect)(U8 *host,I64 port)=NULL;
I64 (*fp_tss_send)(I64 sock,U8 *buf,I64 len)=NULL;
I64 (*fp_tss_recv)(I64 sock,U8 *buf,I64 len)=NULL;
U0 (*fp_tss_close)(I64 sock)=NULL;
U8 *(*fp_tss_url)(U8 *url,Bool text,I64 *_len)=NULL;
Bool (*fp_tss_rem_com)(I64 com)=NULL;

U0 TSSLog(CTOSSrv *s,U8 *fmt,...)
{//Foreground: on screen. Background: the Adam log.
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  I64 n=MinI64(StrLen(st),79);
  MemCpy(s->last,st,n);
  s->last[n]=0;
  if (s->fg)
    "%s\n",st;
  else
    AdamLog("TOSServer COM%d: %s\n",s->com,st);
  Free(st);
}

Bool TSSRx(CTOSSrv *s,U8 *buf,I64 n)
{//n bytes, at most TSS_BYTE_MS between two of them. FALSE on a timeout.
  F64 t=tS+TSS_BYTE_MS/1000.0;
  while (n>0)
  {
    if (CommGetCharNoWait(s->com,buf))
    {
      buf++;
      n--;
      s->bytes_in++;
      t=tS+TSS_BYTE_MS/1000.0;
    }
    else if (tS>t || s->stop)
      return FALSE;
    else
      Yield;
  }
  return TRUE;
}

I64 TSSRxU8(CTOSSrv *s)
{//A byte, -1 on a timeout.
  U8 b;
  if (TSSRx(s,&b,1))
    return b;
  return -1;
}

U8 *TSSRxBlk(CTOSSrv *s,I64 len)
{//len bytes and a terminating 0, NULL on a timeout or a bad length.
  U8 *buf;
  if (!(0<=len<=TSS_MAX_LEN))
    return NULL;
  buf=MAlloc(len+1);
  if (!TSSRx(s,buf,len))
  {
    Free(buf);
    return NULL;
  }
  buf[len]=0;
  return buf;
}

U8 *TSSRxStr(CTOSSrv *s)
{//A string sent as a length byte and the characters.
  I64 n=TSSRxU8(s);
  if (n<0)
    return NULL;
  return TSSRxBlk(s,n);
}

I64 TSSRxLen(CTOSSrv *s)
{//A length sent as a byte count and decimal digits ("\x032048"), -1 if bad.
  U8 b[24];
  I64 n=TSSRxU8(s);
  if (!(0<n<20))
    return -1;
  if (!TSSRx(s,b,n))
    return -1;
  b[n]=0;
  return Str2I64(b);
}

Bool TSSTx(CTOSSrv *s,U8 *buf,I64 n)
{//FALSE if the port gave up ('ComErr').
  I64 k;
  Bool ok=TRUE;
  try
  {
    while (n>0)
    {
      k=MinI64(n,TSS_TX_CHUNK);
      CommPutBlk(s->com,buf,k);
      buf+=k;
      n-=k;
      s->bytes_out+=k;
    }
  }
  catch
  {
    Fs->catch_except=TRUE;
    ok=FALSE;
  }
  return ok;
}

Bool TSSTxU8(CTOSSrv *s,U8 b)
{
  return TSSTx(s,&b,1);
}

Bool TSSTxData(CTOSSrv *s,U8 *data,I64 len)
{//A reply with a length: length, the client's ack, then the data.
  U8 ls[24];
  I64 n,ack;
  StrPrint(ls,"%d",len);
  n=StrLen(ls);
  if (!TSSTxU8(s,n))
    return FALSE;
  if (!TSSTx(s,ls,n))
    return FALSE;
  ack=TSSRxU8(s);
  if (ack!=n)
  {
    TSSLog(s,"No ack from the client (%d, expected %d)",ack,n);
    return FALSE;
  }
  return TSSTx(s,data,len);
}

Bool TSSPathOk(CTOSSrv *s,U8 *name)
{//Only names inside the transfer directory.
  if (!*name || *name=='/' || *name=='~' || *name=='.' && name[1]=='.' ||
      StrOcc(name,':') || StrFind("/..",name))
  {
    TSSLog(s,"Refused name outside the transfer directory: %s",name);
    return FALSE;
  }
  return TRUE;
}

U8 *TSSFind(U8 *name)
{//Full name of name, or of name with .Z added or removed. NULL if neither.
  CDirEntry de;
  if (FileFind(name,&de,FUF_Z_OR_NOT_Z|FUF_JUST_FILES))
    return de.full_name;
  return NULL;
}

Bool TSSMkParent(CTOSSrv *s,U8 *name)
{//Make the directories name is in.
  I64 i=StrLen(name);
  U8 *d;
  Bool ok;
  while (i>0 && name[i-1]!='/')
    i--;
  if (i<=1)
    return TRUE;
  d=MAlloc(i);
  MemCpy(d,name,i-1);
  d[i-1]=0;
  ok=Cd(d,TRUE);
  Cd(s->root);
  Free(d);
  return ok;
}

U8 *TSSCat(U8 *st,U8 *add)
{//st followed by "\n" and add. Frees st.
  U8 *res=MStrPrint("%s\n%s",st,add);
  Free(st);
  return res;
}

U0 TSSSendFile(CTOSSrv *s)
{//Client's Fget.
  U8 *name=TSSRxStr(s),*full=NULL,*data=NULL;
  I64 len=0;
  if (!name)
    return;
  if (TSSPathOk(s,name))
    full=TSSFind(name);
  if (full)
    data=FileRead(full,&len);
  if (data)
  {
    if (TSSTxData(s,data,len))
    {
      s->files_out++;
      TSSLog(s,"Sent %s (%d bytes)",name,len);
    }
  }
  else
  {
    TSSLog(s,"No file %s",name);
    TSSTxU8(s,0);
  }
  Free(data);
  Free(full);
  Free(name);
}

U0 TSSRecvFile(CTOSSrv *s)
{//Client's Fput. Into name, or into name.Z if that is the one that exists.
  I64 len=TSSRxLen(s),n;
  U8 *name=TSSRxStr(s),*data=NULL,*full=NULL;
  Bool ok=FALSE;
  if (name)
    data=TSSRxBlk(s,len);
  if (data && TSSPathOk(s,name))
  {
    try
    {
      if (TSSMkParent(s,name))
      {
        if (full=TSSFind(name))
          FileWrite(full,data,len);
        else
          FileWrite(name,data,len);
        ok=TRUE;
      }
    }
    catch
      Fs->catch_except=TRUE;
  }
  if (ok)
  {
    s->files_in++;
    TSSLog(s,"Received %s (%d bytes)",name,len);
    n=StrLen(name)&255;
    if (!n)
      n=1;
    TSSTxU8(s,n);
  }
  else
  {
    if (name)
      TSSLog(s,"Could not receive %s",name);
    TSSTxU8(s,0);
  }
  Free(full);
  Free(data);
  Free(name);
}

U0 TSSCmpHash(CTOSSrv *s)
{//Client's FCmpHash: the name's length back if the MD5 sums match, 0 if not.
  I64 len=TSSRxLen(s),size,res=0;
  U8 *name=TSSRxStr(s),*hash=NULL,*full=NULL,*data=NULL,*mine=NULL;
  if (name && len==32)
    hash=TSSRxBlk(s,32);
  if (hash && TSSPathOk(s,name))
    full=TSSFind(name);
  if (full)
    data=FileRead(full,&size);
  if (data)
  {
    md5buf(data,size,&mine);
    if (mine && !StrCmp(mine,hash))
      res=StrLen(name)&255;
  }
  if (res)
    TSSLog(s,"%s unchanged",name);
  else
    TSSLog(s,"%s differs",name);
  TSSTxU8(s,res);
  Free(mine);
  Free(data);
  Free(full);
  Free(hash);
  Free(name);
}

U8 *TSSDirStr(CTOSSrv *s,U8 *dir,Bool recurse)
{//Dir's entries, one per line. NULL if dir is not a directory.
  CDirEntry *de,*de1;
  U8 *st,*cur,*line;
  I64 i;
  Bool dot=!StrCmp(dir,".");
  if (!dot && !Cd(dir))
  {
    Cd(s->root);
    return NULL;
  }
  cur=DirCur;
  i=StrLen(cur);
  if (i==3)
    i--;
  st=StrNew("");
  if (recurse)
    de=FilesFind("*",FUF_RECURSE|FUF_JUST_FILES);
  else
    de=FilesFind("*");
  de1=de;
  while (de1)
  {
    if (StrCmp(de1->name,".") && StrCmp(de1->name,".."))
    {
      if (!recurse)
        st=TSSCat(st,de1->name);
      else
      {
        if (dot)
          line=StrNew(de1->full_name+i+1);
        else
          line=MStrPrint("%s/%s",dir,de1->full_name+i+1);
        st=TSSCat(st,line);
        Free(line);
      }
    }
    de1=de1->next;
  }
  DirTreeDel(de);
  Free(cur);
  Cd(s->root);
  return TSSCat(st,"");
}

U0 TSSDir(CTOSSrv *s,Bool recurse)
{//Client's Hdir (recurse FALSE) and Dget (TRUE).
  U8 *dir=TSSRxStr(s),*st=NULL;
  I64 n;
  if (!dir)
    return;
  n=StrLen(dir);
  while (n>1 && dir[n-1]=='/')
    dir[--n]=0;
  if (TSSPathOk(s,dir))
    st=TSSDirStr(s,dir,recurse);
  if (st)
  {
    TSSLog(s,"Listed %s",dir);
    TSSTxData(s,st,StrLen(st)+1);
  }
  else
  {
    TSSLog(s,"No directory %s",dir);
    TSSTxU8(s,0);
  }
  Free(st);
  Free(dir);
}

U8 *TSSDocText(CDoc *doc)
{//The plain text of doc: its text, tabs and line ends.
  CDocEntry *doc_e;
  I64 n=1;
  U8 *res,*p;
  Bool unlock=DocLock(doc);
  for (doc_e=doc->head.next; doc_e!=doc; doc_e=doc_e->next)
    if (doc_e->type_u8==DOCT_TEXT)
      n+=StrLen(doc_e->tag);
    else
      n++;
  res=p=MAlloc(n);
  for (doc_e=doc->head.next; doc_e!=doc; doc_e=doc_e->next)
    if (doc_e->type_u8==DOCT_TEXT)
    {
      StrCpy(p,doc_e->tag);
      p+=StrLen(p);
    }
    else if (doc_e->type_u8==DOCT_NEW_LINE)
      *p++='\n';
    else if (doc_e->type_u8==DOCT_TAB)
      *p++='\t';
  *p=0;
  if (unlock)
    DocUnlock(doc);
  return res;
}

U0 TSSGetClip(CTOSSrv *s)
{//Client's ClipGetStr: this machine's clipboard as text.
  U8 *st=TSSDocText(sys_clip_doc);
  TSSLog(s,"Clipboard sent (%d bytes)",StrLen(st));
  TSSTxData(s,st,StrLen(st));
  Free(st);
}

U0 TSSSetClip(CTOSSrv *s)
{//Client's ClipPutStr. No reply. a dollar sign is doubled so it stays plain text.
  I64 len=TSSRxLen(s),i,j=0;
  U8 *st=TSSRxBlk(s,len),*esc;
  if (!st)
    return;
  esc=MAlloc(2*len+1);
  for (i=0; i<len; i++)
  {
    if (st[i]=='$$')
      esc[j++]='$$';
    esc[j++]=st[i];
  }
  esc[j]=0;
  ClipDel;
  DocPrint(sys_clip_doc,"%s",esc);
  TSSLog(s,"Clipboard set (%d bytes)",len);
  Free(esc);
  Free(st);
}

U8 *TSSExec(U8 *code)
{//Run HolyC code in this task and return what it printed.
  CDoc *doc=DocNew,*old=Fs->put_doc;
  U8 *res;
  Bool old_raw=Raw(OFF),old_silent=Silent(OFF);
  Fs->put_doc=doc;
  try
    ExePutS(code);
  catch
  {
    "\nException: ";
    PutExcept;
  }
  Fs->put_doc=old;
  Silent(old_silent);
  Raw(old_raw);
  res=TSSDocText(doc);
  DocDel(doc);
  return res;
}

U0 TSSHostExec(CTOSSrv *s)
{//Client's HExec: here the command is HolyC, not a shell command.
  I64 len=TSSRxLen(s);
  U8 *code=TSSRxBlk(s,len),*res;
  if (!code)
    return;
  if (s->exec)
  {
    TSSLog(s,"HExec %s",code);
    res=TSSExec(code);
  }
  else
  {
    TSSLog(s,"HExec refused (exec is off)");
    res=StrNew("TOSServer: HExec is off. Start the server with exec=TRUE.\n");
  }
  TSSTxData(s,res,StrLen(res));
  Free(res);
  Free(code);
}

U0 TSSUrl(CTOSSrv *s,Bool text)
{//Client's URLGet and URLGetTextStr: http only, through Demo/Net.
  U8 *url=TSSRxStr(s),*data=NULL;
  I64 len=0;
  if (!url)
    return;
  if (fp_tss_url)
    data=(*fp_tss_url)(url,text,&len);
  else
    TSSLog(s,"URL fetch needs the network (#include \"::/Demo/Net/Start\")");
  if (data)
  {
    TSSLog(s,"Fetched %s (%d bytes)",url,len);
    TSSTxData(s,data,len);
  }
  else
  {
    TSSLog(s,"Could not fetch %s",url);
    TSSTxU8(s,0);
  }
  Free(data);
  Free(url);
}

I64 TSSSockArg(CTOSSrv *s)
{//A socket number byte: the number if it is in use, 0 if not, -1 on a timeout.
  I64 fd=TSSRxU8(s);
  if (fd<0)
    return -1;
  if (!(0<fd<TSS_SOCKS))
    return 0;
  if (!s->sock_used[fd])
    return 0;
  return fd;
}

U0 TSSSockClose(CTOSSrv *s,I64 fd)
{
  if (s->socks[fd] && fp_tss_close)
    (*fp_tss_close)(s->socks[fd]);
  s->socks[fd]=0;
  s->sock_used[fd]=FALSE;
}

U0 TSSSock(CTOSSrv *s,I64 cmd)
{//The socket commands: this machine makes the TCP connections for the client.
  I64 fd,len,port,n;
  U8 *host,buf[256],a[2];
  switch (cmd)
  {
    case TSS_SOCKET:
      if (!TSSRx(s,a,2))
        return;
      for (fd=1; fd<TSS_SOCKS; fd++)
        if (!s->sock_used[fd])
          break;
      if (fd<TSS_SOCKS && fp_tss_connect)
      {
        s->sock_used[fd]=TRUE;
        s->socks[fd]=0;
        TSSTxU8(s,fd);
      }
      else
        TSSTxU8(s,0xFF);
      break;
    case TSS_CLOSE:
      if ((fd=TSSSockArg(s))<0)
        return;
      if (fd)
      {
        TSSSockClose(s,fd);
        TSSLog(s,"Socket %d closed",fd);
      }
      TSSTxU8(s,0);
      break;
    case TSS_CONNECT_TCP:
      if ((fd=TSSSockArg(s))<0)
        return;
      if (!(host=TSSRxStr(s)))
        return;
      if (!TSSRx(s,a,2))
      {
        Free(host);
        return;
      }
      port=a[0]|a[1]<<8;
      if (fd && fp_tss_connect)
        s->socks[fd]=(*fp_tss_connect)(host,port);
      if (fd && s->socks[fd])
      {
        TSSLog(s,"Socket %d connected to %s:%d",fd,host,port);
        TSSTxU8(s,0);
      }
      else
      {
        TSSLog(s,"Socket %d could not connect to %s:%d",fd,host,port);
        TSSTxU8(s,0xFF);
      }
      Free(host);
      break;
    case TSS_RECV:
      if ((fd=TSSSockArg(s))<0)
        return;
      if (!TSSRx(s,a,2))
        return;
      n=0;
      if (fd && s->socks[fd] && fp_tss_recv)
        n=ClampI64((*fp_tss_recv)(s->socks[fd],buf,a[0]),0,a[0]);
      if (TSSTxU8(s,n))
        TSSTx(s,buf,n);
      break;
    case TSS_SEND:
      if ((fd=TSSSockArg(s))<0)
        return;
      if (!TSSRx(s,a,2))
        return;
      len=a[0];
      if (!TSSRx(s,buf,len))
        return;
      n=0;
      if (fd && s->socks[fd] && fp_tss_send)
        n=ClampI64((*fp_tss_send)(s->socks[fd],buf,len),0,255);
      TSSTxU8(s,n);
      break;
  }
}

U0 TSSCmd(CTOSSrv *s,I64 cmd)
{
  switch (cmd)
  {
    case TSS_HELLO:
      TSSTxU8(s,TSS_HELLO);
      break;
    case TSS_ID:
      TSSLog(s,"Found by a client");
      TSSTx(s,"TOSSERVER",9);
      break;
    case TSS_SEND_FILE:
      TSSSendFile(s);
      break;
    case TSS_RECV_FILE:
      TSSRecvFile(s);
      break;
    case TSS_CMP_HASH:
      TSSCmpHash(s);
      break;
    case TSS_HDIR:
      TSSDir(s,FALSE);
      break;
    case TSS_GET_DIR:
      TSSDir(s,TRUE);
      break;
    case TSS_GET_CB:
      TSSGetClip(s);
      break;
    case TSS_SET_CB:
      TSSSetClip(s);
      break;
    case TSS_HOST_EXEC:
      TSSHostExec(s);
      break;
    case TSS_GET_OS:
      TSSTxData(s,"TinkerOS",8);
      break;
    case TSS_URL_RAW:
      TSSUrl(s,FALSE);
      break;
    case TSS_URL_TEXT:
      TSSUrl(s,TRUE);
      break;
    case TSS_SOCKET...TSS_RECV:
      TSSSock(s,cmd);
      break;
    case 0:
      break;
    default:
      TSSLog(s,"Unknown command %d",cmd);
  }
}

U0 TSSLoop(CTOSSrv *s)
{//Commands until TOSServerStop (or Esc in the foreground).
  U8 b;
  F64 last=tS;
  Cd(s->root);
  while (!s->stop)
  {
    if (s->fg && ScanChar==CH_ESC)
      break;
    if (CommGetCharNoWait(s->com,&b))
    {
      s->bytes_in++;
      s->cmds++;
      try
        TSSCmd(s,b);
      catch
      {
        Fs->catch_except=TRUE;
        s->errs++;
        TSSLog(s,"Exception in command %d",b);
      }
      Cd(s->root);
      last=tS;
    }
    else if (tS-last>0.25)
      Sleep(1);
    else
      Yield;
  }
}

U0 TSSEnd(CTOSSrv *s)
{//Close the server's sockets (and its TCP port) and free it.
  I64 fd;
  for (fd=1; fd<TSS_SOCKS; fd++)
    TSSSockClose(s,fd);
  tos_srvs[s->com]=NULL;
  comm_ports[s->com].probe_skip=FALSE;
  if (s->own_com && fp_tss_rem_com)
    (*fp_tss_rem_com)(s->com);
  Free(s->root);
  Free(s);
}

U0 TSSTask(CTOSSrv *s)
{
  TSSLoop(s);
  TSSEnd(s);
}

public Bool TOSServerOn(I64 com)
{//TRUE if a TOSServer answers on COM com.
  if (!(1<=com<=MAX_COMM_NUM))
    return FALSE;
  return tos_srvs[com]!=NULL;
}

public I64 TOSServer(I64 com=1,U8 *dir="~/TOSXfr",Bool exec=FALSE,
	Bool bg=TRUE,Bool own_com=FALSE)
{//Answer TOSClient on COM com, with files in dir (made if missing).
  CTOSSrv *s;
  U8 *root,*cur;
  Bool ok;
  if (!CommExists(1))
    Adam("CommInit;\n");
  if (!CommExists(com))
  {
    "TOSServer: there is no COM %d (CommRep lists them).\n",com;
    return 0;
  }
  if (tos_srvs[com])
  {
    "TOSServer: one already runs on COM %d.\n",com;
    return 0;
  }
  root=DirNameAbs(dir);
  cur=DirCur;
  ok=Cd(root,TRUE);
  Cd(cur);
  Free(cur);
  if (!ok)
  {
    "TOSServer: cannot use directory %s.\n",root;
    Free(root);
    return 0;
  }
  CommInit8n1(com,115200);
  CommFlush(com);
  s=CAlloc(sizeof(CTOSSrv),adam_task);
  s->com=com;
  s->root=StrNew(root,adam_task);
  s->exec=exec;
  s->own_com=own_com;
  s->fg=!bg;
  tos_srvs[com]=s;
  comm_ports[com].probe_skip=TRUE;
  "TOSServer on COM %d, files in %s, HExec %Z.\n",com,root,exec,"ST_OFF_ON";
  Free(root);
  if (bg)
    s->task=Spawn(&TSSTask,s,"TOSServer",,adam_task);
  else
  {
    "Press Esc to stop.\n";
    cur=DirCur;
    TSSLoop(s);
    Cd(cur);
    Free(cur);
    TSSEnd(s);
    "TOSServer on COM %d stopped.\n",com;
  }
  return com;
}

public I64 TOSServerStop(I64 com=0)
{//Stop the server on COM com, or all of them (0). Returns how many stopped.
  I64 i,res=0;
  CTOSSrv *s;
  CTask *task;
  F64 t;
  for (i=1; i<=MAX_COMM_NUM; i++)
  {
    s=tos_srvs[i];
    if (s && (!com || com==i) && !s->fg)
    {
      task=s->task;
      s->stop=TRUE;
      t=tS+TSS_STOP_MS/1000.0;
      while (TaskValidate(task) && tS<t)
        Sleep(10);
      if (TaskValidate(task))
      {
        Kill(task);
        TSSEnd(s);
      }
      "TOSServer on COM %d stopped.\n",i;
      res++;
    }
  }
  if (!res)
    "TOSServer: none running.\n";
  return res;
}

public U0 TOSServerRep()
{//What each running TOSServer has done.
  I64 i,n=0;
  CTOSSrv *s;
  for (i=1; i<=MAX_COMM_NUM; i++)
    if (s=tos_srvs[i])
    {
      "COM %d: files in %s, HExec %Z",i,s->root,s->exec,"ST_OFF_ON";
      if (s->own_com)
        ", TCP port made for it";
      "\n";
      "  %d requests, %d files received, %d sent, %d bytes in, %d out, %d errors\n",
	    s->cmds,s->files_in,s->files_out,s->bytes_in,s->bytes_out,s->errs;
      "  Last: %s\n",s->last;
      n++;
    }
  if (!n)
    "No TOSServer running.\n";
}
#help_index ""
