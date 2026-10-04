// TinkerOS has functions to use a I64
// as a simple 64-bit bitfield as done below.

I64 my_bitfield=0;
"\n";
"my_bitfield in binary is %b\n\n",my_bitfield;
"Setting 4 high bits to 4-bit integer 15.\n\n";

// Use the 4 high bits as an integer
// whose size is 4 bits with value 15

BitFieldSet(&my_bitfield, 59, 4, 15);

// Show high bits are now 4 ones in
// binary
"my_bitfield in binary is now %b\n\n",my_bitfield;

// Get the value of the 4-bit integer
// stored in the bitfield

"The four high bits as a 4-bit bitfield = %d\n",BitFieldGet(&my_bitfield, 59, 4);

// TinkerOS also supports real, C-like bitfield members on classes.
// Annotate a member with ":width" inside a union and the compiler tracks
// its bit offset and width -- plain "." and "->" access on that member
// then automatically reads/writes just those bits, read-modify-write,
// exactly like C bitfields (including silent truncation if you write a
// value wider than the field).

class BFtest {
// bitfield variables should be a union!
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

bftest.whole_byte=0x55;   // 01010101
bftest.whole_word=0xff00; // 11111111000000



"\n=== ClassRep shows each member's bit offset/width ===\n\n";
ClassRep(&bftest);

"\n=== Testing each bit field via bftest.bit_N ===\n\n";
"bftest.bit_0=%b\n",bftest.bit_0;
"bftest.bit_1=%b\n",bftest.bit_1;
"bftest.bit_2=%b\n",bftest.bit_2;
"bftest.bit_3=%b\n",bftest.bit_3;
"bftest.bit_4=%b\n",bftest.bit_4;
"bftest.bit_5=%b\n",bftest.bit_5;
"bftest.bit_6=%b\n",bftest.bit_6;
"bftest.bit_7=%b\n",bftest.bit_7;

"\n=== Testing each nibble field via bftest.nibble_N ===\n\n";
"bftest.nibble_0=%b\n",bftest.nibble_0;
"bftest.nibble_1=%b\n",bftest.nibble_1;
"bftest.nibble_2=%b\n",bftest.nibble_2;
"bftest.nibble_3=%b\n",bftest.nibble_3;

"\n=== Change one bit and show the new whole_byte (bftest) ===\n\n";
bftest.bit_3=1;
"After bftest.bit_3=1, bftest.whole_byte=%b\n\n",bftest.whole_byte;

"\n=== Change one nibble and show the new whole_word (bftest) ===\n\n";
bftest.nibble_1=0xA;
"After bftest.nibble_1=0xA, bftest.whole_word=%b\n\n",bftest.whole_word;

"\n=== Testing each bit field via pbftest->bit_N ===\n\n";
"pbftest->bit_0=%b\n",pbftest->bit_0;
"pbftest->bit_1=%b\n",pbftest->bit_1;
"pbftest->bit_2=%b\n",pbftest->bit_2;
"pbftest->bit_3=%b\n",pbftest->bit_3;
"pbftest->bit_4=%b\n",pbftest->bit_4;
"pbftest->bit_5=%b\n",pbftest->bit_5;
"pbftest->bit_6=%b\n",pbftest->bit_6;
"pbftest->bit_7=%b\n",pbftest->bit_7;

"\n=== Testing each nibble field via pbftest->nibble_N ===\n\n";
"pbftest->nibble_0=%b\n",pbftest->nibble_0;
"pbftest->nibble_1=%b\n",pbftest->nibble_1;
"pbftest->nibble_2=%b\n",pbftest->nibble_2;
"pbftest->nibble_3=%b\n",pbftest->nibble_3;

"\n=== Change one bit and show the new whole_byte (pbftest) ===\n\n";
pbftest->bit_5=1;
"After pbftest->bit_5=1, pbftest->whole_byte=%b\n\n",pbftest->whole_byte;

"\n=== Change one nibble and show the new whole_word (pbftest) ===\n\n";
pbftest->nibble_3=0x3;
"After pbftest->nibble_3=0x3, pbftest->whole_word=%b\n\n",pbftest->whole_word;


