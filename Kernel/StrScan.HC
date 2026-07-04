I64 Str2I64(U8 *st,I64 radix=10,U8 **_end_ptr=NULL)
{//String to I64. Similar to strtoul().
//Allows radix change with "0x20" "0b1010" "0d123" "0o18".
  //Be careful of Str2I64("0b101",16)-->0xB101.
  Bool neg=FALSE;
  I64 ch,res=0;
  if (!st || !(2<=radix<=36))
  {
    if (_end_ptr) *_end_ptr=st;
    return 0;
  }
  while (Bt(char_bmp_white_space,*st))
    st++;
  while (TRUE)
    switch (*st)
    {
    case '-':
      st++;
      neg=!neg;
      break;
    case '+':
      st++;
      break;
    case '0':
      st++;
      ch=ToUpper(*st);
      if (ch>='B' && (radix<=10 || ch>'A'+radix-11))
        switch (ch)
        {
        case 'B':
          radix=2;
          st++;
          break;
        case 'D':
          radix=10;
          st++;
          break;
        case 'X':
          radix=16;
          st++;
          break;
        }
    default:
      goto ai_cont;
    }
ai_cont:
  while (ch=ToUpper(*st++))
  {
    if (radix>10)
    {
      if ('0'<=ch<='9')
        res=res*radix+ch-'0';
      else if ('A'<=ch<='A'+radix-11)
        res=res*radix+ch-'A'+10;
      else
        break;
    }
    else if ('0'<=ch<='0'+radix-1)
      res=res*radix+ch-'0';
    else
      break;
  }
  if (_end_ptr) *_end_ptr=st-1;
  if (neg)
    return -res;
  else
    return res;
}

