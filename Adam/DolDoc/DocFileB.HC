#help_index "DolDoc/File"

public U0 DocAppend(CDoc *doc, U8 *line)
{//Append a line to a CDoc
  DocBottom(doc);
  DocPrint(doc,line);
}

public U0 DocAppendLine(U8 *filename, U8 *line)
{//Append a line to a doc file.
  CDoc *doc=DocRead(filename);
  DocAppend(doc, line);
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

