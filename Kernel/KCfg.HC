//This is run in a $LK,"#exe",A="FF:::/Kernel/Kernel.PRJ,KCfg"${}.

U8 *kernel_cfg_options="MemInit\0HeapInit\0VarInit\0StaffMode\0"
                       "HomeDir\0NoMP\0TextMode\0DontProbe\0MountIDEAuto\0DbgDistro\0Resolution\0ScreenSaver\0AHCIMode\0Help\0";

#define CFG_MEM_INIT		0
#define CFG_HEAP_INIT		1
#define CFG_VAR_INIT		2
#define CFG_STAFF_MODE		3
#define CFG_HOME_DIR		4
#define CFG_NO_MP		5
#define CFG_TEXT_MODE		6
#define CFG_DONT_PROBE		7
#define CFG_MOUNT_IDE_AUTO	8
#define CFG_DBG_DISTRO		9
#define CFG_RESOLUTION		10
#define CFG_SCREEN_SAVER	11
#define CFG_AHCI_MODE		12
#define CFG_OPTIONS_NUM		13

#define CFG_HELP		13

class CKCfg
{
  U8 *dsk_cache_size_exp;
  CDoc *add_dev;
  U8 *dbg_distro_file,*dbg_distro_start;
  U8 *home_dir;
  Bool opts[CFG_OPTIONS_NUM];
  U8 mem_init_val,heap_init_val,var_init_val,
  boot_drv_let,mount_ide_auto_hd_let,mount_ide_auto_cd_let;
  U64 gr_width,gr_height,gr_scale,
      fb_width,fb_height,x_scale,y_scale,letter_box,
      letter_box_bar_width,screen_saver_timeout;
  I64 cur_drv_hint;
};

CDoc *KCfgAddDev(CKCfg *c)
{
  I64 ch;
  CDoc *doc=DocNew;
  "\n\nIn anticipation of the drives you will\n"
  "define shortly, enter the drive letter\n"
  "of the drive with the account directory.\n"
  "\n($$PURPLE$$<ENTER>$$FG$$ for cur drv) Boot Drv:";
  ch=Let2Let(GetChar);
  if ('A'<=ch<='Z')
    c->boot_drv_let=ch;
  else
    c->boot_drv_let=Drv2Let(Fs->cur_dv);
  "\n\n$$BK,1$$$$PURPLE$$Mount drives so they will be present when "
  "you boot.$$FG$$$$BK,0$$\n";
  Mount2(c->boot_drv_let,doc,FALSE,FALSE,&c->cur_drv_hint);
  return doc;
}

U0 KCfgOptions(CKCfg *c)
{
  I64 i,x_scale_max,y_scale_max;
  U8 *st=NULL,*st2,*st3,*cfgfile;
  Bool state;
  do
  {
    Free(st);
    for (i=0; i<CFG_OPTIONS_NUM; i++)
      if (i==CFG_HOME_DIR)
        "$$PURPLE$$%13tz$$FG$$:\"%s\"\n",i,kernel_cfg_options,c->home_dir;
      else if (i==CFG_RESOLUTION) {
        "$$PURPLE$$%13tz$$FG$$:\"%dx%d\"\n",i,kernel_cfg_options,c->gr_width,c->gr_height;
        if (c->fb_width!=c->gr_width || c->fb_height!=c->gr_height)
          "$$PURPLE$$  Framebuffer$$FG$$:\"%dx%d\"\n",c->fb_width,c->fb_height;
        if (c->x_scale!=1 || c->y_scale!=1)
          "$$PURPLE$$      Scaling$$FG$$:\"%dx%d\"\n",c->x_scale,c->y_scale;
      }
      else if (i==CFG_SCREEN_SAVER)
        "$$PURPLE$$%13tz$$FG$$:\"%d\"\n",i,kernel_cfg_options,c->screen_saver_timeout;
      else
        "$$PURPLE$$%13tz$$FG$$:%Z\n",i,kernel_cfg_options,c->opts[i],"ST_OFF_ON";
    "\nType '$$PURPLE$$Help$$FG$$' for help.\n";
    st=GetStr("Option ($$PURPLE$$<ENTER>$$FG$$ when done):","");
    i=LstMatch(st,kernel_cfg_options,LMF_IGNORE_CASE);
    if (i==CFG_HELP)
    {
      "\n"
      "$$PURPLE$$MemInit$$FG$$ Initializes memory above 0x100000 "
      "to a val at boot.\n"
      "$$PURPLE$$HeapInit$$FG$$ Initializes MAlloc() memory to a val.\n"
      "$$PURPLE$$VarInit$$FG$$ Initializes glbl var memory to a val.\n"
      "$$PURPLE$$HomeDir$$FG$$ Set home dir.\n"
      "$$PURPLE$$NoMP$$FG$$ No multicore.\n"
      "$$PURPLE$$TextMode$$FG$$ Text Mode (requires hard reboot).\n"
      "$$PURPLE$$DontProbe$$FG$$ Just prompt CD/DVD ports, don't probe.\n"
      "$$PURPLE$$MountIDEAuto$$FG$$ Auto Mount IDE drives to 'C' and 'T'.\n"
      "$$PURPLE$$DbgDistro$$FG$$ Include RAM Drv in Kernel.BIN.\n";
      "$$PURPLE$$Resolution$$FG$$ Change Resolution (%dx%d)\n"
      "$$PURPLE$$AHCIMode$$FG$$ AHCI Mode.\n"
      ,c->gr_width,c->gr_height;
      if (c->screen_saver_timeout>0)
        "$$PURPLE$$ScreenSaver$$FG$$ Change Screen Saver Timeout (%d seconds)\n",c->screen_saver_timeout;
      else
        "$$PURPLE$$ScreenSaver$$FG$$ Change Screen Saver Timeout (0=disabled)\n";
      "\n";
    }
    else if (0<=i<CFG_OPTIONS_NUM)
    {
      state=c->opts[i]=!c->opts[i];
      switch (i)
      {
      case CFG_SCREEN_SAVER:
        if (state)
          c->screen_saver_timeout=GetI64("Screen Saver Timeout (seconds, 0=disable): ",300,0,3600*24);
        break;
      case CFG_RESOLUTION:
        if (state)
        {
          "\n\nPlease enter a 32-bit resolution\n"
          "supported by your hardware:\n\n"
          "Widely supported resolutions:\n\n"
          "640 x 480 (default 4:3)\n"
          "800 x 600 (alt 4:3, some games may not look right)\n\n";
          c->fb_width=GetI64("Enter width (min 640, max 3440):",640,640,3440);
          c->fb_height=GetI64("Enter height (min 360, max 1440):",480,360,1440);
          c->gr_width=c->fb_width;
          c->gr_height=c->fb_height;
          c->gr_scale=0;
          c->letter_box=0;
          c->letter_box_bar_width=(c->fb_width-c->gr_width)/2;
          "\nWould you like to configure advanced\n"
          "options such as letterboxing or scaling ";
          if (YorN)
          {
            if (c->fb_width>640 && c->fb_height==480 || c->fb_width>800 && c->fb_height==600 || c->fb_width>1024 && c->fb_height==768 || c->fb_width % 8)
            {
#ifndef NO_LB
              if (c->fb_width % 8 == 0)
              {
                "\nWould you like to letterbox for a true"
                " 4:3 experience";
                if (YorN)
                {
                  c->letter_box=1;
                  if (c->fb_height==480)
                  {
                    c->gr_width=640;
                  }
                  if (c->fb_height==600)
                  {
                    c->gr_width=800;
                  }
                  if (c->fb_height==768)
                  {
                    c->gr_width=1024;
                  }
                  c->letter_box_bar_width=(c->fb_width-c->gr_width)/2;
                  break;
                }
              }
              else
              {
                c->gr_width=1;
                while (c->gr_width % 8 != 0)
                  c->gr_width=GetI64("Letterbox width (min 640, multiple of 8):",640,640,c->fb_width - c->fb_width%8);
                c->letter_box_bar_width=(c->fb_width-c->gr_width)/2;
                break;
              }
#endif
            }
            if (c->fb_width>=800 && c->fb_height>=600)
            {
              "\nScaling allows you to generate a lower\n"
              "effective resolution using a higher\n"
              "resolutions by repeating columns/rows for\n"
              "the purpose of making objects larger\n"
              "and/or correcting for differences between\n"
              "4:3 and widescreen monitors\n\n"
              "\nWould you like to configure x/y scaling ";
              if (YorN)
              {
                for (i=1; i<c->fb_width/400; i++)
                {
                  if (c->fb_width % i == 0)
                    x_scale_max=i;
                }
                y_scale_max = c->fb_height/300;
                if (x_scale_max<1)
                  x_scale_max=1;
                if (y_scale_max<1)
                  y_scale_max=1;
                "Max allowed x scale for width %d is: %d\n"
                ,c->fb_width,x_scale_max;
                c->x_scale=GetI64("Enter x scale >=1:",1,1,x_scale_max);
                "Max allowed y scale for width %d is: %d\n"
                ,c->fb_height,y_scale_max;
                c->y_scale=GetI64("Enter y scale >=1:",1,1,y_scale_max);
              }
              if (c->x_scale>1 || c->y_scale>1)
                c->gr_scale=1;
              c->gr_width=c->fb_width/c->x_scale;
              c->gr_height=c->fb_height/c->y_scale;
            }
          }
        }
        break;
      case CFG_MEM_INIT:
        if (state)
          c->mem_init_val=GetI64("Val (0-255):",255,0,255);
        break;
      case CFG_HEAP_INIT:
        if (state)
          c->heap_init_val=GetI64("Val (0-255):",255,0,255);
        break;
      case CFG_VAR_INIT:
        if (state)
          c->var_init_val=GetI64("Val (0-255):",255,0,255);
        break;
      case CFG_HOME_DIR:
        st2=GetStr("Home Dir(\"%s\"):",c->home_dir);
        if (!*st2)
          st2=StrNew("::/Home");
        else if (st2[1]!=':')
        {
          st3=MStrPrint("::%s",st2);
          Free(st2);
          st2=st3;
        }
        Free(c->home_dir);
        c->home_dir=st2;
        if (StrCmp(c->home_dir,"::/Home"))
          c->opts[i]=TRUE;
        else
          c->opts[i]=FALSE;
        break;
      case CFG_MOUNT_IDE_AUTO:
        if (state)
        {
          "First HD Drive Let:";
          c->mount_ide_auto_hd_let=Let2Let(GetChar);
          if (!('A'<=c->mount_ide_auto_hd_let<='Z'))
            c->mount_ide_auto_hd_let=0;
          '\n';
          if (c->mount_ide_auto_hd_let)
            "First HD Drive:%C\n",c->mount_ide_auto_hd_let;
          else
            "First HD Drive:%C\n",'C';
          "First CD Drive Let:";
          c->mount_ide_auto_cd_let=Let2Let(GetChar);
          if (!('A'<=c->mount_ide_auto_cd_let<='Z'))
            c->mount_ide_auto_cd_let=0;
          '\n';
          if (c->mount_ide_auto_cd_let)
            "First CD Drive:%C\n",c->mount_ide_auto_cd_let;
          else
            "First CD Drive:%C\n",'T';
        }
        else
        {
          c->mount_ide_auto_hd_let=0;
          c->mount_ide_auto_cd_let=0;
        }
        break;
      case CFG_DBG_DISTRO:
        Free(c->dbg_distro_file);
        c->dbg_distro_file=0;
        c->dbg_distro_start=0;
        if (state)
        {
          c->dbg_distro_file=GetStr("Dbg Distro File:");
          c->dbg_distro_start=GetI64("Dbg Distro Start:");
        }
        break;
      }
    }
  }
  while (*st);
  Free(st);
  CDoc *cfgdoc=DocNew;
  cfgfile=MStrPrint("%s/KCfg.HH",DirCur);
  StrCpy(&cfgdoc->filename.name,cfgfile);
  Free(cfgfile);
  DocPrint(cfgdoc,"//This is an autogenerated header file, do NOT change me!\n",c->gr_width);
  DocPrint(cfgdoc,"//Instead recompile kernel (BootHDIns)\n\n",c->gr_width);
  DocPrint(cfgdoc,"#define GR_WIDTH %d\n",c->gr_width);
  DocPrint(cfgdoc,"#define GR_HEIGHT %d\n",c->gr_height);
  DocPrint(cfgdoc,"#define FB_WIDTH %d\n",c->fb_width);
  DocPrint(cfgdoc,"#define FB_HEIGHT %d\n",c->fb_height);
  DocPrint(cfgdoc,"#define WIDTH_SCALE %d\n",c->x_scale);
  DocPrint(cfgdoc,"#define HEIGHT_SCALE %d\n",c->y_scale);
  DocPrint(cfgdoc,"#define DO_SCALING %d\n",c->gr_scale);
  DocPrint(cfgdoc,"#define LETTER_BOX %d\n",c->letter_box);
  DocPrint(cfgdoc,"#define SCREEN_SAVER_TIMEOUT %d\n",c->screen_saver_timeout);
  DocPrint(cfgdoc,"#define LETTER_BOX_BAR_WIDTH %d\n",c->letter_box_bar_width);
  DocPrint(cfgdoc,"#define GR_TEXT_MODE %d\n",c->opts[CFG_TEXT_MODE]);
  DocPrint(cfgdoc,"#define NOMP_MODE %d\n",c->opts[CFG_NO_MP]);
  if (c->cur_drv_hint >= 0)
    DocPrint(cfgdoc,"#define CUR_DRV_HINT %d\n",c->cur_drv_hint);
  DocWrite(cfgdoc);
  DocDel(cfgdoc);
}

CKCfg *KCfgNew()
{
  CKCfg *c=CAlloc(sizeof(CKCfg));
  c->cur_drv_hint=-1;
  c->add_dev=KCfgAddDev(c);
  c->home_dir=StrNew("::/Home");
  c->dsk_cache_size_exp=GetStr(
                        "Disk Cache Size in Bytes,\n"
                        "gets rounded-up funny,\n"
                        "($$PURPLE$$<ENTER>$$FG$$ will use default.):",
                        "Scale2Mem(0x80000,0x8000000)");
  c->screen_saver_timeout=300;
  c->gr_width=GR_WIDTH;
  c->gr_height=GR_HEIGHT;
  c->fb_width=FB_WIDTH;
  c->fb_height=FB_HEIGHT;
  c->x_scale=WIDTH_SCALE;
  c->y_scale=HEIGHT_SCALE;
  c->letter_box=LETTER_BOX;
  c->letter_box_bar_width=LETTER_BOX_BAR_WIDTH;
  c->gr_scale=0;
  if (WIDTH_SCALE>1||HEIGHT_SCALE>1)
    c->gr_scale=1;
  c->opts[CFG_TEXT_MODE]=0;
  c->opts[CFG_AHCI_MODE]=0;
  if (HashFind("AHCIMode",adam_task->hash_table,HTT_GLBL_VAR))
  {
    c->opts[CFG_AHCI_MODE]=ExePrint("AHCIMode;\n")(I64);
  }
  if (HashFind("NOMP_MODE",adam_task->hash_table,HTT_DEFINE_STR))
  {
    c->opts[CFG_NO_MP]=ExePrint("NOMP_MODE;\n")(I64);
  }
  KCfgOptions(c);
  return c;
}

U0 KCfgDel(CKCfg *c)
{
  DocDel(c->add_dev);
  Free(c->dbg_distro_file);
  Free(c->home_dir);
  Free(c->dsk_cache_size_exp);
  Free(c);
}
