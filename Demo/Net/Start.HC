
Cd(__DIR__);;
AutoComplete(0);
#include "Load"
I64 retries = 5;
NetConfigure;
while (ipv4_globals.local_ip == 0 && retries--)  // local_ip is set if NetConfigure is successful
{
  "\nNetConfigure unsuccessful. Retrying...\n";
  NetConfigure;
}
if (ipv4_globals.local_ip == 0)
  "\nNetConfigure unsuccessful. See Network Log for details.\n\n";
else
  "\nNetConfigure successful!\n\n";
NetRep;
if (ipv4_globals.local_ip != 0 && Fs != adam_task)
{
  "\nNow run one of the $MA,"Programs",LM="Cd(\"/Demo/Net/Programs\");Dir;\n"$.\n";
      "\nIf anything crashes to Dbg, try typing $FG,0$G2;$FG$\n\n";
}