#define TCP_MAX_PORT	65535

#define TCP_SRTT_ALPHA	0.9

#define TCP_RTO_BETA	2
#define TCP_RTO_MIN		0.2
#define TCP_RTO_MAX		10

#define TCP_WINDOW_SIZE	8192

#define TCP_MSS			536

#define TCP_TIMEOUT		5000

#define TCP_STATE_CLOSED		0
#define TCP_STATE_LISTEN		1
#define TCP_STATE_SYN_SENT		2
#define TCP_STATE_SYN_RECEIVED	3
#define TCP_STATE_ESTABLISHED	4
#define TCP_STATE_FIN_WAIT1		5
#define TCP_STATE_FIN_WAIT2		6
#define TCP_STATE_CLOSE_WAIT	7
#define TCP_STATE_CLOSING		8
#define TCP_STATE_LAST_ACK		9
#define TCP_STATE_TIME_WAIT		10

#define TCPf_FIN	0
#define TCPf_SYN	1
#define TCPf_RST	2
#define TCPf_ACK	4
//#define TCPf_URG	5 // most stacks don't implement URGENT.

#define TCPF_FIN	(1 << TCPf_FIN)
#define TCPF_SYN	(1 << TCPf_SYN)
#define TCPF_RST	(1 << TCPf_RST)
#define TCPF_ACK	(1 << TCPf_ACK)
//#define TCPF_URG	(1 << TCPf_URG) // most stacks don't implement URGENT.


class CTCPAckQue:CQue
{
	F64 time_sent;
	U32 retries;
	U32 start_seq_num;
	U32 end_seq_num;

	U32 tcp_pkt_size;
	U8 *tcp_pkt;
};

// stores packet data of incoming connect() requests,
// local accept() will search queue for pending connections,
// and use this data to send out notification connection was accepted.
class CTCPAcceptQue:CQue
{
	U32 segment_seq_num;
	U32 ipv4_addr;
	U16 port;
};

class CTCPSock
{
	CSock					*sock;
	U8						 state;
	U64						 timeout;

	CSockAddrStorage	 src_addr;
	CSockAddrStorage	 dst_addr;

	CTCPAckQue			*ack_queue;

	U64						 accept_queue_limit;
	CTCPAcceptQue			*accept_queue;

	U32						 max_segment_size;

	U32						 first_unacked_seq;
	U32						 next_send_seq_num;
	U32						 next_recv_seq_num;
	F64						 srtt;
	F64						 connection_time;

	U32						 rx_window;
	U32						 send_window;

	I64						 write_position;
	I64						 read_position;
	I64						 rx_buf_size;
	U8						*rx_buf;
	U32						 rx_drops;
	I64						 handler_refs;
	I64						 close_lock;
};


class CTCPTreeQue:CQue
{
	CTCPSock		*sock;
};

class CTCPTreeNode:CBST
{
	CTCPTreeQue	*queue;
};

class CTCPRepEnt:CQue
{
	CTCPTreeNode *node;
};


class CTCPHdr
{
	U16	src_port;
	U16	dst_port;
	U32 seq_num;
	U32	ack_num;
	union
	{
		U8	offset_byte;
		U8	reserved:4;
		U8	data_offset:4;
	}
	union
	{
		U8	flags;
		U8	fin:1;
		U8	syn:1;
		U8	rst:1;
		U8	psh:1;
		U8	ack:1;
		U8	urg:1;
	}
	U16	window_size;
	U16	checksum;
	U16	urgent_pointer;
};

class CTCPPseudoHdr
{
	U32 src_addr;
	U32 dst_addr;
	U8	zeros;
	U8	protocol;
	U16	tcp_len;
};

class CTCPGlbls
{

	CTCPTreeNode	*bound_sock_tree;
	U16				 next_src_port;

} tcp_globals;

