Cd(__DIR__);;

public CTask* netfifo_handler_task = NULL;

Bool net_log_log=FALSE;
Bool net_log_warn=FALSE;
Bool net_log_dbg=FALSE;

#include "Pci"

#include "Utilities/Net.HH"

#include "Utilities/NetLogAdam"

#include "Utilities/NetQueue"

#include "Drivers/Run"

#include "Protocols/Ethernet"

#include "Protocols/ARP"
#include "Protocols/IPV4"
#include "Protocols/ICMP"

#include "Protocols/Sockets"

#include "Utilities/BST"
#include "Protocols/UDP/MakeUDP"
#include "Protocols/DNS"
#include "Utilities/Ping"

#include "Protocols/TCP/MakeTCP"

#include "Protocols/DHCP"

#include "Utilities/NetHandler" // needs IPV4, UDP, ICMP
