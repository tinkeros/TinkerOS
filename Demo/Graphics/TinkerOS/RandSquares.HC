// Demo 238 default colors available in TinkerOS

#define SQUARE_SIZE  20
#define SQUARE_GAP   5
#define SQUARE_DELAY 5 // mS

U0 DrawPixel(CDC* dc, I64 x, I64 y, U8 color)
{
  dc->body[x + y * dc->width_internal] = color;
}

U0 RandColorSqrs()
{
  I64 i, j, x, y;
  I64 color;
  CDC *dc=DCAlias;

  "\nPress any key to exit demo.\n\n";

  Sleep(500);

  while (!ScanChar)
  {
    x = FloorI64(RandU16 % dc->width, SQUARE_SIZE + SQUARE_GAP);
    y = FloorI64(RandU16 % dc->height, SQUARE_SIZE + SQUARE_GAP);
    color = RandRange(0,238);

    for (i = 0; i < SQUARE_SIZE; i++)
      for (j = 0; j < SQUARE_SIZE; j++)
        DrawPixel(dc, x + i, y + j, color);

    Sleep(SQUARE_DELAY);
  }


  DCFill(dc);
  DCDel(dc);
}

RandColorSqrs;

