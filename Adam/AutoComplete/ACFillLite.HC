#help_index "AutoComplete/Dictionary"
/*Fmt of word lst entry:
  U8 ACD_WORD_CHAR
  U8 word[] with terminating zero
  I16 block;
*/
public U8 *ACDWordPtAt(U8 *st)
{//Point to word in word list.
  I64 i;
  U8 *start=acd.word_lst,*r=start,
      *end=acd.word_lst+acd.word_lst_size;
  if (!st || !*st)
    return acd.word_lst;
  if (acd.word_lst_size)
  {
    while (start+3<end)
    {
      r=(start+end)>>1;
      while (TRUE)
      {
        while (*r!=ACD_WORD_CHAR && r>acd.word_lst)
          r--;
        if ((r[2]==ACD_WORD_CHAR||r[1]==ACD_WORD_CHAR)&&r-3>acd.word_lst)
          r--;
        else
          break;
      }
      if (*r==ACD_WORD_CHAR)
      {
        i=StrICmp(st,r+1);
        if (i<0)
          end=r-1;
        else if (i>0)
          start=r+StrLen(r)+3;
        else
          return r;
      }
      else
        break;
    }
    r=(start+end)>>1;
    while (TRUE)
    {
      while (*r!=ACD_WORD_CHAR && r>acd.word_lst)
        r--;
      if ((r[2]==ACD_WORD_CHAR||r[1]==ACD_WORD_CHAR)&&r-3>acd.word_lst)
        r--;
      else
        break;
    }
    if (*r==ACD_WORD_CHAR && StrICmp(st,r+1)>0)
      r+=StrLen(r)+3;
  }
  if (*r==ACD_WORD_CHAR)
    return r;
  else
    return acd.word_lst;
}

U0 ACDFillin(I64 n)
{
  U8 *s;
  I64 len;
  if (0<=n<acd.num_fillins)
  {
    s=acd.fillins[n]+1;
    len=StrLen(s);
    if (len>ac.partial_len)
      In(s+ac.partial_len);
  }
}


U0 ACDDefUI(CTask *parent=NULL)
{
  U8 *buf;
  buf=MStrPrint("\"Dictionary is not implemented.\n\";View;");
  PopUp(buf,parent);
  Free(buf);
}

U0 ACDDef(I64 n,CTask *parent=NULL)
{
  if (n>=0)
    ACDDefUI(parent);
}

#help_index "AutoComplete"
U0 ACFillIn(I64 n)
{
  U8 *s;
  if (0<=--n<ac.num_fillins)
  {
    s=ac.fillin_matches[n]->str;
    if (StrLen(s)>ac.partial_len)
      In(s+ac.partial_len);
  }
}

U0 ACMan(I64 n,CTask *parent_task=NULL)
{
  CHashAC *tmpw;
  CHashSrcSym *tmph;
  if (0<=--n<ac.num_fillins && (tmpw=ac.fillin_matches[n]) &&
      (tmph=HashFind(tmpw->str,Fs->hash_table,HTG_SRC_SYM)) &&
      tmph->src_link)
    PopUpEd(tmph->src_link,parent_task);
}
