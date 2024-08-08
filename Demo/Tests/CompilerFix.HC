I64 WorkingAndEqCmp(I64 x)
{
  x&=~1;
  return x;
}

U0 TestAndEqCmp()
{
  if (WorkingAndEqCmp(-200)!=-200) throw('FAIL');
  else
  {
    "Test passed!\n";
    Sleep(500);
  }
}

TestAndEqCmp;

