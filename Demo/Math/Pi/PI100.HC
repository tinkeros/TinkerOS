#include "/Demo/Math/Pi/BnPiKernel"

static U8 correct_pi_100[102]={'3','.','1','4','1','5','9','2','6','5','3','5','8','9','7','9','3','2','3','8','4','6','2','6','4','3','3','8','3','2','7','9','5','0','2','8','8','4','1','9','7','1','6','9','3','9','9','3','7','5','1','0','5','8','2','0','9','7','4','9','4','4','5','9','2','3','0','7','8','1','6','4','0','6','2','8','6','2','0','8','9','9','8','6','2','8','0','3','4','8','2','5','3','4','2','1','1','7','0','6','7',0};

U0 CalcPi100Test()
{
  Bool passed=TRUE;
  I64 digits=100;
  U8 digits_out[102];
  F64 start_time=tS;
  "Calculating the first 100 digits of PI...\n\n";
  "\nPI ~ ";
  Yield;
  BnPiKernel(digits, digits_out);
  digits_out[101]=0;
  "\n\n";
  "Calculation took %1.5f (s)\n\n",tS-start_time;

  "Verifying result...";

  for (digits=0; digits<101; digits++)
    if (digits_out[digits] != correct_pi_100[digits]) passed=FALSE;

  if (passed) "result OK!\n";
  else throw('FAIL');
}

CalcPi100Test;
Sleep(500);
