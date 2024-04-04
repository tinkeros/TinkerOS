U8 *FileBaseName(U8 *filename)
{// Returns file name without the path
  U8 *res, *orig, *p;
  if (filename)
  {
    p=orig=StrNew(filename);
    res=MAlloc(StrLen(filename)+1);
    StrLastRem(p,"/",res);
    Free(orig);
  }
  return res;
}


