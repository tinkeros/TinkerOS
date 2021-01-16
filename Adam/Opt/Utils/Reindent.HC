U0 ReindentFile(U8 *filename)
{
  I64 start_y;
  CDoc *doc=DocRead(filename);
  CDocEntry *doc_e;
  doc_e=doc->head.next;
  while (doc_e!=doc)
  {
    if (doc_e->type_u8==DOCT_TEXT && *doc_e->tag=='{')
    {
      doc->cur_entry=doc_e;
      doc->cur_col=0;
      start_y=doc->cur_entry->y;
      EdCodeTools2(doc,EF_REINDENT,FALSE);
      DocGoToLine(doc,start_y+1);
      doc_e=doc->cur_entry;
    }
    while (doc_e!=doc && doc_e->type_u8!=DOCT_NEW_LINE)
      doc_e=doc_e->next;
    if (doc_e==doc)
      break;
    doc_e=doc_e->next;
  }
  DocWrite(doc);
  DocDel(doc);
}
public U0 Reindent(U8 *files_find_mask="*",U8 *fu_flags=NULL)
{//Find files with too many cols.
  CTask *task=Spawn(&UserCmdLine,,"Reindent Servant",,Fs);
  I64 fuf_flags=0;
  CDirEntry *tmpde,*tmpde1;
  XTalkWait(task,
            "DocMax;\n"
            "#define __DATE__ \"\"\n"
            "#define __TIME__ \"\"\n"
            "#define __LINE__ 0\n"
            "#define __CMD_LINE__ 0\n"
            "#define __FILE__ \"\"\n"
            "#define __DIR__ \"\"\n");
  ScanFlags(&fuf_flags,Define("ST_FILE_UTIL_FLAGS"),"+r+f+F+A");
  ScanFlags(&fuf_flags,Define("ST_FILE_UTIL_FLAGS"),fu_flags);
  tmpde=tmpde1=FilesFind(files_find_mask,fuf_flags);
  while (tmpde)
  {
    XTalkWait(task,"ReindentFile(\"%s\");\n",tmpde->full_name);
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
}
