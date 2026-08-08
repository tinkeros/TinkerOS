#define NES_GENIE_MAX	32

#define NES_GENIE_LIST_MAX	64
#define NES_GENIE_CODES_LEN	96
#define NES_GENIE_DESC_LEN	72

U8 *nes_genie_letters="APZLGITYEOXUKSVN";

class CNESGenie
{
  I64 next;
  U16 addr;
  U8 patch_val;
  U8 cmp_val;
  U8 has_cmp;
  U8 text[12];
};

CNESGenie nes_genie[NES_GENIE_MAX];
I64 nes_genie_cnt=0;
Bool nes_genie_on=FALSE, nes_genie_over=FALSE;

U8 *nes_genie_map=NULL;

class CNESGenieItem
{//One line of a "Genie/<rom>.DD" file.
  U8 codes[NES_GENIE_CODES_LEN];
  U8 desc[NES_GENIE_DESC_LEN];
  Bool on;
};

CNESGenieItem nes_genie_list[NES_GENIE_LIST_MAX];
I64 nes_genie_list_cnt=0, nes_genie_list_bad=0;
U8 nes_genie_list_name[256];

I64 NESGenieLetter(U8 ch)
{
  I64 i;
  U8 up=ToUpper(ch);
  for (i=0; i<16; i++)
    if (nes_genie_letters[i]==up)
      return i;
  return -1;
}

Bool NESGenieDecode(U8 *code,CNESGenie *g)
{
  I64 n[8];
  I64 len,i,v;

  len=StrLen(code);
  if (len!=6 && len!=8)
    return FALSE;
  for (i=0; i<len; i++)
  {
    v=NESGenieLetter(code[i]);
    if (v<0)
      return FALSE;
    n[i]=v;
  }

  g->addr=0x8000+(((n[3]&7)<<12)|((n[5]&7)<<8)|((n[4]&8)<<8)|
          ((n[2]&7)<<4)|((n[1]&8)<<4)|(n[4]&7)|(n[3]&8));
  if (len==6)
  {
    g->patch_val=((n[1]&7)<<4)|((n[0]&8)<<4)|(n[0]&7)|(n[5]&8);
    g->cmp_val=0;
    g->has_cmp=FALSE;
  }
  else
  {
    g->patch_val=((n[1]&7)<<4)|((n[0]&8)<<4)|(n[0]&7)|(n[7]&8);
    g->cmp_val=((n[7]&7)<<4)|((n[6]&8)<<4)|(n[6]&7)|(n[5]&8);
    g->has_cmp=TRUE;
  }
  g->next=0;
  return TRUE;
}

U0 NESGenieClear()
{
  nes_genie_on=FALSE;
  nes_genie_over=FALSE;
  nes_genie_cnt=0;
  if (nes_genie_map)
  {
    Free(nes_genie_map);
    nes_genie_map=NULL;
  }
}

Bool NESGenieAdd(U8 *code)
{
  if (nes_genie_cnt>=NES_GENIE_MAX)
    return FALSE;
  if (!NESGenieDecode(code,&nes_genie[nes_genie_cnt]))
    return FALSE;
  StrCpy(nes_genie[nes_genie_cnt].text,code);
  nes_genie_cnt++;
  return TRUE;
}

U0 NESGenieBuildMap()
{
  I64 i,a;

  if (!nes_genie_cnt)
    return;
  if (!nes_genie_map)
    nes_genie_map=CAlloc(0x8000);
  else
    MemSet(nes_genie_map,0,0x8000);

  for (i=nes_genie_cnt-1; i>=0; i--)
  {
    a=nes_genie[i].addr-0x8000;
    nes_genie[i].next=nes_genie_map[a];
    nes_genie_map[a]=i+1;
  }
}

U8 NESGenieMap(U16 address,U8 raw)
{
  CNESGenie *g;
  I64 gi=nes_genie_map[address-0x8000];

  while (gi)
  {
    g=&nes_genie[gi-1];
    if (!g->has_cmp || g->cmp_val==raw)
      return g->patch_val;
    gi=g->next;
  }
  return raw;
}

U0 NESGenieList()
{
  I64 i;
  if (!nes_genie_cnt)
  {
    "TempleNES: no Game Genie codes.\n";
    return;
  }
  if (nes_genie_on)
    "TempleNES: %d Game Genie code(s), ON:\n",nes_genie_cnt;
  else
    "TempleNES: %d Game Genie code(s), OFF:\n",nes_genie_cnt;
  for (i=0; i<nes_genie_cnt; i++)
  {
    if (nes_genie[i].has_cmp)
    {
      "  %-8s  0x%04X = 0x%02X when 0x%02X\n",nes_genie[i].text,
      nes_genie[i].addr,nes_genie[i].patch_val,nes_genie[i].cmp_val;
    }
    else
    {
      "  %-8s  0x%04X = 0x%02X\n",nes_genie[i].text,
      nes_genie[i].addr,nes_genie[i].patch_val;
    }
  }
}

I64 NESGenieAddList(U8 *list,Bool quiet=FALSE)
{//Add every code in a '+', ',' or space separated list, returning how many
  U8 tok[24];
  I64 i,ti,n_ok=0;
  U8 ch;
  Bool too_long,done;

  if (!list || !*list)
    return 0;

  i=0;
  ti=0;
  too_long=FALSE;
  done=FALSE;
  while (!done)
  {
    ch=list[i];
    if (!ch)
      done=TRUE;
    if (!ch || ch=='+' || ch==',' || ch==';' || ch==' ' || ch=='\t' ||
        ch=='\n')
    {
      if (ti)
      {
        tok[ti]=0;
        if (nes_genie_cnt>=NES_GENIE_MAX)
        {
          nes_genie_over=TRUE;
          if (!quiet)
            "TempleNES: over %d Game Genie codes, \"%s\" ignored.\n",
            NES_GENIE_MAX,tok;
        }
        else if (too_long || !NESGenieAdd(tok))
        {
          if (!quiet)
            "TempleNES: \"%s\" isn't a Game Genie code, ignored.\n",tok;
        }
        else
          n_ok++;
      }
      ti=0;
      too_long=FALSE;
    }
    else
    {

      if (!(('0'<=ch<='9') || ('A'<=ch<='Z') || ('a'<=ch<='z')))
        ch='?';
      if (ti<23)
        tok[ti++]=ch;
      else
        too_long=TRUE;
    }
    i++;
  }
  return n_ok;
}

U0 NESGenieSet(U8 *list)
{//Replace the live codes with a list typed at the prompt.
  NESGenieClear;
  if (NESGenieAddList(list))
  {
    NESGenieBuildMap;
    nes_genie_on=TRUE;
  }
  NESGenieList;
}

U0 NESGenieCpy(U8 *dst,U8 *src,I64 max)
{//Bounded copy, always terminated.
  I64 i=0;
  while (src[i] && i<max-1)
  {
    dst[i]=src[i];
    i++;
  }
  dst[i]=0;
}

U0 NESGenieLabel(U8 *dst,U8 *src,I64 max)
{//Copy text for a DolDoc widget label.
  I64 i=0;
  U8 ch;
  while ((ch=*src++) && i<max-2)
  {
    if (ch==0x22)
      ch=0x27;
    if (ch=='$$')
      dst[i++]='$$';
    dst[i++]=ch;
  }
  dst[i]=0;
}

U0 NESGenieStripDollars(U8 *st)
{//Drop DolDoc cmds and unescape doubled dollar signs in place
  U8 *src=st,*dst=st,ch;
  Bool in_cmd=FALSE;
  while (ch=*src++)
  {
    if (ch=='$$')
    {
      if (in_cmd)
        in_cmd=FALSE;
      else if (*src=='$$')
      {
        src++;
        *dst++='$$';
      }
      else
        in_cmd=TRUE;
    }
    else if (!in_cmd && ch!=CH_CURSOR)
      *dst++=ch;
  }
  *dst=0;
}

U0 NESGenieListLine(U8 *line)
{//Parse one "CODE [+ CODE...]  Description" line into the pick list.
  U8 tok[24],*sep,*desc,*p;
  CNESGenie g;
  I64 ti,n;
  CNESGenieItem *it;

  while (*line==' ' || *line=='\t' || *line=='\r')
    line++;
  if (!*line || (*line=='/' && line[1]=='/'))
    return;

  sep=line;
  while (*sep)
  {
    if (*sep=='\t')
      break;
    if (*sep==' ' && sep[1]==' ')
    {
      p=sep;
      while (*p==' ')
        p++;
      if (*p!='+')
        break;
      p++;
      while (*p==' ')
        p++;
      sep=p;
    }
    else
      sep++;
  }
  desc=sep;
  while (*desc==' ' || *desc=='\t' || *desc=='\r')
    desc++;
  while (sep>line && (sep[-1]==' ' || sep[-1]=='\t'))
    sep--;
  *sep=0;
  n=StrLen(desc);
  while (n && (desc[n-1]==' ' || desc[n-1]=='\t' || desc[n-1]=='\r'))
    desc[--n]=0;

  p=line;
  n=0;
  while (*p)
  {
    while (*p==' ' || *p=='+' || *p=='\t')
      p++;
    ti=0;
    while (*p && *p!=' ' && *p!='+' && *p!='\t')
    {
      if (ti<23)
        tok[ti++]=*p;
      p++;
    }
    tok[ti]=0;
    if (!ti)
      break;
    if (!NESGenieDecode(tok,&g))
    {
      nes_genie_list_bad++;
      return;
    }
    n++;
  }
  if (!n || nes_genie_list_cnt>=NES_GENIE_LIST_MAX)
    return;
  if (StrLen(line)>=NES_GENIE_CODES_LEN)
  {
    nes_genie_list_bad++;
    return;
  }

  it=&nes_genie_list[nes_genie_list_cnt++];
  NESGenieCpy(it->codes,line,NES_GENIE_CODES_LEN);
  if (*desc)
    NESGenieCpy(it->desc,desc,NES_GENIE_DESC_LEN);
  else
    NESGenieCpy(it->desc,it->codes,NES_GENIE_DESC_LEN);
  it->on=FALSE;
}

Bool NESGenieLoadList(U8 *rom_filename)
{//Fill the pick list from "Genie/<rom name>.DD" (or .DD.Z).
  U8 *buf,*line,*next,*p,path[256],stem[256];
  I64 n;

  NESGenieClear;
  nes_genie_list_cnt=0;
  nes_genie_list_bad=0;
  *nes_genie_list_name=0;
  if (!rom_filename)
    return FALSE;

  p=StrLastOcc(rom_filename,"/");
  if (p)
    p++;
  else
    p=rom_filename;
  NESGenieCpy(stem,p,256);
  n=StrLen(stem);
  if (n>2 && !StrICmp(stem+n-2,".Z"))
    stem[n-2]=0;
  if (p=StrLastOcc(stem,"."))
    *p=0;
  StrCpy(nes_genie_list_name,stem);

  StrPrint(path,"%s/Genie/%s.DD",__DIR__,stem);
  if (!(buf=FileRead(path)))
    return FALSE;
  NESGenieStripDollars(buf);
  line=buf;
  while (*line && nes_genie_list_cnt<NES_GENIE_LIST_MAX)
  {
    if (next=StrFirstOcc(line,"\n"))
      *next++=0;
    else
      next=line+StrLen(line);
    NESGenieListLine(line);
    line=next;
  }
  Free(buf);
  return ToBool(nes_genie_list_cnt);
}

U0 NESGenieApplyList()
{//Rebuild the live codes from the checked items.
  I64 i;
  NESGenieClear;
  for (i=0; i<nes_genie_list_cnt; i++)
    if (nes_genie_list[i].on)
      NESGenieAddList(nes_genie_list[i].codes,TRUE);
  if (nes_genie_cnt)
  {
    NESGenieBuildMap;
    nes_genie_on=TRUE;
  }
}

Bool NESGeniePick()
{//'g': check off which of the ROM's codes to run.  TRUE back means reset
  CDoc *doc;
  CDocEntry *cb[NES_GENIE_LIST_MAX];
  U8 label[2*NES_GENIE_DESC_LEN],*msg;
  I64 i,res;
  Bool over=FALSE,reset=FALSE;

  NESGenieLabel(label,nes_genie_list_name,2*NES_GENIE_DESC_LEN);
  if (!nes_genie_list_cnt)
  {
    msg=MStrPrint("$$FG,4$$No Game Genie codes for \"%s\".$$FG$$\n\n"
            "Put them one per line in\n"
            "\"%s/Genie/%s.DD\".\n"
            "\"%s/Genie/README.DD\" has the format.\n\n",
            label,__DIR__,label,__DIR__);
    PopUpOk(msg);
    Free(msg);
    return FALSE;
  }

  doc=DocNew;
  DocPrint(doc,"$$LTBLUE$$Game Genie: %s$$FG$$\n"
      "Space checks a code.  ON runs what's checked, OFF\n"
      "runs none.  A code that patches the game's start up\n"
      "has nothing to bite on until you reset, so those\n"
      "want ON + RESET.\n\n",label);
  for (i=0; i<nes_genie_list_cnt; i++)
  {
    NESGenieLabel(label,nes_genie_list[i].desc,2*NES_GENIE_DESC_LEN);
    cb[i]=DocPrint(doc,"$$CB,\"%s\"$$\n",label);
    if (nes_genie_list[i].on)
      cb[i]->de_flags|=DOCEF_CHECKED_COLLAPSED;
  }
  if (nes_genie_list_bad)
    DocPrint(doc,"\n$$FG,4$$%d line(s) of the file weren't codes.$$FG$$\n",
        nes_genie_list_bad);
  DocPrint(doc,"\n  $$BT,\"ON\",LE=1$$\n\n\n  $$BT,\"ON + RESET\",LE=2$$"
      "\n\n\n  $$BT,\"OFF\",LE=3$$\n");
  res=PopUpMenu(doc);
  if (1<=res<=3)
  {
    for (i=0; i<nes_genie_list_cnt; i++)
      nes_genie_list[i].on=ToBool(cb[i]->de_flags&DOCEF_CHECKED_COLLAPSED);
    if (res==3)
      NESGenieClear;
    else
    {
      NESGenieApplyList;
      over=nes_genie_over;
      reset=ToBool(res==2);
    }
  }
  DocDel(doc);

  if (over)
    PopUpOk("$$FG,4$$Too many codes.$$FG$$\n\n"
        "Only 32 codes run at once, so the picks\n"
        "past that one are off.\n\n");
  return reset;
}
