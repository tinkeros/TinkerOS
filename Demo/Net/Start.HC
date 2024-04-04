
Cd(__DIR__);;
#include "Load"
I64 retries = 0;
NetCfg;
while (ipv4_globals.local_ip == 0
    && retries<3) // local_ip is set if NetConfigure is successful
{
  retries++;
  if (retries>0)
    net_log_dbg=TRUE;
  if (retries>1)
  {
    net_log_warn=TRUE;
    net_log_log=TRUE;
  }
  "\nNetCfg unsuccessful. Retrying...\n";
  NetCfg;
}
if (ipv4_globals.local_ip == 0)
  "\nNetCfg unsuccessful. See Network Log for details.\n\n";
else
  "\nNetCfg successful!\n\n";
NetRep;
if (ipv4_globals.local_ip != 0 && Fs != adam_task)
{
  "\nNow run one of the $MA,"Programs",LM="Cd(\"/Demo/Net/Programs\");Dir;\n"$.\n";
      "\nIf anything crashes to Dbg, try typing $FG,0$G2;$FG$\n\n";
}
