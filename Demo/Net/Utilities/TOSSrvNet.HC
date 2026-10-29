#help_index "TOSClient/TOSServer;Networking"

#ifndef TOSServer
#include "::/Adam/Opt/Utils/TOSServer"
#endif

#define TSS_NET_MS	5000
#define TSS_RECV_MS	200

I64 TSSNetConnect(U8 *host,I64 port)
{
  CTCPSock *sock;
  if (!ipv4_globals.local_ip)
    return 0;
  sock=TCPConnectionCreate(host,port);
  return sock;
}

I64 TSSNetSend(CTCPSock *sock,U8 *buf,I64 len)
{
  sock->timeout=TSS_NET_MS;
  return TCPSockSendAll(sock,buf,len);
}

I64 TSSNetRecv(CTCPSock *sock,U8 *buf,I64 len)
{
  sock->timeout=TSS_RECV_MS;
  return TCPSockRx(sock,buf,len);
}

U0 TSSNetClose(CTCPSock *sock)
{
  sock->timeout=COMM_TCP_CLOSE_MS;
  TCPSockClose(sock);
}

U8 *TSSHtmlText(U8 *html,I64 len,I64 *_len)
{//The text of an HTML page: no tags, scripts or styles.
  U8 *res=MAlloc(len+1),*p=html,*end=html+len,*q;
  I64 n=0;
  Bool space=FALSE;
  while (p<end)
  {
    if (*p=='<')
    {
      if (!MemCmp(p,"<script",7) || !MemCmp(p,"<SCRIPT",7))
        q=StrIMatch("</script",p);
      else if (!MemCmp(p,"<style",6) || !MemCmp(p,"<STYLE",6))
        q=StrIMatch("</style",p);
      else
        q=p;
      if (!q)
        break;
      while (q<end && *q!='>')
        q++;
      p=q+1;
      space=TRUE;
    }
    else if (Bt(char_bmp_white_space,*p))
    {
      space=TRUE;
      p++;
    }
    else
    {
      if (space && n)
        res[n++]=' ';
      space=FALSE;
      if (*p=='&')
      {
        if (!MemCmp(p,"&amp;",5))
        {
          res[n++]='&';
          p+=5;
        }
        else if (!MemCmp(p,"&lt;",4))
        {
          res[n++]='<';
          p+=4;
        }
        else if (!MemCmp(p,"&gt;",4))
        {
          res[n++]='>';
          p+=4;
        }
        else if (!MemCmp(p,"&quot;",6))
        {
          res[n++]='"';
          p+=6;
        }
        else if (!MemCmp(p,"&nbsp;",6))
        {
          res[n++]=' ';
          p+=6;
        }
        else
          res[n++]=*p++;
      }
      else
        res[n++]=*p++;
    }
  }
  res[n]=0;
  *_len=n;
  return res;
}

U8 *TSSNetUrl(U8 *url,Bool text,I64 *_len)
{//GET an http:// URL (HTTP/1.0). The body, or its text. NULL on failure.
  U8 host[256],*path,*req,*buf,*body,*p,*res;
  I64 port=80,n,len=0,size=0x10000,got;
  F64 t;
  CTCPSock *sock;
  if (StrNCmp(url,"http://",7))
    return NULL;
  url+=7;
  n=0;
  while (url[n] && url[n]!='/' && url[n]!=':' && n<255)
  {
    host[n]=url[n];
    n++;
  }
  host[n]=0;
  path=url+n;
  if (*path==':')
  {
    port=Str2I64(path+1);
    while (*path && *path!='/')
      path++;
  }
  if (!*path)
    path="/";
  if (!(sock=TSSNetConnect(host,port)))
    return NULL;
  req=MStrPrint("GET %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: TinkerOS\r\n"
        "Connection: close\r\n\r\n",path,host);
  sock->timeout=TSS_NET_MS;
  n=TCPSockSendAll(sock,req,StrLen(req));
  Free(req);
  buf=MAlloc(size+1);
  t=tS+TSS_NET_MS/1000.0;
  while (n>0 && tS<t)
  {
    if (sock->state!=TCP_STATE_ESTABLISHED &&
          sock->read_position==sock->write_position)
      break;
    if (len==size)
    {
      p=MAlloc(2*size+1);
      MemCpy(p,buf,len);
      Free(buf);
      buf=p;
      size*=2;
    }
    sock->timeout=TSS_RECV_MS;
    if ((got=TCPSockRx(sock,buf+len,size-len))>0)
    {
      len+=got;
      t=tS+TSS_NET_MS/1000.0;
    }
  }
  TSSNetClose(sock);
  buf[len]=0;
  if (StrNCmp(buf,"HTTP/",5) || !(body=StrFind("\r\n\r\n",buf)))
  {
    Free(buf);
    return NULL;
  }
  body+=4;
  n=buf+len-body;
  if (text)
    res=TSSHtmlText(body,n,_len);
  else
  {
    res=MAlloc(n+1);
    MemCpy(res,body,n);
    res[n]=0;
    *_len=n;
  }
  Free(buf);
  return res;
}

fp_tss_connect=&TSSNetConnect;
fp_tss_send=&TSSNetSend;
fp_tss_recv=&TSSNetRecv;
fp_tss_close=&TSSNetClose;
fp_tss_url=&TSSNetUrl;
fp_tss_rem_com=&RemTcpComm;

public I64 TOSServerTcp(I64 port=12345,U8 *dir="~/TOSXfr",Bool exec=FALSE,
	Bool bg=TRUE)
{//Listen on TCP port and answer TOSClient on whatever connects.
  I64 com=AddTcpCommSrv(port);
  if (!com)
    return 0;
  if (!TOSServer(com,dir,exec,bg,TRUE))
  {
    RemTcpComm(com);
    return 0;
  }
  return com;
}

public I64 TOSServerTcpCli(U8 *ip,I64 port=12345,U8 *dir="~/TOSXfr",
	Bool exec=FALSE,Bool bg=TRUE)
{//Connect to ip:port and answer TOSClient there.
  I64 com=AddTcpCommCli(ip,port);
  if (!com)
    return 0;
  if (!TOSServer(com,dir,exec,bg,TRUE))
  {
    RemTcpComm(com);
    return 0;
  }
  return com;
}
#help_index ""
