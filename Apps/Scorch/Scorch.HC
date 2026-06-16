#define TERRAIN_W    500
#define PANEL_X      504
#define SCREEN_W     640
#define SCREEN_H     480
#define GROUND_Y     479

#define NUM_PLAYERS    4
#define TANK_W        16
#define TANK_H         8
#define BARREL_LEN    12

#define GRAVITY      0.15
#define MAX_SPD      8.5
#define WIND_MAX     0.015

#define BLAST_R       28
#define CRATER_R      22
#define MAX_DMG    90
#define EXPLODE_FRAMES 24

#define WINS_NEEDED    3

#define S_AIM      0
#define S_CPU      1
#define S_FIRE     2
#define S_EXPLODE  3
#define S_MSG      4
#define S_GAMEOVER 5

class CSCTank
{
  I64 x;
  I64 y;
  I64 health;
  I64 angle;
  I64 power;
  Bool alive;
  Bool is_cpu;
  U8 name[12];
  I64 col;
};

CSCTank tanks[NUM_PLAYERS];

U8 msg[80];
I64 terrain_h[TERRAIN_W];
I64 scores[NUM_PLAYERS];
I64 g_player_kills, g_max_kills, g_score, g_hi_score, num_players, state, cur, round, ex, ey, eframe;
F64 wind, bx, by, bvx, bvy, cpu_fire_t;
Bool key_left, key_right, key_up, key_down, running, ball_active;

U0 GenTerrain()
{
  I64 x;
  F64 h, r1, r2, r3, r4, pi2 = 2.0 * ã;
  r1 = (RandU16 % 628) / 100.0;
  r2 = (RandU16 % 628) / 100.0;
  r3 = (RandU16 % 628) / 100.0;
  r4 = (RandU16 % 628) / 100.0;

  for (x = 0; x < TERRAIN_W; x++)
  {
    h = 290.0;
    h += 70.0 * Sin(pi2 * x / 300.0 + r1);
    h += 35.0 * Sin(pi2 * x / 140.0 + r2);
    h += 18.0 * Sin(pi2 * x / 70.0 + r3);
    h += 9.0 * Sin(pi2 * x / 35.0 + r4);
    if (h < 90.0) h = 90.0;
    if (h > 430.0) h = 430.0;
    terrain_h[x] = ToI64(h);
  }
}

U0 Carve(I64 cx, I64 cy, I64 radius)
{
  F64 dy_f;
  I64 dx, x2, new_h, dy_i, r2 = radius * radius;

  for (dx = -radius; dx <= radius; dx++)
  {
    x2 = cx + dx;
    if (x2 < 0 || x2 >= TERRAIN_W) goto carve_next;
    dy_f = Sqrt(ToF64(r2 - dx * dx));
    dy_i = ToI64(dy_f);
    new_h = cy + dy_i;
    if (new_h > terrain_h[x2])
      terrain_h[x2] = new_h;
    if (terrain_h[x2] > GROUND_Y - 5)
      terrain_h[x2] = GROUND_Y - 5;
carve_next:
    ;
  }
}

U0 DropTanks()
{
  I64 i;
  for (i = 0; i < num_players; i++)
    if (tanks[i].alive)
      tanks[i].y = terrain_h[tanks[i].x];
}

I64 CntAlive()
{
  I64 i, n;
  n = 0;
  for (i = 0; i < num_players; i++)
    if (tanks[i].alive) n++;
  return n;
}

I64 NextPlayer(I64 from)
{
  I64 i, idx;
  for (i = 1; i <= num_players; i++)
  {
    idx = (from + i) % num_players;
    if (tanks[idx].alive) return idx;
  }
  return -1;
}

U0 PlaceTanks()
{
  I64 i, j, sw, tx, tmp, slots[NUM_PLAYERS];
  U8 *cnames[3];
  I64 ccols[3];

  cnames[0] = "Alice";
  cnames[1] = "Bob";
  cnames[2] = "Terry";
  ccols[0] = LTRED;
  ccols[1] = LTCYAN;
  ccols[2] = LTPURPLE;

  for (i = 0; i < num_players; i++) slots[i] = i;
  for (i = num_players - 1; i > 0; i--)
  {
    j = RandU16 % (i + 1);
    tmp = slots[i]; slots[i] = slots[j]; slots[j] = tmp;
  }

  sw = TERRAIN_W / num_players;

  for (i = 0; i < num_players; i++)
  {
    tx = sw * slots[i] + sw / 2 + (RandU16 % 30) - 15;
    tx = ClampI64(tx, 25, TERRAIN_W - 25);

    tanks[i].x = tx;
    tanks[i].y = terrain_h[tx];
    tanks[i].health = 100;
    tanks[i].alive = TRUE;
    if (tx < TERRAIN_W / 2) tanks[i].angle = 55;
    else tanks[i].angle = 125;
    tanks[i].power = 50;

    if (i == 0)
    {
      StrPrint(tanks[i].name, "YOU");
      tanks[i].col = YELLOW;
      tanks[i].is_cpu = FALSE;
    }
    else
    {
      StrPrint(tanks[i].name, "%s", cnames[i - 1]);
      tanks[i].col = ccols[i - 1];
      tanks[i].is_cpu = TRUE;
    }
  }
}

Bool SimShot(I64 pidx, I64 target, I64 angle_deg, I64 power_pct)
{
  F64 sx, sy, svx, svy, theta, spd, dist_f;
  I64 ix, iy, dtx, dty, step;

  theta = ToF64(angle_deg) * ã / 180.0;
  spd   = ToF64(power_pct) * MAX_SPD / 100.0;
  sx    = ToF64(tanks[pidx].x) + Cos(theta) * ToF64(BARREL_LEN);
  sy    = ToF64(tanks[pidx].y - TANK_H / 2) - Sin(theta) * ToF64(BARREL_LEN);
  svx   = spd * Cos(theta);
  svy   = -spd * Sin(theta);

  for (step = 0; step < 600; step++)
  {
    svx += wind;
    svy += GRAVITY;
    sx  += svx;
    sy  += svy;

    ix = ToI64(sx);
    iy = ToI64(sy);

    if (ix < 0 || ix >= TERRAIN_W) return FALSE;
    if (sy < -1200.0) return FALSE;

    dtx    = ix - tanks[target].x;
    dty    = iy - (tanks[target].y - TANK_H / 2);
    dist_f = Sqrt(ToF64(dtx * dtx + dty * dty));
    if (dist_f < ToF64(BLAST_R))
      return TRUE;

    if (iy >= terrain_h[ix])
      return FALSE;
  }
  return FALSE;
}

U0 CpuAim(I64 pidx)
{
  I64 target, i, ideal_angle, ai_angle, ai_power, alive_cnt;
  I64 try_ang, try_pow, best_ang, best_pow, ang_diff, best_diff;
  F64 dx, tg, é_r, sin2a, ideal_spd, spd_err, ai_spd;
  Bool found_hit;

  alive_cnt = 0;
  for (i = 0; i < num_players; i++)
    if (tanks[i].alive) alive_cnt++;

  target = -1;
  for (i = 0; i < num_players; i++)
  {
    if (i == pidx || !tanks[i].alive) goto cpu_aim_next;
    if (target < 0)
      target = i;
    else if (Abs(ToF64(tanks[i].x - tanks[pidx].x)) <
             Abs(ToF64(tanks[target].x - tanks[pidx].x)))
      target = i;
cpu_aim_next:
    ;
  }
  if (target < 0) return;

  dx = ToF64(tanks[target].x - tanks[pidx].x);
  if (dx >= 0.0)
    ideal_angle = 45;
  else
    ideal_angle = 135;

  found_hit = FALSE;
  best_ang  = ideal_angle;
  best_pow  = 50;
  best_diff = 9999;

  for (try_ang = 5; try_ang <= 175; try_ang += 5)
  {
    for (try_pow = 20; try_pow <= 100; try_pow += 10)
    {
      if (!SimShot(pidx, target, try_ang, try_pow)) goto grid_next;
      ang_diff = try_ang - ideal_angle;
      if (ang_diff < 0) ang_diff = -ang_diff;
      if (!found_hit || ang_diff < best_diff)
      {
        found_hit = TRUE;
        best_ang  = try_ang;
        best_pow  = try_pow;
        best_diff = ang_diff;
      }
grid_next:
      ;
    }
  }

  if (found_hit)
  {
    ai_angle = best_ang;
    ai_power = best_pow;
    if (pidx != 3)
    {
      ai_angle += (RandU16 % 21) - 10;
      ai_power += (RandU16 % 21) - 10;
    }
    else
    {
      ai_angle += (RandU16 % 9) - 4;
      ai_power += (RandU16 % 9) - 4;
    }
  }
  else
  {
    tg = Abs(dx);
    if (pidx != 3)
    {
      ideal_angle += (RandU16 % 41) - 20;
      ideal_angle = ClampI64(ideal_angle, 5, 175);
    }
    else
    {
      ideal_angle += (RandU16 % (10 * alive_cnt + 1)) - 5 * alive_cnt;
      ideal_angle = ClampI64(ideal_angle, 5, 175);
    }

    é_r   = ToF64(ideal_angle) * ã / 180.0;
    sin2a = Abs(2.0 * Sin(é_r) * Cos(é_r));
    if (sin2a < 0.05) sin2a = 0.05;
    ideal_spd = Sqrt(tg * GRAVITY / sin2a);

    if (pidx != 3)
      spd_err = ToF64((RandU16 % 31) - 15) * MAX_SPD / 100.0;
    else
      spd_err = ToF64((RandU16 % (8 * alive_cnt + 1)) - 4 * alive_cnt) * MAX_SPD / 100.0;

    ai_spd = ideal_spd + spd_err;
    if (ai_spd < 0.5) ai_spd = 0.5;
    if (ai_spd > MAX_SPD) ai_spd = MAX_SPD;

    ai_angle = ideal_angle;
    ai_power = ToI64(ai_spd * 100.0 / MAX_SPD);
  }

  tanks[pidx].angle = ClampI64(ai_angle, 1, 179);
  tanks[pidx].power = ClampI64(ai_power, 5, 100);
}


U0 DoExplosion(I64 cx, I64 cy)
{
  I64 i, damage, dtx, dty, ty_center, old_health, actual_dmg, pts;
  F64 dist_f, dam_f;

  ex = cx;
  ey = cy;
  eframe = 0;
  state = S_EXPLODE;

  Carve(cx, cy, CRATER_R);

  for (i = 0; i < num_players; i++)
  {
    if (!tanks[i].alive) goto expl_next;
    dtx = tanks[i].x - cx;
    ty_center = tanks[i].y - TANK_H / 2;
    dty = ty_center - cy;
    dist_f = Sqrt(ToF64(dtx * dtx + dty * dty));
    if (dist_f < ToF64(BLAST_R))
    {
      dam_f = MAX_DMG * (1.0 - dist_f / BLAST_R);
      damage = ToI64(dam_f);
      old_health = tanks[i].health;
      tanks[i].health -= damage;
      if (tanks[i].health <= 0)
      {
        tanks[i].health = 0;
        tanks[i].alive = FALSE;
        if (cur == 0 && i != 0)
        {
          g_player_kills++;
          if (i == 3) g_score += 200;
          else        g_score += 100;
        }
        if (i == 0)
        {
          g_score -= 50;
          if (g_score < 0) g_score = 0;
        }
      }
      actual_dmg = old_health - tanks[i].health;
      if (cur == 0)
      {
        if (i == 0)
        {
          g_score -= actual_dmg;
          if (g_score < 0) g_score = 0;
        }
        else
        {
          if (i == 3) pts = actual_dmg * 2;
          else        pts = actual_dmg;
          g_score += pts;
        }
      }
    }
expl_next:
    ;
  }

  DropTanks;
}

U0 AdvanceTurn()
{
  I64 next;
  next = NextPlayer(cur);
  if (next < 0) return;
  cur = next;
  if (tanks[cur].is_cpu)
  {
    CpuAim(cur);
    cpu_fire_t = tS + 1.2 + (RandU16 % 8) * 0.1;
    state = S_CPU;

    if (cur==3)
      tanks[3].health=ClampI64(tanks[3].health+15,0,100);
  }
  else
    state = S_AIM;
}

U0 SaveBests()
{
  if (g_player_kills > g_max_kills)
  {
    g_max_kills = g_player_kills;
    RegWrite("TinkerOS/Scorch/MaxKills", "%d", g_max_kills);
  }
  if (g_score > g_hi_score)
  {
    g_hi_score = g_score;
    RegWrite("TinkerOS/Scorch/HiScore", "%d", g_hi_score);
  }
}

U0 EndRound()
{
  I64 i, winner;
  winner = -1;
  for (i = 0; i < num_players; i++)
    if (tanks[i].alive)
    {
      winner = i;
      break;
    }

  if (winner >= 0)
  {
    scores[winner]++;
    if (winner != 0)
    {
      g_score -= 100;
      if (g_score < 0) g_score = 0;
    }
    if (scores[winner] >= WINS_NEEDED)
    {
      StrPrint(msg, "%s wins the match!", tanks[winner].name);
      SaveBests;
      state = S_GAMEOVER;
    }
    else
    {
      StrPrint(msg, "%s wins round %d!", tanks[winner].name, round);
      state = S_MSG;
    }
  }
  else
  {
    StrPrint(msg, "Draw - no survivors!");
    state = S_MSG;
  }
}

U0 Launch(I64 pidx)
{
  F64 é, spd;
  é = ToF64(tanks[pidx].angle) * ã / 180.0;
  spd = ToF64(tanks[pidx].power) * MAX_SPD / 100.0;
  bx = ToF64(tanks[pidx].x) + Cos(é) * ToF64(BARREL_LEN);
  by = ToF64(tanks[pidx].y - TANK_H / 2) - Sin(é) * ToF64(BARREL_LEN);
  bvx = spd * Cos(é);
  bvy = -spd * Sin(é);
  ball_active = TRUE;
  state = S_FIRE;
}

U0 FireStep()
{
  I64 ix, iy, i, dtx, dty, alive, next;
  F64 dist_f;

  if (!ball_active) return;

  bvx += wind;
  bvy += GRAVITY;
  bx += bvx;
  by += bvy;

  ix = ToI64(bx);
  iy = ToI64(by);

  if (ix < 0 || ix >= TERRAIN_W)
  {
    ball_active = FALSE;
    alive = CntAlive;
    if (alive <= 1)
      EndRound;
    else
      AdvanceTurn;
    return;
  }

  for (i = 0; i < num_players; i++)
  {
    if (!tanks[i].alive) goto fire_next;
    dtx = ix - tanks[i].x;
    dty = iy - (tanks[i].y - TANK_H / 2);
    dist_f = Sqrt(ToF64(dtx * dtx + dty * dty));
    if (dist_f < ToF64(TANK_W / 2 + 2))
    {
      ball_active = FALSE;
      DoExplosion(ix, iy);
      return;
    }
fire_next:
    ;
  }

  if (iy >= terrain_h[ix])
  {
    ball_active = FALSE;
    DoExplosion(ix, iy);
    return;
  }

  if (iy < -800 || bvy < -40.0)
  {
    ball_active = FALSE;
    alive = CntAlive;
    if (alive <= 1) EndRound;
    else AdvanceTurn;
  }
}

U0 NewRound()
{
  round++;
  wind = ToF64((RandU16 % 31) - 15) * WIND_MAX / 15.0;
  ball_active = FALSE;
  eframe = 0;

  GenTerrain;
  PlaceTanks;

  cur = 0;
  if (tanks[cur].is_cpu)
  {
    CpuAim(cur);
    cpu_fire_t = tS + 1.5;
    state = S_CPU;
  }
  else
    state = S_AIM;
}

U0 DrawTerrain(CDC *dc)
{
  I64 x, th;

  dc->color = BLUE;
  GrRect(dc, 0, 0, TERRAIN_W, 180);
  dc->color = LTBLUE;
  GrRect(dc, 0, 180, TERRAIN_W, SCREEN_H - 180);

  for (x = 0; x < TERRAIN_W; x++)
  {
    th = terrain_h[x];

    dc->color = LTGREEN;
    GrVLine(dc, x, th, MinI64(th + 3, GROUND_Y));

    dc->color = BROWN;
    if (th + 4 <= GROUND_Y)
      GrVLine(dc, x, th + 4, GROUND_Y);
  }
}

U0 DrawTank(CDC *dc, I64 pidx)
{
  CSCTank *t;
  I64 tx, ty, bx2, by2, bar_w, pivot_y, col;
  F64 é;

  t = &tanks[pidx];
  tx = t->x;
  ty = t->y;
  col = t->col;

  if (pidx == cur && (state == S_AIM || state == S_CPU))
  {
    dc->color = WHITE;
    GrHLine(dc, tx - TANK_W / 2 - 1, tx + TANK_W / 2, ty - TANK_H - 1);
    GrHLine(dc, tx - TANK_W / 2 - 1, tx + TANK_W / 2, ty + 1);
    GrVLine(dc, tx - TANK_W / 2 - 1, ty - TANK_H - 1, ty + 1);
    GrVLine(dc, tx + TANK_W / 2, ty - TANK_H - 1, ty + 1);
  }

  dc->color = col;
  GrRect(dc, tx - TANK_W / 2, ty - TANK_H, TANK_W, TANK_H);

  dc->color = DKGRAY;
  GrRect(dc, tx - TANK_W / 2, ty - 3, TANK_W, 3);

  é = ToF64(t->angle) * ã / 180.0;
  pivot_y = ty - TANK_H / 2;
  bx2 = tx + ToI64(Cos(é) * ToF64(BARREL_LEN));
  by2 = pivot_y - ToI64(Sin(é) * ToF64(BARREL_LEN));
  dc->color = DKGRAY;
  GrLine(dc, tx, pivot_y, bx2, by2);

  GrLine(dc, tx, pivot_y + 1, bx2, by2 + 1);

  dc->color = DKGRAY;
  GrRect(dc, tx - TANK_W / 2, ty - TANK_H - 7, TANK_W, 4);
  bar_w = t->health * TANK_W / 100;
  if (t->health > 60) dc->color = LTGREEN;
  else if (t->health > 25) dc->color = YELLOW;
  else dc->color = LTRED;
  if (bar_w > 0) GrRect(dc, tx - TANK_W / 2, ty - TANK_H - 7, bar_w, 4);
}

U0 DrawProjectile(CDC *dc)
{
  I64 px, py;
  if (!ball_active) return;
  px = ToI64(bx);
  py = ToI64(by);
  dc->color = WHITE;
  GrCircle3(dc, px, py, 0, 3);
  dc->color = YELLOW;
  GrCircle3(dc, px, py, 0, 2);
}

U0 DrawExplosion(CDC *dc)
{
  I64 r, col;
  if (state != S_EXPLODE || eframe >= EXPLODE_FRAMES) return;
  r = BLAST_R * (EXPLODE_FRAMES - eframe) / EXPLODE_FRAMES;
  if (eframe < 8) col = YELLOW;
  else if (eframe < 16) col = BROWN;
  else col = LTRED;
  dc->color = col;
  if (r > 0) GrCircle3(dc, ex, ey, 0, r);
  if (eframe < 10)
  {
    dc->color = WHITE;
    GrPrint(dc, ex - 14, ey - 24, "BOOM!");
  }
}

U0 DrawPanel(CDC *dc)
{
  I64 x, y, i, bar_w, col, wind_i;

  x = PANEL_X;

  dc->color = DKGRAY;
  GrRect(dc, x - 4, 0, SCREEN_W - x + 4, SCREEN_H);
  dc->color = 8;
  GrVLine(dc, x - 5, 0, SCREEN_H - 1);

  y = 6;
  dc->color = YELLOW;
  GrPrint(dc, x, y, "SCORCH");
  y += 16;

  dc->color = LTGRAY;
  GrPrint(dc, x, y, "Round %d", round);
  y += 24;

  dc->color = 8;
  GrHLine(dc, x, SCREEN_W - 2, y);
  y += 7;

  wind_i = ToI64(wind * 1000.0 + 0.5);
  if (wind < 0.0) wind_i = -ToI64(-wind * 1000.0 + 0.5);
  dc->color = LTCYAN;
  if (wind_i > 0)
    GrPrint(dc, x, y, "Wind >>%3d", wind_i);
  else if (wind_i < 0)
    GrPrint(dc, x, y, "Wind <<%3d", -wind_i);
  else
    GrPrint(dc, x, y, "Wind  calm");
  y += 14;

  dc->color = 8;
  GrHLine(dc, x, SCREEN_W - 2, y);
  y += 7;

  for (i = 0; i < num_players; i++)
  {
    if (i == cur) col = WHITE;
    else col = LTGRAY;
    if (!tanks[i].alive) col = DKGRAY;

    dc->color = tanks[i].col;
    GrRect(dc, x - 4, y, 3, 12);

    dc->color = col;
    GrPrint(dc, x, y, "%s", tanks[i].name);

    if (!tanks[i].alive)
    {
      dc->color = 8;
      GrPrint(dc, x + 40, y, "DEAD");
    }
    else
    {
      dc->color = 8;
      GrRect(dc, x + 44, y + 1, 56, 8);
      bar_w = tanks[i].health * 56 / 100;
      if (tanks[i].health > 60) dc->color = LTGREEN;
      else if (tanks[i].health > 25) dc->color = YELLOW;
      else dc->color = LTRED;
      if (bar_w > 0)
        GrRect(dc, x + 44, y + 1, bar_w, 8);
      dc->color = WHITE;
      GrPrint(dc, x + 102, y, "%3d", tanks[i].health);
    }
    y += 14;
  }

  dc->color = 8;
  GrHLine(dc, x, SCREEN_W - 2, y);
  y += 7;

  switch (state)
  {
  case S_AIM:
    dc->color = LTGREEN;
    GrPrint(dc, x, y, "YOUR TURN");
    y += 14;
    dc->color = WHITE;
    GrPrint(dc, x, y, "Ang:%3d", tanks[0].angle);
    y += 12;
    GrPrint(dc, x, y, "Pow:%3d%%", tanks[0].power);
    y += 14;
    dc->color = LTGRAY;
    GrPrint(dc, x, y, "left/right=Angle");
    y += 11;
    GrPrint(dc, x, y, "up/down=Power");
    y += 11;
    GrPrint(dc, x, y, "Space=FIRE!");
    y += 11;
    break;

   case S_CPU:
    dc->color = LTCYAN;
    GrPrint(dc, x, y, "%s", tanks[cur].name);
    y += 12;
    GrPrint(dc, x, y, "thinking...");
    y += 12;
    break;

  case S_FIRE:
    dc->color = LTCYAN;
    GrPrint(dc, x, y, "IN FLIGHT");
    y += 12;
    break;

  case S_EXPLODE:
    dc->color = YELLOW;
    GrPrint(dc, x, y, "* BOOM! *");
    y += 12;
    break;

  case S_MSG:
    dc->color = LTGREEN;
    GrPrint(dc, x, y, "ROUND OVER");
    y += 14;
    dc->color = WHITE;
    GrPrint(dc, x, y, "%s", msg);
    y += 20;
    dc->color = LTGRAY;
    GrPrint(dc, x, y, "Spc=next");
    y += 11;
    GrPrint(dc, x, y, "R=restart");
    y += 11;
    break;

  case S_GAMEOVER:
    dc->color = YELLOW;
    GrPrint(dc, x, y, "GAME OVER");
    y += 14;
    dc->color = WHITE;
    GrPrint(dc, x, y, "%s", msg);
    y += 20;
    dc->color = LTGRAY;
    GrPrint(dc, x, y, "R=new game");
    y += 11;
    GrPrint(dc, x, y, "ESC=quit");
    y += 11;
    break;
  }

  y = SCREEN_H - 128;
  dc->color = 8;
  GrHLine(dc, x, SCREEN_W - 2, y);
  y += 6;
  dc->color = YELLOW;
  GrPrint(dc, x, y, "Score:%d", g_score);
  y += 11;
  dc->color = LTGRAY;
  GrPrint(dc, x, y, "Best: %d", g_hi_score);
  y += 11;
  dc->color = 8;
  GrHLine(dc, x, SCREEN_W - 2, y);
  y += 6;
  dc->color = YELLOW;
  GrPrint(dc, x, y, "Kills:%d", g_player_kills);
  y += 11;
  dc->color = LTGRAY;
  GrPrint(dc, x, y, "Best: %d", g_max_kills);
  y += 11;
  dc->color = 8;
  GrHLine(dc, x, SCREEN_W - 2, y);
  y += 6;
  dc->color = LTGRAY;
  GrPrint(dc, x, y, "Wins:");
  y += 12;
  for (i = 0; i < num_players; i++)
  {
    if (scores[i] == MaxI64(scores[0], MaxI64(scores[1],
                MaxI64(scores[2], scores[3])))) dc->color = WHITE;
    else dc->color = LTGRAY;
    GrPrint(dc, x, y, "%s: %d", tanks[i].name, scores[i]);
    y += 11;
  }

  y = SCREEN_H - 10;
  dc->color = 8;
  GrPrint(dc, x, y, "ESC=quit");
}

U0 DrawIt(CTask *task, CDC *dc)
{
  I64 i;
  no_warn task;

  DrawTerrain(dc);

  for (i = 0; i < num_players; i++)
    if (tanks[i].alive)
      DrawTank(dc, i);

  DrawProjectile(dc);
  DrawExplosion(dc);
  DrawPanel(dc);
}

U0 Init()
{
  I64 i;

  num_players = NUM_PLAYERS;
  round = 0;
  ball_active = FALSE;
  eframe = 0;
  key_left = FALSE;
  key_right = FALSE;
  key_up = FALSE;
  key_down = FALSE;

  g_score = 0;
  g_player_kills = 0;
  for (i = 0; i < NUM_PLAYERS; i++)
    scores[i] = 0;

  MemSet(msg, 0, sizeof(msg));

  NewRound;
}

U0 Scorch()
{
  I64 alive, arg1, arg2;

  Init;

  SettingsPush;
  Fs->text_attr = BLACK << 4 + WHITE;
  MenuPush(
      "File { Exit(,CH_ESC); }"
      "Game {"
      "  Fire(,' ');"
      "  Restart(,'R');"
      "}"
  );
  WinBorder;
  WinMax;
  AutoComplete(0);
  DocCursor;
  DocClear;
  Fs->draw_it = &DrawIt;

  running = TRUE;
  try
  {
    while (running)
    {
      if (state == S_CPU && tS >= cpu_fire_t)
        Launch(cur);

      if (state == S_FIRE && ball_active)
        FireStep;

      if (state == S_EXPLODE)
      {
        eframe++;
        if (eframe >= EXPLODE_FRAMES)
        {
          alive = CntAlive;
          if (alive <= 1)
            EndRound;
          else
            AdvanceTurn;
        }
      }

      if (state == S_AIM)
      {
        if (key_left)
        {
          tanks[0].angle += 2;
          if (tanks[0].angle < 1) tanks[0].angle = 1;
        }
        if (key_right)
        {
          tanks[0].angle -= 2;
          if (tanks[0].angle > 179) tanks[0].angle = 179;
        }
        if (key_up)
        {
          tanks[0].power++;
          if (tanks[0].power > 100) tanks[0].power = 100;
        }
        if (key_down)
        {
          tanks[0].power--;
          if (tanks[0].power < 1) tanks[0].power = 1;
        }
      }

      switch (ScanMsg(&arg1, &arg2, (1 << MSG_KEY_DOWN) | (1 << MSG_KEY_UP)))
      {
      case MSG_KEY_DOWN:
        if (arg1 == CH_ESC || arg1 == CH_SHIFT_ESC)
          goto done;

        if (arg1 == 'R' || arg1 == 'r')
        {
          Init;
          break;
        }

        if (arg1 == ' ' || arg1 == '\n')
        {
          if (state == S_AIM)
            Launch(0);
          else if (state == S_MSG)
            NewRound;
          else if (state == S_GAMEOVER)
            Init;
          break;
        }

        switch (arg2.u8[0])
        {
        case SC_CURSOR_LEFT:
          key_left = TRUE;
          break;
        case SC_CURSOR_RIGHT:
          key_right = TRUE;
          break;
        case SC_CURSOR_UP:
          key_up = TRUE;
          break;
        case SC_CURSOR_DOWN:
          key_down = TRUE;
          break;
        }
        break;

      case MSG_KEY_UP:
        switch (arg2.u8[0])
        {
        case SC_CURSOR_LEFT:
          key_left = FALSE;
          break;
        case SC_CURSOR_RIGHT:
          key_right = FALSE;
          break;
        case SC_CURSOR_UP:
          key_up = FALSE;
          break;
        case SC_CURSOR_DOWN:
          key_down = FALSE;
          break;
        }
        break;
      }

      Sleep(16);
    }
done:
    ;
  }
  catch
    PutExcept;

  Fs->draw_it = NULL;
  key_left = key_right = key_up = key_down = FALSE;
  MenuPop;
  SettingsPop;
  DocClear;
}

RegDft("TinkerOS/Scorch/MaxKills", "0");
RegExe("g_max_kills = Str2I64(RegRead(\"TinkerOS/Scorch/MaxKills\", NULL));");
RegDft("TinkerOS/Scorch/HiScore", "0");
RegExe("g_hi_score = Str2I64(RegRead(\"TinkerOS/Scorch/HiScore\", NULL));");

Scorch;
