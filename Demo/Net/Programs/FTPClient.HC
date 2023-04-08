#define FTP_BUF_SIZE    1024

I64 FTPGetMsg(CTCPSocket *message_socket, U8 *buf)
{// returns FTP status code of message
  U8        *temp;
  Bool   first = TRUE;
  I64        status;
  "\n";
  while (TCPSocketReceive(message_socket, buf, FTP_BUF_SIZE) > 0)
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

I64 FTPReplyPassivePrs(CTCPSocket *message_socket, CSocketAddressIPV4 *dest_addr_out)
{// Prs an FTP reply message to the PASV command, destination written to arg.
  U8             buf[8192], *str;
  I64            tk, cur_section = 0, recv = 0, recv_sum = 0, res;
  U32            ip_addr = 0;
  U16            port = 0;
  CCmpCtrl  *cc;
  while ((recv = TCPSocketReceive(message_socket, buf + recv_sum, 8192 - recv_sum)) > 0)
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
      break; // skip
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
    dest_addr_out->family           = AF_INET;
    dest_addr_out->port             = EndianU16(port);
    dest_addr_out->address.address  = ip_addr;
    res = 0;
  }
  CmpCtrlDel(cc);
  return res;
}

I64 FTPFileDownload(CTCPSocket *data_socket, U8 *dest)
{
  CFile *f;
  I64        data_len = 0, recv_sum = 0, recv;
  U8         buf[BLK_SIZE];
  progress4 = 0;
  f = FOpen(dest, "w");
  if (!f)
  {
    ST_ERR_ST "Failed to open %s for writing\n", dest;
    return -1;
  }
  while (TRUE)
  {
    recv = TCPSocketReceive(data_socket, buf + data_len, sizeof(buf) - data_len);
    if (recv <= 0)
    {
      if (recv < 0)
        ST_ERR_ST "Failed to receive TCP data\n";
      if (data_len != 0 && !FBlkWrite(f, buf))
        break;
      f->de.size = recv_sum;
      FClose(f);
      TCPSocketClose(data_socket);
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
  TCPSocketClose(data_socket);
  ST_ERR_ST "Write failed, %s may be corrupted\n", dest;
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
  //BAD FOR FILENAMES: ? / | = % : ; * + " < > space
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
    result[21] = 0; // truncate filename len
  AdamLog("%s\n", result);
  return result;
}

class CFTPFilePmt
{
  U8 name[256] format "$$DA-P,LEN=255,A=\"FileName:%s\"$$";
};
U8 *FTPFilePmt(U8 *path)
{
  CFTPFilePmt    form;
  U8                *basename = FTPBasename(path);
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
  U32                    addr;
  CAddressInfo      *current;
  CAddressInfo      *result = NULL;
  I64                    error, tk, i;
  CSocketAddressIPV4     ipv4_address, *temp_ipv4, data_ipv4;
  CTCPSocket            *message_socket = TCPSocket(AF_INET), *data_socket;
  I64                    status = 0;
  U8                     buf[FTP_BUF_SIZE], *temp, *input_str, *dest;
  CCmpCtrl          *cc;
  if (!hostname)
    hostname = GetStr("\nEnter FTP server address (URL or IPV4): ");
  if (!IPV4AddressPrs(hostname, &addr))
  {
    error = DNSAddressInfoGet(hostname, NULL, &result);
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
        temp_ipv4 = current->address;
        addr = EndianU32(temp_ipv4->address); // why does it need EndianU32
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
  ipv4_address.port             = EndianU16(port);
  ipv4_address.family               = AF_INET;
  ipv4_address.address.address  = addr;
  message_socket->timeout = TCP_TIMEOUT;
  if (TCPSocketConnect(message_socket, &ipv4_address) != 0)
  {
    "\nFailed to connect to server.\n";
    TCPSocketClose(message_socket);
    return -1;
  }
  else
    "\nSuccessfully connected.\n";
  message_socket->timeout = 2 * JIFFY_FREQ;
  FTPGetMsg(message_socket, buf);
  "\n\nType HELP for command list.\n\n";
  while (TRUE)
  {
    input_str = GetStr(">");
    cc = CmpCtrlNew(input_str);
    while ((tk = Lex(cc)))
    {
      switch (tk)
      {
      case TK_IDENT: // command
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
          TCPSocketSendString(message_socket, temp);
          FTPGetMsg(message_socket, buf);
          Free(temp);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "LIST")   ||
                 !StrCmp(cc->cur_str, "DIR")    ||
                 !StrCmp(cc->cur_str, "LS"))
        {
          TCPSocketSendString(message_socket, "PASV\r\n");
          if (FTPReplyPassivePrs(message_socket, &data_ipv4) != 0)
          {
            ST_ERR_ST "Error parsing server response to PASV command!\n";
            goto lex_done;
          }
          data_socket = TCPSocket(AF_INET);
          data_socket->timeout = 2 * JIFFY_FREQ;
          if (TCPSocketConnect(data_socket, &data_ipv4) != 0)
          {
            ST_ERR_ST "Failed at data socket connect!";
            TCPSocketClose(data_socket);
            goto lex_done;
          }
          TCPSocketSendString(message_socket, "LIST\r\n");
          FTPGetMsg(data_socket, buf);
          FTPGetMsg(message_socket, buf);
          if (TCPSocketClose(data_socket) != 0)
            ST_ERR_ST "Failed at data socket close!";
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "PWD"))
        {
          TCPSocketSendString(message_socket, "PWD\r\n");
          FTPGetMsg(message_socket, buf);
        }
        else if (!StrCmp(cc->cur_str, "RETR")   ||
                 !StrCmp(cc->cur_str, "GET"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          TCPSocketSendString(message_socket, "PASV\r\n");
          if (FTPReplyPassivePrs(message_socket, &data_ipv4) != 0)
          {
            ST_ERR_ST "Error parsing server response to PASV command!\n";
            goto lex_done;
          }
          data_socket = TCPSocket(AF_INET);
          data_socket->timeout = 2 * JIFFY_FREQ;
          if (TCPSocketConnect(data_socket, &data_ipv4) != 0)
          {
            ST_ERR_ST "Failed at data socket connect!";
            TCPSocketClose(data_socket);
            goto lex_done;
          }
          dest = FTPFilePmt(input_str);
          if (dest == NULL)
          {
            ST_ERR_ST "Download filename cannot be empty!";
            TCPSocketClose(data_socket);
            goto lex_done;
          }
          temp = MStrPrint("RETR %s\r\n", input_str);
          TCPSocketSendString(message_socket, temp);
          FTPFileDownload(data_socket, dest);
          FTPGetMsg(message_socket, buf);
          "\nOpen file with Ed? ";
          if (YorN)
            FTPFileView(dest);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "VIEW")   ||
                 !StrCmp(cc->cur_str, "CAT"))
        {
          StrFirstRem(input_str, " ");
          if (!StrCmp(input_str, ""))
          {
            ST_ERR_ST "Must provide argument!\n";
            goto lex_done;
          }
          TCPSocketSendString(message_socket, "PASV\r\n");
          if (FTPReplyPassivePrs(message_socket, &data_ipv4) != 0)
          {
            ST_ERR_ST "Error parsing server response to PASV command!\n";
            goto lex_done;
          }
          data_socket = TCPSocket(AF_INET);
          data_socket->timeout = 2 * JIFFY_FREQ;
          if (TCPSocketConnect(data_socket, &data_ipv4) != 0)
          {
            ST_ERR_ST "Failed at data socket connect!";
            TCPSocketClose(data_socket);
            goto lex_done;
          }
          temp = MStrPrint("RETR %s\r\n", input_str);
          TCPSocketSendString(message_socket, temp);
          FTPGetMsg(data_socket, buf);
          FTPGetMsg(message_socket, buf);
          if (TCPSocketClose(data_socket) != 0)
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
          TCPSocketSendString(message_socket, temp);
          FTPGetMsg(message_socket, buf);
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
          TCPSocketSendString(message_socket, temp);
          FTPGetMsg(message_socket, buf);
          Free(temp);
          goto lex_done;
        }
        else if (!StrCmp(cc->cur_str, "QUIT") ||
                 !StrCmp(cc->cur_str, "EXIT") ||
                 !StrCmp(cc->cur_str, "BYE"))
        {
          TCPSocketSendString(message_socket, "QUIT\r\n");
          status = FTPGetMsg(message_socket, buf);
          if (status == 221)
            "Server closed successfully, exiting normally...\n\n";
          else
            ST_WARN_ST "Server error during close, force exit...\n\n";
          TCPSocketClose(message_socket);
          "See ya later!\n\n";
          CmpCtrlDel(cc);
          return 0;
        }
        else
        {
          "
Command Lst:
        (Alternate names separated by '/'; names case-insensitive)
            CWD/CD <path>       = Chg Working Directory to <path>.
                                  LIST/DIR/LS           = Lst directory contents.
                                      PWD                 = Print name of current directory.
                                          RETR/GET <file>     = Download copy of <file> from server.
                                              VIEW/CAT <file>     = Print the contents of <file> to the screen.
                                                  USER <username>     = Set username to <username>.
                                                      PASS <password>     = Set password to <password>.
                                                          QUIT/EXIT/BYE       = End FTP session.\n\n";
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
