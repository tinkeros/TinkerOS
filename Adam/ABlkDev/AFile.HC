#help_index "CFile"

U0 GetFileDate(U8 *filename,CDate *cd)
{
  CDirEntry de;
  U8 *cur_dir=StrNew(filename);
  ZeroClass(cd);
  if (FileFind(filename,&de,FUF_JUST_FILES))
  {
    Free(de.full_name);
    ClassCpy(cd, &de.datetime);
  }
  Free(cur_dir);
}

Bool IsFileNewer(U8 *filename, CDate *cd)
{
  CDate cur_cd;
  GetFileDate(filename,&cur_cd);
  if (cur_cd.date>cd->date) return TRUE;
  if (cur_cd.date<cd->date) return FALSE;
  if (cur_cd.time>cd->time) return TRUE;
  return FALSE;
}

#help_index ""
