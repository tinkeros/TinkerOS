


I64 my_bitfield=0;

// Use the 4 high bits as an integer
// whose size is 4 bits with value 15

BitFieldSet(&my_bitfield, 59, 4, 15);

// Show high bits are now 4 ones in
// binary

"%b\n"
,my_bitfield;

// Get the value of the 4-bit integer
// stored in the bitfield

BitFieldGet(&my_bitfield, 59, 4);


