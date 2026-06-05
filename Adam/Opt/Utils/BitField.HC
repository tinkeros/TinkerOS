// See /Demo/BitField.HC

public I64 CBFG(U8 *x)
{// Gets bitfield value from class.member
  U8 *var_name,*class_name,*member,*ptr;
  I64 mask;
  CMemberLst *ml;
  CHashClass *tmpc;
  CHashGlblVar *hp;

  StrScan(x,"%s.%s",&var_name,&member);
  
  hp=HashFind(var_name,Fs->hash_table,HTT_GLBL_VAR);

  if (hp && hp->var_class && hp->var_class->str)
  {
    ptr=HashVal(hp);
    class_name=hp->var_class->str;

    tmpc=HashFind(class_name,Fs->hash_table,HTT_CLASS);
    if (tmpc)
    {
      ml=tmpc->member_lst_and_root;
      while (ml)
      {
        if (!StrCmp(member,ml->str)&&ml->bf_size)
        {
          mask = ((1<<ml->bf_size)-1);
          ptr+=ml->offset;
          switch (ml->size) {
            case 1:
              return (*ptr>>ml->bf_offset)&mask;
            case 2:
              return (*(ptr(U16*))>>ml->bf_offset)&mask;
            case 4:
              return (*(ptr(U32*))>>ml->bf_offset)&mask;
          }
              return (*(ptr(U64*))>>ml->bf_offset)&mask;
        }
        ml=ml->next;
      }
    }
  }
  throw('BADCLASS');
}

public U0 CBFS(U8 *x, U64 val)
{// Sets bitfield value from class.member
  U8 *var_name,*class_name,*member,*ptr;
  I64 mask;
  CMemberLst *ml;
  CHashClass *tmpc;
  CHashGlblVar *hp;

  StrScan(x,"%s.%s",&var_name,&member);
  
  hp=HashFind(var_name,Fs->hash_table,HTT_GLBL_VAR);

  if (hp && hp->var_class && hp->var_class->str)
  {
    ptr=HashVal(hp);
    class_name=hp->var_class->str;

    tmpc=HashFind(class_name,Fs->hash_table,HTT_CLASS);
    if (tmpc)
    {
      ml=tmpc->member_lst_and_root;
      while (ml)
      {
        if (!StrCmp(member,ml->str)&&ml->bf_size)
        {
          mask = ((1<<ml->bf_size)-1);
          ptr+=ml->offset;
          switch (ml->size) {
            case 1:
              *ptr &= ~(mask << ml->bf_offset);
              *ptr |= ((val & mask) << ml->bf_offset);
              break;
            case 2:
              *(ptr(U16*)) &= ~(mask << ml->bf_offset);
              *(ptr(U16*)) |= ((val & mask) << ml->bf_offset);
              break;
            case 4:
              *(ptr(U32*)) &= ~(mask << ml->bf_offset);
              *(ptr(U32*)) |= ((val & mask) << ml->bf_offset);
              break;
            case 8:
              *(ptr(U64*)) &= ~(mask << ml->bf_offset);
              *(ptr(U64*)) |= ((val & mask) << ml->bf_offset);
              break;
          }
          return;
        }
        ml=ml->next;
      }
    }
  }
  throw('BADCLASS');
}

