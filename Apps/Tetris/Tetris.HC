Cd(__DIR__);

#define BOARD_W    10
#define BOARD_H    20
#define CELL       20

#define TT_PANEL_W  120
#define BOARD_X    ((GR_WIDTH  - (BOARD_W * CELL + 20 + TT_PANEL_W)) / 2)
#define BOARD_Y    ((GR_HEIGHT - (BOARD_H * CELL)) / 2)
#define PANEL_X    (BOARD_X + BOARD_W * CELL + 20)
#define PANEL_Y    20

U8 board[BOARD_H * BOARD_W];
Bool game_over, running, paused;
F64 drop_time, drop_interval;
I64 cur_piece, cur_rot, cur_x, cur_y, next_piece, score, lvl, lines_total, hi_score, cross_flash_t;

RegDft("TinkerOS/Tetris","hi_score=0;\n");
RegExe("TinkerOS/Tetris");

U16 piece_shapes[32] =
{
  0x000F,0x2222,0x000F,0x2222,
  0x0066,0x0066,0x0066,0x0066,
  0x0072,0x0131,0x0270,0x0232,
  0x0036,0x0231,0x0036,0x0231,
  0x0063,0x0132,0x0063,0x0132,
  0x0071,0x0113,0x0470,0x0322,
  0x0074,0x0311,0x0170,0x0223,
  0x2272,0x04F4,0x4E44,0x2F20
};

U8 piece_col[8]={LTCYAN, YELLOW, PURPLE, LTGREEN, LTRED, LTBLUE, GREEN, BROWN};
I64 score_pts[5]={0, 100, 300, 500, 800};

Bool PCellFilled(I64 piece, I64 rot, I64 c, I64 r)
{
  return (piece_shapes[piece * 4 + rot] >> (r * 4 + c)) & 1;
}

U8 BGet(I64 row, I64 col)
{
  if (row < 0 || row >= BOARD_H || col < 0 || col >= BOARD_W)
    return 0xFF;
  return board[row * BOARD_W + col];
}

U0 BSet(I64 row, I64 col, U8 val)
{
  if (row >= 0 && row < BOARD_H && col >= 0 && col < BOARD_W)
    board[row * BOARD_W + col] = val;
}

Bool IsValid(I64 piece, I64 rot, I64 px, I64 py)
{
  I64 r, c;
  for (r = 0; r < 4; r++)
    for (c = 0; c < 4; c++)
      if (PCellFilled(piece, rot, c, r))
      {
        if (px + c < 0 || px + c >= BOARD_W || py + r >= BOARD_H)
          return FALSE;
        if (py + r >= 0 && BGet(py + r, px + c) != 0)
          return FALSE;
      }
  return TRUE;
}

U0 LockPiece()
{
  I64 r, c;
  for (r = 0; r < 4; r++)
    for (c = 0; c < 4; c++)
      if (PCellFilled(cur_piece, cur_rot, c, r))
        BSet(cur_y + r, cur_x + c, cur_piece + 1);
}

I64 ClearLines()
{
  I64 row, col, dst, cnt = 0;
  Bool full;
  for (row = BOARD_H - 1; row >= 0; row--)
  {
    full = TRUE;
    for (col = 0; col < BOARD_W && full; col++)
      if (board[row * BOARD_W + col] == 0)
        full = FALSE;
    if (full)
    {
      for (dst = row; dst > 0; dst--)
        MemCpy(&board[dst * BOARD_W], &board[(dst - 1) * BOARD_W], BOARD_W);
      for (col = 0; col < BOARD_W; col++)
        board[col] = 0;
      cnt++;
      row++;
    }
  }
  return cnt;
}

I64 CrossClear()
{
  I64 row, col, cnt;
  Bool had_cell;

  cnt = 0;

  row = cur_y + 1;
  if (row >= 0 && row < BOARD_H)
  {
    had_cell = FALSE;
    for (col = 0; col < BOARD_W; col++)
    {
      if (board[row * BOARD_W + col]) had_cell = TRUE;
      board[row * BOARD_W + col] = 0;
    }
    if (had_cell) cnt++;
  }

  for (row = cur_y; row < BOARD_H; row++)
  {
    had_cell = FALSE;
    for (col = cur_x; col <= cur_x + 2; col++)
    {
      if (col >= 0 && col < BOARD_W)
      {
        if (board[row * BOARD_W + col]) had_cell = TRUE;
        board[row * BOARD_W + col] = 0;
      }
    }
    if (had_cell) cnt++;
  }

  cross_flash_t = 180;
  return cnt;
}

I64 DoLineClear()
{
  if (cur_piece == 7 && cur_rot == 0)
    return CrossClear();
  return ClearLines();
}

U0 AddScore(I64 cleared)
{
  if (cleared >= 1 && cleared <= 4)
    score += score_pts[cleared] * lvl;
  else if (cleared > 4)
    score += cleared * score_pts[1] * lvl;
  if (score > hi_score) hi_score = score;
  lines_total += cleared;
  lvl = lines_total / 10 + 1;
  if (lvl > 20) lvl = 20;
  drop_interval = 1.0 - (lvl - 1) * 0.045;
  if (drop_interval < 0.05)
    drop_interval = 0.05;
}

I64 CntNonEmptyRows()
{
  I64 row, col, cnt;
  Bool has_any;
  cnt = 0;
  for (row = 0; row < BOARD_H; row++)
  {
    has_any = FALSE;
    for (col = 0; col < BOARD_W && !has_any; col++)
      if (board[row * BOARD_W + col]) has_any = TRUE;
    if (has_any) cnt++;
  }
  return cnt;
}

I64 PickNextPiece()
{
  I64 filled, threshold;
  filled    = CntNonEmptyRows();
  threshold = 100 - (filled * 80) / 15;
  if (threshold < 20) threshold = 20;
  if (filled > 5 && cur_piece != 7 && cross_flash_t < 1)
    if (RandU16 % threshold == 0) return 7;
  return RandU16 % 7;
}

Bool SpawnPiece()
{
  cur_piece = next_piece;
  cur_rot = 0;
  cur_x = 3;
  cur_y = 0;
  next_piece = PickNextPiece();
  if (!IsValid(cur_piece, cur_rot, cur_x, cur_y))
  {
    game_over = TRUE;
    return FALSE;
  }
  return TRUE;
}

I64 GhostY()
{
  I64 gy = cur_y;
  while (IsValid(cur_piece, cur_rot, cur_x, gy + 1))
    gy++;
  return gy;
}

U0 DrawCell(CDC *dc, I64 bx, I64 by, U8 col)
{
  I64 x,y;
  x = BOARD_X + bx * CELL;
  y = BOARD_Y + by * CELL;
  dc->color = col;
  GrRect(dc, x, y, CELL, CELL);
  dc->color = WHITE;
  GrLine(dc, x, y, x + CELL - 2, y);
  GrLine(dc, x, y, x, y + CELL - 2);
  dc->color = DKGRAY;
  GrLine(dc, x + CELL - 1, y, x + CELL - 1, y + CELL - 1);
  GrLine(dc, x, y + CELL - 1, x + CELL - 1, y + CELL - 1);
}

U0 DrawGhostCell(CDC *dc, I64 bx, I64 by, U8 col)
{
  I64 x,y;
  x = BOARD_X + bx * CELL;
  y = BOARD_Y + by * CELL;
  dc->color = DKGRAY;
  GrRect(dc, x, y, CELL, CELL);
  dc->color = col;
  GrRect(dc, x + 3, y + 3, CELL - 6, CELL - 6);
}

U0 DrawPreviewCell(CDC *dc, I64 bx, I64 by, U8 col, I64 ox, I64 oy)
{
  I64 x,y;
  x = ox + bx * CELL;
  y = oy + by * CELL;
  dc->color = col;
  GrRect(dc, x, y, CELL, CELL);
  dc->color = WHITE;
  GrLine(dc, x, y, x + CELL - 2, y);
  GrLine(dc, x, y, x, y + CELL - 2);
  dc->color = DKGRAY;
  GrLine(dc, x + CELL - 1, y, x + CELL - 1, y + CELL - 1);
  GrLine(dc, x, y + CELL - 1, x + CELL - 1, y + CELL - 1);
}

U0 DrawIt(CTask *task, CDC *dc)
{
  I64 bval, col, r, c, gy, cy, row, w, h;
  w = task->pix_width;
  h = task->pix_height;

  dc->color = BLACK;
  GrRect(dc, 0, 0, w, h);

  dc->color = LTGRAY;
  GrRect(dc, BOARD_X - 2, BOARD_Y - 2, BOARD_W * CELL + 4, BOARD_H * CELL + 4);
  dc->color = DKGRAY;
  GrRect(dc, BOARD_X, BOARD_Y, BOARD_W * CELL, BOARD_H * CELL);

  for (row = 0; row < BOARD_H; row++)
    for (col = 0; col < BOARD_W; col++)
    {
      bval = board[row * BOARD_W + col];
      if (bval >= 1 && bval <= 8)
        DrawCell(dc, col, row, piece_col[bval - 1]);
    }

  if (!game_over)
  {

    gy = GhostY();
    if (gy > cur_y)
      for (r = 0; r < 4; r++)
        for (c = 0; c < 4; c++)
          if (PCellFilled(cur_piece, cur_rot, c, r))
            if (gy + r >= 0 && gy + r < BOARD_H)
              DrawGhostCell(dc, cur_x + c, gy + r, piece_col[cur_piece]);


    for (r = 0; r < 4; r++)
      for (c = 0; c < 4; c++)
        if (PCellFilled(cur_piece, cur_rot, c, r))
          if (cur_y + r >= 0 && cur_y + r < BOARD_H)
            DrawCell(dc, cur_x + c, cur_y + r, piece_col[cur_piece]);
  }


  dc->color = DKGRAY;
  GrRect(dc, PANEL_X - 4, PANEL_Y - 4, w - PANEL_X + 4, h - PANEL_Y + 4);

  dc->color = YELLOW;
  GrPrint(dc, PANEL_X, PANEL_Y, "TETRIS");

  dc->color = LTGRAY;
  GrPrint(dc, PANEL_X, PANEL_Y + 20, "Score:");
  dc->color = WHITE;
  GrPrint(dc, PANEL_X, PANEL_Y + 30, "%d", score);

  dc->color = LTGRAY;
  GrPrint(dc, PANEL_X, PANEL_Y + 50, "Level:");
  dc->color = WHITE;
  GrPrint(dc, PANEL_X, PANEL_Y + 60, "%d", lvl);

  dc->color = LTGRAY;
  GrPrint(dc, PANEL_X, PANEL_Y + 80, "Lines:");
  dc->color = WHITE;
  GrPrint(dc, PANEL_X, PANEL_Y + 90, "%d", lines_total);

  dc->color = LTGRAY;
  GrPrint(dc, PANEL_X, PANEL_Y + 115, "Next:");

  dc->color = BLACK;
  GrRect(dc, PANEL_X - 2, PANEL_Y + 126, CELL * 4 + 4, CELL * 4 + 4);
  for (r = 0; r < 4; r++)
    for (c = 0; c < 4; c++)
      if (PCellFilled(next_piece, 0, c, r))
        DrawPreviewCell(dc, c, r, piece_col[next_piece], PANEL_X, PANEL_Y + 128);

  cy = PANEL_Y + 128 + CELL * 4 + 10;
  dc->color = LTGRAY;
  GrPrint(dc, PANEL_X, cy, "Best:");
  cy += 10;
  dc->color = CYAN;
  GrPrint(dc, PANEL_X, cy, "%d", hi_score);
  cy += 32;
  dc->color = LTGRAY;
  GrPrint(dc, PANEL_X, cy, "Left/Right: move");
  cy += 12;
  GrPrint(dc, PANEL_X, cy, "Up: rotate");
  cy += 12;
  GrPrint(dc, PANEL_X, cy, "Down: soft drop");
  cy += 12;
  GrPrint(dc, PANEL_X, cy, "Space: hard drop");
  cy += 12;
  GrPrint(dc, PANEL_X, cy, "P: pause");
  cy += 12;
  GrPrint(dc, PANEL_X, cy, "Enter: restart");
  cy += 12;
  GrPrint(dc, PANEL_X, cy, "ESC: quit");

  if (Blink && cross_flash_t > 0)
  {
    dc->color = YELLOW;
    GrPrint(dc, BOARD_X + (BOARD_W * CELL - 12 * 8) / 2, BOARD_Y + BOARD_H * CELL / 2 - 14, "JESUS SAVES!");
  }

  if (paused && !game_over)
  {
    dc->color = YELLOW;
    GrPrint(dc, BOARD_X + 25, BOARD_Y + BOARD_H * CELL / 2 - 4, "PAUSED");
  }

  if (game_over)
  {
    dc->color = LTGRAY;
    GrRect(dc, BOARD_X + 10, BOARD_Y + BOARD_H * CELL / 2 - 24,
        BOARD_W * CELL - 20, 44);
    dc->color = LTRED;
    GrPrint(dc, BOARD_X + 20, BOARD_Y + BOARD_H * CELL / 2 - 18, "GAME OVER");
    dc->color = WHITE;
    GrPrint(dc, BOARD_X + 14, BOARD_Y + BOARD_H * CELL / 2 + 0, "Enter=restart");
  }
}

U0 TryRot()
{
  I64 new_rot = (cur_rot + 1) % 4;

  if (IsValid(cur_piece, new_rot, cur_x, cur_y))
    cur_rot = new_rot;
  else if (IsValid(cur_piece, new_rot, cur_x + 1, cur_y))
  {
    cur_rot = new_rot;
    cur_x++;
  }
  else if (IsValid(cur_piece, new_rot, cur_x - 1, cur_y))
  {
    cur_rot = new_rot;
    cur_x--;
  }
  else if (IsValid(cur_piece, new_rot, cur_x + 2, cur_y))
  {
    cur_rot = new_rot;
    cur_x += 2;
  }
  else if (IsValid(cur_piece, new_rot, cur_x - 2, cur_y))
  {
    cur_rot = new_rot;
    cur_x -= 2;
  }
}

U0 HardDrop()
{
  I64 cleared;
  while (IsValid(cur_piece, cur_rot, cur_x, cur_y + 1))
  {
    cur_y++;
    score += 2;
  }
  LockPiece;
  cleared = DoLineClear();
  AddScore(cleared);
  if (!game_over)
    SpawnPiece;
  drop_time = tS;
}

U0 SoftDrop()
{
  I64 cleared;
  if (IsValid(cur_piece, cur_rot, cur_x, cur_y + 1))
  {
    cur_y++;
    score++;
  }
  else
  {
    LockPiece;
    cleared = DoLineClear();
    AddScore(cleared);
    if (!game_over)
      SpawnPiece;
  }
  drop_time = tS;
}

U0 Init()
{
  I64 i;
  for (i = 0; i < BOARD_H * BOARD_W; i++)
    board[i] = 0;
  score = 0;
  lvl = 1;
  lines_total = 0;
  game_over = FALSE;
  paused = FALSE;
  drop_interval = 0.8;
  cross_flash_t = 0;
  next_piece = PickNextPiece();
  SpawnPiece;
  drop_time = tS;
}

U0 Tetris()
{
  I64 arg1, arg2, cleared;
  F64 t;

  SettingsPush;
  Fs->text_attr = BLACK << 4 + WHITE;
  MenuPush(
      "File {"
      "  Exit(,CH_ESC);"
      "}"
      "Game {"
      "  Restart(,'\n');"
      "  Pause(,'P');"
      "  Rot(,,SC_CURSOR_UP);"
      "  MoveLeft(,,SC_CURSOR_LEFT);"
      "  MoveRight(,,SC_CURSOR_RIGHT);"
      "  SoftDrop(,,SC_CURSOR_DOWN);"
      "  HardDrop(,' ');"
      "}"
  );
  AutoComplete(0);
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  Type("Tetris.DD");
  "\n$FG,14$Press any key to start...$FG$\n";
  arg1 = GetKey;
  DocClear;
  Init;
  Fs->draw_it = &DrawIt;
  running = TRUE;
  try
  {
    while (running)
    {
      switch (ScanMsg(&arg1, &arg2, 1 << MSG_KEY_DOWN))
      {
      case MSG_KEY_DOWN:
        if (arg1 == CH_ESC || arg1 == CH_SHIFT_ESC)
          goto ttr_done;
        if (arg1 == '\n')
        {
          Init;
          break;
        }
        if (arg1 == 'P' || arg1 == 'p')
        {
          paused = !paused;
          break;
        }
        if (!game_over && !paused)
        {
          if (arg1 == ' ')
          {
            HardDrop;
          }
          else
          {
            switch (arg2.u8[0])
            {
            case SC_CURSOR_LEFT:
              if (IsValid(cur_piece, cur_rot, cur_x - 1, cur_y))
                cur_x--;
              break;
            case SC_CURSOR_RIGHT:
              if (IsValid(cur_piece, cur_rot, cur_x + 1, cur_y))
                cur_x++;
              break;
            case SC_CURSOR_UP:
              TryRot;
              break;
            case SC_CURSOR_DOWN:
              SoftDrop;
              break;
            }
          }
        }
        break;
      }

      if (!game_over && !paused)
      {
        t = tS;
        if (t - drop_time >= drop_interval)
        {
          drop_time = t;
          if (IsValid(cur_piece, cur_rot, cur_x, cur_y + 1))
          {
            cur_y++;
          }
          else
          {
            LockPiece;
            cleared = DoLineClear();
            AddScore(cleared);
            if (!game_over)
              SpawnPiece;
          }
        }
      }

      if (cross_flash_t > 0) cross_flash_t--;
      Sleep(16);
    }
ttr_done:
  }
  catch
    PutExcept;

  Fs->draw_it = NULL;
  RegWrite("TinkerOS/Tetris","hi_score=%d;\n",hi_score);
  MenuPop;
  SettingsPop;
  DocClear;
}

Tetris;

