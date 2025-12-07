#help_index "OtherTinkerOSFuncs"

I64 ToLower(I64 ch)
{// Basic lower case conversion implementation
  I64 res=ch;
  if ('A'<=ch<='Z')
    res = ch ^ 0x20;
  return res;
}

Bool YorN(I64 enter_default=0)
{//Wait for user to answer Y or N.
  I64 ch;
  if (ToLower(enter_default)=='y' || ToLower(enter_default)=='n')
    "(y or n, default: %c)? ",ToLower(enter_default);
  else
    "(y or n)? ";
  while (TRUE)
  {
    ch=ToUpper(GetChar(,FALSE));
    if (enter_default && ch=='\n')
      ch=ToUpper(enter_default);
    if (ch=='Y')
    {
      "$$PT$$YES$$FG$$\n";
      return TRUE;
    }
    else if (ch=='N')
    {
      "$$PT$$NO$$FG$$\n";
      return FALSE;
    }
  }
}

Bool AreYouSure()
{//Print "Are you sure" and waits for Y or N.
  "ARE YOU SURE ";
  return YorN;
}

Bool StrContains(U8 *param,U8 *str)
{
  I64 m_cnt=0,len=StrLen(param);
  U8 *p_param=param,*p_str=str;

  while (*p_str)
    {
    m_cnt=0;
    p_param=param;
    while (m_cnt!=len && *p_str++==*p_param++)
      m_cnt++;
    if (m_cnt==len)
      return TRUE;
  }
  return FALSE;
}

I64 GetNumParam(U8 *param,U8 *str)
{
  I64 res=-1,m_cnt=0,len=StrLen(param);
  U8 *p_param=param,*p_str;

  p_str=StrMatch(param,str);

  if (!p_str) return -1;

    m_cnt=0;
    p_param=param;

    while (m_cnt!=len && *p_str++==*p_param++)
      m_cnt++;
    if ((m_cnt==len) && (*p_str=='=' || *p_str==' '))
      {
      p_str++;
      if ('0'<=*p_str<='9')
        {
        res=0;
        while ('0'<=*p_str<='9') {
      res*=10;
      res+=*p_str++-'0';
        }
      }
    }
  return res;
}

U8 GetLetParam(U8 *param,U8 *str)
{
  I64 m_cnt=0,len=StrLen(param);
  U8 *p_param=param,*p_str;

  p_str=StrMatch(param,str);

  if (!p_str) return 0;

    m_cnt=0;
    p_param=param;

    while (m_cnt!=len && *p_str++==*p_param++)
      m_cnt++;
    if ((m_cnt==len) && (*p_str=='=' || *p_str==' '))
      {
      p_str++;
      if (('A'<=*p_str<='Z')||('a'<=*p_str<='z'))
        {
        if (*p_str>=0x61)
        {
          return (*p_str)^0x20;
        }
        return *p_str;
      }
    }
  return 0;
}
