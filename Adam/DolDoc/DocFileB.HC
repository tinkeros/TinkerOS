#help_index "DolDoc/File"

public U0 DocAppendLine(U8 *filename, U8 *line)
{//Append a line to a doc file.
  CDoc *doc=DocRead(filename);
  DocBottom(doc);
  DocPrint(doc,line);
  DocWrite(doc);
  DocDel(doc);
}

public U0 DocPrependLine(U8 *filename, U8 *line)
{//Append a line to a doc file.
  CDoc *doc=DocRead(filename);
  DocTop(doc);
  DocPrint(doc,line);
  DocWrite(doc);
  DocDel(doc);
}

