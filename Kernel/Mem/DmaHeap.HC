#define DMA_HEAP_PAGES 4 // TODO fixed size, assuming 2MB pages for now

static CBlkPool dma_blk_pool;

static U0 DmaHeapUncacheRange(U8 *addr,I64 len)
{
  U8 *end=addr+len-1;

  *MemPageTable(addr)=*MemPageTable(addr)&~0x18 |0x11;
  InvlPg(addr);

  if (MemPageTable(end)!=MemPageTable(addr))
  {
    *MemPageTable(end)=*MemPageTable(end)&~0x18 |0x11;
    InvlPg(end);
  }
}

public U0 DmaHeapInit()
{
  U8 *raw;
  I64 size=DMA_HEAP_PAGES*mem_page_size;

  raw=CAllocAligned(size,mem_page_size,adam_task->code_heap);

  DmaHeapUncacheRange(raw,size);

  MemSet(&dma_blk_pool,0,sizeof(CBlkPool));
  BlkPoolAdd(&dma_blk_pool,raw,size>>MEM_PAG_BITS);

  sys_dma_heap=HeapCtrlInit(,adam_task,&dma_blk_pool);
}
