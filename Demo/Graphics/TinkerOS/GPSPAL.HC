// Draw Grand Prismatic Spring as Sprite with full TinkerOS default colors
// Made using GIMP with the TinkerOS palette and exported as RAW
//
// You can get the GIMP palette tinkeros.gpl from here:
// https://github.com/tinkeros/HolyGFXBot
//
// Make sure not to discard unused palette colors on export.

U0 GPSpringPalette()
{
  CDC *dc=DCNew(640,480);
  I64 s;
  U8 *img_buf=FileRead("GPSPAL.BIN.Z",&s);

  MemCpy(dc->body,img_buf,s);
  Free(img_buf);

  CSprite *elems=DC2Sprite(dc);

  DocSprite(,elems);
  for (s=0;s<480/8;s++) "\n";

  Free(elems);
  DCDel(dc);
}

GPSpringPalette;

