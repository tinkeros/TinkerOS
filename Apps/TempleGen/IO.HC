#define PAD_UP		0
#define PAD_DOWN	1
#define PAD_LEFT	2
#define PAD_RIGHT	3
#define PAD_B		4
#define PAD_C		5
#define PAD_A		6
#define PAD_S		7

U16 button_state[3];
U16 pad_state[3];
U8 io_reg[16]={0xA0, 0x7F, 0x7F, 0x7F, 0, 0, 0, 0xFF,
        0, 0, 0xFF, 0, 0, 0xFF, 0, 0
    };

U0 GenJoypadInit()
{
  I64 i;
  for (i = 0; i < 3; i++)
    button_state[i] = pad_state[i] = 0;
}

U0 GenJoypadScan()
{
  I64 b = 0;
  if (KeyDown(SC_CURSOR_UP))
    b |= 1 << PAD_UP;
  if (KeyDown(SC_CURSOR_DOWN))
    b |= 1 << PAD_DOWN;
  if (KeyDown(SC_CURSOR_LEFT))
    b |= 1 << PAD_LEFT;
  if (KeyDown(SC_CURSOR_RIGHT))
    b |= 1 << PAD_RIGHT;
  if (KeyDown(Char2ScanCode('z')))
    b |= 1 << PAD_A;
  if (KeyDown(Char2ScanCode('x')))
    b |= 1 << PAD_B;
  if (KeyDown(Char2ScanCode('c')))
    b |= 1 << PAD_C;
  if (KeyDown(SC_ENTER))
    b |= 1 << PAD_S;
  button_state[0] = b;
  button_state[1] = 0;
  button_state[2] = 0;
}

U0 pad_write(I64 pad, I64 value)
{
  I64 mask = io_reg[pad + 4];
  pad_state[pad] &= ~mask;
  pad_state[pad] |= value & mask;
}

U8 pad_read(I64 pad)
{
  I64 value;
  value = pad_state[pad] & 0x40;
  value |= 0x3F;
  if (value & 0x40)
    value &= ~(button_state[pad] & 0x3F);
  else
    value &= ~(0xC | (button_state[pad] & 3) |
            ((button_state[pad] >> 2) & 0x30));
  return value;
}

U0 io_write_memory(U32 address, U32 value)
{
  address >>= 1;
  if (address >= 0x1 && address < 0x4)
  {
    io_reg[address] = value;
    pad_write(address - 1, value);
  }
  else if (address >= 0x4 && address < 0x7)
  {
    if (io_reg[address] != value)
    {
      io_reg[address] = value;
      pad_write(address - 4, io_reg[address - 3]);
    }
  }
}

U32 io_read_memory(U32 address)
{
  I64 mask, value;
  address >>= 1;
  if (address >= 0x1 && address < 0x4)
  {
    mask = 0x80 | io_reg[address + 3];
    value = io_reg[address] & mask;
    value |= pad_read(address - 1) & ~mask;
    return value;
  }
  return io_reg[address];
}
