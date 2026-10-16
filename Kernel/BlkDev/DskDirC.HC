public Bool IsFile(U8* filename)
{//Test if file exists
  I64 old_silent=Silent, res;
  try {
    res=Dir(filename);
  }
  catch {
    res=0;
    Fs->catch_except=TRUE;
  }
  Silent(old_silent);
  return res>0;
}
public Bool IsFileZorNotZ(U8* filename)
{//Test if file exists, trying filename with .Z toggled if not found as-is.
  U8 *altname;
  Bool res=IsFile(filename);
  if (!res)
  {
    altname=ToggleZorNotZ(filename);
    res=IsFile(altname);
    Free(altname);
  }
  return res;
}
public Bool Cdd(U8 *dirname=NULL,Bool make_dirs=FALSE)
{//Change directory and list contents
  if(Cd(dirname,make_dirs))
    return Dir>0;
  else
    return FALSE;
}
