#include "::/Misc/MakeMenu"

MenuBegin;
MenuFile("::/Misc/PersonalMenuHead.DD");
MenuScan("::/Apps/Icon*.DD*");
if (IsDir("::/3rdParty") && IsDir("::/3rdParty/Apps"))
  MenuScan("::/3rdParty/Apps/Icon*.DD*");
//The Community file set is an optional install (build/rebuild_community.sh,
//offered by Misc/OSInstall.HC only when the media carries Community.ISO.C),
//so most systems have no ::/Community at all.  The scan is recursive, so any
//project under it that ships an Icon.DD is picked up without further edits.
if (IsDir("::/Community"))
  MenuScan("::/Community/Icon*.DD*");
MenuScan("::/Demo/Games/Icons/*.DD*");
MenuApps("Fun Games\0Emulators\0Text Adventures\0"
      "Unfun Games\0Code Scraps\0Nongames\0");
MenuFile("::/Misc/PersonalMenuFoot.DD");
#ifdef personal_menu_file
MenuEnd(personal_menu_file);
#else
MenuEnd("::/PersonalMenu.DD");
#endif
