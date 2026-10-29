CTCPSock *tcp = TCPSock(AF_INET);
CTCPSock *new;

ClassRep(tcp);

CSockAddrIPV4 *addr = CAlloc(sizeof(CSockAddrIPV4));

addr->port = EndianU16(0xBEEF);
addr->family = AF_INET;
addr->addr.addr = INADDR_ANY;

TCPSockBind(tcp, addr);
TCPSockLsten(tcp, 32);

"\nTry TCPSockClose(tcp);\n";
/*
ClassRep(tcp_globals.bound_sock_tree);

tcp->timeout = TCP_TIMEOUT;
while (TRUE)
{
    new = TCPSockAccept(tcp);

    if (new)
    {
        "\n\nSock accepted\n\n";
        ClassRep(new);
        break;
    }
    else
        Sleep(1);
}

*/

/*
"\nTrying to close the accepted socket:\n";
TCPSockClose(new);

"\nTrying to close the original Lstening socket\n";
TCPSockClose(tcp);*/
