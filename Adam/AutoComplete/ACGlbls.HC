#help_index "AutoComplete/Dictionary"
#define ACD_WORD_FILENAME       "/Adam/AutoComplete/ACWords.DATA.Z"
#define ACD_DEF_FILENAME        "/Adam/AutoComplete/ACDefs.DATA"
#define ACD_DEF_FILENAME_Z      "/Adam/AutoComplete/ACDefs.DATA.Z"

#define ACD_H1                  0
#define ACD_H1_END              1
#define ACD_DEF                 2
#define ACD_DEF_END             3
#define ACD_PRONUNCIATION       4
#define ACD_PRONUNCIATION_END   5
#define ACD_POS                 6
#define ACD_POS_END             7
#define ACD_EXTRA               8
#define ACD_EXTRA_END           9
#define ACD_BLK_SIZE            0x4000

#define ACD_END_CHAR            0x00
#define ACD_WORD_CHAR           0x01
#define ACD_DEF_CHAR            0x02
#define ACD_PRONUNCIATION_CHAR  0x03
#define ACD_POS_CHAR            0x04
#define ACD_EXTRA_CHAR          0x05

#define ACD_FILLINS_NUM 10
public class CAutoCompleteDictGlbls
{
  U8    *word_lst;
  I64   word_lst_size,num_words,num_fillins;
  U8    *fillins[ACD_FILLINS_NUM];
  Bool  has_words,has_defs;
} acd;

ZeroClass(&acd);

