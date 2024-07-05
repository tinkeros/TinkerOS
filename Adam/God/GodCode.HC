public U0 GodCodeJmp()
{//Jump to rand code in OS. See $LK,"::/Adam/God/HSNotes.DD"$.
  CDirEntry *tmpde1=FilesFind("/*",
        FUF_JUST_FILES|FUF_RECURSE|FUF_JUST_SRC|FUF_CLUS_ORDER),
        *tmpde=tmpde1;
  I64 cnt=0,num;
  CDoc *doc;
  U8 *st;
  while (tmpde) {
    doc=DocRead(tmpde->full_name);
    tmpde->user_data=doc->head.y;
    cnt+=doc->head.y;
    DocDel(doc);
    tmpde=tmpde->next;
  }

  FifoU8Flush(god.fifo);
  GodBitsIns(GOD_GOOD_BITS,KbdMsEvtTime>>GOD_BAD_BITS);
  num=GodBits(GOD_GOOD_BITS)%cnt;

  tmpde=tmpde1;
  while (tmpde) {
    num-=tmpde->user_data;
    if (num<0) {
      st=MStrPrint("FL:%s,%d",tmpde->full_name,-num);
      break;
    }
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  Ed(st);
  Free(st);
}

