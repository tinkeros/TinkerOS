#include "/Adam/AutoComplete/ACInit"


U0 DoACInit()
{
  Silent;       //no output to scrn
  ACInit("/*;!*/Bible.TXT*");
  Silent(OFF); //no output to scrn
}

DoACInit;


// If not Adam, give him symbols too
if (!Gs->num)
  AdamFile("/Adam/AutoComplete/ACInit");



Adam("ShowACWhenReady;\n");


