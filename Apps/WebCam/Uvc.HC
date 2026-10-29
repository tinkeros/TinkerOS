#define UVC_NFR		32
#define UVC_NALT	16
#define UVC_NIVL	8
#define UVC_PKTS	64
#define UVC_NHDR	16
#define UVC_NLEN	6

#define UVC_DESC_MAX	4096
#define UVC_CLS		0x0E
#define UVC_RT_IN	0x80
#define UVC_RT_IF	1
#define UVC_GET_DESC	6
#define UVC_SET_IF	11
#define UVC_DT_CFG	2
#define UVC_DT_IF	4
#define UVC_DT_EP	5

#define UVC_YUY2	0
#define UVC_MJPEG	1
#define UVC_OTHER	2

class CUvcFrame
{
  I64 type,fmt,idx,w,h,size,
	nivl,ivl[UVC_NIVL];
};

class CUvcAlt
{
  I64 alt,ep,mps,bw,ivl;
};

class CUvc
{
  I64 k,gen,vc_if,vs_if,bcd,nfr,nalt;
  CUvcFrame fr[UVC_NFR];
  CUvcAlt alt[UVC_NALT];
  CUvcFrame *cur;
  I64 cur_alt,cur_ivl,max_payload,pkt_max;
  U8 probe[48];
  U8 *iso_buf,*asm_buf,*ready;
  I64 *lens,asm_len,fid,ready_cnt,ready_len,lock,
	raw_len,
	fsize;
  Bool bad,err,over,stop,running,dead;
  CTask *owner;
  I64 frames,bad_frames,pkts,lost,
	rej_err,rej_long,rej_lost,rej_short,rej_jpg,
	nhdr,hdr[UVC_NHDR],
	nlen,flen[UVC_NLEN],
	padded,
	miss_sum,
	pl_max,pl_big,pl_empty,
	sof,sof_gaps,sof_lost,
	in_gaps,in_lost,
	zrun,zrun_max,zrun_n,
	f_lost,f_zrun,
	flost[UVC_NLEN],fzrun[UVC_NLEN],
	mf,
	mf_data[8],mf_gap[8],
	mf_pend[8],
	data_pl;
};

U8 uvc_guid_yuy2[16]={0x59,0x55,0x59,0x32,0x00,0x00,0x10,0x00,
	0x80,0x00,0x00,0xAA,0x00,0x38,0x9B,0x71};

U0 UvcParse(CUvc *c,U8 *d,I64 total)
{//Interfaces, YUY2/MJPEG frames and the streaming i/f's isochronous alts.
  I64 pos=0,ln,ty,sub,cur_if=-1,cur_alt=0,fmt=0,ftype=UVC_OTHER,i,n;
  CUvcFrame *fr;
  CUvcAlt *a;
  c->vc_if=-1;
  c->vs_if=-1;
  c->nfr=0;
  c->nalt=0;
  while (pos+2<=total)
  {
    ln=d[pos];
    ty=d[pos+1];
    if (ln<2 || pos+ln>total) break;
    if (ty==UVC_DT_IF && ln>=9)
    {
      cur_if=d[pos+2];
      cur_alt=d[pos+3];
      if (d[pos+5]==UVC_CLS && d[pos+6]==1 && c->vc_if<0)
	c->vc_if=cur_if;
      if (d[pos+5]==UVC_CLS && d[pos+6]==2 && c->vs_if<0)
	c->vs_if=cur_if;
    }
    else if (ty==0x24 && ln>=3)
    {
      sub=d[pos+2];
      if (cur_if==c->vc_if && sub==1 && ln>=5)
	c->bcd=d[pos+3]|d[pos+4]<<8;
      else if (cur_if==c->vs_if && !cur_alt)
      {
	if (sub==4 && ln>=21)
	{
	  fmt=d[pos+3];
	  if (!MemCmp(d+pos+5,uvc_guid_yuy2,16))
	    ftype=UVC_YUY2;
	  else
	    ftype=UVC_OTHER;
	}
	else if (sub==6 && ln>=4)
	{
	  fmt=d[pos+3];
	  ftype=UVC_MJPEG;
	}
	else if (sub==0x10 && ln>=4)
	{
	  fmt=d[pos+3];
	  ftype=UVC_OTHER;
	}
	else if ((sub==5 || sub==7 || sub==0x11) && ln>=26 && c->nfr<UVC_NFR)
	{
	  fr=&c->fr[c->nfr++];
	  fr->type=ftype;
	  fr->fmt=fmt;
	  fr->idx=d[pos+3];
	  fr->w=d[pos+5]|d[pos+6]<<8;
	  fr->h=d[pos+7]|d[pos+8]<<8;
	  if (sub==0x11)
	    fr->size=0;
	  else
	    fr->size=(d+pos+17)(U32 *)[0];
	  if (ftype==UVC_YUY2)
	    fr->size=fr->w*fr->h*2;
	  n=d[pos+25];
	  fr->nivl=0;
	  if (!n && ln>=38)
	  {
	    fr->ivl[fr->nivl++]=(d+pos+26)(U32 *)[0];
	    fr->ivl[fr->nivl++]=(d+pos+30)(U32 *)[0];
	  }
	  for (i=0; i<n && i<UVC_NIVL && 26+4*i+4<=ln; i++)
	    fr->ivl[fr->nivl++]=(d+pos+26+4*i)(U32 *)[0];
	}
      }
    }
    else if (ty==UVC_DT_EP && ln>=7 && cur_if==c->vs_if && cur_alt &&
	  d[pos+3]&3==1 && d[pos+2]&0x80 && c->nalt<UVC_NALT)
    {
      a=&c->alt[c->nalt++];
      a->alt=cur_alt;
      a->ep=d[pos+2];
      a->mps=d[pos+4]|d[pos+5]<<8;
      a->bw=(a->mps&0x7FF)*(a->mps>>11&3+1);
      a->ivl=d[pos+6];
    }
    pos+=ln;
  }
}

public CUvc *UvcOpen(I64 n=0)
{//The n-th camera, NULL if there is none. UvcClose when done.
  CUvc *c;
  U8 *d;
  I64 k=UsbVenFind(-1,-1,n,USB_KIND_VIDEO),gen,total;
  if (k<0) return NULL;
  gen=UsbVenGen(k);
  d=CAlloc(UVC_DESC_MAX);
  if (UsbVenCtl(k,gen,UVC_RT_IN,UVC_GET_DESC,UVC_DT_CFG<<8,0,9,d)<9)
  {
    Free(d);
    return NULL;
  }
  total=MinI64(d[2]|d[3]<<8,UVC_DESC_MAX);
  total=UsbVenCtl(k,gen,UVC_RT_IN,UVC_GET_DESC,UVC_DT_CFG<<8,0,total,d);
  c=CAlloc(sizeof(CUvc));
  c->k=k;
  c->gen=gen;
  UvcParse(c,d,total);
  Free(d);
  if (c->vs_if<0 || !c->nalt)
  {
    Free(c);
    return NULL;
  }
  UsbVenCtl(k,gen,UVC_RT_IF,UVC_SET_IF,0,c->vs_if);
  return c;
}

public U0 UvcRep(CUvc *c)
{//Camera c's interfaces, frame sizes and streaming bandwidths.
  I64 i,j;
  CUvcFrame *fr;
  U8 *nm;
  "$$FG,2$$Camera$$FG$$ USB #%d %04X:%04X UVC %X.%02X, i/f %d control, %d streaming\n",
	c->k,UsbVenId(c->k)>>16,UsbVenId(c->k)&0xFFFF,c->bcd>>8,c->bcd&0xFF,
	c->vc_if,c->vs_if;
  for (i=0; i<c->nfr; i++)
  {
    fr=&c->fr[i];
    if (fr->type==UVC_YUY2) nm="YUY2";
    else if (fr->type==UVC_MJPEG) nm="MJPEG";
    else nm="other";
    "  format %d frame %d: %-5s %4dx%-4d fps",fr->fmt,fr->idx,nm,fr->w,fr->h;
    for (j=0; j<fr->nivl; j++)
      if (fr->ivl[j])
	" %d",(10000000+fr->ivl[j]/2)/fr->ivl[j];
    if (fr->type==UVC_OTHER)
      " (not supported)";
    '\n';
  }
  "  streaming alts:";
  for (i=0; i<c->nalt; i++)
    " %d:%d",c->alt[i].alt,c->alt[i].bw;
  " bytes/microframe\n";
  if (c->cur)
    "  streaming %dx%d, alt %d, payload %d: %d frames, %d bad, %d packets, %d lost\n",
	  c->cur->w,c->cur->h,c->cur_alt,c->max_payload,c->frames,c->bad_frames,
	  c->pkts,c->lost;
  if (c->cur && c->bad_frames)
  {
    "  dropped: %d error bit, %d too long, %d lost packet, %d short, %d not JPEG\n",
	  c->rej_err,c->rej_long,c->rej_lost,c->rej_short,c->rej_jpg;
  }
  if (c->cur)
    "  %d short frames shown, payloads: longest %d, %d over 1024, %d empty, "
	  "%d USB frame jumps (%d frames skipped)\n",c->padded,c->pl_max,c->pl_big,
	  c->pl_empty,c->sof_gaps,c->sof_lost;
  if (c->cur)
  {
    "  inside frames: %d USB frame jumps (%d skipped), longest gap without data "
	  "%d microframes, %d gaps of 8+\n",c->in_gaps,c->in_lost,c->zrun_max,c->zrun_n;
    "  last frames (length, want %d, -: dropped / USB frames skipped inside / "
	  "longest gap):",c->fsize;
    for (i=MaxI64(c->nlen-UVC_NLEN,0); i<c->nlen; i++)
      " %d/%d/%d",c->flen[i%UVC_NLEN],c->flost[i%UVC_NLEN],c->fzrun[i%UVC_NLEN];
    '\n';
  }
  if (c->cur)
  {
    "  by microframe 0-7, payloads with data:";
    for (i=0; i<8; i++)
      " %d",c->mf_data[i];
    "\n  by microframe 0-7, empty inside a frame:";
    for (i=0; i<8; i++)
      " %d",c->mf_gap[i];
    '\n';
  }
  if (c->cur && c->nhdr)
  {
    "  first payloads (length/header length/flags):";
    for (i=0; i<c->nhdr; i++)
      " %d/%d/%02X",c->hdr[i]>>16,c->hdr[i]>>8&0xFF,c->hdr[i]&0xFF;
    '\n';
  }
}

Bool UvcBigger(CUvc *c,CUvcFrame *fr,I64 than)
{//fr has more pixels than frame than (-1: none yet), YUY2 wins a tie.
  CUvcFrame *t;
  if (than<0) return TRUE;
  t=&c->fr[than];
  if (fr->w*fr->h!=t->w*t->h)
    return fr->w*fr->h>t->w*t->h;
  return fr->type==UVC_YUY2 && t->type!=UVC_YUY2;
}

CUvcFrame *UvcPick(CUvc *c,I64 w,I64 h,I64 type=-1)
{//The frame w x h of type (UVC_YUY2, UVC_MJPEG, -1: either), else the best fit.
  I64 i,best=-1,small=-1,pass;
  CUvcFrame *fr;
  for (pass=0; pass<2; pass++)
    for (i=0; i<c->nfr; i++)
    {
      fr=&c->fr[i];
      if (fr->w==w && fr->h==h)
      {
	if (type>=0 && fr->type==type) return fr;
	if (type<0 && !pass && fr->type==UVC_YUY2) return fr;
	if (type<0 && pass && fr->type==UVC_MJPEG) return fr;
      }
    }
  for (i=0; i<c->nfr; i++)
  {
    fr=&c->fr[i];
    if (fr->type==UVC_OTHER || type>=0 && fr->type!=type)
      goto pk_skip;
    if (fr->w<=w && fr->h<=h && UvcBigger(c,fr,best))
      best=i;
    if (small<0)
      small=i;
    else if (fr->w*fr->h<c->fr[small].w*c->fr[small].h)
      small=i;
pk_skip:;
  }
  if (best>=0) return &c->fr[best];
  if (small>=0) return &c->fr[small];
  return NULL;
}

U0 UvcFrameEnd(CUvc *c)
{//A whole frame becomes the ready one; a short or damaged one is dropped.
  U8 *t;
  Bool ok;
  if (c->asm_len)
  {
    if (c->cur->type==UVC_YUY2)
    {
      ok=c->asm_len==c->fsize;
      if (!ok && !c->bad && c->asm_len>=c->fsize-c->fsize/8)
      {
	c->miss_sum+=c->fsize-c->asm_len;
	MemSet(c->asm_buf+c->asm_len,0x80,c->fsize-c->asm_len);
	c->asm_len=c->fsize;
	c->padded++;
	ok=TRUE;
      }
    }
    else
      ok=c->asm_len>=4 && c->asm_buf[0]==0xFF && c->asm_buf[1]==0xD8;
    if (c->over)
      c->rej_long++;
    else if (c->err)
      c->rej_err++;
    else if (c->bad)
      c->rej_lost++;
    else if (!ok)
    {
      if (c->cur->type==UVC_YUY2)
	c->rej_short++;
      else
	c->rej_jpg++;
    }
    c->flost[c->nlen%UVC_NLEN]=c->f_lost;
    c->fzrun[c->nlen%UVC_NLEN]=c->f_zrun;
    if (c->bad || !ok)
      c->flen[c->nlen++%UVC_NLEN]=-c->raw_len;
    else
      c->flen[c->nlen++%UVC_NLEN]=c->raw_len;
    if (!c->bad && ok)
    {
      while (LBts(&c->lock,0))
	Yield;
      t=c->ready;
      c->ready=c->asm_buf;
      c->asm_buf=t;
      c->ready_len=c->asm_len;
      c->ready_cnt++;
      LBtr(&c->lock,0);
      c->frames++;
    }
    else
      c->bad_frames++;
  }
  c->asm_len=c->raw_len=c->f_lost=c->f_zrun=0;
  c->bad=c->err=c->over=FALSE;
}

U0 UvcPkt(CUvc *c,U8 *p,I64 len)
{//One payload: header, then video data.
  I64 hl,info,n,sof,i;
  Bool cont;
  if (len<2)
  {
    c->zrun++;
    c->mf_pend[c->mf]++;
    return;
  }
  hl=p[0];
  if (c->nhdr<UVC_NHDR && (len>hl || hl<2))
    c->hdr[c->nhdr++]=len<<16|hl<<8|p[1];
  if (hl<2 || hl>len) return;
  info=p[1];
  n=len-hl;
  if (n>c->pl_max) c->pl_max=n;
  if (n>1024) c->pl_big++;
  if (!n)
  {
    c->pl_empty++;
    c->zrun++;
    c->mf_pend[c->mf]++;
  }
  cont=c->asm_len && info&1==c->fid && n;
  if (info&8 && hl>=8)
  {
    sof=(p+hl-2)(U16 *)[0]&2047;
    if (c->sof>=0 && (sof-c->sof)&2047>1)
    {
      c->sof_gaps++;
      c->sof_lost+=(sof-c->sof)&2047-1;
      if (cont)
      {
	c->in_gaps++;
	c->in_lost+=(sof-c->sof)&2047-1;
	c->f_lost+=(sof-c->sof)&2047-1;
      }
    }
    c->sof=sof;
  }
  if (n)
  {
    c->data_pl++;
    c->mf_data[c->mf]++;
    for (i=0; i<8; i++)
    {
      if (cont)
	c->mf_gap[i]+=c->mf_pend[i];
      c->mf_pend[i]=0;
    }
    if (cont)
    {
      if (c->zrun>c->zrun_max) c->zrun_max=c->zrun;
      if (c->zrun>c->f_zrun) c->f_zrun=c->zrun;
      if (c->zrun>=8) c->zrun_n++;
    }
    c->zrun=0;
  }
  if (c->asm_len && info&1!=c->fid)
    UvcFrameEnd(c);
  c->fid=info&1;
  if (info&0x40)
    c->bad=c->err=TRUE;
  c->raw_len+=n;
  if (c->asm_len+n>c->fsize)
  {
    c->over=TRUE;
    c->bad=TRUE;
    n=c->fsize-c->asm_len;
  }
  MemCpy(c->asm_buf+c->asm_len,p+hl,n);
  c->asm_len+=n;
  if (info&2)
    UvcFrameEnd(c);
}

U8 *uvc_cap=NULL;
I64 uvc_cap_n=0,uvc_cap_max=0;

I64 UvcCpu()
{//Where UvcTask runs: core 1 when there is one, else the caller's.
  if (mp_cnt>1)
    return 1;
  return -1;
}

U0 UvcTask(CUvc *c)
{//Reads the stream every millisecond: the kernel queues 32 ms of it.
  I64 i,n,k=c->k,gen=c->gen;
  U8 *p;
  CTask *own=c->owner;
  while (TRUE)
  {
    if (!TaskValidate(own))
    {
      UsbVenIsoStop(k,gen);
      return;
    }
    if (c->stop)
      break;
    n=UsbVenIsoRead(c->k,c->gen,c->iso_buf,c->lens,UVC_PKTS);
    if (n<0)
    {
      c->dead=TRUE;
      break;
    }
    p=c->iso_buf;
    for (i=0; i<n; i++)
    {
      c->mf=c->pkts&7;
      c->pkts++;
      if (uvc_cap && uvc_cap_n<uvc_cap_max)
      {
	MemSet(uvc_cap+uvc_cap_n*16,0,16);
	(uvc_cap+uvc_cap_n*16)(I16 *)[0]=c->lens[i];
	if (c->lens[i]>0)
	  MemCpy(uvc_cap+uvc_cap_n*16+2,p,MinI64(c->lens[i],14));
	uvc_cap_n++;
      }
      if (c->lens[i]<0)
      {
	c->lost++;
	if (c->asm_len)
	  c->bad=TRUE;
      }
      else
      {
	UvcPkt(c,p,c->lens[i]);
	p+=c->lens[i];
      }
    }
    if (n<UVC_PKTS)
      Sleep(1);
  }
  c->running=FALSE;
}

public U0 UvcStop(CUvc *c)
{//Stop streaming.
  if (!c->cur) return;
  c->stop=TRUE;
  while (c->running)
    Sleep(1);
  UsbVenIsoStop(c->k,c->gen);
  UsbVenCtl(c->k,c->gen,UVC_RT_IF,UVC_SET_IF,0,c->vs_if);
  Free(c->iso_buf);
  Free(c->lens);
  Free(c->asm_buf);
  Free(c->ready);
  c->iso_buf=c->lens=c->asm_buf=c->ready=NULL;
  c->cur=NULL;
}

public Bool UvcStart(CUvc *c,I64 w=640,I64 h=480,I64 fps=15,I64 type=-1)
{//Stream frames of w x h (or the nearest smaller size) at about fps.
  CUvcFrame *fr;
  CUvcAlt *a=NULL;
  I64 i,plen,want,best,d;
  U8 mx[48];
  UvcStop(c);
  if (!(fr=UvcPick(c,w,h,type)))
    return FALSE;
  want=10000000/ClampI64(fps,1,60);
  best=0;
  for (i=0; i<fr->nivl; i++)
    if (fr->ivl[i] && (!best || AbsI64(fr->ivl[i]-want)<AbsI64(best-want)))
      best=fr->ivl[i];
  if (!best) best=want;
  if (c->bcd>=0x150) plen=48;
  else if (c->bcd>=0x110) plen=34;
  else plen=26;
  MemSet(c->probe,0,48);
  c->probe[0]=1;
  c->probe[2]=fr->fmt;
  c->probe[3]=fr->idx;
  (c->probe+4)(U32 *)[0]=best;
  if (UsbVenCtlOut(c->k,c->gen,0x21,1,0x100,c->vs_if,c->probe,plen)<0)
    return FALSE;
  MemSet(mx,0,48);
  if (UsbVenCtl(c->k,c->gen,0xA1,0x83,0x100,c->vs_if,plen,mx)>=26)
  {
    (c->probe+12)(U16 *)[0]=(mx+12)(U16 *)[0];
    if (UsbVenCtlOut(c->k,c->gen,0x21,1,0x100,c->vs_if,c->probe,plen)<0)
      return FALSE;
  }
  if (UsbVenCtl(c->k,c->gen,0xA1,0x81,0x100,c->vs_if,plen,c->probe)<26)
    return FALSE;
  c->max_payload=(c->probe+22)(U32 *)[0];
  c->cur_ivl=(c->probe+4)(U32 *)[0];
  if (UsbVenCtlOut(c->k,c->gen,0x21,1,0x200,c->vs_if,c->probe,plen)<0)
    return FALSE;
  for (i=0; i<c->nalt; i++)
  {
    d=c->alt[i].bw;
    if (!a)
      a=&c->alt[i];
    else if (d>=c->max_payload)
    {
      if (a->bw<c->max_payload || d<a->bw)
	a=&c->alt[i];
    }
    else if (a->bw<c->max_payload && d>a->bw)
      a=&c->alt[i];
  }
  c->cur_alt=a->alt;
  if (UsbVenCtl(c->k,c->gen,UVC_RT_IF,UVC_SET_IF,a->alt,c->vs_if)<0)
    return FALSE;
  if ((c->pkt_max=UsbVenIsoStart(c->k,c->gen,a->ep,a->mps,a->ivl))<0)
  {
    UsbVenCtl(c->k,c->gen,UVC_RT_IF,UVC_SET_IF,0,c->vs_if);
    return FALSE;
  }
  c->iso_buf=MAlloc(UVC_PKTS*c->pkt_max);
  c->lens=MAlloc(UVC_PKTS*sizeof(I64));
  if (fr->type==UVC_YUY2)
    c->fsize=fr->w*fr->h*2;
  else
    c->fsize=MaxI64(MaxI64(fr->size,(c->probe+18)(U32 *)[0]),fr->w*fr->h*2);
  c->asm_buf=MAlloc(c->fsize);
  c->ready=MAlloc(c->fsize);
  c->asm_len=c->raw_len=0;
  c->bad=c->err=c->over=FALSE;
  c->ready_cnt=c->frames=c->bad_frames=c->pkts=c->lost=0;
  c->rej_err=c->rej_long=c->rej_lost=c->rej_short=c->rej_jpg=0;
  c->nhdr=c->nlen=c->padded=c->miss_sum=c->pl_max=c->pl_big=c->pl_empty=0;
  c->sof=-1;
  c->sof_gaps=c->sof_lost=c->in_gaps=c->in_lost=0;
  c->zrun=c->zrun_max=c->zrun_n=c->f_lost=c->f_zrun=c->data_pl=0;
  MemSet(c->mf_data,0,8*sizeof(I64));
  MemSet(c->mf_gap,0,8*sizeof(I64));
  MemSet(c->mf_pend,0,8*sizeof(I64));
  c->lock=0;
  c->stop=c->dead=FALSE;
  c->cur=fr;
  c->running=TRUE;
  c->owner=Fs;
  if (UvcCpu>=0)
    Spawn(&UvcTask,c,"UVC stream",UvcCpu);
  else
    Spawn(&UvcTask,c,"UVC stream",,Fs);
  return TRUE;
}

public I64 UvcGrab(CUvc *c,U8 *dst,I64 *_cnt)
{//Copy the newest whole frame to dst. Its length, 0 if none newer.
  I64 res=0;
  if (!c->cur || c->ready_cnt==*_cnt) return 0;
  while (LBts(&c->lock,0))
    Yield;
  if (c->ready_cnt!=*_cnt)
  {
    MemCpy(dst,c->ready,c->ready_len);
    *_cnt=c->ready_cnt;
    res=c->ready_len;
  }
  LBtr(&c->lock,0);
  return res;
}

public U0 UvcClose(CUvc *c)
{
  if (!c) return;
  UvcStop(c);
  Free(c);
}

#define UVC_PAL_ALL	0
#define UVC_PAL_16	1
#define UVC_PALS	2

I64 uvc_ty[256],uvc_trv[256],uvc_tgu[256],uvc_tgv[256],uvc_tbu[256],
	uvc_dofs[UVC_PALS*3*16];
U8 uvc_clip[1024],
	uvc_near[UVC_PALS*32*32*32];
U8 uvc_bayer[16]={0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
I64 uvc_spread[UVC_PALS]={51,85};
Bool uvc_tab_ok=FALSE;

I64 UvcNearest16(I64 r,I64 g,I64 b)
{//The nearest of the 16 CGA colors.
  I64 i,d,dr,dg,db,best=0,best_d=I64_MAX;
  CBGR48 c;
  for (i=0; i<16; i++)
  {
    c=GrPaletteColorGet(i);
    dr=r-c.r.u8[1];
    dg=g-c.g.u8[1];
    db=b-c.b.u8[1];
    d=dr*dr+dg*dg+db*db;
    if (d<best_d)
    {
      best_d=d;
      best=i;
    }
  }
  return best;
}

U0 UvcTabInit()
{
  I64 i,p,r,g,b,cx,cy;
  if (uvc_tab_ok) return;
  for (i=0; i<256; i++)
  {
    uvc_ty[i]=298*(i-16)+128;
    uvc_trv[i]=409*(i-128);
    uvc_tgu[i]=-100*(i-128);
    uvc_tgv[i]=-208*(i-128);
    uvc_tbu[i]=516*(i-128);
  }
  for (i=0; i<1024; i++)
    uvc_clip[i]=ClampI64(i-256,0,255);
  for (p=0; p<UVC_PALS; p++)
    for (i=0; i<16; i++)
    {//i is the 4x4 Bayer cell (i>>2,i&3).  Red keeps its phase; green and blue
      //get rotated ones so the dither moves the 3 channels independently and
      //can reach a tinted palette entry.  One shared offset only slides a pixel
      //along the gray diagonal, which is how a low chroma frame came out gray.
      cy=i>>2;
      cx=i&3;
      uvc_dofs[p*48+   i]=((2*uvc_bayer[i]+1)-16)*uvc_spread[p]/32;
      uvc_dofs[p*48+16+i]=((2*uvc_bayer[(((cy+1)&3)<<2)+((cx+2)&3)]+1)-16)*
	    uvc_spread[p]/32;
      uvc_dofs[p*48+32+i]=((2*uvc_bayer[(((cy+2)&3)<<2)+((cx+1)&3)]+1)-16)*
	    uvc_spread[p]/32;
    }
  for (i=0; i<32*32*32; i++)
  {
    r=i>>10<<3|4;
    g=(i>>5&31)<<3|4;
    b=(i&31)<<3|4;
    uvc_near[UVC_PAL_ALL*32768+i]=GetNearestColorNum(r,g,b);
    uvc_near[UVC_PAL_16*32768+i]=UvcNearest16(r,g,b);
    if (!(i&1023))
      Yield;
  }
  uvc_tab_ok=TRUE;
}

public U0 UvcToDC(U8 *src,I64 w,I64 h,CDC *dc,Bool dither=TRUE,
	I64 pal=UVC_PAL_ALL)
{//YUY2 frame src (w x h) into dc's top left, in color set pal.
  I64 x,y,yy,r,g,b,rv,gg,bu,o,o2,o3,k,*ofs,dw=MinI64(w,dc->width)&~1,dh=MinI64(h,dc->height);
  U8 *s,*d,*nr;
  UvcTabInit;
  pal=ClampI64(pal,0,UVC_PALS-1);
  nr=uvc_near+pal*32768;
  for (y=0; y<dh; y++)
  {
    s=src+y*w*2;
    d=dc->body+y*dc->width_internal;
    ofs=uvc_dofs+pal*48;
    for (x=0; x<dw; x+=2)
    {
      rv=uvc_trv[s[3]];
      gg=uvc_tgu[s[1]]+uvc_tgv[s[3]];
      bu=uvc_tbu[s[1]];
      o=0;
      o2=0;
      o3=0;
      if (dither)
      {
	k=(y&3)<<2+x&3;
	o =ofs[k];
	o2=ofs[16+k];
	o3=ofs[32+k];
      }
      yy=uvc_ty[s[0]];
      r=uvc_clip[uvc_clip[(yy+rv)>>8+256]+o+256];
      g=uvc_clip[uvc_clip[(yy+gg)>>8+256]+o2+256];
      b=uvc_clip[uvc_clip[(yy+bu)>>8+256]+o3+256];
      d[x]=nr[r>>3<<10|g>>3<<5|b>>3];
      if (dither)
      {
	k=(y&3)<<2+(x+1)&3;
	o =ofs[k];
	o2=ofs[16+k];
	o3=ofs[32+k];
      }
      yy=uvc_ty[s[2]];
      r=uvc_clip[uvc_clip[(yy+rv)>>8+256]+o+256];
      g=uvc_clip[uvc_clip[(yy+gg)>>8+256]+o2+256];
      b=uvc_clip[uvc_clip[(yy+bu)>>8+256]+o3+256];
      d[x+1]=nr[r>>3<<10|g>>3<<5|b>>3];
      s+=4;
    }
    if (!(y&15))
      Yield;
  }
}

public U0 UvcRgbToDC(U8 *rgb,I64 w,I64 h,CDC *dc,Bool dither=TRUE,
	I64 pal=UVC_PAL_ALL)
{//RGB24 picture (w x h) into dc's top left, like UvcToDC.
  I64 x,y,o,o2,o3,k,*ofs,dw=MinI64(w,dc->width),dh=MinI64(h,dc->height);
  U8 *s,*d,*nr;
  UvcTabInit;
  pal=ClampI64(pal,0,UVC_PALS-1);
  nr=uvc_near+pal*32768;
  ofs=uvc_dofs+pal*48;
  for (y=0; y<dh; y++)
  {
    s=rgb+y*w*3;
    d=dc->body+y*dc->width_internal;
    for (x=0; x<dw; x++)
    {
      o=0;
      o2=0;
      o3=0;
      if (dither)
      {
	k=(y&3)<<2+x&3;
	o =ofs[k];
	o2=ofs[16+k];
	o3=ofs[32+k];
      }
      d[x]=nr[uvc_clip[s[0]+o+256]>>3<<10|uvc_clip[s[1]+o2+256]>>3<<5|
	    uvc_clip[s[2]+o3+256]>>3];
      s+=3;
    }
    if (!(y&15))
      Yield;
  }
}

public Bool UvcFrameToDC(CUvc *c,U8 *frame,I64 len,CDC *dc,Bool dither=TRUE,
	I64 pal=UVC_PAL_ALL)
{//A frame from UvcGrab into dc, YUY2 or MJPEG. FALSE if a JPEG did not decode.
  U8 *rgb;
  I64 w,h;
  if (!c->cur) return FALSE;
  if (c->cur->type==UVC_YUY2)
  {
    UvcToDC(frame,c->cur->w,c->cur->h,dc,dither,pal);
    return TRUE;
  }
  if (!(rgb=JpgDecode(frame,len,&w,&h)))
    return FALSE;
  UvcRgbToDC(rgb,w,h,dc,dither,pal);
  Free(rgb);
  return TRUE;
}
