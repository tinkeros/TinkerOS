#define FTP_BUF_SIZE    1024

I64 FTPGetMsg(CTCPSock *message_sock, U8 *buf)
{// returns FTP status code of message
  U8 *temp;
  Bool first = TRUE;
  I64 status;
  "\n";
  while (TCPSockRx(message_sock, buf, FTP_BUF_SIZE) > 0)
  {
    if (first)
    {
      status = Str2I64(buf);
      first = FALSE;
    }
    temp = MStrPrint("%Q", buf);
    temp = StrReplace(temp, "\\r", "",, TRUE);
    temp = StrReplace(temp, "\\n", "\n",, TRUE);
    temp = StrReplace(temp, "\\t", "\t",, TRUE);
    temp = StrReplace(temp, "\\\"", "\"",, TRUE);
    "%s"
    , temp;
    MemSet(buf, 0, FTP_BUF_SIZE);
    Free(temp);
  }
  "\n";
  return status;
}

I64 FTPReplyPassivePrs(CTCPSock *message_sock, CSockAddrIPV4 *dst_addr_out)
{// Prs an FTP reply message to the PASV command, destination written to arg.
  U8 buf[8192], *str;
  I64 tk, cur_section = 0, recv = 0, recv_sum = 0, res;
  U32 ip_addr = 0;
  U16 port = 0;
  CCmpCtrl *cc;
  while ((recv = TCPSockRx(message_sock, buf + recv_sum, 8192 - recv_sum)) > 0)
  {
    recv_sum += recv;
  }
  str = StrNew(buf);
  cc = CmpCtrlNew(str);
  while ((tk = Lex(cc)))
  {
    switch (tk)
    {
    case TK_IDENT:
      cur_section = 0;
      ip_addr = 0;
      port = 0;
      break;
    case ',':
      break;
    case TK_I64:
      if (cur_section < 4)
      {
        ip_addr.u8[3 - cur_section] = cc->cur_i64;
        cur_section++;
      }
      else if (4 <= cur_section < 6)
      {
        port.u8[5 - cur_section] = cc->cur_i64;
        cur_section++;
      }
      if (cur_section >= 6)
        goto parse_done;
      break;
    default:
      break;
    }
  }
parse_done:
  if (cur_section < 6)
    res = -1;
  else
  {
    dst_addr_out->family = AF_INET;
    dst_addr_out->port = EndianU16(port);
    dst_addr_out->addr.addr = ip_addr;
    res = 0;
  }
  CmpCtrlDel(cc);
  return res;
}

I64 FTPFileDownload(CTCPSock *data_sock, U8 *dst)
{
  CFile *f;
  I64 data_len = 0, recv_sum = 0, recv;
  U8 buf[BLK_SIZE];
  progress4 = 0;
  f = FOpen(dst, "w");
  if (!f)
  {
    ST_ERR_ST "Failed to open %s for writing\n", dst;
    return -1;
  }
  while (TRUE)
  {
    recv = TCPSockRx(data_sock, buf + data_len, sizeof(buf) - data_len);
    if (recv <= 0)
    {
      if (recv < 0)
        ST_ERR_ST "Failed to receive TCP data\n";
      if (data_len != 0 && !FBlkWrite(f, buf))
        break;
      f->de.size = recv_sum;
      FClose(f);
      TCPSockClose(data_sock);
      return recv;
    }
    data_len += recv;
    recv_sum += recv;
    progress4 += recv;
    if (data_len == BLK_SIZE)
    {
      if (!FBlkWrite(f, buf))
        break;
      data_len = 0;
    }
  }
  TCPSockClose(data_sock);
  ST_ERR_ST "Write failed, %s may be corrupted\n", dst;
  FClose(f);
  return -1;
}

I64 FTPFileView(U8 *filename=NULL, CTask *parent=NULL, CTask **_pu_task=NULL)
{
  U8 *st = MStrPrint("Cd(\"%Q\");Plain(\"%Q\");", __DIR__, filename);
  I64 res = PopUp(st, parent, _pu_task);
  Free(st);
  return res;
}

U8 *FTPBasename(U8 *path)
{
  U8 *lastslash = StrLastOcc(path, "/"), *result;
  if (lastslash == NULL)
    result = path;
  else
    result = lastslash + 1;
  result = StrReplace(result, "?", "");
  result = StrReplace(result, "/", "",, TRUE);
  result = StrReplace(result, "|", "",, TRUE);
  result = StrReplace(result, "=", "",, TRUE);
  result = StrReplace(result, "%", "",, TRUE);
  result = StrReplace(result, ":", "",, TRUE);
  result = StrReplace(result, ";", "",, TRUE);
  result = StrReplace(result, "*", "",, TRUE);
  result = StrReplace(result, "+", "",, TRUE);
  result = StrReplace(result, "\"", "",, TRUE);
  result = StrReplace(result, "<", "",, TRUE);
  result = StrReplace(result, ">", "",, TRUE);
  result = StrReplace(result, " ", "",, TRUE);
  if (StrLen(result) > 22)
    result[21] = 0;
  AdamLog("%s\n", result);
  return result;
}

class CFTPFilePmt
{
  U8 name[256] format "$$DA-P,LEN=255,A=\"FileName:%s\"$$";
};
U8 *FTPFilePmt(U8 *path)
{
  CFTPFilePmt form;
  U8 *basename = FTPBasename(path);
  MemSet(form.name, 0, 256);
  MemCpy(form.name, basename, MinI64(StrLen(basename), sizeof(form.name) - 1));
  form.name[255] = 0;
  if (PopUpForm(&form))
  {
    if (StrLen(form.name) >= 26)
      form.name[25] = 0;
    return StrNew(form.name);
  }
  return NULL;
}

I64 FTPClient(U8 *hostname=NULL, U16 port=21)
{
  U32 addr;
  CAddrInfo *current;
  CAddrInfo *result = NULL;
  I64 error, tk, i;
  CSockAddrIPV4 ipv4_addr, *temp_ipv4, data_ipv4;
  CTCPSock *message_sock = TCPSock(AF_INET), *data_sock;
  I64 status = 0;
  U8 buf[FTP_BUF_SIZE], *temp, *input_str, *dst;
  CCmpCtrl *cc;
  if (!hostname)
    hostname = GetStr("\nEnter FTP server address (URL or IPV4): ");
  if (!IPV4AddrPrs(hostname, &addr))
  {
    error = DNSAddrInfoGet(hostname, NULL, &result);
    if (error < 0)
    {
      NetErr("FTP Client: Failed at DNS Get Address Info.");
      return -1;
    }
    current = result;
    while (current)
    {
      if (current->family == AF_INET)
      {
        temp_ipv4 = current->addr;
        addr = EndianU32(temp_ipv4->addr);
        break;
      }
      current = current->next;
    }
    if (!current)
    {
      NetErr("FTP Client: Failed to resolve address.");
      return -1;
    }
  }
  ipv4_addr.port = EndianU16(port);
  ipv4_addr.family = AF_INET;
  ipv4_addr.addr.addr = addr;
  message_sock->timeout = TCP_TIMEOUT;
  if (TCPSockConnect(message_sock, &ipv4_addr) != 0)
  {
    "\nFailed to connect to server.\n";
    TCPSockClose(message_sock);
    return -1;
  }
  else
    "\nSuccessfully connected.\n";
  message_sock->timeout = 2 * JIFFY_FREQ;
  FTPGetMsg(message_sock, buf);
  "\n\nType HELP for command list.\n\n";
  while (TRUE)
  {
    input_str = GetStr(">");
    cc = CmpCtrlNew(input_str);
    while ((tk = Lex(cc)))
    {
      switch (tk)
      {
      case TK_IDENT:
        "COMMAND:%s\n"
        , cc->cur_str;
        for (i = 0; i < StrLen(cc->cur_str); i++)
          cc->cur_str[i] = ToUpper(cc->cur_str[i]);
        if (!StrCmp(cc->cur_str, "CWD") ||
            !StrCmp(cc->cur_str, "CD"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          "ARG:%s\n", input_str;
          temp = MStrPrint("CWD %s\r\n", input_str);
          TCPSockSendStr(message_sock, temp);
          FTPGetMsg(message_sock, buf);
          Free(temp);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "LIST") ||
            !StrCmp(cc->cur_str, "DIR") ||
            !StrCmp(cc->cur_str, "LS"))
        {
          TCPSockSendStr(message_sock, "PASV\r\n");
          if (FTPReplyPassivePrs(message_sock, &data_ipv4) != 0)
          {
            ST_ERR_ST "Error parsing server response to PASV command!\n";
            goto lex_done;
          }
          data_sock = TCPSock(AF_INET);
          data_sock->timeout = 2 * JIFFY_FREQ;
          if (TCPSockConnect(data_sock, &data_ipv4) != 0)
          {
            ST_ERR_ST "Failed at data socket connect!";
            TCPSockClose(data_sock);
            goto lex_done;
          }
          TCPSockSendStr(message_sock, "LIST\r\n");
          FTPGetMsg(data_sock, buf);
          FTPGetMsg(message_sock, buf);
          if (TCPSockClose(data_sock) != 0)
            ST_ERR_ST "Failed at data socket close!";
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "PWD"))
        {
          TCPSockSendStr(message_sock, "PWD\r\n");
          FTPGetMsg(message_sock, buf);
        }
        else if (!StrCmp(cc->cur_str, "RETR") ||
            !StrCmp(cc->cur_str, "GET"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          TCPSockSendStr(message_sock, "PASV\r\n");
          if (FTPReplyPassivePrs(message_sock, &data_ipv4) != 0)
          {
            ST_ERR_ST "Error parsing server response to PASV command!\n";
            goto lex_done;
          }
          data_sock = TCPSock(AF_INET);
          data_sock->timeout = 2 * JIFFY_FREQ;
          if (TCPSockConnect(data_sock, &data_ipv4) != 0)
          {
            ST_ERR_ST "Failed at data socket connect!";
            TCPSockClose(data_sock);
            goto lex_done;
          }
          dst = FTPFilePmt(input_str);
          if (dst == NULL)
          {
            ST_ERR_ST "Download filename cannot be empty!";
            TCPSockClose(data_sock);
            goto lex_done;
          }
          temp = MStrPrint("RETR %s\r\n", input_str);
          TCPSockSendStr(message_sock, temp);
          FTPFileDownload(data_sock, dst);
          FTPGetMsg(message_sock, buf);
          "\nOpen file with Ed? ";
          if (YorN)
            FTPFileView(dst);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "VIEW") ||
            !StrCmp(cc->cur_str, "CAT"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          TCPSockSendStr(message_sock, "PASV\r\n");
          if (FTPReplyPassivePrs(message_sock, &data_ipv4) != 0)
          {
            ST_ERR_ST "Error parsing server response to PASV command!\n";
            goto lex_done;
          }
          data_sock = TCPSock(AF_INET);
          data_sock->timeout = 2 * JIFFY_FREQ;
          if (TCPSockConnect(data_sock, &data_ipv4) != 0)
          {
            ST_ERR_ST "Failed at data socket connect!";
            TCPSockClose(data_sock);
            goto lex_done;
          }
          temp = MStrPrint("RETR %s\r\n", input_str);
          TCPSockSendStr(message_sock, temp);
          FTPGetMsg(data_sock, buf);
          FTPGetMsg(message_sock, buf);
          if (TCPSockClose(data_sock) != 0)
            ST_ERR_ST "Failed at data socket close!";
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "USER"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          "ARG:%s\n", input_str;
          temp = MStrPrint("USER %s\r\n", input_str);
          TCPSockSendStr(message_sock, temp);
          FTPGetMsg(message_sock, buf);
          Free(temp);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "PASS"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          "ARG:%s\n", input_str;
          temp = MStrPrint("PASS %s\r\n", input_str);
          TCPSockSendStr(message_sock, temp);
          FTPGetMsg(message_sock, buf);
          Free(temp);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "QUIT") ||
            !StrCmp(cc->cur_str, "EXIT") ||
            !StrCmp(cc->cur_str, "BYE"))
        {
          TCPSockSendStr(message_sock, "QUIT\r\n");
          status = FTPGetMsg(message_sock, buf);
          if (status == 221)
            "Server closed successfully, exiting normally...\n\n";
          else
            ST_WARN_ST "Server error during close, force exit...\n\n";
          TCPSockClose(message_sock);
          "See ya later!\n\n";
          CmpCtrlDel(cc);
          return 0;
        }
        else
        {
          "
Command Lst:
        (Alternate names separated by '/'; names case-insensitive)
            CWD/CD <path> = Chg Working Directory to <path>.
                LIST/DIR/LS = Lst directory contents.
            PWD = Print name of current directory.
                        RETR/GET <file> = Download copy of <file> from server.
                            VIEW/CAT <file> = Print the contents of <file> to the screen.
                                USER <username> = Set username to <username>.
                                    PASS <password> = Set password to <password>.
                                        QUIT/EXIT/BYE = End FTP session.\n\n";
          }
        break;
      default:
        "\nCommand expected. Type HELP for command list.\n"
        ;
        break;
      }
    }
lex_done:
    CmpCtrlDel(cc);
  }
};

FTPClient;
