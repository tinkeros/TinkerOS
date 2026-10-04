// Test Cases for RmParens.HC

U0 TC_NeededBothSides(I64 a,I64 b,I64 c)
{
  I64 x,y;
  x=(a+b)*c;              // keep -- * binds tighter than the inner +
  y=c*(a+b);              // keep -- symmetric case
}

U0 TC_ShiftAdd(I64 n)
{
  I64 mask;
  mask=1<<n-1;          // -> mask=1<<n-1;  (<< binds tighter than - in HolyC)
}

U0 TC_AndAdd(I64 a,I64 b,I64 c)
{
  I64 x,y;
  x=a&b+c;              // -> x=a&b+c;  (& binds TIGHTER than + in HolyC, unlike C)
  y=a&(b+c);              // keep -- needed given that same precedence
}

U0 TC_AndOrOr(Bool a,Bool b,Bool c)
{
  Bool x,y;
  x=a&&b||c;            // -> x=a&&b||c;
  y=a&&(b||c);            // keep
}

U0 TC_UnaryBare(I64 a,I64 *p)
{
  I64 x,y,z,w,v;
  x=-a;                 // -> x=-a;
  y=!a;                 // -> y=!a;
  z=~a;                 // -> z=~a;
  w=*p;                 // -> w=*p;
  v=++a;                // -> v=++a;
}

U0 TC_UnaryBinary(I64 a,I64 b)
{
  I64 x;
  x=-(a+b);               // keep -- -a+b would mean (-a)+b, not -(a+b)
}

U0 TC_BareAtom(I64 a)
{
  I64 x;
  x=a;                  // -> x=a;
}

U0 TC_DoubleWrapCondition(I64 a)
{
  I64 x;
  if (a==1)             // -> if (a==1)  (outer, mandatory if-parens untouched)
    x=1;
}

U0 TC_DoubleWrapGroup(I64 a,I64 b,I64 c)
{
  I64 x;
  x=(a+b)*c;            // -> x=(a+b)*c;  (inner pair redundant, outer pair needed)
}

U0 Foo(I64 a,I64 b,I64 c){}

U0 TC_CallArgs(I64 a,I64 b,I64 c)
{
  Foo(a,b,c);           // -> Foo(a,b,c);
  Foo(a,b+c,a*2);     // -> Foo(a,b+c,a*2);  (each arg scanned on its own)
}

U0 TC_Subscript(I64 *arr,I64 i)
{
  I64 x;
  x=arr[i];             // -> x=arr[i];
  x=arr[i+1];           // -> x=arr[i+1];
}

I64 TC_Return(I64 a,I64 b)
{
  return a+b;           // -> return a+b;
}

U0 TC_ChainAssign(I64 a,I64 b,I64 c)
{
  I64 x,y;
  x=a=b;                // -> x=a=b;
  y=(a=b)+c;              // keep -- assignment is the loosest operator
}

U0 TC_PostfixTouch(CMemberLst *f)
{
  I64 x;
  x=(f)->next;            // keep -- the real compiler never flags a paren with a postfix touching it
}

U0 TC_ForLoop(I64 n)
{
  I64 i;
  for (i=0;i<n+1;i=i+1) // -> for (i=0;i<n+1;i=i+1)
    ;
}

U0 TC_NoChange(I64 a,I64 b)
{
  I64 x;
  x=a+b*2;                // keep -- no parens here to begin with
}

