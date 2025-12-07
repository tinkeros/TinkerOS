// QEMU/VMware backdoor mouse
//
// https://wiki.osdev.org/VMware_tools

#define VMWARE_MAGIC 0x564D5868
#define VMWARE_PORT 0x5658

#define CMD_GETVERSION 10

#define CMD_ABSPOINTER_DATA 39
#define CMD_ABSPOINTER_STATUS 40
#define CMD_ABSPOINTER_COMMAND 41

#define ABSPOINTER_ENABLE 0x45414552
#define ABSPOINTER_RELATIVE 0xF5
#define ABSPOINTER_ABSOLUTE 0x53424152

U0 VMWSend(CRAXRBXRCXRDX* cmd)
{
    U32 reg RAX rax = cmd->rax(U32);
    U32 reg RBX rbx = cmd->rbx(U32);
    U32 reg RCX rcx = cmd->rcx(U32);
    U32 reg RDX rdx = cmd->rdx(U32);

    // Unused, but QEMU clobbers them
    U32 reg RSI rsi;
    U32 reg RDI rdi;
    no_warn rsi,rdi;

    rax = VMWARE_MAGIC;
    rdx = VMWARE_PORT;
    asm {
        IN AX, DX
    }

    cmd->rax = rax(U32);
    cmd->rbx = rbx(U32);
    cmd->rcx = rcx(U32);
    cmd->rdx = rdx(U32);
}

Bool VMWCheck()
{
    CRAXRBXRCXRDX cmd;
    cmd.rbx = ~VMWARE_MAGIC;
    cmd.rcx = CMD_GETVERSION;
    VMWSend(&cmd);
    if (cmd.rbx != VMWARE_MAGIC || cmd.rax == 0xFFFFFFFF) {
        return FALSE;
    }
    return TRUE;
}

U0 VMWMsAbsDisable()
{
    CRAXRBXRCXRDX cmd;

    cmd.rbx = ABSPOINTER_RELATIVE;
    cmd.rcx = CMD_ABSPOINTER_COMMAND;
    VMWSend(&cmd);
}


U0 VMWMsAbsEnable()
{
    CRAXRBXRCXRDX cmd;

    cmd.rbx = ABSPOINTER_ENABLE;
    cmd.rcx = CMD_ABSPOINTER_COMMAND;
    VMWSend(&cmd);

    cmd.rbx = 0;
    cmd.rcx = CMD_ABSPOINTER_STATUS;
    VMWSend(&cmd);

    cmd.rbx = 1;
    cmd.rcx = CMD_ABSPOINTER_DATA;
    VMWSend(&cmd);

    cmd.rbx = ABSPOINTER_ABSOLUTE;
    cmd.rcx = CMD_ABSPOINTER_COMMAND;
    VMWSend(&cmd);
}

interrupt U0 IRQMsVM()
{
  CLD
  OutU8(0xA0,0x20);
  OutU8(0x20,0x20);
  InU8(KBD_PORT);

  I64 x,y,z;
  Bool lb,rb;

  CRAXRBXRCXRDX cmd;

  cmd.rbx = 0;
  cmd.rcx = CMD_ABSPOINTER_STATUS;
  VMWSend(&cmd);
  if ((cmd.rax & 0xFFFF) < 4)
    return;

  cmd.rbx = 4;
  cmd.rcx = CMD_ABSPOINTER_DATA;
  VMWSend(&cmd);

  x=cmd.rbx(U16)*GR_WIDTH/0xffff;
  y=cmd.rcx(U16)*GR_HEIGHT/0xffff;
  z=cmd.rdx.i8[0];
  rb=cmd.rax&0x10==0x10;
  lb=cmd.rax&0x20==0x20;

  MsSet(x, y, ms.pos.z+z,lb,rb);

}

U0 VMWMsInit()
{
    if (!VMWCheck) {
        return;
    }
    AdamLog("Enabling VMMouse!\n");
    VMWMsAbsEnable;
    IntEntrySet(0x2C,&IRQMsVM);
}

VMWMsInit;
