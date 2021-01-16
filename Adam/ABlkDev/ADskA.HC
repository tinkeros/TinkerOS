#help_index "File/Cmd Line (Typically);Cmd Line (Typically)"
public U8 *DBlk(I64 blk,Bool write=FALSE)
{//Dump disk block. Optionally, write.
//If you set write to TRUE, the block will
  //be written when you press <ESC>.
  //See $LK,"::/Demo/Dsk/DskRaw.HC"$.
  U8 *buf=MAlloc(BLK_SIZE);
  BlkRead(Fs->cur_dv,buf,blk,1);
  DocD(buf,BLK_SIZE);
  if (write)
  {
    "Edit and press <ESC> to write or <SHIFT-ESC>\n";
    if (View)
    {
      "Write\n";
      BlkWrite(Fs->cur_dv,buf,blk,1);
    }
  }
  return buf;
}

public U8 *DClus(I64 c,Bool write=FALSE,I64 num=0)
{//Dump disk clus. Optionally, write.
//If you set write to TRUE, the clus will
  //be written when you press <ESC>.
  //See $LK,"::/Demo/Dsk/DskRaw.HC"$.
  //Do $LK,"Dir",A="MN:Dir"$("*",TRUE); to get clus numbers of files.
  U8 *buf=MAlloc(Fs->cur_dv->spc<<BLK_SIZE_BITS);
  c=ClusNumNext(Fs->cur_dv,c,num);
  ClusRead(Fs->cur_dv,buf,c,1);
  "Clus:%X\n"
  ,c;
  DocD(buf,Fs->cur_dv->spc<<BLK_SIZE_BITS);
  if (write)
  {
    "Edit and press <ESC> to write or <SHIFT-ESC>\n";
    if (View)
    {
      "Write\n";
      ClusWrite(Fs->cur_dv,buf,c,1);
    }
  }
  return buf;
}

public U8 *Dump(U8 *filename,Bool write=FALSE)
{//Dump file. Optionally, write.
//If you set write to TRUE, the file will
  //be written when you press <ESC>.
  U8 *buf;
  I64 size;
  if (buf=FileRead(filename,&size))
  {
    DocD(buf,size);
    if (write)
    {
      "Edit and press <ESC> to write or <SHIFT-ESC>\n";
      if (View)
      {
        "Write\n";
        FileWrite(filename,buf,size);
      }
    }
  }
  return buf;
}

