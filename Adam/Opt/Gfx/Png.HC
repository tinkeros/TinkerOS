static U32 crc_table[256];
static U8 png_sig[8]={137,80,78,71,13,10,26,10};

static U0 MkCrcTbl()
{
  U32 c;
  I64 n, k;
  for (n = 0; n < 256; n++)
  {
    c = n;
    for (k = 0; k < 8; k++)
    {
      if (c & 1)
      {
        c = 0xedb88320 ^ c >> 1;
      }
      else
      {
        c = c >> 1;
      }
    }
    crc_table[n] = c;
  }
}

MkCrcTbl();

static U32 UpdateCrc(U32 crc, U8 *buf, I64 len)
{
  U32 c = crc;
  I64 i;
  for (i = 0; i < len; i++)
  {
    c = crc_table[(c ^ buf[i]) & 0xff] ^ c >> 8;
  }
  return c;
}

static U32 Crc(U8 *type, U8 *buf, I64 len)
{
  U32 c = 0xffffffff;
  c = UpdateCrc(c, type, 4);
  if (len > 0)
  {
    c = UpdateCrc(c, buf, len);
  }
  return c ^ 0xffffffff;
}

static U32 Adler32(U8 *data, I64 len)
{
  U32 a = 1, b = 0;
  I64 i;
  for (i = 0; i < len; i++)
  {
    a = (a + data[i]) % 65521;
    b = (b + a) % 65521;
  }
  return b << 16 | a;
}

I64 PngSize(I64 width, I64 height)
{
  I64 raw_size, zdata_size, idat_chunk;
  raw_size = (width + 1) * height;
  zdata_size = 2 + 5 + raw_size + 4;
  idat_chunk = 12 + zdata_size;
  return 8
      + 25
      + 770
      + 266
      + idat_chunk
      + 12;
}

I64 WritePNG(U8 *out, I64 width, I64 height, I64 pitch,
    U8 *pixels,
    U8 *palette_rgba254,
    I64 *out_size_written)
{
  if (out == NULL || pixels == NULL || palette_rgba254 == NULL) return -1;
  if (width <= 0 || height <= 0 || pitch < width) return -2;


  I64 i, pos, raw_size, remaining, y, zsize;
  U16 len, nlen;
  U8 *p, ihdr[13], plte[254*3], *raw, *src, trns[254], *zbuf;
  U32 ad, chunk;

  p = out;

  MemCpy(p, png_sig, 8);
  p += 8;

  *(ihdr+0)(U32*)=EndianU32(width);
  *(ihdr+4)(U32*)=EndianU32(height);
  ihdr[8] = 8;
  ihdr[9] = 3;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  *p(U32*)++=EndianU32(13);
  MemCpy(p,"IHDR",4);
  p+=4;
  MemCpy(p,ihdr,13);
  p+=13;
  *p(U32*)++=EndianU32(Crc("IHDR", ihdr, 13));

  for (i=0; i<254; i++)
  {
    plte[i*3+0] = palette_rgba254[i*4+0];
    plte[i*3+1] = palette_rgba254[i*4+1];
    plte[i*3+2] = palette_rgba254[i*4+2];
  }
  *p(U32*)++=EndianU32(254*3);
  MemCpy(p,"PLTE",4);
  p+=4;
  MemCpy(p,plte,sizeof(plte));
  p+=sizeof(plte);
  *p(U32*)++=EndianU32(Crc("PLTE", plte, sizeof(plte)));

  for (i=0; i<254; i++)
  {
    trns[i] = palette_rgba254[i*4+3];
  }
  *p(U32*)++=EndianU32(254);
  MemCpy(p,"tRNS",4);
  p+=4;
  MemCpy(p,trns,sizeof(trns));
  p+=sizeof(trns);
  *p(U32*)++=EndianU32(Crc("tRNS", trns, sizeof(trns)));

  raw_size = (width+1)*height;
  raw = MAlloc(raw_size);
  if (raw == NULL) return -3;
  for (y=0; y<height; y++)
  {
    raw[y*(width+1)] = 0;
    MemCpy(raw+y*(width+1)+1, pixels+y*pitch, width);
  }

  zsize = 2 + (raw_size/65535 + 1) * (5 + 65535) + 4;
  zbuf = MAlloc(zsize);
  if (zbuf == NULL)
  {
    Free(raw);
    return -4;
  }
  pos=0;

  zbuf[pos++] = 0x78;
  zbuf[pos++] = 0x01;

  remaining = raw_size;
  src = raw;

  while (remaining > 0)
  {
    chunk = 65535;
    if (remaining<65535) chunk = remaining;

    zbuf[pos++] = remaining <= 65535;

    len = chunk;
    nlen = ~len;
    zbuf[pos++] = len & 0xff;
    zbuf[pos++] = len >> 8;
    zbuf[pos++] = nlen & 0xff;
    zbuf[pos++] = nlen >> 8;

    MemCpy(zbuf + pos, src, chunk);
    pos += chunk;
    src += chunk;
    remaining -= chunk;
  }

  ad = Adler32(raw, raw_size);
  zbuf[pos++] = ad >> 24 & 0xff;
  zbuf[pos++] = ad >> 16 & 0xff;
  zbuf[pos++] = ad >> 8 & 0xff;
  zbuf[pos++] = ad & 0xff;

  Free(raw);

  *p(U32*)++=EndianU32(pos);
  MemCpy(p,"IDAT",4);
  p+=4;
  MemCpy(p,zbuf,pos);
  p+=pos;
  *p(U32*)++=EndianU32(Crc("IDAT", zbuf, pos));
  Free(zbuf);

  *p(U32*)++=0;
  MemCpy(p,"IEND",4);
  p+=4;
  *p(U32*)++=EndianU32(Crc("IEND", NULL, 0));

  if (out_size_written != NULL)
  {
    *out_size_written = p - out;
  }
  return 0;
}

public Bool DC2Png(CDC *dc, U8 *filename)
{// Convert DC to PNG file
  I64 i,need,rc, written;
  U8 *buf, pal[254*4];
  Bool res=FALSE;

  if (!dc||!filename) return FALSE;
  if (dc->width!=dc->width_internal) return FALSE;

  for (i=0; i<254; i++)
  {
    pal[i*4+0] = gr_palette[i].r;
    pal[i*4+1] = gr_palette[i].g;
    pal[i*4+2] = gr_palette[i].b;
    pal[i*4+3] = 0xff;
  }

  need = PngSize(dc->width_internal,dc->height);
  buf = MAlloc(need+1024);
  written=0;
  rc = WritePNG(buf,dc->width,dc->height,dc->width_internal,dc->body,pal,&written);

  res=FileWrite(filename,buf,written);

  Free(buf);
  return res;
}

