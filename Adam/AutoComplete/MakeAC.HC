//See $LK,"::/Doc/AutoComplete.DD"$
Cd(__DIR__);;
#define AC_HISTORY_MAX 20
Bool ac_show_history=FALSE;
Bool ac_history_dirty=TRUE;
I64  ac_history_cnt=0;
U8  *ac_history_items[AC_HISTORY_MAX];
// TODO deprecate ACFill?
//#include "ACFill"
#include "ACGlbls"
#include "ACFillLite"
#include "ACTask"
Cd("..");;
