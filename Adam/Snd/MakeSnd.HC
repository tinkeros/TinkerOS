Cd(__DIR__);;

#help_index "Snd"
class CSndWaveCtrl
{
  I64 sample_rate,sample_bits,channels;
  F64 freq_multiplier,amp_multiplier;
  F64 phase,last_y,last_dydt,next_y;
};

#help_index "Snd"
public U0 SndTaskEndCB()
{//Will turn-off snd when a task gets killed.
  Snd;
  Exit;
}

#include "ASnd"
#include "SndWave"
#include "SndFile"
Cd("..");;
