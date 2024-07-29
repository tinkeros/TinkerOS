//See $LK,"Install Documentation",A="FI:::/Doc/Install.DD"$.
//Study my account examples: $LK,"Cfg Strs",A="FL:::/Demo/AcctExample/TOS/TOSCfg.HC,1"$, $LK,"Update Funs",A="FL:::/Demo/AcctExample/TOS/TOSDistro.HC,1"$

#include "BootHD"

#help_index "Install"

#define KERNEL_BIN_C	"Kernel.BIN.C"

public Bool MakeCmp()
{//Recompile compiler
  return Cmp("/Compiler/Compiler","Compiler",,':');
}

public U0 MakeAll()
{//Recompile compiler and kernel manually
  if (MakeCmp)
    throw;
  if (Cmp("/Kernel/Kernel","Kernel",,':'))
    throw;
}

public U0 BootHDIns(U8 drv_let=0)
{//Install new parition boot-loader
  //$LK,"MakeAll",A="MN:MakeAll"$ and install new boot-loader.
  CDrv *dv;
  CFAT32Boot br;
  CDirEntry de;
  I64 i;
  try
  {
    if (!Drv(drv_let))
      throw;
    dv=Fs->cur_dv;
    MakeAll;
    switch (Let2BlkDevType(dv->drv_let))
    {
    case BDT_RAM:
    case BDT_AHCI_SATA:
    case BDT_ATA:
      Move("/Kernel/Kernel.BIN.Z","/" KERNEL_BIN_C);
      if (!FileFind("/" KERNEL_BIN_C,&de,FUF_JUST_FILES))
        "No Kernel.BIN.C\n";
      else
      {
        Free(de.full_name);
        "Modifying partition boot record.\n";
        BlkRead(dv,&br,dv->drv_offset,1);
        br.jump_and_nop[0]=OC_JMP_REL8;
        br.jump_and_nop[1]=offset(CFAT32Boot.code)-2;
#assert offset(CFAT32Boot.code)>=offset(CRedSeaBoot.code)
        br.jump_and_nop[2]=OC_NOP;
        *BHD_BLK_CNT(U16 *)=(de.size+BLK_SIZE-1)>>BLK_SIZE_BITS;
        *BHD_DAP_BLK(I64 *)=Clus2Blk(dv,de.clus);
        for (i=0; i<BHD_END-BHD_CODE; i++)
          br.code[i]=BHD_CODE(U8 *)[i];
#assert sizeof(CFAT32Boot.code)>=BHD_END-BHD_CODE
        for (; i<sizeof(CFAT32Boot.code); i++)
          br.code[i]=0;
        BlkWrite(dv,&br,dv->drv_offset,1);
      }
      break;
    default:
      throw;
    }
  }
  catch
  {
    PutExcept;
    Beep;
  }
}

public U0 MakeAllDef(Bool install=FALSE, I64 width=-1, I64 height=-1, I64 do_mbr=-1, I64 scale=1)
{//Try to automatically recompile both compiler and kernel
  U8 *def_cfg, *res_str;
  I64 cur_drv_hint=-1;
  Bool res_ok=TRUE;
  res_str=MStrPrint("");
  CBlkDev *boot_blkdev=Let2BlkDev(blkdev.boot_drv_let,0);

  Adam("#define NO_LB 1\n");

  if (HashFind("CUR_DRV_HINT",adam_task->hash_table,HTT_DEFINE_STR))
  {
    if (width>0 && height>0 && !CheckVidMode(width, height, scale))
    {
      "This resolution is not supported!\n";
      return;
    }
    if (scale!=1 &&(FB_WIDTH!=GR_WIDTH || FB_HEIGHT!=GR_HEIGHT || DO_SCALING
      || LETTER_BOX || WIDTH_SCALE>1 || HEIGHT_SCALE>1))
      res_ok=FALSE;

    if (AHCIMode)
    {
      if (boot_blkdev)
        cur_drv_hint=boot_blkdev->port_num;
      else
        cur_drv_hint=ExePrint("CUR_DRV_HINT;\n")(I64);
    }
    else {
      ATARep(0);
      cur_drv_hint=blkdev.boot_hint;
      if (cur_drv_hint<0)
        cur_drv_hint=ExePrint("CUR_DRV_HINT;\n")(I64);
    }

    if (res_ok && width>0 && height>0)
    {
      Free(res_str);
      if (scale==1)
        res_str=MStrPrint("Resolution\n%d\n%d\nn",width,height);
      if (scale>1)
        res_str=MStrPrint("Resolution\n%d\n%d\nyy%d\n%d\n",width*scale,height*scale,scale,scale);
    }
    else {
      "Resolution settings might not be preserved, continue anyway ";
      if (!YorN('n')) return;
    }
    if (cur_drv_hint>=0)
    {
      if (AHCIMode)
      {
        def_cfg=MStrPrint("\nB\nScale2Mem(2048,0x40000)\n%c\n%d\n\n\n%s\n",
          'C',cur_drv_hint,res_str);
      }
      else
      {
        def_cfg=MStrPrint("\nB\nScale2Mem(2048,0x40000)\n%c\np%d\n\n\n%s\n",
          'C',cur_drv_hint,res_str);
      }
      In(def_cfg);
      if (install)
      { 
        BootHDIns(blkdev.boot_drv_let);
        if (do_mbr==-1) {
          "$$RED$$Re-install Master Boot loader to drive C?$$FG$$";
          if (YorN('y'))
          {
            '\n';
            BootMHDIns('C');
          }
          "$$RED$$Reboot?$$FG$$\n";
          if (YorN('y')) Reboot;
        }
        else if (do_mbr==1)
        {
          BootMHDIns('C');
        }
      }
      else MakeAll;
      Free(def_cfg);
      return;
    }
  }
  "Can not make default config, from this kernel, use MakeAll and set options manually!\n";
}

public U0 MakeAllIns(I64 width=-1, I64 height=-1)
{//Try to automatically recompile both compiler and kernel and install
  MakeAllDef(TRUE,width,height);
}

public U0 Do640x480()
{//Try to recompile kernel with standard 640x480 resolution
  MakeAllDef(TRUE,640,480,1);
}

public U0 Do800x600()
{//Try to recompile kernel with standard 800x600 resolution
  MakeAllDef(TRUE,800,600,1);
}

#help_index ""
