#define JSONT_INVALID   0
#define JSONT_STRING    1
#define JSONT_INTEGER   2
#define JSONT_FLOAT     3
#define JSONT_ARRAY     4
#define JSONT_BOOL      5
#define JSONT_OBJ       6
#define JSONT_NULL      7

#define JSON_HASHTABLE_SIZE 1024

#define HTT_JSON    0x00100 // identical to HTT_DICT_WORD

class CJSONDataEntry:CQue
{
  U8                 type;

  I64                int_data;
  F64                float_data;
  U8                *string_data;
  Bool           bool_data;
  CJSONDataEntry    *list_data;
  CHashTable        *hash_table;
};

class CJSONDataHash:CHash
{
  CJSONDataEntry    *data;
};

U8 **JSONKeysGet(CHashTable *table)
{
  I64         i, cnt = 0;
  CHash  *temp_hash;
  U8        **keys;
  I64         key_index = 0;
  for (i = 0; i <= table->mask; i++) // mask is table length 0-based
    if (temp_hash = table->body[i]) // if temp_hash exists
      cnt++;
  keys = CAlloc(sizeof(U8*) * cnt); // alloc string list
  for (i = 0; i <= table->mask; i++)
    if (temp_hash = table->body[i])
    {
      keys[key_index] = StrNew(temp_hash->str); // add key string to list
      key_index++;
    }
  return keys;
}

U0 JSONDataRep(CJSONDataEntry *data, I64 indent=0)
{
  U8                **keys;
  I64                 index;
  I64                 cnt;
  CJSONDataEntry     *entry;
  CJSONDataHash  *temp_hash;
  "%h*c"
  , indent, '\t';
  switch (data->type)
  {
  case JSONT_INVALID:
    "Invalid JSON.\n"
    ;
    break;
  case JSONT_STRING:
    "%s\n"
    , data->string_data;
    break;
  case JSONT_INTEGER:
    "%d\n"
    , data->int_data;
    break;
  case JSONT_FLOAT:
    "%.9f\n"
    , data->float_data;
    break;
  case JSONT_BOOL:
    "%Z\n"
    , data->bool_data, "ST_FALSE_TRUE";
    break;
  case JSONT_NULL:
    "Null.\n"
    ;
    break;
  case JSONT_ARRAY:
    "Array:\n"
    ;
    "%h*c"
    , indent, '\t';
    "[\n";
    entry = data->list_data->next; // one after head.
    while (entry != data->list_data) // head ignored, stop on head.
    {
      JSONDataRep(entry, indent + 1); // recursive Rep on the list entry
      entry = entry->next;
    }
    "%h*c", indent, '\t';
    "]\n";
    break;
  case JSONT_OBJ:
    "Object.\n"
    ;
    "%h*c"
    , indent, '\t';
    "{\n";
    keys = JSONKeysGet(data->hash_table);
    cnt = MSize(keys) / sizeof(U8*);
    for (index = 0; index < cnt; index++)
    {
      "%h*c", indent, '\t';
      "Key: %s\n"
      , keys[index];
      temp_hash = HashFind(keys[index], data->hash_table, HTT_JSON);
      JSONDataRep(temp_hash->data, indent + 1);
    }
    "%h*c", indent, '\t';
    "}\n";
    break;
  }
}

CJSONDataEntry *JSONKeyValueGet(CJSONDataEntry *data, U8 *key)
{
  U8                **keys;
  I64                 index;
  I64                 cnt;
  CJSONDataHash  *temp_hash;
  switch (data->type)
  {
  case JSONT_OBJ:
    keys = JSONKeysGet(data->hash_table);
    cnt = MSize(keys) / sizeof(U8*);
    for (index = 0; index < cnt; index++)
    {
      temp_hash = HashFind(keys[index], data->hash_table, HTT_JSON);
      if (!StrCmp(key, keys[index]) && temp_hash)
        return temp_hash->data;
    }
    break;
  default:
    break;
  }
  return NULL;
}

CJSONDataEntry *JSONIndexValueGet(CJSONDataEntry *data, U64 list_index)
{
  CJSONDataEntry    *entry;
  U64                i = 0;
  switch (data->type)
  {
  case JSONT_ARRAY:
    entry = data->list_data->next; // one after head.
    while (entry != data->list_data) // head ignored, stop on head.
    {
      if (i++ == list_index)
        return entry;
      entry = entry->next;
    }
    break;
  default:
    break;
  }
  return NULL;
}


CJSONDataEntry *JSONPrs(CCmpCtrl *cc)
{
  CJSONDataEntry    *result = CAlloc(sizeof(CJSONDataEntry));
  I64                tk, last_tk;
  Bool           is_done = FALSE;
  CJSONDataEntry    *temp_entry;
  CJSONDataHash *temp_hash = CAlloc(sizeof(CJSONDataHash));
  while (tk = Lex(cc))
  {
    switch (tk)
    {
    case '}':
      LexExcept(cc, "Expected Value, got '}'.");
    case TK_STR:
      result->type      = JSONT_STRING;
      result->string_data = StrNew(cc->cur_str);
      is_done = TRUE;
      break;
    case TK_I64: //todo, LexExcept on 0x or 0b vals.
      result->type   = JSONT_INTEGER;
      result->int_data = cc->cur_i64;
      is_done = TRUE;
      break;
    case TK_F64:
      result->type      = JSONT_FLOAT;
      result->float_data    = cc->cur_f64;
      is_done = TRUE;
      break;
    case TK_IDENT:
      if (!StrCmp(cc->cur_str, "true") ||
          !StrCmp(cc->cur_str, "false"))
      {
        result->type = JSONT_BOOL;
        if (!StrCmp(cc->cur_str, "true"))
          result->bool_data = TRUE;
        if (!StrCmp(cc->cur_str, "false"))
          result->bool_data = FALSE;
        is_done = TRUE;
      }
      if (!StrCmp(cc->cur_str, "null"))
      {
        result->type = JSONT_NULL;
        is_done = TRUE;
      }
      is_done = TRUE;
      break;
    case '[':
      result->type    = JSONT_ARRAY;
      result->list_data = CAlloc(sizeof(CJSONDataEntry));
      QueInit(result->list_data);
lex_lstitem:
      last_tk = tk;
      LexPush(cc);
      tk = Lex(cc);
      if (last_tk == ',' && tk == ']')
        LexExcept(cc, "Expected Lst value, got ']'");
      if (tk == ']')
        goto lex_lstdone;
      if (tk == ',')
        LexExcept(cc, "Expected Lst Value, got comma.");
      LexPopRestore(cc);
      temp_entry = JSONPrs(cc);
      QueIns(temp_entry, result->list_data->last);
      tk = Lex(cc);
      if (tk == ',')
        goto lex_lstitem;
lex_lstdone:
      is_done = TRUE;
      break;
    case '{':
      result->type      = JSONT_OBJ;
      result->hash_table    = HashTableNew(JSON_HASHTABLE_SIZE);
lex_objkey:
      // lex next. expect TK_STR. Mk a temp_hash.
      last_tk = tk;
      tk = Lex(cc);
      if (last_tk == ',' && tk == '}')
        LexExcept(cc, "Expected Key after comma.");
      if (tk == '}')
        goto lex_objdone;
      if (tk != TK_STR)
        LexExcept(cc, "Expected Key String.");
      temp_hash = CAlloc(sizeof(CJSONDataHash));
      // set hash type and StrNew with cc->cur_str into hash str.
      temp_hash->type = HTT_JSON;
      temp_hash->str  = StrNew(cc->cur_str);
      // lex next. expect ':'.
      tk = Lex(cc);
      if (tk != ':')
        LexExcept(cc, "Expected ':' after Key String.");
      // now expect JSONDataEntry-able value next.
      // Recursive JSONPrs into hash data member.
      temp_hash->data = JSONPrs(cc);
      // JSONPrs leaves off on the last token. e.g. int, tk will
      // still be TK_I64.
      // add hash to result hash_table.
      HashAdd(temp_hash, result->hash_table);
      // lex next. expect ',' or '}'.
      tk = Lex(cc);
      if (tk != ',' && tk != '}')
        LexExcept(cc, "Expected ',' or '}' after Object Value.");
      if (tk == ',')
        goto lex_objkey;
lex_objdone:
      is_done = TRUE;
      break;
    }
    if (is_done)
      break;
  }
  return result;
}

U0 JSONFileRep(U8 *filename)
{
  CCmpCtrl      *cc     = CmpCtrlNew(MStrPrint("#include \"%s\"", filename));
  CJSONDataEntry    *data   = JSONPrs(cc);
  JSONDataRep(data);
  ClassRep((data = JSONKeyValueGet(data, "floats")));
//  ClassRep((data = JSONIndexValueGet(data, 3)));
  CmpCtrlDel(cc);
}




"\n";
class CTestClass
{
  CTestClass    *next, *last;
  U8         field1;
  I64        field2;
  U8        *buffer;
};

CTestClass *head = CAlloc(sizeof(CTestClass));
QueInit(head); // works since CTestClass has next & last members
head->field1 = 2;
head->field2 = 1234567890; // DONT DO THIS ONLY DOING FOR DEBUG REASONS

CTestClass *test_class1 = CAlloc(sizeof(CTestClass));
CTestClass *test_class2 = CAlloc(sizeof(CTestClass));
CTestClass *test_class3 = CAlloc(sizeof(CTestClass));
QueInsRev(test_class1, head);
QueInsRev(test_class2, head);
QueInsRev(test_class3, head);

test_class1->field1 = 45;
test_class1->field2 = 123;
test_class1->buffer = MAlloc(1024);

test_class2->field1 = 11;
test_class2->field2 = -456;
test_class2->buffer = MAlloc(1024);

test_class3->field1 = 22;
test_class3->field2 = 999;
test_class3->buffer = MAlloc(1024);


CTestClass *temp_test_class = head->next;

while (temp_test_class != head)
{
  "test_class entry = field1:%d field2:%d\n", temp_test_class->field1, temp_test_class->field2;
  temp_test_class = temp_test_class->next;
}
"\n\n";

ClassRep(head);


// WIP, TODO: FIX/REWRITE this method
U8 *JSONString(U8 *obj, U8 *class_name=lastclass, Bool is_base=FALSE, Bool is_lst=FALSE,
               U8 *head=NULL)
{// convert some struct in memory to a JSON string. See $LK+PU,"ClassRep",A="MN:ClassRep2"$.
  U8            *ptr, *temp_obj;
  CMemberLst *ml;
  CHashClass    *tmpc, *tmpc2;
  I64            i, stars;
  if (!(tmpc = HashFind(class_name, Fs->hash_table, HTG_ALL)))
    return NULL;
  if (!CheckPtr(obj) || !CheckPtr(obj(U8 *) + tmpc->size))
    return NULL;
  if (tmpc->base_class)
    JSONString(obj, tmpc->base_class->str, TRUE);
  ml = tmpc->member_lst_and_root;
  if (ml && !StrCmp(ml->str, "next") && !is_base)
  {
    "[";
    is_lst = TRUE;
    tmpc2 = ml->member_class;
    stars = tmpc2->ptr_stars_cnt;
    tmpc2 = OptClassFwd(tmpc2);
    tmpc2 -= tmpc2->ptr_stars_cnt;
    ptr = obj + ml->offset;
    temp_obj = *ptr(I64 *);
    if (stars)
    {
      while (temp_obj != obj && temp_obj != NULL)
      {
        JSONString(temp_obj, tmpc2->str, TRUE);
        temp_obj = *(temp_obj + ml->offset)(I64 *);
        if (temp_obj != obj && temp_obj != NULL)
          ", ";
      }
    }
    ml = NULL;
//      ml = ml->next;
//      if (ml && !StrCmp(ml->str, "last"))
//          ml = ml->next;
  }
  else
    "{";
  while (ml)
  {
    tmpc2 = ml->member_class;
    stars = tmpc2->ptr_stars_cnt;
    tmpc2 = OptClassFwd(tmpc2);
    tmpc2 -= tmpc2->ptr_stars_cnt;
    ptr = obj + ml->offset;
    "\"%s\":"
    , ml->str;
    switch (tmpc2->raw_type)
    {
    case RT_I0:
    case RT_U0:
      break;
    case RT_I8:
    case RT_U8:
      "%d"
      , *ptr++;
      break;
    case RT_I16:
    case RT_U16:
      "%d"
      , *ptr(I16 *)++;
      break;
    case RT_I32:
    case RT_U32:
      "%d"
      , *ptr(I32 *)++;
      break;
    case RT_I64: // RT_PTR
    case RT_U64:
      "%d"
      , *ptr(I64 *)++;
      break;
    case RT_F64:
      break;
    }
    ml = ml->next;
    if (ml)
      ", ";
  }
  if (is_lst && !is_base)
    "]";
  else
    "}";
  return NULL;
}

"\n\nRESULT OF JSONString(head):\n\n";
JSONString(head);
"\n\n";





Cd(__DIR__);
JSONFileRep("JSON1.TXT");
