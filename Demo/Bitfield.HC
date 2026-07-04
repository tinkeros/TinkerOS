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

// TinkerOS also supports parsing bitfield info from classes:

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
}
union {
    U16 nibble_0 : 4;
    U16 nibble_1 : 4;
    U16 nibble_2 : 4;
    U16 nibble_3 : 4;
}
};

BFtest bftest;

// Normal HolyC behaves just like default, has no awareness of bitfields
bftest.bit_0=0x55;  // sets full U8 union to 0x55 
bftest.nibble_0=0xf0f0; // sets full U16 union to 0xff00

"The normal value of bftest.bit_0 is %02x\n",bftest.bit_0;
"The normal value of bftest.nibble_0 is %04x\n",bftest.nibble_0;

"ClassRep shows bitfield info:\n";
ClassRep(&bftest);

// TinkerOS extension to read/write bitfield values via CBFG/CBFS
// Crashes QEMU on some machines, might be a bug, don't use yet
/*
"The bitfield value of bit_0 is %d\n",CBFG("bftest.bit_0");
"The bitfield value of bit_1 is %d\n",CBFG("bftest.bit_1");
"The bitfield value of bit_2 is %d\n",CBFG("bftest.bit_2");
"The bitfield value of bit_3 is %d\n",CBFG("bftest.bit_3");
"The bitfield value of bit_4 is %d\n",CBFG("bftest.bit_4");
"The bitfield value of bit_5 is %d\n",CBFG("bftest.bit_5");
"The bitfield value of bit_6 is %d\n",CBFG("bftest.bit_6");
"The bitfield value of bit_7 is %d\n",CBFG("bftest.bit_7");
"\n";
"The bitfield value of nibble_0 is %01X\n",CBFG("bftest.nibble_0");
"The bitfield value of nibble_1 is %01X\n",CBFG("bftest.nibble_1");
"The bitfield value of nibble_2 is %01X\n",CBFG("bftest.nibble_2");
"The bitfield value of nibble_3 is %01X\n",CBFG("bftest.nibble_3");
"\n";
"Setting bit 1 to 1\n";
CBFS("bftest.bit_1",1);
"Setting nibbles to their index with CBFS\n";
CBFS("bftest.nibble_0",0);
CBFS("bftest.nibble_1",1);
CBFS("bftest.nibble_2",2);
CBFS("bftest.nibble_3",3);
"Now the bitfield value of nibble_0 is %01X\n",CBFG("bftest.nibble_0");
"Now the bitfield value of nibble_1 is %01X\n",CBFG("bftest.nibble_1");
"Now the bitfield value of nibble_2 is %01X\n",CBFG("bftest.nibble_2");
"Now the bitfield value of nibble_3 is %01X\n",CBFG("bftest.nibble_3");
"\n";

// Accessing with normal HolyC
// shows full changed value of
// all nibbles of the full U16
"The normal value of bftest.bit_0 is now %02x\n",bftest.bit_0;
"The normal value of bftest.nibble_0 is now %04x\n",bftest.nibble_0;
*/

