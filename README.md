<p align="center">
  <a href="https://tinkeros.github.io">
  <img src="https://tinkeros.github.io/Images/theme.gif" /></a>
</p>
<p align="center"><a href="https://tinkeros.github.io">TinkerOS/TempleOS documentation</a></p>
<p align="center"><a href="https://tinkeros.github.io/WbTempleOS/Downloads/">TempleOS downloads</a></p>
<p align="center"><a href="https://github.com/tinkeros/TinkerOS/releases">TinkerOS downloads</a></p>
<p align="center"><a href="https://github.com/tinkeros/TinkerOS/blob/main/LinuxQEMU.md">TempleOS/TinkerOS Linux QEMU VM setup guide</a></p>
<p align="center"><a href="https://github.com/tinkeros/TinkerOS/blob/main/WindowsQEMU.md">TempleOS/TinkerOS Windows QEMU VM setup guide</a></p>
<p align="center"><a href="https://github.com/tinkeros/TinkerOS/blob/main/Baremetal.md">TempleOS/TinkerOS baremetal (real hardware) setup guide</a></p>
</p>


### Preface
TinkerOS is essentially TempleOS renamed with some changes that allow it to run bare metal on some more modern machines since it "only" requires real or emulated PS/2 keyboard and mouse input and legacy boot support, but does not require legacy / IDE disk support. Though some improvements and bug fixes are added to TinkerOS, 95% of the code is the same as TempleOS and TinkerOS can install and compile TempleOS.  TempleOS on the other hand requires hardware which supports Terry's hard coded 640x480 video mode which has been deprecated on some newer machines.  Also TempleOS requires an IDE drive interface or legacy ATA SATA support.  TinkerOS supports AHCI SATA mode installation.  It also has a "Live USB" version which runs from a RAM disk which allows it to be tried without installing or run on systems without supported drives.  You can also use the USB version to install it on supported machines that do not have a CD/DVD drive.  If your machine uses the newer EFI boot method, it will still need to support legacy booting (via CSM) which you may need to turn on in your BIOS.  

### Goals
- Keep a TempleOS like look and feel while attempting to keep a fully TempleOS compatible API to the maximum extent possible.  TinkerOS should always be able to compile and install TempleOS.
- Be a fun playground OS that you can run on older machines 64-bit machines and do useful things with the serial and parallel ports.
- Live USB boot images allow trying TempleOS/TinkerOS without having to install it.  These also work on some systems lacking legacy storage support.  The live boot version also contains utilities to help with baremetal installation on real hardware.
- Cleanup some unfortunate language that was left in TempleOS.
- Bring back some old TempleOS features and add new features, popular apps, and games.
- Make higher resolutions easy to setup.
- Make more colors available for TinkerOS features and 3rd party apps.  The original TempleOS code that makes use of only 16 colors still works, no backward compatability has been broken.  TempleOS uses colors 16 colors 0-15 and 255=transparent.  TinkerOS and 3rd party apps can additionally use colors 16-254 for 239 more colors to work with.  These can be any 24-bit RGB color.
- Make most apps and games work and look decent on both 4:3 and widescreen monitors using letterboxing for a 4:3 experience or scaled widescreen modes with an effective width of 640 (640x360, 640x400, 640x512)
- Improve installation process.
- Possibly new device driver support for modern storage and/or networking.
- Document bare-metal device compatability.  Please make a pull request to update Compatibility.csv if you want to help.

### Notes
- TempleOS and TinkerOS have no device drivers for CPU frequency control, temperature detection, fans, or other motherboard devices.  It may be the case that you are able to boot TinkerOS bare metal, but you may be putting your machine at risk and it may crash due to thermal issues or because a watchdog timer is tripped because the operating system does not take over control of critical hardware (since there is no driver for it).  There are no plans to fix this, if you system has these issues your only option is to run it inside a virtual machine instead of bare metal or to implement the required drivers yourself.
- Though only 16 colors are typically used at a time, the graphics mode is 32-bit.  The frame buffer is linear and has resolution FB_WIDTH by FB_HEIGHT which maybe larger than GR_WIDTH and GR_HEIGHT.  You can always suspend the window manager and draw whatever graphics you want instead.  text.fb_alias is a pointer to the frame buffer.
- Many laptops have keyboards and trackpads which are not PS/2 compatible (this is especially true of ultra thin laptops and chromebooks).
- Contributions are welcome, but please do not create an issue you do not intend to create a pull request to fix.


### Acknowlegements
- Terry Davis for <a href="https://templeos.org/">TempleOS</a> of course!
- Code ported from <a href="https://github.com/Zeal-Operating-System/ZealOS">ZealOS</a>.

