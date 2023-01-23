//Uses $LK,"fixed-point",A="FI:::/Demo/Lectures/FixedPoint.HC"$.

RegDft("TempleOS/CF2","F64 best_score=9999;\n");
RegExe("TempleOS/CF2");

//Set snap to 4 and width to 4
//if you edit this map.

#define MAX_TANKS         10
#define MAX_ITEMS         16

#define ZOMBIE_LIFE       5
#define TANK_LIFE         10

#define ZOMBIE_AMMO       10
#define TANK_AMMO         20
#define MONSTER_HOLD_TIME 2.0

#define PLAYER_AMMO_MAX   250

#define TANK_DAMAGE       20
#define ZOMBIE_DAMAGE     10

#define ITEM_AMMO_BONUS   10
#define ITEM_TIME_BONUS   30
#define ITEM_HEALTH_BONUS 15

#define ITEM_RESPAWN_TIME    60.0
#define MONSTER_RESPAWN_TIME 180.0
#define DEATH_TIME_PENALTY   60.0


F64 MAN_START_X=-1.0;
F64 MAN_START_Y=-1.0;
F64 last_health_loss=tS;
F64 last_coffin_respawn=tS;
I64 tanks_left=0;
I64 player_health=100;
I64 player_ammo=PLAYER_AMMO_MAX;
I64 player_gold=0;
I64 player_lives_lost=0;
I64 difficulty=1;
Bool player_dead=FALSE;


$SP,"<1>",BI=1$
















#define MONSTER_SCALE	2.0








		     $SP,"<2>",BI=2$
 









		     $SP,"<3>",BI=3$
 








		     $SP,"<4>",BI=4$
 






#define PLANT_SCALE	2.0



		     $SP,"<5>",BI=5$


















		       $SP,"<6>",BI=6$












// Time bonus item


		$SP,"<7>",BI=7$













		$SP,"<8>",BI=8$
















// These add to ammo



		   $SP,"<9>",BI=9$


// These add health 


		$SP,"<10>",BI=10$


// DEADPLAYER

		$SP,"<11>",BI=11$





#define TANK_SCALE 1.0

#define SCRN_SCALE		512
#define PLOT_GRID_WIDTH		24
#define PLOT_GRID_HEIGHT	24
#define MAN_HEIGHT		125

#define MAP_SCALE	4
I64 map_width,map_height;
U8 *map=NULL,
*panels_processed_bitmap=NULL;

I64 man_xx,man_yy,man_spawn_xx,man_spawn_yy;
F64 man_é;

F64 t0,tf;

I64 *deadman=NULL,*t1,*t2,*r1,*r2,*r3,*s2w,*dcr;
Bool play_music=FALSE;

#define MONSTERS_NUM	15


I64 monsters_left;

#define MONSTER_NULL   0
#define MONSTER_ZOMBIE 1
#define MONSTER_TANK   2


class Monster
{
  I64 ammo,x,y,type,life;
  F64 death_time,hold_time;
  Bool dead,pad[7];
} monsters[MONSTERS_NUM+MAX_TANKS];

#define ITEM_NULL   0
#define ITEM_HEALTH 1
#define ITEM_AMMO   2
#define ITEM_BONUS  3

class Item
{
  I64 x,y,type;
  F64 last_consume_time;
  Bool exists;
} items[MAX_ITEMS];


U0 CFTransform(CDC *dc,I64 *x,I64 *y,I64 *z)
{
  I64 zz;
  Mat4x4MulXYZ(dc->r,x,y,z);
  zz=SCRN_SCALE/3+*z;
  if (zz<1) zz=1;
  *x=SCRN_SCALE/2* *x/zz;
  *y=SCRN_SCALE/2* (*y+MAN_HEIGHT)/zz;
  *x+=dc->x;
  *y+=dc->y;
  *z+=dc->z;
}

#define LOS_SCALE	4

Bool LOSPlot(U8 *,I64 x,I64 y,I64)
{
  I64 xx,yy;
  xx=ClampI64(x/LOS_SCALE,0,map_width-1);
  yy=ClampI64(y/LOS_SCALE,0,map_height-1);
  if (!map[yy*map_width+xx])
    return FALSE;
  else
    return TRUE;
}

Bool LOS(I64 x1,I64 y1,I64 x2,I64 y2)
{//Line of sight
  Bool res=FALSE;
  try {
   res=Line(NULL,x1*LOS_SCALE/SCRN_SCALE,y1*LOS_SCALE/SCRN_SCALE,0,
        x2*LOS_SCALE/SCRN_SCALE,y2*LOS_SCALE/SCRN_SCALE,0,&LOSPlot);
  }
  catch {
   res=FALSE;
  }
  return res;
}


U0 Death()
{
    player_dead=TRUE;
    Sweep(1000,62,62);
    Sleep(1000);
    Sweep(2000,54,54);
    Sleep(2000);
    player_health=100;
    player_ammo=PLAYER_AMMO_MAX/2;
    man_xx=man_spawn_xx;
    man_yy=man_spawn_yy;
    man_é=0;
    player_dead=FALSE;
}


U0 DrawIt(CTask *task,CDC *dc)
{
  I64 i,j,k,xx,yy,zz,x,y,x1,y1,z1,
        c,x1w,y1w,x1h,y1h,xh,yh,zh,
        cx=task->pix_width/2,
        cy=task->pix_height/2, *olddcr;
  U8 *tmps;
  F64 tt;
  CD3I32 poly[4];
  Monster *tmpm;
  Item *tmpi;

  if (!deadman)
    {
    deadman=Mat4x4IdentNew(task);
    s2w=Mat4x4IdentNew(task);
    t1=Mat4x4IdentNew(task);
    t2=Mat4x4IdentNew(task);
    r1=Mat4x4IdentNew(task);
    r2=Mat4x4IdentNew(task);
    r3=Mat4x4IdentNew(task);
    dcr=Mat4x4IdentNew(task);
  }

  DCDepthBufAlloc(dc);
  MemSet(panels_processed_bitmap,0,(map_width*map_height+7)>>3);

  Mat4x4IdentEqu(dcr);
  olddcr=dc->r;
  dc->r=dcr;

  //World to scrn
  Mat4x4RotZ(dc->r,man_é+ã/2);
  Mat4x4RotX(dc->r,ã/2);
  DCMat4x4Set(dc,dc->r);

  xh=-man_xx/SCRN_SCALE; yh=-man_yy/SCRN_SCALE; zh=0;
  Mat4x4MulXYZ(dc->r,&xh,&yh,&zh);
  Mat4x4TranslationEqu(dc->r,xh,yh,zh);

  //Scrn to world
  Mat4x4IdentEqu(s2w);
  Mat4x4RotX(s2w,-ã/2);
  Mat4x4RotZ(s2w,-man_é-ã/2);
  xh=0; yh=0; zh=SCRN_SCALE;
  Mat4x4MulXYZ(s2w,&xh,&yh,&zh);

  //Rotate light source
  xx=dc->ls.x; yy=dc->ls.y; zz=-dc->ls.z;
  (*dc->transform)(dc,&xx,&yy,&zz);
  dc->ls.x=xx; dc->ls.y=yy; dc->ls.z=zz;

  dc->flags|=DCF_TRANSFORMATION;
  dc->transform=&CFTransform;
  dc->x=cx;
  dc->y=cy;


  Mat4x4IdentEqu(deadman);
  Mat4x4TranslationAdd(deadman,0,-10,0);
  Mat4x4RotZ(deadman,tS);
  Mat4x4Scale(deadman,3.0);

  Mat4x4IdentEqu(t1);
  Mat4x4TranslationAdd(t1,0,-30,0);
  Mat4x4Scale(t1,TANK_SCALE);

  Mat4x4IdentEqu(t2);
  Mat4x4TranslationAdd(t2,0,-30,0);
  Mat4x4RotX(t2,-ã/2);
  Mat4x4RotZ(t2,tS);
  Mat4x4Scale(t2,TANK_SCALE);

  Mat4x4IdentEqu(r1);
  Mat4x4RotX(r1,-ã/2);
  Mat4x4RotZ(r1,4.0*tS);
  Mat4x4Scale(r1,MONSTER_SCALE);

  Mat4x4IdentEqu(r2);
  Mat4x4Scale(r2,MONSTER_SCALE);

  Mat4x4IdentEqu(r3);
  Mat4x4RotX(r3,-ã/2);
  Mat4x4Scale(r3,PLANT_SCALE);

  Seed(1);
  x1h=man_xx+yh*PLOT_GRID_WIDTH/2+xh*(PLOT_GRID_HEIGHT-1);
  y1h=man_yy-xh*PLOT_GRID_WIDTH/2+yh*(PLOT_GRID_HEIGHT-1);
  xh>>=1; yh>>=1;
  for (j=0;j<PLOT_GRID_HEIGHT*2;j++) {
    x1w=x1h;
    y1w=y1h;
    for (i=0;i<PLOT_GRID_WIDTH*4;i++) {
      xx=x1w/SCRN_SCALE; yy=y1w/SCRN_SCALE;
      x=xx*SCRN_SCALE-man_xx; y=yy*SCRN_SCALE-man_yy;
      if (1<=xx<map_width-1 && 1<=yy<map_height-1 &&
	    !LBts(panels_processed_bitmap,yy*map_width+xx)) {
        if ((c=map[yy*map_width+xx]) &&
	      LOS(xx*SCRN_SCALE+SCRN_SCALE/2,yy*SCRN_SCALE+SCRN_SCALE/2,
	      man_xx,man_yy)) {
	  if (c==YELLOW)
	    dc->color=DKGRAY;
	  else
	    dc->color=c;
	  poly[0].x=x;
	  poly[0].y=y;
	  poly[0].z=0;
	  poly[1].x=x+SCRN_SCALE;
	  poly[1].y=y;
	  poly[1].z=0;
	  poly[2].x=x+SCRN_SCALE;
	  poly[2].y=y+SCRN_SCALE;
	  poly[2].z=0;
	  poly[3].x=x;
	  poly[3].y=y+SCRN_SCALE;
	  poly[3].z=0;
	  GrFillPoly3(dc,4,poly);
	  if (c==GREEN) {
	    x1=x+SCRN_SCALE/2;
	    y1=y+SCRN_SCALE/2;
	    z1=0;
	    DCTransform(dc,&x1,&y1,&z1);
	    if (z1>0)
	      Sprite3Mat4x4B(dc,x+SCRN_SCALE/2,y+SCRN_SCALE/2,0,$IB,"<5>",BI=5$,r3);
	  } else if (c==YELLOW) {
	    x1=x+SCRN_SCALE/2;
	    y1=y+SCRN_SCALE/2;
	    z1=0;
	    DCTransform(dc,&x1,&y1,&z1);
	    if (z1>0)
	      Sprite3Mat4x4B(dc,x+SCRN_SCALE/2,y+SCRN_SCALE/2,0,$IB,"<6>",BI=6$,r3);
	  }

	  if (!map[(yy+1)*map_width+xx]) {
	    dc->color=LTGRAY;
	    poly[0].x=x;
	    poly[0].y=y+SCRN_SCALE;
	    poly[0].z=0;
	    poly[1].x=x+SCRN_SCALE;
	    poly[1].y=y+SCRN_SCALE;
	    poly[1].z=0;
	    poly[2].x=x+SCRN_SCALE;
	    poly[2].y=y+SCRN_SCALE;
	    poly[2].z=SCRN_SCALE;
	    poly[3].x=x;
	    poly[3].y=y+SCRN_SCALE;
	    poly[3].z=SCRN_SCALE;
	    GrFillPoly3(dc,4,poly);
	  }
	  if (!map[yy*map_width+xx+1]) {
	    dc->color=WHITE;
	    poly[0].x=x+SCRN_SCALE;
	    poly[0].y=y;
	    poly[0].z=0;
	    poly[1].x=x+SCRN_SCALE;
	    poly[1].y=y+SCRN_SCALE;
	    poly[1].z=0;
	    poly[2].x=x+SCRN_SCALE;
	    poly[2].y=y+SCRN_SCALE;
	    poly[2].z=SCRN_SCALE;
	    poly[3].x=x+SCRN_SCALE;
	    poly[3].y=y;
	    poly[3].z=SCRN_SCALE;
	    GrFillPoly3(dc,4,poly);
	  }
	  if (!map[(yy-1)*map_width+xx]) {
	    dc->color=LTGRAY;
	    poly[0].x=x;
	    poly[0].y=y;
	    poly[0].z=0;
	    poly[1].x=x+SCRN_SCALE;
	    poly[1].y=y;
	    poly[1].z=0;
	    poly[2].x=x+SCRN_SCALE;
	    poly[2].y=y;
	    poly[2].z=SCRN_SCALE;
	    poly[3].x=x;
	    poly[3].y=y;
	    poly[3].z=SCRN_SCALE;
	    GrFillPoly3(dc,4,poly);
	  }
	  if (!map[yy*map_width+xx-1]) {
	    dc->color=WHITE;
	    poly[0].x=x;
	    poly[0].y=y;
	    poly[0].z=0;
	    poly[1].x=x;
	    poly[1].y=y+SCRN_SCALE;
	    poly[1].z=0;
	    poly[2].x=x;
	    poly[2].y=y+SCRN_SCALE;
	    poly[2].z=SCRN_SCALE;
	    poly[3].x=x;
	    poly[3].y=y;
	    poly[3].z=SCRN_SCALE;
	    GrFillPoly3(dc,4,poly);
	  }
        }
      }
      x1w-=yh;
      y1w+=xh;
    }
    x1h-=xh;
    y1h-=yh;
  }

  // start dead player exclude
  if (!player_dead) {


    x1=2*(man_xx/SCRN_SCALE);
    y1=2*(map_height-1-man_yy/SCRN_SCALE);

    //Coffin spawn monster
    if (tS-last_coffin_respawn>3.0-difficulty/2.0)
      {
      for (i=0;i<map_height;i++)
        for (j=0;j<map_width;j++) {
	  x=j;
	  y=(map_height-1-i);
	  if (YELLOW==map[y*map_width+x])
	    if ((2*j-x1)*(2*j-x1)+(2*i-y1)*(2*i-y1)<8+difficulty) {
	      for (k=0,tmpm=monsters+MAX_TANKS;k<MONSTERS_NUM;k++,tmpm++)
	        {
	        if (tmpm->type==MONSTER_ZOMBIE && tmpm->dead) {
		  tmpm->dead=FALSE;
		  tmpm->life=ZOMBIE_LIFE+difficulty;
		  tmpm->ammo=1+RandU64%(ZOMBIE_AMMO-difficulty);
		  tmpm->x=man_xx+2.0*Cos(man_é);
		  tmpm->y=man_yy+2.0*Sin(man_é);		  
		  monsters_left++;
		  k=MONSTERS_NUM;
		  last_coffin_respawn=tmpm->hold_time=tS;
		  Sweep(70,62,62);
	        }
	      }
	    }
        }
    }

    //Draw Monsters
    for (i=0,tmpm=monsters;i<MONSTERS_NUM+MAX_TANKS;i++,tmpm++) {
      x=tmpm->x;
      y=tmpm->y;
      if (LOS(x,y,man_xx,man_yy)) {
        x-=man_xx;
        y-=man_yy;
        xx=x;
        yy=y;
        zz=0;
        if (MONSTER_ZOMBIE==tmpm->type)
	  {
	  DCTransform(dc,&xx,&yy,&zz);
	  if (zz>0) {
	    if (tmpm->dead) {
	      if (tmpm->ammo && tS-tmpm->death_time>1.5)
	        Sprite3Mat4x4B(dc,x,y,0,$IB,"<9>",BI=9$,r2);
	      else if(tmpm->ammo)
	        Sprite3Mat4x4B(dc,x,y,0,$IB,"<2>",BI=2$,r2);
	    }
	    else {
	      tt=Tri(tS,1.0);
	      tmps=SpriteInterpolate(tt,$IB,"<3>",BI=3$,$IB,"<4>",BI=4$);
	      Sprite3Mat4x4B(dc,x,y,0,tmps,r1);
	      Free(tmps);
	    }
	  }
        }
        if (MONSTER_TANK==tmpm->type)
	  {
	  DCTransform(dc,&xx,&yy,&zz);
	  if (zz>0) {
	    if (tmpm->dead) {
	      if (tmpm->ammo && tS-tmpm->death_time>1.5)
	        Sprite3Mat4x4B(dc,x,y,0,$IB,"<9>",BI=9$,t1);
	      else if (tmpm->ammo)
	        Sprite3Mat4x4B(dc,x,y,0,$IB,"<8>",BI=8$,t1);
	    }
	    else
	      Sprite3Mat4x4B(dc,x,y,0,$IB,"<8>",BI=8$,t2);
	  }
        }
      }
    }

    // Draw Items
    for (i=0,tmpi=items;i<MAX_ITEMS-difficulty;i++,tmpi++) {
      x=tmpi->x;
      y=tmpi->y;
      if (LOS(x,y,man_xx,man_yy)) {
        x-=man_xx;
        y-=man_yy;
        xx=x;
        yy=y;
        zz=0;
        if (tmpi->exists) {
	  DCTransform(dc,&xx,&yy,&zz);
	  if (ITEM_HEALTH==tmpi->type && zz>0)
	    Sprite3Mat4x4B(dc,x,y,0,$IB,"<10>",BI=10$,t1);
	  if (ITEM_AMMO==tmpi->type && zz>0)
	    Sprite3Mat4x4B(dc,x,y,0,$IB,"<9>",BI=9$,t1);
	  if (ITEM_BONUS==tmpi->type && zz>0)
	    Sprite3Mat4x4B(dc,x,y,0,$IB,"<7>",BI=7$,t1);
        }
      }
    }

    //Draw Map heads-up display, scaled 2 pixs
    Mat4x4IdentEqu(dcr);

    dc->x=task->pix_width -2*map_width;
    dc->y=task->pix_height-2*map_height;
    dc->z=0;
    dc->transform=&DCTransform;
    dc->thick=2;
    for (i=0;i<map_height;i++)
      for (j=0;j<map_width;j++) {
        dc->color=map[(map_height-1-i)*map_width+j];
        GrPlot3(dc,2*j,2*i,0);
      }

    //Draw monsters on heads-up map and handle collisions
    dc->color=LTPURPLE;
    for (i=0,tmpm=monsters;i<MONSTERS_NUM+MAX_TANKS;i++,tmpm++) {
      x=2*(tmpm->x/SCRN_SCALE);
      y=2*(map_height-1-tmpm->y/SCRN_SCALE);
      if (!tmpm->dead) {
        dc->color=LTPURPLE;
        if (tmpm->type==MONSTER_TANK)
	  dc->color=CYAN;
        if (tmpm->type) {
	  GrPlot3(dc,x,y,0);
	  if (x==x1&&y==y1&&tS-last_health_loss>1.0) {
	    Sweep(50,62,100);
	    last_health_loss=tS;
	    if (tmpm->type==MONSTER_ZOMBIE) 
	      player_health-=ZOMBIE_DAMAGE;
	    if (tmpm->type==MONSTER_TANK) 
	      player_health-=TANK_DAMAGE;
	  }
        }
      }
      if (tmpm->dead && tmpm->ammo && ((x-x1)*(x-x1)+(y-y1)*(y-y1))<6) {
        player_ammo+=tmpm->ammo;
        tmpm->ammo=0;
        Sweep(50,200,100);
      }
    }
    // Draw health items and consume
    for (i=0,tmpi=items;i<MAX_ITEMS-difficulty;i++,tmpi++)
      {
      x=2*(tmpi->x/SCRN_SCALE);
      y=2*(map_height-1-tmpi->y/SCRN_SCALE);
      if (tmpi->type==ITEM_HEALTH) {
        dc->color=LTRED;
        if (tmpi->exists)
	  GrPlot3(dc,x,y,0);
        if (player_health<100 && tmpi->exists && ((x-x1)*(x-x1)+(y-y1)*(y-y1))<6) {
	  player_health+=ITEM_HEALTH_BONUS;
	  tmpi->exists=FALSE;
	  Sweep(50,200,100);
        }
      }
      if (tmpi->type==ITEM_AMMO) {
        // Not drawing ammo on minimap
        if (player_ammo<PLAYER_AMMO_MAX && tmpi->exists && ((x-x1)*(x-x1)+(y-y1)*(y-y1))<6) {
	  player_ammo+=ITEM_AMMO_BONUS;
	  tmpi->exists=FALSE;
	  Sweep(50,200,100);
        }
      }
      if (tmpi->type==ITEM_BONUS) {
        // Not drawing ammo on minimap
        if (tS-t0>ITEM_TIME_BONUS && tmpi->exists && ((x-x1)*(x-x1)+(y-y1)*(y-y1))<6) {
	  t0+=ITEM_TIME_BONUS;
	  tmpi->exists=FALSE;
	  Sweep(50,200,100);
        }
      }
    }


  } // end dead exclude


  dc->color=LTCYAN;
  GrPlot3(dc,x1,y1,0);

  if (tf) {
    dc->color=LTRED;
    if (Blink)
      GrPrint(dc,cx-(FONT_WIDTH*14)/2,cy-FONT_HEIGHT/2,"Game Completed");
    tt=tf;
  } else {
    dc->color=LTGREEN;
    GrLine(dc,cx-5,cy,cx+5,cy);
    GrLine(dc,cx,cy-5,cx,cy+5);
    tt=tS;
  }
  if (player_health>100)
    player_health=100;
  if (player_ammo>PLAYER_AMMO_MAX)
    player_ammo=PLAYER_AMMO_MAX;

  if (!player_dead && player_health<1) {
    player_lives_lost++;
    player_dead=TRUE;
    t0-=DEATH_TIME_PENALTY+30.0*(difficulty-1);
    Spawn(&Death,NULL);
  }
  if (player_dead) {
    GrPrint(dc,0,0,"Life: %d Bullets: %d Enemy: %d Deaths: %d Difficulty: %d Time:%3.2f Best:%3.2f",
	  0,0,monsters_left+tanks_left,player_lives_lost,difficulty,tt-t0,best_score);
    Sprite3Mat4x4B(dc,0,0,0,$IB,"<11>",BI=11$,deadman);
  }
  else
    GrPrint(dc,0,0,"Life: %d Bullets: %d Enemy: %d Deaths: %d Difficulty: %d Time:%3.2f Best:%3.2f",
	  player_health,player_ammo,monsters_left+tanks_left,player_lives_lost,difficulty,tt-t0,best_score);

  Seed(0);

  dc->r=olddcr;

}

CTask *respawn_task=NULL;

U0 RespawnTask()
{
  Bool monster_respawned=FALSE;
  I64 i;
  Monster *tmpm;
  Item *tmpi;

  while (TRUE)
    {
    Sleep(1000);

    //Respawn monsters (just one at a time, reset timer for rest)
    for (i=0,tmpm=monsters+MAX_TANKS;i<MONSTERS_NUM;i++,tmpm++)
      {
      if (!monster_respawned && tmpm->type) {
        if (tmpm->dead && tS-tmpm->death_time>MONSTER_RESPAWN_TIME/difficulty) {
	  tmpm->dead=FALSE;
	  monster_respawned=TRUE;
	  if (tmpm->type==MONSTER_ZOMBIE) {
	    tmpm->life=ZOMBIE_LIFE+difficulty;
	    tmpm->ammo=1+RandU64%(ZOMBIE_AMMO-difficulty);
	    monsters_left++;
	  }
          // Not currently respawning tanks
	  if (tmpm->type==MONSTER_TANK) {
	    tmpm->life=TANK_LIFE;
	    tmpm->ammo=TANK_AMMO;
	    tanks_left++;
	  }

	  do {
	    tmpm->x=RandU64%((map_width-2)*SCRN_SCALE)+SCRN_SCALE;
	    tmpm->y=RandU64%((map_height-2)*SCRN_SCALE)+SCRN_SCALE;
	  } while (DKGRAY!=map[(tmpm->y/SCRN_SCALE)*map_width+tmpm->x/SCRN_SCALE]);

        }
      }
    }

    // Reset timer for rest of monsters if we spawned one
    if (monster_respawned)
      for (i=0,tmpm=monsters;i<MONSTERS_NUM+MAX_TANKS;i++,tmpm++)
        {
        tmpm->death_time=tS-20.0*difficulty;
      }

    // Respawn items (all items can respawn)
    for (i=0,tmpi=items;i<MAX_ITEMS-difficulty;i++,tmpi++) {
      if (!tmpi->exists && tS-tmpi->last_consume_time>ITEM_RESPAWN_TIME*difficulty) {
        tmpi->exists=TRUE;
        tmpi->last_consume_time=tS;
        do {
	  tmpi->x=RandU64%((map_width-2)*SCRN_SCALE)+SCRN_SCALE;
	  tmpi->y=RandU64%((map_height-2)*SCRN_SCALE)+SCRN_SCALE;
        } while (DKGRAY!=map[(tmpi->y/SCRN_SCALE)*map_width+tmpi->x/SCRN_SCALE]);

      }  
    }
  }
}


U0 Fire()
{
  I64 i,x,y;
  F64 d,dx,dy,xx=Cos(man_é),yy=Sin(man_é);
  Monster *tmpm;
  if (player_ammo>0) {
  Sweep(40,60,40);
  for (i=0,tmpm=monsters;i<MONSTERS_NUM+MAX_TANKS;i++,tmpm++) {
    x=tmpm->x;
    y=tmpm->y;
    if (!tmpm->dead &&
	  LOS(x,y,man_xx,man_yy)) {
      dx=x-man_xx;
      dy=man_yy-y;
      if (d=Sqrt(dx*dx+dy*dy)) {
        dx/=d;
        dy/=d;
        if (dx*xx+dy*yy>0.995) {
          tmpm->life--;
          if (tmpm->life<=0) {
	  tmpm->dead=TRUE;
          tmpm->death_time=tS;
          if (tmpm->type==MONSTER_ZOMBIE)
            monsters_left--;
          if (tmpm->type==MONSTER_TANK)
            tanks_left--;
	  if (!monsters_left && !tanks_left) {
	    tf=tS;
	    if (tf-t0<best_score)
	      best_score=tf-t0;
	  }
         }
        }
      }
    }
  }
  player_ammo--;
  }
  else {
    Sweep(40,25,25);
  }
}

U0 StepBackMan(F64 é)
{
  I64 x,y,x2,y2,color,color2,step=1;
  do {
    x=man_xx+64*step*Cos(man_é+é);
    y=man_yy-64*step*Sin(man_é+é);
    x2=man_xx+128*step*Cos(man_é+é);
    y2=man_yy-128*step*Sin(man_é+é);
    x=Clamp(x,0,map_width*SCRN_SCALE);
    y=Clamp(y,0,map_height*SCRN_SCALE);
    x2=Clamp(x2,0,map_width*SCRN_SCALE);
    y2=Clamp(y2,0,map_height*SCRN_SCALE);

    color=map[y/SCRN_SCALE*map_width+x/SCRN_SCALE];
    color2=map[y2/SCRN_SCALE*map_width+x2/SCRN_SCALE];
    if (color==DKGRAY || color==GREEN) {
    if (color2==DKGRAY || color2==GREEN) {
      break;
    }
    }
    man_xx-=64*step*Cos(man_é+é);
    man_yy+=64*step*Sin(man_é+é);
    step*=2;
    if (step<16) break;    
  } while (step<SCRN_SCALE/2);
    
}

CTask *relocate_task=NULL;

// Helps keep player in maze by checking
// various direction and nudging the player
// back into the maze
U0 RelocateTask()
{
  I64 x;

  while (TRUE) {
    for (x=0;x<8;x++) {
      StepBackMan(ToF64(x)*ã/8.0);
      Sleep(15);
    }
  }
}


U0 Init()
{
  I64 i,x,y,tanks=0;
  CDC *dc;
  Monster *tmpm;
  Item *tmpi;

  DocClear;
  "$$BG,BLACK$$%h*c",TEXT_ROWS/2,'\n';

  last_health_loss=tS;
  last_coffin_respawn=tS;
  tanks=0;
  tanks_left=0;
  player_health=100;
  player_ammo=PLAYER_AMMO_MAX;
  player_gold=0;
  player_lives_lost=0;
  player_dead=FALSE;


  dc=Sprite2DC($IB,"<1>",BI=1$);
  map_width =dc->width/MAP_SCALE+2;
  map_height=dc->height/MAP_SCALE+2;
  Free(map);
  Free(panels_processed_bitmap);
  map=CAlloc((map_width+2)*(map_height+2));
  panels_processed_bitmap=MAlloc(((map_width+1)*map_height+7)>>3);


  for (i=0,tmpm=monsters;i<MONSTERS_NUM+MAX_TANKS;i++,tmpm++) {
   tmpm->type=MONSTER_NULL;
   tmpm->hold_time=tS;
  }


  tmpm=monsters;
  for (y=0;y<map_height-2;y++)
    for (x=0;x<map_width-2;x++) {
      map[(map_height-2-y)*map_width+x+1]=GrPeek(dc,x*MAP_SCALE,y*MAP_SCALE);
      if (WHITE==GrPeek(dc,x*MAP_SCALE,y*MAP_SCALE))
      {
        map[(map_height-2-y)*map_width+x+1]=0;
      }
      if (LTGREEN==GrPeek(dc,x*MAP_SCALE,y*MAP_SCALE))
      {
        map[(map_height-2-y)*map_width+x+1]=DKGRAY;
        if (MAN_START_X<0)
	  MAN_START_X=x+0.5;
        if (MAN_START_Y<0)
	  MAN_START_Y=y+0.5;
      }
      if (CYAN==GrPeek(dc,x*MAP_SCALE,y*MAP_SCALE))
      {
        map[(map_height-2-y)*map_width+x+1]=DKGRAY;
        if (tanks<MAX_TANKS) {
          tanks++;
          tanks_left++;
          tmpm->dead=FALSE;
          tmpm->life=TANK_LIFE+2*difficulty;
          tmpm->x=(1+x)*SCRN_SCALE;
          tmpm->y=(map_height-1-y)*SCRN_SCALE;
          tmpm->type=MONSTER_TANK;
          tmpm->ammo=TANK_AMMO;
          tmpm++;
        }

      }

      }
  DCDel(dc);
  tmpm=monsters+MAX_TANKS;
  for (i=0;i<MONSTERS_NUM;i++,tmpm++) {
    tmpm->dead=FALSE;
    tmpm->life=ZOMBIE_LIFE+difficulty;
    tmpm->type=MONSTER_ZOMBIE;
    tmpm->ammo=1+RandU64%(ZOMBIE_AMMO-difficulty);
    do {
      tmpm->x=RandU64%((map_width-2)*SCRN_SCALE)+SCRN_SCALE;
      tmpm->y=RandU64%((map_height-2)*SCRN_SCALE)+SCRN_SCALE;
    } while (DKGRAY!=map[(tmpm->y/SCRN_SCALE)*map_width+tmpm->x/SCRN_SCALE]);
  }

  tmpi=items;
  for (i=0;i<MAX_ITEMS;i++,tmpi++) {
    tmpi->type=ITEM_NULL;
    tmpi->exists=FALSE;
  }

  tmpi=items;
  for (i=0;i<MAX_ITEMS-difficulty;i++,tmpi++) {
    tmpi->exists=TRUE;
    if (i%5==0) {
      tmpi->type=ITEM_BONUS;
    }
    if (0<i%5<3) {
      tmpi->type=ITEM_HEALTH;
    }
    if (2<i%5<5) {
      tmpi->type=ITEM_AMMO;
    }
      
    tmpi->last_consume_time=tS;
    do {
      tmpi->x=RandU64%((map_width-2)*SCRN_SCALE)+SCRN_SCALE;
      tmpi->y=RandU64%((map_height-2)*SCRN_SCALE)+SCRN_SCALE;
    } while (DKGRAY!=map[(tmpi->y/SCRN_SCALE)*map_width+tmpi->x/SCRN_SCALE]);
  }


  man_spawn_xx=man_xx=(1+MAN_START_X)*SCRN_SCALE;
  man_spawn_yy=man_yy=(map_height-1-MAN_START_Y)*SCRN_SCALE;
  man_é=0;

  monsters_left=MONSTERS_NUM;
  tf=0;
  t0=tS;
  respawn_task=Spawn(&RespawnTask,NULL,"CF2 Monster Respawn",,Fs);
  relocate_task=Spawn(&RelocateTask,NULL,"CF2 Movement Stablizer",,Fs);

}

U0 AnimateTask(I64)
{
  I64 i,j,x,y,m,dd,dd2;
  Monster *tmpm;
  Item *tmpi;

  m=0;

  while (TRUE) {

   if (player_dead)
   {
    Sleep(4000);
   }
   else {
    j=ToI64(tS/20.0);
    dd=0.25*SCRN_SCALE*Sin(tS/2);
    dd2=0.25*SCRN_SCALE*Sin(tS);
    for (i=0,tmpm=monsters;i<MONSTERS_NUM+MAX_TANKS;i++,tmpm++)
      if (!tmpm->dead && tS-tmpm->hold_time > MONSTER_HOLD_TIME) {
        x=tmpm->x;
        y=tmpm->y;
        if (tmpm->life>1) {
          if ((i+j)&1)
	    x+=dd;
          else
	    y+=dd;
        }
        else {
          if ((i+j)&1)
	    x+=dd2;
          else
	    y+=dd2;
        }
        if (m==0 && tmpm->life>2) {
          if (man_xx-x>0)
            x+=0.25*SCRN_SCALE;
          else
            x-=0.25*SCRN_SCALE;
          if (man_yy-y>0)
            y+=0.25*SCRN_SCALE;
          else
            y-=0.25*SCRN_SCALE;

        }
        if (m%8==0 && tmpm->life<3) {
          if (man_xx-x>0)
            x-=0.25*SCRN_SCALE;
          else
            x+=0.25*SCRN_SCALE;
          if (man_yy-y>0)
            y-=0.25*SCRN_SCALE;
          else
            y+=0.25*SCRN_SCALE;

        }
        if (0<=x<=map_width*SCRN_SCALE &&
	      0<=y<=map_height*SCRN_SCALE &&
	      map[(y/SCRN_SCALE)*map_width+x/SCRN_SCALE]) {
	  if (!map[(y/SCRN_SCALE)*map_width+x/SCRN_SCALE+1] &&
	        x-RoundI64(x,SCRN_SCALE)>SCRN_SCALE/2 ||
	        !map[(y/SCRN_SCALE)*map_width+x/SCRN_SCALE-1] &&
	        x-RoundI64(x,SCRN_SCALE)<SCRN_SCALE/2)
	    x=RoundI64(x,SCRN_SCALE)+SCRN_SCALE/2;
	  if (!map[(y/SCRN_SCALE+1)*map_width+x/SCRN_SCALE] &&
	        y-RoundI64(y,SCRN_SCALE)>SCRN_SCALE/2 ||
	        !map[(y/SCRN_SCALE-1)*map_width+x/SCRN_SCALE] &&
	        y-RoundI64(y,SCRN_SCALE)<SCRN_SCALE/2)
	    y=RoundI64(y,SCRN_SCALE)+SCRN_SCALE/2;
	  tmpm->x=x;
	  tmpm->y=y;
        }
      }
    Sleep(20);
    m++;
    m%=16;
  }
 }
}

U0 CleanUp()
{
  Free(map);
  Free(panels_processed_bitmap);
  map=NULL;
  panels_processed_bitmap=NULL;
}

U0 SongTask(I64)
{//Song by Terry A. Davis
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  while (TRUE) {
    Play("3q.A#eGAeA#qAq.A#eGeAeA#qA");
    Play("3q.A#eGA#AqGq.A#eGA#AqG");
    Play("4eA#AqGeA#AqGeA#AGAA#AqG");
  }
}




U0 MoveMan(F64 é)
{
  I64 x,y,x2,y2,color,color2,step=SCRN_SCALE/2;
  do {
    x=man_xx+step*Cos(é);
    y=man_yy-step*Sin(é);
    x2=man_xx+3*step*Cos(é);
    y2=man_yy-3*step*Sin(é);
    x=Clamp(x,0,map_width*SCRN_SCALE);
    y=Clamp(y,0,map_height*SCRN_SCALE);
    x2=Clamp(x2,0,map_width*SCRN_SCALE);
    y2=Clamp(y2,0,map_height*SCRN_SCALE);
    color=map[y/SCRN_SCALE*map_width+x/SCRN_SCALE];
    color2=map[y2/SCRN_SCALE*map_width+x2/SCRN_SCALE];
    if (color==DKGRAY || color==GREEN) {
    if (color2==DKGRAY || color2==GREEN) {
      man_xx=x;
      man_yy=y;
      break;
    }
    }
    step>>=1;
    if (step<16) break;
  } while (step);
}


#define MICRO_STEPS	4

CTask *mouse_task=NULL;
CTask *game_task=Fs;
F64 mouse_scale=32.0;

U0 MouseHandler()
{
  Bool button;
  I64 x;
  while (TRUE)
  {
    button=ms_hard.raw_bttns[0];
    x=ms_hard.raw_data.x;
    if (button || x!=0)
      MsRawRst;
    if (button)
      PostMsgWait(game_task,MSG_KEY_DOWN_UP,CH_SPACE,0);
    if (x != 0) {
      man_é+=(x/mouse_scale)/MICRO_STEPS;
    }
    Sleep(10);
  }
}

U0 RotateMan(F64 d)
{
  I64 i,x;
  for (i=0;i<MICRO_STEPS;i++) {
    man_é+=d/MICRO_STEPS;
    Sleep(15);
  }
}

U0 CastleFrankenstein()
{

  I64 sc;
  MenuPush(
        "File {"
        "  Abort(,CH_SHIFT_ESC);"
        "  Exit(,CH_ESC);"
        "}"
        "Difficulty {"
        "  Normal(,'1');"
        "  HurtMe(,'2');"
        "  HurtMePlenty(,'3');"
        "  Hell(,'4');"
        "  NightmareHell(,'5');"
        "}"
        "Play {"
        "  Restart(,'\n');"
        "  Fwd(,,SC_CURSOR_UP);"
        "  Bwd(,,SC_CURSOR_DOWN);"
        "  Left(,,SC_CURSOR_LEFT);"
        "  Right(,,SC_CURSOR_RIGHT);"
        "  Fire(,CH_SPACE);"
        "  MouseMode(,'m');"
        "  ToggleMusic(,'t');"
        "}"
        );

  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  Fs->text_attr=DKGRAY<<4+WHITE;
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;

  DocClear;
  "\n\n\n";

  "Objective: Kill all tanks and zombies\n\n\n";

"\n\n    ";  DocSprite(,$IB,"<9>",BI=9$);

  "  - These are ammo to pick up\n\n";

"\n\n    ";  DocSprite(,$IB,"<10>",BI=10$);

  "  - These are health to pick up\n\n";

"\n\n    ";  DocSprite(,$IB,"<7>",BI=7$);

  "  - These are a time bonus to pick up\n\n";

  "\n\n\n";


  "Control keys:\n\n";
  "w     - Move forward\n";
  "s     - Move backward\n";
  "a     - Turn left (strafe left mouse mode)\n";
  "d     - Turn right (strafe right mouse mode)\n\n";
  "Arrows keys work simiar to above 4 keys\n\n";

  "Enter - Restart\n";
  "Space - Fire (or left mouse button in mouse mode)\n";
  "1-5   - Set difficulty level and restart\n";
  "+     - Increase mouse sensativity\n";
  "-     - Increase mouse sensativity\n";
  "m     - Toggles mouse control\n";
  "t     - Toggles music\n\n";
  "ESC   - Quit game\n";
"\n\n\n";
  "Notes: Coffins can spawn additional zombies,\n       be careful when getting close!\n";
"\n\n\n\n                                                            ";  DocSprite(,$IB,"<6>",BI=6$);



"\n\n";

  PressAKey;

  DocClear;

  Init;
  Fs->animate_task=Spawn(&AnimateTask,NULL,"CF2 Animate",,Fs);
  Fs->song_task=Spawn(&SongTask,NULL,"CF2 Song",,Fs);
  Fs->draw_it=&DrawIt;

  try {
    while (TRUE) {
      if (player_dead)
        Sleep(4000);
      else
      switch (GetKey(&sc)) {
        case 'm':
	  if (!mouse_task) {
	    MsRaw(TRUE);
	    mouse_task=Spawn(&MouseHandler,NULL,"CF2 Mouse",,Fs);
	  }
          else {
            MsRaw(FALSE);
            if (mouse_task) {
              Kill(mouse_task);
              mouse_task=NULL;
            }
          }
          break;
        case 't':
          if (Fs->song_task) {
            Kill(Fs->song_task);
            Fs->song_task=NULL;
          }
          else {
            Fs->song_task=Spawn(&SongTask,NULL,"CF2 Song",,Fs);
          }
          break;
        case 'w':
	  MoveMan(man_é);
          break;
	case 'a':
	  MoveMan(man_é-ã/2.0);
	  break;
	case 'd':
	  MoveMan(man_é+ã/2.0);
	  break;
	case 's':
	  MoveMan(man_é+ã);
	  break;
        case '1':
          difficulty=1;
          Init;
          break;
        case '2':
          difficulty=2;
          Init;
          break;
        case '3':
          difficulty=3;
          Init;
          break;
        case '4':
          difficulty=4;
          Init;
          break;
        case '5':
          difficulty=5;
          Init;
          break;
        case '+':
	  mouse_scale*=0.9;
          break;
        case '-':
	  mouse_scale*=1.1;
          break;
        case CH_SPACE:
	  Fire;
	  break;
        case '\n':
	  Init;
	  break;
        case CH_ESC:
        case CH_SHIFT_ESC:
	  goto fs_done;
        case 0:
	  switch (sc.u8[0]) {
	    case SC_CURSOR_RIGHT:
	      if (mouse_task)
	        MoveMan(man_é+ã/2.0);
	      else
	        Spawn(&RotateMan,(ã/32)(I64));
	      break;
	    case SC_CURSOR_LEFT:
	      if (mouse_task)
	        MoveMan(man_é-ã/2.0);
	      else
	        Spawn(&RotateMan,(-ã/32)(I64));
	      break;
	    case SC_CURSOR_UP:
	      MoveMan(man_é);
	      break;
	    case SC_CURSOR_DOWN:
	      MoveMan(man_é+ã);
	      break;
	  }
	  break;
      }
    }
fs_done:
  } catch
    PutExcept;
  DocClear;
  SettingsPop;
  CleanUp;
  MenuPop;
  RegWrite("TempleOS/CF2","F64 best_score=%5.4f;\n",
        best_score);
}

CastleFrankenstein;
if (mouse_task) Kill(mouse_task);
if (respawn_task) Kill(respawn_task);
if (relocate_task) Kill(relocate_task);
MsRaw(FALSE);


Free(deadman);
Free(t1);
Free(t2);
Free(r1);
Free(r2);
Free(r3);
Free(s2w);
                
             
              
       <      
<      <      
<             
,      ,   ,   
$      8      
8      8      
8      $      
$      $      
$      4      
4      4      
4      (      
(      (      
(      0      
,   0   T   0   
T   0   T   L   
T   L   ,   L   
,   L   ,   4   
0   4   P   4   
P   4   P   H   
P   H   0   H   
0   H   0   8   
0   8   L   8   
L   8   L   D   
L   D   4   D   
4   D   4   <   
4   <   H   <   
H   <   H   @   
H   @   8   @   
T   @   l   @   
l   4   l   L   
l   L   ˆ   L   
ˆ   L   ˆ   $   
ˆ   $   €   $   
€   $   €   0   
€   0   l   0   
p   4   „   4   
„   (   „   H   
€   H   p   H   
p   D   p   8   
p   8   €   8   
€   8   €   D   
€   D   t   H   
t   D   t   <   
t   <   |   <   
x   @   |   @   
|   D   x   D   
„       „      
„      t      
p      p      
p      \      
\      \      
\      l      
l      h      
l      l      
l      `      
`      `      
`      d      
d      d      
h      h      
X      T      
P      P      
P      L      
L      L      
(   @      @   
   8      H   
   H      H   
   H      8   
   8      8   
   8      D   
   D      D   
   D      <      Z   ,   u   
    @      Z   
D       D   <   
D   D   D   \   
D   \   D   d   T   0   T   8   T   H   L   0   L   L      d       d       h      h   8      8      x   8   |   8   |   4   x   4      t      t   $   t      @      8      H   L      L      ,   L   4   L   <   L   
      …   Õÿÿÿ                                                   ìÿÿÿ,   ðÿÿÿ,   ôÿÿÿ,   ìÿÿÿ0   ðÿÿÿ0   ôÿÿÿ0   ìÿÿÿ4   ðÿÿÿ4   ôÿÿÿ4   øÿÿÿ0   üÿÿÿ0       0      0      0      0      0      4   ðÿÿÿ(   ðÿÿÿ   ðÿÿÿ    ðÿÿÿ$   ðÿÿÿ   ðÿÿÿ   ôÿÿÿ   øÿÿÿ   üÿÿÿ                             $      $      $                                         ð   0   Œ   0      0   ˜   0   ”   0   œ   0       0   ¤   0   ¨   0   ¨   4   ¨   8   ¨   @   ¨   H   ¤   P   ¨   P   ¬   P   °   P   °   T   °   X   ¬   X   ¨   X   ¤   X   ¤   T   ¨   T   ¬   T   ¨   L   ¨   D   ¨   <       P       T       X       \   ¤   \   ¬   \   ¨   \   °   \   °   `   ¬   `   ¨   `   ¤   `       `       d   ¨   d   ¤   d   ¬   d   °   d   ¨   ,   ¬   (   ¨   (   ¨   $   ¨       ¨      ¨      ¨      ¤                   $   œ   $   ˜   $   ˜       ˜      ˜      œ                            œ      œ       ˜   (   œ   (       (   °       °   (   °   ,   °   0   ´   0   ¸   0   ¸   ,   ¸   (   ¸   $   ¸       ´       °   $   ´   $   ´   (   ´   ,   ¨      ¬      °      °      °      ´      ¸      ¸      ¸      ¸      ´      °      °      ´      ¸      ´      ´      ´      h   `   l   `   t   `   p   `   x   `   |   `   €   `   „   `   ˆ   `   Œ   `   ”   `      `   ˜   `   œ   `   x   \   x   X   |   X   |   \   x   d   x   h   |   h   |   d       h   ¤   h   ¨   h   ¬   h   °   h   h   X   h   `   h   d   h   h   h   l   h   l   d   l   \   l   `   l   X   l   X   d   X   h   X   `   X   X   X   \   \   X   `   X   d   X   h   \   h   T   d   T   `   T   X   P   X   T   \   T   \   \   `   \   `   \   d   \   d   `   `   `   \   `   `   d   \   d   d   d   d   h   `   h   \   h   ´   `   ¸   `   ¼   `   Ä   `   À   `   È   `   Ð   `   Ì   `   Ð   `   Ô   `   Ô   X   Ô   \   Ô   T   Ô   L   Ô   D   Ô   P   Ô   H   Ô   @   Ð   @   Ø   @   Ø   <   Ô   <   Ð   <   Ð   8   Ô   8   Ø   8   Ø   4   Ô   4   Ð   4   Ü   <   à   <   ä   <   è   <   ì   <   ð   <   ô   <   ø   <   ø   8   ø   0   ø   ,   ô   ,   ð   ,   ì   0   ì   ,   ì   (   ì   $   ð   $   ô   $   ô   (   ð   (   ô   0   ø   4   ø   (   ø   $   è   (   ä   (   à   (   Ü   (   Ü   $   Ü      Ü       Ü      Ü      Ü      Ü         T      T      T      T      T       T   üÿÿÿT      T      T   
üÿÿÿT             P      P      P      X      X      X   „   Ôÿÿÿ„   Øÿÿÿˆ   Øÿÿÿˆ   Ôÿÿÿ   T   X   P   ¨   h   Ô   4   h      øÿÿÿ   X   l   h   l   h   T   l   L   ˆ   L   €   $   ˆ   $   œ       ¸       ¸   0   ¸      ¸      ˜      ˜   (   ø   $   ì   0   °   P       P   Ü      ¼      À      Ä      È      Ì      Ð      Ø      Ô      Ð      Ð      Ð      Ð      Ô      Ø      Ü      Ü      Ø      Ô      Ð      Ô      Ø      Ø      Ô      Ô      Ø      ˆ      Œ            ”      ˜      œ             ¤      Ô      Ø      Ô      Ø      \      p      p      \      0      4      8      <      @      D   l   D   h   t   (   t   ,   t   0   t   4   t   8   t   <   x   <   |   <   |   L   |   H   |   D   „   D   €   D   Ä   P   È   P   Ì   P   Ð   P   Ø   P   Ü   P   à   P   ä   P   è   P   ì   P   ð   P   ô   P   ø   T   ø   P   ø   L   Ä   L   Ä   l   Ä   h   È   h   Ì   h   Ð   h   Ô   h   Ø   h   Ü   h   à   h   ä   h   è   h   ì   h   ð   h   ô   h   ø   l   ø   h   ü   h   À   h   À   P   ü   P   À   d   À   \   À   X   À   T   Ä   T   È   T   Ì   X   Ì   X   Ð   T   Ì   T   È   X   Ä   \   Ä   \   Ä   X   È   \   Ì   \   Ð   \   Ð   X   Ä   d   Ì   d   Ì   d   È   d   Ð   `   Ð   d   Ô   d   Ø   d   Ü   d   à   d   ä   d   ì   d   ð   d   è   d   Ø   `   Ø   \   Ø   X   Ø   T   Ü   T   Ü   X   Ü   \   Ü   `   ä   `   è   `   è   `   ð   `   ð   `   ô   d   ô   `   ô   \   ô   X   ô   T   ð   T   ì   T   ä   T   à   T   ä   T   è   T   à   \   à   T   à   X   è   X   ì   \   ì   X   ð   X   ì   `   ð   \   è   \   ä   \   ä   X   à   `   ø   d   ¼   h   ¼   P   È   L   Ì   L   Ð   L   Ø   L   Ü   L   à   L   è   L   ä   L   ì   L   ð   L   ô   L   À   L   À   H   ø   H   
À   \   Ì   \   
Ä   `   Ì   `   
Ä   P   Ü   P   
Ü   L   Ü   L   
Ð   \   ä   \   
ä   X   ä   X   
ä   T   ä   T   
è   T   è   T   
è   X   è   X   
è   \   è   \   
è   `   è   `   
ä   `   ä   `   
à   `   à   `   
Ø   `   Ø   `   
Ô   `   Ô   `   
Ð   `   Ð   `   
Ü   `   Ü   `   à   X   à   L   Ø   X   Ð   X   È   X   À   X   è   P   ì   X   ì   `   è   d   à   d   Ø   d   Ô   d   Ð   d   È   d   Ô   d   ô   X   ô   \   ô   `   ð   L   œ       p   <   p   @   p   D   t   @   t   D   p   D   p   @   p   <   p   8   p   4   p   0   €   L   €   H   ˜       ¸   (   øÿÿÿ   ü   h   Ä   l   D   l   D   h   D   d   D   \   D   `   D   X   D   T   D   P   D      D      D      D       D      D      @      D      D      D       D   $   D   (   D   ,       $      $                 d      h      t   (   t   ,   
p      p      
\      \       
\       t       
t      t      
d      h      h      \       t       t      ìÿÿÿ4   
\      t      
t       \       
x       x       
h      h      
t       t       \       x       x       l      h      h      l         T   L         T           Z     <   H   ñÿÿÿ        ñÿÿÿØÿÿÿ    ìÿÿÿØÿÿÿ    ûÿÿÿ¿ÿÿÿ       ¿ÿÿÿ       Øÿÿÿ       Øÿÿÿ    ìÿÿÿ                      ƒÿÿÿ    çÿÿÿƒÿÿÿ    ûÿÿÿƒÿÿÿ       ƒÿÿÿ    
   tÿÿÿ    öÿÿÿtÿÿÿ    
   ¿ÿÿÿ    öÿÿÿ¿ÿÿÿ       ƒÿÿÿ
   
   tÿÿÿ
      ƒÿÿÿ
   ûÿÿÿƒÿÿÿ
   çÿÿÿƒÿÿÿ
   
   ¿ÿÿÿ
      ¿ÿÿÿ
   ûÿÿÿ¿ÿÿÿ
   öÿÿÿ¿ÿÿÿ
   ìÿÿÿØÿÿÿ
   ñÿÿÿØÿÿÿ
      Øÿÿÿ
      Øÿÿÿ
      ûÿÿÿ
      ûÿÿÿ
   ñÿÿÿûÿÿÿ
   ìÿÿÿûÿÿÿ
      ƒÿÿÿ
   ìÿÿÿƒÿÿÿ
   çÿÿÿ«ÿÿÿ-   ìÿÿÿ«ÿÿÿ-      «ÿÿÿ-      «ÿÿÿ-      °ÿÿÿ-      °ÿÿÿ-   ìÿÿÿ°ÿÿÿ-   çÿÿÿ°ÿÿÿ-   øÿÿÿxÿÿÿ   ýÿÿÿ|ÿÿÿ      xÿÿÿ      xÿÿÿ      |ÿÿÿ   öÿÿÿtÿÿÿ
   ÿÿÿÿxÿÿÿ   ìÿÿÿûÿÿÿ   ñÿÿÿûÿÿÿ   ñÿÿÿ          ûÿÿÿ      ûÿÿÿ   ìÿÿÿ                                                                                                                                    	      	   
                                                                                        !            !                                                         &   '      '   "         #   %   $      $      #                                                      	                                          	                                                !                                 
                           
         
                     $   %   *      $   *   +      '   &   (      '   (   )      &   (            (   	      $   +         +   
         0   /   .         1                     1            2   -   ,      7            7      6      5   3   4      3   !          3       4      5   8   3      3   !         8   3               9      ;   :   7      ;   7   6         6   ;         ;            1                          Z     <   H   ñÿÿÿ    öÿÿÿñÿÿÿØÿÿÿ    ìÿÿÿØÿÿÿ    ûÿÿÿ¿ÿÿÿ       ¿ÿÿÿ       Øÿÿÿ       Øÿÿÿ    ìÿÿÿ    öÿÿÿ             ƒÿÿÿ    çÿÿÿƒÿÿÿ    ûÿÿÿƒÿÿÿ       ƒÿÿÿ    
   tÿÿÿ    öÿÿÿtÿÿÿ    
   ¿ÿÿÿ    öÿÿÿ¿ÿÿÿ       ƒÿÿÿ
   
   tÿÿÿ
      ƒÿÿÿ
   ûÿÿÿƒÿÿÿ
   çÿÿÿƒÿÿÿ
   
   ¿ÿÿÿ
      ¿ÿÿÿ
   ûÿÿÿ¿ÿÿÿ
   öÿÿÿ¿ÿÿÿ
   ìÿÿÿØÿÿÿ
   ñÿÿÿØÿÿÿ
      Øÿÿÿ
      Øÿÿÿ
      ûÿÿÿ      ûÿÿÿ   ñÿÿÿûÿÿÿ    ìÿÿÿûÿÿÿ       ƒÿÿÿ
   ìÿÿÿƒÿÿÿ
   çÿÿÿ«ÿÿÿ-   ìÿÿÿ«ÿÿÿ-      «ÿÿÿÓÿÿÿ   «ÿÿÿÓÿÿÿ   °ÿÿÿÓÿÿÿ   °ÿÿÿÓÿÿÿìÿÿÿ°ÿÿÿ-   çÿÿÿ°ÿÿÿ-   øÿÿÿxÿÿÿ   ýÿÿÿ|ÿÿÿ      xÿÿÿ      xÿÿÿ      |ÿÿÿ   öÿÿÿtÿÿÿ
   ÿÿÿÿxÿÿÿ   ìÿÿÿûÿÿÿ   ñÿÿÿûÿÿÿ   ñÿÿÿ          ûÿÿÿ-      ûÿÿÿ-   ìÿÿÿ                        -          -                                                                                                 	      	   
                                                                                        !            !                                                         &   '      '   "         #   %   $      $      #                                                      	                                          	                                                !                                 
                           
         
                     $   %   *      $   *   +      '   &   (      '   (   )      &   (            (   	      $   +         +   
         0   /   .         1                     1            2   -   ,      7            7      6      5   3   4      3   !          3       4      5   8   3      3   !         8   3               9      ;   :   7      ;   7   6         6   ;         ;            1                          Z     <   H   ñÿÿÿ       ñÿÿÿØÿÿÿ    ìÿÿÿØÿÿÿ    ûÿÿÿ¿ÿÿÿ       ¿ÿÿÿ       Øÿÿÿ       Øÿÿÿ    ìÿÿÿ              öÿÿÿ   ƒÿÿÿ    çÿÿÿƒÿÿÿ    ûÿÿÿƒÿÿÿ       ƒÿÿÿ    
   tÿÿÿ    öÿÿÿtÿÿÿ    
   ¿ÿÿÿ    öÿÿÿ¿ÿÿÿ       ƒÿÿÿ
   
   tÿÿÿ
      ƒÿÿÿ
   ûÿÿÿƒÿÿÿ
   çÿÿÿƒÿÿÿ
   
   ¿ÿÿÿ
      ¿ÿÿÿ
   ûÿÿÿ¿ÿÿÿ
   öÿÿÿ¿ÿÿÿ
   ìÿÿÿØÿÿÿ
   ñÿÿÿØÿÿÿ
      Øÿÿÿ
      Øÿÿÿ
      ûÿÿÿ       ûÿÿÿ    ñÿÿÿûÿÿÿ   ìÿÿÿûÿÿÿ      ƒÿÿÿ
   ìÿÿÿƒÿÿÿ
   çÿÿÿ«ÿÿÿÓÿÿÿìÿÿÿ«ÿÿÿÓÿÿÿ   «ÿÿÿ-      «ÿÿÿ-      °ÿÿÿ-      °ÿÿÿ-   ìÿÿÿ°ÿÿÿÓÿÿÿçÿÿÿ°ÿÿÿÓÿÿÿøÿÿÿxÿÿÿ   ýÿÿÿ|ÿÿÿ      xÿÿÿ      xÿÿÿ      |ÿÿÿ   öÿÿÿtÿÿÿ
   ÿÿÿÿxÿÿÿ   ìÿÿÿûÿÿÿ#   ñÿÿÿûÿÿÿ#   ñÿÿÿ    #      ûÿÿÿ      ûÿÿÿ   ìÿÿÿ    #          öÿÿÿ                                                                                                                  	      	   
                                                                                        !            !                                                         &   '      '   "         #   %   $      $      #                                                      	                                          	                                                !                                 
                           
         
                     $   %   *      $   *   +      '   &   (      '   (   )      &   (            (   	      $   +         +   
         0   /   .         1                     1            2   -   ,      7            7      6      5   3   4      3   !          3       4      5   8   3      3   !         8   3               9      ;   :   7      ;   7   6         6   ;         ;            1                                  ,      Îÿÿÿ      Îÿÿÿûÿÿÿ   çÿÿÿûÿÿÿ   çÿÿÿ      µÿÿÿ      ÿÿÿ       ƒÿÿÿ       ÿÿÿâÿÿÿ   µÿÿÿâÿÿÿûÿÿÿÎÿÿÿ   ûÿÿÿÎÿÿÿûÿÿÿûÿÿÿçÿÿÿûÿÿÿûÿÿÿçÿÿÿ   ûÿÿÿµÿÿÿ   ûÿÿÿÿÿÿ   ûÿÿÿÿÿÿâÿÿÿûÿÿÿµÿÿÿâÿÿÿ   ÿÿÿ      µÿÿÿ   âÿÿÿµÿÿÿ   âÿÿÿÿÿÿ      ÿÿÿûÿÿÿ   µÿÿÿûÿÿÿâÿÿÿµÿÿÿûÿÿÿâÿÿÿÿÿÿûÿÿÿ                             	               
   	      
            
            	                   	                                                                                                                                                      	            	             	   
               	                               
               
         	            
                                                                                                                                                                                        ÷ÿÿÿ    ÷ÿÿÿñÿÿÿ        ÷ÿÿÿ    	                      ôÿÿÿ	       ÷ÿÿÿ	       	              øÿÿÿçÿÿÿ   ìÿÿÿçÿÿÿ   ìÿÿÿçÿÿÿøÿÿÿøÿÿÿçÿÿÿðÿÿÿ   çÿÿÿðÿÿÿ   çÿÿÿøÿÿÿ   çÿÿÿ      çÿÿÿ                                                                         	      	            	            	            	            	   
               	                  	            	      
             
      
                                                                                                                                                                   (   Øÿÿÿ   (          Øÿÿÿ       ØÿÿÿØÿÿÿ   ìÿÿÿÎÿÿÿ       Îÿÿÿ       ìÿÿÿ‚          ‚   ìÿÿÿ    ‚   ìÿÿÿìÿÿÿ‚   öÿÿÿâÿÿÿ‚   
   âÿÿÿ‚              ìÿÿÿ                             
      
            
      	                        
         
   	         	            	                                                                                                                                                                   Î
     ;   €           öÿÿÿ   ýÿÿÿ÷ÿÿÿ   ÿÿÿÿ÷ÿÿÿ      ÷ÿÿÿ      ÷ÿÿÿÿÿÿÿ   ÷ÿÿÿýÿÿÿ   ÷ÿÿÿýÿÿÿÿÿÿÿ÷ÿÿÿÿÿÿÿýÿÿÿ÷ÿÿÿ   üÿÿÿùÿÿÿ       ùÿÿÿ      ùÿÿÿ       ùÿÿÿüÿÿÿ   ùÿÿÿùÿÿÿ    ùÿÿÿûÿÿÿüÿÿÿùÿÿÿ    ùÿÿÿùÿÿÿ   ûÿÿÿùÿÿÿ   ýÿÿÿýÿÿÿ      ýÿÿÿ      ýÿÿÿýÿÿÿ   ýÿÿÿøÿÿÿ   ýÿÿÿøÿÿÿýÿÿÿýÿÿÿýÿÿÿøÿÿÿýÿÿÿ   øÿÿÿýÿÿÿ
                         
       ùÿÿÿ       öÿÿÿ        ùÿÿÿùÿÿÿ        öÿÿÿ       ùÿÿÿ                      ýÿÿÿ      øÿÿÿ      øÿÿÿýÿÿÿ   ýÿÿÿøÿÿÿ      øÿÿÿ      ýÿÿÿ                      üÿÿÿ      ùÿÿÿ       ûÿÿÿüÿÿÿ       ùÿÿÿ      ûÿÿÿ                   	   ÿÿÿÿ   	   ýÿÿÿ   	   ýÿÿÿÿÿÿÿ	   ÿÿÿÿýÿÿÿ	      ýÿÿÿ	      ÿÿÿÿ	         	           
                                                                                                                                                                                                                                    	      	      
            
      
                                                                                                                                                            	   
            
         
                                                                                                                                                                                                                                                                                                                                             !            !      !                  "      "      #            #      #      $            $      $      %            %      %      &            &      &      '             '      '       (          !   (      (   !   )      !      )      )      "      "   #   *      *   #   +      #   $   +      +   $   ,      $   %   ,      ,   %   -      %   &   -      -   &   .      &   '   .      .   '   /      '   (   /      /   (   0      (   )   0      0   )   1      )   "   1      1   "   *      *   +   2      2   +   3      +   ,   3      3   ,   4      ,   -   4      4   -   5      -   .   5      5   .   6      .   /   6      6   /   7      /   0   7      7   0   8      0   1   8      8   1   9      1   *   9      9   *   2      2   3   :      :   3   :      3   4   :      :   4   :      4   5   :      :   5   :      5   6   :      :   6   :      6   7   :      :   7   :      7   8   :      :   8   :      8   9   :      :   9   :      9   2   :      :   2   :           ²     6   R   F   Øÿÿÿ#   ºÿÿÿØÿÿÿ#   ºÿÿÿ(   #   F   (   #   d   ìÿÿÿ#   d      #   œÿÿÿ   #   œÿÿÿìÿÿÿ#   F   Øÿÿÿ2   ºÿÿÿØÿÿÿ2   œÿÿÿìÿÿÿ2   œÿÿÿ   2   ºÿÿÿ(   2   F   (   2   d      2   d   ìÿÿÿ2   P   
   #   P   ìÿÿÿ#      ºÿÿÿ#   Øÿÿÿºÿÿÿ#   Éÿÿÿìÿÿÿ#   A      #   F   ØÿÿÿÝÿÿÿºÿÿÿØÿÿÿÝÿÿÿºÿÿÿ(   ÝÿÿÿF   (   Ýÿÿÿd      Ýÿÿÿœÿÿÿ   ÝÿÿÿœÿÿÿìÿÿÿÝÿÿÿF   ØÿÿÿÎÿÿÿºÿÿÿØÿÿÿÎÿÿÿœÿÿÿìÿÿÿÎÿÿÿœÿÿÿ   Îÿÿÿºÿÿÿ(   ÎÿÿÿF   (   Îÿÿÿd      Îÿÿÿd   ìÿÿÿÎÿÿÿP   
   ÝÿÿÿP   ìÿÿÿÝÿÿÿ   ºÿÿÿÝÿÿÿØÿÿÿºÿÿÿÝÿÿÿÉÿÿÿìÿÿÿÝÿÿÿÉÿÿÿ   ÝÿÿÿA      ÝÿÿÿÉÿÿÿ   #   d   ìÿÿÿÝÿÿÿ   Îÿÿÿûÿÿÿ   Îÿÿÿ      Øÿÿÿ      Øÿÿÿûÿÿÿ–   Îÿÿÿûÿÿÿ–   Îÿÿÿ   –   Øÿÿÿ   –   Øÿÿÿûÿÿÿ                                                                                                      	            	   
            	                                                                                                                         
                        
            	   
                                     	          	                                                         $   "         $   #   "         !                          !            "   !      #   "         $   #            !                !                                                           "   !            "                                 %   +         +            &   %         %            '   &         &            (   '         '         (            (      )      )      ,      )   ,   *      *   ,         *      +                              -   $            $   -            $      '   (   )      '   )   &       3   /   .       .   2   3       2   .   1       1   5   2       3   4   0       0   /   3       4   5   1       1   0   4                        -            "    	       Ò                
       
               öÿÿÿ    öÿÿÿ                öÿÿÿ        
                                                                                                        
       *           
   öÿÿÿöÿÿÿ
   
   öÿÿÿöÿÿÿöÿÿÿöÿÿÿöÿÿÿ
   öÿÿÿ
   öÿÿÿ
   
   
   
   öÿÿÿöÿÿÿ
   öÿÿÿ
   
                                                                                                                                                                Ê     p   ¨      ­ÿÿÿûÿÿÿûÿÿÿ­ÿÿÿûÿÿÿ   ·ÿÿÿûÿÿÿûÿÿÿ·ÿÿÿûÿÿÿ   ­ÿÿÿ   ûÿÿÿ­ÿÿÿ      ·ÿÿÿ   ûÿÿÿ·ÿÿÿ   
   ·ÿÿÿûÿÿÿöÿÿÿ·ÿÿÿûÿÿÿ
   ÚÿÿÿûÿÿÿöÿÿÿÚÿÿÿûÿÿÿ
   ·ÿÿÿ   öÿÿÿ·ÿÿÿ   
   Úÿÿÿ   öÿÿÿÚÿÿÿ      ¾ÿÿÿýÿÿÿ   ¾ÿÿÿÿÿÿÿ   ¾ÿÿÿ      ¾ÿÿÿ      ¸ÿÿÿýÿÿÿ   ¸ÿÿÿÿÿÿÿ   ¸ÿÿÿ      ¸ÿÿÿ      ¾ÿÿÿ      ¾ÿÿÿ      ·ÿÿÿ      ·ÿÿÿ      ¸ÿÿÿ      ¸ÿÿÿ      ±ÿÿÿ      ±ÿÿÿ      ¶ÿÿÿ      ¶ÿÿÿ      ³ÿÿÿ#      ³ÿÿÿ%      ²ÿÿÿ      ²ÿÿÿ      ¯ÿÿÿ!      ¯ÿÿÿ#   öÿÿÿ¾ÿÿÿþÿÿÿòÿÿÿ¾ÿÿÿþÿÿÿóÿÿÿ¾ÿÿÿ   ïÿÿÿ¾ÿÿÿ   öÿÿÿ¸ÿÿÿþÿÿÿòÿÿÿ¸ÿÿÿþÿÿÿóÿÿÿ¸ÿÿÿ   ïÿÿÿ¸ÿÿÿ   óÿÿÿ¾ÿÿÿ   ïÿÿÿ¾ÿÿÿ   ñÿÿÿ¾ÿÿÿ   íÿÿÿ¾ÿÿÿ   óÿÿÿ¸ÿÿÿ   ïÿÿÿ¸ÿÿÿ   ñÿÿÿ¸ÿÿÿ   íÿÿÿ¸ÿÿÿ   ñÿÿÿ½ÿÿÿ   íÿÿÿ½ÿÿÿ   ðÿÿÿ½ÿÿÿ&   ìÿÿÿ½ÿÿÿ&   ñÿÿÿ¹ÿÿÿ   íÿÿÿ¹ÿÿÿ   ðÿÿÿ¹ÿÿÿ&   ìÿÿÿ¹ÿÿÿ&   	   Úÿÿÿüÿÿÿ   Úÿÿÿüÿÿÿ   êÿÿÿüÿÿÿ   êÿÿÿüÿÿÿ	   Úÿÿÿ      Úÿÿÿ      êÿÿÿ      êÿÿÿ      êÿÿÿüÿÿÿ   êÿÿÿüÿÿÿ   úÿÿÿüÿÿÿ   úÿÿÿüÿÿÿ   êÿÿÿ      êÿÿÿ      úÿÿÿ      úÿÿÿ      ÿÿÿÿýÿÿÿ   ÿÿÿÿýÿÿÿ   ÿÿÿÿ   ÿÿÿÿÿÿÿÿ      ùÿÿÿýÿÿÿ   ùÿÿÿýÿÿÿ   ùÿÿÿ   ÿÿÿÿùÿÿÿ   ýÿÿÿÙÿÿÿüÿÿÿ÷ÿÿÿÛÿÿÿüÿÿÿÿÿÿÿéÿÿÿüÿÿÿùÿÿÿëÿÿÿüÿÿÿýÿÿÿÙÿÿÿ   ÷ÿÿÿÛÿÿÿ   ÿÿÿÿéÿÿÿ   ùÿÿÿëÿÿÿ   ÿÿÿÿçÿÿÿýÿÿÿùÿÿÿéÿÿÿýÿÿÿ   õÿÿÿöÿÿÿûÿÿÿ÷ÿÿÿöÿÿÿÿÿÿÿëÿÿÿ   ùÿÿÿíÿÿÿ      ùÿÿÿüÿÿÿûÿÿÿûÿÿÿüÿÿÿ   ûÿÿÿòÿÿÿûÿÿÿýÿÿÿôÿÿÿ          ýÿÿÿ         õÿÿÿôÿÿÿûÿÿÿ÷ÿÿÿöÿÿÿ   üÿÿÿ   ýÿÿÿþÿÿÿ   0            0           0           0           0            0           0           0           0            0           0           0           0  	      
   0  
      	   0           0           0  	         0        	   0     
      0           0  
         0        
   0     	      0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0  !       "   0  "   #   !   0  %   $   &   0  &   '   %   0  !       $   0  $   %   !   0  #   "   &   0  &   '   #   0  "       $   0  $   &   "   0  #   !   %   0  %   '   #   0  )   (   *   0  *   +   )   0  -   ,   .   0  .   /   -   0  )   (   ,   0  ,   -   )   0  +   *   .   0  .   /   +   0  *   (   ,   0  ,   .   *   0  +   )   -   0  -   /   +   0  1   0   2   0  2   3   1   0  5   4   6   0  6   7   5   0  1   0   4   0  4   5   1   0  3   2   6   0  6   7   3   0  2   0   4   0  4   6   2   0  3   1   5   0  5   7   3   0  9   8   :   0  :   ;   9   0  =   <   >   0  >   ?   =   0  9   8   <   0  <   =   9   0  ;   :   >   0  >   ?   ;   0  :   8   <   0  <   >   :   0  ;   9   =   0  =   ?   ;   0  A   @   B   0  B   C   A   0  E   D   F   0  F   G   E   0  A   @   D   0  D   E   A   0  C   B   F   0  F   G   C   0  B   @   D   0  D   F   B   0  C   A   E   0  E   G   C   0  I   H   J   0  J   K   I   0  M   L   N   0  N   O   M   0  I   H   L   0  L   M   I   0  K   J   N   0  N   O   K   0  J   H   L   0  L   N   J   0  K   I   M   0  M   O   K   0  Q   P   R   0  R   S   Q   0  U   T   V   0  V   W   U   0  Q   P   T   0  T   U   Q   0  S   R   V   0  V   W   S   0  R   P   T   0  T   V   R   0  S   Q   U   0  U   W   S   0  Y   X   Z   0  Z   [   Y   0  ]   \   ^   0  ^   _   ]   0  Y   X   \   0  \   ]   Y   0  [   Z   ^   0  ^   _   [   0  Z   X   \   0  \   ^   Z   0  [   Y   ]   0  ]   _   [   0  a   `   b   0  b   c   a   0  e   d   f   0  f   g   e   0  a   `   d   0  d   e   a   0  c   b   f   0  f   g   c   0  b   `   d   0  d   f   b   0  c   a   e   0  e   g   c   0  i   h   j   0  j   k   i   0  m   l   n   0  n   o   m   0  i   h   l   0  l   m   i   0  k   j   n   0  n   o   k   0  j   h   l   0  l   n   j   0  k   i   m   0  m   o   k    