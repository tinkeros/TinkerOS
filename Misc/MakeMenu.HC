#help_index "DolDoc/Menu"

#define MENU_COLS	37
#define MENU_CELL_W	8
#define MENU_ROW_MAX	8
#define MENU_GAP	2

class CMenuItem
{
  CMenuItem *next;
  U8 *name,*name2,*lm,*cat,*elems;
  I64 rank,w,h,pad,pad2;
};

CDoc *menu_doc=NULL;
CMenuItem *menu_apps=NULL,*menu_row[MENU_ROW_MAX];
I64 menu_app_cnt=0,menu_row_cnt=0,menu_row_w=0;

U0 MenuSpaces(I64 n)
{
  while (n-->0)
    DocPrint(menu_doc," ");
}

U0 MenuSplit(CMenuItem *tmpm,I64 max)
{//Wrap a label longer than max at its most central space.
  U8 *st=tmpm->name,*best=NULL;
  I64 i,len=StrLen(st),b=len;
  if (len>max)
    for (i=0; i<len; i++)
      if (st[i]==' ' && MaxI64(i,len-1-i)<b)
      {
        b=MaxI64(i,len-1-i);
        best=st+i;
      }
  if (best)
  {
    *best=0;
    tmpm->name2=best+1;
  }
}

U0 MenuIcon(CMenuItem *tmpm,U8 *data,I64 size)
{//Sprite shifted to sit centered MENU_GAP above its label.
  I64 i,x1,x2,y1,y2,w,len,len2=0;
  U8 *res;
  CSpritePtMeshU8s *m;
  CSpritePt *s;
  CD3I32 *p;
  F64 r=0;
  if (*data==SPT_SHIFTABLE_MESH)
  {
    res=MAlloc(size);
    MemCpy(res,data,size);
    m=res;
    p=&m->u;
    for (i=0; i<m->vertex_cnt; i++,p++)
      r=Max(r,Sqrt(Sqr(p->x)+Sqr(p->y)+Sqr(p->z)));
    i=Ceil(r);
    x1=-i;
    x2=i;
    y1=-i;
    y2=i;
  }
  else
    SpriteExtents(data,&x1,&x2,&y1,&y2);
  w=x2-x1+1;
  i=MaxI64(MENU_CELL_W,(w+FONT_WIDTH-1)/FONT_WIDTH);
  MenuSplit(tmpm,i);
  len=StrLen(tmpm->name);
  if (tmpm->name2)
    len2=StrLen(tmpm->name2);
  if (len>=len2)
  {
    tmpm->w=MaxI64(i,len+1);
    if ((tmpm->w-len)&1)
      tmpm->w++;
    tmpm->pad=(tmpm->w-len)/2;
    tmpm->pad2=tmpm->pad+(len-len2)/2;
  }
  else
  {
    tmpm->w=MaxI64(i,len2+1);
    if ((tmpm->w-len2)&1)
      tmpm->w++;
    tmpm->pad2=(tmpm->w-len2)/2;
    tmpm->pad=tmpm->pad2+(len2-len)/2;
  }
  tmpm->h=y2-y1+1;
  i=tmpm->w*FONT_WIDTH/2-(tmpm->pad+len)*FONT_WIDTH;
  if (*data==SPT_SHIFTABLE_MESH)
  {
    m->x=i;
    m->y=-MENU_GAP-1-y2;
  }
  else
  {
    res=MAlloc(sizeof(CSpritePt)+size);
    s=res;
    s->type=SPT_SHIFT;
    s->x1=i-w/2-x1;
    s->y1=-MENU_GAP-1-y2;
    MemCpy(res+sizeof(CSpritePt),data,size);
  }
  tmpm->elems=res;
}

U0 MenuRowFlush()
{
  I64 i,j,pad,h=0;
  U8 *fmt;
  Bool two=FALSE;
  CMenuItem *tmpm;
  if (menu_row_cnt)
  {
    for (i=0; i<menu_row_cnt; i++)
    {
      h=Max(h,menu_row[i]->h);
      if (menu_row[i]->name2)
        two=TRUE;
    }
    for (i=0; i<(h+MENU_GAP+FONT_HEIGHT-1)/FONT_HEIGHT; i++)
      DocPrint(menu_doc,"\n");
    MenuSpaces((MENU_COLS-menu_row_w)/2);
    for (i=0; i<menu_row_cnt; i++)
    {
      tmpm=menu_row[i];
      j=StrLen(tmpm->name);
      pad=tmpm->pad;
      MenuSpaces(pad);
      fmt=MStrPrint("$$SP+PU,\"%Q\",LM=\"%Q\",BI=%%d$$",tmpm->name,tmpm->lm);
      DocSprite(menu_doc,tmpm->elems,fmt);
      Free(fmt);
      MenuSpaces(tmpm->w-pad-j);
    }
    if (two)
    {
      DocPrint(menu_doc,"\n");
      MenuSpaces((MENU_COLS-menu_row_w)/2);
      for (i=0; i<menu_row_cnt; i++)
      {
        tmpm=menu_row[i];
        if (tmpm->name2)
        {
          j=StrLen(tmpm->name2);
          MenuSpaces(tmpm->pad2);
          DocPrint(menu_doc,"$$FG,%d$$%s$$FG$$",DOC_COLOR_MACRO,tmpm->name2);
          MenuSpaces(tmpm->w-tmpm->pad2-j);
        }
        else
          MenuSpaces(tmpm->w);
      }
    }
    DocPrint(menu_doc,"\n\n");
    menu_row_cnt=0;
    menu_row_w=0;
  }
}

U0 MenuApp(CMenuItem *tmpm)
{//Add an app to the current row.
  if (menu_row_cnt==MENU_ROW_MAX || menu_row_w+tmpm->w>MENU_COLS)
    MenuRowFlush;
  menu_row[menu_row_cnt++]=tmpm;
  menu_row_w+=tmpm->w;
}

U0 MenuCat(U8 *title)
{//Start a category.
  MenuRowFlush;
  DocPrint(menu_doc,"\n\n");
  MenuSpaces((MENU_COLS-StrLen(title))/2);
  DocPrint(menu_doc,"$$FG,5$$%s$$FG$$\n",title);
}

I64 MenuAppCmp(CMenuItem *e1,CMenuItem *e2)
{
  I64 res=e1->rank-e2->rank;
  if (!res)
    res=StrICmp(e1->cat,e2->cat);
  if (!res)
    res=StrICmp(e1->name,e2->name);
  return res;
}

public U0 MenuBegin()
{//Start a new menu doc.
  menu_doc=DocNew;
  menu_apps=NULL;
  menu_app_cnt=0;
  menu_row_cnt=0;
  menu_row_w=0;
}

public U0 MenuFile(U8 *filename)
{//Insert a DolDoc text file (no sprites) as is.
  U8 *st=FileRead(filename);
  MenuRowFlush;
  DocPutS(menu_doc,st);
  Free(st);
}

public I64 MenuScan(U8 *mask)
{//Collect the icon files matching mask (recursive) that have a category.
  I64 res=0;
  CDirEntry *tmpde=FilesFind(mask,FUF_RECURSE|FUF_JUST_FILES),*tmpde1=tmpde;
  CDoc *doc;
  CDocEntry *doc_e;
  CMenuItem *tmpm;
  while (tmpde)
  {
    doc=DocRead(tmpde->full_name);
    doc_e=doc->head.next;
    while (doc_e!=doc && doc_e->type_u8!=DOCT_SPRITE)
      doc_e=doc_e->next;
    if (doc_e!=doc && doc_e->de_flags&DOCEF_AUX_STR && doc_e->bin_data)
    {
      tmpm=CAlloc(sizeof(CMenuItem));
      tmpm->name=StrNew(doc_e->tag);
      if (doc_e->de_flags&DOCEF_LEFT_MACRO)
        tmpm->lm=StrNew(doc_e->left_macro);
      else
        tmpm->lm=StrNew("");
      tmpm->cat=StrNew(doc_e->aux_str);
      MenuIcon(tmpm,doc_e->bin_data->data,doc_e->bin_data->size);
      tmpm->next=menu_apps;
      menu_apps=tmpm;
      menu_app_cnt++;
      res++;
    }
    DocDel(doc);
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  return res;
}

public U0 MenuApps(U8 *cats=NULL)
{//Lay out the collected apps by category, cats first, then the rest.
  I64 i;
  CMenuItem *tmpm=menu_apps,**a=MAlloc(menu_app_cnt*sizeof(U8 *));
  for (i=0; i<menu_app_cnt; i++)
  {
    tmpm->rank=LstMatch(tmpm->cat,cats,LMF_IGNORE_CASE|LMF_EXACT);
    if (tmpm->rank<0)
      tmpm->rank=I64_MAX;
    a[i]=tmpm;
    tmpm=tmpm->next;
  }
  QSortI64(a,menu_app_cnt,&MenuAppCmp);
  for (i=0; i<menu_app_cnt; i++)
  {
    if (!i || StrICmp(a[i]->cat,a[i-1]->cat))
      MenuCat(a[i]->cat);
    MenuApp(a[i]);
  }
  MenuRowFlush;
  Free(a);
}

public U0 MenuEnd(U8 *filename="::/PersonalMenu.DD")
{//Save the menu doc.
  U8 *st=FileNameAbs(filename);
  CMenuItem *tmpm;
  MenuRowFlush;
  StrCpy(menu_doc->filename.name,st);
  DocWrite(menu_doc);
  DocDel(menu_doc);
  menu_doc=NULL;
  Free(st);
  while (tmpm=menu_apps)
  {
    menu_apps=tmpm->next;
    Free(tmpm->name);
    Free(tmpm->lm);
    Free(tmpm->cat);
    Free(tmpm->elems);
    Free(tmpm);
  }
  menu_app_cnt=0;
}
