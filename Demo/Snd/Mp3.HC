// Convert an input file for use with this player using ffmpeg.
// Sample rate must be 32000, 44100 or 48000
//
// Low quality (fastest to decode, mono 32000Hz 64kbit):
//   ffmpeg -i input.wav -ac 1 -ar 32000 -c:a libmp3lame -b:a 64k output.mp3
//
// High quality (stereo at the mixer rate, no resampling):
//   ffmpeg -i input.wav -ac 2 -ar 48000 -c:a libmp3lame -b:a 320k output.mp3

I64 mp3_huff[2804]={
      513,0,513,16,513,1,17,513,0,1025,513,16,
      1,513,17,1025,513,32,33,513,18,513,2,34,
      1025,513,0,1,513,17,513,16,1025,513,32,33,
      513,18,513,2,34,513,0,1025,513,16,1,513,
      17,2049,1025,513,32,2,513,33,18,2049,1025,513,
      34,48,513,3,19,513,49,513,50,513,35,51,
      1537,1025,513,0,16,17,1537,513,1,513,32,33,
      1537,513,18,513,2,34,1025,513,49,19,1025,513,
      48,50,513,35,513,3,51,513,0,1025,513,16,
      1,2049,513,17,1025,513,32,2,33,4609,1537,513,
      18,513,34,48,1025,513,49,19,1025,513,3,50,
      513,35,4,2561,1025,513,64,65,513,20,513,66,
      36,3073,1537,1025,513,51,67,80,1025,513,52,5,
      81,1537,513,21,513,82,37,1025,513,68,53,1025,
      513,83,84,513,69,85,1537,513,0,513,16,1,
      513,17,1025,513,33,18,3585,1025,513,32,2,513,
      34,1025,513,48,3,513,49,19,3585,2049,1025,513,
      50,35,513,64,4,513,65,513,20,66,3073,1537,
      513,36,513,51,80,1025,513,67,52,81,1537,513,
      21,513,5,82,1537,513,37,513,68,53,513,83,
      513,69,513,84,85,2049,1025,513,0,16,513,1,
      17,2561,1025,513,32,33,513,18,513,2,34,3073,
      1537,1025,513,48,3,49,513,19,513,50,35,3073,
      1025,513,65,20,1025,513,64,51,513,66,36,2561,
      1537,1025,513,4,80,67,513,52,81,2049,1025,513,
      21,82,513,37,68,1537,1025,513,5,84,83,513,
      53,513,69,85,513,0,1025,513,16,1,2561,513,
      17,1025,513,32,2,513,33,18,7169,2049,1025,513,
      34,48,513,49,19,2049,1025,513,3,50,513,35,
      64,1025,513,65,20,1025,513,4,51,513,66,36,
      7169,2561,1537,1025,513,80,5,96,513,97,22,3073,
      1537,1025,513,67,52,81,513,21,513,82,37,1025,
      513,38,54,113,5121,2049,513,23,1025,513,68,83,
      6,1537,1025,513,53,69,98,513,112,513,7,100,
      3585,1025,513,114,39,1537,513,99,513,84,85,513,
      70,115,2049,1025,513,55,101,513,86,116,1537,513,
      71,513,102,117,1025,513,87,118,513,103,119,1537,
      513,0,513,16,1,2049,513,17,1025,513,32,2,
      18,6145,2049,513,33,513,34,513,48,3,1025,513,
      49,19,1025,513,50,35,1025,513,64,4,513,65,
      20,7681,4097,2561,1025,513,66,36,1025,513,51,67,
      80,1025,513,52,81,97,1537,513,22,513,6,38,
      513,98,513,21,513,5,82,4097,2561,1537,1025,513,
      37,68,96,513,99,54,1025,513,112,23,113,4097,
      1537,1025,513,7,100,114,513,39,1025,513,83,53,
      513,84,69,2561,1025,513,70,115,513,55,513,101,
      86,2561,1537,1025,513,85,87,116,513,71,102,1025,
      513,117,118,513,103,119,3073,1025,513,16,1,513,
      17,513,0,513,32,2,4097,1025,513,33,18,1025,
      513,34,49,513,19,513,48,513,3,64,6657,2049,
      1025,513,50,35,513,65,51,2561,1025,513,20,66,
      513,36,513,4,80,1025,513,67,52,513,81,21,
      7169,3585,2049,1025,513,82,37,513,83,53,1025,513,
      96,22,97,1025,513,98,38,1537,1025,513,5,6,
      68,513,84,69,4609,2561,1025,513,99,54,1025,513,
      112,7,113,1025,513,23,100,513,70,114,2561,1537,
      513,39,513,85,115,513,55,86,2049,1025,513,101,
      116,513,71,102,1025,513,117,87,513,118,513,103,
      119,513,0,1537,513,16,513,1,17,7169,2049,1025,
      513,32,2,513,33,18,2049,1025,513,34,48,513,
      3,49,1537,513,19,513,50,35,1025,513,64,4,
      65,17921,7169,3585,1537,513,20,513,51,66,1025,513,
      36,80,513,67,52,1025,513,81,21,1025,513,5,
      82,513,37,513,68,83,3585,2049,1025,513,96,6,
      513,97,22,1025,513,128,8,129,4097,2049,1025,513,
      53,98,513,38,84,1025,513,69,99,513,54,112,
      1537,1025,513,7,85,113,513,23,513,39,55,18433,
      6145,3073,1025,513,24,130,513,40,1025,513,100,70,
      114,2049,1025,513,132,72,513,144,9,513,145,25,
      6145,3585,2049,1025,513,115,101,513,86,116,1025,513,
      71,102,131,1537,513,56,513,117,87,513,146,41,
      3585,2049,1025,513,103,133,513,88,57,513,147,513,
      73,134,1537,513,160,513,104,10,513,161,26,17409,
      6145,3073,1025,513,162,42,1025,513,149,89,513,163,
      58,2049,1025,513,74,150,513,176,11,513,177,27,
      5121,2049,513,178,1025,513,118,119,148,1537,1025,513,
      135,120,164,1025,513,105,165,43,3073,1537,1025,513,
      90,136,179,513,59,513,121,166,1537,1025,513,106,
      180,192,1025,513,12,152,193,15361,5633,2561,1537,513,
      28,513,137,181,513,91,194,1025,513,44,60,1025,
      513,182,107,513,196,76,4097,2049,1025,513,168,138,
      513,208,13,513,209,513,75,513,151,167,3073,1537,
      513,195,513,122,153,1025,513,197,92,183,1025,513,
      29,210,513,45,513,123,211,13313,7169,3073,1025,513,
      61,198,1025,513,108,169,513,154,212,2049,1025,513,
      184,139,513,77,199,1025,513,124,213,513,93,224,
      2561,1025,513,225,30,1025,513,14,46,226,2049,1025,
      513,227,109,513,140,228,1025,513,229,186,240,9729,
      4097,1025,513,241,31,1537,1025,513,170,155,185,513,
      62,513,214,200,3073,1537,513,78,513,215,125,513,
      171,513,94,201,1537,513,15,513,156,110,513,242,
      47,8193,4097,1537,1025,513,216,141,63,1537,513,243,
      513,230,202,513,244,79,2049,1025,513,187,172,513,
      231,245,1025,513,217,157,513,95,232,7681,3073,1537,
      513,111,513,246,203,1025,513,188,173,218,2049,513,
      247,1025,513,126,127,142,1537,1025,513,158,174,204,
      513,248,143,4609,2049,1025,513,219,189,513,234,249,
      1025,513,159,235,513,190,513,205,250,3585,1025,513,
      221,236,1537,1025,513,233,175,220,513,206,251,2049,
      1025,513,191,222,513,207,238,1025,513,223,239,513,
      255,513,237,513,253,513,252,254,4097,1537,513,0,
      513,16,1,513,17,1025,513,32,2,513,33,18,
      12801,4097,1537,513,34,513,48,49,1537,513,19,513,
      3,64,513,50,35,3585,1537,1025,513,4,20,65,
      1025,513,51,66,513,36,67,2561,1537,513,52,513,
      80,5,513,81,21,1025,513,82,37,1025,513,68,
      83,97,23041,9217,4609,2561,1537,513,53,513,96,6,
      513,22,98,1025,513,38,84,513,69,99,2561,1537,
      513,54,513,112,7,513,113,85,1025,513,23,100,
      513,114,39,6145,4097,2049,1025,513,70,115,513,55,
      101,1025,513,86,128,513,8,116,1025,513,129,24,
      513,130,40,4097,2049,1025,513,71,102,513,131,56,
      1025,513,117,87,513,132,72,1537,1025,513,144,25,
      145,1025,513,146,118,513,103,41,23553,9217,4609,2561,
      1025,513,133,88,1025,513,9,119,147,1025,513,57,
      148,513,73,134,2561,1537,513,104,513,160,10,513,
      161,26,1025,513,162,42,513,149,89,6657,3585,1537,
      513,163,513,58,135,1025,513,120,164,513,74,150,
      1537,1025,513,105,176,177,1025,513,27,165,178,3585,
      2049,1025,513,90,43,513,136,151,513,179,513,121,
      59,2049,1025,513,106,180,513,75,193,1025,513,152,
      137,513,28,181,20481,8705,4097,1537,1025,513,91,44,
      194,1537,1025,513,11,192,166,513,167,122,2561,1025,
      513,195,60,1025,513,12,153,182,1025,513,107,196,
      513,76,168,5121,2561,1025,513,138,197,1025,513,208,
      92,209,1025,513,183,123,513,29,513,13,45,3073,
      1025,513,210,211,1025,513,61,198,513,108,169,1537,
      1025,513,154,184,212,1025,513,139,77,513,199,124,
      17409,8705,4609,2561,1025,513,213,93,1025,513,224,14,
      225,1025,513,30,226,513,170,46,2049,1025,513,185,
      155,513,227,214,1025,513,109,62,513,200,140,4097,
      2049,1025,513,228,78,513,215,125,1025,513,229,186,
      513,171,94,2049,1025,513,201,156,513,241,31,1537,
      1025,513,240,110,242,513,47,230,9729,4609,2049,1025,
      513,216,243,513,63,244,1537,513,79,513,141,217,
      513,187,202,2049,1025,513,172,231,513,126,245,2049,
      1025,513,157,95,513,232,142,513,246,203,8705,4609,
      2561,1537,1025,513,15,174,111,513,188,218,1025,513,
      173,247,513,127,233,2049,1025,513,158,204,513,248,
      143,1025,513,219,189,513,234,249,4097,2049,1025,513,
      159,220,513,205,235,1025,513,190,250,513,175,221,
      3585,1537,1025,513,236,206,251,1025,513,191,237,513,
      222,252,1537,1025,513,207,253,238,1025,513,223,254,
      513,239,255,513,0,1537,513,16,513,1,17,10753,
      2049,1025,513,32,2,513,33,18,2561,1537,513,34,
      513,48,3,513,49,19,2561,1025,513,50,35,1025,
      513,64,4,65,1537,513,20,513,51,66,1025,513,
      36,80,513,67,52,35329,10241,4097,1537,1025,513,5,
      21,81,1025,513,82,37,1025,513,68,53,83,2561,
      1537,1025,513,96,6,97,513,22,98,2049,1025,513,
      38,84,513,69,99,1025,513,54,112,113,10241,4609,
      2049,513,23,513,7,513,85,100,1025,513,114,39,
      1025,513,70,101,115,2561,1537,513,55,513,86,8,
      513,128,129,1537,513,24,513,116,71,513,130,513,
      40,102,6145,3585,2049,1025,513,131,56,513,117,132,
      1025,513,72,144,145,1537,513,25,513,9,118,513,
      146,41,3585,2049,1025,513,133,88,513,147,57,1025,
      513,160,10,26,2049,513,162,513,103,513,87,73,
      1537,513,148,513,119,134,513,161,513,104,149,56321,
      32257,12801,6657,3073,1537,513,42,513,89,58,513,163,
      513,135,120,2049,1025,513,164,74,513,150,105,1025,
      513,176,11,177,2561,1025,513,27,178,513,43,513,
      165,90,1537,513,179,513,166,106,1025,513,180,75,
      513,12,193,7681,3585,1537,1025,513,181,194,44,1025,
      513,167,195,513,107,196,2049,513,29,1025,513,136,
      151,59,1025,513,209,210,513,45,211,4609,1537,1025,
      513,30,46,226,1537,1025,513,121,152,192,513,28,
      513,137,91,3585,1537,513,60,513,122,182,1025,513,
      76,153,513,168,138,1537,513,13,513,197,92,1025,
      513,61,198,513,108,154,22529,22017,9217,4097,2049,1025,
      513,139,77,513,199,124,1025,513,213,93,513,224,
      14,2049,513,227,1025,513,208,183,123,1537,1025,513,
      169,184,212,513,225,513,170,185,6145,2561,1537,1025,
      513,155,214,109,513,62,200,1537,1025,513,140,228,
      78,1025,513,215,229,513,186,171,3073,1025,513,156,
      230,1025,513,110,216,513,141,187,2049,1025,513,231,
      157,513,232,142,1025,513,203,188,158,241,513,31,
      513,15,47,16897,14337,513,242,13313,12801,5121,2049,513,
      189,513,94,513,125,201,1537,513,202,513,172,126,
      1025,513,218,173,204,2561,1537,513,174,513,219,220,
      513,205,190,1537,1025,513,235,237,238,1537,1025,513,
      217,234,233,513,222,1025,513,221,236,206,63,240,
      1025,513,243,244,513,79,513,245,95,2561,513,255,
      1025,513,246,111,513,247,127,3073,1537,513,143,513,
      248,249,1025,513,159,250,175,2049,1025,513,251,191,
      513,252,207,1025,513,253,223,513,254,239,15361,2049,
      1025,513,0,16,513,1,17,3585,1537,1025,513,32,
      2,33,513,18,513,34,513,48,3,3585,1025,513,
      49,19,1025,513,50,35,1025,513,64,4,65,2049,
      1025,513,20,51,513,66,36,1537,1025,513,67,52,
      81,1537,1025,513,80,5,21,513,82,37,64001,25089,
      8705,4609,2561,1025,513,68,83,513,53,513,96,6,
      1025,513,97,22,513,98,38,2049,1025,513,84,69,
      513,99,54,1025,513,113,85,513,100,70,8193,3585,
      1537,513,114,513,39,55,513,115,1025,513,112,7,
      23,2561,1025,513,101,86,1025,513,128,8,129,1025,
      513,116,71,513,24,130,4097,2049,1025,513,40,102,
      513,131,56,1025,513,117,87,513,132,72,2049,1025,
      513,145,25,513,146,118,1025,513,103,41,513,133,
      88,23553,8705,4097,2049,1025,513,147,57,513,148,73,
      1025,513,119,134,513,104,161,2049,1025,513,162,42,
      513,149,89,1025,513,163,58,513,135,513,120,74,
      5633,3073,1025,513,164,150,1025,513,105,177,513,27,
      165,1537,513,178,513,90,43,513,136,179,4097,2561,
      1537,513,144,513,9,160,513,151,121,1025,513,166,
      106,180,3073,1537,513,26,513,10,176,513,59,513,
      11,192,1025,513,75,193,513,152,137,17153,8705,4097,
      2049,1025,513,28,181,513,91,194,1025,513,44,167,
      513,122,195,2561,1537,513,60,513,12,208,513,182,
      107,1025,513,196,76,513,153,168,4097,2049,1025,513,
      138,197,513,92,209,1025,513,183,123,513,29,210,
      2305,1025,513,45,211,513,61,198,22010,1025,513,108,
      169,513,154,212,8193,4097,2049,1025,513,184,139,513,
      77,199,1025,513,124,213,513,93,225,2049,1025,513,
      30,226,513,170,185,1025,513,155,227,513,214,109,
      5121,2561,1537,513,62,513,46,78,513,200,140,1025,
      513,228,215,1025,513,125,171,229,2561,1025,513,186,
      94,513,201,513,156,110,2049,513,230,513,13,513,
      224,14,1025,513,216,141,513,187,202,18945,513,255,
      16385,14849,8193,4097,2049,1025,513,172,231,513,126,217,
      1025,513,157,232,513,142,203,2049,1025,513,188,218,
      513,173,233,1025,513,158,204,513,219,189,4097,2049,
      1025,513,234,174,513,220,205,1025,513,235,190,513,
      221,236,2049,1025,513,206,237,513,222,238,15,1025,
      513,240,31,241,1025,513,242,47,513,243,63,4609,
      2049,1025,513,244,79,513,245,95,1025,513,246,111,
      513,247,513,127,143,2561,1025,513,248,249,1025,513,
      159,175,250,2049,1025,513,251,191,513,252,207,1025,
      513,253,223,513,254,239,513,0,2049,1025,513,8,
      4,513,1,2,2049,1025,513,12,10,513,3,6,
      1537,513,9,513,5,7,1025,513,14,13,513,15,
      11,4097,2049,1025,513,0,1,513,2,3,1025,513,
      4,5,513,6,7,2049,1025,513,8,9,513,10,
      11,1025,513,12,13,513,14,15};

I64 mp3_huff_off[34]={
      0,0,7,24,0,41,72,103,174,245,316,443,
      570,697,0,1208,1719,1719,1719,1719,1719,1719,1719,1719,
      2230,2230,2230,2230,2230,2230,2230,2230,2742,2773};

I64 mp3_huff_len[34]={
      0,7,17,17,0,31,31,71,71,71,127,127,
      127,511,0,511,511,511,511,511,511,511,511,511,
      512,512,512,512,512,512,512,512,31,31};

I64 mp3_huff_linbits[34]={
      0,0,0,0,0,0,0,0,0,0,0,0,
      0,0,0,0,1,2,3,4,6,8,10,13,
      4,5,6,7,8,9,11,13,0,0};

I64 mp3_sfb_l[69]={
      0,4,8,12,16,20,24,30,36,44,52,62,
      74,90,110,134,162,196,238,288,342,418,576,0,
      4,8,12,16,20,24,30,36,42,50,60,72,
      88,106,128,156,190,230,276,330,384,576,0,4,
      8,12,16,20,24,30,36,44,54,66,82,102,
      126,156,194,240,296,364,448,550,576};

I64 mp3_sfb_s[42]={
      0,4,8,12,16,22,30,40,52,66,84,106,
      136,192,0,4,8,12,16,22,28,38,50,64,
      80,100,126,192,0,4,8,12,16,22,30,42,
      58,78,104,138,180,192};

I64 mp3_dtbl_i[512]={
      0,-1,-1,-1,-1,-1,-1,-2,-2,-2,
      -2,-3,-3,-4,-4,-5,-5,-6,-7,-7,
      -8,-9,-10,-11,-13,-14,-16,-17,-19,-21,
      -24,-26,-29,-31,-35,-38,-41,-45,-49,-53,
      -58,-63,-68,-73,-79,-85,-91,-97,-104,-111,
      -117,-125,-132,-139,-147,-154,-161,-169,-176,-183,
      -190,-196,-202,-208,213,218,222,225,227,228,
      228,227,224,221,215,208,200,189,177,163,
      146,127,106,83,57,29,-2,-36,-72,-111,
      -153,-197,-244,-294,-347,-401,-459,-519,-581,-645,
      -711,-779,-848,-919,-991,-1064,-1137,-1210,-1283,-1356,
      -1428,-1498,-1567,-1634,-1698,-1759,-1817,-1870,-1919,-1962,
      -2001,-2032,-2057,-2075,-2085,-2087,-2080,-2063,2037,2000,
      1952,1893,1822,1739,1644,1535,1414,1280,1131,970,
      794,605,402,185,-45,-288,-545,-814,-1095,-1388,
      -1692,-2006,-2330,-2663,-3004,-3351,-3705,-4063,-4425,-4788,
      -5153,-5517,-5879,-6237,-6589,-6935,-7271,-7597,-7910,-8209,
      -8491,-8755,-8998,-9219,-9416,-9585,-9727,-9838,-9916,-9959,
      -9966,-9935,-9863,-9750,-9592,-9389,-9139,-8840,-8492,-8092,
      -7640,-7134,6574,5959,5288,4561,3776,2935,2037,1082,
      70,-998,-2122,-3300,-4533,-5818,-7154,-8540,-9975,-11455,
      -12980,-14548,-16155,-17799,-19478,-21189,-22929,-24694,-26482,-28289,
      -30112,-31947,-33791,-35640,-37489,-39336,-41176,-43006,-44821,-46617,
      -48390,-50137,-51853,-53534,-55178,-56778,-58333,-59838,-61289,-62684,
      -64019,-65290,-66494,-67629,-68692,-69679,-70590,-71420,-72169,-72835,
      -73415,-73908,-74313,-74630,-74856,-74992,75038,74992,74856,74630,
      74313,73908,73415,72835,72169,71420,70590,69679,68692,67629,
      66494,65290,64019,62684,61289,59838,58333,56778,55178,53534,
      51853,50137,48390,46617,44821,43006,41176,39336,37489,35640,
      33791,31947,30112,28289,26482,24694,22929,21189,19478,17799,
      16155,14548,12980,11455,9975,8540,7154,5818,4533,3300,
      2122,998,-70,-1082,-2037,-2935,-3776,-4561,-5288,-5959,
      6574,7134,7640,8092,8492,8840,9139,9389,9592,9750,
      9863,9935,9966,9959,9916,9838,9727,9585,9416,9219,
      8998,8755,8491,8209,7910,7597,7271,6935,6589,6237,
      5879,5517,5153,4788,4425,4063,3705,3351,3004,2663,
      2330,2006,1692,1388,1095,814,545,288,45,-185,
      -402,-605,-794,-970,-1131,-1280,-1414,-1535,-1644,-1739,
      -1822,-1893,-1952,-2000,2037,2063,2080,2087,2085,2075,
      2057,2032,2001,1962,1919,1870,1817,1759,1698,1634,
      1567,1498,1428,1356,1283,1210,1137,1064,991,919,
      848,779,711,645,581,519,459,401,347,294,
      244,197,153,111,72,36,2,-29,-57,-83,
      -106,-127,-146,-163,-177,-189,-200,-208,-215,-221,
      -224,-227,-228,-228,-227,-225,-222,-218,213,208,
      202,196,190,183,176,169,161,154,147,139,
      132,125,117,111,104,97,91,85,79,73,
      68,63,58,53,49,45,41,38,35,31,
      29,26,24,21,19,17,16,14,13,11,
      10,9,8,7,7,6,5,5,4,4,
      3,3,2,2,2,2,1,1,1,1,
      1,1};

I64 mp3_bitrate_tbl[15]={0,32000,40000,48000,56000,64000,80000,96000,
      112000,128000,160000,192000,224000,256000,320000};
I64 mp3_srate_tbl[3]={44100,48000,32000};

I64 mp3_sf_sizes[32]={
      0,0,0,1,0,2,0,3,3,0,1,1,1,2,1,3,
      2,1,2,2,2,3,3,1,3,2,3,3,4,2,4,3};

I64 mp3_pretab[21]={0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,3,3,3,2};

#define MP3_OK		0
#define MP3_ERR		1
#define MP3_NEED_MORE	2
#define MP3_EOF		3

#define MP3_POW2_OFS	340
#define MP3_PI		3.14159265358979

F64 mp3_dtbl[512],
    mp3_nwin[2048],
    mp3_imdctwin[144],
    mp3_cos12[72],
    mp3_cos36[648],
    mp3_cs[8],mp3_ca[8],
    mp3_is_ratios[6],
    mp3_pow2q[400],
    mp3_pow43[8207];
I64 mp3_tables_init=0;

U8 *mp3_in=0;
I64 mp3_in_size=0,mp3_in_pos=0;

I64 mp3_h_br_idx=0,mp3_h_sr_idx=0,mp3_h_pad=0,mp3_h_prot=0,
    mp3_h_mode=0,mp3_h_mode_ext=0,mp3_nch=1;

U8  mp3_si_vec[40];
I64 mp3_si_byte=0,mp3_si_bit=0;

U8  mp3_main_vec[2056];
I64 mp3_md_byte=0,mp3_md_bit=0,
    mp3_main_top=0;

I64 mp3_main_data_begin=0,
    mp3_scfsi[8],
    mp3_part23_len[4],mp3_big_values[4],mp3_global_gain[4],
    mp3_scalefac_compress[4],mp3_win_switch[4],mp3_block_type[4],
    mp3_mixed_block[4],mp3_table_select[12],mp3_subblock_gain[12],
    mp3_region0_cnt[4],mp3_region1_cnt[4],
    mp3_preflag[4],mp3_scalefac_scale[4],mp3_count1_tbl[4],mp3_count1[4];

I64 mp3_scalefac_l[84],
    mp3_scalefac_s[144];

F64 mp3_is[2304],
    mp3_store[1152],
    mp3_v[2048];

I16 mp3_pcm[2304];

U0 Mp3InitTables()
{
  I64 i,j;
  F64 ci,cval;
  if (mp3_tables_init)
    return;
  for (i=0;i<512;i++)
    mp3_dtbl[i]=mp3_dtbl_i[i]/65536.0;
  for (i=0;i<64;i++)
    for (j=0;j<32;j++)
      mp3_nwin[(i*32)+j]=Cos(((16.0+i)*((2.0*j)+1.0))*(MP3_PI/64.0));
  for (i=0;i<36;i++)
    mp3_imdctwin[i]=Sin((MP3_PI/36.0)*(i+0.5));
  for (i=0;i<18;i++)
    mp3_imdctwin[36+i]=Sin((MP3_PI/36.0)*(i+0.5));
  for (i=18;i<24;i++)
    mp3_imdctwin[36+i]=1.0;
  for (i=24;i<30;i++)
    mp3_imdctwin[36+i]=Sin((MP3_PI/12.0)*(i+0.5-18.0));
  for (i=30;i<36;i++)
    mp3_imdctwin[36+i]=0.0;
  for (i=0;i<12;i++)
    mp3_imdctwin[72+i]=Sin((MP3_PI/12.0)*(i+0.5));
  for (i=12;i<36;i++)
    mp3_imdctwin[72+i]=0.0;
  for (i=0;i<6;i++)
    mp3_imdctwin[108+i]=0.0;
  for (i=6;i<12;i++)
    mp3_imdctwin[108+i]=Sin((MP3_PI/12.0)*(i+0.5-6.0));
  for (i=12;i<18;i++)
    mp3_imdctwin[108+i]=1.0;
  for (i=18;i<36;i++)
    mp3_imdctwin[108+i]=Sin((MP3_PI/36.0)*(i+0.5));
  for (i=0;i<6;i++)
    for (j=0;j<12;j++)
      mp3_cos12[(i*12)+j]=Cos((MP3_PI/24.0)*((2.0*j)+1.0+6.0)*((2.0*i)+1.0));
  for (i=0;i<18;i++)
    for (j=0;j<36;j++)
      mp3_cos36[(i*36)+j]=Cos((MP3_PI/72.0)*((2.0*j)+1.0+18.0)*((2.0*i)+1.0));
  for (i=0;i<8;i++) {
    if (i==0) ci=-0.6;
    if (i==1) ci=-0.535;
    if (i==2) ci=-0.33;
    if (i==3) ci=-0.185;
    if (i==4) ci=-0.095;
    if (i==5) ci=-0.041;
    if (i==6) ci=-0.0142;
    if (i==7) ci=-0.0037;
    cval=1.0/Sqrt(1.0+(ci*ci));
    mp3_cs[i]=cval;
    mp3_ca[i]=ci*cval;
  }
  for (i=0;i<6;i++)
    mp3_is_ratios[i]=Tan((i*MP3_PI)/12.0);
  for (i=0;i<400;i++)
    mp3_pow2q[i]=Pow(2.0,(i-MP3_POW2_OFS)/4.0);
  for (i=0;i<8207;i++)
    mp3_pow43[i]=Pow(i,4.0/3.0);
  mp3_tables_init=1;
}

U0 Mp3Reset(U8 *data,I64 size)
{
  I64 i;
  Mp3InitTables();
  mp3_in=data;
  mp3_in_size=size;
  mp3_in_pos=0;
  mp3_main_top=0;
  mp3_md_byte=0;
  mp3_md_bit=0;
  mp3_nch=1;
  for (i=0;i<2304;i++)
    mp3_is[i]=0.0;
  for (i=0;i<1152;i++)
    mp3_store[i]=0.0;
  for (i=0;i<2048;i++)
    mp3_v[i]=0.0;
  for (i=0;i<84;i++)
    mp3_scalefac_l[i]=0;
  for (i=0;i<144;i++)
    mp3_scalefac_s[i]=0;
  if ((size>10) && (data[0]==0x49) && (data[1]==0x44) && (data[2]==0x33)) {
    i=((data[6]&0x7F)<<21)|((data[7]&0x7F)<<14)|((data[8]&0x7F)<<7)|(data[9]&0x7F);
    mp3_in_pos=10+i;
    if (mp3_in_pos>size)
      mp3_in_pos=size;
  }
}

I64 Mp3GetByte()
{
  I64 v;
  if (mp3_in_pos>=mp3_in_size)
    return -1;
  v=mp3_in[mp3_in_pos];
  mp3_in_pos=mp3_in_pos+1;
  return v;
}

I64 Mp3ReadHeader()
{
  I64 b1,b2,b3,b4,hdr,id,layer,br,sr;
  b1=Mp3GetByte();
  b2=Mp3GetByte();
  b3=Mp3GetByte();
  b4=Mp3GetByte();
  if ((b1<0)||(b2<0)||(b3<0)||(b4<0))
    return MP3_EOF;
  while (1) {
    hdr=(b1<<24)|(b2<<16)|(b3<<8)|b4;
    if ((hdr&0xFFF00000)==0xFFF00000) {
      id   =(hdr&0x00080000)>>19;
      layer=(hdr&0x00060000)>>17;
      br   =(hdr&0x0000F000)>>12;
      sr   =(hdr&0x00000C00)>>10;
      if ((id==1)&&(layer==1)&&(br>0)&&(br<15)&&(sr<3)) {
        mp3_h_br_idx  =br;
        mp3_h_sr_idx  =sr;
        mp3_h_prot    =(hdr&0x00010000)>>16;
        mp3_h_pad     =(hdr&0x00000200)>>9;
        mp3_h_mode    =(hdr&0x000000C0)>>6;
        mp3_h_mode_ext=(hdr&0x00000030)>>4;
        if (mp3_h_mode==3)
          mp3_nch=1;
        else
          mp3_nch=2;
        return MP3_OK;
      }
    }
    b1=b2;
    b2=b3;
    b3=b4;
    b4=Mp3GetByte();
    if (b4<0)
      return MP3_EOF;
  }
}

I64 Mp3FrameSize()
{
  return ((144*mp3_bitrate_tbl[mp3_h_br_idx])/mp3_srate_tbl[mp3_h_sr_idx])+
        mp3_h_pad;
}

I64 Mp3SideBits(I64 n)
{
  I64 tmp;
  if (!n)
    return 0;
  tmp=(mp3_si_vec[mp3_si_byte]<<24)|(mp3_si_vec[mp3_si_byte+1]<<16)|
      (mp3_si_vec[mp3_si_byte+2]<<8)|mp3_si_vec[mp3_si_byte+3];
  tmp=(tmp<<mp3_si_bit)&0xFFFFFFFF;
  tmp=tmp>>(32-n);
  mp3_si_byte=mp3_si_byte+((mp3_si_bit+n)>>3);
  mp3_si_bit=(mp3_si_bit+n)&7;
  return tmp;
}

I64 Mp3MainBit()
{
  I64 tmp;
  tmp=(mp3_main_vec[mp3_md_byte]>>(7-mp3_md_bit))&1;
  mp3_md_byte=mp3_md_byte+((mp3_md_bit+1)>>3);
  mp3_md_bit=(mp3_md_bit+1)&7;
  return tmp;
}

I64 Mp3MainBits(I64 n)
{
  I64 tmp;
  if (!n)
    return 0;
  tmp=(mp3_main_vec[mp3_md_byte]<<24)|(mp3_main_vec[mp3_md_byte+1]<<16)|
      (mp3_main_vec[mp3_md_byte+2]<<8)|mp3_main_vec[mp3_md_byte+3];
  tmp=(tmp<<mp3_md_bit)&0xFFFFFFFF;
  tmp=tmp>>(32-n);
  mp3_md_byte=mp3_md_byte+((mp3_md_bit+n)>>3);
  mp3_md_bit=(mp3_md_bit+n)&7;
  return tmp;
}

I64 Mp3MainPos()
{
  return (mp3_md_byte*8)+mp3_md_bit;
}

U0 Mp3SetMainPos(I64 bit_pos)
{
  mp3_md_byte=bit_pos>>3;
  mp3_md_bit=bit_pos&7;
}

I64 Mp3ReadSideInfo()
{
  I64 i,ch,gr,g2c,region,window,scfsi_band,si_size,v;
  if (mp3_nch==1)
    si_size=17;
  else
    si_size=32;
  for (i=0;i<si_size;i++) {
    v=Mp3GetByte();
    if (v<0)
      return MP3_EOF;
    mp3_si_vec[i]=v;
  }
  mp3_si_vec[si_size]=0;
  mp3_si_vec[si_size+1]=0;
  mp3_si_vec[si_size+2]=0;
  mp3_si_byte=0;
  mp3_si_bit=0;
  mp3_main_data_begin=Mp3SideBits(9);
  if (mp3_nch==1)
    Mp3SideBits(5);
  else
    Mp3SideBits(3);
  for (ch=0;ch<mp3_nch;ch++)
    for (scfsi_band=0;scfsi_band<4;scfsi_band++)
      mp3_scfsi[(ch*4)+scfsi_band]=Mp3SideBits(1);
  for (gr=0;gr<2;gr++) {
    for (ch=0;ch<mp3_nch;ch++) {
      g2c=(gr*2)+ch;
      mp3_part23_len[g2c]       =Mp3SideBits(12);
      mp3_big_values[g2c]       =Mp3SideBits(9);
      mp3_global_gain[g2c]      =Mp3SideBits(8);
      mp3_scalefac_compress[g2c]=Mp3SideBits(4);
      mp3_win_switch[g2c]       =Mp3SideBits(1);
      if (mp3_win_switch[g2c]) {
        mp3_block_type[g2c] =Mp3SideBits(2);
        mp3_mixed_block[g2c]=Mp3SideBits(1);
        for (region=0;region<2;region++)
          mp3_table_select[(g2c*3)+region]=Mp3SideBits(5);
        mp3_table_select[(g2c*3)+2]=0;
        for (window=0;window<3;window++)
          mp3_subblock_gain[(g2c*3)+window]=Mp3SideBits(3);
        if ((mp3_block_type[g2c]==2)&&(mp3_mixed_block[g2c]==0))
          mp3_region0_cnt[g2c]=8;
        else
          mp3_region0_cnt[g2c]=7;
        mp3_region1_cnt[g2c]=20-mp3_region0_cnt[g2c];
      } else {
        for (region=0;region<3;region++)
          mp3_table_select[(g2c*3)+region]=Mp3SideBits(5);
        mp3_region0_cnt[g2c]=Mp3SideBits(4);
        mp3_region1_cnt[g2c]=Mp3SideBits(3);
        mp3_block_type[g2c]=0;
        mp3_mixed_block[g2c]=0;
        for (window=0;window<3;window++)
          mp3_subblock_gain[(g2c*3)+window]=0;
      }
      mp3_preflag[g2c]       =Mp3SideBits(1);
      mp3_scalefac_scale[g2c]=Mp3SideBits(1);
      mp3_count1_tbl[g2c]    =Mp3SideBits(1);
    }
  }
  return MP3_OK;
}

I64 Mp3AssembleMainData(I64 main_data_size)
{
  I64 i,v,start;
  if (mp3_main_data_begin>mp3_main_top) {
    for (i=0;i<main_data_size;i++) {
      v=Mp3GetByte();
      if (v<0)
        return MP3_EOF;
      mp3_main_vec[mp3_main_top+i]=v;
    }
    mp3_main_top=mp3_main_top+main_data_size;
    if (mp3_main_top>511) {
      start=mp3_main_top-511;
      for (i=0;i<511;i++)
        mp3_main_vec[i]=mp3_main_vec[start+i];
      mp3_main_top=511;
    }
    mp3_md_byte=0;
    mp3_md_bit=0;
    return MP3_NEED_MORE;
  }
  start=mp3_main_top-mp3_main_data_begin;
  for (i=0;i<mp3_main_data_begin;i++)
    mp3_main_vec[i]=mp3_main_vec[start+i];
  for (i=0;i<main_data_size;i++) {
    v=Mp3GetByte();
    if (v<0)
      return MP3_EOF;
    mp3_main_vec[mp3_main_data_begin+i]=v;
  }
  mp3_main_top=mp3_main_data_begin+main_data_size;
  mp3_main_vec[mp3_main_top]=0;
  mp3_main_vec[mp3_main_top+1]=0;
  mp3_main_vec[mp3_main_top+2]=0;
  mp3_md_byte=0;
  mp3_md_bit=0;
  return MP3_OK;
}

U0 Mp3ReadScalefactors(I64 gr,I64 ch)
{
  I64 g2c,sfb,win,nbits,slen1,slen2,sb,sb0;
  g2c=(gr*2)+ch;
  sb0=g2c*21;
  sb=(g2c*12)*3;
  slen1=mp3_sf_sizes[(mp3_scalefac_compress[g2c]*2)];
  slen2=mp3_sf_sizes[(mp3_scalefac_compress[g2c]*2)+1];
  if (mp3_win_switch[g2c]&&(mp3_block_type[g2c]==2)) {
    if (mp3_mixed_block[g2c]) {
      for (sfb=0;sfb<8;sfb++)
        mp3_scalefac_l[sb0+sfb]=Mp3MainBits(slen1);
      for (sfb=3;sfb<12;sfb++) {
        if (sfb<6)
          nbits=slen1;
        else
          nbits=slen2;
        for (win=0;win<3;win++)
          mp3_scalefac_s[sb+(sfb*3)+win]=Mp3MainBits(nbits);
      }
    } else {
      for (sfb=0;sfb<12;sfb++) {
        if (sfb<6)
          nbits=slen1;
        else
          nbits=slen2;
        for (win=0;win<3;win++)
          mp3_scalefac_s[sb+(sfb*3)+win]=Mp3MainBits(nbits);
      }
    }
  } else {
    if ((mp3_scfsi[(ch*4)]==0)||(gr==0)) {
      for (sfb=0;sfb<6;sfb++)
        mp3_scalefac_l[sb0+sfb]=Mp3MainBits(slen1);
    } else {
      for (sfb=0;sfb<6;sfb++)
        mp3_scalefac_l[sb0+sfb]=mp3_scalefac_l[(ch*21)+sfb];
    }
    if ((mp3_scfsi[(ch*4)+1]==0)||(gr==0)) {
      for (sfb=6;sfb<11;sfb++)
        mp3_scalefac_l[sb0+sfb]=Mp3MainBits(slen1);
    } else {
      for (sfb=6;sfb<11;sfb++)
        mp3_scalefac_l[sb0+sfb]=mp3_scalefac_l[(ch*21)+sfb];
    }
    if ((mp3_scfsi[(ch*4)+2]==0)||(gr==0)) {
      for (sfb=11;sfb<16;sfb++)
        mp3_scalefac_l[sb0+sfb]=Mp3MainBits(slen2);
    } else {
      for (sfb=11;sfb<16;sfb++)
        mp3_scalefac_l[sb0+sfb]=mp3_scalefac_l[(ch*21)+sfb];
    }
    if ((mp3_scfsi[(ch*4)+3]==0)||(gr==0)) {
      for (sfb=16;sfb<21;sfb++)
        mp3_scalefac_l[sb0+sfb]=Mp3MainBits(slen2);
    } else {
      for (sfb=16;sfb<21;sfb++)
        mp3_scalefac_l[sb0+sfb]=mp3_scalefac_l[(ch*21)+sfb];
    }
  }
}

I64 mp3_huf_x=0,mp3_huf_y=0,mp3_huf_v=0,mp3_huf_w=0;

U0 Mp3HuffmanDecode(I64 tbl)
{
  I64 point,bitsleft,tlen,linbits,base,entry,x,y;
  point=0;
  bitsleft=32;
  tlen=mp3_huff_len[tbl];
  linbits=mp3_huff_linbits[tbl];
  mp3_huf_x=0;
  mp3_huf_y=0;
  mp3_huf_v=0;
  mp3_huf_w=0;
  if (!tlen)
    return;
  base=mp3_huff_off[tbl];
  while (1) {
    entry=mp3_huff[base+point];
    if ((entry&0xFF00)==0) {
      mp3_huf_x=(entry>>4)&15;
      mp3_huf_y=entry&15;
      break;
    }
    if (Mp3MainBit()) {
      while ((point<tlen)&&((mp3_huff[base+point]&0xFF)>=250))
        point=point+(mp3_huff[base+point]&0xFF);
      if (point>=tlen)
        break;
      point=point+(mp3_huff[base+point]&0xFF);
    } else {
      while ((point<tlen)&&((mp3_huff[base+point]>>8)>=250))
        point=point+(mp3_huff[base+point]>>8);
      if (point>=tlen)
        break;
      point=point+(mp3_huff[base+point]>>8);
    }
    bitsleft=bitsleft-1;
    if ((bitsleft<=0)||(point>=tlen))
      break;
  }
  if (tbl>31) {
    y=mp3_huf_y;
    mp3_huf_v=(y>>3)&1;
    mp3_huf_w=(y>>2)&1;
    mp3_huf_x=(y>>1)&1;
    mp3_huf_y=y&1;
    if (mp3_huf_v) {
      if (Mp3MainBit())
        mp3_huf_v=-mp3_huf_v;
    }
    if (mp3_huf_w) {
      if (Mp3MainBit())
        mp3_huf_w=-mp3_huf_w;
    }
    if (mp3_huf_x) {
      if (Mp3MainBit())
        mp3_huf_x=-mp3_huf_x;
    }
    if (mp3_huf_y) {
      if (Mp3MainBit())
        mp3_huf_y=-mp3_huf_y;
    }
  } else {
    x=mp3_huf_x;
    y=mp3_huf_y;
    if (linbits&&(x==15))
      x=x+Mp3MainBits(linbits);
    if (x) {
      if (Mp3MainBit())
        x=-x;
    }
    if (linbits&&(y==15))
      y=y+Mp3MainBits(linbits);
    if (y) {
      if (Mp3MainBit())
        y=-y;
    }
    mp3_huf_x=x;
    mp3_huf_y=y;
  }
}

U0 Mp3ReadHuffman(I64 part_2_start,I64 gr,I64 ch)
{
  I64 g2c,bit_pos_end,region_1_start,region_2_start,is_pos,tbl,sb,sfl,r2;
  g2c=(gr*2)+ch;
  sb=g2c*576;
  sfl=mp3_h_sr_idx*23;
  if (mp3_part23_len[g2c]==0) {
    for (is_pos=0;is_pos<576;is_pos++)
      mp3_is[sb+is_pos]=0.0;
    mp3_count1[g2c]=0;
    return;
  }
  bit_pos_end=(part_2_start+mp3_part23_len[g2c])-1;
  if (mp3_win_switch[g2c]&&(mp3_block_type[g2c]==2)) {
    region_1_start=36;
    region_2_start=576;
  } else {
    region_1_start=mp3_sfb_l[sfl+mp3_region0_cnt[g2c]+1];
    r2=mp3_region0_cnt[g2c]+mp3_region1_cnt[g2c]+2;
    if (r2>22)
      r2=22;
    region_2_start=mp3_sfb_l[sfl+r2];
  }
  for (is_pos=0;is_pos<(mp3_big_values[g2c]*2);is_pos++) {
    if (is_pos<region_1_start)
      tbl=mp3_table_select[(g2c*3)];
    else {
      if (is_pos<region_2_start)
        tbl=mp3_table_select[(g2c*3)+1];
      else
        tbl=mp3_table_select[(g2c*3)+2];
    }
    Mp3HuffmanDecode(tbl);
    mp3_is[sb+is_pos]=mp3_huf_x;
    is_pos=is_pos+1;
    mp3_is[sb+is_pos]=mp3_huf_y;
  }
  tbl=mp3_count1_tbl[g2c]+32;
  is_pos=mp3_big_values[g2c]*2;
  while ((is_pos<=572)&&(Mp3MainPos()<=bit_pos_end)) {
    Mp3HuffmanDecode(tbl);
    mp3_is[sb+is_pos]=mp3_huf_v;
    is_pos=is_pos+1;
    if (is_pos>=576)
      break;
    mp3_is[sb+is_pos]=mp3_huf_w;
    is_pos=is_pos+1;
    if (is_pos>=576)
      break;
    mp3_is[sb+is_pos]=mp3_huf_x;
    is_pos=is_pos+1;
    if (is_pos>=576)
      break;
    mp3_is[sb+is_pos]=mp3_huf_y;
    is_pos=is_pos+1;
  }
  if (Mp3MainPos()>(bit_pos_end+1))
    is_pos=is_pos-4;
  if (is_pos<0)
    is_pos=0;
  mp3_count1[g2c]=is_pos;
  while (is_pos<576) {
    mp3_is[sb+is_pos]=0.0;
    is_pos=is_pos+1;
  }
  Mp3SetMainPos(bit_pos_end+1);
}

F64 Mp3Pow43(F64 fv)
{
  I64 iv;
  F64 s;
  s=1.0;
  if (fv<0.0) {
    s=-1.0;
    fv=-fv;
  }
  iv=Floor(fv+0.5);
  if (iv>8206)
    iv=8206;
  return s*mp3_pow43[iv];
}

U0 Mp3RequantizeLong(I64 gr,I64 ch,I64 is_pos,I64 sfb)
{
  I64 g2c,q,scf,pf,sfm4;
  g2c=(gr*2)+ch;
  scf=0;
  pf=0;
  if (sfb<21) {
    scf=mp3_scalefac_l[(g2c*21)+sfb];
    pf=mp3_preflag[g2c]*mp3_pretab[sfb];
  }
  if (mp3_scalefac_scale[g2c])
    sfm4=4;
  else
    sfm4=2;
  q=(mp3_global_gain[g2c]-210)-(sfm4*(scf+pf));
  q=q+MP3_POW2_OFS;
  if (q<0)
    q=0;
  if (q>399)
    q=399;
  mp3_is[(g2c*576)+is_pos]=mp3_pow2q[q]*Mp3Pow43(mp3_is[(g2c*576)+is_pos]);
}

U0 Mp3RequantizeShort(I64 gr,I64 ch,I64 is_pos,I64 sfb,I64 win)
{
  I64 g2c,q,scf,sfm4;
  g2c=(gr*2)+ch;
  scf=0;
  if (sfb<12)
    scf=mp3_scalefac_s[((g2c*12)+sfb)*3+win];
  if (mp3_scalefac_scale[g2c])
    sfm4=4;
  else
    sfm4=2;
  q=(mp3_global_gain[g2c]-210)-(8*mp3_subblock_gain[(g2c*3)+win])-(sfm4*scf);
  q=q+MP3_POW2_OFS;
  if (q<0)
    q=0;
  if (q>399)
    q=399;
  mp3_is[(g2c*576)+is_pos]=mp3_pow2q[q]*Mp3Pow43(mp3_is[(g2c*576)+is_pos]);
}

U0 Mp3Requantize(I64 gr,I64 ch)
{
  I64 g2c,sfb,next_sfb,i,j,win,win_len,sfl,sfs;
  g2c=(gr*2)+ch;
  sfl=mp3_h_sr_idx*23;
  sfs=mp3_h_sr_idx*14;
  if (mp3_win_switch[g2c]&&(mp3_block_type[g2c]==2)) {
    if (mp3_mixed_block[g2c]) {
      sfb=0;
      next_sfb=mp3_sfb_l[sfl+sfb+1];
      for (i=0;i<36;i++) {
        if (i==next_sfb) {
          sfb=sfb+1;
          next_sfb=mp3_sfb_l[sfl+sfb+1];
        }
        Mp3RequantizeLong(gr,ch,i,sfb);
      }
      sfb=3;
      next_sfb=mp3_sfb_s[sfs+sfb+1]*3;
      win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
      i=36;
      while (i<mp3_count1[g2c]) {
        if (i==next_sfb) {
          sfb=sfb+1;
          next_sfb=mp3_sfb_s[sfs+sfb+1]*3;
          win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
        }
        for (win=0;win<3;win++)
          for (j=0;j<win_len;j++) {
            Mp3RequantizeShort(gr,ch,i,sfb,win);
            i=i+1;
          }
      }
    } else {
      sfb=0;
      next_sfb=mp3_sfb_s[sfs+sfb+1]*3;
      win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
      i=0;
      while (i<mp3_count1[g2c]) {
        if (i==next_sfb) {
          sfb=sfb+1;
          next_sfb=mp3_sfb_s[sfs+sfb+1]*3;
          win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
        }
        for (win=0;win<3;win++)
          for (j=0;j<win_len;j++) {
            Mp3RequantizeShort(gr,ch,i,sfb,win);
            i=i+1;
          }
      }
    }
  } else {
    sfb=0;
    next_sfb=mp3_sfb_l[sfl+sfb+1];
    for (i=0;i<mp3_count1[g2c];i++) {
      if (i==next_sfb) {
        sfb=sfb+1;
        if (sfb<22)
          next_sfb=mp3_sfb_l[sfl+sfb+1];
        else
          next_sfb=576;
      }
      Mp3RequantizeLong(gr,ch,i,sfb);
    }
  }
}

U0 Mp3Reorder(I64 gr,I64 ch)
{
  I64 g2c,sb,sfb,next_sfb,win_len,i,j,win,sfs;
  F64 re[576];
  g2c=(gr*2)+ch;
  sb=g2c*576;
  sfs=mp3_h_sr_idx*14;
  if (!(mp3_win_switch[g2c]&&(mp3_block_type[g2c]==2)))
    return;
  if (mp3_mixed_block[g2c]) {
    sfb=3;
    i=36;
  } else {
    sfb=0;
    i=0;
  }
  next_sfb=mp3_sfb_s[sfs+sfb+1]*3;
  win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
  while (i<576) {
    if (i==next_sfb) {
      for (j=0;j<(3*win_len);j++)
        mp3_is[sb+(3*mp3_sfb_s[sfs+sfb])+j]=re[j];
      if (i>=mp3_count1[g2c])
        return;
      sfb=sfb+1;
      next_sfb=mp3_sfb_s[sfs+sfb+1]*3;
      win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
    }
    for (win=0;win<3;win++)
      for (j=0;j<win_len;j++) {
        re[(j*3)+win]=mp3_is[sb+i];
        i=i+1;
      }
  }
  for (j=0;j<(3*win_len);j++)
    mp3_is[sb+(3*mp3_sfb_s[sfs+12])+j]=re[j];
}

U0 Mp3IntensityLong(I64 gr,I64 sfb)
{
  I64 is_pos,sfb_start,sfb_stop,i,sfl;
  F64 rl,rr,left,right;
  sfl=mp3_h_sr_idx*23;
  is_pos=mp3_scalefac_l[(gr*2)*21+sfb];
  if (is_pos==7)
    return;
  sfb_start=mp3_sfb_l[sfl+sfb];
  sfb_stop=mp3_sfb_l[sfl+sfb+1];
  if (is_pos==6) {
    rl=1.0;
    rr=0.0;
  } else {
    rl=mp3_is_ratios[is_pos]/(1.0+mp3_is_ratios[is_pos]);
    rr=1.0/(1.0+mp3_is_ratios[is_pos]);
  }
  for (i=sfb_start;i<sfb_stop;i++) {
    left=rl*mp3_is[(gr*2)*576+i];
    right=rr*mp3_is[(gr*2)*576+i];
    mp3_is[((gr*2)*576)+i]=left;
    mp3_is[(((gr*2)+1)*576)+i]=right;
  }
}

U0 Mp3IntensityShort(I64 gr,I64 sfb)
{
  I64 is_pos,sfb_start,sfb_stop,i,win,win_len,sfs;
  F64 rl,rr,left,right;
  sfs=mp3_h_sr_idx*14;
  win_len=mp3_sfb_s[sfs+sfb+1]-mp3_sfb_s[sfs+sfb];
  for (win=0;win<3;win++) {
    is_pos=mp3_scalefac_s[(((gr*2)*12)+sfb)*3+win];
    if (is_pos!=7) {
      sfb_start=(mp3_sfb_s[sfs+sfb]*3)+(win_len*win);
      sfb_stop=sfb_start+win_len;
      if (is_pos==6) {
        rl=1.0;
        rr=0.0;
      } else {
        rl=mp3_is_ratios[is_pos]/(1.0+mp3_is_ratios[is_pos]);
        rr=1.0/(1.0+mp3_is_ratios[is_pos]);
      }
      for (i=sfb_start;i<sfb_stop;i++) {
        left=rl*mp3_is[(gr*2)*576+i];
        right=rr*mp3_is[(gr*2)*576+i];
        mp3_is[((gr*2)*576)+i]=left;
        mp3_is[(((gr*2)+1)*576)+i]=right;
      }
    }
  }
}

U0 Mp3Stereo(I64 gr)
{
  I64 i,max_pos,sfb,g0,g1,sfl,sfs;
  F64 left,right;
  if ((mp3_h_mode!=1)||(mp3_h_mode_ext==0))
    return;
  g0=(gr*2)*576;
  g1=((gr*2)+1)*576;
  if (mp3_h_mode_ext&2) {
    max_pos=mp3_count1[(gr*2)];
    if (mp3_count1[(gr*2)+1]>max_pos)
      max_pos=mp3_count1[(gr*2)+1];
    for (i=0;i<max_pos;i++) {
      left=(mp3_is[g0+i]+mp3_is[g1+i])*0.70710678118654752440;
      right=(mp3_is[g0+i]-mp3_is[g1+i])*0.70710678118654752440;
      mp3_is[g0+i]=left;
      mp3_is[g1+i]=right;
    }
  }
  if (mp3_h_mode_ext&1) {
    sfl=mp3_h_sr_idx*23;
    sfs=mp3_h_sr_idx*14;
    if (mp3_win_switch[(gr*2)]&&(mp3_block_type[(gr*2)]==2)) {
      if (mp3_mixed_block[(gr*2)]) {
        for (sfb=0;sfb<8;sfb++)
          if (mp3_sfb_l[sfl+sfb]>=mp3_count1[(gr*2)+1])
            Mp3IntensityLong(gr,sfb);
        for (sfb=3;sfb<12;sfb++)
          if ((mp3_sfb_s[sfs+sfb]*3)>=mp3_count1[(gr*2)+1])
            Mp3IntensityShort(gr,sfb);
      } else {
        for (sfb=0;sfb<12;sfb++)
          if ((mp3_sfb_s[sfs+sfb]*3)>=mp3_count1[(gr*2)+1])
            Mp3IntensityShort(gr,sfb);
      }
    } else {
      for (sfb=0;sfb<21;sfb++)
        if (mp3_sfb_l[sfl+sfb]>=mp3_count1[(gr*2)+1])
          Mp3IntensityLong(gr,sfb);
    }
  }
}

U0 Mp3Antialias(I64 gr,I64 ch)
{
  I64 g2c,sb,sblim,i,li,ui,b;
  F64 lb,ub;
  g2c=(gr*2)+ch;
  b=g2c*576;
  if (mp3_win_switch[g2c]&&(mp3_block_type[g2c]==2)&&
      (mp3_mixed_block[g2c]==0))
    return;
  if (mp3_win_switch[g2c]&&(mp3_block_type[g2c]==2)&&mp3_mixed_block[g2c])
    sblim=2;
  else
    sblim=32;
  for (sb=1;sb<sblim;sb++)
    for (i=0;i<8;i++) {
      li=((18*sb)-1)-i;
      ui=(18*sb)+i;
      lb=(mp3_is[b+li]*mp3_cs[i])-(mp3_is[b+ui]*mp3_ca[i]);
      ub=(mp3_is[b+ui]*mp3_cs[i])+(mp3_is[b+li]*mp3_ca[i]);
      mp3_is[b+li]=lb;
      mp3_is[b+ui]=ub;
    }
}

U0 Mp3IMDCTWin(F64 *in,F64 *out,I64 block_type)
{
  I64 i,m,p;
  F64 sum,tin[18];
  for (i=0;i<36;i++)
    out[i]=0.0;
  for (i=0;i<18;i++)
    tin[i]=in[i];
  if (block_type==2) {
    for (i=0;i<3;i++) {
      for (p=0;p<12;p++) {
        sum=0.0;
        for (m=0;m<6;m++)
          sum=sum+(tin[i+(3*m)]*mp3_cos12[(m*12)+p]);
        out[(6*i)+p+6]=out[(6*i)+p+6]+(sum*mp3_imdctwin[(2*36)+p]);
      }
    }
  } else {
    for (p=0;p<36;p++) {
      sum=0.0;
      for (m=0;m<18;m++)
        sum=sum+(in[m]*mp3_cos36[(m*36)+p]);
      out[p]=sum*mp3_imdctwin[(block_type*36)+p];
    }
  }
}

U0 Mp3HybridSynthesis(I64 gr,I64 ch)
{
  I64 g2c,sb,i,bt,b,st;
  F64 rawout[36];
  g2c=(gr*2)+ch;
  b=g2c*576;
  for (sb=0;sb<32;sb++) {
    if (mp3_win_switch[g2c]&&mp3_mixed_block[g2c]&&(sb<2))
      bt=0;
    else
      bt=mp3_block_type[g2c];
    Mp3IMDCTWin(&mp3_is[b+(sb*18)],rawout,bt);
    st=((ch*32)+sb)*18;
    for (i=0;i<18;i++) {
      mp3_is[b+(sb*18)+i]=rawout[i]+mp3_store[st+i];
      mp3_store[st+i]=rawout[i+18];
    }
  }
}

U0 Mp3FreqInversion(I64 gr,I64 ch)
{
  I64 b,sb,i;
  b=((gr*2)+ch)*576;
  for (sb=1;sb<32;sb=sb+2)
    for (i=1;i<18;i=i+2)
      mp3_is[b+(sb*18)+i]=0.0-mp3_is[b+(sb*18)+i];
}

U0 Mp3SubbandSynthesis(I64 gr,I64 ch)
{
  I64 g2c,i,j,ss,samp,vb;
  F64 sum,t,u_vec[512],s_vec[32];
  g2c=(gr*2)+ch;
  vb=ch*1024;
  for (ss=0;ss<18;ss++) {
    for (i=1023;i>63;i--)
      mp3_v[vb+i]=mp3_v[vb+i-64];
    for (i=0;i<32;i++)
      s_vec[i]=mp3_is[(g2c*576)+(i*18)+ss];
    for (i=0;i<64;i++) {
      sum=0.0;
      for (j=0;j<32;j++)
        sum=sum+(mp3_nwin[(i*32)+j]*s_vec[j]);
      mp3_v[vb+i]=sum;
    }
    for (i=0;i<8;i++)
      for (j=0;j<32;j++) {
        u_vec[(i*64)+j]   =mp3_v[vb+(i*128)+j];
        u_vec[(i*64)+j+32]=mp3_v[vb+(i*128)+j+96];
      }
    for (i=0;i<512;i++)
      u_vec[i]=u_vec[i]*mp3_dtbl[i];
    for (i=0;i<32;i++) {
      sum=0.0;
      for (j=0;j<16;j++)
        sum=sum+u_vec[(j*32)+i];
      t=sum*32767.0;
      samp=Floor(t+0.5);
      if (samp>32767)
        samp=32767;
      if (samp<-32768)
        samp=-32768;
      mp3_pcm[(((gr*576)+(32*ss)+i)*mp3_nch)+ch]=samp;
    }
  }
}

I64 Mp3DecodeGranules()
{
  I64 gr,ch;
  for (gr=0;gr<2;gr++) {
    for (ch=0;ch<mp3_nch;ch++) {
      Mp3Requantize(gr,ch);
      Mp3Reorder(gr,ch);
    }
    Mp3Stereo(gr);
    for (ch=0;ch<mp3_nch;ch++) {
      Mp3Antialias(gr,ch);
      Mp3HybridSynthesis(gr,ch);
      Mp3FreqInversion(gr,ch);
      Mp3SubbandSynthesis(gr,ch);
    }
  }
  return 1152;
}

I64 Mp3NextFrame()
{
  I64 r,gr,ch,g2c,part_2_start,main_data_size;
  while (1) {
    r=Mp3ReadHeader();
    if (r==MP3_EOF)
      return -1;
    if (mp3_h_prot==0) {
      if (Mp3GetByte()<0)
        return -1;
      if (Mp3GetByte()<0)
        return -1;
    }
    r=Mp3ReadSideInfo();
    if (r==MP3_EOF)
      return -1;
    main_data_size=Mp3FrameSize()-4;
    if (mp3_nch==1)
      main_data_size=main_data_size-17;
    else
      main_data_size=main_data_size-32;
    if (mp3_h_prot==0)
      main_data_size=main_data_size-2;
    if ((main_data_size>=0)&&(main_data_size<=1728)) {
      r=Mp3AssembleMainData(main_data_size);
      if (r==MP3_EOF)
        return -1;
      if (r==MP3_NEED_MORE)
        return 0;
      for (gr=0;gr<2;gr++)
        for (ch=0;ch<mp3_nch;ch++) {
          g2c=(gr*2)+ch;
          if (mp3_big_values[g2c]>288)
            return 0;
          if ((mp3_part23_len[g2c]>0)&&(mp3_win_switch[g2c])&&
              (mp3_block_type[g2c]==0))
            return 0;
        }
      for (gr=0;gr<2;gr++)
        for (ch=0;ch<mp3_nch;ch++) {
          g2c=(gr*2)+ch;
          part_2_start=Mp3MainPos();
          if ((part_2_start+mp3_part23_len[g2c])>(mp3_main_top*8))
            return 0;
          Mp3ReadScalefactors(gr,ch);
          Mp3ReadHuffman(part_2_start,gr,ch);
        }
      return Mp3DecodeGranules();
    }
  }
}



#help_index "Snd/MP3"

F64 mp3_gain=1.0;

I16 *mp3_song=NULL;
I64 mp3_song_samps=0,
    mp3_song_ch=1,
    mp3_song_hz=44100,
    mp3_play_pos=0,
    mp3_play_step=0;
Bool mp3_playing=FALSE;

I64 mp3_mixer_idx=-1;
Bool mp3_verbose=TRUE;

U0 MP3FillBuf(SND_OUT_CONTAINER *buf,I64)
{
  I64 j,l,c,idx,samp,t;
  F64 frac,s0,s1,s;
  MemSet(buf,0,SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
  if (!mp3_playing)
    return;
  j=0;
  while (j<SND_BUF_LEN) {
    idx=mp3_play_pos>>32;
    if (idx+1>=mp3_song_samps) {
      mp3_playing=FALSE;
      break;
    }
    frac=(mp3_play_pos&0xFFFFFFFF)/4294967296.0;
    for (l=0;l<SND_OCHANNELS;l++) {
      c=l;
      if (mp3_song_ch==1)
	c=0;
      s0=mp3_song[idx*mp3_song_ch+c];
      s1=mp3_song[(idx+1)*mp3_song_ch+c];
      s=(s0+(s1-s0)*frac)/32768.0;
      samp=ToI64(Clamp(s*snd_vol*mp3_gain,-1.0,1.0)*I32_MAX)&~0xFF;
      t=buf[j]+samp;
      if (t>I32_MAX)
	t=I32_MAX;
      if (t<I32_MIN)
	t=I32_MIN;
      buf[j]=t;
      j++;
    }
    mp3_play_pos+=mp3_play_step;
  }
}

public I16 *MP3Decode(U8 *data,I64 size,I64 *_samps=NULL,I64 *_hz=NULL,
	I64 *_nch=NULL)
{
  I16 *out,*out2;
  I64 n,i,total=0,cap=0x200000,frames=0;
  out=AMAlloc(cap*sizeof(I16));
  Mp3Reset(data,size);
  n=Mp3NextFrame;
  while (n>=0) {
    if (n>0) {
      if ((total+n)*mp3_nch>cap) {
	cap*=2;
	out2=AMAlloc(cap*sizeof(I16));
	MemCpy(out2,out,total*mp3_nch*sizeof(I16));
	Free(out);
	out=out2;
      }
      for (i=0;i<n*mp3_nch;i++)
	out[total*mp3_nch+i]=mp3_pcm[i];
      total+=n;
    }
    frames++;
    if (!(frames&127) && mp3_verbose)
      ".";
    n=Mp3NextFrame;
  }
  if (!total) {
    Free(out);
    return NULL;
  }
  if (_samps)
    *_samps=total;
  if (_hz)
    *_hz=mp3_srate_tbl[mp3_h_sr_idx];
  if (_nch)
    *_nch=mp3_nch;
  return out;
}

public U0 MP3Stop()
{
  mp3_playing=FALSE;
  Sleep(3*SND_BUF_TIME_mS);
  Free(mp3_song);
  mp3_song=NULL;
}

public Bool MP3Busy()
{
  return mp3_playing;
}

public U0 MP3Wait()
{
  while (mp3_playing)
    Sleep(20);
}

public Bool MP3Play(U8 *filename,Bool bkg=TRUE,Bool verbose=TRUE)
{
  U8 *raw;
  I16 *pcm;
  I64 size,samps,hz,nch;
  if (mp3_mixer_idx<0) {
    if (verbose)
      "MP3: not installed -- bring up HD Audio and HDMixer first.\n";
    return FALSE;
  }
  raw=FileRead(filename,&size);
  if (!raw) {
    if (verbose)
      "MP3: can't read %s\n",filename;
    return FALSE;
  }
  mp3_verbose=verbose;
  if (verbose)
    "MP3: decoding %s ",filename;
  pcm=MP3Decode(raw,size,&samps,&hz,&nch);
  Free(raw);
  mp3_verbose=TRUE;
  if (!pcm) {
    if (verbose)
      " no MPEG-1 Layer III frames found.\n";
    return FALSE;
  }
  if (verbose)
    " %d.%03d sec @ %dHz %dch\n",samps/hz,(samps%hz)*1000/hz,hz,nch;
  MP3Stop;
  mp3_song_samps=samps;
  mp3_song_ch=nch;
  mp3_song_hz=hz;
  mp3_play_pos=0;
  mp3_play_step=(hz<<32)/SND_SAMPLE_RATE;
  mp3_song=pcm;
  mp3_playing=TRUE;
  if (!bkg)
    MP3Wait;
  return TRUE;
}

U0 MP3Install()
{
  Mp3InitTables;
  mp3_mixer_idx=MixerRegister("MP3",&MP3FillBuf);
}

if (snd_dev==SD_HD_AUDIO) {
  MP3Install;
  "MP3 module loaded.\n";
} else
  "MP3: needs HD Audio + Mixer.\n";

#help_index ""
