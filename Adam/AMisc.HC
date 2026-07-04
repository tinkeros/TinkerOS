#help_index "Keyboard Devices;Char/Input;StdIn"

I64 PressAKey()
{//Print "Press a key" and wait for non-zero $LK,"ASCII",A="MN:CH_CTRLA"$ key.
  "$$BK,1$$PRESS A KEY$$BK,0$$\n";
  return GetChar(,FALSE);
}

#help_index "Time/Seconds"
Bool Blink(F64 Hz=2.5)
{//Return TRUE, then FALSE, then TRUE at given frequency.
  if (!Hz) return 0;
  if (!blink_master_flag) return 0;
  return ToI64(cnts.jiffies*2*Hz/JIFFY_FREQ)&1;
}

#help_index "Debug"
U64 ThisFunc()
{// Returns start address of caller function
  U32 final_addr;
  I64 **ptr,of;
  CHashExport *tmpex;

  U8 **rbp=GetRBP;
  CTask *task=Fs;

  while (ChkOnStk(rbp,task))
  {
    ptr=rbp+1;
    if (tmpex=FunSegFind(*ptr,&of))
    {
      if (tmpex->type&HTT_FUN)
      {
        final_addr=*ptr;
        final_addr-=of;
        return final_addr;
      }
    }
    if (rbp>=*rbp)
      break;
    rbp=*rbp;
  }
  return 0;
}

U8 *ThisFuncName()
{// Returns string name of caller function
  I64 **ptr,of;
  CHashExport *tmpex;

  U8 **rbp=GetRBP;
  CTask *task=Fs;

  while (ChkOnStk(rbp,task))
  {
    ptr=rbp+1;
    if (tmpex=FunSegFind(*ptr,&of))
    {
      if (tmpex->type&HTT_FUN)
      {
        if (tmpex->str)
          return tmpex->str;
        return 0;
      }
    }
    if (rbp>=*rbp)
      break;
    rbp=*rbp;
  }
  return 0;
}

#help_index "Snd"

U0 SndRst()
{//Fix stuck sound.
  if (Bt(&sys_semas[SEMA_SND],0))
  {
    Sleep(1);
    if (Bt(&sys_semas[SEMA_SND],0))
    {
      Sleep(1);
      LBtr(&sys_semas[SEMA_SND],0);
    }
  }
  Snd;
}

I64 GetVolume()
{// Returns system volume
  // Override me, if changing from PC speaker
  if (IsMute) return 0;
  return 100;
}

U0 ShowVolume()
{
  progress3=GetVolume;
  StrPrint(progress3_desc, "Volume %d %%",progress3);
  progress3_max=100;
  Sleep(1000);
  progress3_max=0;
}

#help_index "Bitfields"
public U0 BitFieldSet(U8 *bit_field, U8 offset, U8 size, U8 value)
{//Sets values in a bit field
  I64 i;
  for (i=0; i<size; i++)
    BEqu(bit_field,offset+i,value>>i);
}

public U64 BitFieldGet(U8 *bit_field, U8 offset, U8 size)
{//Gets values from a bit field
  I64 i;
  U64 val=0;
  for (i=0; i<size; i++)
    BEqu(&val,i,Bt(bit_field,offset+i));
  return val;
}

#help_index "Virtualization"

public Bool IsHypervisorPresent()
{
  CRAXRBXRCXRDX regs;
  CPUId(1, &regs);
  I64 hyper=regs.rcx>>31;
  if (hyper&1)
    return 1;
  return 0;
}

U8 *HypeInfo()
{
  return hype_info;
}

#help_index "Windows"

Bool WinInside(I64 x,I64 y,CTask *task=NULL,I64 border=0)
{//Is pixel (x,y) inside task's win? Border to FONT_WIDTH.
  if (!task) task=Fs;
  if (TaskValidate(task) && Bt(&task->display_flags,DISPLAYf_SHOW))
  {
    if (Bt(&task->display_flags,DISPLAYf_NO_BORDER))
      border=0;
    if (task->pix_left-border<=x<=task->pix_right+border &&
        task->pix_top-border<=y<=task->pix_bottom+border)
      return TRUE;
  }
  return FALSE;
}

#help_index "Memory"

U0 ZeroClass(U8 *ptr, I64 s_elem=firstsize)
{// Set all data in a class to zero
  MemSet(ptr, 0, s_elem);
}

U8 *MemMove(U8 *dst, U8 *src, I64 n) {
    I64 i;
    U8 *d = dst, *s = src;

    if (d == s || n == 0) {
        return dst;
    }

    if (d < s) {
        for (i = 0; i < n; i++) {
            d[i] = s[i];
        }
    } else {
        for (i = n; i > 0; i--) {
            d[i - 1] = s[i - 1];
        }
    }

    return dst;
}

U0 MemZero(U8 *dst, I64 cnt)
{
  MemSet(dst,0,cnt);
}

#help_index "Debugging/Debugger;DolDoc/Cmd Line (Typically);"\
        "Cmd Line (Typically);Help System"

Bool Man(U8 *st,I64 edf_dof_flags=0)
{//Owner's manual for symbol.  Edit src code for symbol.
  Bool res=FALSE;
  U8 **st2;
  CHashSrcSym *tmph;
  if (IsRaw)
  {
    if ((tmph=HashFind(st,Fs->hash_table,HTG_SRC_SYM)) && tmph->src_link)
      res=EdLiteFileLine(tmph->src_link,edf_dof_flags);
  }
  else
  {
    st2=MStrPrint("MN:%s",st);
    res=Ed(st2,edf_dof_flags);
    Free(st2);
  }
  return res;
}

#help_index "File/FileNames;Misc"

U8 *FileNameTmpTxt()
{//Make pretty-safe tmp filename in home dir.
  return MStrPrint("~/SysTmp%X.DD.Z",GetTSC>>8&0xFFFFFFFF);
}

#help_index ""
