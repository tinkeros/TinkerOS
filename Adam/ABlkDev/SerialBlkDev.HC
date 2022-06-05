#define SERIAL_BLKDEV_COM 1
#define SERIAL_CMD_DELAY 100
#define SERIAL_WRITE_DELAY 10
#define SERIAL_MAX_CTS_TX_BYTES 16

SetDrvLetType('S', BDT_SERIAL);

Bool serial_blkdev_initialized=FALSE;

Bool serial_blkdev_init()
{
  CommInit8n1(SERIAL_BLKDEV_COM, 115200);
  CommFlush(SERIAL_BLKDEV_COM);
  CommPutChar(SERIAL_BLKDEV_COM,'S');
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommPutChar(SERIAL_BLKDEV_COM,0);
  //TODO ack
  Sleep(SERIAL_CMD_DELAY);
  serial_blkdev_initialized=TRUE;
  return TRUE;
}

Bool serial_blkdev_deinit()
{
  CommFlush(SERIAL_BLKDEV_COM);
  CommPutChar(SERIAL_BLKDEV_COM,'E');
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommPutChar(SERIAL_BLKDEV_COM,0);
  CommFlush(SERIAL_BLKDEV_COM);
  Sleep(SERIAL_CMD_DELAY);
  serial_blkdev_initialized=FALSE;
  return TRUE;
}

Bool serial_blkdev_read(U8* buf, I64 blk, I64 cnt)
{// returns a pointer to the block data or null if it fails
  F64 st, timeout=2.0;
  I64 i,count;
  U8 *buf_ptr=buf;
  if (serial_blkdev_initialized)
  {
    CommFlush(SERIAL_BLKDEV_COM);
    for (i=0; i<cnt; i++)
    {
      CommPutChar(SERIAL_BLKDEV_COM,'R');
      CommPutChar(SERIAL_BLKDEV_COM, blk >> 24 & 0xff);
      CommPutChar(SERIAL_BLKDEV_COM, blk >> 16 & 0xff);
      CommPutChar(SERIAL_BLKDEV_COM, blk >> 8 & 0xff);
      CommPutChar(SERIAL_BLKDEV_COM, blk & 0xff);
      st=tS;
      count=0;
      while (tS-st < timeout && count < 512)
      {
        if (CommGetCharNoWait(SERIAL_BLKDEV_COM, buf_ptr))
        {
          count++;
          buf_ptr++;
        }
      }
      if (count<512)
      {
        "Serial BlkDev read timeout failure\n";
        return FALSE;
      }
      Sleep(SERIAL_CMD_DELAY);
      blk++;
    }
    // TODO expect an ACK
    return TRUE;
  }
  else
  {
    "Serial BlkDev read failure (not initialized)\n";
  }
  return FALSE;
}

Bool serial_blkdev_write(U8* buf, I64 blk, I64 cnt)
{// returns a pointer to the block data or null if it fails
  I64 i,j,count;
  F64 st, timeout=2.0;
  U8 tmpval, *buf_ptr=buf;
  CommFlush(SERIAL_BLKDEV_COM);
  if (serial_blkdev_initialized)
  {
    for (i=0; i<cnt; i++)
    {
      CommPutChar(SERIAL_BLKDEV_COM,'W');
      CommPutChar(SERIAL_BLKDEV_COM, blk >> 24 & 0xff);
      CommPutChar(SERIAL_BLKDEV_COM, blk >> 16 & 0xff);
      CommPutChar(SERIAL_BLKDEV_COM, blk >> 8 & 0xff);
      CommPutChar(SERIAL_BLKDEV_COM, blk & 0xff);
      for (j=0; j<512/SERIAL_MAX_CTS_TX_BYTES; j++)
      {
        CommPutBlk(SERIAL_BLKDEV_COM, buf_ptr, SERIAL_MAX_CTS_TX_BYTES);
        buf_ptr+=SERIAL_MAX_CTS_TX_BYTES;
        Sleep(SERIAL_WRITE_DELAY);
      }
      Sleep(SERIAL_WRITE_DELAY);
      st=tS;
      count=0;
      while (tS-st < timeout && count < 16)
      {
        if (CommGetCharNoWait(SERIAL_BLKDEV_COM, &tmpval))
        {
          count++;
        }
      }
      if (count<16)
      {
        "Serial BlkDev write timeout failure\n";
        return FALSE;
      }
      if (tmpval != 0xff)
      {
        "Serial BlkDev write ack failure\n";
        return FALSE;
      }
      blk++;
    }
    // TODO expect an ACK
    return TRUE;
  }
  return FALSE;
}

I64 serial_blkdev_get_max()
{
  U8 tmpval;
  F64 st,timeout=2.0;
  I64 count=0;
  U32 size=0;
  if (serial_blkdev_initialized)
  {
    CommPutChar(SERIAL_BLKDEV_COM,'M');
    CommPutChar(SERIAL_BLKDEV_COM,0);
    CommPutChar(SERIAL_BLKDEV_COM,0);
    CommPutChar(SERIAL_BLKDEV_COM,0);
    CommPutChar(SERIAL_BLKDEV_COM,0);
    st=tS;
    count=0;
    while (tS-st < timeout && count < 4)
    {
      if (CommGetCharNoWait(SERIAL_BLKDEV_COM, &tmpval))
      {
        count++;
        size *= 256;
        size = size + tmpval;
      }
    }
    if (count<4)
    {
      "Serial BlkDev get max timeout failure\n";
      return FALSE;
    }
  }
  //TODO
  tmpval=size.u8[0];
  size.u8[0]=size.u8[3];
  size.u8[3]=tmpval;
  tmpval=size.u8[1];
  size.u8[1]=size.u8[2];
  size.u8[2]=tmpval;
  "Serial BlkDev got card size %d\n"
  ,size;
  Sleep(SERIAL_CMD_DELAY);
  return size;
}

// Set kernel functoin pointers for this block device type

fp_serial_blkdev_init=&serial_blkdev_init;
fp_serial_blkdev_deinit=&serial_blkdev_deinit;

fp_serial_blkdev_read=&serial_blkdev_read;
fp_serial_blkdev_write=&serial_blkdev_write;

fp_serial_blkdev_get_max=&serial_blkdev_get_max;
