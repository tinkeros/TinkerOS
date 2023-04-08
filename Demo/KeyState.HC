
U0 ShowKeysDown()
{
  I64 i,arg1,arg2,msg_code;
// Reset state of keys to DOWN in case some UP message were lost
  // or DOWN states were introduced into the FIFO by other means
  // non-keyboard means.
  KeyStateRst;
// Check for printable ASCII keys in key_state, for example check to
  // for 'A' use if (key_state['A'])
  //
  // Check for non-printable keys in either sc_state or sc_flags_state
  //
  // For example to check of the down arrow key use if (sc_state[SC_CURSOR_DOWN])
  //
  // Check for modifier keys such as ALT with if (SCF_ALT&sc_flags_state)
  do
  {
// Call to GetMsg below is not to get the state
    // of the keys (since multiple may be down, but
    // this message may only contain one change), but
    // instead it's purposes is to:
    //
    // 1) Consume the message (so for example SHIFT-ESC
    //    doesn't close our window when this loop exits)
    //
    // 2) Refresh the state when a message comes in
    //
    // The arrays key_state, sc_states, and variable
    // sc_flags_state update immediately reguardless of
    // if GetMsg was called or not.
    //
    msg_code=GetMsg(&arg1, &arg2,~(1<<MSG_NULL));
    DocClear;
// specific examples
    "The state of 'a' is: %B\n"
    ,key_state['a'];
    "The state of 'b' is: %B\n"
    ,key_state['b'];
    "The state of 'c' is: %B\n"
    ,key_state['c'];
    "The state of 'A' is: %B\n"
    ,key_state['A'];
    "The state of 'B' is: %B\n"
    ,key_state['B'];
    "The state of 'C' is: %B\n"
    ,key_state['C'];
    "The state of the down arrow key is: %B\n"
    ,sc_state[SC_CURSOR_DOWN];
    "The state of the up arrow key is: %B\n"
    ,sc_state[SC_CURSOR_UP];
    "The state of the ALT key is: %B\n"
    ,sc_flags_state&SCF_ALT!=0;
    "The state of the CTRL key is: %B\n"
    ,sc_flags_state&SCF_CTRL!=0;
    "The state of the SHIFT key is: %B\n"
    ,sc_flags_state&SCF_SHIFT!=0;
    "\n";
// Output all keys down as well as modifiers CTRL, ALT, and SHIFT
    "Keys down: \n\n";
    for (i=SC_ESC; i<=SC_PRTSCRN2; i++)
      if (sc_state[i])
        "%s ",ScanCode2KeyName(i);
    if (SCF_CTRL&sc_flags_state)
      "CTRL ";
    if (SCF_ALT&sc_flags_state)
      "ALT ";
    if (SCF_SHIFT&sc_flags_state)
    {
      "SHIFT ";
      if (sc_state[SC_ESC])
        return;
    }
    "\n\nPress SHIFT-ESC to quit!\n";
  }
  while (TRUE);
  FlushMsgs;
  "\n";
}


ShowKeysDown;
"\n";
