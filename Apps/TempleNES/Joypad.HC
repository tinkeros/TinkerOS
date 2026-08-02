
class CNESJoypad
{
  U8 pointer;
  U8 button_status[8];
  U8 latched[8];
  U8 previous_write;
};

CNESJoypad nes_joypad;

Bool NESKeyDown(I64 sc)
{
  return Bt(kbd.down_bitmap,sc);
}

U0 JoypadInit(CNESJoypad *joypad)
{
  I64 i;
  joypad->pointer=0;
  for (i=0; i<8; i++)
  {
    joypad->button_status[i]=0;
    joypad->latched[i]=0;
  }
  joypad->previous_write=0;
}

U0 JoypadScan(CNESJoypad *joypad)
{

  joypad->button_status[0]=NESKeyDown(SC_ALT) ||
      NESKeyDown(Char2ScanCode('x'));
  joypad->button_status[1]=NESKeyDown(SC_CTRL) ||
      NESKeyDown(Char2ScanCode('z'));
  joypad->button_status[2]=NESKeyDown(SC_TAB);
  joypad->button_status[3]=NESKeyDown(SC_ENTER);
  joypad->button_status[4]=NESKeyDown(SC_CURSOR_UP);
  joypad->button_status[5]=NESKeyDown(SC_CURSOR_DOWN);
  joypad->button_status[6]=NESKeyDown(SC_CURSOR_LEFT);
  joypad->button_status[7]=NESKeyDown(SC_CURSOR_RIGHT);
}

U0 JoypadWrite(CNESJoypad *joypad, U8 data)
{
  I64 i;
  data&=1;
  if (joypad->previous_write && !data)
  {
    for (i=0; i<8; i++)
      joypad->latched[i]=joypad->button_status[i];
    joypad->pointer=0;
  }
  joypad->previous_write=data;
}

U8 JoypadNextButton(CNESJoypad *joypad)
{
  U8 retval=joypad->latched[joypad->pointer++];
  joypad->pointer=joypad->pointer%8;
  return retval;
}
