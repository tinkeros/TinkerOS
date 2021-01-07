## Future home of TinkerOS

### Preface
TinkerOS is essentially TempleOS renamed with some changes that allow it to run bare metal on some more modern machines since it "only" requires real or emulated PS/2 keyboard and mouse input and legacy boot support.  TempleOS on the other hand requires hardware which supports Terry's hard coded 640x480 video mode which has been deprecated on some newer machines.  Also TempleOS requires an IDE drive interface or legacy ATA SATA support.  I created a "LiveCD/USB" version which may allow you to use it installed on a RAM disk which allows it to run on modern machines which do not support legacy storage modes.  Your machine still needs to support at minimum legacy booting (CSM).  Also note the processor bring up mechanism TempleOS uses is not acceptable on some newer boards.  For example only 1 core is seen on my 12 - core Ryzen system.  Also know that many laptops have keyboards and trackpad which are not PS/2 compatible.  Contributions are welcome, but please do not create an issue you do not intend to create a pull request to fix.

### Goals
- Keep a TempleOS like feel and do not make horrible refactoring and API changes which break compatability with existing TempleOS applications.
- Cleanup some unfortunate language that was left in TempleOS.
- Bring back some old TempleOS features and add new features.
- Any bug fixes are welcome.
- New device drivers.

### The main features are:
- VBE2 video mode support, provides 2x 4:3 (640x480 or 800x600) and 2x wide screen resolutions (640x340 or 1280x512)
- Slipstreamed TempleOS supplemental discs as well as some 3rd party software.
- Modified installer to make it easy to install with different resolutions and easy to optionally copy additional software to your installation.
- SSE support is enabled on the CPU (for now only used by some 3rd party apps)
- If you have more than 1 core a second core is used to help render providing a faster system (since normally everything by default happens on core 1)
- Added AfterEgypt and Chess so you don't have to dig into the supplemental discs to run them.
- Fixed Chess and Titanium (now called SpyHunt and changed a bit).
- Added an old school Oregon Trail text adventure.
- Minor improvments to Kernel to cause it to use less calls to MAlloc.
- Slipstreamed additional software in Extras folder so you can just use MountFile to mount extra discs and don't have to deal with changing virtual cd drives.
- You can edit your MakeHome.HC to comment out some things like extra stuff from Adam like Utils and Autocomplete to save memory (I'm thinking this for the Raspberry PI or low power systems)
- You can dynamically change the frame rate SetFPS(60);
- Some people are annoyed by blinking and scrolling, functions ToggleBlink and ToggleScroll exist.
- Other stuff TODO, update this
