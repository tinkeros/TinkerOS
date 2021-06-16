// starting at 6 since SnailLib uses < 6
#define CMD_FILE_RECV     6
#define CMD_FILE_SEND     7
#define CMD_HELLO         0xAA

#define SNAIL_COM         1
#define SNAIL_TIMEOUT     500
#define SNAIL_FRAME_SIZE  112

static U8 ReadByte()
{
  U8 chr;
  while (1)
  {
    if (CommGetCharNoWait(SNAIL_COM,&chr))
      return chr;
    else
      Yield;
  }
}

static I8 ReadI8()
{
  I8 chr;
  while (1)
  {
    if (CommGetCharNoWait(SNAIL_COM,&chr))
      return chr;
    else
      Yield;
  }
}

static U0 ReadBlock(U8* buf, I64 count)
{
  while (count)
  {
    if (CommGetCharNoWait(SNAIL_COM,buf))
    {
      buf++;
      count--;
    }
    else
      Yield;
  }
}

I64 SocketInit()
{
  U8 chr;
  CommInit8n1(SNAIL_COM, 115200);
  CommFlush(SNAIL_COM);
  CommPutChar(SNAIL_COM, CMD_HELLO);
  I64 max_time = cnts.jiffies + SNAIL_TIMEOUT * JIFFY_FREQ / 1000;
  do
  {
    if (CommGetCharNoWait(SNAIL_COM, &chr))
    {
      if (chr == CMD_HELLO)
      {
        return 0;
      }
      else
      {
        "$FG,6$Failed to initialize Snail -- wrong hello 0x%02X\n", chr;
        "Are you using the right version of snail.py?\n$FG$";
        throw;
      }
      return chr;
    }
    else
      Yield;
  }
  while (cnts.jiffies < max_time);
  "$FG,6$Failed to initialize Snail -- make sure COM%d "
  "is properly configured & snail.py is running!\n$FG$"
  , SNAIL_COM;
  throw;
}

