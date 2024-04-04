public U0 DumpAdamLog()
{// Output Adam Log to current doc/term
  DocInsDoc(DocPut,adam_task->put_doc);
}

public U0 HijackFunc(U8 *orig, U8 *new)
{// Replace a system function with a new function

    // Warning old function address is not saved and this overwrites it!
    // Assembly code of old function is patched to jump to new instead.
    // Only a reboot will restore the original function!
    PUSHFD
    CLI
    *orig=0xe9;
    *(orig+1)(U32*)=new-orig-5;
    POPFD
}
