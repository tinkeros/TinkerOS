class CRpRem
{
  CRpRem *next;
  I64 pos;
};

U8 *g_rp_buf;
CRpRem *g_rp_head,*g_rp_tail;
I64 g_rp_rawpos, g_rp_cnt, g_rp_fake_nest;

U0 RpInit(U8 *buf)
{
  g_rp_buf=buf;
  g_rp_rawpos=0;
  g_rp_head=NULL;
  g_rp_tail=NULL;
  g_rp_cnt=0;
  g_rp_fake_nest=0;
}

U0 RpMark(I64 pos)
{
  CRpRem *r,*prev,*cur;
  if (pos<0)
    return;
  prev=NULL;
  cur=g_rp_head;
  while (cur && cur->pos<pos)
  {
    prev=cur;
    cur=cur->next;
  }
  if (cur && cur->pos==pos)
    return;
  r=CAlloc(sizeof(CRpRem));
  r->pos=pos;
  r->next=cur;
  if (prev)
    prev->next=r;
  else
    g_rp_head=r;
  if (!cur)
    g_rp_tail=r;
  g_rp_cnt++;
}

Bool RpHasPlainIf(U8 *buf)
{
  I64 pos=0,ch,quote;
  while (ch=buf[pos])
  {
    if (ch=='/' && buf[pos+1]=='/')
    {
      pos+=2;
      while ((ch=buf[pos]) && ch!='\n')
        pos++;
    }
    else if (ch=='/' && buf[pos+1]=='*')
    {
      pos+=2;
      while ((ch=buf[pos]) && !(ch=='*' && buf[pos+1]=='/'))
        pos++;
      if (!ch)
        return FALSE;
      pos+=2;
    }
    else if (ch=='"' || ch=='\'')
    {
      quote=ch;
      pos++;
      while ((ch=buf[pos]) && ch!=quote)
      {
        if (ch=='\\' && buf[pos+1])
          pos++;
        pos++;
      }
      if (!ch)
        return FALSE;
      pos++;
    }
    else if (ch=='#' && buf[pos+1]=='i' && buf[pos+2]=='f' &&
             !Bt(char_bmp_alpha_numeric,buf[pos+3]))
      return TRUE;
    else
      pos++;
  }
  return FALSE;
}

I64 RpRawFind(I64 target_ch)
{
  I64 ch,p,quote;
  while (ch=g_rp_buf[g_rp_rawpos])
  {
    if (ch=='#')
    {
      p=g_rp_rawpos+1;
      while (g_rp_buf[p]==' ' || g_rp_buf[p]=='\t')
        p++;
      if (g_rp_buf[p]=='d' && g_rp_buf[p+1]=='e' && g_rp_buf[p+2]=='f' &&
          g_rp_buf[p+3]=='i' && g_rp_buf[p+4]=='n' && g_rp_buf[p+5]=='e' &&
          !Bt(char_bmp_alpha_numeric,g_rp_buf[p+6]))
      {
        p+=6;
        while (g_rp_buf[p]==' ' || g_rp_buf[p]=='\t')
          p++;
        while (Bt(char_bmp_alpha_numeric,g_rp_buf[p]))
          p++;
        while ((ch=g_rp_buf[p]) && ch!='\n')
        {
          if (ch=='\\' && (g_rp_buf[p+1]=='\n' || g_rp_buf[p+1]=='\r'))
          {
            p++;
            if (g_rp_buf[p]=='\r' && g_rp_buf[p+1]=='\n')
              p++;
          }
          p++;
        }
        g_rp_rawpos=p;
      }
      else
        g_rp_rawpos++;
    }
    else if (ch=='/' && g_rp_buf[g_rp_rawpos+1]=='/')
    {
      g_rp_rawpos+=2;
      while ((ch=g_rp_buf[g_rp_rawpos]) && ch!='\n')
        g_rp_rawpos++;
    }
    else if (ch=='/' && g_rp_buf[g_rp_rawpos+1]=='*')
    {
      g_rp_rawpos+=2;
      while ((ch=g_rp_buf[g_rp_rawpos]) &&
             !(ch=='*' && g_rp_buf[g_rp_rawpos+1]=='/'))
        g_rp_rawpos++;
      if (!ch)
        return -1;
      g_rp_rawpos+=2;
    }
    else if (ch=='"' || ch=='\'')
    {
      quote=ch;
      g_rp_rawpos++;
      while ((ch=g_rp_buf[g_rp_rawpos]) && ch!=quote)
      {
        if (ch=='\\' && g_rp_buf[g_rp_rawpos+1])
          g_rp_rawpos++;
        g_rp_rawpos++;
      }
      if (!ch)
        return -1;
      g_rp_rawpos++;
    }
    else if (ch==target_ch)
    {
      g_rp_rawpos++;
      return g_rp_rawpos-1;
    }
    else
      g_rp_rawpos++;
  }
  return -1;
}

I64 RpLex(CCmpCtrl *cc)
{
  I64 pos=-1;
  if (cc->token=='(' || cc->token==')')
  {
    if (g_rp_fake_nest>0)
    {
      if (cc->token=='(')
        g_rp_fake_nest++;
      else
        g_rp_fake_nest--;
    }
    else if (cc->lex_include_stk->depth==-1)
      pos=RpRawFind(cc->token);
    else if (cc->token=='(')
      g_rp_fake_nest=1;
  }
  Lex(cc);
  return pos;
}

U0 RpResyncTo(CCmpCtrl *cc,I64 tok1,I64 tok2)
{
  I64 depth=0;
  while (cc->token!=TK_EOF)
  {
    if (!depth && (cc->token==tok1 || cc->token==tok2))
      return;
    if (cc->token=='(' || cc->token=='[' || cc->token=='{')
      depth++;
    else if (cc->token==')' || cc->token==']' || cc->token=='}')
    {
      if (!depth)
        return;
      depth--;
    }
    RpLex(cc);
  }
}

U0 RpExpectAndSkip(CCmpCtrl *cc,I64 tok)
{
  if (cc->token!=tok)
    RpResyncTo(cc,tok,TK_EOF);
  if (cc->token==tok)
    RpLex(cc);
}

I64 RpScanExpr(CCmpCtrl *cc)
{
  I64 max_prec=PREC_NULL,left_prec=PREC_MAX,
      paren_prec,unary_pre_prec,unary_post_prec,term_max,
      open_pos,close_pos,cur_op,prec_byte,
      pp_bare,pp_left,pp_right,lp_bare,lp_left,co_bare,
      inner_max,saved_paren_prec;

  while (TRUE)
  {
    unary_pre_prec=PREC_NULL;
    unary_post_prec=PREC_NULL;
    paren_prec=PREC_NULL;
    open_pos=-1;
    close_pos=-1;

    while (cc->token=='~' || cc->token=='!' || cc->token=='-' ||
           cc->token=='*' || cc->token=='&' || cc->token=='+' ||
           cc->token==TK_PLUS_PLUS || cc->token==TK_MINUS_MINUS)
    {
      unary_pre_prec=PREC_UNARY_PRE;
      RpLex(cc);
    }

    if (cc->token==')' || cc->token==']' || cc->token=='}' ||
        cc->token==';' || cc->token==',' || cc->token=='{' ||
        cc->token==TK_EOF)
    {
      term_max=unary_pre_prec;
    }
    else
    {
      if (cc->token=='(')
      {
        open_pos=RpLex(cc);
        inner_max=RpScanExpr(cc);
        if (cc->token==')')
        {
          close_pos=RpLex(cc);
          if (open_pos>=0 && close_pos>=0)
            paren_prec=inner_max;
        }
      }
      else
        RpLex(cc);

      while (TRUE)
      {
        if (cc->token=='.' || cc->token==TK_DEREFERENCE)
        {
          unary_post_prec=PREC_TERM;
          RpLex(cc);
          if (cc->token==TK_IDENT)
            RpLex(cc);
        }
        else if (cc->token=='[')
        {
          unary_post_prec=PREC_TERM;
          RpLex(cc);
          RpScanExpr(cc);
          if (cc->token==']')
            RpLex(cc);
        }
        else if (cc->token=='(')
        {
          unary_post_prec=PREC_TERM;
          RpLex(cc);
          if (cc->token!=')')
          {
            while (TRUE)
            {
              RpScanExpr(cc);
              if (cc->token!=',')
                break;
              RpLex(cc);
            }
          }
          if (cc->token==')')
            RpLex(cc);
        }
        else if (cc->token==TK_PLUS_PLUS || cc->token==TK_MINUS_MINUS)
        {
          unary_post_prec=PREC_UNARY_POST;
          RpLex(cc);
        }
        else
          break;
      }

      if (unary_pre_prec>PREC_TERM)
        term_max=unary_pre_prec;
      else
        term_max=PREC_TERM;
    }

    if (term_max>max_prec)
      max_prec=term_max;
    saved_paren_prec=paren_prec;

    if (paren_prec)
    {
      if (unary_pre_prec || unary_post_prec)
      {
        if (paren_prec<=unary_pre_prec && !unary_post_prec)
        {
          RpMark(open_pos);
          RpMark(close_pos);
          if (saved_paren_prec>max_prec)
            max_prec=saved_paren_prec;
        }
        paren_prec=PREC_NULL;
      }
      else if (paren_prec<=PREC_UNARY_PRE+ASSOC_MASK)
      {
        RpMark(open_pos);
        RpMark(close_pos);
        if (saved_paren_prec>max_prec)
          max_prec=saved_paren_prec;
      }
    }

    cur_op=cmp.binary_ops[cc->token];
    if (!cur_op)
    {
      if (paren_prec>PREC_UNARY_PRE+ASSOC_MASK)
      {
        pp_bare=paren_prec&~ASSOC_MASK;
        pp_left=paren_prec&ASSOCF_LEFT;
        lp_bare=left_prec&~ASSOC_MASK;
        lp_left=left_prec&ASSOCF_LEFT;
        if (pp_bare<=lp_bare-pp_left-lp_left)
        {
          RpMark(open_pos);
          RpMark(close_pos);
          if (saved_paren_prec>max_prec)
            max_prec=saved_paren_prec;
        }
      }
      return max_prec;
    }

    prec_byte=cur_op.u8[2];
    if (paren_prec>PREC_UNARY_PRE+ASSOC_MASK)
    {
      pp_bare=paren_prec&~ASSOC_MASK;
      pp_right=paren_prec&ASSOCF_RIGHT;
      lp_bare=left_prec&~ASSOC_MASK;
      co_bare=prec_byte&~ASSOC_MASK;
      if (pp_bare<lp_bare+pp_right && pp_bare<co_bare+!pp_right)
      {
        RpMark(open_pos);
        RpMark(close_pos);
        if (saved_paren_prec>max_prec)
          max_prec=saved_paren_prec;
      }
    }
    if (prec_byte>max_prec)
      max_prec=prec_byte;
    left_prec=prec_byte;
    RpLex(cc);
  }
  return max_prec;
}

U0 RpStatementStep(CCmpCtrl *cc)
{
  I64 kw,cur_op;

  if (cc->token==TK_IDENT)
  {
    kw=PrsKeyWord(cc);
    if (kw==KW_IF || kw==KW_WHILE || kw==KW_SWITCH)
    {
      RpLex(cc);
      if (cc->token=='(')
      {
        RpLex(cc);
        RpScanExpr(cc);
        RpExpectAndSkip(cc,')');
      }
      return;
    }
    if (kw==KW_FOR)
    {
      RpLex(cc);
      if (cc->token=='(')
      {
        RpLex(cc);
        RpScanExpr(cc);
        RpExpectAndSkip(cc,';');
        RpScanExpr(cc);
        RpExpectAndSkip(cc,';');
        RpScanExpr(cc);
        RpExpectAndSkip(cc,')');
      }
      return;
    }
    if (kw==KW_RETURN)
    {
      RpLex(cc);
      if (cc->token!=';')
        RpScanExpr(cc);
      return;
    }
    RpScanExpr(cc);
    return;
  }

  if (cc->token=='(' || cc->token=='~' || cc->token=='!' ||
      cc->token=='-' || cc->token=='*' || cc->token=='&' ||
      cc->token=='+' || cc->token==TK_PLUS_PLUS ||
      cc->token==TK_MINUS_MINUS || cc->token=='[')
  {
    RpScanExpr(cc);
    return;
  }

  cur_op=cmp.binary_ops[cc->token];
  if (cur_op && cur_op.u8[2]&~ASSOC_MASK==PREC_ASSIGN)
  {
    RpLex(cc);
    RpScanExpr(cc);
    return;
  }

  RpLex(cc);
}

U0 RpScanFile(CCmpCtrl *cc)
{
  Lex(cc);
  while (cc->token!=TK_EOF)
    RpStatementStep(cc);
}

U0 RmParens(U8 *filename)
{
  I64 size,i,j;
  U8 *buf,*out,*suffix;
  CCmpCtrl *cc;
  CRpRem *r;

  buf=FileRead(filename,&size);
  if (!buf)
  {
    "RmParens: can't read '%s'\n",filename;
    return;
  }

  if (RpHasPlainIf(buf))
  {
    "RmParens: '%s' uses a plain #if directive -- "
        "refusing (see RpHasPlainIf's comment)\n",filename;
    Free(buf);
    return;
  }

  RpInit(buf);
  cc=CmpCtrlNew(buf,CCF_DONT_FREE_BUF,filename);
  RpScanFile(cc);

  if (!g_rp_cnt)
  {
    "RmParens: no redundant parens found in '%s'\n",filename;
    Free(buf);
    return;
  }

  out=MAlloc(size+1);
  r=g_rp_head;
  i=0;
  j=0;
  while (i<size)
  {
    if (r && r->pos==i)
    {
      r=r->next;
      i++;
    }
    else
      out[j++]=buf[i++];
  }
  out[j]=0;
  FileWrite(filename,out,j);
  if (g_rp_cnt==1)
    suffix="";
  else
    suffix="s";
  "RmParens: removed %d redundant paren char%s from '%s'\n",
      g_rp_cnt,suffix,filename;
  Free(out);
  Free(buf);
}

