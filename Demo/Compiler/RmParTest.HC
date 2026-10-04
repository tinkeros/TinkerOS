Cd(__DIR__);;
#include "RmParens"

U0 RmParTest()
{
  U8 *tmp_file=NULL;
  U8 *buf,*expected_hash=NULL,*result_hash=NULL;
  I64 size;

  if (DrvMounted('B'))
    tmp_file=StrNew("B:/RmParTestCases.HC");
  else if (DrvIsWritable())
    tmp_file=MStrPrint("%C:/RmParTestCases.HC",Drv2Let(Fs->cur_dv));

  if (!tmp_file)
  {
    "RmParTest: SKIP -- no writable drive available for temp file\n";
    return;
  }

  buf=FileRead("RmParTestCases.HC",&size);
  if (!buf)
  {
    "RmParTest: can't read 'RmParTestCases.HC'\n";
    Free(tmp_file);
    return;
  }
  FileWrite(tmp_file,buf,size);
  Free(buf);

  RmParens(tmp_file);

  md5("RmParExpected.HC",&expected_hash);
  md5(tmp_file,&result_hash);

  if (expected_hash && result_hash && !StrCmp(expected_hash,result_hash))
    "RmParTest: PASS -- '%s' matches RmParExpected.HC (MD5 %s)\n",
        tmp_file,expected_hash;
  else
    "RmParTest: FAIL -- MD5 mismatch (expected %s, got %s)\n",
        expected_hash,result_hash;

  Free(expected_hash);
  Free(result_hash);
  Del(tmp_file,FALSE,FALSE,FALSE);
  Free(tmp_file);
}

RmParTest;
