#define LIN_CONGRUE_A 6364136223846793005
#define LIN_CONGRUE_C 1442695040888963407

RegDft("TempleOS/Sudoku","\n");
RegExe("TempleOS/Sudoku");

class SaveState
{
  U64 board_seed;
  U8  state[81];
  U8  solution[81];
  F64 time_add;
};

U8 state[81];
U8 check[81];
U8 solution[81];
U8 ch;
U8 *verse=NULL;
F64 best_time,time,start_time,time_add=0,final_time=0;
Bool PlayAgain=FALSE;
Bool running=TRUE;
Bool resetBoard=FALSE;
Bool validate=FALSE;
I64 arg1;
I64 arg2;
I64 score;
I64 hint_cnt=0;
I64 ch=0;
I64 cur_x=0;
I64 cur_y=0;
I64 font_scale = 3;
I64 box_width = FONT_HEIGHT * font_scale+2*font_scale;
I64 board_x_ul = (GR_WIDTH / 2) - (box_width * 9) / 2;
I64 board_y_ul = (GR_HEIGHT / 2) - (box_width * 9) / 2;
I64 rx_prev=0,ry_prev=0;
I64 start_cnt=22;
U64 board_seed = RandI64;

I64 RandRangeSeed(I64 min=0, I64 max, I64 seed)
{
  I64 res, res2;
  res=LIN_CONGRUE_A*seed^(seed&0xFFFFFFFF0000)>>16+LIN_CONGRUE_C;
  res2=res * (1 + 1<<16 + 1<<32 + 1<<48);
  return ((res2&0xffffffff)(U64) * (max-min+1)) >> 32 + min;
}

F64 GetBestTime(I64 start_cnt)
{
  F64 res;
  U8 *tmp,*var = MStrPrint("sudoku_best_time_%d",start_cnt);
  if (!HashFind(var,adam_task->hash_table,HTT_GLBL_VAR))
  {
    tmp=MStrPrint("F64 %s=99999999;\n",var);
    Adam(tmp);
    Free(tmp);
  }
  tmp = MStrPrint("%s;\n",var);
  res = ExePrint(tmp)(F64);
  Free(tmp);
  Free(var);
  return res;
}

U0 SetBestTime(I64 start_cnt, F64 time)
{
  U8 *tmp,*var = MStrPrint("sudoku_best_time_%d",start_cnt);
  tmp=MStrPrint("F64 %s=%1.2f;\n",var,time);
  Adam(tmp);
  Free(tmp);
  Free(var);
}

U0 SaveBestTimes()
{
  I64 i;
  F64 time;
  U8 *regstr=CAlloc(64*81),*var;
  for (i=0; i<81; i++)
  {
    var = MStrPrint("sudoku_best_time_%d",i);
    time=GetBestTime(i);
    if (time<99999999)
    {
      CatPrint(regstr,"F64 %s=%1.2f;\n",var,time);
    }
  }
  RegWrite("TempleOS/Sudoku","%s\n",regstr);
  Free(regstr);
}

U0 SaveGame()
{
  SaveState ss;
  ss.board_seed=board_seed;
  ss.time_add=tS-start_time+time_add;
  MemCpy(&ss.state,state,81);
  MemCpy(&ss.solution,solution,81);
  DirMk("~/SaveGames");
  FileWrite("~/SaveGames/Sudoku.BIN.Z",&ss,sizeof(SaveState));
  DocClear;
  "Game Saved\n";
}

U0 LoadGame()
{
  SaveState ss;
  I64 size;
  U8* savedata=FileRead("~/SaveGames/Sudoku.BIN.Z",&size);
  if (!savedata)
    return;
  if (size == sizeof(SaveState))
  {
    MemCpy(&ss,savedata,sizeof(SaveState));
    board_seed=ss.board_seed;
    time_add=ss.time_add;
    MemCpy(state,&ss.state,81);
    MemCpy(solution,&ss.solution,81);
  }
  Free(savedata);
  start_time=tS;
  DocClear;
  "Game Loaded\n";
}

U0 FillInitialSolution()
{
  I64 x,y,tmp=board_seed%9;
  for (y=0; y<9; y++)
  {
    if (y%3 == 0)
      tmp=(tmp%9)+1;
    for (x=0; x<9; x++)
    {
      solution[y*9+x]=tmp;
      tmp=(tmp%9)+1;
    }
    tmp+=3;
    tmp=((tmp-1)%9)+1;
  }
}

U0 SwapRows(I64 row1, I64 row2)
{
  I64 i;
  if (row1 != row2)
    if (row1/3 == row2/3)
      for (i=0; i<9; i++)
        SwapU8(&solution[row1*9+i],&solution[row2*9+i]);
}

U0 SwapCols(I64 col1, I64 col2)
{
  I64 i;
  if (col1 != col2)
    if (col1/3 == col2/3)
      for (i=0; i<9; i++)
        SwapU8(&solution[i*9+col1],&solution[i*9+col2]);
}

U0 RandomizeSolutionPass()
{
  I64 i,j,k,l=0;
  for (i=0; i<3; i++)
  {
    do
    {
      j=RandRangeSeed(0,2,board_seed+l++);
      k=RandRangeSeed(0,2,board_seed+i+l++);
    }
    while (j==k);
    SwapCols(i*3+j,i*3+k);
  }
  l=RandRangeSeed(0,100000,board_seed);
  for (i=0; i<3; i++)
  {
    do
    {
      j=RandRangeSeed(0,2,board_seed+l++);
      k=RandRangeSeed(0,2,board_seed+i+l++);
    }
    while (j==k);
    SwapRows(i*3+j,i*3+k);
  }
  l=RandRangeSeed(0,100000,board_seed*2);
  for (i=0; i<3; i++)
  {
    do
    {
      j=RandRangeSeed(0,2,board_seed+l++);
      k=RandRangeSeed(0,2,board_seed+i+l++);
    }
    while (j==k);
    SwapRows(i*3+j,i*3+k);
    SwapCols(i*3+j,i*3+k);
  }
  l=RandRangeSeed(0,100000,board_seed*3);
  for (i=0; i<3; i++)
  {
    do
    {
      j=RandRangeSeed(0,2,board_seed*l++);
      k=RandRangeSeed(0,2,board_seed*i*l++);
    }
    while (j==k);
    SwapRows(i*3+j,i*3+k);
    SwapCols(i*3+j,i*3+k);
  }
}

U0 RandomizeSolution()
{
  I64 i;
  for(i=0;i<3;i++)
    RandomizeSolutionPass;
}

U0 DrawBoard(CDC *dc)
{
  I64 x,y,i,j,k;
  I64 dx,dy;
  I64 f;
  I64 cell_border_width = font_scale/2;
  I64 y_min=20;
  I64 cell_idx,cell_val;
  if (cell_border_width>2)
    cell_border_width=2;
  if (cell_border_width<1)
    cell_border_width=1;
  dc->color=WHITE;
  GrRect(dc,0,y_min,GR_WIDTH,GR_HEIGHT-y_min);
  dc->color=LTGRAY;
  GrRect(dc,board_x_ul,board_y_ul,box_width*9,box_width*9);
  for (y=0; y<9; y++)
  {
    for (x=0; x<9; x++)
    {
      cell_idx=y*9+x;
      cell_val=state[cell_idx];
      if (0<cell_val<10)
        f = text.font[48+cell_val];
      else
        f=0;
      dc->color=WHITE;
      GrRect(dc,
             board_x_ul+box_width*x+cell_border_width,
             board_y_ul+box_width*y+cell_border_width,
             box_width-2*cell_border_width,
             box_width-2*cell_border_width);
      k=0;
      for (i=0; i<FONT_HEIGHT; i++)
      {
        for (j=0; j<FONT_WIDTH; j++)
        {
          if (cur_x==x && cur_y==y)
          {
            if (Bt(&f,k++))
              dc->color=WHITE;
            else
              dc->color=BLACK;
          }
          else
          {
            if (check[9*y+x]==0)
            {
              if (Bt(&f,k++))
                dc->color=BLACK;
              else
                dc->color=WHITE;
            }
            else if (check[9*y+x]==1)
            {
              if (Bt(&f,k++))
                dc->color=WHITE;
              else
                dc->color=RED;
            }
            else if (check[9*y+x]==2)
            {
              if (Bt(&f,k++))
                dc->color=WHITE;
              else
                dc->color=LTGREEN;
            }
          }
          for (dx=0; dx<font_scale; dx++)
          {
            for (dy=0; dy<font_scale; dy++)
            {
              GrPlot(dc,
                     board_x_ul+box_width*x+j*font_scale+dx+font_scale,
                     board_y_ul+box_width*y+i*font_scale+dy+font_scale);
            }
          }
        }
      }
    }
  }
  dc->color=BLACK;
  x=0;
  y=0;
  while (0<=x<=box_width*9)
  {
    for (y=0; y<cell_border_width; y++)
    {
      for (i=0; i<3; i++)
      {
        GrLine(dc,
               board_x_ul+x+y-i,
               board_y_ul-2,
               board_x_ul+x+y-i,
               board_y_ul-2+box_width*9);
        GrLine(dc,
               board_x_ul,
               board_y_ul+x+y-i,
               board_x_ul+box_width*9,
               board_y_ul+x+y-i);
      }
    }
    x+=box_width*3;
  }
}

U0 ClearAll()
{
  I64 i=0;
  for (i=0; i<81; i++)
  {
    state[i]=0;
    check[i]=0;
  }
}

U0 ClearCheck()
{
  I64 i=0;
  for (i=0; i<81; i++)
  {
    check[i]=0;
  }
}

U0 RunCheck()
{
  I64 bx,by,x,x2,y,y2,z,val;
  for (y=0; y<9; y++)
  {
    for (x=0; x<8; x++)
    {
      val=state[y*9+x];
      if (val>0)
      {
        for (z=x+1; z<9; z++)
        {
          if (state[y*9+z]==val)
          {
            check[y*9+z]=1;
            check[y*9+x]=1;
          }
        }
      }
    }
  }
  for (x=0; x<9; x++)
  {
    for (y=0; y<8; y++)
    {
      val=state[y*9+x];
      if (val>0)
      {
        for (z=y+1; z<9; z++)
        {
          if (state[z*9+x]==val)
          {
            check[z*9+x]=1;
            check[y*9+x]=1;
          }
        }
      }
    }
  }
  for (bx=0; bx<3; bx++)
  {
    for (by=0; by<3; by++)
    {
      for (y=0; y<3; y++)
      {
        for (x=0; x<3; x++)
        {
          val = state[27*by + 9*y + 3*bx + x];
          if (val != 0)
          {
            for (x2=0; x2<3; x2++)
            {
              for (y2=0; y2<3; y2++)
              {
                if (y!=y2 && x!=x2)
                {
                  if (val ==  state[27*by + 9*y2 + 3*bx + x2])
                  {
                    check[27*by + 9*y2 + 3*bx + x2]=1;
                    check[27*by + 9*y + 3*bx + x]=1;
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  if (validate)
  {
    val=0;
    for (y=0; y<9; y++)
    {
      for (x=0; x<9; x++)
      {
        if (state[y*9+x]>0)
          if (state[y*9+x]!=solution[y*9+x])
          {
            check[y*9+x]=1;
            val++;
          }
          else
          {
            check[y*9+x]=2;
          }
      }
    }
    if (val == 0)
      validate=FALSE;
  }
}

I64 CountFilled()
{
  I64 cnt=0;
  I64 x,y;
  for (y=0; y<9; y++)
  {
    for (x=0; x<9; x++)
    {
      if (state[y*9+x]>0)
        cnt++;
    }
  }
  return cnt;
}

Bool ValidateBox(I64 box)
{
  I64 i,j,x,y,val=0;
  y=box/3;
  x=box%3;
  for (i=0; i<3; i++)
  {
    for (j=0; j<3; j++)
    {
      if (state[27*y+9*i+3*x+j] == solution[27*y+9*i+3*x+j])
      {
        val+=1;
      }
      else
      {
        return FALSE;
      }
    }
  }
  return val==9;
}

Bool BoxContains(I64 box, I64 value)
{
  I64 i,j,x,y;
  y=box/3;
  x=box%3;
  for (i=0; i<3; i++)
  {
    for (j=0; j<3; j++)
    {
      if (state[27*y+9*i+3*x+j] == value)
      {
        return TRUE;
      }
    }
  }
  return FALSE;
}

I64 GetBoxNum(I64 box)
{
  I64 i,j,x,y,val=0;
  y=box/3;
  x=box%3;
  for (i=0; i<3; i++)
  {
    for (j=0; j<3; j++)
    {
      val=val*10;
      if (state[27*y+9*i+3*x+j]>0)
      {
        val+=state[27*y+9*i+3*x+j];
      }
      else
      {
        return -1;
      }
    }
  }
  return val;
}

U0 RevealHint(I64 value=-1)
{
  I64 x,y,bx,by,bbx,bby;
  I64 mincnt=9;
  I64 cnt=0,n=0;
  for (bx=0; bx<3; bx++)
  {
    for (by=0; by<3; by++)
    {
      cnt=0;
      for (y=0; y<3; y++)
      {
        for (x=0; x<3; x++)
        {
          if (state[27*by + 9*y + 3*bx + x]!=0)
            cnt++;
          if ((value>0) && (value == state[27*by + 9*y + 3*bx + x]))
            cnt+=9;
        }
      }
      if (cnt < mincnt)
      {
        bbx=bx;
        bby=by;
        mincnt=cnt;
      }
      if (cnt == mincnt)
      {
        if (RandRangeSeed(0,1,board_seed+hint_cnt))
        {
          bbx=bx;
          bby=by;
        }
      }
    }
  }
  if (mincnt<9)
  {
    x=RandRangeSeed(0,2,board_seed+mincnt+hint_cnt+cnt++);
    y=RandRangeSeed(0,2,board_seed+mincnt+hint_cnt+cnt++);
    n=x*3+y;
    while (TRUE)
    {
      Yield;
      if (state[27*bby + 9*y + 3*bbx + x]==0)
      {
        if (value<1)
        {
          state[27*bby + 9*y + 3*bbx + x]=solution[27*bby + 9*y + 3*bbx + x];
          break;
        }
        else
        {
          if (value==solution[3*bby*9 + 9*y + 3*bbx + x])
          {
            state[27*bby + 9*y + 3*bbx + x]=solution[27*bby + 9*y + 3*bbx + x];
            break;
          }
        }
      }
      n++;
      n%=9;
      x=n/3;
      y=n%3;
    }
  }
  hint_cnt++;
}

U0 CheckBoard()
{
  ClearCheck();
  RunCheck();
}

U0 DrawIt(CTask *, CDC *dc)
{
  I64 i,x,y,box_count=0;
  U64 box_num,bible_line=0;
  F64 game_time;
  I64 num_lines=3;
  I64 start_line=0;
  if (final_time>0)
  {
    game_time = final_time;
  }
  else
  {
    game_time = tS - start_time + time_add;
  }
  DrawBoard(dc);
  dc->color=BLACK;
  y=board_y_ul - FONT_HEIGHT*2;
  x=board_x_ul;
  GrPrint(dc,x,y,"Board Seed: %u",board_seed);
  x=board_x_ul+9*box_width+16;
  y=board_y_ul - FONT_HEIGHT*4;
  if (final_time>0)
  {
    GrPrint(dc,x,y,"Final Time: %1.2f", final_time);
  }
  else
  {
    GrPrint(dc,x,y,"Time: %1.2f", game_time);
  }
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"Start Count: %u",start_cnt);
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"Best Time: %1.2f", best_time);
  y=board_y_ul+box_width*9/2;
  y-=FONT_HEIGHT*12;
  GrPrint(dc,x,y,"Keyboard commands:");
  y+=FONT_HEIGHT*3;
  GrPrint(dc,x,y,"SPACE to clear box");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"1-9 to assign box");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"H for hint");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"N for new board");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"R to reset board");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"S to save game");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"L to load game");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"V to validate");
  y+=FONT_HEIGHT*3;
  GrPrint(dc,x,y,"Starting hints");
  y+=FONT_HEIGHT*3;
  GrPrint(dc,x,y,"+ to increase");
  y+=FONT_HEIGHT*2;
  GrPrint(dc,x,y,"- to decrease");
  y+=FONT_HEIGHT*3;
  GrPrint(dc,x,y,"ESC to quit");
  y=board_y_ul;
  x=FONT_WIDTH/2;
  y+=FONT_HEIGHT*2;
  for(i=0; i<9; i++)
  {
    y+=FONT_HEIGHT;
    box_num=GetBoxNum(i);
    if (box_num>0)
    {
      if (ValidateBox(i))
      {
        Yield;
        GrPrint(dc,x,y,"%d",box_num);
        y+=FONT_HEIGHT;
        GrPrint(dc,x,y,"%s",god.words[box_num%god.num_words]);
        y+=FONT_HEIGHT;    
        box_count++;
        bible_line+=box_num;
      }
    }
  }
  if (box_count==9)
  {
    bible_line+=board_seed;
    y+=FONT_HEIGHT*2;
    start_line=bible_line%(ST_BIBLE_LINES-(num_lines-1))+1;
    y=GR_HEIGHT - FONT_HEIGHT*10;
    GrPrint(dc,x,y,"Bible Number = sum of box numbers + board seed = %u",bible_line);
    y+=FONT_HEIGHT*2;
    if (!verse)
      verse=BibleLine2Verse(start_line);
    GrPrint(dc,x,y, "Bible verse: %s\n\n",verse);
    if (final_time == 0)
    {
      final_time = game_time;
      if ((best_time < 0) || (0 < final_time < best_time))
      {
        SetBestTime(start_cnt,final_time);
        best_time = final_time;
      }
    }
  }
}

U0 GameOver()
{
  DCFill;
  PlayAgain = FALSE;
  running=FALSE;
}

U0 GetMousePos(I64 arg1,I64 arg2,I64 *x, I64 *y)
{
  I64 ms_x, ms_y;
  if (0<(arg1 - board_x_ul)<(9*box_width))
  {
    if (0<(arg2 - board_y_ul)<(9*box_width))
    {
      ms_x = (arg1 - board_x_ul)/box_width;
      ms_y = (arg2 - board_y_ul)/box_width;
      *x=ms_x;
      *y=ms_y;
      return;
    }
  }
  *x=-1;
  *y=-1;
}

U0 GetInput()
{
  I64 x,y,cell_idx;
  Bool input=FALSE;
  while (running&&!input)
  {
    switch (ScanMsg(&arg1,&arg2,1<<MSG_MS_L_DOWN+1<<MSG_KEY_DOWN))
    {
    case 0:
      Refresh;
      break;
start:
      cell_idx=cur_y*9+cur_x;
    case MSG_MS_L_DOWN:
      GetMousePos(arg1,arg2,&x,&y);
      if (x>=0 && y>=0)
      {
        cur_x=x;
        cur_y=y;
      }
    case MSG_KEY_DOWN:
      DocClear;
      if(CH_ESC==arg1)
        GameOver;
      if (SC_CURSOR_RIGHT == arg2.u8[0] )
        if (cur_x<9 - 1)
          cur_x++;
      if (SC_CURSOR_LEFT == arg2.u8[0])
        if (cur_x>0)
          cur_x--;
      if (SC_CURSOR_UP == arg2.u8[0])
        if (cur_y>0)
          cur_y--;
      if (SC_CURSOR_DOWN == arg2.u8[0])
        if (cur_y<9-1)
          cur_y++;
      if(48<arg1<58)
      {
        state[cell_idx]=arg1-48;
      }
      if (arg1=='R')
      {
        resetBoard=FALSE;
        running=FALSE;
      }
      if (arg1=='+')
        if (start_cnt<9*(9-1))
          start_cnt++;
      if (arg1=='-')
        if (start_cnt>9*2-1)
          start_cnt--;
      if ((arg1=='N')||(arg1=='+')||(arg1=='-'))
      {
        resetBoard=TRUE;
        running=FALSE;
      }
      if (arg1=='H')
      {
        RevealHint;
        time_add+=60;
      }
      if (arg1=='S')
        SaveGame();
      if (arg1=='L')
        LoadGame();
      if (arg1=='V')
      {
        validate=TRUE;
        time_add+=60;
      }
      if (arg1==' ')
        state[cell_idx]=0;
end:
      input=TRUE;
      break;
    }
  }
}

U0 SetStartHints()
{
  I64 i;
  for (i=1; i<=9; i++)
    RevealHint((board_seed+i)%9+1);
  for (i=0; i<3; i++)
  {
    RevealHint(board_seed%9+1);
  }
  while(CountFilled < start_cnt)
  {
    RevealHint;
  }
}

U0 MainLoop()
{
  while(running)
  {
    GetInput;
    Yield;
    CheckBoard;
    Yield;
  }
}

U0 Sudoku(U64 seed=0)
{
  Bool old_ac=AutoComplete(0);
  MenuPush(
	"File {"
	"  Load(,'L');"
	"  Save(,'S');"
	"  Exit(,CH_ESC);"
	"}"
	"Game {"
	"  New(,'N');"
	"  Reset(,'R');"
	"  Hint(,'H');"
	"  Validate(,'V');"
	"}"
	);
  SettingsPush;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  if (seed>0)
  {
    board_seed=seed;
  }
  do
  {
    Fs->draw_it=NULL;
    Yield;
    if (resetBoard)
    {
      board_seed=RandI64;
      time_add=0;
    }
    best_time = GetBestTime(start_cnt);
    hint_cnt=0;
    ClearAll;
    FillInitialSolution;
    RandomizeSolution;
    SetStartHints;
    hint_cnt=0;
    final_time=0;
    verse=NULL;
    ClearCheck;
    running=TRUE;
    start_time=tS;
    PlayAgain=TRUE;
    Fs->draw_it=&DrawIt;
    MainLoop;
    Free(verse);
  }
  while(PlayAgain);
  SaveBestTimes;
  AutoComplete(old_ac);
  DocCursor(1);
  MenuPop;
  DocClear;
  SettingsPop;
}
