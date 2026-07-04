U0 QSortI64(I64 *base,I64 num, I64 (*fp_compare)(I64 e1,I64 e2))
{
  /*Quick Sort for width==8.
  fp_compare() passes by value instead of ref.

  For ascending strings: return StrCmp(e1,e2);
  For ascending ints   : return e1-e2;

  Maybe, look at $LK,"::/Demo/MultiCore/MPRadix.HC"$.
  */
  I64 i,*left,*right,pivot;
  if (num>1)
  {
    left =base;
    right=base+num-1;
    pivot=base[num/2];
    do
    {
      while ((*fp_compare)(*left,pivot)<0)
        left++;
      while ((*fp_compare)(*right,pivot)>0)
        right--;
      if (left<=right)
        SwapI64(left++,right--);
    }
    while (left<=right);
    i=right+1-base;
    if (1<i<num)
      QSortI64(base,i,fp_compare);
    i=base+num-left;
    if (1<i<num)
      QSortI64(left,i,fp_compare);
  }
}

