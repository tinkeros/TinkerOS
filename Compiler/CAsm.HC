Bool Option(I64 num,Bool val)
{//Set compiler $LK,"Option",A="FI:::/Doc/Options.DD"$ to val.
  return BEqu(&Fs->last_cc->opts,num,val);
}

Bool GetOption(I64 num)
{//Get state of compiler $LK,"option",A="MN:OPTf_ECHO"$.
  return Bt(&Fs->last_cc->opts,num);
}

asm
{
  _LAST_FUN::	//See $LK,"_CALL_IND",A="MN:_CALL_IND"$
  PUSH	RBP
  MOV	RBP,RSP
  PUSH	RSI
  PUSH	RDI

  XOR	RAX,RAX
  MOV	RAX,FS:CTask.last_fun[RAX]
  TEST	RAX,RAX
  JZ	@@10
  MOV	RDX,U64 CHashFun.exe_addr[RAX]

  MOV	RCX,U64 SF_ARG1[RBP]	//argc
  MOV	RSI,U64 SF_ARG2[RBP]	//argv
  SHL	RCX,3
  SUB	RSP,RCX
  MOV	RDI,RSP
  REP_MOVSB
  TEST	RDX,RDX
  JZ	@@05

  CALL	RDX
  POP	RDI
  POP	RSI
  POP	RBP
  RET1	16

@@05:	MOV	RCX,U64 SF_ARG1[RBP]	//argc
  SHL	RCX,3
  ADD	RSP,RCX
  XOR	RAX,RAX
@@10:	POP	RDI
  POP	RSI
  POP	RBP
  RET1	16
}
_extern _LAST_FUN I64 LastFun(I64 argc,I64 *argv); //Execute last fun with args.

