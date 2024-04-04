Bool IsFile(U8* filename)
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

Bool Cdd(U8 *dirname=NULL,Bool make_dirs=FALSE)
{//Change directory and list contents
  if(Cd(dirname,make_dirs))
    return Dir>0;
  else
    return FALSE;
}
