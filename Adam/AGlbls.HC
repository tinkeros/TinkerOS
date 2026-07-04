#help_index "DolDoc/Clip"

CDoc *sys_clip_doc=NULL;

#help_index "AutoComplete"

#define ACf_INIT_IN_PROGRESS    0
#define AC_FILLINS_NUM 10

public class CAutoCompleteGlbls
{
  I64   num_words;
  CHashTable *hash_table;
  U8    *cur_word;
  I64   flags;
  CTask *task;
  I64   partial_len,num_fillins,
        fillin_hits     [AC_FILLINS_NUM+1];
  CHashAC *fillin_matches[AC_FILLINS_NUM+1];
} ac;

ZeroClass(&ac);

#help_index ""
