I64 DocCommentEntry(CDoc *doc, CDocEntry *doc_e, U8 *comment)
{
  I64 cnt=0,clen=StrLen(comment);
  U8 *ptr;
  if (StrNCmp(comment,doc_e->tag,clen))
  {
    ptr=CAlloc(clen+1+doc_e->max_col+1,doc->mem_task);
    CatPrint(ptr,"%s",comment);
    CatPrint(ptr,"%s",doc_e->tag);
    Free(doc_e->tag);
    doc_e->tag=ptr;
    cnt++;
  }
  return cnt;
}

I64 DocUnCommentEntry(CDoc *doc, CDocEntry *doc_e, U8 *comment)
{
  I64 cnt=0,clen=StrLen(comment);
  U8 *ptr;
  if (!StrNCmp(comment,doc_e->tag,clen))
  {
    ptr=CAlloc(doc_e->max_col-clen+1,doc->mem_task);
    CatPrint(ptr,"%s",doc_e->tag+clen);
    Free(doc_e->tag);
    doc_e->tag=ptr;
    cnt++;
  }
  return cnt;
}

public I64 DocComment(CDoc *haystack_doc, U8 *needle, U8 *comment)
{//Comment lines matching needle with prefix comment
  Bool unlock;
  CDocEntry *doc_e;
  I64 cnt=0;

  if (haystack_doc && needle)
    {
    unlock=DocLock(haystack_doc);
    DocGoToLine(haystack_doc,0);
    doc_e=haystack_doc->cur_entry;
    while (doc_e!=haystack_doc)
    {
      if (doc_e->de_flags&DOCEF_TAG && doc_e->tag &&
	    StrMatch(needle,doc_e->tag))
      {
        cnt+=DocCommentEntry(haystack_doc,doc_e,comment);
      }
      doc_e=doc_e->next;
    }
    DocGoToLine(haystack_doc,0);
    if (unlock)
      DocUnlock(haystack_doc);
  }
  return cnt;
}

public I64 DocUnComment(CDoc *haystack_doc, U8 *needle, U8 *comment)
{//Uncomment lines matching needle with prefix comment
  Bool unlock;
  CDocEntry *doc_e;
  I64 cnt=0;

  if (haystack_doc && needle)
    {
    unlock=DocLock(haystack_doc);
    DocGoToLine(haystack_doc,0);
    doc_e=haystack_doc->cur_entry;
    while (doc_e!=haystack_doc)
    {
      if (doc_e->de_flags&DOCEF_TAG && doc_e->tag &&
	    StrMatch(needle,doc_e->tag))
      {
        cnt+=DocUnCommentEntry(haystack_doc,doc_e,comment);
      }
      doc_e=doc_e->next;
    }
    DocGoToLine(haystack_doc,0);
    if (unlock)
      DocUnlock(haystack_doc);
  }
  return cnt;
}

public U0 DocCommentSel(CDoc *doc)
{//Comment selected lines
  Bool unlock_doc=DocLock(doc);
  CDocEntry *doc_e=doc->head.next;
  while (doc_e!=doc)
  {
    if (doc_e->type & DOCET_SEL && doc_e->de_flags&DOCEF_TAG && doc_e->tag)
        DocCommentEntry(doc, doc_e, "// ");
    doc_e=doc_e->next;
  }
  DocRemSoftNewLines(doc,NULL);
  if (unlock_doc)
    DocUnlock(doc);
}

public U0 DocUnCommentSel(CDoc *doc)
{//Comment selected lines
  Bool unlock_doc=DocLock(doc);
  CDocEntry *doc_e=doc->head.next;
  while (doc_e!=doc)
  {
    if (doc_e->type & DOCET_SEL && doc_e->de_flags&DOCEF_TAG && doc_e->tag)
        DocUnCommentEntry(doc, doc_e, "// ");
    doc_e=doc_e->next;
  }
  DocRemSoftNewLines(doc,NULL);
  if (unlock_doc)
    DocUnlock(doc);
}
