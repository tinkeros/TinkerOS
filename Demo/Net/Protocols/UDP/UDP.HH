#define UDP_MAX_PORT	65535

class CUDPMsgQue:CQue
{ // each bound socket queues data. recv functions & hndlr use this.
	U8						*data;
	I64						 data_len;
	I64						 received_len;
	CSockAddrStorage	 from_addr;
};

class CUDPSock
{
	CSock					*sock;
	CUDPMsgQue		*rx_queue;
	CSockAddrStorage	 rx_addr;
	I64						 rx_timeout_ms;
	I64						 rx_max_timeout;
	U16						 bound_to;
	I64						 rx_queue_depth;
	I64						 rx_lock;
	I64						 handler_refs;
	I64						 close_lock;
};

#define UDP_RECV_QUEUE_MAX	32

class CUDPTreeQue:CQue
{
	CUDPSock		*sock;
};

class CUDPTreeNode:CBST
{
	CUDPTreeQue	*queue;
};

class CUDPRepEnt:CQue
{
	CUDPTreeNode *node;
};

class CUDPHdr
{
	U16 src_port;
	U16 dst_port;
	U16 len;
	U16 checksum;
};


class CUDPGlbls
{

	CUDPTreeNode *bound_sock_tree;

} udp_globals;

