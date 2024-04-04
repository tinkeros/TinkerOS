I64 ts_i;
F64 ts_t0;

U0 TS(U8 *desc, I64 i)
{//We must set these because an app can call $LK,"ProgressBarsRst",A="MN:ProgressBarsRst"$.
  U8 *st=MStrPrint("%d. %s - %d Seth GFX helpers",ts_i,desc,i);
  if (*desc)
    progress3_max=1;
  else
    progress3_max=0;
  StrPrint(progress3_desc,"%*hc%s",
      (PROGRESS_DESC_LEN-StrLen(st))>>1,CH_SPACE,st);
  Free(st);
  progress4=ts_i++;
  progress4_max=2*mp_cnt;
  progress4_t0=ts_t0;
  *progress4_desc=0;
}

U0 DoSpyHunt()
{
  I64 i,j;
  CTask *task=User;
  XTalkWait(task,"#include \"::/Apps/SpyHunt/Run\";\n");
  FPSProf;
  for (i=0; i<4; i++)
  {
    Sleep(1000);
    PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SPACE,0);
    Sleep(200);
    PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SPACE,0);
    Sleep(200);
    PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SPACE,0);
    for (j=0; j<3; j++)
    {
      PostMsgWait(task,MSG_KEY_DOWN,CH_SPACE,0);
      LBts(kbd.down_bitmap,SC_CURSOR_RIGHT);
      Sleep(200);
      PostMsgWait(task,MSG_KEY_UP,CH_SPACE,0);
      LBtr(kbd.down_bitmap,SC_CURSOR_RIGHT);
      Sleep(200);
      PostMsgWait(task,MSG_KEY_DOWN,CH_SPACE,0);
      LBts(kbd.down_bitmap,SC_CURSOR_LEFT);
      Sleep(200);
      PostMsgWait(task,MSG_KEY_UP,CH_SPACE,0);
      LBtr(kbd.down_bitmap,SC_CURSOR_LEFT);
      Sleep(200);
    }
  }
  PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SHIFT_ESC,0);
  DeathWait(&task,TRUE);
}

U0 DoTalons()
{
  I64 i,j;
  CTask *task=User;
  XTalkWait(task,"#include \"::/Demo/Games/Talons\";\n");
  Sleep(500);
  FPSProf;
  for (i=0; i<10; i++)
  {
    PostMsgWait(task,MSG_KEY_DOWN_UP,0,SC_CURSOR_DOWN);
    Sleep(5);
  }
  Sleep(2500);
  for (j=0; j<12; j++)
  {
    for (i=0; i<127; i++)
    {
      PostMsgWait(task,MSG_KEY_DOWN_UP,0,SC_CURSOR_DOWN);
      Sleep(4);
    }
    Sleep(1000);
  }
  PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SHIFT_ESC,0);
  DeathWait(&task,TRUE);
}

U0 FPSTest(I64 targetFPS=200)
{
  I64 i, single_max=0, multi_max=0, old_fps_target;
  F64 *single_thread_game, *multi_thread_game, single_max_fps=0, multi_max_fps=0;
  old_fps_target=fps_master;
  "Setting target FPS to %d for benchmark...\n"
  ,targetFPS;
  SetFPS(targetFPS);
  multi_thread_game=CAlloc(sizeof(F64)*mp_cnt);
  single_thread_game=CAlloc(sizeof(F64)*mp_cnt);
  ts_t0=tS;
  ts_i=0;
  FPSProfReset;
  for (i=0; i<mp_cnt; i++)
  {
    TS("Talons",i);
    DoTalons;
    multi_thread_game[i]=FPSProf;
    if (multi_thread_game[i]>multi_max_fps)
    {
      multi_max_fps=multi_thread_game[i];
      multi_max=i;
    }
    TS("Spy Hunt",i);
    DoSpyHunt;
    single_thread_game[i]=FPSProf;
    if (single_thread_game[i]>single_max_fps)
    {
      single_max_fps=single_thread_game[i];
      single_max=i;
    }
  }
  "Elapsed Time:%5.3f\n"
  ,tS-ts_t0;
  "Target FPS was: %d\n"
  ,targetFPS;
  "Test results:\n";
  for (i=0; i<mp_cnt; i++)
  {
    "Helpers: %d Single thread game FPS: %1.2f Multi-thread game FPS: %1.2f\n",
      i,single_thread_game[i],multi_thread_game[i];
  }
  "Best single thread game FPS %1.2f with (%d Seth GFX helpers)\n",
    single_thread_game[single_max],single_max;
  "Best multi thread game FPS %1.2f with (%d Seth GFX helpers)\n"
  ,multi_thread_game[multi_max],multi_max;
}

Bool mute=Mute(1);
ProgressBarsRst;
ms.show=0;
SetScreenSaverTimeout(0);
FPSTest;
ms.show=1;
progress4_max=0;
FPSProfReset;
ProgressBarsRst;
Mute(mute);
