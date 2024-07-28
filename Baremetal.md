# Installing TempleOS or TinkerOS on Real Hardware

Note: Only do this on a machine you are prepared to lose all data on.  This will not setup a dual boot environment.  Installing baremetal is possible and has succeeded on many machines.  That being said this is totally unsupported so please do not make issues if your particular hardware does not work.

## Beginner "easy" baremetal install guide:

1) Check you have the right hardware and knowledge
   - 64-bit x86_64 PC (not Mac or Chromebook) with at least 2 GB of RAM
   - Must have a IDE or SATA drive to install to (M.2/NVME is not supported, this guide assumes 1 drive, not multiple).
   - Familiarity with how to enter the BIOS and change settings.
   - Must support CSM/Legacy booting, if your system is UEFI only, it is too new.
   - Use older < 500 GB spinning disks instead of SSDs for supporting the type of ATA communication TempleOS does, newer SSDs might not mount even if the OS can see them!
   - Your target hardware should probably be from between the years 2000 (first 64-bit CPU was a Pentium 4) and 2018 (newer probably lacks compatability, but still worth testing).
   - Here's a list of [baremetal installs](https://tinkeros.github.io/WbGit/Doc/Baremetal/Baremetal.html) which might be good options if you are looking to purchase hardware (note that some, but not all run both TempleOS and TinkerOS).
   
3) Make appropriate changes to BIOS settings (varies by system).
   - Secure boot off
   - Legacy / CSM boot on
   - UEFI boot off
   - Legacy USB / Port 60/64 emulation enabled
   - SATA drive in ATA / Compatability / IDE / Legacy (not AHCI or RAID) for installing both TempleOS and TinkerOS
   - SATA drive in AHCI mode (for installing TinkerOS only, no TempleOS support)
   - HPET disabled
   - Fast boot disabled

4) Write the Live USB image to a thumb drive or burn a CD/DVD (for IDE/legacy systems) to boot from.
   - Write TinkerOS_USB.img from latest [releases page](https://github.com/tinkeros/TinkerOS/releases)
     (Write with Rufus, Etcher, Raspberry PI Imager on Windows, simple dd command works on Linux)

5) Try Live booting TempleOS and TinkerOS from the USB
   - Check the keyboard and mouse work.
   - If they do not, do you have a PS/2 port you can try with real PS/2 keyboard/mouse? (USB to PS/2 adapters will not help).
   - Note that even if you can live boot TempleOS to a RAM disk, you still need support for legacy/IDE mode to be able to actually install it.
   - It is possible that TinkerOS works and TempleOS does not in which case TinkerOS would be your only option for that machine.

6) Use Clonezilla to partition your drive
   - Enter through defaults until you get to mode, then select Beginner
   - Select restoredisk
   - Choose included image file templeos_tinkeros_.....
   - Choose your hard drive (you will lose all data on this drive)
   - Select No to skip image checking
   - Enter and confirm if you really want to do it!
     
7) Live USB boot the first TinkerOS option to install
   - Choose Y for Install onto hard drive
   - Choose N for automated partitioning
   - Choose Y for run MountAuto
   - Choose Y for Continue Install Wizard
   - You should be able to press enter and select all default options for here (or modify them as you desire).

8) Boot from your hard drive hopefully to get a boot menu for TempleOS/TinkerOS!

9) If you have success and find a good machine for runnning TempleOS/TinkerOS let others know about it!
   - Run `SysSurvey;`
   - Edit the file and remove any information you do not want to share `Ed("/Home/Survey.DD");`
   - Add the form factor if applicable (for example Dell makes multiple form factors of the same Optiplex model so I added MFF/SFF after Optiplex 7050)
   - Copy file off manually or use Live USB to back up to the USB thumb drive.
   - Make a github pull request with the file name under and appropriate subdirectory of /Doc/Baremetal/Machines

## Advanced baremetal install tips

### USB emulation
  - On some boards strangely USB mice will work only if a PS/2 mouse is also plugged in.
  - Sometimes combo devices where the keyboard/mouse share one usb port do not work, but having a normal individual separate USB keyboard and mouse does work.
  - A PS/2 to USB adapter will not help you, these convert PS/2 to USB (so if USB isn't working, this won't help).

### Dual booting
  If you want to dual boot the best thing to do is let TempleOS/TinkerOS have one entire drive which it can install its bootloader on and then you can choose to boot that drive or your other OS manually at boot time (many computers have a key you can press/hold at start-up to let you choose a boot device manually, if you can't and have Windows it is probably because Fast Boot is on and you need to turn it off).

### Multiple hard drives (same controller/motherboard)
  - Use clonezilla to partition the drive, but make sure you select the correct one.
  - Choose N for Install onto hard drive and N for tour.  Then manually mount the drive (run `Mount;`) and pick the appropriate drive (if things are correct you should see C,D,E, and F FAT32 partitions mounted).
  - Restart the installer `#include "/Misc/OSInstall";` It should detect drives are already mounted and let you continue with a guided manual install.

### IDE/Legacy install when an AHCI controller is present
  By default TinkerOS prefers AHCI and will start in AHCI mode if it is detected as available.  If you know you've added an IDE controller (or SATA with legacy support) that you want to use for TempleOS/TinkerOS, then Choose N for Install onto hard drive and N for tour and run `SwitchToIDE;` to change to IDE mode.  Then use `Mount;` to mount the drive and restart the installer `#include "/Misc/OSInstall";` It should detect drives are already mounted and let you continue with a guided manual install.
