// All information public domain
// Datasheet: https://www.alsa-project.org/files/pub/datasheets/forte_media/FM801-AU-Data.PDF

// TODO Add gameport read functions

#define PCIV_FM801 0x1319
#define PCID_FM801 0x0801

#define FM801_PCM_VOL		0x00	/* PCM Output Volume */
#define FM801_FM_VOL		0x02	/* FM Output Volume */
#define FM801_I2S_VOL		0x04	/* I2S Volume */
#define FM801_REC_SRC		0x06	/* Record Source */
#define FM801_PLY_CTRL		0x08	/* Playback Control */
#define FM801_PLY_COUNT		0x0a	/* Playback Count */
#define FM801_PLY_BUF1		0x0c	/* Playback Bufer I */
#define FM801_PLY_BUF2		0x10	/* Playback Buffer II */
#define FM801_CAP_CTRL		0x14	/* Capture Control */
#define FM801_CAP_COUNT		0x16	/* Capture Count */
#define FM801_CAP_BUF1		0x18	/* Capture Buffer I */
#define FM801_CAP_BUF2		0x1c	/* Capture Buffer II */
#define FM801_CODEC_CTRL	0x22	/* Codec Control */
#define FM801_I2S_MODE		0x24	/* I2S Mode Control */
#define FM801_VOLUME		0x26	/* Volume Up/Down/Mute Status */
#define FM801_I2C_CTRL		0x29	/* I2C Control */
#define FM801_AC97_CMD		0x2a	/* AC'97 Command */
#define FM801_AC97_DATA		0x2c	/* AC'97 Data */
#define FM801_MPU401_DATA	0x30	/* MPU401 Data */
#define FM801_MPU401_CMD	0x31	/* MPU401 Command */
#define FM801_GPIO_CTRL		0x52	/* General Purpose I/O Control */
#define FM801_GEN_CTRL		0x54	/* General Control */
#define FM801_IRQ_MASK		0x56	/* Interrupt Mask */
#define FM801_IRQ_STATUS	0x5a	/* Interrupt Status */
#define FM801_OPL3_BANK0	0x68	/* OPL3 Status Read / Bank 0 Write */
#define FM801_OPL3_DATA0	0x69	/* OPL3 Data 0 Write */
#define FM801_OPL3_BANK1	0x6a	/* OPL3 Bank 1 Write */
#define FM801_OPL3_DATA1	0x6b	/* OPL3 Bank 1 Write */
#define FM801_POWERDOWN		0x70	/* Blocks Power Down Control */

#define FM801_AC97_BUSY		(1<<9)	/* busy=1 */

static I64 fm801_io_bar=0;
static Bool codec_ok=TRUE;
static U8 cur_vol_percent=50;

static U0 OutU16D(I64 port, I64 val)
{
  Sleep(1);
  OutU16(port,val);
}

public U0 FM801SetVol(U8 percent)
{
  I64 vol=(31*ClampI64(percent,0,100)/100)&31;
  vol=31 - vol;
  if (percent)
    OutU16D(fm801_io_bar+FM801_FM_VOL, vol|vol<<8);
  else
    OutU16D(fm801_io_bar+FM801_FM_VOL, vol|vol<<8|0x8000);
  cur_vol_percent=percent;
}

public U8 FM801GetVol()
{
  return cur_vol_percent;
}

static U0 CodecWrite(I64 val, I64 r, I64 max_tries=10)
{
  I64 i,j;

  if (!codec_ok) return;

  for (i=0; i<max_tries; i++)
  {
    if (!(InU16(fm801_io_bar+FM801_AC97_CMD) & FM801_AC97_BUSY))
    {
      OutU16(fm801_io_bar+FM801_AC97_DATA,val);
      OutU16(fm801_io_bar+FM801_AC97_CMD,r);
      for (j=0; j<max_tries; j++)
      {
        Sleep(1);
        if (!(InU16(fm801_io_bar+FM801_AC97_CMD) & FM801_AC97_BUSY))
          return;
      }
    }
    Sleep(1);
  }
  "Failed to CodecWrite failed to write %04x to register %04x\n",val,r;
  codec_ok=FALSE;
  return;
}

static U0 FM801Init()
{
  I64 b, d, f;
  U32 bar=0;
  U8 *def_str;
  CPciDevInfo snd_driver_pci;
  Bool found = FALSE;
  if (PciFindByID(PCIV_FM801,PCID_FM801, PCIC_MULTIMEDIA, 1, &b, &d, &f))
  {
    "Found FM801 sound card!\n";
    found=TRUE;
  }
  if (found)
  {
    PciGetDevInfo(&snd_driver_pci,b,d,f);
    bar=PCIGetFirstIOBar(&snd_driver_pci);
  }

  if (bar>0)
  {
    "Found Forte Media PCI card, trying to initialize!\n";
    fm801_io_bar=bar;
  }
  else
  {
    return;
  }

// PCI read cmd U16(0x4) should be 0x0 at start
// enable io space and memory access and bus master
// PCI write U16 0x07 to 0x4

  PCIWriteU16(b,d,f,0x4,PCIReadU16(b,d,f,0x4)|0x7);

// PCI read U16(0x40) should be 0x907F at start
// enable legacy
  PCIWriteU16(b,d,f,0x40,0x7f);

// PCI read U16(0) = 0x1319
// PCI read U16(2) = 0x0801

// PCI revision read U16(8) >= 0xb1 -> FM801-AU otherwise FM801-AS
// AU multichannel TODO




//OutU16D(fm801_io_bar+FM801_CODEC_CTRL, 0x20);
  OutU16D(fm801_io_bar+FM801_CODEC_CTRL, 0x30);
  InU16(fm801_io_bar+FM801_CODEC_CTRL);
  Sleep(1);
  OutU16D(fm801_io_bar+FM801_CODEC_CTRL, 0x0);
//TODO linux wait_for_codec
  Sleep(1);

// Read
  OutU16D(fm801_io_bar+FM801_AC97_CMD, 0xa6);
  InU16(fm801_io_bar+FM801_AC97_DATA);

  CodecWrite(0x0, 0x2);
  CodecWrite(0x8808, 0x4);
  CodecWrite(0x8808, 0x6);
  CodecWrite(0x8000, 0xa);
  CodecWrite(0x8008, 0xc);
  CodecWrite(0x8008, 0xe);
  CodecWrite(0x8808, 0x10);
  CodecWrite(0x808, 0x12);
  CodecWrite(0x8808, 0x14);
  CodecWrite(0x8808, 0x16);
  CodecWrite(0x0, 0x18);
  CodecWrite(0x505, 0x1a);
  CodecWrite(0x0, 0x1c);
  CodecWrite(0x0, 0x1e);
  CodecWrite(0x0, 0x20);
  CodecWrite(0x0, 0x22);
  CodecWrite(0x0, 0x38);
  CodecWrite(0x808, 0x72);
  CodecWrite(0x808, 0x74);

  OutU16D(fm801_io_bar+FM801_IRQ_MASK, 0xff7c);
  OutU16D(fm801_io_bar+FM801_IRQ_STATUS, 0xff00);
  OutU16D(fm801_io_bar+FM801_PCM_VOL, 0x808);
  OutU16D(fm801_io_bar+FM801_FM_VOL, 0x0);
  OutU16D(fm801_io_bar+FM801_I2S_VOL, 0x808);
  OutU16D(fm801_io_bar+FM801_REC_SRC, 0x0);
  OutU16D(fm801_io_bar+FM801_PLY_CTRL, 0xca00);
  OutU16D(fm801_io_bar+FM801_CAP_CTRL, 0xca00);
  OutU16D(fm801_io_bar+FM801_CODEC_CTRL, 0x0);
  OutU16D(fm801_io_bar+FM801_I2S_MODE, 0x3);

  OutU8(fm801_io_bar+FM801_OPL3_BANK1,5);
  OutU8(fm801_io_bar+FM801_OPL3_BANK1,0);
  OutU8(fm801_io_bar+FM801_OPL3_BANK1,4);
  OutU8(fm801_io_bar+FM801_OPL3_BANK1,0);
  Sleep(1);

  OutU16D(fm801_io_bar+FM801_FM_VOL, 0x0);
  OutU16D(fm801_io_bar+0x50, 0x8);
  OutU16D(fm801_io_bar+FM801_GPIO_CTRL, 0xe40);
  OutU16D(fm801_io_bar+FM801_GEN_CTRL, 0x280c);
  OutU16D(fm801_io_bar+FM801_I2S_MODE, 0x3);
  OutU16D(fm801_io_bar+FM801_GEN_CTRL, 0x280c);
  OutU16D(fm801_io_bar+FM801_FM_VOL, 0x808);

  FM801SetVol(50);

  if (found && codec_ok && fm801_io_bar)
  {
    def_str=MStrPrint("#define FM801_OPL_BASE 0x%08x", fm801_io_bar+FM801_OPL3_BANK0);
    Adam(def_str);
    Sleep(10);
    Free(def_str);
    "Found FM801 sound card!\n";
  }
}

FM801Init;

// Sound mute/vol up/down hooks
// Gameport
