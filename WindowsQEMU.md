# Installing TempleOS or TinkerOS on Windows using QEMU

## Setup Steps:
1) Enable Virtualization in your BIOS (this step may not be necessary)
	- Steps vary by manufacturer

2) Enable Hyper-V (or performance will suck)

   - Search for windows features
   - Turn Windows features on or off
   - Check Hyper-V -> Hyper-V Platform
   - Reboot to enable
  
3) Download latest 64-bit QEMU for Windows
 
	- https://qemu.weilnetz.de/w64/2024/  (this site is legit, https://www.qemu.org/download/#windows links to it)
	
4) Download TempleOS and/or TinkerOS ISO
	- TempleOS: http://templeos.org/Downloads/TOS_Distro.ISO
	- TinkerOS: https://github.com/tinkeros/TinkerOS/releases

5) Copy downloaded TempleOS/TinkerOS ISO files to where you installed QEMU `C:\Program Files\qemu`

## Test run from CD:

### Open a command prompt and switch to QEMU directory
	cd "C:\Program Files\qemu"

### Run TempleOS (with PC speaker sound) from CD only (no install)
	qemu-system-x86_64.exe -m 2g -accel whpx,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc,pcspk-audiodev=snd0 -display sdl -cdrom TOS_Distro.ISO
	
### Run TinkerOS (with Adlib sound) from CD only (no install)
	qemu-system-x86_64.exe -m 2g -accel whpx,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc -device adlib,audiodev=snd0 -display sdl -cdrom TinkerOS_5.14.ISO

## Install to virtual hard drive:

### Create a virtual hard drive with desired name/format/size
	qemu-img.exe create tos.qcow2 512M

### Run TempleOS (with PC speaker sound) to install from CD to virtual hard disk
	qemu-system-x86_64.exe -m 2g -accel whpx,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc,pcspk-audiodev=snd0 -display sdl -cdrom TOS_Distro.ISO -hda tos.qcow2

### Run TinkerOS (with Adlib sound) to install from CD to virtual hard disk
	qemu-system-x86_64.exe -m 2g -accel whpx,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc -device adlib,audiodev=snd0 -display sdl -cdrom TinkerOS_5.14.ISO -hda tos.qcow2

### Notes
  - QEMU has a poorly emulated PC speaker sound might not be good with TempleOS
  - If you use TinkerOS instead you can use Adlib sound instead and as an added bonus you can [roll your own 64-bit randomly generated instrument with RandInst to go with your randomly generated GodSong or use PickInst to select from a list of available instruments](https://youtu.be/d0J1Jbhxsv0)!
 
