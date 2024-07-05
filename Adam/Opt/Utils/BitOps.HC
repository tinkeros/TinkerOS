// Note that not all of these functions are usable on all processors!

// TODOs

// add more to compiler OpCodes.DD
// and replace DU8 strings
//
// Add BMI2 instructions?
// Add AES / SHA1/256 ?

asm
{
  _POPCNT::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RAX,U64 SF_ARG1[RBP]

  POPCNT U64 RAX,U64 RAX

  POP    U64 RBP
  LEAVE
  RET
  _LZCNT::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RAX,U64 SF_ARG1[RBP]

  LZCNT  U64 RAX,U64 RAX

  POP    U64 RBP
  LEAVE
  RET
  _TZCNT::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RAX,U64 SF_ARG1[RBP]

  TZCNT  U64 RAX,U64 RAX

  POP    U64 RBP
  LEAVE
  RET
  _RDRAND::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP

  // RDRAND U64 RAX
  DU8    0x48,0x0f,0xc7,0xf0;

  POP    U64 RBP
  LEAVE
  RET
  _RDSEED::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP

  // RDSEED U64 RAX
  DU8    0x48,0x0f,0xc7,0xf8;

  POP    U64 RBP
  LEAVE
  RET
  _ANDN::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RCX,U64 SF_ARG1[RBP]
  MOV    RBX,U64 SF_ARG2[RBP]

  // ANDN RAX,RBX,RCX
  DU8    0xc4,0xe2,0xe0,0xf2,0xc1;

  POP    U64 RBP
  LEAVE
  RET
  _BEXTR::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RAX,U64 SF_ARG1[RBP]
  MOV    RBX,U64 SF_ARG2[RBP]
  MOV    RCX,U64 SF_ARG3[RBP]

  SHL    RCX,8
  XOR    RBX,RCX

  // BEXTR RAX,RAX,RBX
  DU8    0xc4,0xe2,0xe0,0xf7,0xc0;

  POP    U64 RBP
  LEAVE
  RET
  _BLSI::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RBX,U64 SF_ARG1[RBP]

  // BLSI RAX,RBX
  DU8    0xc4,0xe2,0xf8,0xf3,0xdb;

  POP    U64 RBP
  LEAVE
  RET
  _BLSR::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RBX,U64 SF_ARG1[RBP]

  // BLSR RAX,RBX
  DU8    0xc4,0xe2,0xf8,0xf3,0xcb;

  POP    U64 RBP
  LEAVE
  RET
  _BLSMSK::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RBX,U64 SF_ARG1[RBP]

  // BLSMSK RAX,RBX
  DU8    0xc4,0xe2,0xf8,0xf3,0xd3;

  POP    U64 RBP
  LEAVE
  RET
  _CRC32::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RAX,U64 SF_ARG1[RBP]
  MOV    RBX,U64 SF_ARG2[RBP]

  // CRC32 EAX,EBX
  DU8    0xf2,0x0f,0x38,0xf1,0xc3;

  POP    U64 RBP
  LEAVE
  RET
  _CRC64::
  PUSH   U64 RBP
  MOV    U64 RBP,U64 RSP
  MOV    RAX,U64 SF_ARG1[RBP]
  MOV    RBX,U64 SF_ARG2[RBP]

  // CRC32 RAX,RBX
  DU8    0xf2,0x48,0x0f,0x38,0xf1,0xc3;

  POP    U64 RBP
  LEAVE
  RET
};

#help_index "BitOPS"
_extern _ANDN I64 Andn(I64 val, I64 val2); // Returns val & ~val2
// Bit extract, returns (src >> start) & ((1 << len) - 1)
_extern _BEXTR I64 Bextr(I64 src, U8 start, U8 len);
_extern _BLSI I64 Blsi(I64 val); // Extracts lowest set isolated bit
_extern _BLSR I64 Blsr(I64 val); // Returns val with the lowest set bit unset
_extern _BLSMSK I64 Blsmsk(I64 val); // Returns a mask up to the lowest set bit
_extern _POPCNT I64 PopCnt(I64 val); // Returns number of set bits in 64-bit value
_extern _LZCNT I64 LzCnt(I64 val); // Returns number of leading zeros in 64-bit value
_extern _TZCNT I64 TzCnt(I64 val); // Returns number of trailing zeros in 64-bit value
_extern _RDRAND I64 RDRand(); // Returns a random 64-bit value using RDRAND
_extern _RDSEED I64 RDSeed(); // Returns a random 64-bit value using RDSEED
// Returns 32-bit accumulated CRC32 accumulating 32-bit val into a
_extern _CRC32 U32 Crc32(U32 a, U32 val);
// Returns 32-bit accumulated CRC32 accumulating 64-bit val into a.
_extern _CRC64 U32 Crc64(U64 a, U64 val);
#help_index ""