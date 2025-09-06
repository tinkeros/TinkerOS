// Multi-Channel Risen Demo

U0 RisenMulti()
{
  MusicSettingsRst;
  music.tempo= 2.85;
  music.stacatto_factor= 0.902;

  SetInst(PIPEORG,0);
  SetInst(SQUARWAV,1);

  "Playing with just channel 0\n";
  Play("5eDEqFFetEEFqDeCDDEetCGF");
  Play("5eDEqFFetEEFqDeCDDEetCGF");
  Play("5eDCqDE4eAA5etEEFEDG4B5DCqF");
  Play("5eDCqDE4eAA5etEEFEDG4B5DCqF");

  "Playing with just channel 1\n";
  PlayM("5eDEqFFetEEFqDeCDDEetCGF",,1,1);
  PlayM("5eDEqFFetEEFqDeCDDEetCGF",,1,1);
  PlayM("5eDCqDE4eAA5etEEFEDG4B5DCqF",,1,1);
  PlayM("5eDCqDE4eAA5etEEFEDG4B5DCqF",,1,1);

  "Playing with just channel 0 and 1 at together!\n";
  PlayM("5eDEqFFetEEFqDeCDDEetCGF",,0,1);
  PlayM("5eDEqFFetEEFqDeCDDEetCGF",,0,1);
  PlayM("5eDCqDE4eAA5etEEFEDG4B5DCqF",,0,1);
  PlayM("5eDCqDE4eAA5etEEFEDG4B5DCqF",,0,1);
}

RisenMulti;
