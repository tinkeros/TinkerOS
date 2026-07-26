Cd(__DIR__);;

//If these are not present in /Home, it uses the version in the root dir.  You
//can make your own, modified, version of these files in your /Home directory.
#include "~/HomeLocalize"

// Comment these if you do not want extra utilities
#include "/Adam/Opt/Boot/MakeBoot"
#include "/Adam/Opt/Utils/MakeUtils"

// Comment this if you do not want autocomplete
AdamFile("/Adam/AutoComplete/DoACInit");

// Comment this if you don't want Ed to pop-up warnings
// to help prevent overwriting already changed file.
doc_ed_warn_overwrite=TRUE;
// Comment this if you don't want Ed to pop-up warnings
// to help prevent opening the same file twice.
doc_ed_warn_already_open=TRUE;

// Misc helper functions

// Try to auto mount drive C.
U0 AutoHome()
{
  MountAuto(1);
  Cdd("C:/Home");
}

// Try to auto mount drive C and do a soft-reboot into it.
U0 AutoSBC()
{
  if (!DrvMounted('C'))
    AutoHome;
  if (DrvMounted('C'))
    if (IsFile("C:/Kernel.BIN.C"))
      BootRAM("C:/Kernel.BIN.C");
  "Failed to mount C or find bootable kernel!\n";
}

// Experimental FM 801 sound card OPL support. Kept as a plain #include
// outside AudioInit: FM801.HC defines public FM801SetVol/FM801GetVol
// (global volume-key hotkey handlers) and, if a card is found,
// synchronously #defines FM801_OPL_BASE via Adam() -- the #ifdef
// FM801_OPL_BASE check inside AudioInit below relies on that define
// already being resolved at compile time, which only holds if this
// stays a top-level #include compiled before AudioInit's body.
#include "/Demo/Snd/FM801"

U0 AudioInit()
{
  Bool hda_present,hda_cfg_ok;

  // Intel HD Audio (PCI class 04, subclass 03 -- same 0x040300 probe
  // HDAudio.HC itself uses). When a controller is present the HDA stack
  // below takes precedence: AC97 and the standalone Demo/Snd/OPL2 are
  // skipped (OPL2EmuHDA pulls in OPL2.HC itself, routed through HDA).
  hda_present=PCIClassFind(0x040300,0)>=0;

  if (IsHypervisorPresent) {
    if (!hda_present) {
      // AC97 sound support
      AdamFile("/Demo/VM/AC97");
      // Try enabling ISA OPL sounds if VM detected
      AdamFile("/Demo/Snd/OPL2");
    }
  }
  else {
#ifdef FM801_OPL_BASE
    if (!hda_present)
      AdamFile("/Demo/Snd/OPL2");
#endif
  }

  // Bring up the whole HDA sound stack -- driver, codec routing config,
  // mixer, speech (TMS5220/TTS), Wav/Mp3 playback, and the software OPL2
  // (Adlib) FM synth. Order matters: HDAudio must init first; OPL2EmuHDA
  // hijacks Snd() last so everything before it still compiles against
  // plain tones.
  if (hda_present) {
    AdamFile("/Demo/Snd/HDAudio");
    // First boot on this machine? Generate /Home/HDAudioCfg.HC.Z by
    // running HDCfg.HC, whose trailing HDCfgAuto call probes the codec,
    // auto-wires Speaker pins and saves the file -- queued after HDAudio
    // above, so the codec is up when it runs. Adam runs its queue in
    // order, so the file exists by the time the include below executes.
    hda_cfg_ok=IsFile("/Home/HDAudioCfg.HC.Z");
    if (!hda_cfg_ok && DrvIsWritable && IsHypervisorPresent) {
      // Run automatic HDA config if in VM
      AdamFile("/Demo/Snd/HDCfgNew");
      hda_cfg_ok=TRUE;
    }
    if (hda_cfg_ok)
      AdamFile("/Home/HDAudioCfg.HC.Z");
    AdamFile("/Demo/Snd/HDMixer");
    AdamFile("/Demo/Snd/TMS5220");
    AdamFile("/Demo/Snd/TTS");
    AdamFile("/Demo/Snd/Wav");
    AdamFile("/Demo/Snd/Mp3");
    AdamFile("/Demo/Snd/OPL2EmuHDA");
  }
}

if (IsHypervisorPresent) {
  // Enable experimental QEMU/VBox/VMware mouse help
  if (VBoxPciPresent)
    SethFile("/Demo/VM/VBoxAdd",-2);
  else
    AdamFile("/Demo/VM/VMMouse");
  if (mp_cnt>1) AudioInit;
}

#include "~/HomeWrappers"
MapFileLoad("::/Kernel/Kernel");
MapFileLoad("::/Compiler/Compiler");
#include "~/HomeKeyPlugIns"
#include "~/HomeSys"
Cd("..");;
