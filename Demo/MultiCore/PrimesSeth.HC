// This just runs on a few seth cores instead of all

#define NUM_SETH_CORES_TO_TEST 4

U8 *master_bitmap;
I64 prime_range,my_mp_cnt,pending,sleep_mod=2;

U0 PrimesJob(I64 i)
{
  I64 j,k,l=Sqrt(prime_range),
          lo=i*prime_range/my_mp_cnt,
          hi=(i+1)*prime_range/my_mp_cnt,
          lo2=lo+sys_cache_line_width,
          hi2=hi-sys_cache_line_width;
  if (lo2>hi2) lo2=hi2;
  for (j=2; j<=l; j++)
  {
    if (!Bt(master_bitmap,j))
    {
      if (j>=lo)
        k=j+j;
      else
      {
        k=lo-lo%j;
        if (k<lo)
          k+=j;
      }
      while (k<lo2)
      {
        LBts(master_bitmap,k);
        k+=j;
      }
      while (k<hi2)
      {
        Bts(master_bitmap,k);
        k+=j;
      }
      while (k<hi)
      {
        LBts(master_bitmap,k);
        k+=j;
      }
    }
    if ((j%sleep_mod)==0)
      Sleep(1);
  }
  lock pending--;
}

I64 PrimesSethOnly(I64 range, I64 sleep_percent=100)
{
  I64 i,prime_cnt=0;
  F64 t0=tS,tf;
  sleep_mod=ClampI64(100/sleep_percent,2,100);
  my_mp_cnt=NUM_SETH_CORES_TO_TEST;
  prime_range=range;
  master_bitmap=CAlloc((prime_range+7)/8+1);
  Bts(master_bitmap,0);
  Bts(master_bitmap,1);
  pending=my_mp_cnt;
  for (i=0; i<my_mp_cnt; i++)
    JobQue(&PrimesJob,i,i+mp_cnt-NUM_SETH_CORES_TO_TEST);
  while (pending)
  {
    Sleep(1);
  }
  tf=tS;
  for (i=0; i<prime_range; i++)
    if (!Bt(master_bitmap,i))
      prime_cnt++;
  for (i=MaxI64(prime_range-100,0); i<prime_range; i++)
    if (!Bt(master_bitmap,i))
      "%d ",i;
  "\n$$RED$$CPUs:%d PrimeRange:%,d PrimeCnt:%,d Time:%9.7,f$$FG$$\n"
  ,
  my_mp_cnt,prime_range,prime_cnt,tf-t0;
  Free(master_bitmap);
  return prime_cnt;
}

if (mp_cnt>NUM_SETH_CORES_TO_TEST)
  PrimesSethOnly(500000000,10);

