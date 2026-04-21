// Alleluia #1

U0 V1() {
  U8 *str_words = "Je\0-sus \0is \0Lord \0of \0all \0the\0 \0 earth,\n\0He \0is \0the \0king \0of \0cre\0-a\0-tion! \0";
  U8 *str_rest  = "M3/45qCqC4qA5hDqC4hBbq(AqBbh.GqAqGqFqFqGqAh(BbhG";
  Play(str_rest, str_words);
}
U0 V2() {
  U8 *str_words = "Spread \0the \0good \0news \0o'er \0all \0the\0 \0 earth,\n\0Je\0-sus \0has \0died \0and \0has \0ris\0-en! \0";
  U8 *str_rest  = "5qCqC4qA5hDqC4hBbq(AqBbh.GqAqGqFqFqGqAh(BbhG";
  Play(str_rest, str_words);
}
U0 V3() {
  U8 *str_words = "We \0have \0been \0cru\0-ci\0-fied \0with\0 \0 Christ.\n\0Now \0we \0shall \0live \0 \0for\0-ev\0-er! \0";
  U8 *str_rest  = "5qCqC4qA5hDqC4hBbq(AqBbh.GqAqGqFqFqGqAh(BbhG";
  Play(str_rest, str_words);
}
U0 V4() {
  U8 *str_words = "God \0has \0pro\0-claimed \0his \0gra\0-cious \0 \0gift;\n\0Life \0 \0e\0-ter\0-nal \0for \0all \0who \0be\0-lieve!\0";
  U8 *str_rest  = "5qCqC4qA5hDqC4hBbq(AqBbh.Gq(AqGqFqFqGqAqAqAqBbhG";
  Play(str_rest, str_words);
}
U0 V5() {
  U8 *str_words = "Come \0let \0us \0praise \0the \0liv\0-ing\0 \0 God!\n\0Joy\0-ful\0-ly \0sing \0to \0our \0Sav\0-ior! \0";
  U8 *str_rest  = "5qCqC4qA5hDqC4hBbq(AqBbh.GqAqGqFqFqGqAh(BbhG";
  Play(str_rest, str_words);
}

U0 Refrain()
{
  U8 *str_words = "\n\nAl\0-le\0-lu\0-ia, \0al\0-le\0-lu\0-ia,\n\0gi\0ve \0thanks \0to \0the \0ris\0-en \0Lord,\n\0Al\0-le\0-lu\0-ia, \0al\0-le\0-lu\0-ia,\n\0gi\0ve \0praise \0to \0his \0 \0name!\n\n\0";
  U8 *str_rest  = "4qCqCqFqFqGqAqFqFq(GqAqBbqBbqAqGqFqEqCqCqFqFqGqAqFqFq(GqAqBb5qC4q(AqGh.F";
  Play(str_rest, str_words);
}

U0 Song()
{
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  music.tempo= 2.50;
  music.stacatto_factor= 0.902;
  WinMax;
  DocClear;

  Refrain;
  V1;
  Refrain;
  V2;
  Refrain;
  V3;
  Refrain;
  V4;
  Refrain;
  V5;
  Refrain;
  Snd;
}

Song;

