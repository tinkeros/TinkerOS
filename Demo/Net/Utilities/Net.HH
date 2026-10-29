//Generic Networking definitions

#define ETH_MIN_FRAME_SIZE		46
#define ETH_MAC_HDR_LEN	14
#define ETH_ETHERTYPE_OFFSET	12
#define ETH_DATA_OFFSET		14
#define MAC_ADDR_LEN			6
#define FCS_LEN					4

/*	Ethernet Frame Size.
	Linux uses 1544, OSDev and Shrine use 1548. Based on IEEE 802.3as, max frame size was agreed upon as 2000 bytes. */
#define ETH_FRAME_SIZE	2000

#define HTYPE_ETH	1
#define HLEN_ETH	6
#define PLEN_IPV4		4

#define ETHERTYPE_IPV4	0x0800
#define ETHERTYPE_ARP	0x0806
#define ETHERTYPE_IPV6	0x86DD

#define IP_ADDR_LEN	4

/*	NICs reroute PCI interrupts to software. See $LK,"PCNet",A="FF:::/Demo/Net/Drivers/PCNet.HC,PCIInterruptsReroute"$.
	Net Handler interrupt is generated whenever an entry is
	pushed to the NetQue. See $LK,"NetHandler",A="FF:::/Demo/Net/Utilities/NetHandler.HC,I_NETHANDLER"$. */


#define INT_DEST_CPU	0

class CEthHdr
{
	U8	dst[MAC_ADDR_LEN];
	U8	src[MAC_ADDR_LEN];
	U16	ethertype;
};

U8 *EthHdrSet(U8 *frame, U8 *src, U8 *dst, U16 ethertype)
{//Fill in a frame's Ethernet header. Returns where the payload starts.
	CEthHdr *hdr = frame;
	MemCpy(hdr->dst, dst, MAC_ADDR_LEN);
	MemCpy(hdr->src, src, MAC_ADDR_LEN);
	hdr->ethertype = EndianU16(ethertype);
	return frame + sizeof(CEthHdr);
}
