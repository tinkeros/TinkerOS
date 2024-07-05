// Possible TODOs
// Add Menu (doesn't seem necessary for this app?)
// Animate turns (just wastes time?)
// Add layer 1 solver (all people *should* be able to do one layer?)

#define CUBE_START_ROTATE_TIME 5.0

static class cube
{
  I64 x,y,z;
  I64 cxf,cxb,cyf,cyb,czf,czb;
  I64 cu,cd,cf,cb,cr,cl;
  I64 idx;
};

static cube cubes[27];
static Bool show_help=FALSE;
static Bool smash=FALSE;
static U64 smash_size=0;
static U64 cube_size=30;
static I64 start_time=0;

static U8 *reg_move="TempleOS/Cube/MoveXXXXXXX";
static U8 *reg_time="TempleOS/Cube/TimeXXXXXXXX";

Cd(__DIR__);;

U0 EnsureReg()
{
  I64 i;
  for (i=0;i<21;i++)
  {
    reg_move[18]=0;
    reg_time[18]=0;
    CatPrint(reg_move,"%02d",i);
    CatPrint(reg_time,"%02d",i);
    RegDft(reg_move,"999;\n");
    RegDft(reg_time,"9999.9;\n");
  }
}

EnsureReg;

U0 CubeHelp()
{
  show_help=!show_help;
}

U0 DrawCube(CDC *dc, I64 idx)
{
  I64 x_offset,y_offset,z_offset;
  F64 é=45*ã/180.0,è=45*ã/180.0,ê=45*ã/180.0,rot=0;
  CD3I32 poly[4];

  if (CUBE_START_ROTATE_TIME>0.0 && tS-start_time<CUBE_START_ROTATE_TIME)
  {
    rot=2.0*(tS-start_time)*ã/CUBE_START_ROTATE_TIME;
    é+=rot;
    è+=rot;
    ê+=rot;
  }

  cube_size=30;
  dc->x=Fs->pix_width/2;
  dc->y=Fs->pix_height/2;
  dc->z=155;

  if (show_help)
  {
    cube_size=25;
    dc->x+=Fs->pix_width/4;
    dc->y=cube_size*3+32;
  }

  if (smash)
  {
    cube_size=smash_size;
  }

  x_offset=cubes[idx].x*cube_size*2;
  y_offset=cubes[idx].y*cube_size*2;
  z_offset=cubes[idx].z*cube_size*2;


  Mat4x4IdentEqu(dc->r);
  Mat4x4RotX(dc->r,ê);
  Mat4x4RotY(dc->r,è);
  Mat4x4RotZ(dc->r,é);
  DCMat4x4Set(dc,dc->r);

  dc->color=cubes[idx].czf;

  poly[0].x=-cube_size+x_offset;
  poly[0].y=-cube_size+y_offset;
  poly[0].z=-cube_size+z_offset;
  poly[1].x=cube_size+x_offset;
  poly[1].y=-cube_size+y_offset;
  poly[1].z=-cube_size+z_offset;
  poly[2].x=cube_size+x_offset;
  poly[2].y=cube_size+y_offset;
  poly[2].z=-cube_size+z_offset;
  poly[3].x=-cube_size+x_offset;
  poly[3].y=cube_size+y_offset;
  poly[3].z=-cube_size+z_offset;
  GrFillPoly3(dc,4,poly);

  dc->color=cubes[idx].czb;

  poly[0].x=-cube_size+x_offset;
  poly[0].y=-cube_size+y_offset;
  poly[0].z=cube_size+z_offset;
  poly[1].x=cube_size+x_offset;
  poly[1].y=-cube_size+y_offset;
  poly[1].z=cube_size+z_offset;
  poly[2].x=cube_size+x_offset;
  poly[2].y=cube_size+y_offset;
  poly[2].z=cube_size+z_offset;
  poly[3].x=-cube_size+x_offset;
  poly[3].y=cube_size+y_offset;
  poly[3].z=cube_size+z_offset;
  GrFillPoly3(dc,4,poly);

  dc->color=cubes[idx].cxf;

  poly[0].z=-cube_size+z_offset;
  poly[0].y=-cube_size+y_offset;
  poly[0].x=cube_size+x_offset;
  poly[1].z=cube_size+z_offset;
  poly[1].y=-cube_size+y_offset;
  poly[1].x=cube_size+x_offset;
  poly[2].z=cube_size+z_offset;
  poly[2].y=cube_size+y_offset;
  poly[2].x=cube_size+x_offset;
  poly[3].z=-cube_size+z_offset;
  poly[3].y=cube_size+y_offset;
  poly[3].x=cube_size+x_offset;
  GrFillPoly3(dc,4,poly);

  dc->color=cubes[idx].cxb;

  poly[0].z=-cube_size+z_offset;
  poly[0].y=-cube_size+y_offset;
  poly[0].x=-cube_size+x_offset;
  poly[1].z=cube_size+z_offset;
  poly[1].y=-cube_size+y_offset;
  poly[1].x=-cube_size+x_offset;
  poly[2].z=cube_size+z_offset;
  poly[2].y=cube_size+y_offset;
  poly[2].x=-cube_size+x_offset;
  poly[3].z=-cube_size+z_offset;
  poly[3].y=cube_size+y_offset;
  poly[3].x=-cube_size+x_offset;
  GrFillPoly3(dc,4,poly);

  dc->color=cubes[idx].cyf;

  poly[0].z=-cube_size+z_offset;
  poly[0].x=-cube_size+x_offset;
  poly[0].y=cube_size+y_offset;
  poly[1].z=cube_size+z_offset;
  poly[1].x=-cube_size+x_offset;
  poly[1].y=cube_size+y_offset;
  poly[2].z=cube_size+z_offset;
  poly[2].x=cube_size+x_offset;
  poly[2].y=cube_size+y_offset;
  poly[3].z=-cube_size+z_offset;
  poly[3].x=cube_size+x_offset;
  poly[3].y=cube_size+y_offset;
  GrFillPoly3(dc,4,poly);

  dc->color=cubes[idx].cyb;

  poly[0].z=-cube_size+z_offset;
  poly[0].x=-cube_size+x_offset;
  poly[0].y=-cube_size+y_offset;
  poly[1].z=cube_size+z_offset;
  poly[1].x=-cube_size+x_offset;
  poly[1].y=-cube_size+y_offset;
  poly[2].z=cube_size+z_offset;
  poly[2].x=cube_size+x_offset;
  poly[2].y=-cube_size+y_offset;
  poly[3].z=-cube_size+z_offset;
  poly[3].x=cube_size+x_offset;
  poly[3].y=-cube_size+y_offset;
  GrFillPoly3(dc,4,poly);

  dc->color=BLACK;

  GrLine3(dc,-cube_size+x_offset,-cube_size+y_offset,-cube_size+z_offset, -cube_size+x_offset, cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc,-cube_size+x_offset, cube_size+y_offset,-cube_size+z_offset,  cube_size+x_offset, cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc, cube_size+x_offset, cube_size+y_offset,-cube_size+z_offset,  cube_size+x_offset,-cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc, cube_size+x_offset,-cube_size+y_offset,-cube_size+z_offset, -cube_size+x_offset,-cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc,-cube_size+x_offset,-cube_size+y_offset, cube_size+z_offset, -cube_size+x_offset, cube_size+y_offset, cube_size+z_offset);
  GrLine3(dc,-cube_size+x_offset, cube_size+y_offset, cube_size+z_offset,  cube_size+x_offset, cube_size+y_offset, cube_size+z_offset);
  GrLine3(dc, cube_size+x_offset, cube_size+y_offset, cube_size+z_offset,  cube_size+x_offset,-cube_size+y_offset, cube_size+z_offset);
  GrLine3(dc, cube_size+x_offset,-cube_size+y_offset, cube_size+z_offset, -cube_size+x_offset,-cube_size+y_offset, cube_size+z_offset);
  GrLine3(dc,-cube_size+x_offset,-cube_size+y_offset, cube_size+z_offset, -cube_size+x_offset,-cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc,-cube_size+x_offset, cube_size+y_offset, cube_size+z_offset, -cube_size+x_offset, cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc, cube_size+x_offset, cube_size+y_offset, cube_size+z_offset,  cube_size+x_offset, cube_size+y_offset,-cube_size+z_offset);
  GrLine3(dc, cube_size+x_offset,-cube_size+y_offset, cube_size+z_offset,  cube_size+x_offset,-cube_size+y_offset,-cube_size+z_offset);
}

U0 Rotate4(I64 x, I64 y, I64 z, I64 w)
{
  // TheTinkerer's magic special sauce
  // this was the best way I thought
  // of to take advantage of symmetry.

  cube tmpc;

  I64 size=sizeof(cube);

  MemCpy(&tmpc,&cubes[w],size);
  MemCpy(&cubes[w],&cubes[x],size);
  MemCpy(&cubes[x],&cubes[y],size);
  MemCpy(&cubes[y],&cubes[z],size);
  MemCpy(&cubes[z],&tmpc,size);

  size=sizeof(I64)*3;

  MemCpy(&tmpc,&cubes[w],size);
  MemCpy(&cubes[w],&cubes[z],size);
  MemCpy(&cubes[z],&cubes[y],size);
  MemCpy(&cubes[y],&cubes[x],size);
  MemCpy(&cubes[x],&tmpc,size);

}

U0 DoR(Bool dir=0)
{
  I64 idx,tmp,j;

  for (j=0;j<2*dir+1;j++) {

    Rotate4(23,19,21,25);
    Rotate4(20,18,24,26);

    for (idx=18;idx<27;idx++)
    {
      tmp=cubes[idx].cyb;
      cubes[idx].cyb=cubes[idx].czf;
      cubes[idx].czf=cubes[idx].cyf;
      cubes[idx].cyf=cubes[idx].czb;
      cubes[idx].czb=tmp;
    }
  }
}

U0 DoL(Bool dir=0)
{
  I64 idx,tmp,j;

  dir=!dir;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(3,7,5,1);
    Rotate4(6,8,2,0);

    for (idx=0;idx<9;idx++)
    {
      tmp=cubes[idx].cyb;
      cubes[idx].cyb=cubes[idx].czf;
      cubes[idx].czf=cubes[idx].cyf;
      cubes[idx].cyf=cubes[idx].czb;
      cubes[idx].czb=tmp;
    }
  }
}

U0 DoMRL(Bool dir=0)
{
  I64 idx,tmp,j;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(15,17,11,9);
    Rotate4(12,16,14,10);

    for (idx=9;idx<18;idx++)
    {
      tmp=cubes[idx].cyb;
      cubes[idx].cyb=cubes[idx].czf;
      cubes[idx].czf=cubes[idx].cyf;
      cubes[idx].cyf=cubes[idx].czb;
      cubes[idx].czb=tmp;
    }
  }
}

U0 DoU(Bool dir=0)
{
  I64 idx,tmp,i,j;

  dir=!dir;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(11,19,9,1);
    Rotate4(2,20,18,0);

    for (i=0;i<3;i++) {
      for (idx=0;idx<3;idx++)
      {
        tmp=cubes[idx+9*i].czf;
        cubes[idx+9*i].czf=cubes[idx+9*i].cxb;
        cubes[idx+9*i].cxb=cubes[idx+9*i].czb;
        cubes[idx+9*i].czb=cubes[idx+9*i].cxf;
        cubes[idx+9*i].cxf=tmp;
      }
    }
  }
}

U0 DoD(Bool dir=0)
{
  I64 idx,tmp,i,j;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(17,25,15,7);
    Rotate4(8,26,24,6);

    for (i=0;i<3;i++)
    {
      for (idx=0;idx<3;idx++)
      {
        tmp=cubes[idx+9*i+6].czf;
        cubes[idx+9*i+6].czf=cubes[idx+9*i+6].cxb;
        cubes[idx+9*i+6].cxb=cubes[idx+9*i+6].czb;
        cubes[idx+9*i+6].czb=cubes[idx+9*i+6].cxf;
        cubes[idx+9*i+6].cxf=tmp;
      }
    }
  }
}

U0 DoMDU(Bool dir=0)
{
  I64 idx,tmp,i,j;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(4,14,22,12);
    Rotate4(5,23,21,3);

    for (i=0;i<3;i++)
    {
      for (idx=0;idx<3;idx++)
      {
        tmp=cubes[idx+9*i+3].czf;
        cubes[idx+9*i+3].czf=cubes[idx+9*i+3].cxb;
        cubes[idx+9*i+3].cxb=cubes[idx+9*i+3].czb;
        cubes[idx+9*i+3].czb=cubes[idx+9*i+3].cxf;
        cubes[idx+9*i+3].cxf=tmp;
      }
    }
  }
}

U0 DoB(Bool dir=0)
{
  I64 idx,tmp,i,j;

  dir=!dir;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(5,17,23,11);
    Rotate4(8,26,20,2);

    for (i=0;i<3;i++)
    {
      for (idx=2;idx<9;idx+=3)
      {
        tmp=cubes[idx+9*i].cyb;
        cubes[idx+9*i].cyb=cubes[idx+9*i].cxb;
        cubes[idx+9*i].cxb=cubes[idx+9*i].cyf;
        cubes[idx+9*i].cyf=cubes[idx+9*i].cxf;
        cubes[idx+9*i].cxf=tmp;
      }
    }
  }
}

U0 DoF(Bool dir=0)
{
  I64 idx,tmp,i,j;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(6,24,18,0);
    Rotate4(3,15,21,9);

    for (i=0;i<3;i++)
    {
      for (idx=2;idx<9;idx+=3)
      {
        tmp=cubes[idx+9*i-2].cyb;
        cubes[idx+9*i-2].cyb=cubes[idx+9*i-2].cxb;
        cubes[idx+9*i-2].cxb=cubes[idx+9*i-2].cyf;
        cubes[idx+9*i-2].cyf=cubes[idx+9*i-2].cxf;
        cubes[idx+9*i-2].cxf=tmp;
      }
    }
  }
}

U0 DoMFB(Bool dir=0)
{
  I64 idx,tmp,i,j;

  for (j=0;j<2*dir+1;j++)
  {
    Rotate4(4,16,22,10);
    Rotate4(1,7,25,19);

    for (i=0;i<3;i++)
    {
      for (idx=2;idx<9;idx+=3)
      {
        tmp=cubes[idx+9*i-1].cyb;
        cubes[idx+9*i-1].cyb=cubes[idx+9*i-1].cxb;
        cubes[idx+9*i-1].cxb=cubes[idx+9*i-1].cyf;
        cubes[idx+9*i-1].cyf=cubes[idx+9*i-1].cxf;
        cubes[idx+9*i-1].cxf=tmp;
      }
    }
  }
}

Bool IsSolved()
{
  I64 i,j;

  // Check all, but ignore fake middle cube

  for (i=0;i<12;i++)
  {
    for (j=i+1;j<13;j++)
    {
      if (cubes[i].cxb!=cubes[j].cxb) return FALSE;
      if (cubes[i].cyb!=cubes[j].cyb) return FALSE;
      if (cubes[i].czb!=cubes[j].czb) return FALSE;
      if (cubes[i].cxf!=cubes[j].cxf) return FALSE;
      if (cubes[i].cyf!=cubes[j].cyf) return FALSE;
      if (cubes[i].czf!=cubes[j].czf) return FALSE;
    }
  }

  if (cubes[12].cxb!=cubes[14].cxb) return FALSE;
  if (cubes[12].cyb!=cubes[14].cyb) return FALSE;
  if (cubes[12].czb!=cubes[14].czb) return FALSE;
  if (cubes[12].cxf!=cubes[14].cxf) return FALSE;
  if (cubes[12].cyf!=cubes[14].cyf) return FALSE;
  if (cubes[12].czf!=cubes[14].czf) return FALSE;

  for (i=14;i<26;i++)
  {
    for (j=i+1;j<27;j++)
    {
      if (cubes[i].cxb!=cubes[j].cxb) return FALSE;
      if (cubes[i].cyb!=cubes[j].cyb) return FALSE;
      if (cubes[i].czb!=cubes[j].czb) return FALSE;
      if (cubes[i].cxf!=cubes[j].cxf) return FALSE;
      if (cubes[i].cyf!=cubes[j].cyf) return FALSE;
      if (cubes[i].czf!=cubes[j].czf) return FALSE;
    }
  }
  return TRUE;
}

Bool BreakCube()
{
  I64 i;
  static I64 cnt=0;
  static Bool lift=FALSE;
  static Bool slam=FALSE;

  if (!lift)
  {
    smash_size=30;
    for (i=0;i<27;i++)
    {
      cubes[i].y+=-1;
      cubes[i].z+=1;
    }
    cnt++;

    Sleep(2);
    if (cnt==GR_HEIGHT/25)
    {
      lift=TRUE;
      cnt=0;
    }
    return FALSE;
  }

  if (!slam)
  {
    smash_size=20;
    for (i=0;i<27;i++)
    {
      cubes[i].y+=1;
      cubes[i].z+=-1;
    }
    cnt++;

    Sleep(1);
    if (cnt==GR_HEIGHT/25)
    {
      slam=TRUE;
      cnt=0;
    }
    return FALSE;
  }

  for (i=0;i<27;i++)
  {
    cubes[i].x+=SignI64(cubes[i].x);
    cubes[i].y+=SignI64(cubes[i].y);
    cubes[i].z+=SignI64(cubes[i].z);
    cnt++;
  }
  if (cnt>GR_WIDTH) 
  {
    cnt=0;
    lift=FALSE;
    slam=FALSE;
    return TRUE;
  }
  else return FALSE;
}

U8 *SimpPuzStr(U8 *puz_str, U64 difficulty)
{
  I64 x,num_moves=0,len=StrLen(puz_str);
  U8 *new_puz_str=puz_str;
  for (x=0;x<len-1;x++)
  {
    if (((puz_str[x]=='1') && (puz_str[x+1]=='a'))
	  || ((puz_str[x]=='a') && (puz_str[x+1]=='1')))
    {
      puz_str[x]='0';
      puz_str[x+1]='0';
    }
    if (((puz_str[x]=='2') && (puz_str[x+1]=='b'))
	  || ((puz_str[x]=='b') && (puz_str[x+1]=='2')))
    {
      puz_str[x]='0';
      puz_str[x+1]='0';
    }
    if (((puz_str[x]=='3') && (puz_str[x+1]=='c'))
	  || ((puz_str[x]=='c') && (puz_str[x+1]=='3')))
    {
      puz_str[x]='0';
      puz_str[x+1]='0';
    }
    if (((puz_str[x]=='4') && (puz_str[x+1]=='d'))
	  || ((puz_str[x]=='d') && (puz_str[x+1]=='4')))
    {
      puz_str[x]='0';
      puz_str[x+1]='0';
    }
    if (((puz_str[x]=='5') && (puz_str[x+1]=='e'))
	  || ((puz_str[x]=='e') && (puz_str[x+1]=='5')))
    {
      puz_str[x]='0';
      puz_str[x+1]='0';
    }
    if (((puz_str[x]=='6') && (puz_str[x+1]=='f'))
	  || ((puz_str[x]=='f') && (puz_str[x+1]=='6')))
    {
      puz_str[x]='0';
      puz_str[x+1]='0';
    }
  }

  while (*puz_str && num_moves<difficulty)
  {
    if ('1'<=*puz_str<='6'||'a'<=*puz_str<='f') num_moves++;
    else if ('7'<=*puz_str<='9')
    {
      if (num_moves<difficulty-2)
        num_moves+=2;
      else 
      {
        *puz_str='1';
        num_moves+=1;
      }
    }
    *puz_str++;
  }
  *puz_str=0;
  return StrNew(new_puz_str);
}

#define LIN_CONGRUE_A	6364136223846793005
#define LIN_CONGRUE_C	1442695040888963407

U8 *GetPuzStr(U64 puz_num, U64 difficulty)
{
  U64 p2,p3;
  U8 *puz_str,*tmp_str;

  p2=puz_num;
  p2=LIN_CONGRUE_A*p2^(p2&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  p3=LIN_CONGRUE_A*p2^(p2&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;

  tmp_str=MStrPrint("%16x%16x%16x",puz_num,p2,p3);
  puz_str=SimpPuzStr(tmp_str,difficulty);
  Free(tmp_str);
  return puz_str;
}

I64 ApplyMoveStr(U8* str, Bool reverse=0)
{
  I64 dir=1,moves=0;
  U8 *ptr=str,*last=str+StrLen(str);

  if (reverse)
  {
    dir=-1;
    ptr=last-1;
    last=str-1;
  }
  while (ptr!=last)
  {
    if (*ptr=='0')
    {
      DoD(reverse);
      DoMDU(reverse);
      DoU(!reverse);
    }
    if (*ptr=='1') DoB(reverse);
    if (*ptr=='2') DoF(reverse);
    if (*ptr=='3') DoL(reverse);
    if (*ptr=='4') DoR(reverse);
    if (*ptr=='5') DoU(reverse);
    if (*ptr=='6') DoD(reverse);
    if (*ptr=='7') DoMRL(reverse);
    if (*ptr=='8') DoMFB(reverse);
    if (*ptr=='9') DoMDU(reverse);
    if ('1'<=*ptr<='6') moves+=1;
    if ('7'<=*ptr<='9') moves+=2;
    if (*ptr=='a') DoB(!reverse);
    if (*ptr=='b') DoF(!reverse);
    if (*ptr=='c') DoL(!reverse);
    if (*ptr=='d') DoR(!reverse);
    if (*ptr=='e') DoU(!reverse);
    if (*ptr=='f') DoD(!reverse);
    if ('a'<=*ptr<='f') moves+=1;  
   ptr+=dir;
  }
  return moves;
}

Bool CubeGame(U64 difficulty=20,U64 puz_num=0)
{
  Bool quit=FALSE,last_help=show_help;
  I64 key,x,y,z,idx=0,sc,moves=0,best_moves;
  U8 *puz_str;
  static U8 status_str[64];
  F64 finish_time=0.0,best_time,final_time;
  CDoc *help_doc,*orig_doc;

  start_time=tS,
  smash=FALSE;
  if (!puz_num) puz_num=GodBits(64,"Choose your random puzzle!");
  if (difficulty>20) difficulty=20;

  puz_str=GetPuzStr(puz_num, difficulty);

  reg_move[18]=0;
  reg_time[18]=0;
  CatPrint(reg_move,"%02d",difficulty);
  CatPrint(reg_time,"%02d",difficulty);
  best_moves=RegExe(reg_move);
  best_time=RegExe(reg_time)(F64);

  AutoComplete(0);
  WinMax;
  DocClear;
  moves=0;
  start_time=tS;

  "Puzzle num: %20u Level: %2d Best Moves: %3d Best Time: %1.2f\n\n",puz_num,difficulty,best_moves,best_time;

  "Press F1 to toggle help\n";

  orig_doc=Fs->display_doc;
  help_doc=DocRead("CubeHelp.DD.Z");
  DocCursor(,help_doc);
  DocCursor(,orig_doc);
  DocTop(help_doc);
  DocPrint(help_doc,"Puzzle num: %u Level: %d\n\n",puz_num,difficulty);

  if (Fs->pix_height>368) DocPrint(help_doc,"\n\n");

  // Init our cube colors and positions
  for (x=-1;x<=1;x++)
  {
    for (y=-1;y<=1;y++)
    {
      for (z=-1;z<=1;z++)
      {
        cubes[idx].x=x;
        cubes[idx].y=y;
        cubes[idx].z=z;

        cubes[idx].czb=BLUE+LTBLUE<<16+ROPF_DITHER;
        cubes[idx].czf=GREEN+LTGREEN<<16+ROPF_DITHER;

        cubes[idx].cxb=LTRED+YELLOW<<16+ROPF_DITHER;
        cubes[idx].cxf=RED+LTRED<<16+ROPF_DITHER;

        cubes[idx].cyb=WHITE+LTGRAY<<16+ROPF_DITHER;
        cubes[idx].cyf=YELLOW+WHITE<<16+ROPF_DITHER;

        cubes[idx].idx=idx;

        idx++;
      }
    }
  }

  // Shuffle our puzzle
  ApplyMoveStr(puz_str);

  CDC *dc=DCAlias;
  DCDepthBufAlloc(dc);
  dc->flags|=DCF_TRANSFORMATION|DCF_SYMMETRY;
  try
  {
    while(!quit)
    {
      if (IsSolved&&finish_time==0.0)
        finish_time=tS;


      if (moves>999) moves=999;

      while (!ScanKey(&key,&sc) && !quit)
      {
        DCDepthBufRst(dc);

        for (idx=0;idx<27;idx++)
        {
	  if (idx!=13)
	    DrawCube(dc,idx);
        }

        Mat4x4IdentEqu(dc->r);

        dc->color=BLUE;
        x=Fs->pix_width/2;
        y=-Fs->pix_height/2;
        z=100;
        if (tS-start_time>CUBE_START_ROTATE_TIME)
        {
          if (show_help)
          {
            x-=Fs->pix_width/4;
            status_str[0]=0;
            CatPrint(status_str,"Moves: %3d Time:%6.2f",moves,tS-start_time-CUBE_START_ROTATE_TIME);
            GrPrint3(dc,x-Fs->pix_width+40,-3*cube_size-24,z,status_str);
          }
          else {
            status_str[0]=0;
            CatPrint(status_str,"Moves: %3d      Time:%6.2f",moves,tS-start_time-CUBE_START_ROTATE_TIME);
            GrPrint3(dc,x-49*8,y+16,z,status_str);
          }
        }

        if (smash) 
        {
	  quit = BreakCube;
	  if (quit) smash=0;
        }

        Refresh;
        DCFill;
        if (finish_time>0.0&&tS-finish_time>1.0) quit=TRUE;
      }
      switch (key) 
      {
        start:
	  moves++;
	  case 'f':
	    DoF;
	    break;
	  case 'F':
	    DoF(1);
	    break;
	  case 'b':
	    DoB;
	    break;
	  case 'B':
	    DoB(1);
	    break;
	  case 'r':
	    DoR;
	    break;
	  case 'R':
	    DoR(1);
	    break;
	  case 'l':
	    DoL;
	    break;
	  case 'L':
	    DoL(1);
	    break;
	  case 'u':
	    DoU;
	    break;
	  case 'U':
	    DoU(1);
	    break;
	  case 'd':
	    DoD;
	    break;
	  case 'D':
	    DoD(1);
	    break;
        end:
	  break;
        start:
          moves+=8;
	  case 'o':
	    DoR(1);
            DoD(1);
            DoR;
            DoD;
	    DoR(1);
            DoD(1);
            DoR;
            DoD;
	    break;
	  case 'm':
	    DoU;
            DoR;
            DoU(1);
            DoR(1);
            DoU(1);
            DoF(1);
            DoU;
            DoF;
	    break;
	  case 'M':
	    DoU(1);
            DoL(1);
            DoU;
            DoL;
            DoU;
            DoF;
            DoU(1);
            DoF(1);
	    break;
	  case 'p':
	    DoU;
            DoR;
            DoU(1);
            DoL(1);
            DoU;
            DoR(1);
            DoU(1);
            DoL;
	    break;
        end:
	  break;
	case 'c':
	  DoF;
          DoR;
          DoU;
          DoR(1);
          DoU(1);
          DoF(1);
          moves+=6;
	  break;
        case 'e':
	  DoR;
          DoU;
          DoR(1);
          DoU;
          DoR;
          DoU;
	  DoU;
          DoR(1);
          DoU;
          moves+=9;
	  break;
        case 'h':
          CubeHelp;
          break;
        case CH_SHIFT_ESC:
        case 's':
          show_help=FALSE;
	  smash=TRUE;
          break;
        case 'q':
        case CH_ESC:
          show_help=FALSE;
          quit=TRUE;
	  break;
        case 0:
	  switch (sc.u8[0])
          {
            case SC_F1:
              CubeHelp;
              break;
	    case SC_CURSOR_RIGHT:
	      DoD;
	      DoMDU;
	      DoU(1);
	      break;
	    case SC_CURSOR_LEFT:
	      DoD(1);
	      DoMDU(1);
	      DoU;
	      break;
	    case SC_CURSOR_UP:
	      DoF(1);
	      DoMFB(1);
	      DoB;
	      break;
	    case SC_CURSOR_DOWN:
	      DoF;
	      DoMFB;
	      DoB(1);
	      break;
        }
      }
      if (last_help!=show_help)
      {
        last_help=show_help;
        PUSHFD
        CLI
        if (show_help)
          Fs->display_doc=help_doc;
        else
          Fs->display_doc=orig_doc;
        POPFD
      }
    }
  }
  catch
    PutExcept;

  DCFill;
  DCDel(dc);

  Free(puz_str);
  DocDel(help_doc);
  DocCursor(TRUE,orig_doc);

  if (IsSolved)
  {
    final_time=Clamp(finish_time-start_time-CUBE_START_ROTATE_TIME,0.0,9999.0);
    "Solved in %1.2f seconds with %d moves!\n",final_time,moves;
    if (final_time<best_time)
      RegWrite(reg_time,"%1.2f;\n",final_time);
    if (moves<best_moves)
      RegWrite(reg_move,"%d;\n",moves);
    return TRUE;
  }
  else
  {
    final_time=Clamp(tS-start_time-CUBE_START_ROTATE_TIME,0.0,9999.0);
    "Gave up in %1.2f seconds with %d moves!\n",final_time,moves;
  }
  return FALSE;
}
