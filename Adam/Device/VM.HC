public I64 Hypervisor()
{ 
  if (!IsHypervisorPresent) return 0;
  if (!StrCmp(HypeInfo,"KVMKVMKVM") || !StrCmp(HypeInfo,"TCGTCGTCG"))
    return 'QEMU';
  if (!StrCmp(HypeInfo,"VMwareVMware"))
    return 'VMware';
  if (!StrCmp(HypeInfo,"Microsoft Hv"))
    return 'Hyper-V';
  if (!StrCmp(HypeInfo,"prl hyperv"))
    return 'Parallel';
  if (PciFindByID(0x80ee,0xcafe))
    return 'VBox';
  
  return 0;
}
