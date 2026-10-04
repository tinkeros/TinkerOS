#help_index "Defrag"

#define DEFRAG_CLUS_FREE	0
#define DEFRAG_CLUS_DIR		1
#define DEFRAG_CLUS_USED	2
#define DEFRAG_CLUS_FRAG	3
#define DEFRAG_CLUS_PROTECTED	4
#define DEFRAG_RESERVE_BYTES	(16*1024*1024)

CDrv *dfg_dv;
U8 *dfg_clus_status=NULL;
I64 dfg_total_clus=0;
I64 dfg_files_moved=0,dfg_files_skipped=0;
U8 *dfg_status_line="";
I64 dfg_active_start=-1,dfg_active_cnt=0;
I64 dfg_grid_top=2,dfg_grid_cols=1,dfg_grid_rows=1,dfg_grid_cells=1;
I64 dfg_pack_start=0;
CDirEntry **dfg_collect_arr=NULL;
I64 dfg_collect_cnt=0;
I64 dfg_progress_total=0,dfg_progress_done=0;

Bool DfgIsBootFile(U8 *name)
{
  I64 len=StrLen(name);
  return len>=6 && !StrNICmp(name+len-6,".BIN.C",6);
}

I64 DfgClusCnt(I64 size)
{
  if (size<=0) return 0;
  if (dfg_dv->fs_type==FSt_FAT32)
    return (size+dfg_dv->spc*BLK_SIZE-1)/(dfg_dv->spc*BLK_SIZE);
  return (size+BLK_SIZE-1)/BLK_SIZE;
}

U0 DfgMark(I64 c,I64 status)
{
  if (0<=c<dfg_total_clus)
    dfg_clus_status[c]=status;
}

U0 DfgMarkChainOpen(I64 c,I64 status)
{
  I64 guard=0;
  while (0<c<0x0FFFFFF8 && guard++<dfg_total_clus+16)
  {
    DfgMark(c,status);
    c=ClusNumNext(dfg_dv,c,1);
  }
}

Bool DfgFileIsFrag(I64 start_clus,I64 size)
{
  I64 cnt=DfgClusCnt(size),c,expected,i;
  if (dfg_dv->fs_type!=FSt_FAT32 || cnt<=1 || start_clus<=0) return FALSE;
  c=start_clus;
  expected=start_clus;
  for (i=0; i<cnt; i++)
  {
    if (c!=expected) return TRUE;
    expected=c+1;
    if (i+1<cnt) c=ClusNumNext(dfg_dv,c,1);
  }
  return FALSE;
}

U0 DfgMarkFile(I64 start_clus,I64 size,Bool is_protected)
{
  I64 cnt=DfgClusCnt(size),c=start_clus,i;
  Bool frag;
  if (cnt<=0 || start_clus<=0) return;
  frag=DfgFileIsFrag(start_clus,size);
  for (i=0; i<cnt; i++)
  {
    if (is_protected)
      DfgMark(c,DEFRAG_CLUS_PROTECTED);
    else if (frag)
      DfgMark(c,DEFRAG_CLUS_FRAG);
    else
      DfgMark(c,DEFRAG_CLUS_USED);
    if (dfg_dv->fs_type==FSt_FAT32 && i+1<cnt)
      c=ClusNumNext(dfg_dv,c,1);
    else
      c++;
  }
}

I64 DfgFindFreeRun(I64 need)
{//First free run of clusters, never inside the reserved kernel region.
  I64 i,run=0,run_start=0,start=MaxI64(1,dfg_pack_start);
  for (i=start; i<dfg_total_clus; i++)
  {
    if (dfg_clus_status[i]==DEFRAG_CLUS_FREE)
    {
      if (!run) run_start=i;
      if (++run>=need) return run_start;
    }
    else
      run=0;
  }
  return 0;
}

Bool DfgRelFile(CDirEntry *de)
{//Reads the file, then writes it back at an explicitly chosen cluster
  I64 cnt,i,c,new_start,size,attr,target,*old_clus;
  U8 *data;
  cnt=DfgClusCnt(de->size);
  if (cnt<=0) return FALSE;
  target=DfgFindFreeRun(cnt);
  if (!target)
  {
    dfg_files_skipped++;
    return FALSE;
  }
  old_clus=MAlloc(cnt*sizeof(I64));
  c=de->clus;
  for (i=0; i<cnt; i++)
  {
    old_clus[i]=c;
    if (i+1<cnt) c=ClusNumNext(dfg_dv,c,1);
  }
  dfg_status_line=MStrPrint("Relocating file %d/%d: %s",
      dfg_progress_done,dfg_progress_total,de->full_name);
  dfg_active_start=de->clus;
  dfg_active_cnt=cnt;
  Refresh;
  new_start=0;
  try
  {
    if (data=FileRead(de->full_name,&size,&attr))
    {
      new_start=FileWriteAt(de->full_name,data,size,,attr|RS_ATTR_CONTIGUOUS,target);
      Free(data);
    }
  }
  catch
  {
    Fs->catch_except=TRUE;
    new_start=0;
  }
  if (new_start==target)
  {
    for (i=0; i<cnt; i++)
      DfgMark(old_clus[i],DEFRAG_CLUS_FREE);
    for (i=0; i<cnt; i++)
      DfgMark(new_start+i,DEFRAG_CLUS_USED);
    dfg_files_moved++;
  }
  else
    dfg_files_skipped++;
  Free(old_clus);
  dfg_active_cnt=0;
  return TRUE;
}

Bool DfgRelDir(CDirEntry *de)
{
  I64 cnt=DfgClusCnt(de->size),i,c,new_start,target, *old_clus;
  if (cnt<=0 || de->clus<=0) return FALSE;
  target=DfgFindFreeRun(cnt);
  if (!target)
  {
    dfg_files_skipped++;
    return FALSE;
  }
  old_clus=MAlloc(cnt*sizeof(I64));
  c=de->clus;
  for (i=0; i<cnt; i++)
  {
    old_clus[i]=c;
    if (i+1<cnt) c=ClusNumNext(dfg_dv,c,1);
  }
  dfg_status_line=MStrPrint("Relocating dir %d/%d: %s... %c",
      dfg_progress_done,dfg_progress_total,de->full_name);
  dfg_active_start=de->clus;
  dfg_active_cnt=cnt;
  Refresh;
  new_start=0;
  try
    new_start=DirMoveAt(de->full_name,target);
  catch
  {
    Fs->catch_except=TRUE;
    new_start=0;
  }
  if (new_start==target)
  {
    for (i=0; i<cnt; i++)
      DfgMark(old_clus[i],DEFRAG_CLUS_FREE);
    for (i=0; i<cnt; i++)
      DfgMark(new_start+i,DEFRAG_CLUS_DIR);
    dfg_files_moved++;
  }
  else
    dfg_files_skipped++;
  Free(old_clus);
  dfg_active_cnt=0;
  return TRUE;
}

U0 DfgScanTree(CDirEntry *de)
{
  while (de)
  {
    if (de->attr & RS_ATTR_DIR)
    {
      if (dfg_dv->fs_type==FSt_FAT32)
        DfgMarkChainOpen(de->clus,DEFRAG_CLUS_DIR);
      else
        DfgMark(de->clus,DEFRAG_CLUS_DIR);
      DfgScanTree(de->sub);
    }
    else
      DfgMarkFile(de->clus,de->size,DfgIsBootFile(de->full_name));
    de=de->next;
  }
}

U0 DfgRescan(U8 drv_let)
{
  CDirEntry *tree;
  U8 *mask;
  MemSet(dfg_clus_status,DEFRAG_CLUS_FREE,dfg_total_clus);
  if (dfg_dv->fs_type==FSt_FAT32)
    DfgMarkChainOpen(dfg_dv->root_clus,DEFRAG_CLUS_DIR);
  else
    DfgMark(dfg_dv->root_clus,DEFRAG_CLUS_DIR);
  mask=MStrPrint("%C:/*",drv_let);
  tree=FilesFind(mask,FUF_RECURSE);
  Free(mask);
  DfgScanTree(tree);
  DirTreeDel(tree);
}

I64 DfgColor(I64 bg,I64 fg)
{
  return (bg<<4)|fg;
}

U0 DfgLegItm(CTask *task,I64 *x,I64 y,I64 attr,U8 ch,U8 *label)
{
  TextChar(task,,*x,y,ch+(attr<<8));
  TextPrint(task,*x+2,y,DfgColor(BLACK,LTGRAY),"%s",label);
  *x+=StrLen(label)+5;
}

U0 DfgDrawIt(CTask *task,CDC *dc)
{
  I64 x,y,i,cell,start,end,status,d;
  U8 ch,*zone_suffix;
  TextRect(0,TEXT_COLS-1,0,TEXT_ROWS-1,' '+(DfgColor(BLACK,LTGRAY)<<8));
  TextPrint(task,MaxI64(0,(TEXT_COLS-22)/2),0,DfgColor(BLUE,WHITE),
      "TinkerOS Defragmenter");
  if (dfg_pack_start>0)
    zone_suffix=" (clearing kernel region in first 16MB)";
  else
    zone_suffix="";
  TextPrint(task,2,1,DfgColor(BLACK,LTGRAY),"Drive %C:  %d clusters%s",
      Drv2Let(dfg_dv),dfg_total_clus,zone_suffix);
  for (y=0; y<dfg_grid_rows; y++)
    for (x=0; x<dfg_grid_cols; x++)
    {
      cell=y*dfg_grid_cols+x;
      start=cell*dfg_total_clus/dfg_grid_cells;
      end=(cell+1)*dfg_total_clus/dfg_grid_cells;
      if (end<=start)
        TextChar(task,,x,dfg_grid_top+y,' '+(DfgColor(BLACK,BLACK)<<8));
      else
      {
        status=DEFRAG_CLUS_FREE;
        for (i=start; i<end; i++)
          if (dfg_clus_status[i]>status)
            status=dfg_clus_status[i];
        switch (status)
        {
        case DEFRAG_CLUS_PROTECTED:
          ch='B'; d=DfgColor(PURPLE,WHITE);
          break;
        case DEFRAG_CLUS_FRAG:
          ch=' '; d=DfgColor(RED,RED);
          break;
        case DEFRAG_CLUS_DIR:
          ch=' '; d=DfgColor(GREEN,GREEN);
          break;
        case DEFRAG_CLUS_USED:
          ch=' '; d=DfgColor(CYAN,CYAN);
          break;
        default:
          if (dfg_pack_start>0 && start<dfg_pack_start)
          {
            ch=':'; d=DfgColor(BLACK,BLUE);
          }
          else
          {
            ch='.'; d=DfgColor(BLACK,DKGRAY);
          }
          break;
        }
        d=ch+(d<<8);
        if (dfg_active_cnt>0 && start<dfg_active_start+dfg_active_cnt &&
            dfg_active_start<end)
          d=' '+(DfgColor(WHITE,WHITE)<<8)+ATTRF_BLINK;
        TextChar(task,,x,dfg_grid_top+y,d);
      }
    }
  x=1;
  DfgLegItm(task,&x,TEXT_ROWS-4,DfgColor(BLACK,DKGRAY),'.',"Free");
  DfgLegItm(task,&x,TEXT_ROWS-4,DfgColor(CYAN,CYAN),' ',"Used");
  DfgLegItm(task,&x,TEXT_ROWS-4,DfgColor(GREEN,GREEN),' ',"Directory");
  x=1;
  DfgLegItm(task,&x,TEXT_ROWS-3,DfgColor(RED,RED),' ',"Fragmented");
  DfgLegItm(task,&x,TEXT_ROWS-3,DfgColor(PURPLE,WHITE),'B',
      "Boot file, never moved");
  if (dfg_pack_start>0)
    DfgLegItm(task,&x,TEXT_ROWS-3,DfgColor(BLACK,BLUE),':',
        "Reserved for kernel builds");
  TextPrint(task,2,TEXT_ROWS-2,DfgColor(BLACK,LTGRAY),"%s",dfg_status_line);
}

U0 DfgCntFrag(CDirEntry *de)
{
  while (de)
  {
    if (de->attr & RS_ATTR_DIR)
      DfgCntFrag(de->sub);
    else if (!DfgIsBootFile(de->full_name) &&
        DfgFileIsFrag(de->clus,de->size))
      dfg_progress_total++;
    de=de->next;
  }
}

U0 DfgOptimize(CDirEntry *de)
{
  while (de)
  {
    if (ScanChar)
      throw('Esc');
    if (de->attr & RS_ATTR_DIR)
      DfgOptimize(de->sub);
    else if (dfg_dv->fs_type==FSt_FAT32 && DfgIsBootFile(de->full_name))
    {
      // Skip boot files
    }
    else if (dfg_dv->fs_type==FSt_FAT32 &&
        DfgFileIsFrag(de->clus,de->size))
    {
      if (DfgRelFile(de))
        Sleep(80);
    }
    de=de->next;
  }
}

I64 DfgCmpClus(I64 e1,I64 e2)
{
  return e1(CDirEntry*)->clus-e2(CDirEntry*)->clus;
}

U0 DfgCntEntries(CDirEntry *de)
{
  while (de)
  {
    if (de->attr & RS_ATTR_DIR)
    {
      dfg_collect_cnt++;
      DfgCntEntries(de->sub);
    }
    else if (!DfgIsBootFile(de->full_name))
      dfg_collect_cnt++;
    de=de->next;
  }
}

U0 DfgFillEntries(CDirEntry *de)
{
  while (de)
  {
    if (de->attr & RS_ATTR_DIR)
    {
      dfg_collect_arr[dfg_collect_cnt++]=de;
      DfgFillEntries(de->sub);
    }
    else if (!DfgIsBootFile(de->full_name))
      dfg_collect_arr[dfg_collect_cnt++]=de;
    de=de->next;
  }
}

U0 DfgClearKernelRegion(U8 drv_let,CDirEntry *tree)
{
  I64 n,i;
  CDirEntry *de;
  dfg_collect_cnt=0;
  DfgCntEntries(tree);
  n=dfg_collect_cnt;
  if (n>0)
  {
    dfg_collect_arr=MAlloc(n*sizeof(CDirEntry*));
    dfg_collect_cnt=0;
    DfgFillEntries(tree);
    QSortI64(dfg_collect_arr(I64*),n,&DfgCmpClus);
    dfg_progress_total=n;
    dfg_progress_done=0;
    dfg_status_line="Clearing kernel region...";
    Refresh;
    try
    {
      for (i=0; i<n; i++)
      {
        if (ScanChar)
          throw('Esc');
        de=dfg_collect_arr[i];
        if (de->attr & RS_ATTR_DIR)
        {
            DfgRelDir(de);
        }
        else
          DfgRelFile(de);
      }
    }
    catch
      Fs->catch_except=TRUE;
    Free(dfg_collect_arr);
    dfg_collect_arr=NULL;
  }
  DfgRescan(drv_let);
}

public U0 Defrag(U8 drv_let=0,Bool clear_kernel_region=TRUE)
{
  CDrv *dv;
  CDirEntry *tree;
  U8 *mask;
  I64 ch,reserve_clus;
  if (!drv_let)
  {
    drv_let=Fs->cur_dv->drv_let;
  }
  if (!(dv=Let2Drv(drv_let,FALSE)))
  {
    "Drive %C: is not mounted!\n",drv_let;
    return;
  }
  if (dv->fs_type!=FSt_FAT32)
  {
    "Drive %C: is not a FAT32, nothing to do!\n",drv_let;
    return;
  }

  dfg_dv=dv;
  if (dv->fs_type==FSt_FAT32)
    dfg_total_clus=(dv->size+dv->drv_offset-dv->data_area)/dv->spc+2;
  else
    dfg_total_clus=dv->size+2;
  if (dfg_total_clus<=0)
  {
    "Drive %C: has no usable cluster space!\n",drv_let;
    return;
  }
  dfg_clus_status=CAlloc(dfg_total_clus);
  dfg_files_moved=0;
  dfg_files_skipped=0;
  dfg_active_start=-1;
  dfg_active_cnt=0;
  dfg_pack_start=0;
  if (clear_kernel_region)
  {
    reserve_clus=(DEFRAG_RESERVE_BYTES+dv->spc*BLK_SIZE-1)/(dv->spc*BLK_SIZE);
    dfg_pack_start=2+reserve_clus;
  }

  SettingsPush;
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  dfg_grid_top=2;
  dfg_grid_cols=MaxI64(TEXT_COLS,1);
  dfg_grid_rows=MaxI64(TEXT_ROWS-dfg_grid_top-4,1);
  dfg_grid_cells=dfg_grid_cols*dfg_grid_rows;
  Fs->draw_it=&DfgDrawIt;
  Fs->win_inhibit=WIG_TASK_DFT-WIF_SELF_FOCUS-WIF_SELF_BORDER;
  try
  {
    if (dv->fs_type==FSt_FAT32)
      DfgMarkChainOpen(dv->root_clus,DEFRAG_CLUS_DIR);
    else
      DfgMark(dv->root_clus,DEFRAG_CLUS_DIR);
    dfg_status_line="Reading directory tree...";
    Refresh;
    mask=MStrPrint("%C:/*",drv_let);
    tree=FilesFind(mask,FUF_RECURSE);
    Free(mask);
    DfgScanTree(tree);
    dfg_status_line="Scan complete.  Press a key to optimize, ESC to just view the map.";
    Refresh;
    ch=GetChar;
    if (ch!=CH_ESC && ch!=CH_SHIFT_ESC)
    {
      dfg_progress_done=0;
      dfg_progress_total=0;
      if (clear_kernel_region)
      {
        dfg_status_line="Clearing kernel region...";
        Refresh;
        DfgClearKernelRegion(drv_let,tree);
      }
      else
      {
        dfg_collect_cnt=0;
        DfgCntFrag(tree);
        dfg_progress_total=dfg_collect_cnt;
        dfg_status_line="Optimizing...";
        Refresh;
        try
          DfgOptimize(tree);
        catch
          Fs->catch_except=TRUE;
      }
    }
    DirTreeDel(tree);
    dfg_status_line=MStrPrint(
        "Done.  %d optimized, %d skipped.  Press a key to exit.",
        dfg_files_moved,dfg_files_skipped);
    Refresh;
    GetChar;
  }
  catch
  {
    Fs->catch_except=TRUE;
  }
  SettingsPop;
  "\n%d item(s) optimized, %d skipped (not enough free space)\n",
      dfg_files_moved,dfg_files_skipped;
  Free(dfg_clus_status);
  dfg_clus_status=NULL;
}

#help_index ""

Defrag;
