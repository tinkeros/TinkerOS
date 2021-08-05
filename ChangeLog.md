
### Changes added in TinkerOS 5.06.5.1:

#### Bug fixes:

- Fix RAMReboot (must be installed to hard drive to use, must do a normal reboot if you are changing graphics modes)

### Changes added in TinkerOS 5.06.5:

#### Compiler:

- Warning about unnecessary parenthesis now tell you where the problem is located.

#### Demos:

- Demo/Bitfield.HC - test using new bit field functions
- Demo/ScreenSavers - contains example screen savers

#### Documentation:

- Improved installation documentation displayed with auto installer.
- Added <a href="./USBBoot/BareMetal.md">baremetal install doc</a>
- Added <a href="./USBBoot/GraphicsModes.md">graphics mode doc</a>

#### Graphics improvements:

- Added screen saver functionality (since TinkerOS has no power management and cannot sleep the screen).  See /Demo/ScreenSavers for example screen savers and information on coding new ones.
- Added letterbox modes for 4:3 on widescreen
- Faster letterbox partial graphics updates.
- Faster scaled mode graphics updates.
- Added 239 more colors available for non-TempleOS apps to use. The first 16 (0-15) colors are the same as the TempleOS palette. The next 239 (16-254) are available for TinkerOS/3rd party apps.  Color 255 is transparent in both TempleOS and TinkerOS.
- Added message to text mode which is displayed if a user attempted to boot into a graphics mode which their system does not support so they know why they ended up in text mode and what they can do to fix it.
- Correct issues with pitch when pitch != 4 * width to support resolutions like 1366x768

#### Hardware support:

- Added probing of some commonly missed IO ports from some SATA controllers in legacy mode.
- Serial communications functions.
- Added new block device types for future support and function SetDrvLetType to allow their usage.

#### Installer:

- Added more graphics mode options in installer
- Added ability to define a custom resolution
- Installer can now automatically install between 1 and 4 copies of TinkerOS with different graphics settings.
- Improved hard drive probing to increase likelihood of a successful baremetal install using the automated installer.
- Added the ability to NOT probe for hard drives which is useful on some machines where probing crashes the system, but TinkerOS can install normally if you do not probe and instead manually enter the IO ports.

#### Live USB version improvements:

- Added Super Grub to probe available graphics modes for bare metal installs
- Added Clonezilla for backups and command line tools such as lspci for finding IO ports and cfdisk for partitioning
- Added ttylinux for partitioning on older systems
- Added FreeDOS for partitioning on older system
- Added memtest (bonus if you want to test your memory)
- Assuming a baremetal install is possible on your machine, the Live USB should now have everything you would need to do it.

#### Legacy functionality:
 - Added back kernel snd symbol required by Terry's supplemental audio test code.

#### New functionality:
```
// Functions to save and restore RAM disks:
I64 RamDiskToFile(U8 drv_let='B',U8 *filename); // Save a RAM disk to a file
I64 FileToRamDisk(U8 drv_let='B', U8 *filename); // Replace contents of RAM disk with a disk image file.

// Functions to get and put files to/from a host machine while running (for use with snail_lite.py):
I64 Fget(U8 *filename); //Gets file from another PC over serial
I64 Fput(U8 *filename); //Transfers file using to another PC over serial

// Screen saver function:
U0 SetScreenSaverTimeout(I64 new_timeout); // Set timeout value for screen saver in seconds

// Bit-field helper functions:
U0 BitFieldSet(U8 *bit_field, U8 offset, U8 size, U8 value);
U64 BitFieldGet(U8 *bit_field, U8 offset, U8 size);

// File/Disk functions:
U8 *FileBaseName(U8 *filename); // Returns file name without the path
Bool SetDrvLetType(U8 drv_let, U8 type); //Sets the BlkDev type for this drive letter to override default type
Bool DrvMounted(I64 drv_let); //Returns true if drv_let is mounted
```

### Changes added in TinkerOS 5.06.4:

#### Documentation changes:
 - Classes are now clickable links

#### Code changes:
 - Fixed multiple inclusion of many find functions
 - Minor code cleanup
 - Updated Terry's old USB code scrap and broke it up into an initial kernel integration and demo application. Note don't get excited, there is no USB device support, only support to detect the UHCI USB Hosts for some Intel USB controllers. Mainly this has been added in case anyone wants to expand the feature out more or tinker with it. For an example see (QEMU/README.md)

### Changes added in TinkerOS 5.06.3:
- Fix and simplify new serial functions
- Minor documentation fixes

### Changes added in TinkerOS 5.06.2:
- Improved documentation, now global variable symbols, ASM symbols, and defined constants are now links. Also fixed documentation containing symbols which are the same color as the background for examples see <a href="https://templeos.holyc.xyz/Wb/Kernel/KMisc.html#l179">here</a> vs <a href="https://tinkeros.github.io/WbGit/Kernel/KMisc.html#l191">here</a>.
- Fixed more broken documentation links.
- Fixed Adam AutoComplete warnings on bootup.
- Clean up more $ characters from compiler exceptions in raw mode.
- Improved Seth Graphics Helper compatibility with older versions of QEMU (curse you Ubuntu for never updating QEMU, note that OSTestSuite/some of Terry's examples will still fail on some old versions of QEMU as they do in regular TempleOS)
- Fixed screen cache not being flushed after palette change.
- Disabled debug COM1 output so it can be used for other purposes
- Moved serial port code to Adam
- Fixed Aunt Nellie in OT1975

### Semi-complete list of changes between Terry's last TempleOS release and TinkerOS 5.06:
- Documentation similar to templeos.holyc.xyz, but functions are linkable and content which normally can only be accessed within TempleOS is now available on the web (see <a href="https://tinkeros.github.io/WbGit/Doc/HelpIndex.html#l93">here.</a>)
- VBE2 video mode support, provides 2x 4:3 (640x480 or 800x600) and 2x wide screen resolutions (<a href="https://youtu.be/E8UvMijEiUA">640x340</a> or 1280x512).  This can be configured using the auto installer or when building/configuring the kernel.
- Modified installer to make it easy to install with different resolutions and easy to optionally copy additional software to your installation.
- SSE support is enabled on the CPU (for now only used by some 3rd party apps)
- If you have more than 1 core a second core is used to help render providing a faster system (since normally everything by default happens on core 1).  This is particularly useful when running it on slow Intel Atom chips or under QEMU on other architectures.
- Added AfterEgypt and Chess so you don't have to dig into the supplemental discs to run them.
- Fixed Chess and Titanium (now called SpyHunt and changed a bit).
- Added an old school Oregon Trail text adventure.
- Minor improvements to Kernel to cause it to use less calls to MAlloc.
- Slipstreamed additional software in Extras folder so you can just use MountFile to mount extra discs and don't have to deal with changing virtual cd drives.
- You can dynamically change the frame rate SetFPS(60);
- Some people are annoyed by blinking and scrolling, functions ToggleBlink and ToggleScroll exist.
- You may access the up/down state of multiple keys without message parsing, see new <a href="https://tinkeros.github.io/WbGit/Demo/KeyState.html">KeyState Demo</a>
- When on the command line if you mis-type a command followed by a ; and hit enter, you may be able to re-paste your last command if it is still scrolling as text in the top of the window by using the F8 key.
- BMP file support has been restored.
- Raw mode text is also dumped out COM1 which helps when debugging the kernel without a display.
- Compiler now has an option to not warn about unused externs.
- When on the command line a Cd is frequently followed with a Dir so Cdd was born to do both.
- Modified Find to have optional parameter max_cnt which will limit number of results returned (otherwise for some patterns it can find so much it crashes the entire OS).
- Modified Profiler to output the function with the largest CPU percentage at the bottom of the output.
- Improvements to TaskRep output and FindTaskByTitle helps locate tasks by name.
- Mouse no longer dumps random characters into the debugger.
- Some exceptions have been tweaked so parts of the exceptions which previously were covered are now able to be seen.
- Pruned and refactored Adam so some things can be disabled in <a href="https://tinkeros.github.io/WbGit/MakeHome.html">MakeHome.HC</a> to improve performance on low power machines.
- Moved some of Adam to the Kernel so many useful file operations are avaiable before Adam is loaded.
- Removed Task Memory address from top bar to make room for more CPUs to be able to be displayed.
- Fixed Dir missing default arguments (which prevents default usage when KernelC.HH not in scope).
- Fixed IsDir hang if called with a path to an unmounted drive.
- MountIDEAuto now has ability to mount only ATAPI drives via optional parameter.
