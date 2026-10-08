// TinkerOS can treat an I64 as a manual 64-bit bitfield via BitFieldSet/Get,
// and also supports real, C-like bitfield class members: annotate a member
// with ":width" inside a union and the compiler tracks its bit offset/width --
// plain "." and "->" access then reads/writes just those bits, read-modify-write,
// exactly like C (including silent truncation when a write is too wide).
//
// "BF PASS/FAIL" lines below are unit-test checks.

I64 bf_pass=0,bf_fail=0;

U0 BfChk(U8 *name,I64 got,I64 exp)
{
  if (got==exp)
  {
    bf_pass++;
    "BF PASS %s\n",name;
  }
  else
  {
    bf_fail++;
    "BF FAIL %s got %X exp %X\n",name,got,exp;
  }
}

"\n=== I64 as a manual 64-bit bitfield ===\n\n";
I64 my_bitfield=0;
BitFieldSet(&my_bitfield,59,4,15); // 4-bit field at bit 59, value 15
"my_bitfield in binary is now %b\n\n",my_bitfield;
BfChk("I64 BitFieldSet raw value",my_bitfield,0x7800000000000000);
BfChk("I64 BitFieldGet value",BitFieldGet(&my_bitfield,59,4),15);

// Real class bitfields: annotate members with ":width" inside a union.
class BFtest
{
union {
    U8 bit_0 : 1;
    U8 bit_1 : 1;
    U8 bit_2 : 1;
    U8 bit_3 : 1;
    U8 bit_4 : 1;
    U8 bit_5 : 1;
    U8 bit_6 : 1;
    U8 bit_7 : 1;
    U8 whole_byte;
}
union {
    U16 nibble_0 : 4;
    U16 nibble_1 : 4;
    U16 nibble_2 : 4;
    U16 nibble_3 : 4;
    U16 whole_word;
}
};

BFtest bftest,*pbftest=&bftest;
bftest.whole_byte=0x55;   // 0101 0101
bftest.whole_word=0xFF00; // 1111 1111 0000 0000

"=== ClassRep shows each member's bit offset/width ===\n\n";
ClassRep(&bftest);

BfChk("bit_0",bftest.bit_0,1);
BfChk("bit_1",bftest.bit_1,0);
BfChk("bit_2",bftest.bit_2,1);
BfChk("bit_3",bftest.bit_3,0);
BfChk("bit_4",bftest.bit_4,1);
BfChk("bit_5",bftest.bit_5,0);
BfChk("bit_6",bftest.bit_6,1);
BfChk("bit_7",bftest.bit_7,0);
BfChk("nibble_0",bftest.nibble_0,0x0);
BfChk("nibble_1",bftest.nibble_1,0x0);
BfChk("nibble_2",bftest.nibble_2,0xF);
BfChk("nibble_3",bftest.nibble_3,0xF);

// Writing one bit/nibble is a read-modify-write of the rest of the byte/word.
bftest.bit_3=1;
BfChk("bit_3=1 -> whole_byte",bftest.whole_byte,0x5D);
bftest.nibble_1=0xA;
BfChk("nibble_1=0xA -> whole_word",bftest.whole_word,0xFFA0);
pbftest->bit_5=1;
BfChk("ptr bit_5=1 -> whole_byte",pbftest->whole_byte,0x7D);
pbftest->nibble_3=0x3;
BfChk("ptr nibble_3=3 -> whole_word",pbftest->whole_word,0x3FA0);

// A packed status-register style class: several widths sharing one U32.
class BfReg
{
  union
  {
    U32 raw;
    U32 count   : 12;
    U32 rsvd0   : 4;
    U32 flag_a  : 1;
    U32 flag_b  : 1;
    U32 mode    : 2;
    U32 flag_c  : 1;
    U32 rsvd1   : 11;
  }
};

// Outside a union, same-type bitfields share one storage unit, like C.
class BfPacked
{
  U8 lo:4;
  U8 hi:4;
  U8 plain;
  U16 three:3;
  U16 thirteen:13;
  U32 after;
};

BfReg bf_glbl;

U0 BfTestUnionRead()
{
  BfReg t;
  t.raw=0x00010000;
  BfChk("union read flag_a",t.flag_a,1);
  BfChk("union read flag_b",t.flag_b,0);
  t.raw=0x001F0FFF;
  BfChk("union read count",t.count,0xFFF);
  BfChk("union read flag_a2",t.flag_a,1);
  BfChk("union read flag_b2",t.flag_b,1);
  BfChk("union read mode",t.mode,3);
  BfChk("union read flag_c",t.flag_c,1);
}

U0 BfTestUnionWriteLocal()
{
  BfReg t;
  t.raw=0;
  t.flag_a=1;
  BfChk("local write flag_a",t.raw,0x00010000);
  t.mode=3;
  BfChk("local write mode",t.raw,0x000D0000);
  t.count=0xFFF;
  BfChk("local write count",t.raw,0x000D0FFF);
  t.flag_a=0;
  BfChk("local clear flag_a",t.raw,0x000C0FFF);
}

U0 BfTestUnionWritePtr()
{
  BfReg t,*p=&t;
  p->raw=0xFFFFFFFF;
  p->count=0;
  BfChk("ptr write count keeps rest",p->raw,0xFFFFF000);
  p->flag_b=0;
  BfChk("ptr clear flag_b",p->raw,0xFFFDF000);
  BfChk("ptr read via other name",t.flag_b,0);
}

U0 BfTestUnionWriteGlobal()
{
  bf_glbl.raw=0;
  bf_glbl.flag_c=1;
  BfChk("global write flag_c",bf_glbl.raw,0x00100000);
  bf_glbl.flag_b=1;
  BfChk("global write flag_b",bf_glbl.raw,0x00120000);
}

U0 BfTestTruncate()
{
  BfReg t;
  t.raw=0;
  t.mode=7; // 2-bit field truncates to 3
  BfChk("truncate mode value",t.mode,3);
  BfChk("truncate mode raw",t.raw,0x000C0000);
  t.raw=0;
  t.count=0xFFFF; // 12-bit field truncates to 0xFFF
  BfChk("truncate count raw",t.raw,0xFFF);
}

U0 BfTestExpr()
{
  BfReg t;
  I64 n;
  t.raw=0x00010009; // flag_a=1, count=9
  n=t.count+1;
  BfChk("expr count+1",n,10);
  n=0;
  if (t.flag_a && !t.flag_b)
    n=1;
  BfChk("expr in if",n,1);
  BfChk("expr two fields",t.count*2+t.flag_a,19);
}

U0 BfTestPacked()
{
  BfPacked x;
  U8 *b=&x;
  U16 *w=&x;
  BfChk("packed sizeof",sizeof(BfPacked),8);
  BfChk("packed offset plain",offset(BfPacked.plain),1);
  BfChk("packed offset thirteen",offset(BfPacked.thirteen),2);
  BfChk("packed offset after",offset(BfPacked.after),4);
  MemSet(&x,0,sizeof(BfPacked));
  x.lo=3;
  x.hi=0xA;
  BfChk("packed byte0",b[0],0xA3);
  BfChk("packed read lo",x.lo,3);
  BfChk("packed read hi",x.hi,0xA);
  x.plain=0x55;
  x.three=5;
  x.thirteen=0x1ABC;
  BfChk("packed word",w[1],0x1ABC<<3+5);
  BfChk("packed plain untouched",x.plain,0x55);
  BfChk("packed read thirteen",x.thirteen,0x1ABC);
  x.after=0xDEADBEEF;
  BfChk("packed after",x.after,0xDEADBEEF);
}

BfReg bf_arr[3];
I64 bf_calls=0;

BfReg *BfPick(I64 i)
{//A bitfield write base with a side effect: counts its calls.
  bf_calls++;
  return &bf_arr[i];
}

U0 BfTestSideEffects()
{//The base of a bitfield write is evaluated once: a call, an assignment.
 //(Not p++: "(p++)->x=" does not work in HolyC, not even for plain members.)
  BfReg *p;
  I64 i,guard=0x1234;
  MemSet(bf_arr,0,sizeof(BfReg)*3);
  bf_calls=0;
  BfPick(1)->mode=3;
  BfChk("call base called once",bf_calls,1);
  BfChk("call base write",bf_arr[1].raw,0x000C0000);
  BfChk("call base read",BfPick(1)->mode,3);
  for (i=0; i<1000; i++)
    BfPick(2)->count=i;
  BfChk("call base in loop",bf_arr[2].count,999);
  BfChk("call base loop calls",bf_calls,1002);
  BfChk("call base stack intact",guard,0x1234);
  BfPick(0)->flag_b=BfPick(1)->mode-2;
  BfChk("call base, call value",bf_arr[0].raw,0x00020000);
  (p=&bf_arr[2])->flag_c=1;
  BfChk("assign base",bf_arr[2].raw,0x001003E7);
  BfChk("assign base sets p",p==&bf_arr[2],TRUE);
}

U0 BfUnitTests()
{
  BfTestUnionRead;
  BfTestUnionWriteLocal;
  BfTestUnionWritePtr;
  BfTestUnionWriteGlobal;
  BfTestTruncate;
  BfTestExpr;
  BfTestPacked;
  BfTestSideEffects;
}

U0 BfReport()
{
  "BF RESULT pass %d fail %d\n",bf_pass,bf_fail;
}

"\n=== Unit tests ===\n\n";
BfUnitTests;

"\n=== ClassRep of a packed class: lo=3 hi=A three=5 thirteen=1ABC ===\n\n";
BfPacked bf_pk;
MemSet(&bf_pk,0,sizeof(BfPacked));
bf_pk.lo=3;
bf_pk.hi=0xA;
bf_pk.plain=0x55;
bf_pk.three=5;
bf_pk.thirteen=0x1ABC;
bf_pk.after=0xDEADBEEF;
ClassRep(&bf_pk);
BfChk("final packed lo",bf_pk.lo,3);
BfChk("final packed hi",bf_pk.hi,0xA);
BfChk("final packed three",bf_pk.three,5);
BfChk("final packed thirteen",bf_pk.thirteen,0x1ABC);
BfChk("final packed after",bf_pk.after,0xDEADBEEF);

"\n";
BfReport;
