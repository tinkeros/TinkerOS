#define JPG_LOOK	9

class CJpgHuff
{
  I64 maxcode[18],valptr[17],mincode[17];
  U8 vals[256],look_len[1<<JPG_LOOK],look_val[1<<JPG_LOOK];
  Bool ok;
};

class CJpgComp
{
  I64 id,h,v,tq,td,ta,pred,
	pw,ph;
  U8 *plane;
};

class CJpg
{
  U8 *p,*end;
  I64 acc,nbits,w,h,nc,hmax,vmax,dri;
  I64 q[4*64];
  CJpgHuff dc[4],ac[4];
  CJpgComp c[3];
  Bool q_ok[4];
};

U8 jpg_zz[64]={0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,
	41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,
	44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63};

U8 jpg_dc_l[28]={0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11};
U8 jpg_dc_c[28]={0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11};
U8 jpg_ac_l[178]={0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,0x7D,
	0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,0x21,0x31,0x41,0x06,0x13,0x51,0x61,
	0x07,0x22,0x71,0x14,0x32,0x81,0x91,0xA1,0x08,0x23,0x42,0xB1,0xC1,0x15,0x52,
	0xD1,0xF0,0x24,0x33,0x62,0x72,0x82,0x09,0x0A,0x16,0x17,0x18,0x19,0x1A,0x25,
	0x26,0x27,0x28,0x29,0x2A,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x43,0x44,0x45,
	0x46,0x47,0x48,0x49,0x4A,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x63,0x64,
	0x65,0x66,0x67,0x68,0x69,0x6A,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x83,
	0x84,0x85,0x86,0x87,0x88,0x89,0x8A,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,
	0x9A,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xB2,0xB3,0xB4,0xB5,0xB6,
	0xB7,0xB8,0xB9,0xBA,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,0xD2,0xD3,
	0xD4,0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,0xE1,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0xE8,
	0xE9,0xEA,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA};
U8 jpg_ac_c[178]={0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,0x77,
	0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,0x31,0x06,0x12,0x41,0x51,0x07,0x61,
	0x71,0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91,0xA1,0xB1,0xC1,0x09,0x23,0x33,
	0x52,0xF0,0x15,0x62,0x72,0xD1,0x0A,0x16,0x24,0x34,0xE1,0x25,0xF1,0x17,0x18,
	0x19,0x1A,0x26,0x27,0x28,0x29,0x2A,0x35,0x36,0x37,0x38,0x39,0x3A,0x43,0x44,
	0x45,0x46,0x47,0x48,0x49,0x4A,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x63,
	0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,
	0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8A,0x92,0x93,0x94,0x95,0x96,0x97,
	0x98,0x99,0x9A,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xB2,0xB3,0xB4,
	0xB5,0xB6,0xB7,0xB8,0xB9,0xBA,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,
	0xD2,0xD3,0xD4,0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,
	0xE8,0xE9,0xEA,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA};

I64 jpg_cos[64];
I64 jpg_cr_r[256],jpg_cb_g[256],jpg_cr_g[256],jpg_cb_b[256];
U8 jpg_clip[1024];
Bool jpg_tab_ok=FALSE;

U0 JpgTabInit()
{
  I64 x,u;
  F64 cu;
  if (jpg_tab_ok) return;
  for (x=0; x<8; x++)
    for (u=0; u<8; u++)
    {
      if (u) cu=1.0;
      else cu=Sqrt(0.5);
      jpg_cos[x*8+u]=ToI64(Round(4096*cu*Cos((2*x+1)*u*pi/16)/2));
    }
  for (x=0; x<256; x++)
  {
    jpg_cr_r[x]=ToI64(1.402*65536)*(x-128);
    jpg_cb_g[x]=-ToI64(0.344136*65536)*(x-128);
    jpg_cr_g[x]=-ToI64(0.714136*65536)*(x-128)+32768;
    jpg_cb_b[x]=ToI64(1.772*65536)*(x-128);
  }
  for (x=0; x<1024; x++)
    jpg_clip[x]=ClampI64(x-384,0,255);
  jpg_tab_ok=TRUE;
}

Bool JpgHuffBuild(CJpgHuff *t,U8 *bits,U8 *vals)
{//bits: 16 counts, vals: the symbols. Canonical codes, plus the fast table.
  I64 l,i,j,k=0,code=0,n=0,fill;
  for (l=0; l<16; l++)
    n+=bits[l];
  if (n>256) return FALSE;
  MemCpy(t->vals,vals,n);
  MemSet(t->look_len,0,1<<JPG_LOOK);
  for (l=1; l<=16; l++)
  {
    t->valptr[l]=k;
    t->mincode[l]=code;
    for (i=0; i<bits[l-1]; i++)
    {
      if (l<=JPG_LOOK)
      {
	fill=1<<(JPG_LOOK-l);
	for (j=0; j<fill; j++)
	{
	  t->look_len[code<<(JPG_LOOK-l)+j]=l;
	  t->look_val[code<<(JPG_LOOK-l)+j]=vals[k];
	}
      }
      code++;
      k++;
    }
    if (bits[l-1])
      t->maxcode[l]=code-1;
    else
      t->maxcode[l]=-1;
    code<<=1;
  }
  t->maxcode[17]=I64_MAX;
  t->ok=TRUE;
  return TRUE;
}

U0 JpgFill(CJpg *j)
{//Keep at least 48 bits. Stops at a marker: zero bits past it.
  I64 b;
  while (j->nbits<=48)
  {
    b=0;
    if (j->p<j->end)
    {
      b=*j->p;
      if (b==0xFF)
      {
	if (j->p+1<j->end && !j->p[1])
	  j->p+=2;
	else
	  b=0;
      }
      else
	j->p++;
    }
    j->acc=j->acc<<8|b;
    j->nbits+=8;
  }
}

I64 JpgBits(CJpg *j,I64 n)
{
  I64 v;
  if (!n) return 0;
  if (j->nbits<n) JpgFill(j);
  j->nbits-=n;
  v=j->acc>>j->nbits&(1<<n-1);
  return v;
}

I64 JpgHuff(CJpg *j,CJpgHuff *t)
{
  I64 look,l,code;
  if (j->nbits<16) JpgFill(j);
  look=j->acc>>(j->nbits-JPG_LOOK)&(1<<JPG_LOOK-1);
  if (l=t->look_len[look])
  {
    j->nbits-=l;
    return t->look_val[look];
  }
  code=JpgBits(j,JPG_LOOK);
  for (l=JPG_LOOK+1; l<=16; l++)
  {
    code=code<<1|JpgBits(j,1);
    if (code<=t->maxcode[l])
      return t->vals[t->valptr[l]+code-t->mincode[l]];
  }
  return 0;
}

I64 JpgExt(I64 v,I64 s)
{//JPEG F.12 EXTEND
  if (s && v<1<<(s-1))
    v+=-1<<s+1;
  return v;
}

U0 JpgIdct(I64 *f,U8 *dst,I64 stride)
{//8x8 inverse DCT, separable, into dst (level shifted, clipped).
  I64 x,y,u,s,tmp[64],*cs;
  Bool ac=FALSE;
  for (u=1; u<64; u++)
    if (f[u])
    {
      ac=TRUE;
      break;
    }
  if (!ac)
  {
    s=jpg_clip[(f[0]+4)>>3+128+384];
    for (y=0; y<8; y++)
      MemSet(dst+y*stride,s,8);
    return;
  }
  for (y=0; y<8; y++)
    for (x=0; x<8; x++)
    {
      cs=&jpg_cos[x*8];
      s=0;
      for (u=0; u<8; u++)
	s+=cs[u]*f[y*8+u];
      tmp[y*8+x]=s;
    }
  for (x=0; x<8; x++)
    for (y=0; y<8; y++)
    {
      cs=&jpg_cos[y*8];
      s=0;
      for (u=0; u<8; u++)
	s+=cs[u]*tmp[u*8+x];
      dst[y*stride+x]=jpg_clip[(s+1<<23)>>24+128+384];
    }
}

Bool JpgBlock(CJpg *j,CJpgComp *c,U8 *dst,I64 stride)
{
  I64 f[64],k,s,r,rs,*q=&j->q[c->tq*64];
  CJpgHuff *ac=&j->ac[c->ta];
  MemSet(f,0,64*sizeof(I64));
  s=JpgHuff(j,&j->dc[c->td]);
  c->pred+=JpgExt(JpgBits(j,s),s);
  f[0]=c->pred*q[0];
  for (k=1; k<64; k++)
  {
    rs=JpgHuff(j,ac);
    r=rs>>4;
    s=rs&15;
    if (!s)
    {
      if (r!=15) break;
      k+=15;
    }
    else
    {
      k+=r;
      if (k>63) return FALSE;
      f[jpg_zz[k]]=JpgExt(JpgBits(j,s),s)*q[k];
    }
  }
  JpgIdct(f,dst,stride);
  return TRUE;
}

I64 JpgU16(U8 *p)
{
  return p[0]<<8|p[1];
}

Bool JpgScan(CJpg *j)
{//The entropy-coded data at j->p: every MCU into the component planes.
  I64 mx,my,mcux,mcuy,ci,bx,by,n=0,rst=0;
  CJpgComp *c;
  mcux=(j->w+8*j->hmax-1)/(8*j->hmax);
  mcuy=(j->h+8*j->vmax-1)/(8*j->vmax);
  j->acc=j->nbits=0;
  for (ci=0; ci<j->nc; ci++)
    j->c[ci].pred=0;
  for (my=0; my<mcuy; my++)
  {
    for (mx=0; mx<mcux; mx++)
    {
      if (j->dri && n && !(n%j->dri))
      {
	j->acc=j->nbits=0;
	while (j->p+1<j->end && !(j->p[0]==0xFF && 0xD0<=j->p[1]<=0xD7))
	  j->p++;
	if (j->p+1<j->end)
	  j->p+=2;
	for (ci=0; ci<j->nc; ci++)
	  j->c[ci].pred=0;
	rst++;
      }
      for (ci=0; ci<j->nc; ci++)
      {
	c=&j->c[ci];
	for (by=0; by<c->v; by++)
	  for (bx=0; bx<c->h; bx++)
	    if (!JpgBlock(j,c,c->plane+((my*c->v+by)*8)*c->pw+(mx*c->h+bx)*8,c->pw))
	      return FALSE;
      }
      n++;
    }
    if (!(my&7))
      Yield;
  }
  return TRUE;
}

U0 JpgFree(CJpg *j)
{
  I64 i;
  for (i=0; i<3; i++)
    Free(j->c[i].plane);
  Free(j);
}

U0 JpgToRgb(CJpg *j,U8 *rgb)
{//Upsample chroma (nearest) and convert to RGB24.
  I64 x,y,yy,cb,cr,o;
  CJpgComp *c0=&j->c[0],*c1=&j->c[1],*c2=&j->c[2];
  U8 *py,*pb,*pr;
  for (y=0; y<j->h; y++)
  {
    py=c0->plane+y*c0->v/j->vmax*c0->pw;
    if (j->nc==3)
    {
      pb=c1->plane+y*c1->v/j->vmax*c1->pw;
      pr=c2->plane+y*c2->v/j->vmax*c2->pw;
    }
    o=y*j->w*3;
    for (x=0; x<j->w; x++)
    {
      yy=py[x*c0->h/j->hmax]<<16;
      if (j->nc==3)
      {
	cb=pb[x*c1->h/j->hmax];
	cr=pr[x*c2->h/j->hmax];
	rgb[o]=jpg_clip[(yy+jpg_cr_r[cr]+32768)>>16+384];
	rgb[o+1]=jpg_clip[(yy+jpg_cb_g[cb]+jpg_cr_g[cr])>>16+384];
	rgb[o+2]=jpg_clip[(yy+jpg_cb_b[cb]+32768)>>16+384];
      }
      else
	rgb[o]=rgb[o+1]=rgb[o+2]=yy>>16;
      o+=3;
    }
  }
}

public U8 *JpgDecode(U8 *data,I64 len,I64 *_w,I64 *_h)
{//JPEG data to RGB24 (w*h*3 bytes, Free it), NULL if not baseline.
  CJpg *j;
  CJpgComp *c;
  U8 *p=data,*end=data+len,*seg,*rgb=NULL,bits[16];
  I64 m,ln,i,k,n,tc,th,ns,id,mcux,mcuy;
  Bool sof=FALSE;
  if (len<4 || data[0]!=0xFF || data[1]!=0xD8) return NULL;
  JpgTabInit;
  j=CAlloc(sizeof(CJpg));
  p+=2;
  while (p+4<=end)
  {
    if (p[0]!=0xFF)
    {
      p++;
      goto jd_next;
    }
    m=p[1];
    if (m==0xFF || 0xD0<=m<=0xD7 || m==0x01)
    {
      p+=1+(m!=0xFF);
      goto jd_next;
    }
    if (m==0xD9) break;
    ln=JpgU16(p+2);
    seg=p+4;
    if (ln<2 || p+2+ln>end) break;
    switch (m)
    {
      case 0xDB:
	i=0;
	while (i<ln-2)
	{
	  tc=seg[i]>>4;
	  th=seg[i]&3;
	  for (k=0; k<64; k++)
	    if (tc)
	      j->q[th*64+k]=JpgU16(seg+i+1+2*k);
	    else
	      j->q[th*64+k]=seg[i+1+k];
	  j->q_ok[th]=TRUE;
	  i+=1+64*(1+tc);
	}
	break;
      case 0xC4:
	i=0;
	while (i+17<=ln-2)
	{
	  tc=seg[i]>>4;
	  th=seg[i]&3;
	  MemCpy(bits,seg+i+1,16);
	  for (k=n=0; k<16; k++)
	    n+=bits[k];
	  if (tc)
	    JpgHuffBuild(&j->ac[th],bits,seg+i+17);
	  else
	    JpgHuffBuild(&j->dc[th],bits,seg+i+17);
	  i+=17+n;
	}
	break;
      case 0xC0:
      case 0xC1:
	if (seg[0]!=8) goto jd_fail;
	j->h=JpgU16(seg+1);
	j->w=JpgU16(seg+3);
	j->nc=seg[5];
	if (j->nc!=1 && j->nc!=3 || !j->w || !j->h) goto jd_fail;
	j->hmax=j->vmax=1;
	for (i=0; i<j->nc; i++)
	{
	  c=&j->c[i];
	  c->id=seg[6+3*i];
	  c->h=seg[7+3*i]>>4;
	  c->v=seg[7+3*i]&15;
	  c->tq=seg[8+3*i]&3;
	  if (!(1<=c->h<=2) || !(1<=c->v<=2)) goto jd_fail;
	  j->hmax=MaxI64(j->hmax,c->h);
	  j->vmax=MaxI64(j->vmax,c->v);
	}
	mcux=(j->w+8*j->hmax-1)/(8*j->hmax);
	mcuy=(j->h+8*j->vmax-1)/(8*j->vmax);
	for (i=0; i<j->nc; i++)
	{
	  c=&j->c[i];
	  c->pw=mcux*c->h*8;
	  c->ph=mcuy*c->v*8;
	  c->plane=MAlloc(c->pw*c->ph);
	}
	sof=TRUE;
	break;
      case 0xC2...0xC3:
      case 0xC5...0xC7:
      case 0xC9...0xCB:
      case 0xCD...0xCF:
	goto jd_fail;
      case 0xDD:
	j->dri=JpgU16(seg);
	break;
      case 0xDA:
	if (!sof) goto jd_fail;
	ns=seg[0];
	for (i=0; i<ns; i++)
	{
	  id=seg[1+2*i];
	  for (k=0; k<j->nc; k++)
	    if (j->c[k].id==id)
	    {
	      j->c[k].td=seg[2+2*i]>>4&3;
	      j->c[k].ta=seg[2+2*i]&3;
	    }
	}
	if (!j->dc[0].ok)
	  JpgHuffBuild(&j->dc[0],jpg_dc_l,jpg_dc_l+16);
	if (!j->ac[0].ok)
	  JpgHuffBuild(&j->ac[0],jpg_ac_l,jpg_ac_l+16);
	if (!j->dc[1].ok)
	  JpgHuffBuild(&j->dc[1],jpg_dc_c,jpg_dc_c+16);
	if (!j->ac[1].ok)
	  JpgHuffBuild(&j->ac[1],jpg_ac_c,jpg_ac_c+16);
	j->p=seg+ln-2;
	j->end=end;
	if (!JpgScan(j)) goto jd_fail;
	rgb=MAlloc(j->w*j->h*3);
	JpgToRgb(j,rgb);
	*_w=j->w;
	*_h=j->h;
	JpgFree(j);
	return rgb;
    }
    p+=2+ln;
jd_next:;
  }
jd_fail:
  JpgFree(j);
  return NULL;
}

public U8 *JpgFileDecode(U8 *filename,I64 *_w,I64 *_h)
{//A .jpg file to RGB24 (Free it), NULL on failure.
  I64 size;
  U8 *data=FileRead(filename,&size),*rgb=NULL;
  if (data)
    rgb=JpgDecode(data,size,_w,_h);
  Free(data);
  return rgb;
}
