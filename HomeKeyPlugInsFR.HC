// FKey by L0Wigh

asm
{
	FN_KEY_SCAN_DECODE_TABLE::
		DU8 0, CH_ESC, "&‚\"'(-Š_‡…)=", CH_BACKSPACE, '\t';
	    DU8 "azertyuiop^$$", '\n', "<", "qs";
	    DU8 "dfghjklm—*", 0, "*wxcv";
	    DU8 "bn,;:!", 0, '*', 0, CH_SPACE, 0, 0, 0, 0, 0, 0;
	    DU8 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '-', 0, 0, 0, '+', 0;
	FS_KEY_SCAN_DECODE_TABLE::
		DU8 0, CH_SHIFT_ESC, "1234567890ø+", CH_BACKSPACE, '\t';
	    DU8 "AZERTYUIOP??", '\n', 0, "QS";
	    DU8 "DFGHJKLM%\\", 0, "*WXCV";
	    DU8 "BN?./?", 0, '*', 0, CH_SPACE, 0, 0, 0, 0, 0, 0;
	    DU8 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '-', 0, 0, 0, '+', 0;
	FC_KEY_SCAN_DECODE_TABLE::
		DU8 0, CH_ESC, "1234567890-=", CH_BACKSPACE, '\t';
	    DU8 CH_CTRLQ, CH_CTRLW, CH_CTRLE, CH_CTRLR, CH_CTRLT, CH_CTRLY, CH_CTRLU,
	        CH_CTRLI, CH_CTRLO, CH_CTRLP, "[]", '\n', 0, CH_CTRLA, CH_CTRLS;
	    DU8 CH_CTRLD, CH_CTRLF, CH_CTRLG, CH_CTRLH, CH_CTRLJ, CH_CTRLK, CH_CTRLL,
	        ";'\`", 0, "\\", CH_CTRLZ, CH_CTRLX, CH_CTRLC, CH_CTRLV;
	    DU8 CH_CTRLB, CH_CTRLN, CH_CTRLM, ",./", 0, '*', 0, CH_SPACE, 0, 0, 0, 0, 0, 0;
	    DU8 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '-', 0, 0, 0, '+', 0;
};

MemCpy(NORMAL_KEY_SCAN_DECODE_TABLE, FN_KEY_SCAN_DECODE_TABLE, 64);
MemCpy(SHIFT_KEY_SCAN_DECODE_TABLE, FS_KEY_SCAN_DECODE_TABLE, 64);
MemCpy(CTRL_KEY_SCAN_DECODE_TABLE, FC_KEY_SCAN_DECODE_TABLE, 64);
U0 TimeIns()
{
	CDate cdt;
	cdt = Now;
	"$$IV,1$$----%D %T----$$IV,0$$\n", cdt, cdt;
}

Bool MyPutKey(I64 ch,I64 sc)
{//ch=ASCII; sc=scan_code

  //See $LK,"Char",A="HI:Char"$ for definition of scan codes.
  //See $LK,"Key Allocations",A="FI:::/Doc/KeyAlloc.DD"$.
  //See $LK,"Keyboard Devices",A="HI:Keyboard Devices/System"$.

  //You can customize keys.  This routine
  //is called before the main editor
  //key hndlr $LK,"DocPutKey",A="MN:DocPutKey"$().
  //You can intercept any key.

  //Return TRUE if you completely
  //handled the key.
  I64 i;
  U8 *st1,*st2;

  // Adding support for ISO layout
  if (sc&0x7F==0x56 && !(sc&SCF_CTRL||sc&SCF_KEY_DESC)){
    if(sc&SCF_ALT)
      '|';
    else if(sc&SCF_SHIFT^^sc&SCF_CAPS)
      '>';
    else
      '<';
    return TRUE;
  }

  if (sc&SCF_ALT && !(sc&SCF_CTRL)) {
    switch (ch) {
      case 0:
		switch (sc.u8[0]) {
		  case SC_F1:
			if (sc&SCF_SHIFT) {
			  if (sc&SCF_KEY_DESC)
			KeyDescSet("Dol/LTPURPLE");
			  else
			"$$LTPURPLE$$";
			} else {
			  if (sc&SCF_KEY_DESC)
			KeyDescSet("Dol/PURPLE");
			  else
			"$$PURPLE$$";
			}
			return TRUE;
		  case SC_F2:
			if (sc&SCF_SHIFT) {
			  if (sc&SCF_KEY_DESC)
			KeyDescSet("Dol/LTRED");
			  else
			"$$LTRED$$";
			} else {
			  if (sc&SCF_KEY_DESC)
			KeyDescSet("Dol/RED");
			  else
			"$$RED$$";
			}
			return TRUE;
		  case SC_F3:
			if (sc&SCF_SHIFT) {
			  if (sc&SCF_KEY_DESC)
				KeyDescSet("Dol/LTGREEN");
			  else
				"$$LTGREEN$$";
			} else {
			  if (sc&SCF_KEY_DESC)
				KeyDescSet("Dol/GREEN");
			  else
				"$$GREEN$$";
			}
			return TRUE;
		  case SC_F4:
			if (sc&SCF_SHIFT) {
			  if (sc&SCF_KEY_DESC)
				KeyDescSet("Dol/Default Color");
			  else
				"$$FG$$";
			} else {
			  if (sc&SCF_KEY_DESC)
				KeyDescSet("Dol/BLUE");
			  else
				"$$BLUE$$";
			}
			return TRUE;
		  case SC_F7:
			if (!(sc&SCF_SHIFT)) {
			  if (sc&SCF_KEY_DESC)
				KeyDescSet("Cmd/TimeIns");
			  else
				TimeIns;
			}
			return TRUE;
		}
		break;
		case 'a':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Cmd/AutoComplete On");
			else
			  AutoComplete(ON);
			return TRUE;
		case 'A':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Cmd/AutoComplete Off");
			else
			  AutoComplete;
			return TRUE;
		case 'h':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Cmd/WinTileHorz");
			else
			  WinTileHorz;
			return TRUE;
		case 'm':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Cmd/WinMax");
			else {
			  WinBorder;
			  WinMax;
			}
			return TRUE;
		case 'v':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Cmd/WinTileVert");
			else
			  WinTileVert;
			return TRUE;
		case 'l':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Edit/Put Link to Cur Pos on Clip");
			else {
			  ClipDel;
			  st1=FileNameAbs(BIBLE_FILENAME);
			  st2=FileNameAbs(DocPut->filename.name);
			  if (!StrCmp(st1,st2)) {
				Free(st1);
				st1=BibleLine2Verse(DocPut->cur_entry->y+1,',');
				DocPrint(sys_clip_doc,"$$LK,\"BF:%s\"$$",st1);
			  } else
				DocPrint(sys_clip_doc,"$$LK,\"FL:%s,%d\"$$",
				  st2,DocPut->cur_entry->y+1);
			  Free(st1);
			  Free(st2);
			}
			return TRUE;
		case 'L':
			if (sc&SCF_KEY_DESC)
			  KeyDescSet("Edit/Place Anchor, Put Link to Clip");
			else {
			  i=RandU32;
			  ClipDel;
			  DocPrint(sys_clip_doc,"$$LK,\"<TODO>\",A=\"FA:%s,ANC%d\"$$",
				DocPut->filename.name,i);
			  "$$AN,\"<TODO>\",A=\"ANC%d\"$$",i;
			}
			return TRUE;
		//Ins your own ALT-key plug-ins
		case '‚':
			if (!(sc&SCF_KEY_DESC))
				'~';
			return TRUE;
		case '\"':
			if (!(sc&SCF_KEY_DESC))
				'#';
			return TRUE;
		case '\'':
			if (!(sc&SCF_KEY_DESC))
				'{';
			return TRUE;
		case '(':
			if (!(sc&SCF_KEY_DESC))
				'[';
			return TRUE;
		case '-':
			if (!(sc&SCF_KEY_DESC))
				'|';
			return TRUE;
		case 'Š':
			if (!(sc&SCF_KEY_DESC))
				'`';
			return TRUE;
		case '_':
			if (!(sc&SCF_KEY_DESC))
				'\\';
			return TRUE;
		case '‡':
			if (!(sc&SCF_KEY_DESC))
				'^';
			return TRUE;
		case '…':
			if (!(sc&SCF_KEY_DESC))
				'@';
			return TRUE;
		case ')':
			if (!(sc&SCF_KEY_DESC))
				']';
			return TRUE;
		case '=':
			if (!(sc&SCF_KEY_DESC))
				'}';
			return TRUE;
		}
  }
  return FALSE;
}

Bool MyPutS(U8 *)
{
  return FALSE;
}

KeyDevAdd(&MyPutKey,&MyPutS,0x20000000,TRUE);

// just in case of issues
//      case '1':
//	if (sc&SCF_KEY_DESC)
//	  KeyDescSet("Dol/ã");
//	else
//	  'ã';
//	return TRUE;
//      case '2':
//	if (sc&SCF_KEY_DESC)
//	  KeyDescSet("Dol/é");
//	else
//	  'é';
//	return TRUE;
//      case '3':
//	if (sc&SCF_KEY_DESC)
//	  KeyDescSet("Dol/è");
//	else
//	  'è';
//	return TRUE;
//      case '4':
//	if (sc&SCF_KEY_DESC)
//	  KeyDescSet("Dol/ê");
//	else
//	  'ê';
//	return TRUE;
//      case '9':
//	if (sc&SCF_KEY_DESC)
//	  KeyDescSet("Dol/Indent 5");
//	else
//	  "$$ID,5$$";
//	return TRUE;
//      case '0':
//	if (sc&SCF_KEY_DESC)
//	  KeyDescSet("Dol/Unindent 5");
//	else
//	  "$$ID,-5$$";
//	return TRUE;
