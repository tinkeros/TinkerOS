Cd(__DIR__);;

#include "Cube";

U64 level=PopUpRangeI64(1,20,,"Pick Level:\n");

CubeGame(level,RandI64);

