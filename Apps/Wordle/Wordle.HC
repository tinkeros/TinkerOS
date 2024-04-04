// I use () for empty functions because I want syntax highlighting on GitHub and my code
// editor. The Generate.ps1 script does a quick search and replace to remove those.

#include "HolyC"
#include "Palette"

U8 *version = "v1.0.0";

"Wordle by xSlendiX - %s\n"
, version;

"Defines ";

#define LT_EMP  0
#define LT_OK   1
#define LT_POS  2
#define LT_SEL  3

#define LT_SZ  (20)
#define LT_RAD (10)

#define LT_CX ((LT_SZ+(LT_RAD*2))/2)
#define LT_CY ((LT_SZ+(LT_RAD*2))/2)

#define LT_FSCALE (3)
#define LT_OFFX   (-1)
#define LT_OFFY   (0)
#define LT_FHALF  (LT_FSCALE/2)

#define LT_SPACING (2)

#define WDEPTH 5
#define WLEN   5

#define W_NONE 0
#define W_WIN  1
#define W_FAIL 2

#define DIALOGW (FONT_WIDTH*30)
#define DIALOGH (FONT_HEIGHT*7)

"Vars ";
U8 **wwords = NULL;
I64 wcnt = 0;

U8 *gameTable = NULL;
U8 *word;
I64 win=W_NONE;
I64 cdepth=0;
I64 gcheats=OFF;

U8 wdark=ON;
//#include "Settings"

"Funcs ";
// Adapted from GodInit
I64 WordInit(U8 *file="Vocab.TXT")
{
  I64 i,ch,count;
  U8 *buf,*ptr,*ptr2;
  i=0;
  if (buf=ptr=FileRead(file))
  {
    while (*ptr)
    {
      while (*ptr && !Bt(char_bmp_word,*ptr))
        ptr++;
      if (*ptr)
      {
        while (*ptr && Bt(char_bmp_word,*ptr))
          ptr++;
        i++;
      }
    }
    Free(buf);
  }
  count=i;
  wwords=MAlloc(count*sizeof(U8 *));
  i=0;
  if (buf=ptr=FileRead(file))
  {
    while (*ptr)
    {
      while (*ptr && !Bt(char_bmp_word,*ptr))
        ptr++;
      if (*ptr)
      {
        ptr2=ptr;
        while (*ptr && Bt(char_bmp_word,*ptr))
          ptr++;
        ch=*ptr;
        *ptr=0;
        wwords[i]=StrNew(ptr2);
        i++;
        *ptr=ch;
      }
    }
    Free(buf);
  }
  return count;
}

U0 DrawLetter(CDC *dc=gr.dc, U8 ch, I64 type, I64 x, I64 y)
{
  I64 pcol=dc->color;
  switch (type)
  {
  case LT_OK:
    dc->color = GREEN;
    break;
  case LT_POS:
    dc->color = YELLOW;
    break;
  case LT_SEL:
    dc->color = BLUE;
    break;
  case LT_EMP:
  default:
    dc->color = LTGRAY;
  }
  GrRndRect(dc, LT_RAD+x, LT_RAD+y, LT_SZ, LT_SZ, LT_RAD);
  dc->color=BLACK;
  // FIXME: Buggy, needs better math
  GrChar(dc, ch, x+LT_OFFX+(LT_CX-LT_FHALF)/2, y+LT_OFFY+(LT_CY-LT_FHALF)/2, LT_FSCALE);
  dc->color=pcol;
}

U0 DrawWin(CDC *dc)
{
  if (win == W_NONE) return;
  I64 pcol=dc->color;
  dc->color=BLACK;
  GrRndRect(dc, dc->width/2-DIALOGW/2, dc->height/2-DIALOGH/2,
      DIALOGW, DIALOGH, FONT_WIDTH);
  dc->color=WHITE;
  GrRndRect(dc, dc->width/2-DIALOGW/2, dc->height/2-DIALOGH/2,
      DIALOGW, DIALOGH, FONT_WIDTH/2);
  switch (win)
  {
  case W_WIN:
    dc->color=GREEN;
    GrPrint(dc, dc->width/2-4*FONT_WIDTH, dc->height/2-FONT_HEIGHT/2-FONT_HEIGHT,
      "You win!");
    break;
  case W_FAIL:
    dc->color=RED;
    GrPrint(dc, dc->width/2-4.5*FONT_WIDTH, dc->height/2-FONT_HEIGHT/2-FONT_HEIGHT,
        "You lose!");
    break;
  }
  dc->color=BLACK;
  GrPrint(dc, dc->width/2-13*FONT_WIDTH, dc->height/2-FONT_HEIGHT/2+FONT_HEIGHT,
      "Press ENTER to play again!");
  dc->color=pcol;
}

U0 DrawTable(CDC *dc=gr.dc)
{
  I64 i,j;
  I64 type;
  U8 ch;
  I64 w=(LT_SZ+LT_RAD*2+LT_SPACING)*WLEN;
  I64 h=(LT_SZ+LT_RAD*2+LT_SPACING)*WDEPTH;
  I64 offx=dc->width/2-w/2;
  I64 offy=dc->height/2-h/2;
  for (i=0; i<WDEPTH; i++)
  {
    for (j=0; j<WLEN; j++)
    {
      ch=gameTable[j+WLEN*i];
      type=LT_EMP;
      if (cdepth <= i)
      {
        type=LT_SEL;
        goto draw_table_next;
      }
      if (ch == word[j])
      {
        type=LT_OK;
        goto draw_table_next;
      }
      if (U8InStr(ch, word))
      {
        type=LT_POS;
        goto draw_table_next;
      }
draw_table_next:
      DrawLetter(dc, ch, type, j*(LT_SZ+LT_SPACING+LT_RAD*2)+offx,
          i*(LT_SZ+LT_SPACING+LT_RAD*2)+offy);
    }
    if (cdepth == i && win == W_NONE)
      GrArrow3(dc, w+LT_RAD*2+offx, LT_CY+(LT_SZ+LT_SPACING+LT_RAD*2)*i+offy, 0,
        w+LT_RAD+offx,LT_CY+(LT_SZ+LT_SPACING+LT_RAD*2)*i+offy, 0);
  }
}

I64 CheckWin()
{
  if (cdepth == 0) return W_NONE;
  if (StrCmp(gameTable+(cdepth-1)*WLEN, word) == 0) return W_WIN;
  if (cdepth == WDEPTH) return W_FAIL;
  return W_NONE;
}

U0 WordleDrawIt(CTask *, CDC *dc)
{
  DrawTable(dc);
  if (gcheats==ON)
  {
    GrPrint(dc, FONT_WIDTH, FONT_HEIGHT, "Cheats ON!\nWord: %s", word);
  }
  GrPrint(dc, dc->width-FONT_WIDTH*21, FONT_HEIGHT,
      "Toggle theme: CTRL-T\n  Quit: CTRL-Q | ESC");
  GrPrint(dc, dc->width-FONT_WIDTH*(StrLen(version)+1), dc->height-(FONT_HEIGHT*3),
      version);
  DrawWin(dc);
}

U0 ResetGame()
{
  I64 i;
  I64 randomWord = RandRng(,wcnt);
  word = wwords[randomWord];
  if (word == NULL)
    throw('WN');
  cdepth=0;
  for (i=0; i<WDEPTH*WLEN+1; i++)
  {
    gameTable[i] = '\0';
  }
  win=W_NONE;
}

U0 Wordle()
{
  U64 sc;
  I64 i;
  wcnt = WordInit();
  if (wwords == NULL)
    throw('WLN');
  gameTable = MAlloc(sizeof(U8)*WDEPTH*WLEN+1);
  ResetGame();
  SettingsPush();
  DocClear();
  AutoComplete();
  WinBorder();
  WinMax();
  DocCursor();
  if (wdark)
    WordleDark();
  else
    WordleLight();
  Fs->draw_it = &WordleDrawIt;
  I64 wbase,len;
  U8 *cheatCode="elephants";
  I64 cheatIdx=0;
  try
  {
    while (TRUE)
    {
      wbase=cdepth*WLEN;
      len=StrLen(gameTable+wbase);
      U8 key = GetKey(&sc);
      switch (key) // FIXME: This can probably be optimized further
      {
      case 'a'...'z':
        if (key == cheatCode[cheatIdx])
          cheatIdx++;
        else
          cheatIdx=0;
        if (cheatIdx == StrLen(cheatCode))
          gcheats=!gcheats;
        if (win != W_NONE) break;
        if (wbase+len >= (cdepth+1)*WLEN) break;
        if (cdepth != 0)
          if (wbase+len <= (cdepth-1)*WLEN) break;
        if (len <= WLEN)
        {
          gameTable[wbase+len] = key;
        }
        break;
      case CH_BACKSPACE:
        if (win != W_NONE) break;
        if (wbase+len > (cdepth+1)*WLEN) break;
        if (cdepth != 0)
          if (wbase+len <= (cdepth-1)*WLEN) break;
        if (len > 0)
        {
          gameTable[wbase+len-1] = '\0';
        }
        break;
      case '\n':
        if (win != W_NONE)
        {
          ResetGame();
          break;
        }
        if (len == 5)
          cdepth++;
        win = CheckWin();
        break;
      case CH_CTRLT:
        if (wdark)
          WordleLight();
        else
          WordleDark();
        wdark=!wdark;
        break;
      case CH_CTRLQ:
      case CH_SHIFT_ESC:
      case CH_ESC:
        goto wordle_done;
      }
    }
  }
  catch PutExcept;
wordle_done:
  Free(gameTable);
  for (i=0; i<wcnt; i++)
    Free(wwords[i]);
  Free(wwords);
  SettingsPop();
  MenuPop();
}

"\n";
