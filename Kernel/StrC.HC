#help_index "OtherTinkerOSFuncs"
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
