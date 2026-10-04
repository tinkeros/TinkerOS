#help_index "DolDoc/File"

public U0 DocAppend(CDoc *doc, U8 *line, I64 end_idx=0)
{//Append a line to a CDoc.  end_idx counts back from the end: 0 appends
 //at the end, -1 makes the line the second to last, -2 the third to
 //last, and so on.  Docs with fewer lines than asked for get prepended.
  Bool unlock;
  CDocEntry *doc_e;
  I64 cnt;
  if (!doc)
    return;
  DocBottom(doc);
  if (end_idx>=0)
  {
    DocPrint(doc,line);
    return;
  }
  unlock=DocLock(doc);
  doc_e=doc->head.last;
  //A doc normally ends with the newline terminating its last line.  Step
  //over it so the count below is the same whether or not one is there.
  if (doc_e!=doc && doc_e->type_u8==DOCT_NEW_LINE)
    doc_e=doc_e->last;
  cnt=-end_idx;
  while (doc_e!=doc)
  {
    if (doc_e->type_u8==DOCT_NEW_LINE)
    {
      cnt--;
      if (!cnt)
        break;
    }
    doc_e=doc_e->last;
  }
  if (doc_e==doc)
    doc->cur_entry=doc->head.next;
  else
    doc->cur_entry=doc_e->next;
  doc->cur_col=doc->cur_entry->min_col;
  DocRecalc(doc);
  //DocInsEntry() inserts ahead of cur_entry, so this lands the new line
  //in front of the line the cursor was just parked on.
  DocPrint(doc,line);
  if (unlock)
    DocUnlock(doc);
}

public U0 DocAppendLine(U8 *filename, U8 *line, I64 end_idx=0)
{//Append a line to a doc file.  See DocAppend for what end_idx does.
  CDoc *doc=DocRead(filename);
  DocAppend(doc, line, end_idx);
  DocWrite(doc);
  DocDel(doc);
}

public U0 DocPrepend(CDoc *doc, U8 *line)
{//Prepend a line to a CDoc
  DocTop(doc);
  DocPrint(doc,line);
}

public U0 DocPrependLine(U8 *filename, U8 *line)
{//Prepend a line to a doc file.
  CDoc *doc=DocRead(filename);
  DocPrepend(doc,line);
  DocWrite(doc);
  DocDel(doc);
}

