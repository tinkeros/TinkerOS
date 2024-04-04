U0 BlkPoolAdd(CBlkPool *bp,CMemBlk *m,I64 pags)
{//Add mem to BlkPool.
  if (sys_mem_init_flag)
    MemSet(m,sys_mem_init_val,pags*MEM_PAG_SIZE);
  PUSHFD
  CLI
  while (LBts(&bp->locked_flags,BPlf_LOCKED))
    PAUSE
    m->next=bp->mem_free_lst;
  m->pags=pags;
  m->mb_signature=MBS_UNUSED_SIGNATURE_VAL;
  bp->alloced_u8s+=pags<<MEM_PAG_BITS;
  bp->mem_free_lst=m;
  LBtr(&bp->locked_flags,BPlf_LOCKED);
  POPFD
}

U0 BlkPoolInit(CBlkPool *bp,I64 pags)
{//Make mem chunk into a BlkPool.
  I64 num;
  CMemBlk *m;
  MemSet(bp,0,sizeof(CBlkPool));
  m=(bp(U8 *)+sizeof(CBlkPool)+MEM_PAG_SIZE-1)&~(MEM_PAG_SIZE-1);
  num=(bp(U8 *)+pags<<MEM_PAG_BITS-m(U8 *))>>MEM_PAG_BITS;
  bp->alloced_u8s=(pags-num)<<MEM_PAG_BITS; //Compensate before num added.
  BlkPoolAdd(bp,m,num);
}

static Bool first_heap_init=TRUE;

U0 InitHeapRange(I64 lo,I64 hi)
{
  if (first_heap_init)
  {
    BlkPoolInit(lo,(hi-lo)>>MEM_PAG_BITS);
    sys_data_bp=lo;
    Fs->data_heap=HeapCtrlInit(,Fs,sys_data_bp);
    first_heap_init=FALSE;
  }
  else
    BlkPoolAdd(sys_data_bp,lo,(hi-lo)>>MEM_PAG_BITS);
}

U0 BlkPoolsInit()
{
  I64 i,total,lo,hi,code_heap_limit,new_lo1,new_lo2,new_hi1,new_hi2;
  CMemE820 *m20=MEM_E820;
  total=BIOSTotalMem;
  if (total<=0x80000000)
    code_heap_limit=total;
  else if (total<=0x100000000)
    code_heap_limit=total/4;
  else
    code_heap_limit=0x80000000;
  i=code_heap_limit-SYS_16MEG_AREA_LIMIT; //See $LK,"RLf_16MEG_SYS_CODE_BP",A="FF:::/Kernel/Mem/PageTables.HC,RLf_16MEG_SYS_CODE_BP"$
  BlkPoolAdd(sys_code_bp,SYS_16MEG_AREA_LIMIT,i>>MEM_PAG_BITS);
  mem_heap_limit=i+SYS_16MEG_AREA_LIMIT-1;
  if (code_heap_limit<total)
  {
    while (m20->type)
    {
      if (m20->type==1)
      {
        lo=m20->base;
        hi=m20->base+m20->len;
        if (lo<code_heap_limit)
        {
          if (hi>code_heap_limit)
            lo=code_heap_limit;
          else
            hi=lo; //cancel
        }
        if (code_heap_limit<=lo<hi)
        {
          if (sys_initramfs_ptr && sys_initramfs_ptr > hi)
            InitHeapRange(lo,hi);
          else if (sys_initramfs_ptr && sys_initramfs_ptr + sys_initramfs_size < lo)
            InitHeapRange(lo,hi);
          else
          {
            new_lo1=lo;
            new_hi1=sys_initramfs_ptr;
            new_lo2=sys_initramfs_ptr+sys_initramfs_size;
            new_hi2=hi;
            if (new_hi1-new_lo1>65536) {
              new_hi1=new_hi1-new_hi1%8192;
              InitHeapRange(new_lo1,new_hi1);
            }
            if (new_hi2-new_lo2>65536) {
              new_lo2+=8192;
              new_lo2-=new_lo2%8192;
              InitHeapRange(new_lo2,new_hi2);
            }
          }

        }
      }
      m20++;
    }
  }
  LBts(&sys_run_level,RLf_FULL_HEAPS);
}
