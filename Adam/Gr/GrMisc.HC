I64 GrDir(U8 *files_find_mask="*.GR*",Bool full=FALSE)
{//List .GR* images in directory.
  CDirEntry *tmpde1=NULL,*tmpde2;
  U8 *st;
  CDateStruct ds;
  I64 i,csize=0xFFFF,c=0xFFFF,res=0;
  CDC *dc;
  CSprite *elems;

  tmpde1=FilesFind(files_find_mask);
  if (!(st=DirCur))
    PrintErr("Invalid Drive\n");
  else
  {
    if (tmpde1)
    {
      Free(st);
      st=MAllocIdent(tmpde1->full_name);
      StrLastRem(st,"/");
      if (!st[2])
        StrCpy(st+2,"/");
      tmpde2=tmpde1;
      while (tmpde2)
      {
        if (tmpde2->size>csize)
          csize=tmpde2->size;
        if (tmpde2->clus>c)
          c=tmpde2->clus;
        tmpde2=tmpde2->next;
      }
      csize=Bsr(csize)/4+1;
      c=Bsr(c)/4+1;
      "$$MA,T=\"Directory\",LM=\"PopUpCd;Dir;\n\"$$of%s\n"
      ,st;
      if (full)
        "__DATE____TIME__%*ts%*ts\n",
        csize,"SIZE",c,"BLK";
      else
        "DATE_TIME_%*ts\n",csize,"SIZE";
      while (tmpde1)
      {
        tmpde2=tmpde1->next;
        res++;
        if (full)
          "%D%T%0*tX%0*tX ",tmpde1->datetime,tmpde1->datetime,
          csize,tmpde1->size,c,tmpde1->clus;
        else
        {
          Date2Struct(&ds,tmpde1->datetime+local_time_offset);
          "%02d/%02d%02d:%02d%0*tX "
          ,ds.mon,ds.day_of_mon,ds.hour,ds.min,
          csize,tmpde1->size;
        }
        if (tmpde1->attr & RS_ATTR_DIR)
          PutDirLink(tmpde1->name,tmpde1->full_name);
        else {
          dc=GRRead(tmpde1->full_name);
          elems=DC2Sprite(dc);
          DocSprite(NULL,elems);
          for (i=0;i<dc->height/FONT_HEIGHT/2+1;i++) "\n";
          Free(elems);
          PutFileLink(tmpde1->name,tmpde1->full_name);
          for (i=0;i<dc->height/FONT_HEIGHT/2+1;i++) "\n";
          DCDel(dc);
        }
        '\n';
        DirEntryDel(tmpde1);
        tmpde1=tmpde2;
      }
    }
    else
      "No matching entries\n";
    Free(st);
  }
  return res;
}
