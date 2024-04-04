I64 ToLower(I64 ch)
{// Basic lower case conversion implementation
  I64 res=ch;
  if ('A'<=ch<='Z')
    res = ch ^ 0x20;
  return res;
}

Bool YorN(I64 enter_default=0)
{//Wait for user to answer Y or N.
  I64 ch;
  if (ToLower(enter_default)=='y' || ToLower(enter_default)=='n')
    "(y or n, default: %c)? ",ToLower(enter_default);
  else
    "(y or n)? ";
  while (TRUE)
  {
    ch=ToUpper(GetChar(,FALSE));
    if (enter_default && ch=='\n')
      ch=ToUpper(enter_default);
    if (ch=='Y')
    {
      "$$PT$$YES$$FG$$\n";
      return TRUE;
    }
    else if (ch=='N')
    {
      "$$PT$$NO$$FG$$\n";
      return FALSE;
    }
  }
}

Bool AreYouSure()
{//Print "Are you sure" and waits for Y or N.
  "ARE YOU SURE ";
  return YorN;
}
