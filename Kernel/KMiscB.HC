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

