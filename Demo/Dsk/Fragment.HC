#help_index "Fragment"

#define FRG_MAX_SIZE (256*1024)

I64 frg_files_done=0,frg_files_skipped=0;

Bool FrgHasSuffix(U8 *name,I64 len,U8 *suffix)
{
  I64 suf_len=StrLen(suffix);
  return len>=suf_len && !StrNICmp(name+len-suf_len,suffix,suf_len);
}

Bool FrgExtMatch(U8 *name,I64 len,U8 *ext)
{//True if name ends in .ext, .ext.Z or .ext.C (case-insensitive)
  U8 suffix[32];
  StrPrint(suffix,".%s",ext);
  if (FrgHasSuffix(name,len,suffix))
    return TRUE;
  StrPrint(suffix,".%s.Z",ext);
  if (FrgHasSuffix(name,len,suffix))
    return TRUE;
  StrPrint(suffix,".%s.C",ext);
  return FrgHasSuffix(name,len,suffix);
}

Bool FrgIsExcluded(U8 *name)
{//Skip boot images and large files
  I64 len=StrLen(name);
  if (FrgExtMatch(name,len,"ISO"))
    return TRUE;
  if (FrgExtMatch(name,len,"BIN"))
    return TRUE;
  if (FrgExtMatch(name,len,"GR"))
    return TRUE;
  if (FrgExtMatch(name,len,"DATA"))
    return TRUE;
  if (FrgExtMatch(name,len,"TXT"))
    return TRUE;
  return FALSE;
}

Bool FrgFile(CDirEntry *de)
{//Read file/copy to temp/delete original/rename back
  U8 *buf,*tmp_name;
  I64 size,attr;
  Bool res=FALSE;
  buf=FileRead(de->full_name,&size,&attr);
  if (!buf)
    return FALSE;
  tmp_name=MStrPrint("%s.FRG",de->full_name);
  Silent;
  if (FileWrite(tmp_name,buf,size,de->datetime,attr))
  {
    Del(de->full_name);
    Move(tmp_name,de->full_name);
    res=TRUE;
  }
  Silent(OFF);
  Free(tmp_name);
  Free(buf);
  return res;
}

I64 FrgPass(U8 drv_let,I64 pass_num,I64 passes,I64 num_files)
{//Returns number of files scrambled this pass
  CDirEntry *tree,*de,**eligible;
  U8 *mask;
  I64 i,j,total=0,done=0;
  mask=MStrPrint("%C:/*",drv_let);
  tree=FilesFind(mask,FUF_RECURSE|FUF_JUST_FILES);
  Free(mask);
  de=tree;
  while (de)
  {
    if (!FrgIsExcluded(de->full_name) && de->size<=FRG_MAX_SIZE)
      total++;
    de=de->next;
  }
  if (total>0)
  {
    eligible=CAlloc(total*sizeof(CDirEntry *));
    i=0;
    de=tree;
    while (de)
    {
      if (!FrgIsExcluded(de->full_name) && de->size<=FRG_MAX_SIZE)
        eligible[i++]=de;
      de=de->next;
    }
    while (i>0 && !(num_files>0 && done>=num_files))
    {
      de=eligible[RandU32%i];
      "Pass %d/%d: %s\n",pass_num,passes,de->full_name;
      if (FrgFile(de))
      {
        done++;
        frg_files_done++;
      }
      else
        frg_files_skipped++;
    }
    Free(eligible);
  }
  DirTreeDel(tree);
  return done;
}

public U0 Fragment(U8 drv_let=0,I64 passes=3,I64 num_files=100)
{
  CDrv *dv;
  I64 pass;
  if (!drv_let)
    drv_let=Fs->cur_dv->drv_let;
  if (!(dv=Let2Drv(drv_let,FALSE)))
  {
    "Drive %C: is not mounted!\n",drv_let;
    return;
  }
  if (dv->fs_type!=FSt_FAT32)
  {
    "Drive %C: is not a FAT32, nothing to do!\n",drv_let;
    return;
  }
  if (passes<=0)
    passes=1;
  "Are you sure you want to fragment files on drive %C: ",drv_let;
  if (!YorN('n'))
    return;
  frg_files_done=0;
  frg_files_skipped=0;
  for (pass=1; pass<=passes; pass++)
  {
    if (!FrgPass(drv_let,pass,passes,num_files))
      break;
  }
  "Fragmention done.  %d file(s) rewritten, %d skipped.\n",
      frg_files_done,frg_files_skipped;
}

#help_index ""

Fragment;
