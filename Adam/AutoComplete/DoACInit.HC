#include "/Adam/AutoComplete/ACInit"

U0 DoACInit()
{
  Silent;       //no output to scrn
  ACInit("/*;!*/Bible.TXT*");
  Silent(OFF); //no output to scrn
  Adam("ShowACWhenReady;\n");
}

Spawn(&DoACInit);

