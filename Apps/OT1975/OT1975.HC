//  Original version by:
//
//  MINNESOTA EDUCATIONAL COMPUTING CONSORTIUM STAFF
//  PROGRAMMING REVISIONS BY DON RAWITSCH - 1975
//  CURRENT VERSION - 3/27/75
//
//  RIP Terry Davis who also travelled to
//  Oregon, but did not survive the journey.

I64 i, A, AMMO, B1, C, C1, EVNT, D1, D3, D4, EAT, FOOD, F1, F2, F9, K8, L1, M, M1, M2, M9, P, R1, S4, S5, T, T1, TF, X, X1, RBANG;
U8 inputdata[15]= {6,11,13,15,17,22,32,35,37,42,44,54,64,69,95};
U0 FUNC1520()
{
  P=GetI64("",0,0,900);
  T = T - P;
  if (T >= 0)
    return;
  "YOU DON'T HAVE THAT MUCH--KEEP YOUR SPENDING DOWN\n";
  T = T + P;
  P = 0;
  return;
}
U0 FUNC4500()
{
  RBANG = Rand;
  "\n";
  if (RBANG > 0.2)
    goto LINE4535;
  B1 = Round(6*Rand)+1;
LINE4535:
  return;
}
U0 OT1975()
{
  Bool old_ac;
  U8 tmp;
  CFifoU8 *data=FifoU8New(16);
  WinMax;
  if (TaskValidate(ac.task)) {
    old_ac=AutoComplete(0);
  }
  LINE0:
  "\nDO YOU NEED INSTRUCTIONS ";
  if (!YorN)
    goto LINE400;
  // ***INSTRUCTIONS***
  "THIS PROGRAM SIMULATES A TRIP OVER THE OREGON TRAIL FROM\n";
  "INDEPENDENCE, MISSOURI TO OREGON CITY, OREGON IN 1847.\n";
  "YOUR FAMILY OF FIVE WILL COVER THE 2000 MILE OREGON TRAIL\n";
  "IN 5-6 MONTHS --- IF YOU MAKE IT ALIVE.\n";
  "\n";
  "YOU HAD SAVED 900 DOLLARS TO SPEND FOR THE TRIP, AND YOU'VE JUST\n";
  "   PAID 200 DOLLARS FOR A WAGON.\n";
  "YOU WILL NEED TO SPEND THE REST OF YOUR MONEY ON THE\n";
  "   FOLLOWING ITEMS:\n";
  "\n";
  "     OXEN - YOU CAN SPEND 200-300 DOLLARS ON YOUR TEAM\n";
  "            THE MORE YOU SPEND, THE FASTER YOU'LL GO\n";
  "               BECAUSE YOU'LL HAVE BETTER ANIMALS\n";
  "\n";
  "     FOOD - THE MORE YOU HAVE, THE LESS CHANCE THERE\n";
  "               IS OF GETTING SICK\n";
  "\n";
  "     AMMUNITION - 1 DOLLAR BUYS A BELT OF 50 BULLETS\n";
  "            YOU WILL NEED BULLETS FOR ATTACKS BY ANIMALS\n";
  "               AND BANDITS, AND FOR HUNTING FOOD\n";
  "\n";
  "     CLOTHING - THIS IS ESPECIALLY IMPORTANT FOR THE COLD\n";
  "               WEATHER YOU WILL ENCOUNTER WHEN CROSSING\n";
  "               THE MOUNTAINS\n";
  "\n";
  "     MISCELLANEOUS SUPPLIES - THIS INCLUDES MEDICINE AND\n";
  "               OTHER THINGS YOU WILL NEED FOR SICKNESS\n";
  "               AND EMERGENCY REPAIRS\n";
  "\n";
  "YOU CAN SPEND ALL YOUR MONEY BEFORE YOU START YOUR TRIP -\n";
  "OR YOU CAN SAVE SOME OF YOUR CASH TO SPEND AT FORTS ALONG\n";
  "THE WAY WHEN YOU RUN LOW.  HOWEVER, ITEMS COST MORE AT\n";
  "THE FORTS.  YOU CAN ALSO GO HUNTING ALONG THE WAY TO GET\n";
  "MORE FOOD.\n";
  "\n";
  "WHEN ASKED TO ENTER MONEY AMOUNTS, DON'T USE A DOLLAR SIGN.\n";
  "\n";
  "GOOD LUCK!!!\n";
  "\n";
  // ***INITIAL PURCHASES***
LINE400:
  X1 = -1;
  K8 = S4 = F1 = F2 = M = M9 = D3 = TF = 0;
LINE410:
 ;
LINE415:
  "HOW MUCH DO YOU WANT TO SPEND ON YOUR OXEN TEAM";
  A=GetI64(": ",0,0,900);
  if (A >= 200)
    goto LINE440;
  "NOT ENOUGH\n";
  goto LINE415;
LINE440:
  if (A <= 300)
    goto LINE455;
  "TOO MUCH\n";
  goto LINE415;
LINE455:
  "HOW MUCH DO YOU WANT TO SPEND ON FOOD";
  FOOD=GetI64(": ",0,0,900);
  if (FOOD >= 0)
    goto LINE485;
  "IMPOSSIBLE\n";
  goto LINE455;
LINE485:
  "HOW MUCH DO YOU WANT TO SPEND ON AMMUNITION";
  AMMO=GetI64(": ",0,0,900);
  if (AMMO >= 0)
    goto LINE510;
  "IMPOSSIBLE\n";
  goto LINE485;
LINE510:
  "HOW MUCH DO YOU WANT TO SPEND ON CLOTHING";
  C=GetI64(": ",0,0,900);
  if (C >= 0)
    goto LINE535;
  "IMPOSSIBLE\n";
  goto LINE510;
LINE535:
  "HOW MUCH DO YOU WANT TO SPEND ON MISCELANEOUS SUPPLIES";
  M1=GetI64(": ",0,0,9000);
  if (M1 >= 0)
    goto LINE560;
  "IMPOSSIBLE\n";
  goto LINE535;
LINE560:
  T = 700 - A - FOOD - AMMO - C - M1;
  if (T >= 0)
    goto LINE580;
  "YOU OVERSPENT--YOU ONLY HAD 700 DOLLARS TO SPEND.  BUY AGAIN\n";
  goto LINE410;
LINE580:
  AMMO = 50 * AMMO;
  "\nAFTER ALL YOUR PURCHASES, YOU NOW HAVE %d DOLLARS LEFT\n", T;
  "\n";
  "MONDAY MARCH 29 1847\n";
  "\n";
  goto LINE1000;
LINE700:
  if (M >= 2040 || D3 > 17)
    goto LINE4000;
  // ***SETTING DATE***
  D3 = D3 + 1;
  "\n";
  "MONDAY ";
  if (D3 > 10)
    goto LINE735;
  switch(D3)
  {
  case 1:
    goto LINE740;
  case 2:
    goto LINE750;
  case 3:
    goto LINE760;
  case 4:
    goto LINE770;
  case 5:
    goto LINE780;
  case 6:
    goto LINE790;
  case 7:
    goto LINE800;
  case 8:
    goto LINE810;
  case 9:
    goto LINE820;
  case 10:
    goto LINE830;
  }
LINE735:
  switch(D3 - 10)
  {
  case 1:
    goto LINE840;
  case 2:
    goto LINE850;
  case 3:
    goto LINE860;
  case 4:
    goto LINE870;
  case 5:
    goto LINE880;
  case 6:
    goto LINE890;
  case 7:
    goto LINE900;
  }
LINE740:
  "APRIL 12 ";
  goto LINE910;
LINE750:
  "APRIL 26 ";
  goto LINE910;
LINE760:
  "MAY 10 ";
  goto LINE910;
LINE770:
  "MAY 24 ";
  goto LINE910;
LINE780:
  "JUNE 7 ";
  goto LINE910;
LINE790:
  "JUNE 21 ";
  goto LINE910;
LINE800:
  "JULY 5 ";
  goto LINE910;
LINE810:
  "JULY 19 ";
  goto LINE910;
LINE820:
  "AUGUST 2 ";
  goto LINE910;
LINE830:
  "AUGUST 16 ";
  goto LINE910;
LINE840:
  "AUGUST 31 ";
  goto LINE910;
LINE850:
  "SEPTEMBER 13 ";
  goto LINE910;
LINE860:
  "SEPTEMBER 27 ";
  goto LINE910;
LINE870:
  "OCTOBER 11 ";
  goto LINE910;
LINE880:
  "OCTOBER 25 ";
  goto LINE910;
LINE890:
  "NOVEMBER 8 ";
  goto LINE910;
LINE900:
  "NOVEMBER 22 ";
LINE910:
  "1847\n";
  "\n";
  // ***BEGINNING EACH TURN***
LINE1000:
  if (FOOD >= 0)
    goto LINE1015;
  FOOD = 0;
LINE1015:
  if (AMMO >= 0)
    goto LINE1025;
  AMMO = 0;
LINE1025:
  if (C >= 0)
    goto LINE1035;
  C = 0;
LINE1035:
  if (M1 >= 0)
    goto LINE1045;
  M1 = 0;
LINE1045:
  if (FOOD >= 12)
    goto LINE1055;
  "YOU'D BETTER DO SOME HUNTING OR BUY FOOD AND SOON!!!!\n";
LINE1055:
  FOOD = Round(FOOD);
  AMMO = Round(AMMO);
  C = Round(C);
  M1 = Round(M1);
  T = Round(T);
  M = Round(M);
  M2 = M;
  if (S4 == 1)
    goto LINE1105;
  if (K8 == 1)
    goto LINE1105;
  goto LINE1130;
LINE1105:
  T = T - 20;
  if (T < 0)
    goto LINE3520;
  "DOCTOR'S BILL IS 20 DOLLARS\n";
  K8 = S4 = 0;
LINE1130:
  if (M9 == 1)
    goto LINE1145;
  "MILEAGE %d ",M;
  goto LINE1160;
LINE1145:
  "TOTAL MILEAGE IS 950\n";
  M9 = 0;
LINE1160:
  FOOD = ClampU64(Round(FOOD),0,10000);
  AMMO = ClampU64(Round(AMMO),0,10000);
  C = ClampU64(Round(C),0,10000);
  M1 = ClampU64(Round(M1),0,10000);
  T = ClampU64(Round(T),0,10000);
  "FOOD %d BULLETS %d CLOTHING %d MISC. SUPP. %d CASH %d\n\n",FOOD, AMMO, C, M1, T;
  if (X1 == -1)
    goto LINE1350;
  X1 = X1 * -1;
LINE1310:
  "DO YOU WANT TO (1) STOP AT THE NEXT FORT, (2) HUNT, ";
  "OR (3) CONTINUE: ";
  X=GetI64("",1,1,3);
  if (X > 2)
    goto LINE1340;
  if (X < 1)
    goto LINE1340;
  X = Round(X);
  goto LINE1400;
LINE1340:
  X = 3;
  goto LINE1400;
LINE1350:
  X=GetI64("DO YOU WANT TO (1) HUNT, OR (2) CONTINUE: ",1,1,2);
  if (X == 1)
    goto LINE1370;
  X = 2;
LINE1370:
  X = X + 1;
  if (X == 3)
    goto LINE1395;
  if (AMMO > 39)
    goto LINE1395;
  "TOUGH---YOU NEED MORE BULLETS TO GO HUNTING\n";
  goto LINE1350;
LINE1395:
  X1 = X1 * -1;
LINE1400:
  switch(X)
  {
  case 1:
    goto LINE1500;
  case 2:
    goto LINE1700;
  case 3:
    goto LINE1800;
  }
  // ***STOPPING AT FORT***
LINE1500:
  "ENTER WHAT YOU WISH TO SPEND ON THE FOLLOWING\n";
  "FOOD: ";
  FUNC1520;
  goto LINE1555;
LINE1555:
  FOOD = FOOD + 2 * P / 3;
  "AMMUNITION: ";
  FUNC1520;
  AMMO = Round(AMMO + 100 * P / 3);
  "CLOTHING: ";
  FUNC1520;
  C = C + 2 * P / 3;
  "MISCELLANEOUS SUPPLIES: ";
  FUNC1520;
  M1 = M1 + 2 * P / 3;
  M = M - 45;
  goto LINE1800;
  // ***HUNTING***
LINE1700:
  if (AMMO > 39)
    goto LINE1715;
  "TOUGH---YOU NEED MORE BULLETS TO GO HUNTING\n\n";
  goto LINE1310;
LINE1715:
  M = M - 45;
  FUNC4500;
  if (B1 <= 1)
    goto LINE1755;
  if (B1 >= 6 || 100 * Rand < 13 * B1)
    goto LINE1780;
  FOOD = FOOD + 48 - 2 * B1;
  "NICE SHOT--RIGHT THROUGH THE NECK--FEAST TONIGHT!!\n\n";
  AMMO = AMMO - 10 - 3 * B1;
  goto LINE1800;
LINE1755:
  "RIGHT BETWEEN THE EYES---YOU GOT A BIG ONE!!!!\n\n";
  FOOD = FOOD + 52 + Rand * 6;
  AMMO = AMMO - 10 - Rand * 4;
  goto LINE1800;
LINE1780:
  "SORRY---NO LUCK TODAY\n\n";
LINE1800:
  if (FOOD >= 13)
    goto LINE1900;
  goto LINE3500;
  // ***EATING***
LINE1900:
  "DO YOU WANT TO EAT (1) POORLY (2) MODERATELY OR (3) WELL";
  EAT=GetI64(": ",1,1,3);
  "\n";
  if (EAT > 3)
    goto LINE1900;
  if (EAT < 1)
    goto LINE1900;
  EAT = Round(EAT);
  FOOD = FOOD - 8 - 5 * EAT;
  if (FOOD >= 0)
    goto LINE2000;
  FOOD = FOOD + 8 + 5 * EAT;
  "YOU CAN'T EAT THAT WELL\n";
  goto LINE1900;
LINE2000:
  M = M + 200 + (A - 220) / 5 + 10 * Rand;
  L1 = C1 = 0;
  // ***RIDERS ATTACK***
  if (Rand * 10 > (Pow(M / 100 - 4, 2) + 72) / (Pow(M / 100 - 4, 2) + 12) - 1)
    goto LINE2500;
  "RIDERS AHEAD.  THEY ";
  S5 = 0;
  if (Rand < .8)
    goto LINE2130;
  "DON'T ";
  S5 = 1;
LINE2130:
  "LOOK HOSTILE\n\n";
  "TACTICS:\n";
LINE2140:
  "(1) RUN  (2) ATTACK  (3) CONTINUE  (4) CIRCLE WAGONS\n";
  "IF YOU RUN YOU'LL GAIN TIME BUT WEAR DOWN YOUR OXEN\n";
  "IF YOU CIRCLE YOU'LL LOSE TIME: ";
  if (Rand > .2)
    goto LINE2165;
  S5 = 1 - S5;
LINE2165:
  T1=GetI64("",1,1,4);
  if (T1 < 1)
    goto LINE2140;
  if (T1 > 4)
    goto LINE2140;
  T1 = Round(T1);
  if (S5 == 1)
    goto LINE2330;
  if (T1 > 1)
    goto LINE2220;
  M = M + 20;
  M1 = M1 - 15;
  AMMO = AMMO - 150;
  A = A - 40;
  goto LINE2395;
LINE2220:
  if (T1 > 2)
    goto LINE2285;
  FUNC4500;
  AMMO = AMMO - B1 * 40 - 80;
LINE2235:
  if (B1 > 1)
    goto LINE2250;
  "NICE SHOOTING---YOU DROVE THEM OFF\n";
  goto LINE2395;
LINE2250:
  if (B1 <= 4)
    goto LINE2275;
  "LOUSY SHOT---YOU GOT KNIFED\n";
  K8 = 1;
  "YOU HAVE TO SEE OL' DOC BLANCHARD\n";
  goto LINE2395;
LINE2275:
  "KINDA SLOW WITH YOUR COLT .45\n";
  goto LINE2395;
LINE2285:
  if (T1 > 3)
    goto LINE2310;
  if (Rand > .8)
    goto LINE2390;
  AMMO = AMMO - 150;
  M1 = M1 - 15;
  goto LINE2395;
LINE2310:
  FUNC4500;
  AMMO = AMMO - B1 * 30 - 80;
  M = M - 25;
  goto LINE2235;
LINE2330:
  if (T1 > 1)
    goto LINE2350;
  M = M + 15;
  A = A - 10;
  goto LINE2395;
LINE2350:
  if (T1 > 2)
    goto LINE2370;
  M = M - 5;
  AMMO = AMMO - 100;
  goto LINE2395;
LINE2370:
  if (T1 > 3)
    goto LINE2380;
  goto LINE2395;
LINE2380:
  M = M - 20;
  goto LINE2395;
LINE2390:
  "THEY DID NOT ATTACK\n";
  goto LINE2500;
LINE2395:
  if (S5 == 0)
    goto LINE2410;
  "RIDERS WERE FRIENDLY, BUT CHECK FOR POSSIBLE LOSSES\n";
  goto LINE2500;
LINE2410:
  "RIDERS WERE HOSTILE--CHECK FOR LOSSES\n";
  if (AMMO >= 0)
    goto LINE2500;
  "YOU RAN OUT OF BULLETS AND GOT MASSACRED BY THE RIDERS\n";
  goto LINE3600;
  // ***SELECTION OF EVENTS***
LINE2500:
  D1 = 0;
  FifoU8Flush(data);
  for (i=0; i<15; i++)
    FifoU8Ins(data,inputdata[i]);
  "\n";
  R1 = 100 * Rand;
LINE2515:
  D1 = D1 + 1;
  if (D1 == 16)
    goto LINE3020;
  FifoU8Rem(data,&tmp);
  EVNT = tmp;
  if (R1 > EVNT)
    goto LINE2515;
  if (D1 > 10)
    goto LINE2545;
  switch(D1)
  {
  case 1:
    goto LINE2550;
  case 2:
    goto LINE2570;
  case 3:
    goto LINE2590;
  case 4:
    goto LINE2615;
  case 5:
    goto LINE2630;
  case 6:
    goto LINE2645;
  case 7:
    goto LINE2660;
  case 8:
    goto LINE2690;
  case 9:
    goto LINE2785;
  case 10:
    goto LINE2810;
  }
LINE2545:
  switch(D1 - 10)
  {
  case 1:
    goto LINE2825;
  case 2:
    goto LINE2860;
  case 3:
    goto LINE2885;
  case 4:
    goto LINE2970;
  case 5:
    goto LINE2990;
  case 6:
    goto LINE3020;
  };
LINE2550:
  "WAGON BREAKS DOWN--LOSE TIME AND SUPPLIES FIXING IT\n";
  M = M - 15 - 5 * Rand;
  M1 = M1 - 8;
  goto LINE3100;
LINE2570:
  "OX INJURES LEG---SLOWS YOU DOWN REST OF TRIP\n";
  M = M - 25;
  A = A - 20;
  goto LINE3100;
LINE2590:
  "BAD LUCK---YOUR DAUGHTER BROKE HER ARM\n";
  "YOU HAD TO STOP AND USE SUPPLIES TO MAKE A SLING\n";
  M = M - 5 - 4 * Rand;
  M1 = M1 - 2 - 3 * Rand;
  goto LINE3100;
LINE2615:
  "OX WANDERS OFF---SPEND TIME LOOKING FOR IT\n";
  M = M - 17;
  goto LINE3100;
LINE2630:
  "YOUR SON GETS LOST---SPEND HALF THE DAY LOOKING FOR HIM\n";
  M = M - 10;
  goto LINE3100;
LINE2645:
  "UNSAFE WATER--LOSE TIME LOOKING FOR CLEAN SPRING\n";
  M = M - 10 * Rand - 2;
  goto LINE3100;
LINE2660:
  if (M > 950)
    goto LINE2935;
  "HEAVY RAINS---TIME AND SUPPLIES LOST\n";
  FOOD = FOOD - 10;
  AMMO = AMMO - 500;
  M1 = M1 - 15;
  M = M - 10 * Rand - 5;
  goto LINE3100;
LINE2690:
  "BANDITS ATTACK\n";
  FUNC4500;
  AMMO = AMMO - 20 * B1;
  if (AMMO >= 0)
    goto LINE2735;
  "YOU RAN OUT OF BULLETS---THEY GET LOTS OF CASH\n";
  T = T / 3;
  goto LINE2740;
LINE2735:
  if (B1 <= 1)
    goto LINE2770;
LINE2740:
  "YOU GOT SHOT IN THE LEG AND THEY TOOK ONE OF YOUR OXEN\n";
  K8 = 1;
  "BETTER HAVE A DOC LOOK AT YOUR WOUND\n";
  M1 = M1 - 5;
  A = A - 20;
  goto LINE3100;
LINE2770:
  "QUICKEST DRAW OUTSIDE OF DODGE CITY!!!\n";
  "YOU GOT 'EM!\n";
  goto LINE3100;
LINE2785:
  "THERE WAS A FIRE IN YOUR WAGON--FOOD AND SUPPLIES DAMAGED\n";
  FOOD = FOOD - 40;
  AMMO = AMMO - 400;
  M1 = M1 - Rand * 8 - 3;
  M = M - 15;
  goto LINE3100;
LINE2810:
  "LOSE YOUR WAY IN HEAVY FOG---TIME IS LOST\n";
  M = M - 10 - 5 * Rand;
  goto LINE3100;
LINE2825:
  "YOU KILLED A POISONOUS SNAKE AFTER IT BIT YOU\n";
  AMMO = AMMO - 10;
  FOOD = FOOD + 5;
  M1 = M1 - 5;
  if (M1 >= 0)
    goto LINE2855;
  "YOU DIE OF SNAKEBITE SINCE YOU HAVE NO MEDICINE\n";
  goto LINE3600;
LINE2855:
  goto LINE3100;
LINE2860:
  "WAGON GETS SWAMPED FORDING RIVER--LOSE FOOD AND CLOTHES\n";
  FOOD = FOOD - 30;
  C = C - 20;
  M = M - 20 - 20 * Rand;
  goto LINE3100;
LINE2885:
  "WILD ANIMALS ATTACK!\n";
  FUNC4500;
  if (AMMO > 39)
    goto LINE2895;
  "YOU WERE TOO LOW ON BULLETS--\n";
  "THE WOLVES OVERPOWERED YOU\n";
  K8 = 1;
  goto LINE3555;
LINE2895:
  if (B1 > 2)
    goto LINE2910;
  "NICE SHOOTIN' PARDNER---THEY DIDN'T GET MUCH\n";
  goto LINE2915;
LINE2910:
  "SLOW ON THE DRAW---THEY GOT AT YOUR FOOD AND CLOTHES\n";
LINE2915:
  AMMO = AMMO - 20 * B1;
  C = C - B1 * 4;
  FOOD = FOOD - B1 * 8;
  goto LINE3100;
LINE2935:
  "COLD WEATHER---BRRRRRRR!---YOU ";
  if (C > 22 + 4 * Rand)
    goto LINE2955;
  "DON'T ";
  C1 = 1;
LINE2955:
  "HAVE ENOUGH CLOTHING TO KEEP YOU WARM\n";
  if (C1 == 0)
    goto LINE3100;
  goto LINE4700;
LINE2970:
  "HAIL STORM---SUPPLIES DAMAGED\n";
  M = M - 5 - Rand * 10;
  AMMO = AMMO - 200;
  M1 = M1 - 4 - Rand * 3;
  goto LINE3100;
LINE2990:
  if (EAT == 1)
    goto LINE4700;
  if (EAT == 3)
    goto LINE3010;
  if (Rand > .25)
    goto LINE4700;
  goto LINE3100;
LINE3010:
  if (Rand < .5)
    goto LINE4700;
  goto LINE3100;
LINE3015:
  "AS YOU VENTURE FORTH, YOU ENCOUNTER A GROUP OF INDIANS\n";
  "SMOKING A PEACE PIPE WITH A WHITE MAN. THE MAN SAYS HIS\n";
  "NAME IS TERRY AND HE IS FROM THE FUTURE.\n\n";
  "HE TELLS YOU HE MUST GO BACK TO THE FUTURE TO BUILD A\n";
  "TEMPLE, BUT TRAVELED BACK IN TIME TO HELP YOU ON YOUR\n";
  "JOURNEY SO THAT SOMEDAY ONE OF YOUR ANCESTORS MIGHT ENTER\n";
  "THE TEMPLE HE IS BUILDING.\n\n";
  "TERRY AND THE INDIANS REWARD YOU WITH FOOD, CLOTHES, SUPPLIES,\n";
  "64 DOLLARS, A MAP TO HELP YOU THROUGH THE MOUNTAINS AND\n";
  "A DRINK CALLED DIET SHASTA.\n\n";
  TF = 1;
  A = 300;
  M = ClampU64( M + 50 + Round(70 * Rand), 1625, 2020);
  FOOD = FOOD + 100;
  M1 = M1 + 100;
  C = C + 100;
  T = T + 64;
  AMMO = AMMO + 100;
  F1 = 1;
  F2 = 1;
  goto LINE3100;
LINE3020:
  if (M > 1500 && M < 1900 && FOOD < 100
      && M1 < 100 && Rand > 0.6 && TF == 0)
    goto LINE3015; 
  "HELPFUL INDIANS SHOW YOU WHERE TO FIND MORE FOOD\n";
  FOOD = FOOD + 14;
  goto LINE3100;
  // ***MOUNTAINS***
LINE3100:
  if (M <= 950)
    goto LINE700;
  if (Rand * 10 > 9 - (Pow(M / 100 - 15, 2) + 72) / (Pow(M / 100 - 15, 2) + 12))
    goto LINE3175;
  "RUGGED MOUNTAINS\n";
  if (Rand > .1)
    goto LINE3135;
  "YOU GOT LOST---LOSE VALUABLE TIME TRYING TO FIND TRAIL!\n";
  M = M - 60;
  goto LINE3175;
LINE3135:
  if (Rand > .11)
    goto LINE3160;
  "WAGON DAMAGED!---LOSE TIME AND SUPPLIES\n";
  M1 = M1 - 5;
  AMMO = AMMO - 200;
  M = M - 20 - 30 * Rand;
  goto LINE3175;
LINE3160:
  "THE GOING GETS SLOW\n";
  M = M - 45 - Rand / .02;
LINE3175:
  if (F1 == 1)
    goto LINE3195;
  F1 = 1;
  if (Rand < .8)
    goto LINE3300;
  "YOU MADE IT SAFELY THROUGH SOUTH PASS--NO SNOW\n";
LINE3195:
  if (M < 1700)
    goto LINE3215;
  if (F2 == 1)
    goto LINE3215;
  F2 = 1;
  if (Rand < .7)
    goto LINE3300;
LINE3215:
  if (M > 950)
    goto LINE700;
  M9 = 1;
  goto LINE700;
LINE3300:
  "BLIZZARD IN MOUNTAIN PASS--TIME AND SUPPLIES LOST\n";
  L1 = 1;
  FOOD = FOOD - 25;
  M1 = M1 - 10;
  AMMO = AMMO - 300;
  M = M - 30 - 40 * Rand;
  if (C < 18 + 2 * Rand)
    goto LINE4700;
  goto LINE3215;
  // ***DYING***
LINE3500:
  "YOU RAN OUT OF FOOD AND STARVED TO DEATH\n";
  goto LINE3600;
LINE3520:
  T = 0;
  "YOU CAN'T AFFORD A DOCTOR\n";
  goto LINE3555;
LINE3550:
  "YOU RAN OUT MEDICAL SUPPLIES\n";
LINE3555:
  "YOU DIED OF ";
  if (K8 == 1)
    goto LINE3575;
  "PNEUMONIA\n";
  goto LINE3600;
LINE3575:
  "INJURIES\n";
LINE3600:
  "\n";
  "DO TO YOUR UNFORTUNATE SITUATION, THERE ARE A FEW\n";
  "FORMALITIES WE MUST GO THROUGH\n";
  "\n";
  "WOULD YOU LIKE A FANCY FUNERAL ";
  YorN;
  "WOULD YOU LIKE A MINISTER ";
  if (YorN) {
    "\n\nPRESS A KEY TO FIND OUT WHAT BIBLE VERSE WAS\n";
    "READ AT YOUR FUNERAL.\n\n";
    PressAKey;
    "\n";
    GodBiblePassage;
    "\n";
  }
  "WOULD YOU LIKE US TO INFORM YOUR NEXT OF KIN ";
  if (!YorN)
  {
    "YOUR AUNT NELLIE IN ST. LOUIS IS ANXIOUS TO HEAR\n";
    "\n";
  }
  "WE THANK YOU FOR THIS INFORMATION AND WE ARE SORRY YOU\n";
  "DIDN'T MAKE IT TO THE GREAT TERRITORY OF OREGON\n";
  "BETTER LUCK NEXT TIME\n";
  "\n";
  "\n";
  "SINCERELY\n";
  "\n";
  "THE OREGON CITY CHAMBER OF COMMERCE\n";
  "\nDO YOU WANT TO PLAY AGAIN ";
  if (YorN)
    goto LINE0;
  if (TaskValidate(ac.task)) {
    AutoComplete(old_ac);
  }
  FifoU8Del(data);
  return;
  // ***FINAL TURN***
LINE4000:
  F9 = (2040 - M2) / (M - M2);
  FOOD = FOOD + (1 - F9) * (8 + 5 * EAT);
  "\n";
  "YOU FINALLY ARRIVED AT OREGON CITY\n";
  "AFTER 2040 LONG MILES---HOORAY!!!!!\n";
  "\n";
  F9 = Round(F9);
  D3 = D3 * 14 + F9;
  F9 = F9 + 1;
  if (F9 < 8)
    goto LINE4055;
  F9 = F9 - 7;
LINE4055:
  switch(F9)
  {
  case 1:
    goto LINE4060;
  case 2:
    goto LINE4070;
  case 3:
    goto LINE4080;
  case 4:
    goto LINE4090;
  case 5:
    goto LINE4100;
  case 6:
    goto LINE4110;
  case 7:
    goto LINE4120;
  };
LINE4060:
  "MONDAY ";
  goto LINE4125;
LINE4070:
  "TUESDAY ";
  goto LINE4125;
LINE4080:
  "WEDNESDAY ";
  goto LINE4125;
LINE4090:
  "THURSDAY ";
  goto LINE4125;
LINE4100:
  "FRIDAY ";
  goto LINE4125;
LINE4110:
  "SATURDAY ";
  goto LINE4125;
LINE4120:
  "SUNDAY ";
LINE4125:
  if (D3 > 124)
    goto LINE4145;
  D3 = D3 - 93;
  "JULY %d", D3;
  " 1847\n";
  goto LINE4215;
LINE4145:
  if (D3 > 155)
    goto LINE4165;
  D3 = D3 - 124;
  "AUGUST %d", D3;
  " 1847\n";
  goto LINE4215;
LINE4165:
  if (D3 > 185)
    goto LINE4185;
  D3 = D3 - 155;
  "SEPTEMBER %d",D3;
  " 1847\n";
  goto LINE4215;
LINE4185:
  if (D3 > 216)
    goto LINE4205;
  D3 = D3 - 185;
  "OCTOBER %d", D3;
   " 1847\n";
  goto LINE4215;
LINE4205:
  D3 = D3 - 216;
  "NOVEMBER %d",D3;
  " 1847\n";
LINE4215:
  "\n";
  FOOD = ClampU64(Round(FOOD),0,10000);
  AMMO = ClampU64(Round(AMMO),0,10000);
  C = ClampU64(Round(C),0,10000);
  M1 = ClampU64(Round(M1),0,10000);
  T = ClampU64(Round(T),0,10000);
  "FOOD %d BULLETS %d CLOTHING %d MISC. SUPP. %d CASH %d\n",FOOD, AMMO, C, M1, T;
  if (AMMO > 0)
    goto LINE4240;
  AMMO = 0;
LINE4240:
  if (C > 0)
    goto LINE4250;
  C = 0;
LINE4250:
  if (M1 > 0)
    goto LINE4260;
  M1 = 0;
LINE4260:
  if (T > 0)
    goto LINE4270;
  T = 0;
LINE4270:
  if (FOOD > 0)
    goto LINE4285;
  FOOD = 0;
LINE4285:
  "\n";
  "PRESIDENT JAMES K. POLK SENDS YOU HIS\n";
  "      HEARTIEST CONGRATULATIONS\n";
  "\n";
  "AND WISHES YOU A PROSPEROUS LIFE AHEAD\n";
  "\n";
  "AT YOUR NEW HOME\n";
  "\nWOULD YOU LIKE TO THANK GOD FOR YOUR SAFE\n";
  "ARRIVAL BY READING A BIBLE VERSE ";
  if (YorN) {
    "\n";
    GodBiblePassage;
    "\n";
  }
  "\nDO YOU WANT TO PLAY AGAIN ";
  if (YorN)
    goto LINE0;
  if (TaskValidate(ac.task)) {
    AutoComplete(old_ac);
  }
  FifoU8Del(data);
  return;
LINE4700:
  if (100 * Rand < 10 + 35 * (EAT - 1))
    goto LINE4740;
  if (100 * Rand < 100 - (40 / Pow(4, (EAT - 1))))
    goto LINE4760;
  "SERIOUS ILLNESS---\n";
  "YOU MUST STOP FOR MEDICAL ATTENTION\n";
  M1 = M1 - 10;
  S4 = 1;
  goto LINE4780;
LINE4740:
  "MILD ILLNESS---MEDICINE USED\n";
  M = M - 5;
  M1 = M1 - 2;
  goto LINE4780;
LINE4760:
  "BAD ILLNESS---MEDICINE USED\n";
  M = M - 5;
  M1 = M1 - 5;
LINE4780:
  if (M1 < 0)
    goto LINE3550;
  if (L1 == 1)
    goto LINE3215;
  goto LINE3100;
}
