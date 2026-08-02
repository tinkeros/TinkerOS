//Automated soak test: runs every ROM in TempleGen for 5 seconds, presses
//Start, runs 5 more seconds, then exits.  Shows progress bars like OSTestSuite.
//
//  #include "::/Apps/TempleGen/RomsTest"

//Play time before and after Start, how long Start is held down, and how
//long to wait for a clean exit.  All in mS.
#define RT_RUN_MS	5000
#define RT_START_MS	250
#define RT_EXIT_MS	10000

I64 rt_i,rt_n;
F64 rt_t0;

U0 RTProgress(U8 *desc)
{//We must set these because an app can call ProgressBarsRst.
	U8 *st=MStrPrint("%d. Testing %s",rt_i,desc);
	if (StrLen(st)>PROGRESS_DESC_LEN-1)
		st[PROGRESS_DESC_LEN-1]=0;
	progress3_max=1;
	StrPrint(progress3_desc,"%*hc%s",
	        (PROGRESS_DESC_LEN-StrLen(st))>>1,CH_SPACE,st);
	Free(st);
	progress4=rt_i++;
	progress4_max=rt_n;
	progress4_t0=rt_t0;
	*progress4_desc=0;
}

Bool RTIsRomName(U8 *name)
{//Same rule as GenIsRomName(), duplicated so this file stands alone.
	U8 buf[256];
	I64 n;
	StrCpy(buf,name);
	n=StrLen(buf);
	if (n>2 && !StrICmp(buf+n-2,".Z")) {
		n-=2;
		buf[n]=0;
	}
	if (n>=4 && (!StrICmp(buf+n-4,".BIN") || !StrICmp(buf+n-4,".GEN")))
		return TRUE;
	return n>=3 && !StrICmp(buf+n-3,".MD");
}

Bool RTWaitPmt(CTask *task,I64 timeout_ms)
{//TaskWait(task,TRUE) with a timeout, so a wedged ROM can't stall the run.
	CTask *task1;
	CJob *tmpc1;
	I64 waited=0;
	while (waited<timeout_ms) {
		task1=task->last_input_filter_task;
		if (!TaskValidate(task) || !TaskValidate(task1))
			return FALSE;
		tmpc1=&task1->srv_ctrl.next_waiting;
		if (tmpc1==tmpc1->next && Bt(&task1->task_flags,TASKf_IDLE) &&
		    Bt(&task1->task_flags,TASKf_CMD_LINE_PMT))
			return TRUE;
		Sleep(50);
		waited+=50;
	}
	return FALSE;
}

CTask *RTStartEmu()
{//Compile the emulator once, then back out of the ROM picker so that
 //TempleGen() can be called directly with each ROM path.
	CTask *task=User;
	XTalkWait(task,"#include \"%s/TempleGen\";\n",__DIR__);
	PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SPACE,0);	//Dismiss help screen
	PostMsgWait(task,MSG_KEY_DOWN_UP,CH_ESC,0);	//Back out of ROM picker
	TaskWait(task,TRUE);
	return task;
}

U0 RTRunRom(CTask **_task,U8 *rom_full_name)
{
	CTask *task=*_task;
	XTalkWait(task,"TempleGen(\"%s\");\n",rom_full_name);
	PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SPACE,0);	//Dismiss help screen
	Sleep(RT_RUN_MS);
	LBts(kbd.down_bitmap,SC_ENTER);			//Press Start.  The joypad
	Sleep(RT_START_MS);				//reads the key bitmap
	LBtr(kbd.down_bitmap,SC_ENTER);			//directly, not messages.
	Sleep(RT_RUN_MS);
	PostMsg(task,MSG_KEY_DOWN_UP,CH_ESC,0);		//Exit
	if (!RTWaitPmt(task,RT_EXIT_MS)) {
		"$FG,4$%s did not exit cleanly.$FG$\n",rom_full_name;
		if (TaskValidate(task))
			Kill(task);
		*_task=RTStartEmu;
	}
}

U0 RomsTest(U8 *rom_dir="Roms")
{
	CDirEntry *de_list,*tmpde;
	CTask *task;
	U8 mask[256];

	StrPrint(mask,"%s/%s/*",__DIR__,rom_dir);
	de_list=FilesFind(mask,FUF_JUST_FILES);
	rt_n=0;
	tmpde=de_list;
	while (tmpde) {
		if (RTIsRomName(tmpde->name))
			rt_n++;
		tmpde=tmpde->next;
	}
	if (!rt_n) {
		"$FG,4$No ROMs found in \"%s/%s\".$FG$\n",__DIR__,rom_dir;
		DirTreeDel(de_list);
		return;
	}
	"Testing %d ROM(s) from \"%s/%s\".\n",rt_n,__DIR__,rom_dir;

	rt_t0=tS;
	rt_i=0;
	task=RTStartEmu;

	tmpde=de_list;
	while (tmpde) {
		if (RTIsRomName(tmpde->name)) {
			RTProgress(tmpde->name);
			RTRunRom(&task,tmpde->full_name);
		}
		tmpde=tmpde->next;
	}
	DirTreeDel(de_list);
	DeathWait(&task,TRUE);

	ProgressBarsRst;
	"Elapsed Time:%5.3f\n",tS-rt_t0;
}

static I64 rt_old_ss_timeout=gr.scrn_saver_timeout;

U0 RomsTestKillCB()
{
	LBtr(kbd.down_bitmap,SC_ENTER);
	SetScreenSaverTimeout(rt_old_ss_timeout);
	progress3_max=0;
	progress4_max=0;
}

Fs->task_end_cb=&RomsTestKillCB;
ms.show=0;
SetScreenSaverTimeout(0);
RomsTest;
ms.show=1;
SetScreenSaverTimeout(rt_old_ss_timeout);
progress3_max=0;
progress4_max=0;
