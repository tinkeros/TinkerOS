U0 ShowVolume()
{
  progress3=GetVolume;
  StrPrint(progress3_desc, "Volume %d %%",progress3);
  progress3_max=100;
  Sleep(1000);
  progress3_max=0;
}

public U8 MInU8(I64 addr)
{
  U8 *w=addr+dev.uncached_alias;
  return *w;
}

public U16 MInU16(I64 addr)
{
  U16 *w=addr+dev.uncached_alias;
  return *w;
}

public U32 MInU32(I64 addr)
{
  U32 *w=addr+dev.uncached_alias;
  return *w;
}

public U64 MInU64(I64 addr)
{
  U64 *w=addr+dev.uncached_alias;
  return *w;
}

public U0 MOutU8(I64 addr, U8 b)
{
  U8 *p=addr+dev.uncached_alias;
  *p=b;
}

public U0 MOutU16(I64 addr, U16 b)
{
  U16 *p=addr+dev.uncached_alias;
  *p=b;
}

public U0 MOutU64(I64 addr, U32 b)
{
  U64 *p=addr+dev.uncached_alias;
  *p=b;
}

public U0 MOutU32(I64 addr, U32 b)
{
  U32 *p=addr+dev.uncached_alias;
  *p=b;
}

public U8 MInU8D(I64 addr, I64 delay=1)
{
  Sleep(delay);
  U8 *w=addr+dev.uncached_alias;
  return *w;
}

public U16 MInU16D(I64 addr, I64 delay=1)
{
  Sleep(delay);
  U16 *w=addr+dev.uncached_alias;
  return *w;
}

public U64 MInU64D(I64 addr, I64 delay=1)
{
  Sleep(delay);
  U64 *w=addr+dev.uncached_alias;
  return *w;
}

public U32 MInU32D(I64 addr, I64 delay=1)
{
  Sleep(delay);
  U32 *w=addr+dev.uncached_alias;
  return *w;
}

public U0 MOutU8D(I64 addr, U8 b, I64 delay=1)
{
  Sleep(delay);
  U8 *p=addr+dev.uncached_alias;
  *p=b;
}

public U0 MOutU16D(I64 addr, U16 b, I64 delay=1)
{
  Sleep(delay);
  U16 *p=addr+dev.uncached_alias;
  *p=b;
}

public U0 MOutU32D(I64 addr, U32 b, I64 delay=1)
{
  Sleep(delay);
  U32 *p=addr+dev.uncached_alias;
  *p=b;
}

public U8 *UncachedDevCAlloc(I64 size)
{
  U8 *buf = CAllocAligned(size,16,Fs->code_heap);

  if (!buf) return NULL;

  return buf+dev.uncached_alias;
}

public U0 UncachedDevFree(U8 *d)
{
  if (d>dev.uncached_alias) Free(d-dev.uncached_alias);
  else Free(d);
}

U8 *MemMove(U8 *dst, U8 *src, I64 n) {
    I64 i;
    U8 *d = dst, *s = src;

    if (d == s || n == 0) {
        return dst;
    }

    if (d < s) {
        for (i = 0; i < n; i++) {
            d[i] = s[i];
        }
    } else {
        for (i = n; i > 0; i--) {
            d[i - 1] = s[i - 1];
        }
    }

    return dst;
}

U0 MemZero(U8 *dst, I64 cnt)
{
  MemSet(dst,0,cnt);
}

U64 ThisFunc()
{// Returns start address of caller function
  U32 final_addr;
  I64 **ptr,of;
  CHashExport *tmpex;

  U8 **rbp=GetRBP;
  CTask *task=Fs;

  while (ChkOnStk(rbp,task))
  {
    ptr=rbp+1;
    if (tmpex=FunSegFind(*ptr,&of))
    {
      if (tmpex->type&HTT_FUN)
      {
        final_addr=*ptr;
        final_addr-=of;
        return final_addr;
      }
    }
    if (rbp>=*rbp)
      break;
    rbp=*rbp;
  }
  return 0;
}

U8 *ThisFuncName()
{// Returns string name of caller function
  I64 **ptr,of;
  CHashExport *tmpex;

  U8 **rbp=GetRBP;
  CTask *task=Fs;

  while (ChkOnStk(rbp,task))
  {
    ptr=rbp+1;
    if (tmpex=FunSegFind(*ptr,&of))
    {
      if (tmpex->type&HTT_FUN)
      {
        if (tmpex->str)
          return tmpex->str;
        return 0;
      }
    }
    if (rbp>=*rbp)
      break;
    rbp=*rbp;
  }
  return 0;
}
