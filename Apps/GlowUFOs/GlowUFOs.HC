// GlowUFOs for TempleOS/TinkerOS

Cd(__DIR__);

#define WORLD_W  2048
#define GY       438
#define TOP      22
#define MH       20
#define MAX_UFO  16
#define MAX_KUFO 10
#define MAX_GLOW 10
#define MAX_BUL  8
#define MAX_EXP  16
#define N_STARS  36
#define UFO_SEARCH  0
#define UFO_DESCEND 1
#define UFO_CARRY   2
#define ST_PLAY  0
#define ST_DEAD  1
#define ST_OVER  2
#define ST_NEXT  3
#define KING_ROUND     250
#define MAX_BK         3
#define SHASTA_MUL     1.6
#define MAX_PICK     4
#define PICK_GRAB    16.0
#define ITEM_BK      0
#define ITEM_SHASTA  1
#define BIRD_PTS       500

F64 px, py, pvx, pvy, bird_x, bird_y, bird_yphase, bird_flap;
I64 pface, plr_inv, star_x[N_STARS], star_y[N_STARS], score, hi, lives, wave, state,
     dead_t, total_frames, scroll, bk_boosts, n_ufo, n_kufo, n_glow, bonus_life, bonus_bk,
     bonus_shasta, bonus_wave, bonus_hyper, bonus_king, bonus_total, terry, terry_face,
     terry_caps, ufo_caps, pick_msg, pick_who, pick_item, shasta_items, shasta_timer, bk_msg,
     bird_face, bird_timer, bird_msg;
Bool plr_alive, knext, next_armed, kbk, used_bk, used_shasta, bird_caught, had_kufo,
     kufo_respawned, terry_lost, hyper_avail, bird_act, bird_killed, bird_scared, kl, kr, ku,
     kd, kfire;

class UFO
{
  Bool act, conv;
  F64 x, y;
  I64 state, target, anim, drop;
} ufo[MAX_UFO];

class KUFO
{
  Bool act;
  F64 x, y;
  I64 anim, drop;
} kufo[MAX_KUFO];

class Glowie
{
  Bool act, carried;
  F64 x, y;
  I64 carrier;
} glow[MAX_GLOW];

class Bullet
{
  Bool act;
  F64 x, y, vx;
  I64 timer;
} bul[MAX_BUL];

class Explosion
{
  Bool act;
  F64 x, y;
  I64 t;
} xpl[MAX_EXP];

class Pickup
{
  Bool act;
  F64 x, y, vy;
  I64 type;
} pu[MAX_PICK];

RegDft("TinkerOS/GlowUFOs","hi=0;\n");
RegExe("TinkerOS/GlowUFOs");

I64 WX(F64 wx)
{
  I64 sx;
  sx = ToI64(wx) - scroll;
  if (sx > WORLD_W / 2) sx -= WORLD_W;
  if (sx < -WORLD_W / 2) sx += WORLD_W;
  return sx;
}

Bool OnScreen(F64 wx, I64 margin, I64 *sx)
{
  *sx = WX(wx);
  return *sx >= -margin && *sx <= 640 + margin;
}

F64 WrapX(F64 x)
{
  if (x < 0.0) x += ToF64(WORLD_W);
  if (x >= ToF64(WORLD_W)) x -= ToF64(WORLD_W);
  return x;
}

F64 DeltaX(F64 a, F64 b)
{
  F64 d = a - b;
  if (d > ToF64(WORLD_W) / 2.0) d -= ToF64(WORLD_W);
  if (d < -ToF64(WORLD_W) / 2.0) d += ToF64(WORLD_W);
  return d;
}

U0 Explode(F64 wx, F64 wy)
{
  I64 i;
  for (i = 0; i < MAX_EXP; i++)
  {
    if (!xpl[i].act)
    {
      xpl[i].act = TRUE;
      xpl[i].x = wx;
      xpl[i].y = wy;
      xpl[i].t = 18;
      return;
    }
  }
}

U0 SpawnPickup(F64 wx, F64 wy, I64 type)
{
  I64 i;
  for (i = 0; i < MAX_PICK; i++)
  {
    if (!pu[i].act)
    {
      pu[i].act = TRUE;
      pu[i].x = wx;
      pu[i].y = wy;
      pu[i].vy = 0.0;
      pu[i].type = type;
      return;
    }
  }
}

U0 KillPlayer()
{
  if (state == ST_OVER) return;
  if (plr_inv > 0) return;
  plr_alive = FALSE;
  lives--;
  shasta_timer = 0;
  if (lives <= 0) state = ST_OVER;
  else
  {
    state = ST_DEAD;
    dead_t = 90;
  }
}

U0 KillUFO(I64 idx)
{
  I64 h;
  if (!ufo[idx].act) return;
  h = ufo[idx].target;
  if (ufo[idx].state == UFO_CARRY && h >= 0 && glow[h].act)
  {
    glow[h].carried = FALSE;
    glow[h].carrier = -1;
    glow[h].y = ToF64(GY);
  }
  Explode(ufo[idx].x, ufo[idx].y);
  if (ufo[idx].drop >= 0)
  {
    SpawnPickup(ufo[idx].x, ufo[idx].y, ufo[idx].drop);
    ufo[idx].drop = -1;
  }
  ufo[idx].act = FALSE;
  n_ufo--;
  score += 150;
}

U0 KillKUFO(I64 idx)
{
  if (!kufo[idx].act) return;
  Explode(kufo[idx].x, kufo[idx].y);
  if (kufo[idx].drop >= 0)
  {
    SpawnPickup(kufo[idx].x, kufo[idx].y, kufo[idx].drop);
    kufo[idx].drop = -1;
  }
  kufo[idx].act = FALSE;
  n_kufo--;
  score += 250;
}

I64 SpawnKUFO(F64 wx, F64 wy)
{
  I64 i;
  for (i = 0; i < MAX_KUFO; i++)
  {
    if (!kufo[i].act)
    {
      kufo[i].act = TRUE;
      kufo[i].x = wx;
      kufo[i].y = wy;
      kufo[i].anim = 0;
      kufo[i].drop = -1;
      n_kufo++;
      had_kufo = TRUE;
      return i;
    }
  }
  return -1;
}

U0 Init()
{
  I64 i, j, tries, d_tot, d_r1, d_r2;
  F64 cand, ddx;
  Bool ok;

  px = ToF64(WORLD_W / 4);
  py = ToF64((TOP + GY) / 2);
  pvx = 0.0;
  pvy = 0.0;
  pface = 0;
  plr_alive = TRUE;
  plr_inv = 90;

  scroll = (ToI64(px) - 320 + WORLD_W * 4) % WORLD_W;

  for (i = 0; i < MAX_UFO; i++)
  {
    ufo[i].act = FALSE;
    ufo[i].target = -1;
    ufo[i].drop = -1;
    ufo[i].conv = FALSE;
  }
  for (i = 0; i < MAX_KUFO; i++)
  {
    kufo[i].act = FALSE;
    kufo[i].drop = -1;
  }
  for (i = 0; i < MAX_BUL; i++) bul[i].act = FALSE;
  for (i = 0; i < MAX_EXP; i++) xpl[i].act = FALSE;
  n_kufo = 0;

  n_glow = MAX_GLOW;
  terry = 0;
  terry_face = 0;
  for (i = 0; i < MAX_GLOW; i++)
  {
    glow[i].act = TRUE;
    glow[i].y = ToF64(GY);
    glow[i].carried = FALSE;
    glow[i].carrier = -1;
    tries = 0;
    do
    {
      cand = ToF64(RandU16 % WORLD_W);
      ok = TRUE;
      for (j = 0; j < i; j++)
      {
        ddx = DeltaX(glow[j].x, cand);
        if (Abs(ddx) < 120.0)
        {
          ok = FALSE;
          break;
        }
      }
    }
    while (!ok && ++tries < 100);
    glow[i].x = cand;
  }

  n_ufo = 4 + wave * 2;
  if (n_ufo > MAX_UFO) n_ufo = MAX_UFO;
  for (i = 0; i < n_ufo; i++)
  {
    ufo[i].act = TRUE;
    ufo[i].x = ToF64(RandU16 % WORLD_W);
    ufo[i].y = ToF64(TOP + RandU16 % ((GY - TOP) / 3));
    ufo[i].state = UFO_SEARCH;
    ufo[i].target = -1;
    ufo[i].anim = 0;
  }

  for (i = 0; i < MAX_PICK; i++) pu[i].act = FALSE;
  d_tot = n_ufo + n_kufo;
  d_r1 = -1;
  if (d_tot >= 1 && bk_boosts < MAX_BK)
  {
    d_r1 = RandU16 % d_tot;
    if (d_r1 < n_ufo) ufo[d_r1].drop = ITEM_BK;
    else kufo[d_r1 - n_ufo].drop = ITEM_BK;
  }
  if (d_tot >= 1 && shasta_items < 3 && !(d_tot == 1 && d_r1 == 0))
  {
    d_r2 = RandU16 % d_tot;
    while (d_r2 == d_r1) d_r2 = RandU16 % d_tot;
    if (d_r2 < n_ufo) ufo[d_r2].drop = ITEM_SHASTA;
    else kufo[d_r2 - n_ufo].drop = ITEM_SHASTA;
  }
  pick_msg = 0;
  bk_msg = 0;

  for (i = 0; i < N_STARS; i++)
  {
    star_x[i] = RandU16 % WORLD_W;
    star_y[i] = TOP + 4 + RandU16 % (GY - TOP - 8);
  }

  state = ST_PLAY;
  dead_t = 0;
  total_frames = 0;
  kbk = FALSE;
  knext = FALSE;
  kl = kr = ku = kd = kfire = FALSE;
  used_bk = FALSE;
  used_shasta = FALSE;
  bird_caught = FALSE;
  had_kufo = FALSE;
  kufo_respawned = FALSE;
  bird_act = FALSE;
  bird_msg = 0;
  bird_killed = FALSE;
  bird_scared = FALSE;
  bird_timer = 150 + RandU16 % 450;
}

U0 FireBullet()
{
  I64 i;
  for (i = 0; i < MAX_BUL; i++)
  {
    if (!bul[i].act)
    {
      bul[i].act = TRUE;
      bul[i].x = px;
      bul[i].y = py;
      if (pface == 0) bul[i].vx = 14.0;
      else bul[i].vx = -14.0;
      bul[i].timer = 52;
      return;
    }
  }
}

U0 UpdatePlayer()
{
  F64 thr = 0.32, mvx = 7.5, mvy = 4.5;

  if (!plr_alive) return;
  if (plr_inv > 0) plr_inv--;

  if (shasta_timer > 0)
  {
    thr *= SHASTA_MUL;
    mvx *= SHASTA_MUL;
    mvy *= SHASTA_MUL;
  }

  if (kl)
  {
    pvx -= thr;
    pface = 1;
  }
  if (kr)
  {
    pvx += thr;
    pface = 0;
  }
  if (ku) pvy -= thr;
  if (kd) pvy += thr;

  pvx *= 0.88;
  pvy *= 0.88;

  if (pvx > mvx) pvx = mvx;
  if (pvx < -mvx) pvx = -mvx;
  if (pvy > mvy) pvy = mvy;
  if (pvy < -mvy) pvy = -mvy;

  px += pvx;
  py += pvy;

  px = WrapX(px);

  if (py < ToF64(TOP + 6))
  {
    py = ToF64(TOP + 6);
    pvy = 0.0;
  }
  if (py > ToF64(GY - 20))
  {
    py = ToF64(GY - 20);
    pvy = 0.0;
  }

  scroll = (ToI64(px) - 320 + WORLD_W * 4) % WORLD_W;

  if (kfire) FireBullet();
}

U0 TerryAbducted()
{
  bird_scared = TRUE;
  if (bird_caught)
  {
    bird_caught = FALSE;
    bird_act = FALSE;
    bird_timer = 150 + RandU16 % 450;
  }
}

F64 WaveSpeedMul()
{
  F64 m = 1.0 + ToF64(wave - 5) * 0.03;
  if (wave <= 5) return 1.0;
  if (m > 1.5) m = 1.5;
  return m;
}

U0 UpdateUFOs()
{
  I64 i, j, best_glow, terry_idx, pick;
  F64 best_dist, ddx, ddy, tx, terry_dist, pick_dist, spd = WaveSpeedMul();

  for (i = 0; i < MAX_UFO; i++)
  {
    if (!ufo[i].act) goto ufo_i_next;
    ufo[i].anim = (total_frames / 8) & 3;

    if (ufo[i].state == UFO_SEARCH)
    {
      ufo[i].y += 0.4 * spd;
      if (((total_frames + i * 17) / 40) & 1) ufo[i].x += 0.6;
      else ufo[i].x -= 0.6;
      ufo[i].x = WrapX(ufo[i].x);

      best_glow = terry_idx = pick = -1;
      best_dist = terry_dist = pick_dist = 250.0;
      for (j = 0; j < MAX_GLOW; j++)
      {
        if (!glow[j].act || glow[j].carried) goto ufo_j_next;
        ddx = DeltaX(ufo[i].x, glow[j].x);
        if (j == terry)
        {
          terry_dist = Abs(ddx);
          terry_idx = j;
        }
        else if (Abs(ddx) < best_dist)
        {
          best_dist = Abs(ddx);
          best_glow = j;
        }
ufo_j_next:
        ;
      }

      if (best_glow >= 0 && best_dist < 60.0)
      {
        pick = best_glow;
        pick_dist = best_dist;
      }
      else if (terry_idx >= 0 && terry_dist < best_dist)
      {
        pick = terry_idx;
        pick_dist = terry_dist;
      }
      else if (best_glow >= 0)
      {
        pick = best_glow;
        pick_dist = best_dist;
      }
      else if (terry_idx >= 0)
      {
        pick = terry_idx;
        pick_dist = terry_dist;
      }

      if (pick >= 0 && pick_dist < 180.0)
      {
        ufo[i].state = UFO_DESCEND;
        ufo[i].target = pick;
      }

      if (ufo[i].y > ToF64(GY)) ufo[i].y = ToF64(TOP) + 20.0;

    }
    else if (ufo[i].state == UFO_DESCEND)
    {
      j = ufo[i].target;
      if (j < 0 || !glow[j].act)
      {
        ufo[i].state = UFO_SEARCH;
        ufo[i].target = -1;
      }
      else if (glow[j].carried)
      {
        ufo[i].state = UFO_SEARCH;
        ufo[i].target = -1;
      }
      else
      {
        tx = glow[j].x;
        ddx = DeltaX(tx, ufo[i].x);
        if (Abs(ddx) > 1.5)
        {
          if (ddx > 0.0) ufo[i].x += 1.4 * spd;
          else ufo[i].x -= 1.4 * spd;
        }
        ufo[i].y += 1.2 * spd;
        if (ufo[i].y > glow[j].y) ufo[i].y = glow[j].y;
        ufo[i].x = WrapX(ufo[i].x);

        if (Abs(ddx) < 10.0 && ufo[i].y >= glow[j].y)
        {
          if (j == terry && used_bk && used_shasta && bird_caught)
          {
            KillUFO(i);
            goto ufo_i_next;
          }
          ufo[i].state = UFO_CARRY;
          glow[j].carried = TRUE;
          glow[j].carrier = i;
          ufo[i].y = glow[j].y;
          if (j == terry) TerryAbducted();
        }
      }
    }
    else if (ufo[i].state == UFO_CARRY)
    {
      j = ufo[i].target;
      ufo[i].y -= 1.4 * spd;
      if (((total_frames + i * 7) / 30) & 1) ufo[i].x += 0.5;
      else ufo[i].x -= 0.5;
      ufo[i].x = WrapX(ufo[i].x);
      if (j >= 0 && glow[j].act)
      {
        glow[j].x = ufo[i].x;
        glow[j].y = ufo[i].y + 14.0;
      }
      if (ufo[i].y <= ToF64(TOP))
      {
        if (j >= 0 && glow[j].act)
        {
          glow[j].act = FALSE;
          n_glow--;
          if (j == terry)
          {
            terry = -1;
            terry_lost = TRUE;
            state = ST_OVER;
          }
          else
          {
            ufo_caps++;
            score = ClampI64(score - 200, 0, I64_MAX);
          }
        }
        I64 nm = SpawnKUFO(ufo[i].x, ToF64(TOP) + 10.0);
        if (nm >= 0 && ufo[i].drop >= 0) kufo[nm].drop = ufo[i].drop;
        ufo[i].drop = -1;
        ufo[i].act = FALSE;
        ufo[i].conv = TRUE;
        n_ufo--;
      }
    }

    if (plr_alive && plr_inv == 0)
    {
      ddx = DeltaX(ufo[i].x, px);
      ddy = ufo[i].y - py;
      if (Abs(ddx) < 18.0 && Abs(ddy) < 12.0) KillPlayer();
    }
ufo_i_next:
    ;
  }
}

U0 UpdateKUFOs()
{
  I64 i;
  F64 ddx, ddy, dist, kspd = 1.8 * WaveSpeedMul();
  for (i = 0; i < MAX_KUFO; i++)
  {
    if (!kufo[i].act) goto kufo_i_next;
    kufo[i].anim = (total_frames / 6) & 3;

    ddx = DeltaX(px, kufo[i].x);
    ddy = py - kufo[i].y;
    dist = Sqrt(ddx*ddx + ddy*ddy);
    if (dist > 0.5)
    {
      kufo[i].x += ddx / dist * kspd;
      kufo[i].y += ddy / dist * kspd;
    }

    kufo[i].x = WrapX(kufo[i].x);
    if (kufo[i].y < ToF64(TOP)) kufo[i].y = ToF64(TOP);
    if (kufo[i].y > ToF64(GY)) kufo[i].y = ToF64(GY);

    if (plr_alive && plr_inv == 0)
    {
      if (Abs(ddx) < 14.0 && Abs(ddy) < 12.0) KillPlayer();
    }
kufo_i_next:
    ;
  }
}

U0 UpdateBullets()
{
  I64 i, j;
  F64 ddx, ddy;

  for (i = 0; i < MAX_BUL; i++)
  {
    if (!bul[i].act) goto bul_i_next;
    bul[i].x += bul[i].vx;
    bul[i].x = WrapX(bul[i].x);
    bul[i].timer--;
    if (bul[i].timer <= 0)
    {
      bul[i].act = FALSE;
      goto bul_i_next;
    }

    for (j = 0; j < MAX_UFO; j++)
    {
      if (!ufo[j].act) goto bul_ufo_j_next;
      ddx = DeltaX(bul[i].x, ufo[j].x);
      ddy = bul[i].y - ufo[j].y;
      if (Abs(ddx) < 14.0 && Abs(ddy) < 10.0)
      {
        KillUFO(j);
        bul[i].act = FALSE;
        j = MAX_UFO;
      }
bul_ufo_j_next:
      ;
    }
    if (!bul[i].act) goto bul_i_next;

    for (j = 0; j < MAX_KUFO; j++)
    {
      if (!kufo[j].act) goto bul_kufo_j_next;
      ddx = DeltaX(bul[i].x, kufo[j].x);
      ddy = bul[i].y - kufo[j].y;
      if (Abs(ddx) < 12.0 && Abs(ddy) < 10.0)
      {
        KillKUFO(j);
        bul[i].act = FALSE;
        j = MAX_KUFO;
      }
bul_kufo_j_next:
      ;
    }
    if (!bul[i].act) goto bul_i_next;

    if (bird_act)
    {
      ddx = DeltaX(bul[i].x, bird_x);
      ddy = bul[i].y - bird_y;
      if (Abs(ddx) < 14.0 && Abs(ddy) < 10.0)
      {
        Explode(bird_x, bird_y);
        bird_act = FALSE;
        bird_killed = TRUE;
        bird_msg = 60;
        score = ClampI64(score - BIRD_PTS, 0, I64_MAX);
        bul[i].act = FALSE;
      }
    }
bul_i_next:
    ;
  }
}

U0 UpdateExplosions()
{
  I64 i;
  for (i = 0; i < MAX_EXP; i++)
  {
    if (xpl[i].act)
    {
      xpl[i].t--;
      if (xpl[i].t <= 0) xpl[i].act = FALSE;
    }
  }
}

U0 FireBKBoost()
{
  I64 i, sx;
  for (i = 0; i < MAX_UFO; i++)
  {
    if (!ufo[i].act) goto smb_ufo_i_next;
    if (OnScreen(ufo[i].x, 50, &sx)) KillUFO(i);
smb_ufo_i_next:
    ;
  }
  for (i = 0; i < MAX_KUFO; i++)
  {
    if (!kufo[i].act) goto smb_kufo_i_next;
    if (OnScreen(kufo[i].x, 50, &sx)) KillKUFO(i);
smb_kufo_i_next:
    ;
  }
}

U0 HyperJump()
{
  I64 c;
  F64 ty;

  if (!hyper_avail || !plr_alive) return;
  if (terry < 0 || !glow[terry].act || !glow[terry].carried) return;

  c = glow[terry].carrier;
  if (c >= 0 && ufo[c].act)
  {
    px = ufo[c].x - 70.0;
    ty = ufo[c].y;
  }
  else
  {
    px = glow[terry].x - 70.0;
    ty = glow[terry].y;
  }
  px = WrapX(px);

  if (ty < ToF64(TOP + 6)) ty = ToF64(TOP + 6);
  if (ty > ToF64(GY - 20)) ty = ToF64(GY - 20);
  py = ty;

  pvx = 0.0;
  pvy = 0.0;
  pface = 0;
  plr_inv = 36;
  scroll = (ToI64(px) - 320 + WORLD_W * 4) % WORLD_W;

  Explode(px, py);

  hyper_avail = FALSE;
  score = ClampI64(score - 100, 0, I64_MAX);
}

U0 UpdateTerry()
{
  I64 j, best;
  F64 ddx, bestd, step, tx, tspd = 1.1;
  Bool target_is_item, target_is_ufo;

  if (terry < 0 || !glow[terry].act) return;
  if (glow[terry].carried) return;

  for (j = 0; j < MAX_GLOW; j++)
  {
    if (j == terry || !glow[j].act || glow[j].carried) goto terry_grab_next;
    ddx = DeltaX(glow[j].x, glow[terry].x);
    if (Abs(ddx) <= 12.0)
    {
      glow[j].act = FALSE;
      n_glow--;
      terry_caps++;
      score += 100;
    }
terry_grab_next:
    ;
  }

  best = -1;
  bestd = ToF64(WORLD_W);
  target_is_item = FALSE;
  target_is_ufo = FALSE;
  for (j = 0; j < MAX_PICK; j++)
  {
    if (!pu[j].act) goto terry_item_next;
    ddx = DeltaX(pu[j].x, glow[terry].x);
    if (Abs(ddx) < bestd)
    {
      bestd = Abs(ddx);
      best = j;
      target_is_item = TRUE;
    }
terry_item_next:
    ;
  }
  if (best < 0)
  {
    for (j = 0; j < MAX_GLOW; j++)
    {
      if (j == terry || !glow[j].act || glow[j].carried) goto terry_j_next;
      ddx = DeltaX(glow[j].x, glow[terry].x);
      if (Abs(ddx) < bestd)
      {
        bestd = Abs(ddx);
        best = j;
      }
terry_j_next:
      ;
    }
  }
  if (best < 0)
  {
    for (j = 0; j < MAX_UFO; j++)
    {
      if (!ufo[j].act) goto terry_ufo_next;
      ddx = DeltaX(ufo[j].x, glow[terry].x);
      if (Abs(ddx) < bestd)
      {
        bestd = Abs(ddx);
        best = j;
        target_is_ufo = TRUE;
      }
terry_ufo_next:
      ;
    }
  }
  if (best < 0)
  {
    glow[terry].y = ToF64(GY);
    return;
  }

  if (target_is_item) tx = pu[best].x;
  else if (target_is_ufo) tx = ufo[best].x;
  else tx = glow[best].x;
  ddx = DeltaX(tx, glow[terry].x);

  if (Abs(ddx) > 12.0)
  {
    if (shasta_timer > 0) tspd *= SHASTA_MUL;
    if (ddx > 0.0)
    {
      step = tspd;
      terry_face = 0;
    }
    else
    {
      step = -tspd;
      terry_face = 1;
    }
    glow[terry].x += step;
    glow[terry].x = WrapX(glow[terry].x);
  }
  glow[terry].y = ToF64(GY);
}

U0 CollectPickup(I64 i, I64 who)
{
  if (pu[i].type == ITEM_BK && bk_boosts < MAX_BK) bk_boosts++;
  if (pu[i].type == ITEM_SHASTA && shasta_items < 3) shasta_items++;
  pick_item = pu[i].type;
  pu[i].act = FALSE;
  pick_msg = 50;
  pick_who = who;
}

U0 UseShastaBoost()
{
  if (shasta_items <= 0) return;
  shasta_items--;
  used_shasta = TRUE;
  shasta_timer = 900;
}

U0 UpdatePickups()
{
  I64 i;
  F64 ddx, ddy;

  if (pick_msg > 0) pick_msg--;

  for (i = 0; i < MAX_PICK; i++)
  {
    if (!pu[i].act) goto pick_i_next;

    if (pu[i].y < ToF64(GY))
    {
      pu[i].vy += 0.15;
      if (pu[i].vy > 2.6) pu[i].vy = 2.6;
      pu[i].y += pu[i].vy;
      if (pu[i].y > ToF64(GY))
      {
        pu[i].y = ToF64(GY);
        pu[i].vy = 0.0;
      }
    }

    if (plr_alive)
    {
      ddx = DeltaX(pu[i].x, px);
      ddy = pu[i].y - py;
      if (Abs(ddx) < PICK_GRAB && Abs(ddy) < PICK_GRAB)
      {
        CollectPickup(i, 0);
        goto pick_i_next;
      }
    }

    if (pu[i].y < ToF64(GY) - 8) goto pick_i_next;

    if (terry >= 0 && glow[terry].act && !glow[terry].carried)
    {
      ddx = DeltaX(pu[i].x, glow[terry].x);
      if (Abs(ddx) < PICK_GRAB)
      {
        CollectPickup(i, 1);
        goto pick_i_next;
      }
    }

    if (plr_alive && py >= ToF64(GY - 45))
    {
      ddx = DeltaX(pu[i].x, px);
      if (Abs(ddx) < PICK_GRAB)
      {
        CollectPickup(i, 0);
        goto pick_i_next;
      }
    }
pick_i_next:
    ;
  }
}

U0 SpawnBird()
{
  bird_x = WrapX(px + ToF64(WORLD_W / 2) + ToF64(RandU16 % 200 - 100));
  bird_yphase = ToF64(RandU16 % 628) / 100.0;
  bird_y = ((TOP + GY) / 2.0) + ((GY - TOP) / 7.0) * Sin(bird_yphase);
  bird_flap = 0.0;
  bird_act = TRUE;
}

U0 UpdateBird()
{
  F64 ddx, ddy, bspd, mul;

  if (bird_msg > 0) bird_msg--;

  if (!bird_act)
  {
    if (bird_caught || bird_killed) return;
    bird_timer--;
    if (bird_timer <= 0) SpawnBird();
    return;
  }

  mul = 1.0;
  if (wave > 15)
  {
    mul = 1.0 + ToF64(wave - 15) * 0.01;
    if (mul > 1.1) mul = 1.1;
  }
  if (bird_scared) mul *= 1.1;
  bspd = 1.8 * mul;

  ddx = DeltaX(bird_x, px);
  if (ddx >= 0.0)
  {
    bird_x += bspd;
    bird_face = 0;
  }
  else
  {
    bird_x -= bspd;
    bird_face = 1;
  }
  bird_x = WrapX(bird_x);

  bird_yphase += 0.05;
  bird_y = ((TOP + GY) / 2.0) + ((GY - TOP) / 7.0) * Sin(bird_yphase);
  bird_flap += 0.30;

  ddy = bird_y - py;
  if (plr_alive && Abs(ddx) < 16.0 && Abs(ddy) < 16.0)
  {
    score += BIRD_PTS;
    Explode(bird_x, bird_y);
    bird_caught = TRUE;
    bird_act = FALSE;
    bird_msg = 60;
  }
}

I64 GlowiesLeft()
{
  I64 j, n = 0;
  for (j = 0; j < MAX_GLOW; j++)
  {
    if (j == terry || !glow[j].act) goto left_next;
    n++;
left_next:
    ;
  }
  return n;
}

U0 RespawnUFO()
{
  I64 j, n, who, slot;

  n = 0;
  for (j = 0; j < MAX_GLOW; j++)
  {
    if (j == terry || !glow[j].act || glow[j].carried) goto rl_cnt_next;
    n++;
rl_cnt_next:
    ;
  }
  if (n <= 0) return;
  who = -1;
  n = RandU16 % n;
  for (j = 0; j < MAX_GLOW; j++)
  {
    if (j == terry || !glow[j].act || glow[j].carried) goto rl_pick_next;
    if (n == 0)
    {
      who = j;
      break;
    }
    n--;
rl_pick_next:
    ;
  }
  if (who < 0) return;

  slot = -1;
  for (j = 0; j < MAX_UFO; j++)
  {
    if (!ufo[j].act && !ufo[j].conv)
    {
      slot = j;
      break;
    }
  }
  if (slot < 0) return;

  ufo[slot].act = TRUE;
  ufo[slot].x = glow[who].x;
  ufo[slot].y = ToF64(TOP);
  ufo[slot].state = UFO_DESCEND;
  ufo[slot].target = who;
  ufo[slot].anim = 0;
  ufo[slot].drop = -1;
  n_ufo++;
}

U0 RespawnKUFO()
{
  SpawnKUFO(ToF64(RandU16 % WORLD_W), ToF64(TOP + 10));
}

U0 NewGame()
{
  score = 0;
  lives = 3;
  wave = 1;
  bk_boosts = 1;
  shasta_items = 1;
  shasta_timer = 0;
  terry_caps = 0;
  ufo_caps = 0;
  terry_lost = FALSE;
  hyper_avail = TRUE;
  Init();
}

U0 ResumeWave(Bool advance)
{
  I64 nwave = wave, nbk = bk_boosts;
  if (advance)
  {
    nwave = wave + 1;
    nbk = bk_boosts + 1;
    if (nbk > MAX_BK) nbk = MAX_BK;
  }
  Init();
  wave = nwave;
  bk_boosts = nbk;
  if (advance)
  {
    hyper_avail = TRUE;
    shasta_timer = 0;
  }
}

U0 Update()
{
  I64 bi;

  total_frames++;

  if (kbk)
  {
    kbk = FALSE;
    if (bk_boosts > 0)
    {
      bk_boosts--;
      used_bk = TRUE;
      FireBKBoost();
      bk_msg = 60;
    }
  }

  if (state == ST_PLAY)
  {
    if (shasta_timer > 0) shasta_timer--;
    if (bk_msg > 0) bk_msg--;
    UpdatePlayer();
    UpdateUFOs();
    UpdateTerry();
    UpdateKUFOs();
    UpdateBullets();
    UpdatePickups();
    UpdateBird();
    UpdateExplosions();
    if (state == ST_PLAY && n_ufo <= 0 && n_kufo <= 0 &&
        GlowiesLeft() > 0)
    {
      RespawnUFO();
      if (wave > 19 && GlowiesLeft() == 1 && had_kufo && !kufo_respawned)
      {
        RespawnKUFO();
        kufo_respawned = TRUE;
      }
    }

    if (state == ST_PLAY && n_ufo <= 0 && n_kufo <= 0 &&
        GlowiesLeft() <= 0)
    {
      state = ST_NEXT;
      knext = FALSE;
      shasta_timer = 0;
      plr_alive = FALSE;
      for (bi = 0; bi < MAX_BUL; bi++) bul[bi].act = FALSE;
      next_armed = !kfire;
      bonus_life = lives * 100;
      bonus_bk = bk_boosts * 50;
      bonus_shasta = shasta_items * 50;
      bonus_wave = wave * 250;
      bonus_hyper = 0;
      if (hyper_avail) bonus_hyper = 200;
      bonus_king = 0;
      if (used_bk && used_shasta && bird_caught)
      {
        bonus_king = 500 + 100 * wave;
        if (hyper_avail) bonus_king += 250;
        bonus_king = (bonus_king + KING_ROUND - 1) / KING_ROUND * KING_ROUND;
        if (bonus_king > 5000) bonus_king = 5000;
      }
      bonus_total = bonus_life + bonus_bk + bonus_shasta +
          bonus_wave + bonus_hyper + bonus_king;
      score += bonus_total;
    }
  }
  else if (state == ST_DEAD)
  {
    UpdateExplosions();
    dead_t--;
    if (dead_t <= 0) ResumeWave(FALSE);
  }
  else if (state == ST_NEXT)
  {
    UpdateExplosions();
    if (knext)
    {
      knext = FALSE;
      ResumeWave(TRUE);
    }
  }

  if (score > hi) hi = score;
}

U0 DrawBackground(CDC *dc)
{
  I64 i, sx;
  dc->color = 1;
  GrRect(dc, 0, TOP, 640, GY - TOP);
  dc->color = DKGRAY;
  GrRect(dc, 0, GY, 640, 480 - GY);
  dc->color = GREEN;
  GrHLine(dc, 0, 640, GY);
  dc->color = LTGREEN;
  GrHLine(dc, 0, 640, GY + 1);
  dc->color = WHITE;
  for (i = 0; i < N_STARS; i++)
  {
    sx = WX(ToF64(star_x[i]));
    if (sx >= 0 && sx < 640) GrRect(dc, sx, star_y[i], 1, 1);
  }
}

U0 DrawPlayer(CDC *dc)
{
  I64 sy;
  if (!plr_alive) return;
  if (plr_inv > 0 && (total_frames / 4) & 1) return;
  sy = ToI64(py);
  dc->color = LTCYAN;
  if (pface == 0)
  {
    GrLine(dc, 310, sy - 5, 332, sy);
    GrLine(dc, 310, sy + 5, 332, sy);
    GrLine(dc, 310, sy - 5, 310, sy + 5);
    dc->color = DKGRAY;
    GrRect(dc, 305, sy - 3, 6, 6);
    if (kr || kl)
    {
      if (total_frames & 2) dc->color = YELLOW;
      else dc->color = RED;
      GrRect(dc, 298, sy - 2, 7, 4);
    }
  }
  else
  {
    GrLine(dc, 330, sy - 5, 308, sy);
    GrLine(dc, 330, sy + 5, 308, sy);
    GrLine(dc, 330, sy - 5, 330, sy + 5);
    dc->color = DKGRAY;
    GrRect(dc, 329, sy - 3, 6, 6);
    if (kl || kr)
    {
      if (total_frames & 2) dc->color = YELLOW;
      else dc->color = RED;
      GrRect(dc, 335, sy - 2, 7, 4);
    }
  }
  dc->color = CYAN;
  GrRect(dc, 317, sy - 3, 6, 6);
}

U0 DrawSaucer(CDC *dc, I64 sx, I64 sy, I64 hull, I64 under, Bool struts)
{
  dc->color = hull;
  GrRect(dc, sx - 11, sy - 1, 23, 3);
  GrRect(dc, sx - 7, sy - 3, 15, 2);
  GrRect(dc, sx - 4, sy - 5, 9, 2);
  dc->color = WHITE;
  GrCircle3(dc, sx, sy - 5, 0, 3);
  dc->color = under;
  GrRect(dc, sx - 7, sy + 2, 15, 2);
  if ((total_frames / 4) & 1) dc->color = YELLOW;
  else dc->color = LTRED;
  GrRect(dc, sx - 8, sy, 2, 2);
  GrRect(dc, sx - 2, sy, 2, 2);
  GrRect(dc, sx + 5, sy, 2, 2);
  if (struts)
  {
    dc->color = hull;
    GrLine(dc, sx - 7, sy + 3, sx - 9, sy + 9);
    GrLine(dc, sx + 7, sy + 3, sx + 9, sy + 9);
    GrLine(dc, sx, sy + 3, sx, sy + 9);
    GrRect(dc, sx - 11, sy + 9, 4, 2);
    GrRect(dc, sx + 7, sy + 9, 4, 2);
    GrRect(dc, sx - 2, sy + 9, 4, 2);
  }
}

U0 DrawEnemies(CDC *dc)
{
  I64 i, sx, sy;

  for (i = 0; i < MAX_UFO; i++)
  {
    if (!ufo[i].act) goto draw_ufo_i_next;
    if (!OnScreen(ufo[i].x, 20, &sx)) goto draw_ufo_i_next;
    sy = ToI64(ufo[i].y);
    DrawSaucer(dc, sx, sy, LTGRAY, DKGRAY, TRUE);
draw_ufo_i_next:
    ;
  }

  for (i = 0; i < MAX_KUFO; i++)
  {
    if (!kufo[i].act) goto draw_mut_i_next;
    if (!OnScreen(kufo[i].x, 20, &sx)) goto draw_mut_i_next;
    sy = ToI64(kufo[i].y);
    DrawSaucer(dc, sx, sy, LTGREEN, GREEN, FALSE);
draw_mut_i_next:
    ;
  }

  for (i = 0; i < MAX_EXP; i++)
  {
    if (!xpl[i].act) goto exp_i_next;
    if (!OnScreen(xpl[i].x, 30, &sx)) goto exp_i_next;
    if (xpl[i].t > 9) dc->color = YELLOW;
    else if (xpl[i].t > 4) dc->color = RED;
    else dc->color = LTRED;
    GrCircle3(dc, sx, ToI64(xpl[i].y), 0, xpl[i].t / 2 + 2);
exp_i_next:
    ;
  }
}

U0 DrawGlowies(CDC *dc)
{
  I64 i, sx, sy, leg;
  for (i = 0; i < MAX_GLOW; i++)
  {
    if (!glow[i].act) goto glow_i_next;
    if (!OnScreen(glow[i].x, 10, &sx)) goto glow_i_next;
    sy = ToI64(glow[i].y);

    if (i == terry)
    {
      if (glow[i].carried)
      {
        dc->color = LTRED;
        GrCircle3(dc, sx, sy - 10, 0, 4);
        dc->color = YELLOW;
        GrRect(dc, sx - 3, sy - 5, 7, 9);
      }
      else
      {
        dc->color = LTRED;
        GrRect(dc, sx - 10, sy - 4, 20, 8);
        dc->color = RED;
        GrRect(dc, sx - 6, sy - 9, 10, 6);
        dc->color = LTCYAN;
        GrCircle3(dc, sx - 1, sy - 10, 0, 2);
        dc->color = BLACK;
        GrCircle3(dc, sx - 6, sy + 4, 0, 2);
        GrCircle3(dc, sx + 6, sy + 4, 0, 2);
        dc->color = YELLOW;
        if (terry_face == 0) GrRect(dc, sx + 9, sy - 2, 3, 3);
        else GrRect(dc, sx - 12, sy - 2, 3, 3);
      }
      goto glow_i_next;
    }

    dc->color = LTCYAN;
    GrCircle3(dc, sx, sy - 10, 0, 4);
    dc->color = GREEN;
    GrRect(dc, sx - 3, sy - 5, 7, 8);
    if (glow[i].carried) leg = 0;
    else leg = (total_frames / 8) & 1;
    dc->color = LTGREEN;
    GrRect(dc, sx - 4, sy + 3, 3, 5);
    GrRect(dc, sx + 1, sy + 3, 3, 5);
    if (leg)
    {
      dc->color = GREEN;
      GrRect(dc, sx - 5, sy + 6, 2, 3);
      GrRect(dc, sx + 3, sy + 6, 2, 3);
    }
glow_i_next:
    ;
  }
}

U0 DrawBullets(CDC *dc)
{
  I64 i, sx;
  dc->color = YELLOW;
  for (i = 0; i < MAX_BUL; i++)
  {
    if (!bul[i].act) goto draw_bul_i_next;
    if (!OnScreen(bul[i].x, 0, &sx)) goto draw_bul_i_next;
    GrRect(dc, sx - 3, ToI64(bul[i].y) - 1, 7, 3);
draw_bul_i_next:
    ;
  }
}

U0 DrawPickups(CDC *dc)
{
  I64 i, sx, sy;
  for (i = 0; i < MAX_PICK; i++)
  {
    if (!pu[i].act) goto draw_pick_i_next;
    if (!OnScreen(pu[i].x, 10, &sx)) goto draw_pick_i_next;
    sy = ToI64(pu[i].y);
    if (pu[i].type == ITEM_SHASTA)
    {
      dc->color = LTGRAY;
      GrRect(dc, sx - 4, sy - 7, 9, 14);
      dc->color = DKGRAY;
      GrRect(dc, sx - 4, sy - 7, 9, 2);
      GrRect(dc, sx - 1, sy - 8, 3, 1);
      GrRect(dc, sx - 4, sy + 6, 9, 1);
      if ((total_frames / 4) & 1) dc->color = LTRED;
      else dc->color = LTBLUE;
      GrRect(dc, sx - 4, sy - 2, 9, 6);
      dc->color = WHITE;
      GrPrint(dc, sx - 3, sy - 3, "S");
    }
    else
    {
      dc->color = BROWN;
      GrRect(dc, sx - 4, sy - 7, 8, 2);
      GrRect(dc, sx - 6, sy - 5, 12, 3);
      dc->color = WHITE;
      GrRect(dc, sx - 3, sy - 5, 1, 1);
      GrRect(dc, sx, sy - 6, 1, 1);
      GrRect(dc, sx + 3, sy - 5, 1, 1);
      dc->color = YELLOW;
      GrRect(dc, sx - 6, sy - 2, 12, 2);
      GrRect(dc, sx - 5, sy, 2, 1);
      GrRect(dc, sx + 3, sy, 2, 1);
      dc->color = DKGRAY;
      GrRect(dc, sx - 6, sy, 12, 2);
      dc->color = LTGREEN;
      GrRect(dc, sx - 7, sy + 2, 14, 1);
      dc->color = BROWN;
      GrRect(dc, sx - 6, sy + 3, 12, 3);
    }
draw_pick_i_next:
    ;
  }
}

#define BIRD_TILT  2.0
U0 DrawBird(CDC *dc)
{
  I64 sx, sy, k, side, bx, by;
  F64 �, cosw, sinw, fdir, u, tailx, headx, taily, heady, apx, apy;
  if (!bird_act) return;
  if (!OnScreen(bird_x, 20, &sx)) return;
  sy = ToI64(bird_y);

  fdir = 1.0;
  if (bird_face) fdir = -1.0;

  � = Sin(bird_flap);
  cosw = Cos(�);
  sinw = Sin(�);

  tailx = ToF64(sx) - fdir * 5.0;
  taily = ToF64(sy) + BIRD_TILT;
  headx = ToF64(sx) + fdir * 7.0;
  heady = ToF64(sy) - BIRD_TILT;

  dc->color = WHITE;
  for (side = -1; side <= 1; side += 2)
  {
    apx = ToF64(sx) + fdir * 2.0 * cosw;
    apy = ToF64(sy) + ToF64(side) * 8.0 * cosw - 10.0 * sinw;
    for (k = 0; k <= 12; k++)
    {
      u = ToF64(k) / ToF64(12);
      bx = ToI64(tailx + (headx - tailx) * u);
      by = ToI64(taily + (heady - taily) * u);
      GrLine(dc, bx, by, ToI64(apx), ToI64(apy));
    }
  }

  dc->color = LTGRAY;
  GrLine(dc, ToI64(tailx), ToI64(taily), ToI64(headx), ToI64(heady));
  dc->color = YELLOW;
  GrLine(dc, ToI64(headx), ToI64(heady),
      ToI64(headx + fdir * 3.0), ToI64(heady - BIRD_TILT * 0.5));
}

U0 DrawMinimap(CDC *dc)
{
  I64 i, sx, sy, mw;
  F64 ms = 640.0 / ToF64(WORLD_W);

  dc->color = BLACK;
  GrRect(dc, 0, 0, 640, MH);

  dc->color = DKGRAY;
  sx = ToI64(ToF64(scroll) * ms);
  mw = ToI64(640.0 * ms);
  if (sx + mw <= 640)
  {
    GrRect(dc, sx, 1, mw, MH - 2);
  }
  else
  {
    GrRect(dc, sx, 1, 640 - sx, MH - 2);
    GrRect(dc, 0, 1, sx + mw - 640, MH - 2);
  }

  for (i = 0; i < MAX_GLOW; i++)
  {
    if (!glow[i].act) goto mm_glow_i_next;
    if (i == terry) dc->color = LTRED;
    else dc->color = GREEN;
    sx = ToI64(glow[i].x * ms);
    GrRect(dc, sx, MH - 4, 2, 3);
mm_glow_i_next:
    ;
  }

  dc->color = RED;
  for (i = 0; i < MAX_UFO; i++)
  {
    if (!ufo[i].act) goto mm_ufo_i_next;
    sx = ToI64(ufo[i].x * ms);
    sy = 1 + ToI64((ufo[i].y - ToF64(TOP)) * ToF64(MH - 2) / ToF64(GY - TOP));
    GrRect(dc, sx, sy, 2, 2);
mm_ufo_i_next:
    ;
  }

  dc->color = YELLOW;
  for (i = 0; i < MAX_KUFO; i++)
  {
    if (!kufo[i].act) goto mm_mut_i_next;
    sx = ToI64(kufo[i].x * ms);
    sy = 1 + ToI64((kufo[i].y - ToF64(TOP)) * ToF64(MH - 2) / ToF64(GY - TOP));
    GrRect(dc, sx, sy, 2, 2);
mm_mut_i_next:
    ;
  }

  if ((total_frames / 4) & 1) dc->color = WHITE;
  else dc->color = LTRED;
  for (i = 0; i < MAX_PICK; i++)
  {
    if (!pu[i].act) goto mm_pick_i_next;
    sx = ToI64(pu[i].x * ms);
    GrRect(dc, sx, MH - 6, 2, 5);
mm_pick_i_next:
    ;
  }

  if (bird_act)
  {
    dc->color = LTPURPLE;
    sx = ToI64(bird_x * ms);
    sy = 1 + ToI64((bird_y - ToF64(TOP)) * ToF64(MH - 2) / ToF64(GY - TOP));
    GrRect(dc, sx, sy, 2, 2);
  }

  dc->color = WHITE;
  sx = ToI64(px * ms);
  GrRect(dc, sx - 1, MH / 2 - 2, 3, 4);
}

U0 DrawCheck(CDC *dc, I64 x, I64 y)
{
  GrLine(dc, x, y + 2, x + 2, y + 4);
  GrLine(dc, x + 2, y + 4, x + 6, y);
}

U0 DrawCrown(CDC *dc, I64 x, I64 y)
{
  I64 c, p, a, d, best, pcol[3], ph[3];
  pcol[0] = 1;
  ph[0] = 0;
  pcol[1] = 5;
  ph[1] = -1;
  pcol[2] = 9;
  ph[2] = 0;
  for (c = 0; c <= 10; c++)
  {
    best = 99;
    for (p = 0; p < 3; p++)
    {
      a = c - pcol[p];
      if (a < 0) a = -a;
      d = ph[p] + 2 * a;
      if (d < best) best = d;
    }
    GrLine(dc, x + c, y + best, x + c, y + 6);
  }
  GrRect(dc, x, y + 5, 11, 3);
  for (p = 0; p < 3; p++) GrRect(dc, x + pcol[p], y + ph[p], 1, 1);
}

U0 DrawHud(CDC *dc)
{
  dc->color = BLACK;
  GrRect(dc, 0, MH, 640, 4);
  dc->color = WHITE;
  GrPrint(dc, 4, 1, "%07d", score);
  GrPrint(dc, 260, 1, "HI %07d", hi);
  GrPrint(dc, 520, 1, "WAVE %d", wave);
  dc->color = LTRED;
  GrPrint(dc, 68, 1, "B:%d", bk_boosts);
  dc->color = LTGREEN;
  GrPrint(dc, 112, 1, "S:%d", shasta_items);
  if (bird_caught) dc->color = LTGREEN;
  else dc->color = LTRED;
  GrPrint(dc, 156, 1, "BIRD");
  dc->color = LTCYAN;
  GrPrint(dc, 200, 1, "L:%d", lives);
  dc->color = LTGREEN;
  if (used_bk) DrawCheck(dc, 76, 12);
  if (used_shasta) DrawCheck(dc, 120, 12);
  if (bird_caught) DrawCheck(dc, 164, 12);
  if (used_bk && used_shasta && bird_caught)
  {
    dc->color = YELLOW;
    DrawCrown(dc, 206, 11);
  }
  dc->color = LTRED;
  GrPrint(dc, 360, 1, "TERRY %d", terry_caps);
  dc->color = YELLOW;
  GrPrint(dc, 444, 1, "UFO %d", ufo_caps);
  if (hyper_avail) dc->color = LTGREEN;
  else dc->color = DKGRAY;
  GrPrint(dc, 584, 1, "HYP");

  if (terry >= 0 && glow[terry].act && glow[terry].carried)
  {
    if ((total_frames / 4) & 1)
    {
      dc->color = LTRED;
      GrPrint(dc, 168, 60, "!! TERRY ABDUCTED -- SHOOT THE SHIP !!");
    }
    if (hyper_avail)
    {
      dc->color = YELLOW;
      GrPrint(dc, 200, 76, "Press H to HYPER-JUMP to Terry");
    }
  }

  if (pick_msg > 0)
  {
    U8 *nm;
    if (pick_item == ITEM_SHASTA) nm = "SHASTA BOOST";
    else nm = "BK BOOST";
    dc->color = LTGREEN;
    if (pick_who == 1)
      GrPrint(dc, 206, 100, "Terry grabbed a %s!", nm);
    else
      GrPrint(dc, 240, 100, "Got a %s!", nm);
  }

  if (bird_msg > 0)
  {
    if (bird_killed)
    {
      dc->color = LTRED;
      GrPrint(dc, 196, 118, "You killed Terry's bird!  -%d", BIRD_PTS);
    }
    else
    {
      dc->color = LTGREEN;
      GrPrint(dc, 232, 118, "Caught the bird! +%d", BIRD_PTS);
    }
  }

  if (bk_msg > 0)
  {
    U8 *msg = "BK POWER!";
    if ((total_frames / 4) & 1) dc->color = RED;
    else dc->color = YELLOW;
    GrPrint(dc, (640 - StrLen(msg) * FONT_WIDTH) / 2, 136, msg);
  }

  if (shasta_timer > 0)
  {
    I64 bsec = (shasta_timer + 29) / 30;
    if (bsec <= 5 && (total_frames / 4) & 1) dc->color = RED;
    else dc->color = LTGREEN;
    GrPrint(dc, 256, 44, "SHASTA BOOST %ds", bsec);
  }

  if (state == ST_DEAD)
  {
    dc->color = LTRED;
    GrPrint(dc, 236, 210, "SHIP DESTROYED!");
    dc->color = WHITE;
    GrPrint(dc, 236, 230, "Ships left: %d", lives);
  }
  if (state == ST_NEXT)
  {
    dc->color = YELLOW;
    GrPrint(dc, 262, 162, "WAVE CLEAR!");
    dc->color = WHITE;
    GrPrint(dc, 210, 184, "Ships left      %2d x %3d = %5d",
        lives, 100, bonus_life);
    GrPrint(dc, 210, 196, "BK Boost        %2d x %3d = %5d",
        bk_boosts, 50, bonus_bk);
    GrPrint(dc, 210, 208, "Shasta Boost    %2d x %3d = %5d",
        shasta_items, 50, bonus_shasta);
    GrPrint(dc, 210, 220, "Wave %-2d         %2d x %3d = %5d",
        wave, wave, 250, bonus_wave);
    if (bonus_hyper > 0)
    {
      dc->color = LTGREEN;
      GrPrint(dc, 210, 232, "Hyper-jump saved         = %5d", bonus_hyper);
      dc->color = WHITE;
    }
    else
    {
      dc->color = WHITE;
      GrPrint(dc, 210, 232, "Hyper-jump used          = %5d", 0);
    }
    if (bonus_king > 0)
    {
      dc->color = YELLOW;
      DrawCrown(dc, 194, 245);
      dc->color = LTGREEN;
      GrPrint(dc, 210, 244, "KING TERRY BONUS!        = %5d", bonus_king);
      dc->color = WHITE;
    }
    else
    {
      dc->color = WHITE;
      GrPrint(dc, 210, 244, "King Terry               = %5d", 0);
    }
    dc->color = YELLOW;
    GrPrint(dc, 210, 260, "Total bonus              = %5d", bonus_total);
    dc->color = WHITE;
    GrPrint(dc, 216, 280, "Press SPACE for next wave");
  }
  if (state == ST_OVER)
  {
    if (terry_lost)
    {
      dc->color = LTRED;
      GrPrint(dc, 200, 188, "TERRY WAS TAKEN TO THE TOP!");
    }
    dc->color = RED;
    GrPrint(dc, 248, 210, "GAME OVER");
    dc->color = WHITE;
    GrPrint(dc, 222, 234, "Score: %d", score);
    dc->color = YELLOW;
    GrPrint(dc, 210, 258, "R = Restart   ESC = Quit");
    dc->color = LTGREEN;
    GrPrint(dc, 184, 282, "Abducted -- Terry: %d   UFOs: %d",
        terry_caps, ufo_caps);
  }
}

U0 DrawIt(CTask *task, CDC *dc)
{
  no_warn task;
  DrawBackground(dc);
  DrawBird(dc);
  DrawGlowies(dc);
  DrawEnemies(dc);
  DrawPickups(dc);
  DrawPlayer(dc);
  DrawBullets(dc);
  DrawMinimap(dc);
  DrawHud(dc);
}

U0 GlowUFOs()
{
  I64 ch, sc;
  Bool running;

  SettingsPush;
  AutoComplete;
  WinMax;
  WinBorder(0);
  DocCursor(0);
  MenuPush("File {}\n");

  ms.show=0;
  DocClear;
  Type("Help.DD");
  "\n$FG,12$Press any key to start...$FG$\n";
  ch = GetKey;
  DocClear;

  NewGame();

  Fs->draw_it = &DrawIt;
  running = TRUE;

  try
  {
    while (running)
    {
      switch (ScanMsg(&ch, &sc, (1 << MSG_KEY_DOWN) | (1 << MSG_KEY_UP)))
      {
      case MSG_KEY_DOWN:
        switch (sc.u8[0])
        {
        case SC_CURSOR_LEFT:
          kl = TRUE;
          break;
        case SC_CURSOR_RIGHT:
          kr = TRUE;
          break;
        case SC_CURSOR_UP:
          ku = TRUE;
          break;
        case SC_CURSOR_DOWN:
          kd = TRUE;
          break;
        }
        switch (ch)
        {
        case ' ':
          kfire = TRUE;
          if (state == ST_NEXT && next_armed) knext = TRUE;
          break;
        case 'b':
        case 'B':
          kbk = TRUE;
          break;
        case 'h':
        case 'H':
          HyperJump();
          break;
        case 's':
        case 'S':
          UseShastaBoost();
          break;
        case 'r':
        case 'R':
          if (state == ST_OVER) NewGame();
          break;
        case CH_ESC:
          running = FALSE;
          break;
        }
        break;
      case MSG_KEY_UP:
        switch (sc.u8[0])
        {
        case SC_CURSOR_LEFT:
          kl = FALSE;
          break;
        case SC_CURSOR_RIGHT:
          kr = FALSE;
          break;
        case SC_CURSOR_UP:
          ku = FALSE;
          break;
        case SC_CURSOR_DOWN:
          kd = FALSE;
          break;
        }
        switch (ch)
        {
        case ' ':
          kfire = FALSE;
          next_armed = TRUE;
          break;
        }
        break;
      }
      Update();
      Sleep(33);
    }
  }
  catch PutExcept;

  ms.show=1;
  Fs->draw_it = NULL;
  RegWrite("TinkerOS/GlowUFOs","hi=%d;\n",hi);
  MenuPop;
  SettingsPop;
  "\nGlowUFOs ended. Score: %d  Hi: %d\n", score, hi;
}

GlowUFOs;
