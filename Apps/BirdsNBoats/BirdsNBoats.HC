//Uses $LK,"fixed-point",A="FI:::/Demo/Lectures/FixedPoint.HC"$.

RegDft("TempleOS/BirdsNBoats","F64 best_score=9999;\n");
RegExe("TempleOS/BirdsNBoats");

//Keep these power of two so shift is used instead of multiply
//to index arrays.
#define MAP_WIDTH		1024
#define MAP_HEIGHT		1024

#define MAP_SCALE		150
#define DISPLAY_SCALE		100
#define CTRLS_SCALE		0.05

//I think I did these so the heads-up showed intelligable numbers.
//Scaling is a mess.
#define COORDINATE_SCALE	256
#define COORDINATE_BITS		8

#define WATER_ELEVATION		15
#define BIRD_ELEVATION		10
#define ROCK_ELEVATION		45
#define SNOW_ELEVATION		55

#define CAM_BACK		800
#define CAM_UP			750
#define CAM_ZOOM_STEP		1.15
#define CAM_ORBIT_STEP		(г/16)
#define CAM_ELEV_MIN		0.08
#define CAM_ELEV_MAX		1.5

//Too big makes off-scrn draws take place.
#define PANEL_SIZE_MAX		16

#define MAP_MASK_X		(MAP_WIDTH-1)
#define MAP_MASK_Y		(MAP_HEIGHT-1)
#define WORLD_WIDTH		(MAP_WIDTH*MAP_SCALE)
#define WORLD_HEIGHT		(MAP_HEIGHT*MAP_SCALE)

#define VIEW_TILES		1
I64 view_dist=512;







			$SP,"<1>",BI=1$



















			$SP,"<2>",BI=2$

























			$SP,"<3>",BI=3$





















			$SP,"<4>",BI=4$















			$SP,"<5>",BI=5$















			$SP,"<6>",BI=6$








#define LS_TYPES	3
U8	*landscape_small_imgs[LS_TYPES]={$IB,"<4>",BI=4$,$IB,"<5>",BI=5$,$IB,"<6>",BI=6$},
	*landscape_large_imgs[LS_TYPES];

#define	B_NUM	256
class Bird
{
  Bird *next,*last;
  CD3I64 p;
  F64 й,lift,climb_ms;
} b_head[mp_cnt];

class Obj
{
  Obj *next,*last;
  CD3I64 p;
  U8 *img;
  Bool fish;
};

class Panel
{//Polygon or Obj
  Panel *next;
  CD3I32 *pts;
  I64 cnt[4];
  U32 update[4];
  U16 num_sides;
  U8 depth_bias;
  CColorROPU32 color;
  Obj *next_obj,*last_obj;
} *panel_head,*panels[MAP_HEIGHT][MAP_WIDTH];

I64 critical_section_flag;
I16 elevations[MAP_HEIGHT][MAP_WIDTH];
CD3 normals[MAP_HEIGHT][MAP_WIDTH];
Bool bent[MAP_HEIGHT][MAP_WIDTH];

I64 render_first,
    render_cnt;

class MPCtrl {
  I64 init_not_done_flags,update_not_done_flags,app_not_done_flags;
  I64 strip_width[MP_PROCESSORS_NUM];
  Bool time_up[MP_PROCESSORS_NUM];
  Bool app_done;
} mp;

F64 game_t0,game_tf,pitch,roll,heading,и,speed;
Bool invert_pitch,rolled_over;
I64 strip_height,x,y,z;
I64 cam_x,cam_y,cam_z;
F64 boat_x,boat_y,boat_heading,boat_speed,boat_len,boat_beam,boat_ctr;
I64 fish_left_bird,fish_left_boat,anim_lock,fish_cnt;
F64 cam_zoom=1.0,cam_orbit=0,cam_elev=0;
Bool boat_fp=TRUE;
Bool bird_mode,crashed;
F64 bird_orbit=0,bird_elev=0,cam_h,cam_p,fl_heading,fl_phi,fl_roll,bird_bank=0;
#define BIRD_CAM_ELEV0		0.245
I64 boat_img=0;
F64 boat_bow[2],boat_lens[2],boat_beams[2],boat_ctrs[2];

U0 BoatSetImg(I64 k=0)
{
  boat_img=k;
  boat_len=boat_lens[k];
  boat_beam=boat_beams[k];
  boat_ctr=boat_ctrs[k];
}
F64 bird_zoom=0;
U8 *fish_img;
Obj **fish_list;
CD3 v;

I64 WrapCoord(I64 a,I64 m)
{
  a%=m;
  if (a<0)
    a+=m;
  return a;
}

I64 WrapDelta(I64 d,I64 m)
{
  return WrapCoord(d+(m>>1),m)-(m>>1);
}

U0 WrapAngles()
{
  I64 r[4][4],x,y,z;

  и=Wrap(и);
  pitch=Wrap(-и-г/2);
  if (Abs(pitch)>г/2) {
    invert_pitch=TRUE;
    pitch=Wrap(г-pitch);
  } else
    invert_pitch=FALSE;
  roll=Wrap(roll);
  if (invert_pitch ^^ -г/2<=roll<г/2)
    rolled_over=FALSE;
  else
    rolled_over=TRUE;
  heading=Wrap(heading,0);

  //World to scrn coordinates
  Mat4x4IdentEqu(r);
  Mat4x4RotZ(r,heading);
  Mat4x4RotX(r,и);
  Mat4x4RotZ(r,roll);

  //We use velocity vector for dog-fighting.
  x=0x100000000*speed; y=0; z=0;
  Mat4x4MulXYZ(r,&x,&y,&z);
  v.x=x/ToF64(0x100000000); v.y=y/ToF64(0x100000000); v.z=z/ToF64(0x100000000);
}

#define NEAR_Z			16

I64 PanelFill(CDC *dc,I64 n,CD3I32 *p,I64 ox,I64 oy,I64 bias,
	CColorROPU32 color)
{
  I64 i,j,a,b,m=0,res=0,y0,y1,yy,x0,x1,xx,k,d,*mr=dc->r,
	w=dc->width,h=dc->height,wi=dc->width_internal,
	c0=color&0xFF,c1=color>>16&0xFF;
  F64 sx[8],sy[8],sz[8],t,fy,f,e,xl,xr,zl,zr,zz,dz,x[4],y[4],z[4],px,py,pz,
	x_lo=F64_MAX,x_hi=-F64_MAX,y_lo=F64_MAX,y_hi=-F64_MAX;
  Bool dither=ToBool(color&ROPF_DITHER),
	pdither=ToBool(color&ROPF_PROBABILITY_DITHER);
  I64 prob=dc->dither_probability_u16;
  I32 *db;
  U8 *dst;
  for (i=0;i<n;i++) {
    px=p[i].x+ox;
    py=p[i].y+oy;
    pz=p[i].z;
    x[i]=(mr[0]*px+mr[1]*py+mr[2]*pz+mr[3])/4294967296.0;
    y[i]=(mr[4]*px+mr[5]*py+mr[6]*pz+mr[7])/4294967296.0;
    z[i]=-(mr[8]*px+mr[9]*py+mr[10]*pz+mr[11])/4294967296.0;
  }
  for (i=0;i<n;i++) {
    j=(i+1)%n;
    if (z[i]>=NEAR_Z) {
      sx[m]=dc->x+x[i]*DISPLAY_SCALE/z[i];
      sy[m]=dc->y-y[i]*DISPLAY_SCALE/z[i];
      sz[m++]=1.0/(z[i]+bias);
    }
    if ((z[i]>=NEAR_Z)!=(z[j]>=NEAR_Z)) {
      if (z[i]<z[j]) {
	a=i; b=j;
      } else {
	a=j; b=i;
      }
      t=(NEAR_Z-z[a])/(z[b]-z[a]);
      sx[m]=dc->x+(x[a]+(x[b]-x[a])*t)*DISPLAY_SCALE/NEAR_Z;
      sy[m]=dc->y-(y[a]+(y[b]-y[a])*t)*DISPLAY_SCALE/NEAR_Z;
      sz[m++]=1.0/(NEAR_Z+bias);
    }
  }
  if (m<3)
    return 0;
  for (i=0;i<m;i++) {
    x_lo=Min(x_lo,sx[i]); x_hi=Max(x_hi,sx[i]);
    y_lo=Min(y_lo,sy[i]); y_hi=Max(y_hi,sy[i]);
  }
  y0=MaxI64(0,Ceil(y_lo-0.5));
  y1=MinI64(h-1,Ceil(y_hi-0.5)-1);
  for (yy=y0;yy<=y1;yy++) {
    fy=yy+0.5;
    xl=F64_MAX;
    xr=-F64_MAX;
    for (i=0;i<m;i++) {
      j=(i+1)%m;
      if (sy[i]<sy[j]) {
	a=i; b=j;
      } else {
	a=j; b=i;
      }
      if (sy[a]<=fy<sy[b]) {
	f=(fy-sy[a])/(sy[b]-sy[a]);
	e=sx[a]+(sx[b]-sx[a])*f;
	zz=sz[a]+(sz[b]-sz[a])*f;
	if (e<xl) {
	  xl=e; zl=zz;
	}
	if (e>xr) {
	  xr=e; zr=zz;
	}
      }
    }
    if (xl<xr) {
      x0=Ceil(xl-0.5);
      x1=Ceil(xr-0.5)-1;
      dz=(zr-zl)/(xr-xl);
      if (x0<0) x0=0;
      if (x1>=w) x1=w-1;
      if (x0<=x1) {
	zz=zl+(x0+0.5-xl)*dz;
	d=wi*yy+x0;
	db=dc->depth_buf+d;
	dst=dc->body+d;
	for (xx=x0;xx<=x1;xx++) {
	  k=1.0/zz;
	  if (k<=*db) {
	    *db=k;
	    if (pdither) {
	      if (RandU16<prob)
		*dst=c1;
	      else
		*dst=c0;
	    } else if (dither && (xx^yy)&1)
	      *dst=c1;
	    else
	      *dst=c0;
	    res++;
	  }
	  db++;
	  dst++;
	  zz+=dz;
	}
      }
    }
  }
  if (res)
    return res;
  if (x_hi<0 || x_lo>=w || y_hi<0 || y_lo>=h)
    return 0;
  if (x_hi-x_lo<3 || y_hi-y_lo<3)
    return 1;
  return 0;
}

U0 EDTransform(CDC *dc,I64 *x,I64 *y,I64 *z)
{
  I64 zz;
  Mat4x4MulXYZ(dc->r,x,y,z);
  *z=zz=-*z;
  if (zz>0) {
    *x = dc->x + *x * DISPLAY_SCALE/zz; //Foreshortening
    *y = dc->y - *y * DISPLAY_SCALE/zz;
  } else {
    *x = dc->x + *x;
    *y = dc->y - *y;
  }
}

U0 CalcNormals()
{/*Find the normal vect with a curl.

i,j and k are the axis unit vectors,
not to be confused with my local index variables.

i  j  k
0  1  dz2
1  0  dz1

Normal:  dz1*i + dz2*j - k
*/
  I64 i,j;
  for (j=0;j<MAP_HEIGHT;j++)
    for (i=0;i<MAP_WIDTH;i++) {
      normals[j][i].x=elevations[j][(i+1)&MAP_MASK_X]-elevations[j][i];
      normals[j][i].y=elevations[(j+1)&MAP_MASK_Y][i]-elevations[j][i];
      bent[j][i]=elevations[(j+1)&MAP_MASK_Y][(i+1)&MAP_MASK_X]-
	    elevations[(j+1)&MAP_MASK_Y][i]!=normals[j][i].x;
      normals[j][i].z=-1;
      D3Unit(&normals[j][i]);
    }
}

Bool TestSameSlope(I64 x,I64 y,I64 w,I64 h)
{
  CD3 p,*s;
  I64 k1,k2;
  if (!(0<=x && x+w<=MAP_WIDTH && 0<=y && y+h<=MAP_HEIGHT))
    return FALSE;
  s=&normals[y][x];
  for (k2=0;k2<h;k2++)
    for (k1=0;k1<w;k1++)
      if (bent[y+k2][x+k1] ||
	    D3NormSqr(D3Sub(&p,&normals[y+k2][x+k1],s))>0.02)
	return FALSE;
  return TRUE;
}

U0 MPDoPanels(CTask *task)
{
  I64 i,j,l,k1,k2,w,h,threshold,lo,hi;
  Bool cont;
  Panel *tmpp,*start_ptr=NULL,*end_ptr=NULL;
  CD3I32 *poly;
  Obj *tmpo;
  lo=Gs->num*MAP_HEIGHT/mp_cnt;
  hi=(Gs->num+1)*MAP_HEIGHT/mp_cnt;
  for (threshold=8;threshold>=1;threshold--)
    for (j=lo;j<hi;j++) {
      for (i=0;i<MAP_WIDTH;i++) {
	if (!panels[j][i]) {
	  w=1;
	  h=1;
	  do {
	    cont=FALSE;
	    if (w<PANEL_SIZE_MAX && TestSameSlope(i,j,w+1,h)) {
	      w++;
	      cont=TRUE;
	    }
	    if (h<PANEL_SIZE_MAX && TestSameSlope(i,j,w,h+1)) {
	      h++;
	      cont=TRUE;
	    }
	  } while (cont);
	  if (w>=threshold || h>=threshold) {
	    tmpp=CAlloc(sizeof(Panel),task);
	    QueInit(&tmpp->next_obj);
	    l=elevations[j][i];
	    if (l<=WATER_ELEVATION*MAP_SCALE &&
		  elevations[j][(i+w)&MAP_MASK_X]<=WATER_ELEVATION*MAP_SCALE &&
		  elevations[(j+h)&MAP_MASK_Y][i]<=WATER_ELEVATION*MAP_SCALE &&
		  elevations[(j+h)&MAP_MASK_Y][(i+w)&MAP_MASK_X]<=
		  WATER_ELEVATION*MAP_SCALE) {
	      tmpp->color=BLUE;
	      if (Rand<0.05) {
		tmpo=MAlloc(sizeof(Obj),task);
		tmpo->p.x=(i+w/2)*MAP_SCALE;
		tmpo->p.y=(j+h/2)*MAP_SCALE;
		if (Rand<0.1) {
		  tmpo->fish=FALSE;
		  tmpo->img=landscape_large_imgs[RandU16&1];
		  tmpo->p.z=(WATER_ELEVATION+2)*MAP_SCALE;
		} else {
		  tmpo->fish=TRUE;
		  tmpo->img=fish_img;
		  tmpo->p.z=WATER_ELEVATION*MAP_SCALE;
		}
		QueIns(tmpo,tmpp->last_obj);
	      }
	    } else {
	      if (l<ROCK_ELEVATION*MAP_SCALE) {
		if (RandI16&1)
		  tmpp->color=LTGREEN;
		else
		  tmpp->color=GREEN+LTGREEN<<16+ROPF_DITHER;
		if (Rand<0.03) {
		  tmpo=MAlloc(sizeof(Obj),task);
		  tmpo->p.x=(i+w/2)*MAP_SCALE;
		  tmpo->p.y=(j+h/2)*MAP_SCALE;
		  tmpo->p.z=l;
		  tmpo->img=landscape_large_imgs[2]; //Tree
		  tmpo->fish=FALSE;
		  QueIns(tmpo,tmpp->last_obj);
		}
	      } else if (l<SNOW_ELEVATION*MAP_SCALE) {
		if (!(RandU16&3)) {
		  if (RandI16&1)
		    tmpp->color=LTGRAY;
		  else
		    tmpp->color=DKGRAY+LTGRAY<<16+ROPF_DITHER;
		} else {
		  if (RandI16&1)
		    tmpp->color=LTGREEN;
		  else
		    tmpp->color=GREEN+LTGREEN<<16+ROPF_DITHER;
		}
	      } else {
		if (!(RandU16&3)) {
		  if (RandI16&1)
		    tmpp->color=WHITE;
		  else
		    tmpp->color=LTGRAY;
		} else {
		  if (RandI16&1)
		    tmpp->color=LTGRAY+WHITE<<16+ROPF_DITHER;
		  else
		    tmpp->color=DKGRAY+LTGRAY<<16+ROPF_DITHER;
		}
	      }
	    }
	    tmpp->num_sides=4;
	    tmpp->depth_bias=RandU16&(8-1);
	    poly=tmpp->pts=MAlloc(sizeof(CD3I32)*tmpp->num_sides,task);
	    poly[0].x=MAP_SCALE*i;
	    poly[0].y=MAP_SCALE*j;
	    poly[0].z=elevations[j][i];
	    poly[1].x=MAP_SCALE*(i+w);
	    poly[1].y=MAP_SCALE*j;
	    poly[1].z=elevations[j][(i+w)&MAP_MASK_X];
	    poly[2].x=MAP_SCALE*(i+w);
	    poly[2].y=MAP_SCALE*(j+h);
	    poly[2].z=elevations[(j+h)&MAP_MASK_Y][(i+w)&MAP_MASK_X];
	    poly[3].x=MAP_SCALE*i;
	    poly[3].y=MAP_SCALE*(j+h);
	    poly[3].z=elevations[(j+h)&MAP_MASK_Y][i];
	    tmpp->next=start_ptr;
	    start_ptr=tmpp;
	    if (!end_ptr)
	      end_ptr=tmpp;
	    for (k2=0;k2<h;k2++)
	      for (k1=0;k1<w;k1++)
		panels[j+k2][i+k1]=tmpp;
	  }
	}
      }
    }
  if (end_ptr) {
    while (LBts(&critical_section_flag,0))
      Yield;
    if (end_ptr)
      end_ptr->next=panel_head;
    panel_head=start_ptr;
    LBtr(&critical_section_flag,0);
  }
  LBtr(&mp.init_not_done_flags,Gs->num);
}

U0 InitElevations()
{
  I64 i,j,l,x,y,xx,yy;
  MemSet(elevations,0,sizeof(elevations));
  for (i=0;i<MAP_WIDTH*MAP_HEIGHT/128;i++) {
    x=RandU32%MAP_WIDTH;
    y=RandU32%MAP_HEIGHT;
    j=1<<(RandU32%6);
    l=0;
    while (j--) {
      if (!l && RandU16<U16_MAX/4)
	l=RandU16%(j+1);
      if (l) {
	for (yy=y-j;yy<y+j;yy++)
	  for (xx=x-j;xx<x+j;xx++)
	    elevations[yy&MAP_MASK_Y][xx&MAP_MASK_X]+=MAP_SCALE/2;
	l--;
      }
    }
  }

  for (j=0;j<MAP_HEIGHT;j++)
    for (i=0;i<MAP_WIDTH;i++)
      if (elevations[j][i]<WATER_ELEVATION*MAP_SCALE)
	elevations[j][i]=WATER_ELEVATION*MAP_SCALE;
}

#define MAP_CELLS		(MAP_WIDTH*MAP_HEIGHT)

I64 CellStep(I64 c,I64 k)
{
  I64 x=c&MAP_MASK_X,y=c/MAP_WIDTH;
  switch (k) {
    case 0: x=(x+1)&MAP_MASK_X; break;
    case 1: x=(x-1)&MAP_MASK_X; break;
    case 2: y=(y+1)&MAP_MASK_Y; break;
    case 3: y=(y-1)&MAP_MASK_Y; break;
    case 4: x=(x+1)&MAP_MASK_X; y=(y+1)&MAP_MASK_Y; break;
    case 5: x=(x-1)&MAP_MASK_X; y=(y+1)&MAP_MASK_Y; break;
    case 6: x=(x+1)&MAP_MASK_X; y=(y-1)&MAP_MASK_Y; break;
    case 7: x=(x-1)&MAP_MASK_X; y=(y-1)&MAP_MASK_Y; break;
  }
  return y*MAP_WIDTH+x;
}

F64 CellDist(I64 c1,I64 c2)
{
  I64 dx=WrapDelta((c1&MAP_MASK_X)-(c2&MAP_MASK_X),MAP_WIDTH),
	dy=WrapDelta(c1/MAP_WIDTH-c2/MAP_WIDTH,MAP_HEIGHT);
  return Sqrt(dx*dx+dy*dy);
}

I64 LakeFind(I32 *uf,I64 a)
{
  while (uf[a]!=a) {
    uf[a]=uf[uf[a]];
    a=uf[a];
  }
  return a;
}

I64 ConnectLakes()
{
  I16 *e=elevations;
  I64 i,k,c,u,v,a,b,head,tail,lakes=0,cands=0,max_len=0,half,reach,
	water=WATER_ELEVATION*MAP_SCALE,top=water,t,boat=MAP_SCALE,
	min_x,max_x,min_y,max_y;
  I32 *lake=MAlloc(MAP_CELLS*sizeof(I32)),*dist=MAlloc(MAP_CELLS*sizeof(I32)),
	*par=MAlloc(MAP_CELLS*sizeof(I32)),*que=MAlloc(MAP_CELLS*sizeof(I32)),
	*cand_u=MAlloc(MAP_CELLS*sizeof(I32)),*cand_v=MAlloc(MAP_CELLS*sizeof(I32)),
	*cand_len=MAlloc(MAP_CELLS*sizeof(I32)),*order=MAlloc(MAP_CELLS*sizeof(I32)),
	*cnt,*uf;
  Bool *chan=CAlloc(MAP_CELLS*sizeof(Bool));
  F64 d;

  for (i=0;i<LS_TYPES-1;i++) {
    SpriteExtents(landscape_large_imgs[i],&min_x,&max_x,&min_y,&max_y);
    boat=MaxI64(boat,MaxI64(max_x-min_x,max_y-min_y));
  }
  half=boat/(2*MAP_SCALE)+2;

  tail=0;
  for (c=0;c<MAP_CELLS;c++) {
    if (e[c]<=water && e[CellStep(c,0)]<=water &&
	  e[CellStep(c,2)]<=water && e[CellStep(c,4)]<=water)
      dist[c]=-1;
    else {
      dist[c]=0;
      que[tail++]=c;
    }
    top=MaxI64(top,e[c]);
  }
  head=0;
  while (head<tail) {
    u=que[head++];
    for (k=0;k<8;k++) {
      v=CellStep(u,k);
      if (dist[v]<0) {
	dist[v]=dist[u]+1;
	que[tail++]=v;
      }
    }
  }
  for (c=0;c<MAP_CELLS;c++)
    if (dist[c]<0 || dist[c]>=half-1)
      lake[c]=-2;
    else
      lake[c]=-1;

  for (c=0;c<MAP_CELLS;c++)
    if (lake[c]==-2) {
      lake[c]=lakes;
      que[0]=c;
      head=0;
      tail=1;
      while (head<tail) {
	u=que[head++];
	for (k=0;k<4;k++) {
	  v=CellStep(u,k);
	  if (lake[v]==-2) {
	    lake[v]=lakes;
	    que[tail++]=v;
	  }
	}
      }
      lakes++;
    }
  if (lakes<2)
    goto cl_done;

  tail=0;
  for (c=0;c<MAP_CELLS;c++) {
    par[c]=-1;
    if (lake[c]>=0) {
      dist[c]=0;
      que[tail++]=c;
    } else
      dist[c]=-1;
  }
  head=0;
  while (head<tail) {
    u=que[head++];
    for (k=0;k<4;k++) {
      v=CellStep(u,k);
      if (lake[v]<0) {
	lake[v]=lake[u];
	dist[v]=dist[u]+1;
	par[v]=u;
	que[tail++]=v;
      } else if (lake[v]>lake[u] && cands<MAP_CELLS) {
	cand_u[cands]=u;
	cand_v[cands]=v;
	cand_len[cands]=dist[u]+dist[v]+1;
	max_len=MaxI64(max_len,cand_len[cands]);
	cands++;
      }
    }
  }

  cnt=CAlloc((max_len+2)*sizeof(I32));
  for (i=0;i<cands;i++)
    cnt[cand_len[i]+1]++;
  for (i=1;i<=max_len+1;i++)
    cnt[i]+=cnt[i-1];
  for (i=0;i<cands;i++)
    order[cnt[cand_len[i]]++]=i;
  Free(cnt);

  uf=MAlloc(lakes*sizeof(I32));
  for (i=0;i<lakes;i++)
    uf[i]=i;
  for (i=0;i<cands;i++) {
    u=cand_u[order[i]];
    v=cand_v[order[i]];
    a=LakeFind(uf,lake[u]);
    b=LakeFind(uf,lake[v]);
    if (a!=b) {
      uf[a]=b;
      for (c=u;c>=0;c=par[c])
	chan[c]=TRUE;
      for (c=v;c>=0;c=par[c])
	chan[c]=TRUE;
    }
  }
  Free(uf);

  reach=half+(top-water)/(MAP_SCALE/2)+2;

  tail=0;
  for (c=0;c<MAP_CELLS;c++)
    if (chan[c]) {
      par[c]=c;
      que[tail++]=c;
    } else
      par[c]=-1;
  head=0;
  while (head<tail) {
    u=que[head++];
    for (k=0;k<8;k++) {
      v=CellStep(u,k);
      if (par[v]<0 && CellDist(v,par[u])<=reach) {
	par[v]=par[u];
	que[tail++]=v;
      }
    }
  }
  for (c=0;c<MAP_CELLS;c++) {
    dist[c]=FALSE;
    if (par[c]>=0) {
      d=CellDist(c,par[c])-half;
      if (d<=0) {
	d=0;
	dist[c]=TRUE;
      }
      t=water+ToI64(d)*(MAP_SCALE/2);
      if (t<e[c])
	e[c]=t;
    }
  }

  for (i=0;i<2;i++) {
    for (c=0;c<MAP_CELLS;c++)
      que[c]=e[c];
    for (c=0;c<MAP_CELLS;c++)
      if (par[c]>=0 && !dist[c]) {
	t=que[c];
	for (k=0;k<8;k++)
	  t+=que[CellStep(c,k)];
	t=(t+9*MAP_SCALE/4)/(9*MAP_SCALE/2)*(MAP_SCALE/2);
	e[c]=MaxI64(water,t);
      }
  }

cl_done:
  Free(lake);
  Free(dist);
  Free(par);
  Free(que);
  Free(cand_u);
  Free(cand_v);
  Free(cand_len);
  Free(order);
  Free(chan);
  return lakes;
}


Bool BoatSpotOpen(I64 i,I64 j)
{
  I64 di,dj;
  Panel *tmpp;
  for (dj=-2;dj<=2;dj++)
    for (di=-2;di<=2;di++) {
      tmpp=panels[(j+dj)&MAP_MASK_Y][(i+di)&MAP_MASK_X];
      if (!tmpp || tmpp->color!=BLUE)
	return FALSE;
    }
  return TRUE;
}

Bool BoatSpaced(I64 x,I64 y,Obj **kept,I64 k,F64 d2)
{
  I64 i;
  for (i=0;i<k;i++)
    if (Sqr(WrapDelta(kept[i]->p.x-x,WORLD_WIDTH))+
	  Sqr(WrapDelta(kept[i]->p.y-y,WORLD_HEIGHT))<d2)
      return FALSE;
  return TRUE;
}

U0 SpaceBoats()
{
  I64 i,j,n=0,k=0,m,tries,min_x,max_x,min_y,max_y,len=MAP_SCALE;
  F64 d2;
  Panel *tmpp;
  Obj *tmpo,*next,**boats,**kept;
  for (i=0;i<2;i++) {
    SpriteExtents(landscape_large_imgs[i],&min_x,&max_x,&min_y,&max_y);
    len=MaxI64(len,MaxI64(max_x-min_x,max_y-min_y));
  }
  d2=Sqr(ToF64(3*len));
  tmpp=panel_head;
  while (tmpp) {
    tmpo=tmpp->next_obj;
    while (tmpo!=&tmpp->next_obj) {
      if (!tmpo->fish && (tmpo->img==landscape_large_imgs[0] ||
	    tmpo->img==landscape_large_imgs[1]))
	n++;
      tmpo=tmpo->next;
    }
    tmpp=tmpp->next;
  }
  if (!n)
    return;
  boats=MAlloc(n*sizeof(Obj *));
  kept=MAlloc(n*sizeof(Obj *));
  tmpp=panel_head;
  while (tmpp) {
    tmpo=tmpp->next_obj;
    while (tmpo!=&tmpp->next_obj) {
      next=tmpo->next;
      if (!tmpo->fish && (tmpo->img==landscape_large_imgs[0] ||
	    tmpo->img==landscape_large_imgs[1])) {
	QueRem(tmpo);
	boats[k++]=tmpo;
      }
      tmpo=next;
    }
    tmpp=tmpp->next;
  }
  m=k;
  k=0;
  for (n=0;n<m;n++) {
    tmpo=boats[n];
    if (!BoatSpaced(tmpo->p.x,tmpo->p.y,kept,k,d2)) {
      for (tries=0;tries<200;tries++) {
	i=RandU32&MAP_MASK_X;
	j=RandU32&MAP_MASK_Y;
	if (BoatSpotOpen(i,j) &&
	      BoatSpaced((i+0.5)*MAP_SCALE,(j+0.5)*MAP_SCALE,kept,k,d2)) {
	  tmpo->p.x=(i+0.5)*MAP_SCALE;
	  tmpo->p.y=(j+0.5)*MAP_SCALE;
	  break;
	}
      }
      if (tries==200) {
	Free(tmpo);
	tmpo=NULL;
      }
    }
    if (tmpo) {
      tmpp=panels[(tmpo->p.y/MAP_SCALE)&MAP_MASK_Y][(tmpo->p.x/MAP_SCALE)&MAP_MASK_X];
      if (tmpp) {
	QueIns(tmpo,tmpp->last_obj);
	kept[k++]=tmpo;
      } else
	Free(tmpo);
    }
  }
  Free(boats);
  Free(kept);
}

U0 InitMap()
{/*We make a topographic data structure "elevations[][]"
and convert it to panels. "panels[][]" holds the panels
for each spot.
*/
  I64 i;
  InitElevations;
  for (i=0;i<4 && ConnectLakes>1;i++);
  MemSet(panels,0,sizeof(panels));
  CalcNormals;
  panel_head=NULL;
  mp.init_not_done_flags=1<<mp_cnt-1;
  for (i=0;i<mp_cnt;i++)
    Spawn(&MPDoPanels,Fs,"Do Panels",i);
  while (mp.init_not_done_flags)
    Sleep(1);
}

F64 claws_down;

#define HAND_X	(1.0-claws_down)*(0.3*w)+claws_down*(0.4*w)
#define HAND_Y	(1.0-claws_down)*(h-125)+claws_down*h




$SP,"<7>",BI=7$
$SP,"<8>",BI=8$



U0 ClawDraw(CDC *dc,I64 x1,I64 y1,I64 x2,I64 y2,I64 w,I64 segments,Bool talon)
{
  I64 i,j;
  for (i=0,j=segments;i<segments;i++,j--) {
    dc->thick=w;
    dc->color=BLACK;
    GrLine3(dc,
	j*x1/segments+i*x2/segments,
	j*y1/segments+i*y2/segments,0,
	(j-1)*x1/segments+(i+1)*x2/segments,
	(j-1)*y1/segments+(i+1)*y2/segments,0);
    dc->thick=w-2;
    dc->color=YELLOW;
    GrLine3(dc,
	j*x1/segments+i*x2/segments,
	j*y1/segments+i*y2/segments,0,
	(j-1)*x1/segments+(i+1)*x2/segments,
	(j-1)*y1/segments+(i+1)*y2/segments,0);
  }
  if (talon) {
    if (y1<y2)
      Sprite3B(dc,x1,y1,0,$IB,"<7>",BI=7$);
    else
      Sprite3B(dc,x1,y1,0,$IB,"<8>",BI=8$);
  }
}

U0 ClawsDraw(CTask *task,CDC *dc)
{
  F64 claws_up=1.0-claws_down;
  I64 w=task->pix_width,h=task->pix_height;
  dc->flags|=DCF_SYMMETRY;
  DCSymmetrySet(dc,w>>1,0,w>>1,1);

  ClawDraw(dc,HAND_X-30,HAND_Y-50*claws_up,HAND_X-5,HAND_Y,	22,4,TRUE);
  ClawDraw(dc,HAND_X-10,HAND_Y-60*claws_up,HAND_X,HAND_Y,	22,4,TRUE);
  ClawDraw(dc,HAND_X+10,HAND_Y-60*claws_up,HAND_X,HAND_Y,	22,4,TRUE);
  ClawDraw(dc,HAND_X+30,HAND_Y-50*claws_up,HAND_X+5,HAND_Y,	22,4,TRUE);
  ClawDraw(dc,HAND_X+25,HAND_Y+40*claws_up,HAND_X+5,HAND_Y,	22,4,TRUE);

  ClawDraw(dc,HAND_X,HAND_Y,6*w/20,h,38,5,FALSE);
}

CDC *main_dc,*front_dc;
I64 front_lock;

U0 FrontSwap()
{
  while (LBts(&front_lock,0))
    Yield;
  MemCpy(front_dc->body,main_dc->body,
	main_dc->width_internal*main_dc->height);
  LBtr(&front_lock,0);
}

U0 DrawIt(CTask *task,CDC *dc)
{
  while (LBts(&front_lock,0))
    Yield;
  front_dc->flags|=DCF_NO_TRANSPARENTS;
  GrBlot(dc,0,0,front_dc);
  LBtr(&front_lock,0);
  if (bird_mode && !bird_zoom && claws_down)
    ClawsDraw(task,dc);
}

/*
$SP,"<9>",BI=9$


















$SP,"<10>",BI=10$
































Cores render strips that +/- 15%. The cores check the panel map array
and render the panel for each square, marking-it done.

The depth buf is not locked in the graphic routines
so we get some glitches.
*/

#define RENDER_JIFFIES	(JIFFY_FREQ/50)
I64 update_jiffy_limit;

Bool TreeBlocksView(F64 tx,F64 ty)
{
  F64 cx=cam_x>>COORDINATE_BITS,cy=cam_y>>COORDINATE_BITS,
	bx=cx+WrapDelta(boat_x-cx,WORLD_WIDTH),by=cy+WrapDelta(boat_y-cy,WORLD_HEIGHT),
	vx=bx-cx,vy=by-cy,wx=tx-cx,wy=ty-cy,l2=vx*vx+vy*vy,t;
  if (l2<=0)
    return FALSE;
  t=Clamp((wx*vx+wy*vy)/l2,0.0,1.0);
  return Sqr(wx-t*vx)+Sqr(wy-t*vy)<Sqr(350);
}

I64 frame_num;

#define BOAT_TRIS_MAX		512
U16 boat_nz[LS_TYPES-1][BOAT_TRIS_MAX];

U0 BoatNormalsFind(I64 k)
{
  U8 *p=landscape_large_imgs[k],*tri;
  CD3I32 *v,*a,*b,*c;
  I64 i,t,vc,tc,n=0;
  F64 nx,ny,nz,d;
  while (t=*p&SPG_TYPE_MASK) {
    vc=-1;
    if (t==SPT_MESH) {
      vc=*(p+1)(I32 *);
      tc=*(p+5)(I32 *);
      v=p+9;
    } else if (t==SPT_SHIFTABLE_MESH) {
      vc=*(p+13)(I32 *);
      tc=*(p+17)(I32 *);
      v=p+21;
    }
    if (vc>=0) {
      tri=v(U8 *)+vc*sizeof(CD3I32);
      for (i=0;i<tc && n<BOAT_TRIS_MAX;i++,n++) {
	a=&v[*(tri+i*16+4)(I32 *)];
	b=&v[*(tri+i*16+8)(I32 *)];
	c=&v[*(tri+i*16+12)(I32 *)];
	nx=ToF64(b->y-a->y)*(c->z-a->z)-ToF64(b->z-a->z)*(c->y-a->y);
	ny=ToF64(b->z-a->z)*(c->x-a->x)-ToF64(b->x-a->x)*(c->z-a->z);
	nz=ToF64(b->x-a->x)*(c->y-a->y)-ToF64(b->y-a->y)*(c->x-a->x);
	if (d=Sqrt(nx*nx+ny*ny+nz*nz))
	  boat_nz[k][n]=65535*Abs(nz)/d;
	else
	  boat_nz[k][n]=65535;
      }
    }
    p+=SpriteElemSize(p-2*sizeof(U8 *));
  }
}

U0 MeshShade(CDC *dc,CColorROPU32 color,I64 nz)
{
  I64 i=65536+65536*0.6-nz;
  color.c0.rop&=~ROPBF_TWO_SIDED;
  if (color.c0.rop&ROPBF_HALF_RANGE_COLOR) {
    color.c0.rop&=~ROPBF_HALF_RANGE_COLOR;
    i>>=1;
    if (color>=8) {
      color-=8;
      i+=65536;
    }
  }
  if (i<65536) {
    dc->color=ROPF_PROBABILITY_DITHER+color<<16+BLACK;
    dc->dither_probability_u16=i;
  } else {
    dc->color=ROPF_PROBABILITY_DITHER+(color^8)<<16+color;
    dc->dither_probability_u16=i-65536;
  }
}

U0 BoatSprite3(CDC *dc,I64 x,I64 y,I64 z,U8 *img,I64 k)
{
  U8 *p=img,*tri;
  CD3I32 *v,pts[3];
  I64 i,j,t,vc,tc,n=0,idx,nz;
  F64 ax,ay,az,bx,by,bz,nx,ny,nn,d;
  CColorROPU32 old=dc->color;
  while (t=*p&SPG_TYPE_MASK) {
    if (t==SPT_MESH) {
      vc=*(p+1)(I32 *);
      tc=*(p+5)(I32 *);
      v=p+9;
      tri=v(U8 *)+vc*sizeof(CD3I32);
      for (i=0;i<tc;i++,n++) {
	for (j=0;j<3;j++) {
	  idx=*(tri+i*16+4+j*4)(I32 *);
	  pts[j].x=v[idx].x+x;
	  pts[j].y=v[idx].y+y;
	  pts[j].z=v[idx].z+z;
	}
	if (k>=0 && n<BOAT_TRIS_MAX)
	  nz=boat_nz[k][n];
	else {
	  ax=pts[1].x-pts[0].x; ay=pts[1].y-pts[0].y; az=pts[1].z-pts[0].z;
	  bx=pts[2].x-pts[0].x; by=pts[2].y-pts[0].y; bz=pts[2].z-pts[0].z;
	  nx=ay*bz-az*by;
	  ny=az*bx-ax*bz;
	  nn=ax*by-ay*bx;
	  if (d=Sqrt(nx*nx+ny*ny+nn*nn))
	    nz=65535*Abs(nn)/d;
	  else
	    nz=65535;
	}
	MeshShade(dc,*(tri+i*16)(I32 *),nz);
	PanelFill(dc,3,pts,0,0,0,dc->color);
      }
    }
    p+=SpriteElemSize(p-2*sizeof(U8 *));
  }
  dc->color=old;
}

U0 DrawCell(CDC *dc,I64 x1,I64 y1,I64 update)
{
  I64 xi,yi,tx,ty,ox,oy,k,slot,stamp;
  Panel *tmpp;
  Obj *tmpo;
  xi=x1&MAP_MASK_X;
  yi=y1&MAP_MASK_Y;
  if (tmpp=panels[yi][xi]) {
    tx=(x1-xi)/MAP_WIDTH;
    ty=(y1-yi)/MAP_HEIGHT;
    slot=(tx&1)|(ty&1)<<1;
    stamp=update|(tx&0xFF)<<16|(ty&0xFF)<<24;
    if (tmpp->update[slot]!=stamp) {
      tmpp->update[slot]=stamp;
      ox=tx*WORLD_WIDTH;
      oy=ty*WORLD_HEIGHT;
      if (tmpp->cnt[slot]>=0) {
	dc->color=tmpp->color;
	k=PanelFill(dc,tmpp->num_sides,tmpp->pts,ox,oy,tmpp->depth_bias,
	      tmpp->color);
	if (k)
	  tmpp->cnt[slot]=0;
	else
	  tmpp->cnt[slot]=-2;
      } else
	tmpp->cnt[slot]++;
      tmpo=tmpp->next_obj;
      while (tmpo!=&tmpp->next_obj) {
	if (tmpo->img && (tmpo->fish || bird_mode ||
	      !TreeBlocksView(tmpo->p.x+ox,tmpo->p.y+oy)))
	  if (tmpo->img==landscape_large_imgs[0])
	    BoatSprite3(dc,tmpo->p.x+ox,tmpo->p.y+oy,tmpo->p.z,tmpo->img,0);
	  else if (tmpo->img==landscape_large_imgs[1])
	    BoatSprite3(dc,tmpo->p.x+ox,tmpo->p.y+oy,tmpo->p.z,tmpo->img,1);
	  else
	    Sprite3(dc,tmpo->p.x+ox,tmpo->p.y+oy,tmpo->p.z,tmpo->img);
	tmpo=tmpo->next;
      }
    }
  }
}

U0 MPDrawIt(CTask *task,CDC *dc)
{
  I64 j,update=frame_num,strip_width,*s2w,x1,y1,z1,xx,yy,
	xh,yh,zh,yh2,xh2,x1h,y1h,x1wa,y1wa,x1wb,y1wb,x3,y3,z3,dd,dd_old,
	cx=task->pix_width>>1,cy=task->pix_height>>1,r[16],*elems1,*elems_hard,
	cwx,cwy,tx,ty,bx,by,k,cxx,cyy,vd=view_dist,band;
  Bird	*tmpb;
  Bool	w_on_map,h_on_map,time_up=FALSE;

  xx=cxx=cam_x/(MAP_SCALE*COORDINATE_SCALE);
  yy=cyy=cam_y/(MAP_SCALE*COORDINATE_SCALE);
  cwx=cam_x>>COORDINATE_BITS;
  cwy=cam_y>>COORDINATE_BITS;

  //World to scrn coordinates
  Mat4x4IdentEqu(dc->r);
  Mat4x4RotZ(dc->r,heading);
  Mat4x4RotX(dc->r,и);
  Mat4x4RotZ(dc->r,roll);
  DCMat4x4Set(dc,dc->r);

  //Scrn to world coordinates

  //This gives us the vects for stepping through the grid in
  //the direction the plane is facing. we step horizontally and vertically
  //and use the reciprocal slope principle
  //y=mx+b and y=(-1/m)x+b are perpendicular.

  s2w=Mat4x4IdentNew;
  Mat4x4RotZ(s2w,-roll);
  Mat4x4RotX(s2w,-и);
  Mat4x4RotZ(s2w,-heading);

  xh=0;
  yh=0;
  zh=-256;
  Mat4x4MulXYZ(s2w,&xh,&yh,&zh);

  //The layer for core1 is not cleared automatically
  //it is persistent.  I have carefully syncronized to the update
  //cycle initiated by Core0 to prevent flicker.

  dc->flags|=DCF_TRANSFORMATION;
  dc->transform=&EDTransform;
  dc->x=cx;
  dc->y=cy;

  //dc->x and the translation part of dc->r are ident in effect,
  //but we use both to show-off.	We could add offsets together and
  //use one or the other.

  x1=-cam_x>>COORDINATE_BITS;
  y1=-cam_y>>COORDINATE_BITS;
  z1=-cam_z>>COORDINATE_BITS;
  Mat4x4MulXYZ(dc->r,&x1,&y1,&z1);
  Mat4x4TranslationEqu(dc->r,x1,y1,z1);

  //This is a refinement.
  if (Abs(и*180/г)>90) {
    x3=0;
    y3=-cy;
    z3=0;
    Mat4x4MulXYZ(s2w,&x3,&y3,&z3);
    xx+=x3;
    yy+=y3;
  }

  band=Gs->num-render_first;
  if (SqrI64(xh)+SqrI64(yh)<Sqr(256*0.6) && zh<0) {
    j=MaxI64(cam_z>>COORDINATE_BITS-WATER_ELEVATION*MAP_SCALE,MAP_SCALE);
    x3=(cwx+xh*j/-zh)/MAP_SCALE;
    y3=(cwy+yh*j/-zh)/MAP_SCALE;
    k=ClampI64(j*4/MAP_SCALE+8,8,vd);
    for (y1=-k+band;y1<=k;y1+=render_cnt)
      for (x1=-k;x1<=k;x1++)
	if (-vd<x3+x1-cxx<vd && -vd<y3+y1-cyy<vd)
	  DrawCell(dc,x3+x1,y3+y1,update);
    strip_width=I64_MAX;
    goto steep_done;
  }
  if (band&1) {//alt left-right,right-left
    yh2=-yh;
    xh2=-xh;
  } else {
    yh2=yh;
    xh2=xh;
  }

  //Calc starting point.
  x1wa=xx<<8+xh*strip_height>>1/1.3*(band+1.15);
  y1wa=yy<<8+yh*strip_height>>1/1.3*(band+1.15);
  x1wb=0;
  y1wb=0;

  xh=-xh; //Back to front to help with depth.
  yh=-yh;

  //Take half steps to cover whole grid.
  xh>>=1;  yh>>=1;
  xh2>>=1; yh2>>=1;
  w_on_map=FALSE;
  dd_old=I64_MAX;
  for (strip_width=0;!time_up;strip_width++) {
    x1h=x1wa;
    y1h=y1wa;
    h_on_map=FALSE;
    for (j=0;j<strip_height;j++) {
      if (cnts.jiffies>=update_jiffy_limit) {
	time_up=TRUE;
	break;
      }
      x1=x1h>>8; y1=y1h>>8;
      if (-vd<x1-cxx<vd && -vd<y1-cyy<vd) {
	DrawCell(dc,x1,y1,update);
	h_on_map=TRUE;
      } else if (h_on_map)
	break;
      x1h+=xh;
      y1h+=yh;
    }
    if (h_on_map)
      w_on_map=TRUE;
    else if (w_on_map) {
      strip_width=I64_MAX;
      break;
    }
    x1wb-=yh2;
    y1wb+=xh2;
    if (strip_width&1) {
      x1wa-=x1wb;
      y1wa-=y1wb;
    } else {
      x1wa+=x1wb;
      y1wa+=y1wb;
    }
    if (!w_on_map) {
      dd=SqrI64(x1wa>>8-cxx)+SqrI64(y1wa>>8-cyy);
      if (dd>dd_old)
	break;
      dd_old=dd;
    }
  }

steep_done:
  vd*=MAP_SCALE;
  tmpb=b_head[Gs->num].next;
  while (tmpb!=&b_head[Gs->num]) {
    elems_hard=NULL;
    for (ty=-VIEW_TILES;ty<=VIEW_TILES;ty++)
      for (tx=-VIEW_TILES;tx<=VIEW_TILES;tx++) {
	bx=tmpb->p.x+tx*WORLD_WIDTH-cwx;
	by=tmpb->p.y+ty*WORLD_HEIGHT-cwy;
	if (-vd<bx<vd && -vd<by<vd) {
	  if (!elems_hard) {
	    elems1=SpriteInterpolate(Tri(tS,0.2),$IB,"<2>",BI=2$,$IB,"<3>",BI=3$);
	    Mat4x4IdentEqu(r);
	    Mat4x4RotZ(r,tmpb->й);
	    elems_hard=SpriteTransform(elems1,r);
	    Free(elems1);
	  }
	  BoatSprite3(dc,cwx+bx,cwy+by,tmpb->p.z,elems_hard,-1);
	}
      }
    Free(elems_hard);
    tmpb=tmpb->next;
  }

  Free(s2w);
  mp.strip_width[Gs->num]=strip_width;
  mp.time_up[Gs->num]=time_up;
  LBtr(&mp.update_not_done_flags,Gs->num);
}

U0 CoreAPTalonsTask(CTask *master_task)
{
  CDC *dc=DCAlias(main_dc,master_task);
  while (!mp.app_done) {
    while (!Bt(&mp.update_not_done_flags,Gs->num) && !mp.app_done)
      Sleep(1);
    if (!mp.app_done)
      MPDrawIt(master_task,dc);
  }

  //We made an alias of this we don't want freed.
  dc->depth_buf=NULL;

  DCDel(dc);
  LBtr(&mp.app_not_done_flags,Gs->num);
}

U0 DrawHorizon(CDC *dc)
{
  I64 x1,y1,z1,x2,y2,z2,xh,yh,zh,*s2w=Mat4x4IdentNew,
	cx=Fs->pix_width>>1,
	cy=Fs->pix_height>>1;
  CD3I32 p[4];
  I32 *old_db=dc->depth_buf;
  dc->depth_buf=NULL;
  CColorROPU32 ground_color;

  if (-г/4<=Wrap(и-г)<г/4)
    DCFill(dc,LTCYAN);
  else {
    if (z/COORDINATE_SCALE<(WATER_ELEVATION+3)*MAP_SCALE)
      ground_color=BLUE;
    else
      ground_color=LTGREEN;

    Mat4x4IdentEqu(dc->r);
    Mat4x4RotZ(dc->r,heading);
    Mat4x4RotX(dc->r,и);
    Mat4x4RotZ(dc->r,roll);

    DCMat4x4Set(dc,dc->r);
    dc->flags&=~DCF_TRANSFORMATION;
    dc->transform=&EDTransform;
    dc->x=cx;
    dc->y=cy;

    Mat4x4RotZ(s2w,-roll);
    Mat4x4RotX(s2w,-и);
    Mat4x4RotZ(s2w,-heading);

    xh=0;
    yh=0;
    zh=-256;
    Mat4x4MulXYZ(s2w,&xh,&yh,&zh);
    Free(s2w);

    x1=xh+yh*32; y1=yh-xh*32; z1=0;
    (*dc->transform)(dc,&x1,&y1,&z1);
    x2=xh-yh*32; y2=yh+xh*32; z2=0;
    (*dc->transform)(dc,&x2,&y2,&z2);
    DCClipLine(dc,&x1,&y1,&x2,&y2);

    MemSet(p,0,sizeof(p));
    if (x2<x1) {
      SwapI64(&x1,&x2);
      SwapI64(&y1,&y2);
    }
    if (!x1 && x2==dc->width-1) {
      p[0].x=0;
      p[0].y=0;
      p[1].x=dc->width-1;
      p[1].y=0;
      p[2].x=dc->width-1;
      p[2].y=y2;
      p[3].x=0;
      p[3].y=y1;
      if (rolled_over)
	dc->color=ground_color;
      else
	dc->color=LTCYAN;
      GrFillPoly3(dc,4,p);
      p[0].y=dc->height-1;
      p[1].y=dc->height-1;
      if (rolled_over)
	dc->color=LTCYAN;
      else
	dc->color=ground_color;
      GrFillPoly3(dc,4,p);
    } else {
      if (y2<y1) {
	SwapI64(&x1,&x2);
	SwapI64(&y1,&y2);
      }
      if (!y1 && y2==dc->height-1) {
	p[0].x=0;
	p[0].y=0;
	p[1].x=0;
	p[1].y=dc->height-1;
	p[2].x=x2;
	p[2].y=dc->height-1;
	p[3].x=x1;
	p[3].y=0;
	if (x1<x2 ^^ rolled_over)
	  dc->color=ground_color;
	else
	  dc->color=LTCYAN;
	GrFillPoly3(dc,4,p);
	p[0].x=dc->width-1;
	p[1].x=dc->width-1;
	if (x1<x2 ^^ rolled_over)
	  dc->color=LTCYAN;
	else
	  dc->color=ground_color;
	GrFillPoly3(dc,4,p);
      } else
	if (zh<0)
	  DCFill(dc,ground_color);
	else
	  DCFill(dc,LTCYAN);
    }
  }

  dc->depth_buf=old_db;
}

U0 BoatFwd(F64 h,F64 *fx,F64 *fy)
{
  I64 *s2w=Mat4x4IdentNew,dx=0,dy=0,dz=1<<16;
  Mat4x4RotX(s2w,г/2);
  Mat4x4RotZ(s2w,-h);
  Mat4x4MulXYZ(s2w,&dx,&dy,&dz);
  Free(s2w);
  *fx=-dx/ToF64(1<<16);
  *fy=-dy/ToF64(1<<16);
}

Bool WaterCellAt(F64 wx,F64 wy)
{
  I64 i=ToI64(Floor(wx/MAP_SCALE))&MAP_MASK_X,
	j=ToI64(Floor(wy/MAP_SCALE))&MAP_MASK_Y,w=WATER_ELEVATION*MAP_SCALE;
  return elevations[j][i]<=w && elevations[j][(i+1)&MAP_MASK_X]<=w &&
	elevations[(j+1)&MAP_MASK_Y][i]<=w &&
	elevations[(j+1)&MAP_MASK_Y][(i+1)&MAP_MASK_X]<=w;
}

Bool HullFits(F64 bx,F64 by,F64 h)
{
  F64 fx,fy,u,v,l=boat_len*0.85/2,b=boat_beam*0.85/2;
  I64 i,j;
  BoatFwd(h,&fx,&fy);
  bx+=fx*boat_ctr;
  by+=fy*boat_ctr;
  for (i=-4;i<=4;i++)
    for (j=-1;j<=1;j++) {
      u=l*i/4;
      v=b*j;
      if (!WaterCellAt(bx+u*fx-v*fy,by+u*fy+v*fx))
	return FALSE;
    }
  return TRUE;
}

U0 CamFromBoat()
{
  F64 fx,fy,cx,cy,a0=Arg(CAM_BACK,CAM_UP),a,dist,back,up;
  I64 i,j,ground;
  if (boat_fp) {
    BoatFwd(boat_heading,&fx,&fy);
    cx=boat_x+fx*(boat_ctr+boat_len/5);
    cy=boat_y+fy*(boat_ctr+boat_len/5);
    x=WrapCoord(cx*COORDINATE_SCALE,WORLD_WIDTH*COORDINATE_SCALE);
    y=WrapCoord(cy*COORDINATE_SCALE,WORLD_HEIGHT*COORDINATE_SCALE);
    z=(WATER_ELEVATION*MAP_SCALE+2*MAP_SCALE+450)*COORDINATE_SCALE;
    heading=boat_heading;
    и=0.12-г/2;
    roll=0;
    WrapAngles;
    return;
  }
  a=Clamp(a0+cam_elev,CAM_ELEV_MIN,CAM_ELEV_MAX);
  dist=Sqrt(Sqr(CAM_BACK)+Sqr(CAM_UP))*cam_zoom;
  back=dist*Cos(a);
  up=dist*Sin(a);
  BoatFwd(boat_heading+cam_orbit,&fx,&fy);
  cx=boat_x-fx*back;
  cy=boat_y-fy*back;
  i=ToI64(Floor(cx/MAP_SCALE))&MAP_MASK_X;
  j=ToI64(Floor(cy/MAP_SCALE))&MAP_MASK_Y;
  ground=MaxI64(elevations[j][i],elevations[j][(i+1)&MAP_MASK_X]);
  ground=MaxI64(ground,elevations[(j+1)&MAP_MASK_Y][i]);
  ground=MaxI64(ground,elevations[(j+1)&MAP_MASK_Y][(i+1)&MAP_MASK_X]);
  ground=Max(ground+up/2,WATER_ELEVATION*MAP_SCALE+(2*MAP_SCALE)+up);
  x=WrapCoord(cx*COORDINATE_SCALE,WORLD_WIDTH*COORDINATE_SCALE);
  y=WrapCoord(cy*COORDINATE_SCALE,WORLD_HEIGHT*COORDINATE_SCALE);
  z=ground*COORDINATE_SCALE;
  heading=Wrap(boat_heading+cam_orbit,0);
  и=-((-0.6)-(a-a0))-г/2;
  roll=0;
  WrapAngles;
}

Obj *FishFind(F64 x1,F64 y1,F64 *_d)
{
  F64 dd,best_dd=F64_MAX;
  Obj *res=NULL,*tmpo;
  I64 i;
  for (i=0;i<fish_cnt;i++) {
    tmpo=fish_list[i];
    if (tmpo->fish) {
      dd=Sqr(WrapDelta(tmpo->p.x-x1,WORLD_WIDTH))+
	    Sqr(WrapDelta(tmpo->p.y-y1,WORLD_HEIGHT));
      if (dd<best_dd) {
	best_dd=dd;
	res=tmpo;
      }
    }
  }
  *_d=Sqrt(best_dd);
  return res;
}

U0 DrawBoat(CDC *dc)
{
  I64 *r,x1,y1,z1,cwx=cam_x>>COORDINATE_BITS,cwy=cam_y>>COORDINATE_BITS;
  F64 fx,fy;
  U8 *img;
  Mat4x4IdentEqu(dc->r);
  Mat4x4RotZ(dc->r,heading);
  Mat4x4RotX(dc->r,и);
  Mat4x4RotZ(dc->r,roll);
  DCMat4x4Set(dc,dc->r);
  dc->flags|=DCF_TRANSFORMATION;
  dc->transform=&EDTransform;
  dc->x=Fs->pix_width>>1;
  dc->y=Fs->pix_height>>1;
  x1=-cam_x>>COORDINATE_BITS;
  y1=-cam_y>>COORDINATE_BITS;
  z1=-cam_z>>COORDINATE_BITS;
  Mat4x4MulXYZ(dc->r,&x1,&y1,&z1);
  Mat4x4TranslationEqu(dc->r,x1,y1,z1);
  if (bird_mode && bird_zoom) {
    I64 *s2w=Mat4x4IdentNew,dx=0,dy=0,dz=1<<16;
    U8 *e1;
    Mat4x4RotZ(s2w,-fl_roll);
    Mat4x4RotX(s2w,-fl_phi);
    Mat4x4RotZ(s2w,-fl_heading);
    Mat4x4MulXYZ(s2w,&dx,&dy,&dz);
    Free(s2w);
    e1=SpriteInterpolate(Tri(tS,0.2),$IB,"<2>",BI=2$,$IB,"<3>",BI=3$);
    r=Mat4x4IdentNew;
    Mat4x4Scale(r,3.0);
    Mat4x4RotX(r,bird_bank);
    Mat4x4RotY(r,-Arg(Sqrt(ToF64(dx)*dx+ToF64(dy)*dy),-dz));
    Mat4x4RotZ(r,Arg(-dx,-dy));
    img=SpriteTransform(e1,r);
    BoatSprite3(dc,cwx+WrapDelta(x/COORDINATE_SCALE-cwx,WORLD_WIDTH),
	  cwy+WrapDelta(y/COORDINATE_SCALE-cwy,WORLD_HEIGHT),z/COORDINATE_SCALE,img,-1);
    Free(img);
    Free(r);
    Free(e1);
  }
  if (!bird_mode) {
    BoatFwd(boat_heading,&fx,&fy);
    r=Mat4x4IdentNew;
    Mat4x4RotZ(r,Arg(fx,fy)-boat_bow[boat_img]);
    img=SpriteTransform(landscape_large_imgs[boat_img],r);
    BoatSprite3(dc,cwx+WrapDelta(boat_x-cwx,WORLD_WIDTH),
	  cwy+WrapDelta(boat_y-cwy,WORLD_HEIGHT),
	  WATER_ELEVATION*MAP_SCALE+(2*MAP_SCALE),img,boat_img);
    Free(img);
    Free(r);
  }
  dc->flags&=~DCF_TRANSFORMATION;
}

extern F64 HeadingFor(F64 fx,F64 fy);

U0 BirdCam()
{
  I64 *s2w=Mat4x4IdentNew,dx=0,dy=0,dz=1<<16,i,j,ground;
  F64 fx,fy,el,cx,cy,cz,yaw;
  fl_heading=heading;
  fl_phi=и;
  fl_roll=roll;
  Mat4x4RotZ(s2w,-roll);
  Mat4x4RotX(s2w,-и);
  Mat4x4RotZ(s2w,-heading);
  Mat4x4MulXYZ(s2w,&dx,&dy,&dz);
  Free(s2w);
  if (dx || dy)
    yaw=HeadingFor(-dx,-dy);
  else
    yaw=heading;
  cam_h=Wrap(yaw+bird_orbit,0);
  el=Clamp(BIRD_CAM_ELEV0+bird_elev,CAM_ELEV_MIN,CAM_ELEV_MAX);
  cam_p=el-г/2;
  BoatFwd(cam_h,&fx,&fy);
  cx=x/COORDINATE_SCALE-fx*bird_zoom*Cos(el);
  cy=y/COORDINATE_SCALE-fy*bird_zoom*Cos(el);
  cz=z/COORDINATE_SCALE+bird_zoom*Sin(el);
  i=ToI64(Floor(cx/MAP_SCALE))&MAP_MASK_X;
  j=ToI64(Floor(cy/MAP_SCALE))&MAP_MASK_Y;
  ground=MaxI64(elevations[j][i],elevations[j][(i+1)&MAP_MASK_X]);
  ground=MaxI64(ground,elevations[(j+1)&MAP_MASK_Y][i]);
  ground=MaxI64(ground,elevations[(j+1)&MAP_MASK_Y][(i+1)&MAP_MASK_X]);
  cz=Max(cz,ground+MAP_SCALE);
  cam_x=WrapCoord(cx*COORDINATE_SCALE,WORLD_WIDTH*COORDINATE_SCALE);
  cam_y=WrapCoord(cy*COORDINATE_SCALE,WORLD_HEIGHT*COORDINATE_SCALE);
  cam_z=cz*COORDINATE_SCALE;
}

U0 Core0Talons()
{
  CDC *dc=DCAlias(main_dc,Fs);
  I64 i,frame_jiffy,xx,yy,elev,height,cx=Fs->pix_width>>1,cy=Fs->pix_height>>1;
  Bool cam_swap;
  Bool late;
  F64 min_strip_width,tt;

  frame_jiffy=cnts.jiffies;
  update_jiffy_limit=frame_jiffy+4*RENDER_JIFFIES;

  cam_x=x; cam_y=y; cam_z=z;

  xx=(cam_x/(MAP_SCALE*COORDINATE_SCALE))&MAP_MASK_X;
  yy=(cam_y/(MAP_SCALE*COORDINATE_SCALE))&MAP_MASK_Y;
  elev=elevations[yy][xx];
  height=cam_z/COORDINATE_SCALE-elev;
  if (cam_swap=bird_mode && bird_zoom) {
    while (LBts(&anim_lock,0))
      Yield;
    BirdCam;
    heading=cam_h;
    и=cam_p;
    roll=0;
    WrapAngles;
  }
  if (bird_mode && height<0 && elev>WATER_ELEVATION*MAP_SCALE && !game_tf) {
    music.mute=TRUE;
    Beep;
    game_tf=tS;
    crashed=TRUE;
    music.mute=FALSE;
  }

  DrawHorizon(dc);

  DCDepthBufRst(dc);
  if (!(++frame_num&0xFFFF))
    frame_num++;
  frame_num&=0xFFFF;
  mp.update_not_done_flags=(1<<mp_cnt)-(1<<render_first);
  if (!render_first)
    MPDrawIt(Fs,dc);
  while (mp.update_not_done_flags)
    Sleep(1);

  late=cnts.jiffies-frame_jiffy>RENDER_JIFFIES;
  for (i=render_first;i<mp_cnt;i++)
    if (mp.time_up[i])
      late=TRUE;
  if (late)
    view_dist=MaxI64(128,view_dist-view_dist/16);
  else if (cnts.jiffies-frame_jiffy<RENDER_JIFFIES/2)
    view_dist=MinI64(1024,view_dist+4);

  min_strip_width=F64_MAX;
  for (i=render_first;i<mp_cnt;i++)
    min_strip_width=Min(min_strip_width,
	  32.0*mp.strip_width[i]/(i-render_first+32.0));
  strip_height=ClampI64(
	strip_height*Clamp(0.25*min_strip_width/strip_height,0.9,1.1),
	64,1024);

  DrawBoat(dc);
  if (cam_swap) {
    heading=fl_heading;
    и=fl_phi;
    roll=fl_roll;
    WrapAngles;
    LBtr(&anim_lock,0);
  }

  if (game_tf) {
    tt=game_tf-game_t0;
    if (Blink) {
      if (crashed) {
	dc->color=RED;
	GrPrint(dc,(Fs->pix_width-26*FONT_WIDTH)/2,
	      (Fs->pix_height-FONT_HEIGHT)/2-4*FONT_HEIGHT,
	      "Crashed! <ENTER> to restart");
      } else {
	dc->color=YELLOW;
	GrPrint(dc,(Fs->pix_width-30*FONT_WIDTH)/2,
	      (Fs->pix_height-FONT_HEIGHT)/2-4*FONT_HEIGHT,
	      "All fish caught! <ENTER> again");
      }
    }
  } else {
    tt=tS-game_t0;
    if (tt<5.0 && Blink) {
      dc->color=WHITE;
      GrPrint(dc,(Fs->pix_width-38*FONT_WIDTH)/2,
	    (Fs->pix_height-FONT_HEIGHT)/2-4*FONT_HEIGHT,
	    "Catch 10 Fish by Bird, 20 Fish by Boat");
    }
  }

  dc->color=BLUE;
  GrRect(dc,0,0,Fs->pix_width,FONT_HEIGHT);
  dc->color=WHITE;
  if (!bird_mode)
    height=0;
  if (bird_mode)
    i=fish_left_bird;
  else
    i=fish_left_boat;
  GrPrint(dc,0,0,"Fish Remaining:%d Time:%3.2f Best:%3.2f Height:%5d",
	i,tt,best_score,height);
  GrPrint(dc,Fs->pix_width-8*FONT_WIDTH,0,"H - Help");
  if (bird_mode) {
    dc->color=BLACK;
    dc->thick=2;
    GrLine3(dc,cx+5,cy,0,cx-5,cy,0);
    GrLine3(dc,cx,cy+5,0,cx,cy-5,0);
    dc->thick=1;
  }

  dc->depth_buf=NULL;
  DCDel(dc);
  FrontSwap;
  Refresh;
}

U0 FishListMake()
{
  Panel *tmpp=panel_head;
  Obj *tmpo;
  I64 n=0;
  while (tmpp) {
    tmpo=tmpp->next_obj;
    while (tmpo!=&tmpp->next_obj) {
      if (tmpo->fish) n++;
      tmpo=tmpo->next;
    }
    tmpp=tmpp->next;
  }
  fish_list=MAlloc((n+1)*sizeof(Obj *));
  fish_cnt=0;
  tmpp=panel_head;
  while (tmpp) {
    tmpo=tmpp->next_obj;
    while (tmpo!=&tmpp->next_obj) {
      if (tmpo->fish)
	fish_list[fish_cnt++]=tmpo;
      tmpo=tmpo->next;
    }
    tmpp=tmpp->next;
  }
}

U0 FishCaught(Obj *tmpo)
{
  tmpo->fish=FALSE;
  tmpo->img=NULL;
  if (bird_mode) {
    if (fish_left_bird)
      fish_left_bird--;
  } else if (fish_left_boat)
    fish_left_boat--;
  if (!fish_left_bird && !fish_left_boat && !game_tf) {
    game_tf=tS;
    boat_speed=0;
    if (game_tf-game_t0<best_score)
      best_score=game_tf-game_t0;
  }
  music.mute=TRUE;
  Snd(74); Sleep(100); Snd;
  music.mute=FALSE;
}

U0 BoatCatch()
{
  F64 fx,fy,d,hx,hy;
  Obj *tmpo;
  BoatFwd(boat_heading,&fx,&fy);
  hx=boat_x+fx*boat_ctr;
  hy=boat_y+fy*boat_ctr;
  while ((tmpo=FishFind(hx,hy,&d)) && d<boat_len/2)
    FishCaught(tmpo);
}

U0 BoatMove(F64 ms)
{
  F64 fx,fy,nx,ny,d=boat_speed*ms;
  if (!d) return;
  BoatFwd(boat_heading,&fx,&fy);
  nx=boat_x+fx*d;
  ny=boat_y+fy*d;
  if (HullFits(nx,ny,boat_heading)) {
    boat_x=nx;
    boat_y=ny;
  } else if (HullFits(nx,boat_y,boat_heading)) {
    boat_x=nx;
    boat_speed*=0.7;
  } else if (HullFits(boat_x,ny,boat_heading)) {
    boat_y=ny;
    boat_speed*=0.7;
  } else
    boat_speed=0;
  boat_x=WrapCoord(boat_x,WORLD_WIDTH);
  boat_y=WrapCoord(boat_y,WORLD_HEIGHT);
}

U0 BoatTurn(F64 da)
{
  if (HullFits(boat_x,boat_y,boat_heading+da))
    boat_heading=Wrap(boat_heading+da,0);
}

U0 BirdFly(F64 ms)
{
  I64 *s2w,x1,y1,z1,dx,dy,dz;
  F64 й,d;
  Obj *tmpo;
  s2w=Mat4x4IdentNew;
  Mat4x4RotZ(s2w,-roll);
  Mat4x4RotX(s2w,-и);
  Mat4x4RotZ(s2w,-heading);
  dx=0;dy=0;dz=1<<16;
  Mat4x4MulXYZ(s2w,&dx,&dy,&dz);
  x=WrapCoord(x-speed*ms*COORDINATE_SCALE*dx/1<<16,
	WORLD_WIDTH*COORDINATE_SCALE);
  y=WrapCoord(y-speed*ms*COORDINATE_SCALE*dy/1<<16,
	WORLD_HEIGHT*COORDINATE_SCALE);
  z-=speed*ms*COORDINATE_SCALE*dz/1<<16;
  Free(s2w);
  x1=x/COORDINATE_SCALE; y1=y/COORDINATE_SCALE; z1=z/COORDINATE_SCALE;
  if (z1<(WATER_ELEVATION+3)*MAP_SCALE) {
    if (z1<WATER_ELEVATION*MAP_SCALE) {
      z=WATER_ELEVATION*MAP_SCALE*COORDINATE_SCALE;
      if (invert_pitch) {
	if (pitch<-г/8)
	  и+=ms/1000.0*Sign(3*г/8-и);
      } else if (pitch<-г/8)
	и+=ms/1000.0*Sign(-3*г/8-и);
      WrapAngles;
    }
    speed=1.0;
    if (rolled_over || !(tmpo=FishFind(x1,y1,&d)))
      claws_down=0;
    else {
      x1=WrapDelta(x1-tmpo->p.x,WORLD_WIDTH);
      y1=WrapDelta(y1-tmpo->p.y,WORLD_HEIGHT);
      й=ACos((dx*x1+dy*y1)/(d*1<<16));
      if (й>0 && d<MAP_SCALE*4)
	claws_down=Saw(d,MAP_SCALE*4);
      else
	claws_down=0.01;
      if (d<MAP_SCALE*2)
	FishCaught(tmpo);
    }
  } else {
    claws_down=0;
    if (-г/4<=и<=г/4)
      speed+=0.0005;
    else if (-3*г/4<=и<=3*г/4)
      speed+=0.0001;
    else
      speed-=0.0001;
    speed=Clamp(speed+(0.0005-0.0002*Abs(и)/(г/4)),0.1,5.0);
  }
}

F64 HeadingFor(F64 fx,F64 fy)
{
  F64 x0,y0,x1,y1,h0,s;
  BoatFwd(0,&x0,&y0);
  BoatFwd(0.1,&x1,&y1);
  h0=Arg(x0,y0);
  s=Sign(Wrap(Arg(x1,y1)-h0));
  return Wrap((Arg(fx,fy)-h0)*s,0);
}

I64 BirdAheadMax(F64 bx,F64 by,F64 th)
{
  I64 i,j,c,e=0;
  F64 fx=Cos(th)*MAP_SCALE,fy=Sin(th)*MAP_SCALE;
  for (c=0;c<=64;c++) {
    i=ToI64(Floor((bx+fx*c)/MAP_SCALE))&MAP_MASK_X;
    j=ToI64(Floor((by+fy*c)/MAP_SCALE))&MAP_MASK_Y;
    e=MaxI64(e,elevations[j][i]);
    e=MaxI64(e,elevations[j][(i+1)&MAP_MASK_X]);
    e=MaxI64(e,elevations[(j+1)&MAP_MASK_Y][i]);
    e=MaxI64(e,elevations[(j+1)&MAP_MASK_Y][(i+1)&MAP_MASK_X]);
  }
  return e;
}

U0 PlayerToBird()
{
  I64 i,n=0,k,clear,best_clear=I64_MIN,start_z;
  Bird *tmpb,**birds,*best=NULL;
  Obj *tmpo;
  Panel *tmpp;
  for (i=0;i<mp_cnt;i++) {
    tmpb=b_head[i].next;
    while (tmpb!=&b_head[i]) {
      n++;
      tmpb=tmpb->next;
    }
  }
  if (!n)
    return;
  birds=MAlloc(n*sizeof(Bird *));
  n=0;
  for (i=0;i<mp_cnt;i++) {
    tmpb=b_head[i].next;
    while (tmpb!=&b_head[i]) {
      birds[n++]=tmpb;
      tmpb=tmpb->next;
    }
  }
  while (n) {
    k=RandU32%n;
    tmpb=birds[k];
    birds[k]=birds[--n];
    clear=tmpb->p.z+MAP_SCALE-BirdAheadMax(tmpb->p.x,tmpb->p.y,tmpb->й);
    if (clear>=(2*MAP_SCALE)) {
      best=tmpb;
      break;
    }
    if (clear>best_clear) {
      best_clear=clear;
      best=tmpb;
    }
  }
  Free(birds);
  tmpb=best;
  start_z=MaxI64(tmpb->p.z+MAP_SCALE,
	BirdAheadMax(tmpb->p.x,tmpb->p.y,tmpb->й)+(2*MAP_SCALE));
  QueRem(tmpb);
  tmpo=MAlloc(sizeof(Obj));
  tmpo->p.x=WrapCoord(boat_x,WORLD_WIDTH);
  tmpo->p.y=WrapCoord(boat_y,WORLD_HEIGHT);
  tmpo->p.z=(WATER_ELEVATION+2)*MAP_SCALE;
  tmpo->fish=FALSE;
  tmpo->img=landscape_large_imgs[boat_img];
  tmpp=panels[(tmpo->p.y/MAP_SCALE)&MAP_MASK_Y][(tmpo->p.x/MAP_SCALE)&MAP_MASK_X];
  if (tmpp)
    QueIns(tmpo,tmpp->last_obj);
  else
    Free(tmpo);
  x=WrapCoord(tmpb->p.x*COORDINATE_SCALE,WORLD_WIDTH*COORDINATE_SCALE);
  y=WrapCoord(tmpb->p.y*COORDINATE_SCALE,WORLD_HEIGHT*COORDINATE_SCALE);
  z=start_z*COORDINATE_SCALE;
  heading=HeadingFor(Cos(tmpb->й),Sin(tmpb->й));
  и=-г/2;
  roll=0;
  speed=1.5;
  claws_down=0;
  WrapAngles;
  Free(tmpb);
  bird_mode=TRUE;
}

U0 PlayerToBoat()
{
  I64 n=0,k,i;
  Panel *tmpp;
  Obj *tmpo,*pick=NULL,**boats;
  Bird *tmpb;
  I64 *s2w,dx=0,dy=0,dz=1<<16;
  F64 h,h0=0;
  tmpp=panel_head;
  while (tmpp) {
    tmpo=tmpp->next_obj;
    while (tmpo!=&tmpp->next_obj) {
      if (!tmpo->fish && (tmpo->img==landscape_large_imgs[0] ||
	    tmpo->img==landscape_large_imgs[1]))
	n++;
      tmpo=tmpo->next;
    }
    tmpp=tmpp->next;
  }
  if (!n)
    return;
  boats=MAlloc(n*sizeof(Obj *));
  n=0;
  tmpp=panel_head;
  while (tmpp) {
    tmpo=tmpp->next_obj;
    while (tmpo!=&tmpp->next_obj) {
      if (!tmpo->fish && (tmpo->img==landscape_large_imgs[0] ||
	    tmpo->img==landscape_large_imgs[1]))
	boats[n++]=tmpo;
      tmpo=tmpo->next;
    }
    tmpp=tmpp->next;
  }
  while (n && !pick) {
    k=RandU32%n;
    tmpo=boats[k];
    boats[k]=boats[--n];
    if (tmpo->img==landscape_large_imgs[0])
      BoatSetImg;
    else
      BoatSetImg(1);
    h0=HeadingFor(Cos(boat_bow[boat_img]),Sin(boat_bow[boat_img]));
    for (i=0;i<16;i++) {
      h=Wrap(h0+i*г/8,0);
      if (HullFits(tmpo->p.x,tmpo->p.y,h)) {
	pick=tmpo;
	h0=h;
	break;
      }
    }
  }
  Free(boats);
  if (!pick)
    return;
  tmpb=CAlloc(sizeof(Bird));
  tmpb->p.x=x/COORDINATE_SCALE;
  tmpb->p.y=y/COORDINATE_SCALE;
  tmpb->p.z=z/COORDINATE_SCALE;
  s2w=Mat4x4IdentNew;
  Mat4x4RotZ(s2w,-roll);
  Mat4x4RotX(s2w,-и);
  Mat4x4RotZ(s2w,-heading);
  Mat4x4MulXYZ(s2w,&dx,&dy,&dz);
  Free(s2w);
  if (dx || dy)
    tmpb->й=Arg(-dx,-dy);
  else
    tmpb->й=2*г*Rand;
  tmpb->lift=tmpb->p.z-BIRD_ELEVATION*MAP_SCALE-
	elevations[(tmpb->p.y/MAP_SCALE)&MAP_MASK_Y][(tmpb->p.x/MAP_SCALE)&MAP_MASK_X];
  tmpb->climb_ms=3000;
  QueIns(tmpb,b_head[render_first+RandU16%render_cnt].last);
  boat_x=pick->p.x;
  boat_y=pick->p.y;
  boat_heading=h0;
  boat_speed=0;
  QueRem(pick);
  Free(pick);
  claws_down=0;
  bird_mode=FALSE;
}

U0 SwitchPlayer()
{
  while (LBts(&anim_lock,0))
    Yield;
  if (!game_tf) {
    if (bird_mode)
      PlayerToBoat;
    else
      PlayerToBird;
  }
  LBtr(&anim_lock,0);
}

#define ANIMATE_MS	10

U0 AnimateTask(I64)
{
  I64 i;
  F64 t0=tS,ms;
  Bird	*tmpb;
  while (TRUE) {
    while (LBts(&anim_lock,0))
      Sleep(1);
    {
      ms=Min(1000*(tS-t0),100.0);
      t0=tS;
      bird_bank-=bird_bank*Min(1.0,ms/300.0);
      if (!game_tf) {
	if (bird_mode)
	  BirdFly(ms);
	else {
	  BoatMove(ms);
	  BoatCatch;
	}
      }
      if (!bird_mode)
	CamFromBoat;
      for (i=0;i<mp_cnt;i++) {
	tmpb=b_head[i].next;
	while (tmpb!=&b_head[i]) {
	  tmpb->p.x=WrapCoord(tmpb->p.x+10*ms/1000*MAP_SCALE*Cos(tmpb->й),
		WORLD_WIDTH);
	  tmpb->p.y=WrapCoord(tmpb->p.y+10*ms/1000*MAP_SCALE*Sin(tmpb->й),
		WORLD_HEIGHT);
	  if (tmpb->climb_ms>0) {
	    tmpb->climb_ms-=ms;
	    tmpb->lift+=3.0*ms;
	  } else {
	    tmpb->lift=Max(0.0,tmpb->lift-0.3*ms);
	    tmpb->й+=2*г*ms/1000/10;
	  }
	  tmpb->p.z=BIRD_ELEVATION*MAP_SCALE+tmpb->lift+
		elevations[(tmpb->p.y/MAP_SCALE)&MAP_MASK_Y][(tmpb->p.x/MAP_SCALE)&MAP_MASK_X];
	  tmpb=tmpb->next;
	}
      }
      LBtr(&anim_lock,0);
    }
    Refresh;
  }
}

U0 MPEnd()
{
  update_jiffy_limit=0;
  mp.app_not_done_flags=1<<mp_cnt-1-1;
  mp.app_done=TRUE;
//Wait for all cores to exit
  while (mp.app_not_done_flags)
    Sleep(1);
}

U0 TaskEndCB()
{
  MPEnd;
  Exit;
}

U0 SongTask(I64)
{
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  while (TRUE) {
    Play("5eCGFsD4A5e.C4sG5eGDqCDeGsGG4qG");
    Play("5eCGFsD4A5e.C4sG5eGDqCDeGsGG4qG");
    Play("5eGECGC4A5FCsC4B5C4B5e.GsG4qGB");
    Play("5eGECGC4A5FCsC4B5C4B5e.GsG4qGB");
  }
}

U0 PreInit()
{
  I64 i,*r=Mat4x4IdentNew,min_x,max_x,min_y,max_y;
  Mat4x4Scale(r,10.0);
  for (i=0;i<LS_TYPES;i++)
    landscape_large_imgs[i]=SpriteTransform(landscape_small_imgs[i],r);
  for (i=0;i<LS_TYPES-1;i++)
    BoatNormalsFind(i);
  Mat4x4IdentEqu(r);
  Mat4x4Scale(r,3.0);
  fish_img=SpriteTransform($IB,"<1>",BI=1$,r);
  Free(r);
  for (i=0;i<2;i++) {
    SpriteExtents(landscape_large_imgs[i],&min_x,&max_x,&min_y,&max_y);
    if (max_y-min_y>=max_x-min_x) {
      boat_lens[i]=max_y-min_y;
      boat_beams[i]=max_x-min_x;
      if (max_y>=-min_y) {
	boat_bow[i]=г/2;
	boat_ctrs[i]=(max_y+min_y)/2.0;
      } else {
	boat_bow[i]=-г/2;
	boat_ctrs[i]=-(max_y+min_y)/2.0;
      }
    } else {
      boat_lens[i]=max_x-min_x;
      boat_beams[i]=max_y-min_y;
      if (max_x>=-min_x) {
	boat_bow[i]=0;
	boat_ctrs[i]=(max_x+min_x)/2.0;
      } else {
	boat_bow[i]=г;
	boat_ctrs[i]=-(max_x+min_x)/2.0;
      }
    }
  }
  BoatSetImg;
}

U0 PostCleanUp()
{
  I64 i;
  for (i=0;i<LS_TYPES;i++)
    Free(landscape_large_imgs[i]);
  Free(fish_img);
}

U0 Init()
{
  I64 i;
  Bird *tmpb;

  render_first=mp_cnt>1;
  render_cnt=mp_cnt-render_first;

  main_dc=DCNew(GR_WIDTH,GR_HEIGHT);
  front_dc=DCNew(GR_WIDTH,GR_HEIGHT);
  DCFill(front_dc,LTCYAN);
  front_lock=0;
  critical_section_flag=0;
  game_tf=0;

  MemSet(&mp,0,sizeof(MPCtrl));
  InitMap;
  SpaceBoats;
  FishListMake;
  DCDepthBufAlloc(main_dc);

  strip_height=128;

  fish_left_bird=10;
  fish_left_boat=20;
  boat_speed=0;
  BoatSetImg;
  boat_heading=0;
  for (i=0;i<MAP_CELLS;i++) {
    boat_x=(RandU32%MAP_WIDTH+0.5)*MAP_SCALE;
    boat_y=(RandU32%MAP_HEIGHT+0.5)*MAP_SCALE;
    if (HullFits(boat_x,boat_y,boat_heading))
      break;
  }
  CamFromBoat;

  bird_mode=TRUE;
  crashed=FALSE;
  и=-90.0*г/180.0;
  roll=0;
  heading=0;
  speed=2.5;
  claws_down=0;
  WrapAngles;
  x=MAP_WIDTH>>1 *COORDINATE_SCALE*MAP_SCALE;
  y=MAP_HEIGHT>>1*COORDINATE_SCALE*MAP_SCALE;
  z=(64*MAP_SCALE+elevations[MAP_HEIGHT>>1][MAP_WIDTH>>1])*COORDINATE_SCALE;

  for (i=0;i<mp_cnt;i++)
    QueInit(&b_head[i]);

  for (i=0;i<B_NUM;i++) {
    tmpb=CAlloc(sizeof(Bird));
    tmpb->p.x=Rand*MAP_WIDTH*MAP_SCALE;
    tmpb->p.y=Rand*MAP_HEIGHT*MAP_SCALE;
    tmpb->p.z=BIRD_ELEVATION*MAP_SCALE+
	  elevations[tmpb->p.y/MAP_SCALE][tmpb->p.x/MAP_SCALE];
    tmpb->й=2*г*Rand;
    QueIns(tmpb,b_head[render_first+i%render_cnt].last);
  }

  for (i=1;i<mp_cnt;i++)
    Spawn(&CoreAPTalonsTask,Fs,"AP Talons",i);
  Fs->task_end_cb=&TaskEndCB;
  game_t0=tS;
}

U0 CleanUp()
{
  I64 i;
  Panel *tmpp=panel_head,*tmpp1;
  while (LBts(&anim_lock,0))
    Yield;
  MPEnd;
  Free(fish_list);
  fish_list=NULL;
  fish_cnt=0;
  while (tmpp) {
    tmpp1=tmpp->next;
    QueDel(&tmpp->next_obj);
    Free(tmpp->pts);
    Free(tmpp);
    tmpp=tmpp1;
  }
  for (i=0;i<mp_cnt;i++) {
    QueDel(&b_head[i]);
    QueInit(&b_head[i]);
  }
  Fs->draw_it=NULL;
  while (LBts(&front_lock,0))
    Yield;
  DCDel(front_dc);
  DCDel(main_dc);
}

U0 CamOrbit(F64 d)
{
  if (bird_mode) {
    if (bird_zoom)
      bird_orbit=Wrap(bird_orbit+d);
  } else if (!boat_fp)
    cam_orbit=Wrap(cam_orbit+d);
}

U0 CamElev(F64 d)
{
  if (bird_mode) {
    if (bird_zoom)
      bird_elev=Clamp(bird_elev+d,CAM_ELEV_MIN-BIRD_CAM_ELEV0,
	    CAM_ELEV_MAX-BIRD_CAM_ELEV0);
  } else if (!boat_fp)
    cam_elev=Clamp(cam_elev+d,CAM_ELEV_MIN-Arg(CAM_BACK,CAM_UP),
	  CAM_ELEV_MAX-Arg(CAM_BACK,CAM_UP));
}

U0 ShowHelp()
{
  CDoc *doc;
  U8 *name;
  F64 t0=tS;
  while (LBts(&anim_lock,0))
    Yield;
  Fs->draw_it=NULL;
  DocClear;
  name=MStrPrint("%s/BirdsNBoats.DD",__DIR__);
  if (!FileFind(name)) {
    Free(name);
    name=MStrPrint("%s/BirdsNBoats.DD.Z",__DIR__);
  }
  doc=DocRead(name);
  DocInsDoc(DocPut,doc);
  DocDel(doc);
  Free(name);
  "\n$$FG,12$$Press any key to continue.$$FG$$\n";
  GetKey;
  DocClear;
  if (!game_tf)
    game_t0+=tS-t0;
  Fs->draw_it=&DrawIt;
  LBtr(&anim_lock,0);
}

U0 BirdsNBoats()
{
  I64 ch,sc;
  SettingsPush;
  MenuPush(
	"File {"
	"  Abort(,CH_SHIFT_ESC);"
	"  Help(,'h');"
	"  Exit(,CH_ESC);"
	"}"
	"Play {"
	"  Restart(,'\n');"
	"  Faster(,,SC_CURSOR_UP);"
	"  Slower(,,SC_CURSOR_DOWN);"
	"  BirdBoat(,'b');"
	"  Left(,,SC_CURSOR_LEFT);"
	"  Right(,,SC_CURSOR_RIGHT);"
	"  Stop(,CH_SPACE);"
	"  ZoomIn(,'+');"
	"  ZoomOut(,'-');"
	"  OrbitLeft(,'[');"
	"  OrbitRight(,']');"
	"  OrbitUp(,,SC_PAGE_UP);"
	"  OrbitDown(,,SC_PAGE_DOWN);"
	"}"
	);
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  "Initializing...\n";
  Fs->song_task=Spawn(&SongTask,NULL,"Song",,Fs);
  anim_lock=1;
  PreInit;
  Init;
  LBtr(&anim_lock,0);
  Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
  Fs->draw_it=&DrawIt;
  try
    do {
      if (ScanKey(&ch,&sc)) {
	switch (ch) {
	  case 0:
	    if (bird_mode && bird_zoom &&
		  (sc.u8[0]==SC_CURSOR_LEFT || sc.u8[0]==SC_CURSOR_RIGHT)) {
	      roll=0;
	      if (sc.u8[0]==SC_CURSOR_LEFT) {
		heading=Wrap(heading-г/32,0);
		bird_bank=-0.6;
	      } else {
		heading=Wrap(heading+г/32,0);
		bird_bank=0.6;
	      }
	      WrapAngles;
	    } else if (bird_mode)
	      switch (sc.u8[0]) {
		case SC_PAGE_UP:
		  CamElev(CAM_ORBIT_STEP);
		  break;
		case SC_PAGE_DOWN:
		  CamElev(-CAM_ORBIT_STEP);
		  break;
		start:
		  case SC_CURSOR_DOWN:
		    и-=CTRLS_SCALE*Cos(roll);
		    heading-=CTRLS_SCALE*Sin(roll)*Sin(и);
		    break;
		  case SC_CURSOR_UP:
		    и+=CTRLS_SCALE*Cos(roll);
		    heading+=CTRLS_SCALE*Sin(roll)*Sin(и);
		    break;
		  case SC_CURSOR_RIGHT:
		    roll+=CTRLS_SCALE;
		    break;
		  case SC_CURSOR_LEFT:
		    roll-=CTRLS_SCALE;
		    break;
		end:
		  WrapAngles;
	      }
	    else
	      switch (sc.u8[0]) {
		case SC_CURSOR_UP:
		  boat_speed=Min(1.6,boat_speed+0.2);
		  break;
		case SC_CURSOR_DOWN:
		  boat_speed=Max(-1.6/3,boat_speed-0.2);
		  break;
		case SC_CURSOR_LEFT:
		  BoatTurn(-(г/32));
		  break;
		case SC_CURSOR_RIGHT:
		  BoatTurn((г/32));
		  break;
		case SC_PAGE_UP:
		  CamElev(CAM_ORBIT_STEP);
		  break;
		case SC_PAGE_DOWN:
		  CamElev(-CAM_ORBIT_STEP);
		  break;
	      }
	    break;
	  case 'b':
	  case 'B':
	    SwitchPlayer;
	    break;
	  case 'h':
	  case 'H':
	    ShowHelp;
	    break;
	  case 'r':
	  case 'R':
	    cam_zoom=1.0;
	    cam_orbit=0;
	    cam_elev=0;
	    boat_fp=TRUE;
	    bird_zoom=0;
	    bird_orbit=0;
	    bird_elev=0;
	    break;
	  case CH_SPACE:
	    if (!bird_mode)
	      boat_speed=0;
	    break;
	  case '+':
	  case '=':
	    if (bird_mode) {
	      bird_zoom/=CAM_ZOOM_STEP;
	      if (bird_zoom<400)
		bird_zoom=0;
	    } else if (cam_zoom<=0.7)
	      boat_fp=TRUE;
	    else
	      cam_zoom=Max(0.7,cam_zoom/CAM_ZOOM_STEP);
	    break;
	  case '-':
	  case '_':
	    if (bird_mode) {
	      if (bird_zoom)
		bird_zoom=Min(4000,bird_zoom*CAM_ZOOM_STEP);
	      else
		bird_zoom=400;
	    } else if (boat_fp)
	      boat_fp=FALSE;
	    else
	      cam_zoom=Min(3.0,cam_zoom*CAM_ZOOM_STEP);
	    break;
	  case ';':
	    CamElev(-CAM_ORBIT_STEP);
	    break;
	  case '\'':
	    CamElev(CAM_ORBIT_STEP);
	    break;
	  case '[':
	  case ',':
	    CamOrbit(-CAM_ORBIT_STEP);
	    break;
	  case ']':
	  case '.':
	    CamOrbit(CAM_ORBIT_STEP);
	    break;
	  case '\n':
	    Fs->draw_it=NULL;
	    CleanUp;
	    Refresh;
	    Init;
	    LBtr(&anim_lock,0);
	    Fs->draw_it=&DrawIt;
	    break;
	}
      } else
	Core0Talons;
    } while (ch!=CH_SHIFT_ESC && ch!=CH_ESC);
  catch
    PutExcept;
  SettingsPop;
  CleanUp;
  PostCleanUp;
  MenuPop;
  RegWrite("TempleOS/BirdsNBoats","F64 best_score=%5.4f;\n",best_score);
}
BirdsNBoats;
        ђ          
   аяяяэяяя   
эяяя      "   
   "   яяяя+   
яяяя+      &   
   &         
      	   ьяяя
	   ьяяя   бяяя
   бяяя   )    	       :_     йяяя   Ў   ‘   яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                                                                                                                                               яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя яяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя                                                                                                                                                                          яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяя         яяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяя          яяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяя  яяя    яяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяя     яяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяя   я  яяяя яяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяя   яя  яяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя  яяя  я яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя яяяяя   яяя  яяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя                                                                                                                                                                          яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяя   яяяя  яяя яяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяя   яяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя   яяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя я  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя я   яяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя    яяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя   яяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя   яяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя  яяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя   яяяяяяяяяяяяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяя    яяяяяяяяяяя яяяяяяяяяяяяя яяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя   я яяяяяяяяяяяяя яяяяяяяяяяяяяяяя яяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя   яя яяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя  яяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя  яяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя                                                                                                                                                                           яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя                                                                                                                                                                                 яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя                                                                                                                                                                                 яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя                                                                                                                                                                                 яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя         яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя яяяяяяяяяяяяяяяяяяя                                                                                                                                                                                 
       Љ    ляяяэяяя    яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я                                                                                                                                                                                                                                             я       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                      яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                      яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                      яяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                      яяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                      яяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                      яяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяя                                                            яяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяя                                                            яяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяя                                                            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяя                                                            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяя                                                            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяя                                                            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                              яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                              яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                              яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                              яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                              яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                              яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя            яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя            яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя            яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя            яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя            яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя            яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                                                                                                                                                                                                                   я                                                                                                                                                                                                                                                   я                                                                                                                                                                                                                                                   я                                                                                                                                                                                                                                                   я                                                                                                                                                                                                                                                   я                                                                                                                                                                                                                                               я       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                        яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя                  яяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяя            яяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя     яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя     яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя    яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя    яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя     яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя      яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя                                                                                                                                                                                                                                                       я                                                                                                                                                                                                                                                       я                                                                                                                                                                                                                                                       я                                                                                                                                                                                                                                                       я                                                                                                                                                                                                                                                       я                                                                                                                                                                                                                                                       я       яяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя               b     юяяявяяя      яяяяя яяяяя     яяяя  яяяяя     яяяя  яяяяя     яяяя  яяяяя     яяя  яяяя     яя  яяяя     яя  яяяя     яя  яяяя     яя  яяя     я  яяя     я  яяя     я  яяя     я  яяя     я  яяя       яяя       яяя       яя       яя       я       я                             ‚     юяяя         яяяяяяяяяяяяя              яя     яяя     яяя     яяяя     яяяя     яяяяя     яяяяя   я  яяяяя   я  яяяяя   я  яяяяя   я  яяяяя   я  яяяяя   яя  яяяяя   яя  яяяяяя   яя  яяяяяя   яя  яяяяяя   яяя  яяяяяя   яяяя  яяяяяяя   яяяя  яяяяяяя   яяяя  яяяяяяя   яяяяя яяяяяяя   яяяяяяяяяяяяя           К           шяяямяяя       мяяя       шяяя                        шяяя       мяяя       мяяяшяяя    юяяяыяяя•      ыяяя•      юяяя•         •         •   юяяя   •   ыяяя   •   ыяяяюяяя•             	      	                   
      
   	                        
                                                                                                                                       P     
         Уяяязяяя   %   зяяя    ;   зяяяйяяя%   зяяяйяяяУяяязяяя!   јяяя    !   8           Y       Юяяя8       Юяяяјяяя                                                                                       	      	                            	                                                    	            	            	   	   	   яяяяяяяя        яяяя                яяяя        яяяяяяяя•       яяяя•           •   яяяя    •       Яяяя	   0            0            0           0           0           0           0            0           0           p   Ё      ьяяя3   ьяяяьяяя3      ьяяя-   ьяяяьяяя-         3   ьяяя   3         -   ьяяя   -      ьяяя-   щяяяьяяя-      ьяяя   щяяяьяяя         -   щяяя   -            щяяя      	   эяяя+      юяяя*         "         !   	       .         ,         $         #         !                      
               %         $             
                  
                                    
                           щяяяяяяя,   чяяя    ,   чяяящяяя#   хяяяыяяя#   щяяя   +   чяяя   +   чяяяьяяя"   хяяяэяяя"   чяяящяяя#   хяяяыяяя#   цяяяхяяя   фяяяцяяя   чяяяьяяя"   хяяяэяяя"   цяяячяяя   фяяящяяя   цяяяцяяя   фяяячяяя   цяяяфяяя   уяяяхяяя   цяяячяяя   фяяяшяяя   цяяяхяяя   уяяяцяяя      эяяя      юяяя      ьяяя      эяяя                                           ьяяя      эяяя      ыяяя       ьяяя                         юяяя                 ыяяя        ыяяя          юяяяяяяя   юяяя   ыяяя       ыяяя            яяяя      юяяяэяяя   ъяяяюяяя   яяяяяяяя   ыяяя       юяяя      ъяяя      яяяя      ыяяя      яяяяяяяя   ыяяяяяяя       яяяя   ьяяяяяяя   яяяя      ыяяя                ьяяя          яяяя    ьяяя                  юяяя	           яяяя   ьяяя                юяяя	      0            0           0           0           0            0           0           0           0            0           0           0           0  	      
   0  
      	   0           0           0  	         0        	   0     
      0           0  
         0        
   0     	      0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0  !       "   0  "   #   !   0  %   $   &   0  &   '   %   0  !       $   0  $   %   !   0  #   "   &   0  &   '   #   0  "       $   0  $   &   "   0  #   !   %   0  %   '   #   0  )   (   *   0  *   +   )   0  -   ,   .   0  .   /   -   0  )   (   ,   0  ,   -   )   0  +   *   .   0  .   /   +   0  *   (   ,   0  ,   .   *   0  +   )   -   0  -   /   +   0  1   0   2   0  2   3   1   0  5   4   6   0  6   7   5   0  1   0   4   0  4   5   1   0  3   2   6   0  6   7   3   0  2   0   4   0  4   6   2   0  3   1   5   0  5   7   3   0  9   8   :   0  :   ;   9   0  =   <   >   0  >   ?   =   0  9   8   <   0  <   =   9   0  ;   :   >   0  >   ?   ;   0  :   8   <   0  <   >   :   0  ;   9   =   0  =   ?   ;   0  A   @   B   0  B   C   A   0  E   D   F   0  F   G   E   0  A   @   D   0  D   E   A   0  C   B   F   0  F   G   C   0  B   @   D   0  D   F   B   0  C   A   E   0  E   G   C   0  I   H   J   0  J   K   I   0  M   L   N   0  N   O   M   0  I   H   L   0  L   M   I   0  K   J   N   0  N   O   K   0  J   H   L   0  L   N   J   0  K   I   M   0  M   O   K    0  Q   P   R    0  R   S   Q    0  U   T   V    0  V   W   U    0  Q   P   T    0  T   U   Q    0  S   R   V    0  V   W   S    0  R   P   T    0  T   V   R    0  S   Q   U    0  U   W   S   0  Y   X   Z   0  Z   [   Y   0  ]   \   ^   0  ^   _   ]   0  Y   X   \   0  \   ]   Y   0  [   Z   ^   0  ^   _   [   0  Z   X   \   0  \   ^   Z   0  [   Y   ]   0  ]   _   [   0  a   `   b   0  b   c   a   0  e   d   f   0  f   g   e   0  a   `   d   0  d   e   a   0  c   b   f   0  f   g   c   0  b   `   d   0  d   f   b   0  c   a   e   0  e   g   c    0  i   h   j    0  j   k   i    0  m   l   n    0  n   o   m    0  i   h   l    0  l   m   i    0  k   j   n    0  n   o   k    0  j   h   l    0  l   n   j    0  k   i   m    0  m   o   k           !     
      Уяяя   зяяя%      зяяя;       зяяя%   йяяязяяяУяяяйяяязяяяјяяя!       8   !       Y           8   Юяяя    јяяяЮяяя                                                                                       	      	                            	                                                    	            	            	   p   Ё   &      3   &   ьяяя3   &      -   &   ьяяя-         3      ьяяя3         -      ьяяя-   &      -   &   щяяя-   &         &   щяяя         -      щяяя-               щяяя   %   	   +   $      *         "         !   "   	   .   !      ,         $         #         !                         
            %         $                
                  
                                    
                        #   щяяя,   "   чяяя,   )   чяяя#   '   хяяя#   !   щяяя+      чяяя+   &   чяяя"   %   хяяя"   )   чяяя#   '   хяяя#   -   цяяя   ,   фяяя   &   чяяя"   %   хяяя"   +   цяяя   )   фяяя   ,   цяяя   +   фяяя   .   цяяя   -   уяяя   +   цяяя   *   фяяя   -   цяяя   ,   уяяя   %         $         '         &         !                   $         "         '         &         *         )          $         "         &         %          *         *          !      юяяя!   яяяяюяяя*         *          !         !   яяяя   %   юяяя   $   ъяяя   "   яяяя   !   ыяяя   !   юяяя       ъяяя      яяяя      ыяяя   "   яяяя   "   ыяяя   "          "   ьяяя      яяяя      ыяяя                ьяяя   "           !   ьяяя                 юяяя    "          !   ьяяя               юяяя                                                                                                                                                         	      
      
      	                              	                  	         
                     
                  
         	                                                                                                                                                                                                                                                                                                                     !       "      "   #   !      %   $   &      &   '   %      !       $      $   %   !      #   "   &      &   '   #      "       $      $   &   "      #   !   %      %   '   #      )   (   *      *   +   )      -   ,   .      .   /   -      )   (   ,      ,   -   )      +   *   .      .   /   +      *   (   ,      ,   .   *      +   )   -      -   /   +      1   0   2      2   3   1      5   4   6      6   7   5      1   0   4      4   5   1      3   2   6      6   7   3      2   0   4      4   6   2      3   1   5      5   7   3      9   8   :      :   ;   9      =   <   >      >   ?   =      9   8   <      <   =   9      ;   :   >      >   ?   ;      :   8   <      <   >   :      ;   9   =      =   ?   ;      A   @   B      B   C   A      E   D   F      F   G   E      A   @   D      D   E   A      C   B   F      F   G   C      B   @   D      D   F   B      C   A   E      E   G   C      I   H   J      J   K   I      M   L   N      N   O   M      I   H   L      L   M   I      K   J   N      N   O   K      J   H   L      L   N   J      K   I   M      M   O   K       Q   P   R       R   S   Q       U   T   V       V   W   U       Q   P   T       T   U   Q       S   R   V       V   W   S       R   P   T       T   V   R       S   Q   U       U   W   S      Y   X   Z      Z   [   Y      ]   \   ^      ^   _   ]      Y   X   \      \   ]   Y      [   Z   ^      ^   _   [      Z   X   \      \   ^   Z      [   Y   ]      ]   _   [      a   `   b      b   c   a      e   d   f      f   g   e      a   `   d      d   e   a      c   b   f      f   g   c      b   `   d      d   f   b      c   a   e      e   g   c       i   h   j       j   k   i       m   l   n       n   o   m       i   h   l       l   m   i       k   j   n       n   o   k       j   h   l       l   n   j       k   i   m       m   o   k   p   Ё   аяяя      аяяяьяяя   аяяя      аяяяьяяя   Щяяя      Щяяяьяяя   Щяяя      Щяяяьяяя   аяяя      аяяящяяя   аяяя      аяяящяяя   Щяяя      Щяяящяяя   Щяяя      Щяяящяяя   Яяяя	      Юяяя      Щяяя      Шяяя      Эяяя	      Ыяяя      Чяяя      Цяяя      Щяяя      Шяяя      Сяяя      Пяяя
      Шяяя      Цяяя      Пяяя      Ояяя
      Ряяя   	   Пяяя
      Мяяя      Кяяя      Ряяя      Пяяя
   
   Мяяя   	   Кяяя      Эяяящяяя   Ьяяячяяя   гяяячяяя   вяяяхяяя   Ыяяящяяя   Щяяячяяя   аяяячяяя   Яяяяхяяя   гяяячяяя   вяяяхяяя   зяяяцяяя   жяяяфяяя   аяяячяяя   Яяяяхяяя   еяяяцяяя   гяяяфяяя   зяяяцяяя   еяяяфяяя   ияяяцяяя   зяяяуяяя   еяяяцяяя   дяяяфяяя   зяяяцяяя   жяяяуяяя   Юяяя      Ыяяя      Фяяя      Сяяя      Юяяя      Ыяяя      Фяяя      Сяяя      Фяяя      Сяяя      Кяяя      Зяяя      Фяяя      Сяяя      Кяяя      Зяяя      Еяяя       Еяяя      Еяяя   	   Еяяя
      Йяяя       Йяяя      Йяяя   	   Йяяя
      Ьяяяюяяя   Эяяяъяяя   Тяяяыяяя   Уяяячяяя   Ьяяяюяяя   Эяяяъяяя   Тяяяыяяя   Уяяячяяя   Тяяяыяяя   Уяяячяяя   Ияяящяяя   Йяяяхяяя   Тяяяыяяя   Уяяячяяя   Ияяящяяя   Йяяяхяяя   Еяяящяяя   Еяяяцяяя    Еяяяцяяя   Еяяятяяя	   Йяяящяяя   Йяяяцяяя    Йяяяцяяя   Йяяятяяя	   0            0           0           0           0            0           0           0           0            0           0           0           0  	      
   0  
      	   0           0           0  	         0        	   0     
      0           0  
         0        
   0     	      0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0           0  !       "   0  "   #   !   0  %   $   &   0  &   '   %   0  !       $   0  $   %   !   0  #   "   &   0  &   '   #   0  "       $   0  $   &   "   0  #   !   %   0  %   '   #   0  )   (   *   0  *   +   )   0  -   ,   .   0  .   /   -   0  )   (   ,   0  ,   -   )   0  +   *   .   0  .   /   +   0  *   (   ,   0  ,   .   *   0  +   )   -   0  -   /   +   0  1   0   2   0  2   3   1   0  5   4   6   0  6   7   5   0  1   0   4   0  4   5   1   0  3   2   6   0  6   7   3   0  2   0   4   0  4   6   2   0  3   1   5   0  5   7   3   0  9   8   :   0  :   ;   9   0  =   <   >   0  >   ?   =   0  9   8   <   0  <   =   9   0  ;   :   >   0  >   ?   ;   0  :   8   <   0  <   >   :   0  ;   9   =   0  =   ?   ;   
0  A   @   B   
0  B   C   A   
0  E   D   F   
0  F   G   E   
0  A   @   D   
0  D   E   A   
0  C   B   F   
0  F   G   C   
0  B   @   D   
0  D   F   B   
0  C   A   E   
0  E   G   C   0  I   H   J   0  J   K   I   0  M   L   N   0  N   O   M   0  I   H   L   0  L   M   I   0  K   J   N   0  N   O   K   0  J   H   L   0  L   N   J   0  K   I   M   0  M   O   K    0  Q   P   R    0  R   S   Q    0  U   T   V    0  V   W   U    0  Q   P   T    0  T   U   Q    0  S   R   V    0  V   W   S    0  R   P   T    0  T   V   R    0  S   Q   U    0  U   W   S   
0  Y   X   Z   
0  Z   [   Y   
0  ]   \   ^   
0  ^   _   ]   
0  Y   X   \   
0  \   ]   Y   
0  [   Z   ^   
0  ^   _   [   
0  Z   X   \   
0  \   ^   Z   
0  [   Y   ]   
0  ]   _   [   0  a   `   b   0  b   c   a   0  e   d   f   0  f   g   e   0  a   `   d   0  d   e   a   0  c   b   f   0  f   g   c   0  b   `   d   0  d   f   b   0  c   a   e   0  e   g   c    0  i   h   j    0  j   k   i    0  m   l   n    0  n   o   m    0  i   h   l    0  l   m   i    0  k   j   n    0  n   o   k    0  j   h   l    0  l   n   j    0  k   i   m    0  m   o   k           В        (   K   
       K   цяяя    -   зяяя    ыяяяЌяяяn   Ояяязяяя    Ояяя       ыяяяs   n   -          K   
      K   цяяя   -   зяяя   ыяяяЌяяя   Ояяязяяя   Ояяя      ыяяяs      -         Ояяя       Ояяя      Ояяя       Ояяязяяя    њяяяОяяя    њяяя2       Ояяя      Ояяязяяя   њяяяОяяя   њяяя2      0         	   0  	          0        
   0  
   	      0           0     
      0           0           0           0           0           0           0           0           0            0           0            0           0           0           0           0           0  	         0  
   	      0     
      0           0           0           0           0           0           0           0           0           0           0           0           0           0           0                   В        (   K   
       K   цяяя    -   зяяя    ыяяяЌяяя’яяяОяяязяяя    Ояяя       ыяяяs   ’яяя-          K   
      K   цяяя   -   зяяя   ыяяяЌяяяЈяяяОяяязяяя   Ояяя      ыяяяs   Јяяя-         Ояяя       Ояяя      Ояяя       Ояяязяяя    њяяяОяяя    њяяя2       Ояяя      Ояяязяяя   њяяяОяяя   њяяя2      0         	   0  	          0        
   0  
   	      0           0     
      0           0           0           0           0           0           0           0           0            0           0            0           0           0           0           0           0  	         0  
   	      0     
      0           0           0           0           0           0           0           0           0           0           0           0           0           0           0            
