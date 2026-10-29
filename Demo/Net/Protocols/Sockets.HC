/*  docs.idris-lang.org/en/latest/st/examples.html
    beej.us/guide/bgnet/html/

    Sockets are non-standard, a simple
    Finite State Machine. The functions'
    only args are the socket. Socket functions
    requiring more parameters should be
    defined at the protocol level.

    The state machine exists to allow
    protocol code to execute code in
    the appropriate order. When calling
    a socket function, code can use
    the modified/unmodified states to
    determine next procedure.

    Some code is inclded for IPV6, currently
    unused. */

#define SOCK_STATE_READY          0
#define SOCK_STATE_BIND_REQ       1
#define SOCK_STATE_CONNECT_REQ    2
#define SOCK_STATE_BOUND          3
#define SOCK_STATE_LISTEN_REQ     4
#define SOCK_STATE_LISTENING      5
#define SOCK_STATE_OPEN           6
#define SOCK_STATE_CLOSE_REQ      7
#define SOCK_STATE_CLOSED         8

#define SOCK_STREAM   1
#define SOCK_DATAGRAM 2
#define SOCK_RAW      3

#define AF_UNSPEC   0
#define AF_INET     2
#define AF_INET6    10

#define INADDR_ANY  0

#define INET_ADDRSTRLEN     16
#define INET6_ADDRSTRLEN    46

#define INET_MIN_ADDRSTRLEN     7
#define INET6_MIN_ADDRSTRLEN    2


#define IP_PARSE_STATE_NUM          0
#define IP_PARSE_STATE_DOT          1

class CIPV4Addr
{
  U32 addr;
};

class CIPV6Addr
{
  U8    addr[16];
};

class CIPAddrStorage
{// class specifically meant to be generic casted either IPV4 or IPV6 Address.
  U8    padding[16];
};

class CSockAddrIPV4
{
  U16               family;
  U16               port;
  CIPV4Addr  addr;
  U8                zeroes[8];
};

class CSockAddrIPV6
{
  U16               family;
  U16               port;
  U32               flow_info;
  CIPV6Addr  addr;
  U32               scope_id;
};

class CSockAddrStorage
{
  /*    'designed to be large enough to
  hold both IPV4 and IPV6 structures.' */

  U16 family;
  U8    padding[26];
};

class CAddrInfo
{
  I32                        flags;
  I32                        family;
  I32                        sock_type;
  I32                        protocol;
  I64                        addr_len;
  CSockAddrStorage *addr;
  U8                        *canonical_name;
  CAddrInfo          *next;
};

class CSock
{
  U8    state;

  U16   type;
  U16 domain;
};

U0 AddrInfoCpy(CAddrInfo *out, CAddrInfo *in, CTask *mem_task=NULL)
{//Assumes *out already exists. mem_task owns the copied buffers.
  ClassCpy(out, in);
  if (in->addr)
  {
    out->addr = CAlloc(in->addr_len, mem_task);
    MemCpy(out->addr, in->addr, in->addr_len);
  }
  if (in->canonical_name)
  {
    out->canonical_name = StrNew(in->canonical_name, mem_task);
  }
}

U0 AddrInfoFree(CAddrInfo *info)
{
  CAddrInfo *next;
  while (info)
  {
    next = info->next;
    Free(info->addr);
    Free(info->canonical_name);
    Free(info);
    info = next;
  }
}

Bool IPV4AddrPrs(U8 *str, U32 *dst)
{
  U8 *lexable_str = StrNew(str);
  lexable_str = StrReplace(lexable_str, ".", ",");
  CCmpCtrl *cc = CmpCtrlNew(lexable_str);
  cc->opts |= 1 << OPTf_DECIMAL_ONLY;
  I64 tk;
  I64 state = IP_PARSE_STATE_NUM;
  U32 temp_dst = 0;
  I64 current_section = 0;
  while (tk = Lex(cc))
  {
    switch (state)
    {
    case IP_PARSE_STATE_NUM:
      switch (tk)
      {
      case TK_I64:
        if (cc->cur_i64 > 255 || cc->cur_i64 < 0)
        {
          NetErr("IPV4 ADDRESS PARSE: Invalid value, must be 0 - 255.");
          return FALSE;
        }
        if (current_section > 3)
        {
          NetErr("IPV4 ADDRESS PARSE: IP Address can only have 4 sections.");
          return FALSE;
        }
        temp_dst |= cc->cur_i64 << (current_section * 8);
        current_section++;
        state = IP_PARSE_STATE_DOT;
        break;
      default:
        NetErr("IPV4 ADDRESS PARSE: Expected decimal. ");
        return FALSE;
      }
      break;
    case IP_PARSE_STATE_DOT:
      switch (tk)
      {
      case ',':
        state = IP_PARSE_STATE_NUM;
        break;
      default:
        NetErr("IPV4 ADDRESS PARSE: Expected dot. ");
        return FALSE;
      }
      break;
    }
  }
  CmpCtrlDel(cc);
  temp_dst = EndianU32(temp_dst);
  *dst = temp_dst;
  return TRUE;
}

I64 PresToNet(I64 addr_family, U8 *str, CIPAddrStorage *dst)
{
  /*    Converts IP string to internet address class, our inet_pton().
    Destination written as CIPV4Address or CIPV6Address depending
    on value of address_family.
    The destination address is the generic class, functions
    calling this method must cast their classes in the params. */
  CIPV4Addr *ipv4_addr;
  CIPV6Addr *ipv6_addr;
  I64 str_len = StrLen(str);
  switch (addr_family)
  {
  case AF_INET:
    if (str_len > INET_ADDRSTRLEN || str_len < INET_MIN_ADDRSTRLEN)
    {
      NetErr("IP to Socket Address failed: Invalid Input String Size.");
      return -1;
    }
    ipv4_addr = dst;
    if (!IPV4AddrPrs(str, &ipv4_addr->addr))
      return -1;
    break;
  case AF_INET6:
    if (str_len > INET6_ADDRSTRLEN || str_len < INET6_MIN_ADDRSTRLEN)
    {
      NetErr("IP to Socket Address failed: Invalid Input String Size.");
      return -1;
    }
    ipv6_addr = dst;
    NetErr("IP to Socket Address failed: FIXME, IPV6 support not implemented yet.\n");
    return -1;
  default:
    NetErr("IP to Socket Address failed: Invalid Address Family.");
    return -1;
  }
  return 0;
}

U8 *NetToPres(I64 addr_family, CIPAddrStorage *src)
{// converts socket address to IP string, our inet_ntop. Taking Shrine approach of function returns U8* .
  U8             *ip_str = NULL;
  CIPV4Addr *ipv4_src;
  CIPV4Addr *ipv6_src;
  switch (addr_family)
  {
  case AF_INET:
    ipv4_src = src;
    ip_str = MStrPrint("%d.%d.%d.%d",
                          ipv4_src->addr.u8[0],
                          ipv4_src->addr.u8[1],
                          ipv4_src->addr.u8[2],
                          ipv4_src->addr.u8[3]);
    break;
  case AF_INET6:
    ipv6_src = src;
    NetErr("Socket Address to IP failed: FIXME, IPV6 support not implemented yet.\n");
    return -1;
    break;
  default:
    NetErr("Socket Address to IP failed: Invalid Address Family.");
    break;
  }
  return ip_str;
}


CSock *Sock(U16 domain, U16 type, CTask *mem_task=NULL)
{//mem_task owns the socket: adam_task when NetHandler reaches it by tree.
  CSock *sock = CAlloc(sizeof(CSock), mem_task);
  sock->domain = domain;
  sock->type = type;
  sock->state = SOCK_STATE_READY;
  return sock;
}

U0 SockStateErr(U8 *req, U8 state)
{
  U8 *state_str;
  switch (state)
  {
  case SOCK_STATE_READY:
    state_str = StrNew("READY");
    break;
  case SOCK_STATE_BIND_REQ:
    state_str = StrNew("BIND REQUEST");
    break;
  case SOCK_STATE_CONNECT_REQ:
    state_str = StrNew("CONNECT REQUEST");
    break;
  case SOCK_STATE_BOUND:
    state_str = StrNew("BOUND");
    break;
  case SOCK_STATE_LISTEN_REQ:
    state_str = StrNew("LISTEN REQUEST");
    break;
  case SOCK_STATE_LISTENING:
    state_str = StrNew("LISTENING");
    break;
  case SOCK_STATE_OPEN:
    state_str = StrNew("OPEN");
    break;
  case SOCK_STATE_CLOSE_REQ:
    state_str = StrNew("CLOSE REQUEST");
    break;
  case SOCK_STATE_CLOSED:
    state_str = StrNew("CLOSED");
    break;
  }
  NetErr("Socket attempted %s while in %s state.", req, state_str);
}

Bool SockAccept(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_LISTENING:
    /*  Socket expected to stay listening.
        At protocol level, a new socket 'connected'
        to this one is expected to be made. */
    return TRUE;
  default:
    SockStateErr("ACCEPT", sock->state);
    return FALSE;
  }
}

Bool SockClose(CSock *sock)
{
  /* Sockets attempting close will enter close
  request state before destroying the socket at
  the protocol level. */
  sock->state = SOCK_STATE_CLOSE_REQ;
  return TRUE;
}

Bool SockBind(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_READY:
    /*  Sockets can only be bound
        if they are in initial state. */
    sock->state = SOCK_STATE_BIND_REQ;
    return TRUE;
  default:
    SockStateErr("BIND", sock->state);
    return FALSE;
  }
}

Bool SockConnect(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_READY:
    /*  Sockets can only be connected
        if they are in initial state. */
    sock->state = SOCK_STATE_CONNECT_REQ;
    return TRUE;
  default:
    SockStateErr("CONNECT", sock->state);
    return FALSE;
  }
}

Bool SockLsten(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_BOUND:
    /*  A socket must be bound to
        set it to listening. */
    sock->state = SOCK_STATE_LISTEN_REQ;
    return TRUE;
  default:
    SockStateErr("LISTEN", sock->state);
    return FALSE;
  }
}

Bool SockRx(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_OPEN:
  case SOCK_STATE_BOUND:
    /*  Sockets can only recv when
        connected to or bound. */
    return TRUE;
  default:
    SockStateErr("RECEIVE", sock->state);
    return FALSE;
  }
}

Bool SockRxFrom(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_OPEN:
  case SOCK_STATE_BOUND:
    /*  Sockets can only recvfrom when
        connected to or bound. */
    return TRUE;
  default:
    SockStateErr("RECEIVE FROM", sock->state);
    return FALSE;
  }
}

Bool SockSend(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_OPEN:
    /*  Sockets can only send when
        they have been connected to. */
    return TRUE;
  default:
    SockStateErr("SEND", sock->state);
    return FALSE;
  }
}

Bool SockSendTo(CSock *sock)
{
  switch (sock->state)
  {
  case SOCK_STATE_OPEN:
  case SOCK_STATE_BOUND:
  case SOCK_STATE_READY:
    /*  Sockets can only sendto when
        connected to, bound, or in
        initial state. Protocol logic
        will determine how to change
        state based on params. */
    return TRUE;
  default:
    SockStateErr("SEND TO", sock->state);
    return FALSE;
  }
}
