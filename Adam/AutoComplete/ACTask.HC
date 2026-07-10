I64 AC_def_win_x = 51;
I64 AC_def_win_y = 13;
I64 AC_def_win_x_override = -1;
I64 AC_def_win_y_override = -1;
I64 AC_ctr_win_x = 27;
I64 AC_ctr_win_y = 3;
I64 AC_ctr_win_x_override = -1;
I64 AC_ctr_win_y_override = -1;

public U0 PushHistoryItem(U8 *item)
{//Add item to top of history. Oldest item is discarded when max is reached.
  I64 i;
  if (!item || !*item) return;

  // Help avoid history contamination
  if (StrLen(item)<3) return;
  if (item[StrLen(item)-1]!=';' && item[StrLen(item)-1]!='"') return;

  if (!StrCmp("DocTe",item)) return;
  if (!StrCmp("ClearHistory;",item)) return;
  if (!StrCmp("EnableHistory;",item)) return;
  if (!StrCmp("Adam Task CPU",item)) return;
  if (!StrCmp("Cd;#include \"Once\";",item)) return;

  for (i=0;i<ac_history_cnt;i++)
    if (ac_history_items[i])
      if (!StrCmp(ac_history_items[i],item))
        return;

  // Drop the oldest (last) entry if already at capacity.
  if (ac_history_cnt>=AC_HISTORY_MAX)
  {
    Free(ac_history_items[AC_HISTORY_MAX-1]);
    ac_history_cnt=AC_HISTORY_MAX-1;
  }
  // Shift everything toward the end to make room at index 0 (newest = top).
  for (i=ac_history_cnt; i>0; i--)
    ac_history_items[i]=ac_history_items[i-1];
  ac_history_items[0]=AStrNew(item);
  ac_history_cnt++;
  ac_history_dirty=TRUE;
}

public U0 EnableHistory()
{
  PUSHFD
  CLI
  fp_hist=&PushHistoryItem;
  POPFD
}

public U0 ClearHistory()
{
  I64 i;
  PUSHFD
  CLI
  for (i=0;i<ac_history_cnt;i++)
    if (ac_history_items[i])
      Free(ac_history_items[i]);
  POPFD
}

public U0 ToggleHistory()
{//Toggle AutoComplete between normal completion view and history view.
  ac_show_history=!ac_show_history;
  ac_history_dirty=TRUE;
  // Force completions to redraw when switching back to normal mode.
  Free(ac.cur_word);
  ac.cur_word=NULL;
}

public U0 ACHistoryFillIn(I64 n)
{//Inject history item n (1-indexed) as synthetic keystrokes.
  if (0<=--n<ac_history_cnt)
    In(ac_history_items[n]);
}

public Bool ACIsHistoryMode()
{//Return TRUE if AutoComplete is displaying history instead of completions.
  return ac_show_history;
}

#help_index "AutoComplete/Dictionary"
U0 ACDDictWordsAdd(U8 *st)
{
  I64 i;
  U8 *ptr;
  if (st && *st && (ptr=ACDWordPtAt(st)))
  {
    for (i=0; i<ACD_FILLINS_NUM; i++)
    {
      if (*ptr++!=ACD_WORD_CHAR)
        break;
      if (i) '\n';
      acd.fillins[i]=ptr-1;
      "$$GREEN$$'%d'$$FG$$ %-23ts"
      ,i,ptr;
      ptr+=StrLen(ptr)+3;
    }
    acd.num_fillins=i;
  }
}

#help_index "AutoComplete"

U0 ACBottomRight()
{
  AC_def_win_x_override=TEXT_COLS-29;
  AC_def_win_y_override=TEXT_ROWS-21;
  AC_ctr_win_x_override=TEXT_COLS/2+10;
  AC_ctr_win_y_override=TEXT_ROWS/3;
  AutoComplete(AutoComplete);
}

U0 ACDefault()
{
  AC_def_win_x_override=-1;
  AC_def_win_y_override=-1;
  AC_ctr_win_x_override=-1;
  AC_ctr_win_y_override=-1;
  AutoComplete(AutoComplete);
}


U0 ACDocRst(I64 left,I64 top)
{
  CDoc *doc=DocPut;
  DocRst(doc,TRUE);
  doc->flags|=DOCF_SIZE_MIN;
  Fs->border_src=BDS_CONST;
  Fs->border_attr=LTGRAY<<4+DrvTextAttrGet(':')&15;
  Fs->text_attr  =LTGRAY<<4+BLUE;
  LBtr(&Fs->display_flags,DISPLAYf_SHOW);
  WinHorz(left,Fs->win_right);
  WinVert(top,Fs->win_bottom);
  DocCursor;
}

I64 ACSkipCrap(U8 *src,I64 len)
{
  I64 j;
  j=len-1;
  while (j>=0)
  {
    if (Bt(char_bmp_alpha_numeric,src[j]))
      break;
    else
      j--;
  }
  return j+1;
}

I64 ACPriorWordInStr(U8 *src,U8 *dst,I64 len,I64 buf_size)
{
  I64 i,j=0,k;
  i=len-1;
  while (i>=0)
    if (!Bt(char_bmp_alpha_numeric,src[i]))
      break;
    else
      i--;
  if (i>=-1 && len>0)
    for (k=i+1; k<len && j<buf_size-1; k++)
      dst[j++]=src[k];
  dst[j]=0;
  return i+1;
}

U0 ACFillInAdd(CHashAC *tmpw)
{
  I64 k;
  if (ac.num_fillins<AC_FILLINS_NUM ||
      tmpw->hits>ac.fillin_hits[ac.num_fillins-1])
  {
    for (k=ac.num_fillins-1; k>=0; k--)
    {
      if (tmpw->hits<=ac.fillin_hits[k])
        break;
      else
      {
        ac.fillin_matches[k+1]=ac.fillin_matches[k];
        ac.fillin_hits[k+1]   =ac.fillin_hits[k];
      }
    }
    ac.fillin_matches[k+1]=tmpw;
    ac.fillin_hits[k+1]   =tmpw->hits;
    if (ac.num_fillins<AC_FILLINS_NUM)
      ac.num_fillins++;
  }
}

U0 ACShowHistory()
{
  I64 i;
  if (!ac_history_dirty) return;
  ACDocRst(AC_def_win_x,AC_def_win_y);
  "$$PURPLE$$History:\n$$FG$$\n";
  if (ac_history_cnt==0)
    "$$DKGRAY$$  (empty)$$FG$$\n";
  else
    for (i=0; i<ac_history_cnt; i++)
    {
      if (i<10)
        "$$GREEN$$F%02d$$FG$$ %s\n",i+1,ac_history_items[i];
      else
        "     %s\n",ac_history_items[i];
    }
  ac_history_dirty=FALSE;
}

U0 ACPutChoices(CDoc *focus_l,CDocEntry *doc_e,CTask *focus_task,
                Bool force_refresh)
{
  I64 i,data_col;
  U8 *buf,*buf1,*src=NULL,*st;
  CHashAC *tmpw;
  F64 timeout_time=tS+0.5;
  CHashSrcSym *tmph;
  src=DocScanLine(focus_l,doc_e,&data_col);
  DocUnlock(focus_l);
  i=StrLen(src);
  buf =MAlloc(MaxI64(i+1,256));
  buf1=MAlloc(MaxI64(i+1,256));
  if (data_col==-1)
    data_col=0;
  data_col=ACPriorWordInStr(src,buf,data_col,256);
  ac.partial_len=StrLen(buf);
  data_col=ACSkipCrap(src,data_col);
  data_col=ACPriorWordInStr(src,buf1,data_col,256);
  if (!ac.cur_word || StrCmp(ac.cur_word,buf) || force_refresh)
  {
    st=ac.cur_word;
    ac.cur_word=AStrNew(buf);
    Free(st);
    ac.num_fillins=0;
    if (*ac.cur_word)
      for (i=0; i<=ac.hash_table->mask && tS<timeout_time; i++)
      {
        tmpw=ac.hash_table->body[i];
        while (tmpw)
        {
          if (!MemCmp(ac.cur_word,tmpw->str,StrLen(ac.cur_word)))
            ACFillInAdd(tmpw);
          tmpw=tmpw->next;
        }
      }
    ACDocRst(AC_def_win_x,AC_def_win_y);
    if (ac.cur_word && *ac.cur_word)
    {
      "$$PURPLE$$Word:%s$$FG$$\n",ac.cur_word;
      for (i=0; i<ac.num_fillins; i++)
      {
        st=ac.fillin_matches[i]->str;
        "$$GREEN$$F%02d$$FG$$ "
        ,i+1;
        if (TaskValidate(focus_task) &&
            (tmph=HashFind(st,focus_task->hash_table,HTG_SRC_SYM)) &&
            tmph->src_link)
        {
          if (tmph->type&HTF_PUBLIC)
            "$$RED$$";
          "$$TX+UL+L+PU,\"%$$Q\",A=\"%s\"$$$$FG$$\n"
          ,st,tmph->src_link;
        }
        else
          "%s\n",st;
      }
      if (acd.has_words)
        ACDDictWordsAdd(ac.cur_word);
    }
    else if (FileFind("::/Doc/StandBy.DD.Z"))
      Type("::/Doc/StandBy.DD.Z",0);
    else if (FileFind("::/Doc/StandBy.DD"))
      Type("::/Doc/StandBy.DD",0);
  }
  Free(src);
  Free(buf);
  Free(buf1);
}

U0 ACTaskNormal(I64 sc,I64 last_sc,
                CTask *focus_task,CTask *original_focus_task)
{
  CDoc *doc;
  CDocEntry *doc_e;
  // History mode: show the history list instead of completions.
  if (ac_show_history)
  {
    ACShowHistory;
    if (!LBts(&Fs->display_flags,DISPLAYf_SHOW))
      WinZBufUpdate;
    return;
  }
  if ((doc=DocPut(focus_task)) &&
      focus_task!=Fs && Bt(&focus_task->display_flags,DISPLAYf_SHOW))
  {
    DocLock(doc);
    if (TaskValidate(focus_task) && original_focus_task==sys_focus_task &&
        doc && doc==DocPut(focus_task) && (doc_e=doc->cur_entry))
    {
      if (doc_e==doc) doc_e=doc_e->last;
      while (doc_e->last!=doc && (doc_e->type_u8==DOCT_NEW_LINE ||
                                  doc_e->type_u8==DOCT_SOFT_NEW_LINE))
        doc_e=doc_e->last;
      while (doc_e->last->type_u8!=DOCT_NEW_LINE && doc_e->last!=doc)
        doc_e=doc_e->last;
      ACPutChoices(doc,doc_e,focus_task,ToBool(sc!=last_sc));
    }
    else
      DocUnlock(doc);
  }
  if (!LBts(&Fs->display_flags,DISPLAYf_SHOW))
    WinZBufUpdate;
}

U0 ACTaskCtrl(I64 sc,I64 last_sc,
              CTask *focus_task,CTask *original_focus_task)
{
  if (TaskValidate(focus_task) &&
      (focus_task->scroll_x || focus_task->scroll_y))
  {
    if (LBtr(&Fs->display_flags,DISPLAYf_SHOW))
      WinZBufUpdate;
  }
  else
  {
    if (sc!=last_sc)
    {
      if (sc&SCF_ALT)
      {
        ACDocRst(AC_ctr_win_x,AC_ctr_win_y);
        if (TaskValidate(original_focus_task) &&
            !Bt(&original_focus_task->win_inhibit,WIf_SELF_KEY_DESC))
          KeyMapFamily(original_focus_task,SCF_ALT,
                       ToBool(!(sc&SCF_SHIFT)),ToBool(sc&SCF_SHIFT));
        KeyMapCtrlAltFamily(
        ToBool(!(sc&SCF_SHIFT)),ToBool(sc&SCF_SHIFT));
      }
      else if (TaskValidate(original_focus_task) &&
               !Bt(&original_focus_task->win_inhibit,WIf_SELF_KEY_DESC))
      {
        ACDocRst(AC_ctr_win_x,AC_ctr_win_y);
        KeyMapFamily(original_focus_task,SCF_CTRL,
                     ToBool(!(sc&SCF_SHIFT)),ToBool(sc&SCF_SHIFT));
      }
    }
    if (!LBts(&Fs->display_flags,DISPLAYf_SHOW))
      WinZBufUpdate;
  }
  if (ac_show_history)
    ac_history_dirty=TRUE;
}

U0 ACTaskAlt(I64 sc,I64 last_sc,
             CTask *,CTask *original_focus_task)
{
  if (sc!=last_sc && TaskValidate(original_focus_task) &&
      !Bt(&original_focus_task->win_inhibit,WIf_SELF_KEY_DESC))
  {
    ACDocRst(AC_ctr_win_x,AC_ctr_win_y);
    KeyMapFamily(original_focus_task,SCF_ALT,
                 ToBool(!(sc&SCF_SHIFT)),ToBool(sc&SCF_SHIFT));
  }
  if (!LBts(&Fs->display_flags,DISPLAYf_SHOW))
    WinZBufUpdate;
  if (ac_show_history)
    ac_history_dirty=TRUE;
}

U0 ACTaskEndCB()
{
  ac.task=NULL;
  Exit;
}

U0 ACTask(I64)
{
  CTask *focus_task,*original_focus_task;
  I64 ch,scan_code=0,last_scan_code=0;
  CDoc *doc;
  Fs->task_end_cb=&ACTaskEndCB;
  DocTermNew;
  LBts(&Fs->display_flags,DISPLAYf_SHOW);
  WinHorz(AC_def_win_x,Fs->win_right);
  LBts(&Fs->display_flags,DISPLAYf_WIN_ON_TOP);
  Fs->win_inhibit=WIG_NO_FOCUS_TASK_DFT;
  Free(ac.cur_word);
  ac.cur_word=NULL;
  // Ensure history redraws on first cycle if history mode is active.
  ac_history_dirty=TRUE;
  while (TRUE)
  {
    if (scan_code&(SCF_CTRL|SCF_ALT) ||
        GetTSC>KbdMsEvtTime+cnts.time_stamp_freq>>1)
    {
      last_scan_code=scan_code;
      scan_code=kbd.scan_code;
    }
    original_focus_task=focus_task=sys_focus_task;
    while (TaskValidate(focus_task) &&
           Bt(&focus_task->task_flags,TASKf_INPUT_FILTER_TASK))
      focus_task=focus_task->parent_task;
    if (scan_code&SCF_CTRL)
      ACTaskCtrl(scan_code,last_scan_code,focus_task,original_focus_task);
    else if (TaskValidate(focus_task))
    {
      if (scan_code&SCF_ALT)
        ACTaskAlt(scan_code,last_scan_code,focus_task,original_focus_task);
      else
        ACTaskNormal(scan_code,last_scan_code,focus_task,original_focus_task);
    }
    Sleep(333);
    if (ScanMsg(&ch,,1<<MSG_KEY_DOWN) && (ch==CH_ESC||ch==CH_SHIFT_ESC))
      break;
    doc=DocPut;
    DocLock(doc);
    if (doc->cur_entry->de_flags & DOCEF_LINK)
    {
      '' CH_SPACE;
      doc->cur_entry=doc;
    }
    DocUnlock(doc);
  }
}

public Bool AutoComplete(Bool val=OFF)
{//Turn AutoComplete OFF or ON.
  Bool	old_val=FALSE;
  if (TEXT_COLS>80)
    AC_def_win_x = TEXT_COLS - 80 + 51;
  if (TEXT_COLS<80)
    AC_def_win_x = 51 - (80-TEXT_COLS);
  if (TEXT_ROWS>60)
    AC_def_win_y = TEXT_ROWS - 60 + 13;
  if (TEXT_ROWS<60)
    AC_def_win_y = 13 - (60-TEXT_ROWS);
  if (AC_def_win_x_override>0)
    AC_def_win_x=AC_def_win_x_override;
  if (AC_def_win_y_override>0)
    AC_def_win_y=AC_def_win_y_override;
  AC_ctr_win_x = TEXT_COLS/2 - 13;
  AC_ctr_win_y = 3;
  if (AC_ctr_win_x_override>0)
    AC_ctr_win_x=AC_ctr_win_x_override;
  if (AC_ctr_win_y_override>0)
    AC_ctr_win_y=AC_ctr_win_y_override;
  if (!val && !Bt(&sys_run_level,RLf_AUTO_COMPLETE))
  {
    return OFF;
  }
  if (val && !Bt(&sys_run_level,RLf_AUTO_COMPLETE))
  {
    "Must call ACInit first!\n";
    return OFF;
  }
  if (val)
  {
    if (TaskValidate(ac.task))
      old_val=TRUE;
    else
    {
      ac.task=Spawn(&ACTask,NULL,"AutoComplete");
      TaskWait(ac.task);
    }
    WinToTop(ac.task);
  }
  else
  {
    if (TaskValidate(ac.task))
    {
      if (Bt(&sys_run_level,RLf_AUTO_COMPLETE))
        old_val=TRUE;
      Kill(ac.task);
      DeathWait(&ac.task);
    }
  }
  return old_val;
}

U0 ShowACWhenReady()
{
  while (!Bt(&sys_run_level,RLf_AUTO_COMPLETE))
  {
    Sleep(100);
  }
  AutoComplete(ON);
}
