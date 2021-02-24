## TinkerOS a fork of TempleOS

### Preface
TinkerOS is essentially TempleOS renamed with some changes that allow it to run bare metal on some more modern machines since it "only" requires real or emulated PS/2 keyboard and mouse input and legacy boot support.  TempleOS on the other hand requires hardware which supports Terry's hard coded 640x480 video mode which has been deprecated on some newer machines.  Also TempleOS requires an IDE drive interface or legacy ATA SATA support.  I created a "Live CD/USB" version which may allow you to use it installed on a RAM disk which allows it to run on modern machines which do not support legacy storage modes.  If your machine uses the newer EFI boot method, it will still need to support legacy booting (via CSM) which you may need to turn on in your BIOS.  Also note the processor bring up mechanism TempleOS uses is not acceptable on some newer boards.  For example only 1 core is seen on a 12 core Ryzen system it was tested on.  Lastly know that many laptops have keyboards and trackpads which are not PS/2 compatible (this is especially true of ultra thin laptops and chromebooks).  Contributions are welcome, but please do not create an issue you do not intend to create a pull request to fix.

### Goals
- Keep a TempleOS like look and feel while attempting to keep a fully TempleOS compatible API.
- <a href="https://github.com/tinkeros/TinkerOS/blob/main/USBBoot/README.md">Live USB boot</a> mode to allow trying it without having to install it that also works on systems lacking legacy storage support.  You are able to add your own files to be injected onto the RAM disk as well by placing them inside another RedSea ISO image and following the instructions to append it to the Memdisk ISO.  Here's a <a href="https://youtu.be/d5e9RYla36Y">video of it booting up bare metal</a> on a PC via an emulated USB flash drive backed by the TinkerOS Live USB image.
- Cleanup some unfortunate language that was left in TempleOS.
- Bring back some old TempleOS features and add new features, popular apps, and games.
- Make most apps and games work and look decent on both 4:3 and widescreen monitors (install using either 640x480 or 640x340)
- Make higher resolutions modes (mostly for programming) on both 4:3 and widescreen monitors (install using either 800x600 or 1280x512)
- Improve documentation.
- Any bug fixes are welcome.
- Possibly new device driver support for modern storage and/or networking.
- Document bare-metal device compatability.  Please make a pull request to update Compatibility.csv if you want to help.

### <a href="https://github.com/tinkeros/TinkerOS/blob/main/ChangeLog.md">Change Log</a>

### Notes
- TempleOS and TinkerOS have no device drivers for CPU frequency control, temperature detection, fans, or other motherboard devices.  It may be the case that you are able to boot TinkerOS bare metal, but you may be putting your machine at risk and it may crash due to thermal issues or because a watchdog timer is tripped because the operating system does not take over control of critical hardware (since there is no driver for it).  For example on a Toshiba Satellite C655 TinkerOS will run for exactly 5 minutes and then halt.  There are no plans to fix this, if you system has these issues your only option is to run it inside a virtual machine instead of bare metal or to implement the required drivers yourself.
- Though only 16 colors are used at a time, the graphics mode is 32-bit.  The frame buffer is linear and has resolution FB_WIDTH by FB_HEIGHT which maybe larger than GR_WIDTH and GR_HEIGHT.  You can always suspend the window manager and draw whatever graphics you want instead.  text.fb_alias is a pointer to the frame buffer.


### Known issues
- Debugger doesn't accept keyboard input on all machines (can be resolved in QEMU by clicking the mouse).
