// This is not the same benchmark I did when comparing TOS to Linux
//
// This is just a unit test/demo, it prints as it goes and Yields, the original did not.
//
// TODO finish adding missing BigNum functions and move to a separate library this includes

#ifdef __GNUC__
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
typedef float F64;
typedef uint64_t U64;
typedef int64_t I64;
typedef uint32_t U32;
typedef int32_t I32;
typedef uint16_t U16;
typedef int16_t I16;
typedef uint8_t U8;
typedef int8_t I8;
typedef void U0;
#ifdef __cplusplus
#define BNType class
typedef bool Bool;
#else
#define BNType struct
typedef _Bool Bool;
#endif
#else
#define BNType class
#endif

BNType BigNum
{
#ifdef __cplusplus
public:
#endif
  U32 *array;
};

#ifdef __GNUC__
typedef struct BigNum BigNum;
#endif

U0 BigNumAssign(BigNum *dst,BigNum *src)
{
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    dst -> array[i] = src -> array[i];
  }
}

#define LARGER 1
#define SMALLER -1
#define EQUAL 0

I64 BigNumCmp(BigNum *a,BigNum *b)
{
  I64 i = 160;
  do
  {
    i -= 1;
    if (a -> array[i] > b -> array[i])
    {
      return LARGER;
    }
    else if (a -> array[i] < b -> array[i])
    {
      return SMALLER;
    }
  }
  while (i != 0);
  return EQUAL;
}

I64 BigNumIsZero(BigNum *n)
{
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    if (n -> array[i])
    {
      return 0;
    }
  }
  return 1;
}


U0 BigNumAnd(BigNum *a,BigNum *b,BigNum *c)
{
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    c -> array[i] = (a -> array[i] & b -> array[i]);
  }
}

U0 BigNumOr(BigNum *a,BigNum *b,BigNum *c)
{
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    c -> array[i] = (a -> array[i] | b -> array[i]);
  }
}

U0 BigNumXor(BigNum *a,BigNum *b,BigNum *c)
{
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    c -> array[i] = (a -> array[i] ^ b -> array[i]);
  }
}


U0 BigNumRShiftU32(BigNum *a,I64 nwords)
{
  I64 i;
  if (nwords >= 160)
  {
    for (i = 0; i < 160; ++i)
    {
      a -> array[i] = 0;
    }
    return ;
  }
  for (i = 0; i < 160 - nwords; ++i)
  {
    a -> array[i] = a -> array[i + nwords];
  }
  for (; i < 160; ++i)
  {
    a -> array[i] = 0;
  }
}

U0 BigNumLShiftU32(BigNum *a,I64 nwords)
{
  I64 i;
  for (i = 160 - 1; i >= nwords; --i)
  {
    a -> array[i] = a -> array[i - nwords];
  }
  for (; i >= 0; --i)
  {
    a -> array[i] = 0;
  }
}

U0 BigNumLShiftOne(BigNum *a)
{
  I64 i;
  U32 tmp;
  for (i = 160 - 1; i > 0; --i)
  {
    a -> array[i] = (a -> array[i] << 1) | (a -> array[i - 1] >> ((8 * 4) - 1));
  }


  tmp=a->array[0] << 1;
  a->array[0]=tmp;
}

U0 BigNumRShiftOne(BigNum *a)
{
  I64 i;
  U32 tmp;
  for (i = 0; i < 160 - 1; ++i)
  {
    a -> array[i] = (a -> array[i] >> 1) | (a -> array[i + 1] << ((8 * 4) - 1));
  }

  tmp=a -> array[160 - 1] >> 1;
  a->array[160 - 1]=tmp;
}

U0 BigNumZero(BigNum *n)
{
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    n -> array[i] = 0;
  }
}

U0 BigNumInit(BigNum *n)
{
#ifdef __GNUC__
  n->array=malloc(5*128*4);
#else
  n->array=MAlloc(5*128*4);
#endif
  BigNumZero(n);
}

U0 BigNumFree(BigNum *n)
{
#ifdef __GNUC__
  free(n->array);
#else
  Free(n->array);
  Yield;
#endif
}

U0 BigNumFromU32(BigNum *n,U32 i)
{
  BigNumZero(n);
  n -> array[0] = i;
  n -> array[1] = 0;
}

U0 BigNumFromU64(BigNum *n,U64 i)
{
  U64 tmp = i>>32;
  BigNumZero(n);
  n -> array[0] = i;
  n -> array[1] = tmp;
}

U32 BigNumToU32(BigNum *n)
{
  return n -> array[0];
}

U64 BigNumToU64(BigNum *n)
{
  U64 ret = n->array[1];
  ret <<= 32;
  ret += n -> array[0];
  return ret;
}

/*
U0 BigNumFromString(BigNum *n,U8 *str,I64 nbytes)
{
  BigNumZero(n);
  U32 tmp;
  I64 i = nbytes - 2 * 4;
  I64 j = 0;
  while (i >= 0){
    tmp = 0;
    sscanf(&str[i],"%8x",&tmp);
    n -> array[j] = tmp;
    i -= 2 * 4;
    j += 1;
  }
}



U0 BigNumToStr(BigNum *n,U8 *str,I64 nbytes)
{
  I64 j = 160 - 1;
  I64 i = 0;
  while (j >= 0 && nbytes > i + 1){
    str[i]=0;
    CatPrint(&str[i],"%08x",n->array[j]);

    i += 2 * 4;
    j -= 1;
  }
  j = 0;
  while (str[j] == '0'){
    j += 1;
  }
  for (i = 0; i < nbytes - j; ++i) {
    str[i] = str[i + j];
  }
  str[i] = 0;
}
*/


U0 BigNumDec(BigNum *n)
{
  U32 tmp;
  U32 res;
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    tmp = n -> array[i];
    res = tmp - 1;
    n -> array[i] = res;
    if (!(res > tmp))
    {
      break;
    }
  }
}

U0 BigNumInc(BigNum *n)
{
  U32 res;
  U64 tmp;
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    tmp = n -> array[i];
    res = tmp + 1;
    n -> array[i] = res;
    if (res > tmp)
    {
      break;
    }
  }
}

U0 BigNumAdd(BigNum *a,BigNum *b,BigNum *c)
{
  U64 tmp;
  I32 carry = 0;
  I64 i;
  for (i = 0; i < 160; ++i)
  {

    tmp = a -> array[i];
    tmp += b -> array[i];
    tmp += carry;

    carry = (tmp > 0xFFFFFFFF);
    c -> array[i] = tmp & 0xFFFFFFFF;
  }
}

U0 BigNumSub(BigNum *a,BigNum *b,BigNum *c)
{
  U64 res;
  U64 tmp1;
  U64 tmp2;
  I32 borrow = 0;
  I64 i;
  for (i = 0; i < 160; ++i)
  {
    tmp1 = a -> array[i];
    tmp1 += 0x100000000;

    tmp2 = b -> array[i];
    tmp2 += borrow;

    res = tmp1 - tmp2;
    c -> array[i] = res & 0xFFFFFFFF;
    borrow = (res <= 0xFFFFFFFF);
  }
}

U0 BigNumMul(BigNum *a,BigNum *b,BigNum *c)
{
  BigNum row;
  BigNum tmp;
  I64 i,j;
  U64 intermediate;
  BigNumInit(&tmp);
  BigNumInit(&row);

  BigNumZero(c);
  for (i = 0; i < 160; ++i)
  {
    BigNumZero(&row);
    for (j = 0; j < 160; ++j)
    {
      if (i + j < 160)
      {
        BigNumZero(&tmp);
        intermediate = a -> array[i];
        intermediate *= b -> array[j];

        BigNumFromU64(&tmp,intermediate);
        BigNumLShiftU32(&tmp,i + j);
        BigNumAdd(&tmp,&row,&row);
      }
    }
    BigNumAdd(c,&row,c);
  }
  BigNumFree(&tmp);
  BigNumFree(&row);
}

U0 BigNumDiv(BigNum *a,BigNum *b,BigNum *c)
{
  BigNum current;
  BigNum denom;
  BigNum tmp;

  U64 half_max = 0x80000000;
  Bool overflow = 0;

  BigNumInit(&current);
  BigNumInit(&denom);
  BigNumInit(&tmp);
  BigNumFromU32(&current,1);
  BigNumAssign(&denom,b);
  BigNumAssign(&tmp,a);

  while (BigNumCmp(&denom,a) != LARGER)
  {
    if (denom.array[160 - 1] >= half_max)
    {
      overflow = 1;
      break;
    }
    BigNumLShiftOne(&current);
    BigNumLShiftOne(&denom);
  }
  if (!overflow)
  {
    BigNumRShiftOne(&denom);
    BigNumRShiftOne(&current);
  }
  BigNumZero(c);
  while (!BigNumIsZero(&current))
  {
    if (BigNumCmp(&tmp,&denom) != SMALLER)
    {
      BigNumSub(&tmp,&denom,&tmp);
      BigNumOr(c,&current,c);
    }
    BigNumRShiftOne(&current);
    BigNumRShiftOne(&denom);
  }

  BigNumFree(&current);
  BigNumFree(&denom);
  BigNumFree(&tmp);

}

U0 BigNumLShift(BigNum *a,BigNum *b,I64 nbits)
{
  BigNumAssign(b,a);
  I64 i;
  I64 nbits_pr_word = 4 * 8;
  I64 nwords = nbits / nbits_pr_word;
  U32 tmp;
  if (nwords != 0)
  {
    BigNumLShiftU32(b,nwords);
    nbits -= (nwords * nbits_pr_word);
  }
  if (nbits != 0)
  {
    for (i = 160 - 1; i > 0; --i)
    {
      b -> array[i] = (b -> array[i] << nbits) | (b -> array[i - 1] >> ((8 * 4) - nbits));
    }

    tmp = b->array[i]<<nbits;
    b->array[i]=tmp;
  }
}

U0 BigNumRShift(BigNum *a,BigNum *b,I64 nbits)
{
  BigNumAssign(b,a);
  I64 i;
  I64 nbits_pr_word = 4 * 8;
  I64 nwords = nbits / nbits_pr_word;
  if (nwords != 0)
  {
    BigNumRShiftU32(b,nwords);
    nbits -= (nwords * nbits_pr_word);
  }
  if (nbits != 0)
  {
    for (i = 0; i < 160 - 1; ++i)
    {
      b -> array[i] = (b -> array[i] >> nbits) | (b -> array[i + 1] << ((8 * 4) - nbits));
    }
    b -> array[i] >>= nbits;
  }
}

U0 BigNumDivMod(BigNum *a,BigNum *b,BigNum *c,BigNum *d)
{
  BigNum tmp;
  BigNumInit(&tmp);
  BigNumDiv(a,b,c);
  BigNumMul(c,b,&tmp);
  BigNumSub(a,&tmp,d);
  BigNumFree(&tmp);
}

U0 BigNumMod(BigNum *a,BigNum *b,BigNum *c)
{
  BigNum tmp;
  BigNumInit(&tmp);
  BigNumDivMod(a,b,&tmp,c);
  BigNumFree(&tmp);
}

U0 BigNumPow(BigNum *a,BigNum *b,BigNum *c)
{
  BigNum tmp, bcopy;

  BigNumZero(c);
  if (BigNumCmp(b,c) == EQUAL)
  {
    BigNumInc(c);
  }
  else
  {
    BigNumInit(&tmp);
    BigNumInit(&bcopy);

    BigNumAssign(&bcopy,b);
    BigNumAssign(&tmp,a);
    BigNumDec(&bcopy);
    while (!BigNumIsZero(&bcopy))
    {
      BigNumMul(&tmp,a,c);
      BigNumDec(&bcopy);
      BigNumAssign(&tmp,c);
    }
    BigNumAssign(c,&tmp);
    BigNumFree(&tmp);
    BigNumFree(&bcopy);
  }
}

U0 BigNumIsqrt(BigNum *a,BigNum *b)
{
  BigNum low;
  BigNum high;
  BigNum mid;
  BigNum tmp;
  BigNumInit(&low);
  BigNumInit(&high);
  BigNumInit(&mid);
  BigNumInit(&tmp);

  BigNumAssign(&high,a);
  BigNumRShift(&high,&mid,1);
  BigNumInc(&mid);
  while (BigNumCmp(&high,&low) > 0)
  {
    BigNumMul(&mid,&mid,&tmp);
    if (BigNumCmp(&tmp,a) > 0)
    {
      BigNumAssign(&high,&mid);
      BigNumDec(&high);
    }
    else
    {
      BigNumAssign(&low,&mid);
    }
    BigNumSub(&high,&low,&mid);
    BigNumRShiftOne(&mid);
    BigNumAdd(&low,&mid,&mid);
    BigNumInc(&mid);
  }
  BigNumAssign(b,&low);

  BigNumFree(&low);
  BigNumFree(&high);
  BigNumFree(&mid);
  BigNumFree(&tmp);
}


U0 BnPiKernel(I64 digits, U8 *digits_out)
{
  I64 j;
  U32 q = 1;
  U32 r = 180;
  U32 t = 60;
  U32 i = 2;

  BigNum bq;
  BigNum br;
  BigNum bt;
  BigNum bi;
  BigNum bu;
  BigNum by;
  BigNum btmp;
  BigNum btmp2;
  BigNum btmp3;

  BigNumInit(&bq);
  BigNumInit(&br);
  BigNumInit(&bt);
  BigNumInit(&bi);
  BigNumInit(&bu);
  BigNumInit(&by);
  BigNumInit(&btmp);
  BigNumInit(&btmp2);
  BigNumInit(&btmp3);

  BigNumFromU32(&bq,q);
  BigNumFromU32(&br,r);
  BigNumFromU32(&bt,t);
  BigNumFromU32(&bi,i);

  for (j = 0; j < digits; j++)
  {
    Yield;
    BigNumLShift(&bi,&btmp3,1);
    BigNumAdd(&btmp3,&bi,&btmp);
    BigNumInc(&btmp);
    BigNumAssign(&btmp2,&btmp);
    BigNumInc(&btmp2);
    BigNumMul(&btmp2,&btmp,&btmp3);
    BigNumLShift(&btmp3,&btmp2,1);
    BigNumAdd(&btmp3,&btmp2,&bu);
    Yield;
    BigNumLShift(&bi,&btmp,4);
    BigNumLShift(&bi,&btmp2,3);
    BigNumAdd(&btmp,&btmp2,&btmp3);
    BigNumLShift(&bi,&btmp,1);
    BigNumAdd(&btmp,&btmp3,&btmp2);
    BigNumAdd(&btmp2,&bi,&btmp);
    Yield;
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    BigNumDec(&btmp);
    Yield;
    BigNumMul(&btmp,&bq,&btmp2);
    BigNumLShift(&br,&btmp,2);
    BigNumAdd(&br,&btmp,&btmp3);
    BigNumAdd(&btmp2,&btmp3,&btmp);
    BigNumLShift(&bt,&btmp2,2);
    BigNumAdd(&btmp2,&bt,&btmp3);
    Yield;
    BigNumDiv(&btmp,&btmp3,&by);
    Yield;

    *digits_out = '0'+BigNumToU32(&by)&0xff;
    "%c",*digits_out++;
    if (!j)
    {
       *digits_out = '.';
       "%c",*digits_out++;
    }
    Yield;

    BigNumLShift(&bi,&btmp,2);
    BigNumAdd(&btmp,&bi,&btmp2);
    BigNumDec(&btmp2);
    BigNumDec(&btmp2);
    BigNumMul(&bq,&btmp2,&btmp);
    BigNumMul(&by,&bt,&btmp2);
    BigNumAdd(&btmp,&br,&btmp3);
    BigNumSub(&btmp3,&btmp2,&btmp);
    BigNumMul(&btmp,&bu,&btmp2);
    Yield;
    BigNumLShift(&btmp2,&btmp,1);
    BigNumLShift(&btmp2,&btmp3,3);
    BigNumAdd(&btmp,&btmp3,&br);
    BigNumMul(&bt,&bu,&btmp);
    BigNumAssign(&bt,&btmp);
    BigNumLShift(&bi,&btmp2,1);
    BigNumDec(&btmp2);
    Yield;
    BigNumLShift(&btmp2,&btmp,1);
    BigNumMul(&btmp,&bq,&btmp2);
    BigNumMul(&btmp2,&bi,&btmp);
    BigNumLShift(&btmp,&btmp2,2);
    BigNumAdd(&btmp,&btmp2,&bq);
    BigNumInc(&bi);
  }

  BigNumFree(&bq);
  BigNumFree(&br);
  BigNumFree(&bt);
  BigNumFree(&bi);
  BigNumFree(&bu);
  BigNumFree(&by);
  BigNumFree(&btmp);
  BigNumFree(&btmp2);
  BigNumFree(&btmp3);

}
