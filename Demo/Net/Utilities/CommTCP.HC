#help_index "Comm;Networking"

#define COMM_TCP_CONNECT_MS	5000
#define COMM_TCP_CLOSE_MS	1000
#define COMM_TCP_ACCEPT_MS	250
#define COMM_TCP_RX_CHUNK	512

class CCommTCP
{
  CTCPSock *s,
             *listener;
  CTask      *task;
  I64         lock,
              stop,
              com,
              port;
  U8          name[64];
};

U0 CommTCPLock(CCommTCP *t)
{
  while (LBts(&t->lock,0))
    Yield;
}

U0 CommTCPUnlock(CCommTCP *t)
{
  LBtr(&t->lock,0);
}

Bool CommTCPUp(CTCPSock *s)
{//Data can still flow: CLOSE_WAIT means only the peer has stopped sending.
  return s->state==TCP_STATE_ESTABLISHED || s->state==TCP_STATE_CLOSE_WAIT;
}

U8 *CommTCPIpStr(U8 *buf,U32 ip)
{//The stack keeps IPv4 addresses in host order: 10.0.2.2 is 0x0A000202.
  StrPrint(buf,"%d.%d.%d.%d",ip.u8[3],ip.u8[2],ip.u8[1],ip.u8[0]);
  return buf;
}

U0 CommTCPInit(CComm *c, I64 baud, I64 lcr)
{//Baud and line format mean nothing here. CommTCPAttach made the fifo.
  no_warn baud,lcr;
  LBts(&c->flags,COMf_ENABLED);
}

Bool CommTCPPut(CComm *c, U8 *buf, I64 cnt, I64 timeout_ms)
{//With no connection the bytes are dropped, as an unplugged UART would.
  CCommTCP *t=c->link;
  CTCPSock *s;
  Bool res=TRUE;
  if (!t)
    return TRUE;
  CommTCPLock(t);
  s=t->s;
  if (s && CommTCPUp(s))
  {
    s->timeout=timeout_ms;
    res=TCPSockSendAll(s,buf,cnt)==cnt;
  }
  CommTCPUnlock(t);
  return res;
}

U0 CommTCPRxPoll(CComm *c)
{//Move what has arrived into c->RX_fifo. Never waits.
  CCommTCP *t=c->link;
  CTCPSock *s;
  CFifoU8 *f=c->RX_fifo;
  U8 buf[COMM_TCP_RX_CHUNK];
  I64 i,n;
  if (!t || !f)
    return;
  CommTCPLock(t);
  if (s=t->s)
  {
    if (s->read_position==s->write_position)
      TCPCheckACKQue(s);
    else if ((n=MinI64(f->mask-FifoU8Cnt(f),COMM_TCP_RX_CHUNK))>0)
    {
      s->timeout=0;
      n=TCPSockRx(s,buf,n);
      for (i=0; i<n; i++)
        FifoU8Ins(f,buf[i]);
    }
  }
  CommTCPUnlock(t);
}

comm_ops[COMT_TCP].init=&CommTCPInit;
comm_ops[COMT_TCP].put=&CommTCPPut;
comm_ops[COMT_TCP].rx_poll=&CommTCPRxPoll;

Bool CommTCPNetUp(U8 *who)
{
  if (ipv4_globals.local_ip)
    return TRUE;
  "%s: the network is not configured (run NetCfg).\n",who;
  return FALSE;
}

I64 CommTCPSlot(U8 *who)
{//The first free COM port from 5 up, 0 if none.
  I64 com;
  if (!CommExists(1))
    Adam("CommInit;\n");
  for (com=5; com<=MAX_COMM_NUM; com++)
    if (!CommExists(com))
      return com;
  "%s: no free COM port.\n",who;
  return 0;
}

CCommTCP *CommTCPAttach(I64 com, CTCPSock *s, CTCPSock *listener, I64 port)
{//Make comm_ports[com] a TCP port, on the adam_task heap.
  CComm *c=&comm_ports[com];
  CCommTCP *t=CAlloc(sizeof(CCommTCP),adam_task);
  t->s=s;
  t->listener=listener;
  t->com=com;
  t->port=port;
  if (!c->RX_fifo)
    c->RX_fifo=FifoU8New(COMM_RX_FIFO_SIZE,adam_task);
  FifoU8Flush(c->RX_fifo);
  c->link=t;
  c->name=t->name;
  c->base=0;
  c->poll=1;
  c->flags=0;
  c->type=COMT_TCP;
  CommTCPInit(c,0,0);
  return t;
}

public I64 AddTcpCommCli(U8 *ip, I64 port)
{//Connect to ip:port as the first free COM port >= 5. Returns it, 0 on failure.
  CSockAddrIPV4 addr;
  CIPV4Addr ip_addr;
  CTCPSock *s;
  CCommTCP *t;
  I64 com;
  if (!CommTCPNetUp("AddTcpCommCli"))
    return 0;
  if (!(0<port<=0xFFFF) || PresToNet(AF_INET,ip,&ip_addr)<0)
  {
    "AddTcpCommCli: bad address %s:%d.\n",ip,port;
    return 0;
  }
  if (!(com=CommTCPSlot("AddTcpCommCli")))
    return 0;
  addr.family=AF_INET;
  addr.port=EndianU16(port);
  addr.addr.addr=ip_addr.addr;
  if (!(s=TCPSock(AF_INET)))
  {
    "AddTcpCommCli: could not make a TCP socket.\n";
    return 0;
  }
  s->timeout=COMM_TCP_CONNECT_MS;
  "Connecting to %s:%d...\n",ip,port;
  if (TCPSockConnect(s,&addr)<0)
  {
    s->timeout=COMM_TCP_CLOSE_MS;
    TCPSockClose(s);
    "AddTcpCommCli: failed to connect to %s:%d.\n",ip,port;
    return 0;
  }
  t=CommTCPAttach(com,s,NULL,0);
  StrPrint(t->name,"client of %s:%d",ip,port);
  "Connected: COM %d is now TCP %s.\n",com,t->name;
  return com;
}

U0 CommTCPSrvTask(CCommTCP *t)
{//A server port's accept loop: one client at a time.
  CTCPSock *s;
  CSockAddrIPV4 *peer;
  CComm *c=&comm_ports[t->com];
  U8 ip[16];
  while (!t->stop)
  {
    if (s=t->s)
    {
      if (s->state!=TCP_STATE_ESTABLISHED && s->read_position==s->write_position)
      {
        CommTCPLock(t);
        t->s=NULL;
        CommTCPUnlock(t);
        s->timeout=COMM_TCP_CLOSE_MS;
        TCPSockClose(s);
        StrPrint(t->name,"server on port %d, waiting for a client",t->port);
      }
      else
        Sleep(100);
    }
    else
    {
      t->listener->timeout=COMM_TCP_ACCEPT_MS;
      if (s=TCPSockAccept(t->listener))
      {
        FifoU8Flush(c->RX_fifo);
        peer=&s->dst_addr;
        CommTCPIpStr(ip,peer->addr.addr);
        StrPrint(t->name,"server on port %d, client %s",t->port,ip);
        CommTCPLock(t);
        t->s=s;
        CommTCPUnlock(t);
      }
    }
  }
}

public I64 AddTcpCommSrv(I64 port)
{//Listen on port as the first free COM port >= 5. Returns it, 0 on failure.
  CSockAddrIPV4 addr;
  CTCPSock *l;
  CCommTCP *t;
  I64 com;
  U8 ip[16];
  if (!CommTCPNetUp("AddTcpCommSrv"))
    return 0;
  if (!(0<port<=0xFFFF))
  {
    "AddTcpCommSrv: bad port %d.\n",port;
    return 0;
  }
  if (!(com=CommTCPSlot("AddTcpCommSrv")))
    return 0;
  if (!(l=TCPSock(AF_INET)))
  {
    "AddTcpCommSrv: could not make a TCP socket.\n";
    return 0;
  }
  addr.family=AF_INET;
  addr.port=EndianU16(port);
  addr.addr.addr=INADDR_ANY;
  if (TCPSockBind(l,&addr)<0 || TCPSockLsten(l,1)<0)
  {
    l->timeout=COMM_TCP_CLOSE_MS;
    TCPSockClose(l);
    "AddTcpCommSrv: could not listen on port %d.\n",port;
    return 0;
  }
  t=CommTCPAttach(com,NULL,l,port);
  StrPrint(t->name,"server on port %d, waiting for a client",port);
  t->task=Spawn(&CommTCPSrvTask,t,"TCP COM Server",,adam_task);
  "COM %d is now a TCP server on %s port %d.\n",com,
        CommTCPIpStr(ip,ipv4_globals.local_ip),port;
  return com;
}

public Bool RemTcpComm(I64 com)
{//Close a port AddTcpCommCli or AddTcpCommSrv made and free its COM number.
  CComm *c;
  CCommTCP *t;
  CTCPSock *s;
  Bool ok=FALSE;
  if (1<=com<=MAX_COMM_NUM)
    ok=comm_ports[com].type==COMT_TCP;
  if (!ok)
  {
    "RemTcpComm: COM %d is not a TCP port.\n",com;
    return FALSE;
  }
  c=&comm_ports[com];
  t=c->link;
  c->type=COMT_NONE;
  c->flags=0;
  c->link=NULL;
  c->name=NULL;
  c->probe_skip=FALSE;
  if (t->task)
  {
    t->stop=TRUE;
    while (TaskValidate(t->task))
      Sleep(10);
  }
  CommTCPLock(t);
  s=t->s;
  t->s=NULL;
  CommTCPUnlock(t);
  if (s)
  {
    s->timeout=COMM_TCP_CLOSE_MS;
    TCPSockClose(s);
  }
  if (t->listener)
  {
    t->listener->timeout=COMM_TCP_CLOSE_MS;
    TCPSockClose(t->listener);
  }
  FifoU8Flush(c->RX_fifo);
  Sleep(50);
  Free(t);
  "COM %d closed.\n",com;
  return TRUE;
}
