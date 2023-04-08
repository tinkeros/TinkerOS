#help_index "Install;File/Cmd Line (Typically);Cmd Line (Typically);"
U8 Mount2(U8 boot_drv_let,CDoc *_doc,Bool _caller_is_prtdsk, Bool just_ide=FALSE,I64 *cur_drv_hint=NULL)
{//If _doc, called by $LK,"::/Kernel/KCfg.HC"$ else called by $LK,"Mount",A="MN:Mount"$().
  I64 cnt,total=0,num_hints,drv_let,type,unit,prt_num,port;
  U8 blks_buf[STR_LEN],addr_buf[STR_LEN],base0_buf[STR_LEN],base1_buf[STR_LEN],
  *filename=NULL,*filename2=NULL,res=0,port_str[STR_LEN];
  CATARep *head=NULL,*tmpha;
  Bool whole_drv,make_free;
  CDoc *doc;
  if (boot_drv_let)
    boot_drv_let=Let2Let(boot_drv_let);
  do
  {
    cnt=0;
    if (!_doc)
      DrvRep;
    "\n****** Mount Drives ******\n"
    "$$GREEN$$A$$FG$$-$$GREEN$$B$$FG$$ are RAM drives.\n"
    "$$GREEN$$C$$FG$$-$$GREEN$$L$$FG$$ are ATA hard drives.\n"
    "$$GREEN$$M$$FG$$-$$GREEN$$P$$FG$$ are ISO file read drives.\n"
    "$$GREEN$$Q$$FG$$-$$GREEN$$S$$FG$$ are ISO file write drives.\n"
    "$$GREEN$$T$$FG$$-$$GREEN$$Z$$FG$$ are ATAPI CD/DVD drives.\n"
    "\nDrive Letter ($$PURPLE$$<ENTER>$$FG$$ to exit):";
    drv_let=Let2Let(GetChar);
    '\n';
    if (type=Let2BlkDevType(drv_let))
    {
      whole_drv=FALSE;
      if (_doc)   //Called by $LK,"::/Kernel/KCfg.HC"$
      {
        doc=_doc;
        make_free=FALSE;
      }
      else     //Called by $LK,"Mount",A="MN:Mount"$()
      {
        doc=DocNew;
        DocPrint(doc,"CBlkDev *bd;\n");
        make_free=TRUE;
      }
      unit=0;
      prt_num=I64_MIN;
      port = -1;
      switch (type)
      {
      case BDT_RAM:
        "Addr of RAM disk ($$PURPLE$$<ENTER>$$FG$$ to MAlloc):"
        ;
        GetS(addr_buf,STR_LEN);
      case BDT_ISO_FILE_WRITE:
        "Blks of 512 bytes:"
        ;
        GetS(blks_buf,STR_LEN);
        break;
      case BDT_ISO_FILE_READ:
        filename=GetStr("File Name:");
        break;
      case BDT_ATA:
      case BDT_AHCI_SATA:
        prt_num=GetI64("Partition Num (Default=All):",prt_num);
      case BDT_ATAPI:
        if (AHCIMode)
        {
          num_hints=SATARep(type);
        }
        else
        {
          num_hints=ATARep(,just_ide,&head);
        }
        if ((type==BDT_ATAPI || type==BDT_AHCI_SATAPI) && boot_drv_let)
          "<ENTER> to use booted CD/DVD\n"; //Only $LK,"::/Kernel/KCfg.HC"$
        if (AHCIMode)
        {
          do
          {
            if (num_hints)
              "Enter port number: \n";
            GetS(port_str, STR_LEN);
          }
          while ((	type == BDT_ATAPI && AHCIPortSignatureGet(Str2I64(port_str)) != AHCI_PxSIG_ATAPI ||
                    type == BDT_ATA   && AHCIPortSignatureGet(Str2I64(port_str)) != AHCI_PxSIG_ATA ||
                    0 > Str2I64(port_str) || Str2I64(port_str) > num_hints - 1
                 ) &&
                 (type != BDT_AHCI_SATAPI || !boot_drv_let));
          port = Str2I64(port_str);
          if (cur_drv_hint) *cur_drv_hint=port;
          break;
        }
        else
        {
          do
          {
            if (num_hints)
              "Enter dev number or\nport with $$PURPLE$$0x$$FG$$ prefix.\n"
              "I/O Port Base0:\n";
            else
              "Include $$PURPLE$$0x$$FG$$ prefix.\nI/O Port Base0:\n";
            GetS(base0_buf,STR_LEN);
          }
          while (!Str2I64(base0_buf) && (type!=BDT_ATAPI || !boot_drv_let));
          // TODO from here
          if (1<=Str2I64(base0_buf)<=num_hints)
          {
            tmpha=ATARepFind(head,Str2I64(base0_buf));
            if (cur_drv_hint) *cur_drv_hint=Str2I64(base0_buf);
            StrPrint(base0_buf,"0x%X",tmpha->base0);
            StrPrint(base1_buf,"0x%X",tmpha->base1);
            unit=tmpha->unit;
          }
          else if (type!=BDT_ATAPI || *base0_buf)
          {
            if (type==BDT_ATAPI)
              StrCpy(base1_buf,"0");
            else
              do
              {
                "I/O Port Base1:\n";
                GetS(base1_buf,STR_LEN);
              }
              while (!Str2I64(base1_buf));
            do
            {
              "\t$$PURPLE$$0$$FG$$=Master\n\t$$PURPLE$$1$$FG$$=Slave\nUnit:";
              unit=GetChar-'0';
            }
            while (!(0<=unit<=1));
            '\n';
          }
          LinkedLstDel(head);
          break;
        }
      }
      // TODO continue adding AHCI
      DocPrint(doc,"bd=BlkDevNextFreeSlot(\'%C\',%d);bd->unit=%d;\n",
               drv_let,type,unit);
      if (AHCIMode && port != -1 && *port_str)
      {
        DocPrint(doc, "AHCIPortInit(bd, &blkdev.ahci_hba->ports[%d], %d);\n", port, port);
      }
      switch (type)
      {
      case BDT_RAM:
        if (!*addr_buf) StrCpy(addr_buf,"0");
        DocPrint(doc,"bd->RAM_dsk=%s;\n",addr_buf);
      case BDT_ISO_FILE_WRITE:
        if (!*blks_buf) StrCpy(blks_buf,"0");
        DocPrint(doc,"bd->max_blk=(%s)-1;\n",blks_buf);
        DocPrint(doc,"bd->drv_offset=19<<2+"
                 "(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE;\n");
        break;
      case BDT_ISO_FILE_READ:
        filename2=FileNameAbs(filename);
        DocPrint(doc,"bd->file_dsk_name=AStrNew(\"%s\");\n",filename2);
        DocPrint(doc,"bd->drv_offset=19<<2+"
                 "(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE;\n");
        break;
      case BDT_ATA:
      case BDT_ATAPI:
      case BDT_AHCI_SATA:
      case BDT_AHCI_SATAPI:
        if ((type==BDT_ATAPI || type==BDT_AHCI_SATAPI) && !*base0_buf)
        {
          DocPrint(doc,"GetBaseUnit(bd);\n"); //Only $LK,"::/Kernel/KCfg.HC"$
          if (drv_let==boot_drv_let)
            make_free=TRUE;
        }
        else if (!AHCIMode)
        {
          DocPrint(doc,"bd->base0=%s;bd->base1=%s;\n",base0_buf,base1_buf);
        }
        if ((type==BDT_ATA || type==BDT_AHCI_SATA) && _caller_is_prtdsk)
        {
          "\nReformat WHOLE drive!";
          whole_drv=YorN;
        }
        break;
      }
      DocPrint(doc,"BlkDevAdd(bd,%d,%d,%d);\n",prt_num,whole_drv,make_free);
      if (_doc) //Called by $LK,"::/Kernel/KCfg.HC"$
        cnt++;
      else   //Called by $LK,"Mount",A="MN:Mount"$()
      {
        if ((cnt=ExeDoc(doc)) && whole_drv)
        {
          if (_caller_is_prtdsk)
          {
            res=drv_let;
            DskPrt(drv_let,1.0); //First mount whole drive.
          }
          else
            DskPrt(drv_let);
        }
        DocDel(doc);
      }
    }
    total+=cnt;
  }
  while (cnt && !_caller_is_prtdsk ||
         !total && _doc); //At least 1 if Called by $LK,"::/Kernel/KCfg.HC"$
  Free(filename);
  Free(filename2);
  return res;
}

public U8 Mount(Bool caller_is_prtdsk=FALSE,Bool just_ide=FALSE)
{//Mount drives. Called from $LK,"DskPrt(Mount)",A="FF:::/Adam/ABlkDev/DskPrt.HC,Mount("$.
  return Mount2(0,NULL,caller_is_prtdsk, just_ide=FALSE);
}

