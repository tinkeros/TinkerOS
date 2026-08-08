#define GEN_GENIE_MAX	32
#define GEN_GENIE_TOK	24
#define GEN_RAM_BASE	0xE00000
#define GEN_GENIE_LIST_MAX	64
#define GEN_GENIE_CODES_LEN	96
#define GEN_GENIE_DESC_LEN	72

U8 *gen_genie_letters="ABCDEFGHJKLMNPRSTVWXYZ0123456789";

class CGenGenie
{
  U32	addr;
  U16	patch_val;
  U16	orig_val;
  Bool	applied;
  U8	text[12];
};

CGenGenie gen_genie[GEN_GENIE_MAX];
I64 gen_genie_cnt=0;
I64 gen_genie_ram_cnt=0;
Bool gen_genie_on=FALSE, gen_genie_over=FALSE;

class CGenGenieItem
{//One line of a "Genie/<rom>.DD" file.
  U8	codes[GEN_GENIE_CODES_LEN];
  U8	desc[GEN_GENIE_DESC_LEN];
  Bool	on;
};

CGenGenieItem gen_genie_list[GEN_GENIE_LIST_MAX];
I64 gen_genie_list_cnt=0, gen_genie_list_bad=0;
U8 gen_genie_list_name[256];

I64 GenGenieLetter(U8 ch)
{//Position of ch in the Game Genie alphabet, or -1.
  I64 i;
  U8 up=ToUpper(ch);
  for (i=0; i<32; i++)
    if (gen_genie_letters[i]==up)
      return i;
  return -1;
}

Bool GenGenieDecode(U8 *code, CGenGenie *g)
{//Descramble one code.  Hyphens and blanks in it are ignored.
  I64 i,n,cnt=0;
  U32 addr=0,val=0;
  U8 v[8];

  while (*code)
  {
    if (*code=='-' || *code==' ' || *code=='\t')
      code++;
    else
    {
      n=GenGenieLetter(*code++);
      if (n<0 || cnt>=8)
        return FALSE;
      v[cnt++]=n;
    }
  }
  if (cnt!=8)
    return FALSE;
  for (i=0; i<8; i++)
  {
    n=v[i];
    switch (i)
    {
    case 0:
      val|=n<<3;
      break;
    case 1:
      val|=n>>2;
      addr|=(n&3)<<14;
      break;
    case 2:
      addr|=n<<9;
      break;
    case 3:
      addr|=(n&0xF)<<20|(n>>4)<<8;
      break;
    case 4:
      val|=(n&1)<<12;
      addr|=(n>>1)<<16;
      break;
    case 5:
      val|=(n&1)<<15|(n>>1)<<8;
      break;
    case 6:
      val|=(n>>3)<<13;
      addr|=(n&7)<<5;
      break;
    case 7:
      addr|=n;
      break;
    }
  }
  g->addr=addr&0xFFFFFE;
  g->patch_val=val;
  g->orig_val=0;
  g->applied=FALSE;
  for (i=0; i<8; i++)
    g->text[i+(i>=4)]=gen_genie_letters[v[i]];
  g->text[4]='-';
  g->text[9]=0;
  return TRUE;
}

U0 GenGenieApply()
{//Poke the cartridge space codes into the ROM image, saving what they cover.
  I64 i;
  CGenGenie *g;
  if (!ROM || !gen_genie_on)
    return;
  for (i=0; i<gen_genie_cnt; i++)
  {
    g=&gen_genie[i];
    if (!g->applied && g->addr+1<GEN_ROM_SIZE)
    {
      g->orig_val=ROM[g->addr]<<8|ROM[g->addr+1];
      ROM[g->addr]=g->patch_val>>8&0xFF;
      ROM[g->addr+1]=g->patch_val&0xFF;
      g->applied=TRUE;
    }
  }
}

U0 GenGenieUnapply()
{//Put the original ROM words back.
  I64 i;
  CGenGenie *g;
  for (i=gen_genie_cnt-1; i>=0; i--)
  {
    g=&gen_genie[i];
    if (g->applied)
    {
      if (ROM && g->addr+1<GEN_ROM_SIZE)
      {
        ROM[g->addr]=g->orig_val>>8&0xFF;
        ROM[g->addr+1]=g->orig_val&0xFF;
      }
      g->applied=FALSE;
    }
  }
}

U0 GenGenieFrame()
{//Work RAM codes have to be rewritten every frame.  Costs nothing if unused.
  I64 i;
  U32 a;
  CGenGenie *g;
  if (!gen_genie_ram_cnt || !gen_genie_on || !RAM)
    return;
  for (i=0; i<gen_genie_cnt; i++)
  {
    g=&gen_genie[i];
    a=g->addr;
    if (a>=GEN_RAM_BASE)
    {
      RAM[a&0xFFFF]=g->patch_val>>8&0xFF;
      RAM[(a+1)&0xFFFF]=g->patch_val&0xFF;
    }
  }
}

U0 GenGenieClear()
{//Drop every code.  Codes belong to one game, so a ROM change calls this.
  GenGenieUnapply;
  MemSet(gen_genie,0,GEN_GENIE_MAX*sizeof(CGenGenie));
  gen_genie_cnt=0;
  gen_genie_ram_cnt=0;
  gen_genie_on=FALSE;
  gen_genie_over=FALSE;
}

Bool GenGenieAdd(U8 *code)
{
  if (gen_genie_cnt>=GEN_GENIE_MAX)
    return FALSE;
  if (!GenGenieDecode(code,&gen_genie[gen_genie_cnt]))
    return FALSE;
  if (gen_genie[gen_genie_cnt].addr>=GEN_RAM_BASE)
    gen_genie_ram_cnt++;
  gen_genie_cnt++;
  return TRUE;
}

U0 GenGenieList()
{
  I64 i;
  CGenGenie *g;
  if (!gen_genie_cnt)
  {
		"TempleGen: no Game Genie codes.\n";
    return;
  }
  if (gen_genie_on)
		"TempleGen: %d Game Genie code(s), ON:\n",gen_genie_cnt;
  else
		"TempleGen: %d Game Genie code(s), OFF:\n",gen_genie_cnt;
  for (i=0; i<gen_genie_cnt; i++)
  {
    g=&gen_genie[i];
    if (g->addr>=GEN_RAM_BASE)
      "  %-10s  0x%06X = 0x%04X (work RAM)\n",
      g->text,g->addr,g->patch_val;
    else if (g->addr+1>=GEN_ROM_SIZE)
      "  %-10s  0x%06X = 0x%04X (not cartridge, ignored)\n",
      g->text,g->addr,g->patch_val;
    else
      "  %-10s  0x%06X = 0x%04X\n",
      g->text,g->addr,g->patch_val;
  }
}

I64 GenGenieAddList(U8 *list,Bool quiet=FALSE)
{//Add every code in a '+', ',' or space separated list, returning how many.
  I64 i=0,ti=0,n_ok=0;
  U8 ch,tok[GEN_GENIE_TOK];
  Bool too_long=FALSE,done=FALSE;

  if (!list || !*list)
    return 0;
  while (!done)
  {
    ch=list[i];
    if (!ch)
      done=TRUE;
    if (!ch || ch=='+' || ch==',' || ch==';' || ch==' ' ||
        ch=='\t' || ch=='\n' || ch=='\r')
    {
      if (ti)
      {
        tok[ti]=0;
        if (gen_genie_cnt>=GEN_GENIE_MAX)
        {
          gen_genie_over=TRUE;
          if (!quiet)
            "TempleGen: over %d Game Genie "
            "codes, \"%s\" ignored.\n",
            GEN_GENIE_MAX,tok;
        }
        else if (too_long || !GenGenieAdd(tok))
        {
          if (!quiet)
            "TempleGen: \"%s\" isn't a Game "
						        "Genie code, ignored.\n",tok;
        }
        else
          n_ok++;
      }
      ti=0;
      too_long=FALSE;
    }
    else
    {
      if (ch!='-' && !Bt(char_bmp_alpha_numeric,ch))
        ch='?';
      if (ti<GEN_GENIE_TOK-1)
        tok[ti++]=ch;
      else
        too_long=TRUE;
    }
    i++;
  }
  return n_ok;
}

U0 GenGenieSet(U8 *list)
{//Replace the live codes with a list typed at the prompt.
  GenGenieClear;
  if (GenGenieAddList(list))
  {
    gen_genie_on=TRUE;
    GenGenieApply;
  }
  GenGenieList;
}

U0 GenGenieCpy(U8 *dst,U8 *src,I64 max)
{//Bounded copy, always terminated.
  I64 i=0;
  while (src[i] && i<max-1)
  {
    dst[i]=src[i];
    i++;
  }
  dst[i]=0;
}

U0 GenGenieLabel(U8 *dst,U8 *src,I64 max)
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

U0 GenGenieStripDollars(U8 *st)
{//Drop DolDoc cmds and unescape doubled dollar signs in place.
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

U0 GenGenieListLine(U8 *line)
{//Parse one "CODE [+ CODE...]  Description" line into the pick list.
  U8 tok[GEN_GENIE_TOK],*sep,*desc,*p;
  CGenGenie g;
  I64 ti,n;
  CGenGenieItem *it;

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
      if (ti<GEN_GENIE_TOK-1)
        tok[ti++]=*p;
      p++;
    }
    tok[ti]=0;
    if (!ti)
      break;
    if (!GenGenieDecode(tok,&g))
    {
      gen_genie_list_bad++;
      return;
    }
    n++;
  }
  if (!n || gen_genie_list_cnt>=GEN_GENIE_LIST_MAX)
    return;
  if (StrLen(line)>=GEN_GENIE_CODES_LEN)
  {
    gen_genie_list_bad++;
    return;
  }

  it=&gen_genie_list[gen_genie_list_cnt++];
  GenGenieCpy(it->codes,line,GEN_GENIE_CODES_LEN);
  if (*desc)
    GenGenieCpy(it->desc,desc,GEN_GENIE_DESC_LEN);
  else
    GenGenieCpy(it->desc,it->codes,GEN_GENIE_DESC_LEN);
  it->on=FALSE;
}

Bool GenGenieLoadList(U8 *rom_filename)
{//Fill the pick list from "Genie/<rom name>.DD" (or .DD.Z).
  U8 *buf,*line,*next,*p,path[256],stem[256];
  I64 n;

  GenGenieClear;
  gen_genie_list_cnt=0;
  gen_genie_list_bad=0;
  *gen_genie_list_name=0;
  if (!rom_filename)
    return FALSE;

  p=StrLastOcc(rom_filename,"/");
  if (p)
    p++;
  else
    p=rom_filename;
  GenGenieCpy(stem,p,256);
  n=StrLen(stem);
  if (n>2 && !StrICmp(stem+n-2,".Z"))
    stem[n-2]=0;
  if (p=StrLastOcc(stem,"."))
    *p=0;
  StrCpy(gen_genie_list_name,stem);

  StrPrint(path,"%s/Genie/%s.DD",__DIR__,stem);
  if (!(buf=FileRead(path)))
    return FALSE;
  GenGenieStripDollars(buf);
  line=buf;
  while (*line && gen_genie_list_cnt<GEN_GENIE_LIST_MAX)
  {
    if (next=StrFirstOcc(line,"\n"))
      *next++=0;
    else
      next=line+StrLen(line);
    GenGenieListLine(line);
    line=next;
  }
  Free(buf);
  return ToBool(gen_genie_list_cnt);
}

U0 GenGenieApplyList()
{//Rebuild the live codes from the checked items.
  I64 i;
  GenGenieClear;
  for (i=0; i<gen_genie_list_cnt; i++)
    if (gen_genie_list[i].on)
      GenGenieAddList(gen_genie_list[i].codes,TRUE);
  if (gen_genie_cnt)
  {
    gen_genie_on=TRUE;
    GenGenieApply;
  }
}

Bool GenGeniePick()
{//'g': check off which of the ROM's codes to run.  TRUE back means reset
  CDoc *doc;
  CDocEntry *cb[GEN_GENIE_LIST_MAX];
  U8 label[2*GEN_GENIE_DESC_LEN],*msg;
  I64 i,res;
  Bool over=FALSE,reset=FALSE;

  GenGenieLabel(label,gen_genie_list_name,2*GEN_GENIE_DESC_LEN);
  if (!gen_genie_list_cnt)
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
  for (i=0; i<gen_genie_list_cnt; i++)
  {
    GenGenieLabel(label,gen_genie_list[i].desc,2*GEN_GENIE_DESC_LEN);
		cb[i]=DocPrint(doc,"$$CB,\"%s\"$$\n",label);
    if (gen_genie_list[i].on)
      cb[i]->de_flags|=DOCEF_CHECKED_COLLAPSED;
  }
  if (gen_genie_list_bad)
		DocPrint(doc,"\n$$FG,4$$%d line(s) of the file weren't "
		        "codes.$$FG$$\n",gen_genie_list_bad);
	DocPrint(doc,"\n  $$BT,\"ON\",LE=1$$\n\n\n  $$BT,\"ON + RESET\",LE=2$$"
	        "\n\n\n  $$BT,\"OFF\",LE=3$$\n");
  res=PopUpMenu(doc);
  if (1<=res<=3)
  {
    for (i=0; i<gen_genie_list_cnt; i++)
      gen_genie_list[i].on=ToBool(cb[i]->de_flags &
              DOCEF_CHECKED_COLLAPSED);
    if (res==3)
      GenGenieClear;
    else
    {
      GenGenieApplyList;
      over=gen_genie_over;
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
