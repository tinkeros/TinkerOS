#help_index "Math"
public U0 R2P(F64 *_mag=NULL,F64 *_arg=NULL,F64 x,F64 y)
{//Rect to polar
//Returns angle in range (-ã,ã]
  if (_arg)
    *_arg=Arg(x,y);
  if (_mag)
    *_mag=Sqrt(x*x+y*y);
}

public U0 P2R(F64 *_x=NULL,F64 *_y=NULL,F64 mag,F64 arg)
{//Polar to Rect
  if (_x)
    *_x=mag*Cos(arg);
  if (_y)
    *_y=mag*Sin(arg);
}

public F64 Wrap(F64 é,F64 base=-ã)
{//Returns angle in range [base,base+2*ã)
  F64 res=é%(2*ã);
  if (res>=base+2*ã)
    res-=2*ã;
  else if (res<base)
    res+=2*ã;
  return res;
}

public I64 DistSqrI64(I64 x1,I64 y1,I64 x2,I64 y2)
{//Distance-squared between 2 points.
  I64 dx=x1-x2,dy=y1-y2;
  return dx*dx+dy*dy;
}

public F64 ASin(F64 s)
{//Arc Sin (Inverse Sin).
  F64 c;
  c=s*s;
  if (c>=1.0)
    return ã/2.0;
  c=Sqrt(1.0-c);
  return ATan(s/c);
}

public F64 ACos(F64 c)
{//Arc Cos (Inverse Cos).
  F64 s;
  if (!c)
    return ã/2.0;
  s=c*c;
  if (s>=1.0)
    return 0.0;
  s=Sqrt(1.0-s);
  return ATan(s/c);
}

public F64 Sinh(F64 x)
{//Hyperbolic Sine.
  return 0.5*(Exp(x)-Exp(-x));
}

public F64 Cosh(F64 x)
{//Hyperbolic Cosine.
  return 0.5*(Exp(x)+Exp(-x));
}

#help_index "Math/Complex;Data Types/Complex"
public Complex *CAdd(Complex *sum,Complex *n1,Complex *n2)
{//sum=n1+n2
  sum->x=n1->x+n2->x;
  sum->y=n1->y+n2->y;
  return sum;
}

public Complex *CSub(Complex *diff,Complex *n1,Complex *n2)
{//diff=n1-n2
  diff->x=n1->x-n2->x;
  diff->y=n1->y-n2->y;
  return diff;
}

public Complex *CMul(Complex *prod,Complex *n1,Complex *n2)
{//prod=n1*n2
  prod->x=n1->x*n2->x-n1->y*n2->y;
  prod->y=n1->x*n2->y+n1->y*n2->x;
  return prod;
}

public Complex *CDiv(Complex *quot,Complex *n1,Complex *n2)
{//quot=n1/n2
  F64 m1,arg1,m2,arg2;
  R2P(&m1,&arg1,n1->x,n1->y);
  R2P(&m2,&arg2,n2->x,n2->y);
  m1/=m2;
  arg1-=arg2;
  quot->x=m1*Cos(arg1);
  quot->y=m1*Sin(arg1);
  return quot;
}

public Complex *CScale(Complex *dst,F64 s)
{//dst*=s
  dst->x*=s;
  dst->y*=s;
  return dst;
}

public Complex *CCopy(Complex *dst,Complex *src)
{//dst=src
  dst->x=src->x;
  dst->y=src->y;
  return dst;
}

public Complex *CEqu(Complex *dst,F64 x,F64 y)
{//dst=(x,y)
  dst->x=x;
  dst->y=y;
  return dst;
}

public Complex *CPoly(Complex *dst,I64 n,Complex *zeros,Complex *x)
{//Eval complex polynomial
  I64 i;
  Complex n1,n2;
  if (n>0)
  {
    CSub(dst,x,&zeros[0]);
    for (i=1; i<n; i++)
    {
      CCopy(&n1,dst);
      CMul(dst,&n1,CSub(&n2,x,&zeros[i]));
    }
  }
  else
    CEqu(dst,1.0,0.0);
  return dst;
}

public U64 NextPow2(U64 x)
{// Get next power of 2 >= input
  x--;
  x |= x >> 1;
  x |= x >> 2;
  x |= x >> 4;
  x |= x >> 8;
  x |= x >> 16;
  x |= x >> 32;
  x++;
  return x;
}

//See $LK,"::/Doc/Credits.DD"$.
#define LIN_CONGRUE_A	6364136223846793005
#define LIN_CONGRUE_C	1442695040888963407

I16 RandI16()
{//Random I16.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return res.i16[0];
}

U16 RandU16()
{//Random U16.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return res.u16[0];
}

I32 RandI32()
{//Random I32.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return res.i32[0];
}

U32 RandU32()
{//Random U32.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return res.u32[0];
}

I64 RandI64()
{//Random I64.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return res;
}

U64 RandU64()
{//Random U64.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return res;
}

F64 Rand()
{//Random F64.
  I64 res=Fs->rand_seed;
  res=LIN_CONGRUE_A*res^(res&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  if (!Bt(&Fs->task_flags,TASKf_NONTIMER_RAND))
    res^=GetTSC;
  Fs->rand_seed=res;
  return (res&0x3FFFFFFFFFFFFFFF)/ToF64(0x4000000000000000);
}

I64 RandRange(I64 min=0, I64 max)
{// Returns a random integer in [min,max], biased, but fast
  return (RandU32()(U64) * (max-min+1)) >> 32 + min;
}

I64 RandRangeSeed(I64 min=0, I64 max, I64 seed)
{// Returns a reproducibly random integer in [min,max]
  I64 res, res2;
  res=LIN_CONGRUE_A*seed^(seed&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  res2=res * (1 + 1<<16 + 1<<32 + 1<<48);
  return ((res2&0xffffffff)(U64) * (max-min+1)) >> 32 + min;
}

#help_index ""

