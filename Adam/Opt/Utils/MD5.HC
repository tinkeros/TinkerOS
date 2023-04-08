U32 SHIFT_ROUNDS[64] =
{
  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
};

U32 CONSTANTS[64] =
{
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
  0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
  0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
  0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
  0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
  0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
  0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
  0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

U32 INITIAL_A = 0x67452301;
U32 INITIAL_B = 0xefcdab89;
U32 INITIAL_C = 0x98badcfe;
U32 INITIAL_D = 0x10325476;

I32
leftrotate (U32 x, U32 y)
{
  U32 steps = y % 32;
  return x << steps | x >> (32 - steps);
}

U0
md5_process_words (U32 *words,
                   U32 *a, U32 *b,
                   U32 *c, U32 *d)
{
  U32 f, g, i, xa, xb, xc, xd;
  xa = *a;
  xb = *b;
  xc = *c;
  xd = *d;
  for (i = 0; i < 64; i++)
  {
    if (i < 16)
    {
      f = xb & xc | ~xb & xd;
      g = i;
    }
    else if (i < 32)
    {
      f = xd & xb | ~xd & xc;
      g = (i * 5 + 1) % 16;
    }
    else if (i < 48)
    {
      f = xb ^ xc ^ xd;
      g = (i * 3 + 5) % 16;
    }
    else
    {
      f = xc ^ (xb | ~xd);
      g = i * 7 % 16;
    }
    f += xa + CONSTANTS[i] + words[g];
    xa = xd;
    xd = xc;
    xc = xb;
    xb += leftrotate(f, SHIFT_ROUNDS[i]);
  }
  *a += xa;
  *b += xb;
  *c += xc;
  *d += xd;
}

U0
md5_process_chunk (U8 *chunk,
                   U32 *a, U32 *b,
                   U32 *c, U32 *d)
{
  U32 *words = chunk;
  md5_process_words (words, a, b, c, d);
}

U0
md5_print (U32 part)
{
  "%02x%02x%02x%02x", part.u8[0], part.u8[1], part.u8[2], part.u8[3];
}

public U0 md5buf(U8 *bytes, I64 len, U8 **res=NULL)
{
  U8 *msg;
  I32 i,msg_len;
  U32 a, b, c, d;
  msg_len = 56 - len % 64;
  if (msg_len < 1)
    msg_len += 64;
  msg_len += len + 8;
  msg = CAlloc(msg_len);
  MemCpy(msg, bytes, len);
  msg[len] = 0x80;
  a = len << 3;
  MemCpy (&msg[msg_len - 8], &a, 4);
  a = INITIAL_A;
  b = INITIAL_B;
  c = INITIAL_C;
  d = INITIAL_D;
  for (i = 0; i < msg_len; i += 64)
    md5_process_chunk(&msg[i], &a, &b, &c, &d);
  if (!res)
  {
    md5_print (a);
    md5_print (b);
    md5_print (c);
    md5_print (d);
    "\n";
  }
  else
  {
    *res = MStrPrint("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", a.u8[0],a.u8[1],a.u8[2],a.u8[3],b.u8[0],b.u8[1],b.u8[2],b.u8[3],c.u8[0],c.u8[1],c.u8[2],c.u8[3],d.u8[0],d.u8[1],d.u8[2],d.u8[3]);
  }
  Free(msg);
}

public U8 *md5(U8 *file, U8 **res=NULL)
{
  I64 size=0;
  U8 *data=FileRead(file,&size);
  if (size>0 && data)
    md5buf(data,size, res);
  Free(data);
  return res;
}
