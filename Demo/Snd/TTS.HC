
#help_index "Snd/TMS5220"

#define TTS_PI		3.14159265358979
#define TTS_RATE	8000.0

#define TTSK_PAUSE	0
#define TTSK_VOICED	1
#define TTSK_UVFRIC	2
#define TTSK_USTOP	3
#define TTSK_VSTOP	4

#define TTS_NPH		43
#define TPH_KIND	0
#define TPH_F1		1
#define TPH_F2		2
#define TPH_F3		3
#define TPH_F1B		4
#define TPH_F2B		5
#define TPH_F3B		6
#define TPH_GAP		7
#define TPH_E		8
#define TPH_DUR		9

U8 *tts_ph_name[TTS_NPH]={
  "IY","IH","EH","AE","AA","AH","AO","UH","UW","ER","AX",
  "EY","AY","OY","AW","OW",
  "W","Y","R","L","M","N","NG","V","DH",
  "S","SH","F","TH","HH","Z","ZH",
  "P","T","K","CH","JH",
  "B","D","G",
  "Q","QC","QP"};

I64 tts_ph_tab[TTS_NPH*10]={
    1,  270,2290,3010,   0,   0,   0,  0,10,  5,
    1,  390,1990,2550,   0,   0,   0,  0,10,  4,
    1,  530,1840,2480,   0,   0,   0,  0,10,  4,
    1,  660,1720,2410,   0,   0,   0,  0,10,  5,
    1,  730,1090,2440,   0,   0,   0,  0,11,  5,
    1,  640,1190,2390,   0,   0,   0,  0,10,  4,
    1,  570, 840,2410,   0,   0,   0,  0,11,  5,
    1,  440,1020,2240,   0,   0,   0,  0,10,  4,
    1,  300, 870,2240,   0,   0,   0,  0,10,  5,
    1,  490,1350,1690,   0,   0,   0,  0,10,  5,
    1,  500,1400,2400,   0,   0,   0,  0, 8,  2,
    1,  530,1840,2480, 330,2200,2800,  0,10,  6,
    1,  730,1090,2440, 330,2200,2800,  0,11,  7,
    1,  570, 840,2410, 330,2200,2800,  0,11,  7,
    1,  730,1090,2440, 350, 900,2240,  0,11,  7,
    1,  570, 900,2410, 330, 870,2240,  0,10,  6,
    1,  300, 610,2200,   0,   0,   0,  0, 8,  2,
    1,  280,2250,2900,   0,   0,   0,  0, 8,  2,
    1,  420,1300,1600,   0,   0,   0,  0, 9,  3,
    1,  380, 990,2600,   0,   0,   0,  0, 9,  3,
    1,  280, 900,2200,   0,   0,   0,  0, 7,  3,
    1,  280,1700,2600,   0,   0,   0,  0, 7,  3,
    1,  280,2300,2750,   0,   0,   0,  0, 7,  3,
    1,  300,1100,2200,   0,   0,   0,  0, 6,  2,
    1,  350,1600,2600,   0,   0,   0,  0, 6,  2,
    2, 3700, 400,3000, 800,   0,   0,  0, 7,  4,
    2, 2300, 300,3100, 700,   0,   0,  0, 8,  4,
    2, 3400,1600,   0,   0,   0,   0,  0, 5,  3,
    2, 3600,2000,   0,   0,   0,   0,  0, 5,  3,
    2, 1500,1500,   0,   0,   0,   0,  0, 5,  2,
    2, 3700, 400,3000, 800,   0,   0,  0, 6,  3,
    2, 2300, 300,3100, 700,   0,   0,  0, 6,  2,
    3,  800, 700,1900,1200,   0,   0,  2, 8,  1,
    3, 3600, 400,3000, 800,   0,   0,  2, 8,  1,
    3, 1900, 500,3300, 800,   0,   0,  2, 8,  1,
    3, 2300, 300,3100, 700,   0,   0,  1, 8,  3,
    3, 2300, 300,3100, 700,   0,   0,  1, 7,  2,
    4,  250, 700,2200,   0,   0,   0,  1, 8,  2,
    4,  300,1700,2600,   0,   0,   0,  1, 8,  2,
    4,  250,1900,2500,   0,   0,   0,  1, 8,  2,
    0,    0,   0,   0,   0,   0,   0,  0, 0,  2,
    0,    0,   0,   0,   0,   0,   0,  0, 0,  6,
    0,    0,   0,   0,   0,   0,   0,  0, 0, 12};

I64 tts_ph_ki[TTS_NPH*10],
    tts_ph_kib[TTS_NPH*10];

U8 *tts_digits[10]={"ZERO","ONE","TWO","THREE","FOUR","FIVE","SIX",
  "SEVEN","EIGHT","NINE"};

#define TTS_NUM_RULES	321
U8 *tts_rules[TTS_NUM_RULES]={
  " (A) =AX"," (ARE) =AA R"," (AR)O=AX R","(AR)#=EH R"," ^(AS)#=EY S",
  "(A)WA=AX","(AW)=AO"," :(ANY)=EH N IY","(A)^+#=EY","#:(ALLY)=AX L IY",
  " (AL)#=AX L","(AGAIN)=AX G EH N","#:(AG)E=IH JH","(A)^+:#=AE",
  " :(A)^+ =EY","(A)^%=EY"," (ARR)=AX R","(ARR)=AE R"," :(AR) =AA R",
  "(AR) =ER","(AR)=AA R","(AIR)=EH R","(AI)=EY","(AY)=EY","(AU)=AO",
  "#:(AL) =AX L","#:(ALS) =AX L Z","(ALK)=AO K","(AL)^=AO L",
  " :(ABLE)=EY B AX L","(ABLE)=AX B AX L","(ANG)+=EY N JH","#:^(A) =AX",
  "(A)=AE"," (BE)^#=B IH","(BEING)=B IY IH NG"," (BOTH) =B OW TH",
  " (BUS)#=B IH Z","(BUIL)=B IH L","B(B)=","(B)=B"," (CH)^=K","^E(CH)=K",
  "(CH)=CH"," S(CI)#=S AY","(CI)A=SH","(CI)O=SH","(CI)EN=SH","(C)+=S",
  "(CK)=K","(COM)%=K AH M","(C)=K","#:(DED) =D IH D","D(D)=",".E(D) =D",
  "#:^E(D) =T"," (DE)^#=D IH"," (DO) =D UW"," (DOES)=D AH Z",
  " (DOING)=D UW IH NG"," (DOW)=D AW","(DU)A=JH UW"," (DONT)=D OW N T",
  "(D)=D","#:(E) ="," :(E) =IY","#(ED) =D","#:(E)D =","(EV)ER=EH V",
  "(E)^%=IY","(ERI)#=IY R IY","(ERI)=EH R IH","#:(ER)#=ER","(ER)#=EH R",
  "(ER)=ER"," (EVEN)=IY V EH N","#:(E)W=","@(EW)=UW","(EW)=Y UW","(E)O=IY",
  "#:&(ES) =IH Z","#:(E)S =","#:(ELY) =L IY","#:(EMENT)=M EH N T",
  "(EFUL)=F UH L","(EE)=IY","(EARN)=ER N"," (EAR)^=ER","(EAD)=EH D",
  "#:(EA) =IY AX","(EA)SU=EH","(EA)=IY","(EIGH)=EY","(EI)=IY"," (EYE)=AY",
  "(EY)=IY","(EU)=Y UW","(E)=EH","F(F)=","(FUL)=F UH L","(F)=F",
  "(GIV)=G IH V"," (G)I^=G","(GE)T=G EH","SU(GGES)=G JH EH S","(GG)=G",
  " B#(G)=G","(G)+=JH","(GREAT)=G R EY T","#(GH)=","(G)=G"," (HAV)=HH AE V",
  " (HERE)=HH IY R"," (HOUR)=AW ER","(HOW)=HH AW","(H)#=HH","(H)=",
  " (IN)=IH N"," (I) =AY","(IN)D=AY N","(IER)=IY ER","#:R(IED) =IY D",
  "(IED) =AY D","(IEN)=IY EH N","(IE)T=AY EH"," :(I)%=AY","(I)%=IY",
  "(IE)=IY","(I)^+:#=IH","(IR)#=AY R","(IZ)%=AY Z","(IS)%=AY Z","(I)D%=AY",
  "+^(I)^+=IH","(I)T%=AY","#:^(I)^+=IH","(I)^+=AY","(IR)=ER","(IGH)=AY",
  "(ILD)=AY L D","(IGN) =AY N","(IGN)^=AY N","(IGN)%=AY N","(IQUE)=IY K",
  "(I)=IH","(J)=JH"," (K)N=","(K)=K","(LO)C#=L OW","L(L)=","#:^(L)%=AX L",
  "(LEAD)=L IY D","(L)=L","M(M)=","(MOV)=M UW V","(M)=M","N(N)=",
  "E(NG)+=N JH","(NG)R=NG G","(NG)#=NG G","(NGL)%=NG G AX L","(NG)=NG",
  "(NK)=NG K"," (NOW) =N AW","(N)=N","(OF) =AX V","(OROUGH)=ER OW",
  "#:(OR) =ER","#:(ORS) =ER Z","(OR)=AO R"," (ONE)=W AH N","(OW)=OW",
  " (OVER)=OW V ER","(OV)=AH V","(O)^%=OW","(O)^EN=OW","(O)^I#=OW",
  "(OL)D=OW L","(OUGHT)=AO T","(OUGH)=AH F"," (OU)=AW","(OUS)E=AW S",
  "H(OU)S#=AW","(OUS)=AX S","(OUR)=AO R","(OULD)=UH D","^(OU)^L=AH",
  "(OUP)=UW P","(OU)=AW","(OY)=OY","(OING)=OW IH NG","(OI)=OY","(OOR)=AO R",
  "(OOK)=UH K","(OOD)=UH D","(OO)=UW","(O)E=OW","(O) =OW","(OAR)=AO R",
  "(OA)=OW"," (ONLY)=OW N L IY"," (ONCE)=W AH N S"," (WONT)=W OW N T",
  "C(O)N=AA","(O)NG=AO"," :^(O)N=AH","I(ON)=AX N","#:(ON) =AX N",
  "#:^(ON)=AX N","(O)ST =OW","(OF)^=AO F","(OTHER)=AH DH ER","(OSS) =AO S",
  "#:^(OM)=AH M","(O)=AA","P(P)=","(PH)=F","(PEOP)=P IY P","(POW)=P AW",
  "(PUT) =P UH T","(P)=P","(QUAR)=K W AO R","(QU)=K W","(Q)=K",
  " (RE)^#=R IY","R(R)=","(R)=R","(SH)=SH","#(SION)=ZH AX N",
  "(SOME)=S AH M","#(SUR)#=ZH ER","(SUR)#=SH ER","#(SU)#=ZH UW",
  "#(SSU)#=SH UW","#(SED) =Z D","#(S)#=Z","(SAID)=S EH D","^(SION)=SH AX N",
  "(S)S=",".(S) =Z","#:.E(S) =Z","#:^##(S) =Z","#:^#(S) =S","U(S) =S",
  " :#(S) =Z"," (SCH)=S K","(S)C+=","#(SM)=Z M","(S)=S"," (THE) =DH AX",
  "(TO) =T UW","(THAT)=DH AE T"," (THIS) =DH IH S"," (THEY)=DH EY",
  " (THERE)=DH EH R","(THER)=DH ER","(THEIR)=DH EH R"," (THAN) =DH AE N",
  " (THEM) =DH EH M","(THESE) =DH IY Z"," (THEN)=DH EH N",
  "(THROUGH)=TH R UW","(THOSE)=DH OW Z","(THOUGH) =DH OW"," (THUS)=DH AH S",
  "(TH)=TH","#:(TED) =T IH D","T(T)=","S(TI)#N=CH","(TI)O=SH","(TI)A=SH",
  "(TIEN)=SH AX N","(TUR)#=CH ER","(TU)A=CH UW"," (TWO)=T UW","(T)=T",
  " (UN)I=Y UW N"," (UN)=AH N"," (UPON)=AX P AO N","@(UR)#=UH R",
  "(UR)#=Y UH R","(UR)=ER","(U)^ =AH","(U)^^=AH","(UY)=AY"," G(U)#=",
  "G(U)%=","G(U)#=","#N(U)=Y UW","@(U)=UW","(U)=Y UW","(VIEW)=V Y UW",
  "(V)=V"," (WERE)=W ER","(WA)S=W AA","(WA)T=W AA","(WHERE)=W EH R",
  "(WHAT)=W AA T","(WHOL)=HH OW L","(WHO)=HH UW","(WH)=W","(WAR)=W AO R",
  "(WOR)^=W ER","(WR)=R","(W)=W"," (X)=Z","(X)=K S","(YOUNG)=Y AH NG",
  " (YOU)=Y UW"," (YES)=Y EH S"," (Y)=Y","#:^(Y) =IY","#:^(Y)I=IY",
  " :(Y) =AY"," :(Y)#=AY"," :(Y)^+:#=IH"," :(Y)^#=AY","(Y)=IH","Z(Z)=",
  "(Z)=Z",
  NULL};

F64 tts_period0=58.0,tts_period_step=0.10,tts_period_max=90.0,
    tts_vibrato=1.2;

class CTTSEnc
{
  U8 *buf;
  I64 bit_pos,frame_no;
  F64 period;
};

U0 TTSResK(F64 *rf,F64 *rb,I64 n_res,I64 n_st,I64 *out_idx)
{
  F64 a[11],t[11],k[10],r,c1,c2,km,d,v;
  I64 i,j,m,deg;
  for (i=0;i<11;i++)
    a[i]=0.0;
  a[0]=1.0;
  deg=0;
  for (m=0;m<n_res;m++) {
    r=Exp(-TTS_PI*rb[m]/TTS_RATE);
    c1=-2.0*r*Cos(2.0*TTS_PI*rf[m]/TTS_RATE);
    c2=r*r;
    for (j=deg+2;j>=0;j--) {
      v=0.0;
      if (j<=deg)
	v=a[j];
      if (j>=1)
	v+=c1*a[j-1];
      if (j>=2)
	v+=c2*a[j-2];
      t[j]=v;
    }
    for (j=0;j<=deg+2;j++)
      a[j]=t[j];
    deg+=2;
  }
  for (i=0;i<10;i++)
    k[i]=0.0;
  for (m=n_st;m>=1;m--) {
    km=a[m];
    k[m-1]=km;
    d=1.0-km*km;
    if (d<0.001)
      d=0.001;
    for (j=1;j<m;j++)
      t[j]=(a[j]-km*a[m-j])/d;
    for (j=1;j<m;j++)
      a[j]=t[j];
    a[m]=0.0;
  }
  for (i=0;i<n_st;i++)
    out_idx[i]=TMS5220QuantK(i,k[i]);
}

U0 TTSInitPhone(I64 f1,I64 f2,I64 f3,I64 *out_idx)
{
  F64 rf[4],rb[4];
  rf[0]=f1; rb[0]=60.0;
  rf[1]=f2; rb[1]=90.0;
  rf[2]=f3; rb[2]=150.0;
  rf[3]=3400.0; rb[3]=200.0;
  TTSResK(rf,rb,4,10,out_idx);
}

U0 TTSInit()
{
  I64 i,*row,n;
  F64 rf[2],rb[2];
  TMS5220InitTabs;
  for (i=0;i<TTS_NPH;i++) {
    row=&tts_ph_tab[i*10];
    switch (row[TPH_KIND]) {
      case TTSK_VOICED:
      case TTSK_VSTOP:
	TTSInitPhone(row[TPH_F1],row[TPH_F2],row[TPH_F3],
	      &tts_ph_ki[i*10]);
	if (row[TPH_F1B])
	  TTSInitPhone(row[TPH_F1B],row[TPH_F2B],row[TPH_F3B],
		&tts_ph_kib[i*10]);
	break;
      case TTSK_UVFRIC:
      case TTSK_USTOP:
	rf[0]=row[TPH_F1]; rb[0]=row[TPH_F2];
	n=1;
	if (row[TPH_F3]) {
	  rf[1]=row[TPH_F3]; rb[1]=row[TPH_F1B];
	  n=2;
	}
	TTSResK(rf,rb,n,4,&tts_ph_ki[i*10]);
	break;
    }
  }
}

I64 TTSPhLookup(U8 *s,I64 n)
{
  I64 i;
  U8 *nm;
  for (i=0;i<TTS_NPH;i++) {
    nm=tts_ph_name[i];
    if (StrLen(nm)==n && !MemCmp(nm,s,n))
      return i;
  }
  return -1;
}

Bool TTSIsVow(U8 c)
{
  return StrOcc("AEIOUY",c)>0;
}

Bool TTSIsCons(U8 c)
{
  return 'A'<=c<='Z' && !TTSIsVow(c);
}

U8 TTSCh(U8 *txt,I64 len,I64 i)
{
  if (i<0 || i>=len)
    return ' ';
  return txt[i];
}

Bool TTSMatchLeft(U8 *txt,I64 len,I64 pos,U8 *pat,I64 n)
{
  I64 i=pos-1,j,pc,c;
  for (j=n-1;j>=0;j--) {
    pc=pat[j];
    c=TTSCh(txt,len,i);
    switch (pc) {
      case ' ':
	if ('A'<=c<='Z')
	  return FALSE;
	i--;
	break;
      case '#':
	if (!TTSIsVow(c))
	  return FALSE;
	i--;
	while (TTSIsVow(TTSCh(txt,len,i)))
	  i--;
	break;
      case ':':
	while (TTSIsCons(TTSCh(txt,len,i)))
	  i--;
	break;
      case '^':
	if (!TTSIsCons(c))
	  return FALSE;
	i--;
	break;
      case '+':
	if (c!='E' && c!='I' && c!='Y')
	  return FALSE;
	i--;
	break;
      case '.':
	if (!StrOcc("BDVGJLMNRWZ",c))
	  return FALSE;
	i--;
	break;
      case '&':
	if (c=='H' && StrOcc("CS",TTSCh(txt,len,i-1)))
	  i-=2;
	else if (StrOcc("SCGZXJ",c))
	  i--;
	else
	  return FALSE;
	break;
      case '@':
	if (c=='H' && StrOcc("TCS",TTSCh(txt,len,i-1)))
	  i-=2;
	else if (StrOcc("DJLNRSTZ",c))
	  i--;
	else
	  return FALSE;
	break;
      default:
	if (c!=pc)
	  return FALSE;
	i--;
	break;
    }
  }
  return TRUE;
}

Bool TTSMatchRight(U8 *txt,I64 len,I64 pos,U8 *pat,I64 n)
{
  I64 i=pos,j,pc,c;
  for (j=0;j<n;j++) {
    pc=pat[j];
    c=TTSCh(txt,len,i);
    switch (pc) {
      case ' ':
	if ('A'<=c<='Z')
	  return FALSE;
	i++;
	break;
      case '#':
	if (!TTSIsVow(c))
	  return FALSE;
	i++;
	while (TTSIsVow(TTSCh(txt,len,i)))
	  i++;
	break;
      case ':':
	while (TTSIsCons(TTSCh(txt,len,i)))
	  i++;
	break;
      case '^':
	if (!TTSIsCons(c))
	  return FALSE;
	i++;
	break;
      case '+':
	if (c!='E' && c!='I' && c!='Y')
	  return FALSE;
	i++;
	break;
      case '.':
	if (!StrOcc("BDVGJLMNRWZ",c))
	  return FALSE;
	i++;
	break;
      case '&':
	if (StrOcc("CS",c) && TTSCh(txt,len,i+1)=='H')
	  i+=2;
	else if (StrOcc("SCGZXJ",c))
	  i++;
	else
	  return FALSE;
	break;
      case '@':
	if (StrOcc("TCS",c) && TTSCh(txt,len,i+1)=='H')
	  i+=2;
	else if (StrOcc("DJLNRSTZ",c))
	  i++;
	else
	  return FALSE;
	break;
      case '%':
	if (c=='I') {
	  if (TTSCh(txt,len,i+1)=='N' && TTSCh(txt,len,i+2)=='G')
	    i+=3;
	  else
	    return FALSE;
	} else if (c=='E') {
	  if (TTSCh(txt,len,i+1)=='L' && TTSCh(txt,len,i+2)=='Y')
	    i+=3;
	  else if (StrOcc("RSD",TTSCh(txt,len,i+1)))
	    i+=2;
	  else
	    i++;
	} else
	  return FALSE;
	break;
      default:
	if (c!=pc)
	  return FALSE;
	i++;
	break;
    }
  }
  return TRUE;
}

U8 *TTSNormalize(U8 *src)
{
  I64 n=StrLen(src),i,j,c;
  U8 *dst=MAlloc(10*n+16),*s;
  j=0;
  dst[j++]=' ';
  for (i=0;i<n;i++) {
    c=ToUpper(src[i]);
    if ('A'<=c<='Z')
      dst[j++]=c;
    else if ('0'<=c<='9') {
      dst[j++]=' ';
      s=tts_digits[c-'0'];
      while (*s)
	dst[j++]=*s++;
      dst[j++]=' ';
    } else if (c=='.' || c=='!' || c=='?')
      dst[j++]='.';
    else if (c==',' || c==';' || c==':')
      dst[j++]=',';
    else if (c==39) {
    } else
      dst[j++]=' ';
  }
  dst[j++]=' ';
  dst[j]=0;
  return dst;
}

I64 TTSPhonemize(U8 *txt,I64 len,I64 *ph)
{
  I64 n=0,pos=0,i,ri,lp,rp,eq,ml,idx,last=-1,c;
  U8 *r,*p,*tok;
  Bool found,ok;
  while (pos<len) {
    c=txt[pos];
    if (c=='.') {
      ph[n++]=TTS_NPH-1;
      last=TTS_NPH-1;
      pos++;
    } else if (c==',') {
      ph[n++]=TTS_NPH-2;
      last=TTS_NPH-2;
      pos++;
    } else if ('A'<=c<='Z') {
      found=FALSE;
      ri=0;
      while (!found && tts_rules[ri]) {
	r=tts_rules[ri];
	lp=0;
	while (r[lp]!='(')
	  lp++;
	rp=lp+1;
	while (r[rp]!=')')
	  rp++;
	eq=rp+1;
	while (r[eq]!='=')
	  eq++;
	ml=rp-lp-1;
	if (r[lp+1]==c) {
	  ok=TRUE;
	  for (i=1;i<ml;i++)
	    if (TTSCh(txt,len,pos+i)!=r[lp+1+i])
	      ok=FALSE;
	  if (ok && TTSMatchLeft(txt,len,pos,r,lp) &&
	      TTSMatchRight(txt,len,pos+ml,&r[rp+1],eq-rp-1)) {
	    p=&r[eq+1];
	    while (*p) {
	      while (*p==' ')
		p++;
	      tok=p;
	      while (*p && *p!=' ')
		p++;
	      if (p>tok) {
		idx=TTSPhLookup(tok,p-tok);
		if (idx>=0) {
		  ph[n++]=idx;
		  last=idx;
		}
	      }
	    }
	    pos+=ml;
	    found=TRUE;
	  }
	}
	ri++;
      }
      if (!found)
	pos++;
    } else {
      if (n && last<TTS_NPH-3) {
	ph[n++]=TTS_NPH-3;
	last=TTS_NPH-3;
      }
      pos++;
    }
  }
  return n;
}

U0 TTSPutBits(CTTSEnc *e,I64 v,I64 n)
{
  I64 i;
  for (i=n-1;i>=0;i--) {
    if (v>>i&1)
      e->buf[e->bit_pos>>3]|=1<<(e->bit_pos&7);
    e->bit_pos++;
  }
}

I64 TTSPitch(CTTSEnc *e)
{
  F64 p=e->period+tts_vibrato*Cos(e->frame_no*0.55);
  return TMS5220QuantPitch(p);
}

U0 TTSTick(CTTSEnc *e)
{
  e->frame_no++;
  e->period+=tts_period_step;
  if (e->period>tts_period_max)
    e->period=tts_period_max;
}

U0 TTSSilence(CTTSEnc *e,I64 n)
{
  I64 i;
  for (i=0;i<n;i++) {
    TTSPutBits(e,0,4);
    TTSTick(e);
  }
}

U0 TTSVoiced(CTTSEnc *e,I64 energy,I64 *ki,I64 dur)
{
  I64 i;
  TTSPutBits(e,energy,4);
  TTSPutBits(e,0,1);
  TTSPutBits(e,TTSPitch(e),6);
  for (i=0;i<10;i++)
    TTSPutBits(e,ki[i],tms5220_k_bits[i]);
  TTSTick(e);
  for (i=1;i<dur;i++) {
    TTSPutBits(e,energy,4);
    TTSPutBits(e,1,1);
    TTSPutBits(e,TTSPitch(e),6);
    TTSTick(e);
  }
}

U0 TTSUnvoiced(CTTSEnc *e,I64 energy,I64 *ki,I64 dur)
{
  I64 i;
  TTSPutBits(e,energy,4);
  TTSPutBits(e,0,1);
  TTSPutBits(e,0,6);
  for (i=0;i<4;i++)
    TTSPutBits(e,ki[i],tms5220_k_bits[i]);
  TTSTick(e);
  for (i=1;i<dur;i++) {
    TTSPutBits(e,energy,4);
    TTSPutBits(e,1,1);
    TTSPutBits(e,0,6);
    TTSTick(e);
  }
}

public U8 *TTSEncode(U8 *text,I64 *_size)
{
  U8 *txt;
  I64 *ph,n_ph,i,idx,kind,dur,d1,d2,energy,*row,buf_size;
  CTTSEnc enc;
  txt=TTSNormalize(text);
  i=StrLen(txt);
  ph=MAlloc((2*i+16)*sizeof(I64));
  n_ph=TTSPhonemize(txt,i,ph);
  buf_size=n_ph*24+64;
  enc.buf=MAlloc(buf_size);
  MemSet(enc.buf,0,buf_size);
  enc.bit_pos=0;
  enc.frame_no=0;
  enc.period=tts_period0;
  TTSSilence(&enc,1);
  for (i=0;i<n_ph;i++) {
    idx=ph[i];
    row=&tts_ph_tab[idx*10];
    kind=row[TPH_KIND];
    energy=row[TPH_E];
    dur=row[TPH_DUR];
    switch (kind) {
      case TTSK_PAUSE:
	TTSSilence(&enc,dur);
	if (idx==TTS_NPH-1)
	  enc.period=tts_period0;
	break;
      case TTSK_VOICED:
	if (row[TPH_F1B]) {
	  d1=(dur+1)/2;
	  d2=dur-d1;
	  if (d2<1)
	    d2=1;
	  TTSVoiced(&enc,energy,&tts_ph_ki[idx*10],d1);
	  TTSVoiced(&enc,energy,&tts_ph_kib[idx*10],d2);
	} else
	  TTSVoiced(&enc,energy,&tts_ph_ki[idx*10],dur);
	break;
      case TTSK_UVFRIC:
	TTSUnvoiced(&enc,energy,&tts_ph_ki[idx*10],dur);
	break;
      case TTSK_USTOP:
	TTSSilence(&enc,row[TPH_GAP]);
	TTSUnvoiced(&enc,energy,&tts_ph_ki[idx*10],dur);
	break;
      case TTSK_VSTOP:
	TTSSilence(&enc,row[TPH_GAP]);
	TTSVoiced(&enc,energy,&tts_ph_ki[idx*10],dur);
	break;
    }
  }
  TTSPutBits(&enc,15,4);
  Free(ph);
  Free(txt);
  *_size=(enc.bit_pos+7)>>3;
  return enc.buf;
}

public U0 TTSPhonemes(U8 *text)
{
  U8 *txt;
  I64 *ph,n,i,len;
  txt=TTSNormalize(text);
  len=StrLen(txt);
  ph=MAlloc((2*len+16)*sizeof(I64));
  n=TTSPhonemize(txt,len,ph);
  for (i=0;i<n;i++)
    "%s ",tts_ph_name[ph[i]];
  "\n";
  Free(ph);
  Free(txt);
}

public Bool Speak(U8 *text, Bool bkg=TRUE)
{
  U8 *st;
  I64 size;
  Bool res;
  st=TTSEncode(text,&size);
  res=TMS5220PlayStream(st,size,bkg);
  Free(st);
  return res;
}

TTSInit;
"TTS module loaded.\n";

#help_index ""
