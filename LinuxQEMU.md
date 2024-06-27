# Installing TempleOS or TinkerOS on Linux using QEMU

## Setup Steps:
1) Enable Virtualization in your BIOS (this step may not be necessary)
	- Steps vary by manufacturer

2) Enable KVM if available for your CPU

3) Install 64-bit QEMU using package manager or compile from source.
 
4) Download TempleOS and/or TinkerOS ISO
	- TempleOS: http://templeos.org/Downloads/TOS_Distro.ISO
	- TinkerOS: https://github.com/tinkeros/TinkerOS/releases

## Test run from CD:

### Run TempleOS (with PC speaker sound) from CD only (no install)
	qemu-system-x86_64 -m 2g -accel kvm,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc,pcspk-audiodev=snd0 -display sdl -cdrom TOS_Distro.ISO
	
### Run TinkerOS (with Adlib sound) from CD only (no install)
	qemu-system-x86_64 -m 2g -accel kvm,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc -device adlib,audiodev=snd0 -display sdl -cdrom TinkerOS_5.14.ISO

## Install to virtual hard drive:

### Create a virtual hard drive with desired name/format/size
	qemu-img create tos.qcow2 512M

### Run TempleOS (with PC speaker sound) to install from CD to virtual hard disk
	qemu-system-x86_64 -m 2g -accel kvm,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc,pcspk-audiodev=snd0 -display sdl -cdrom TOS_Distro.ISO -hda tos.qcow2

### Run TinkerOS (with Adlib sound) to install from CD to virtual hard disk
	qemu-system-x86_64 -m 2g -accel kvm,kernel-irqchip=off -smp 4 -audiodev sdl,id=snd0 -machine pc -device adlib,audiodev=snd0 -display sdl -cdrom TinkerOS_5.14.ISO -hda tos.qcow2

### Notes
  - QEMU has a poorly emulated PC speaker sound might not be good with TempleOS
  - If you use TinkerOS instead you can use Adlib sound instead and as an added bonus you can [roll your own 64-bit randomly generated instrument with RandInst to go with your randomly generated GodSong or use PickInst to select from a list of available instruments](https://youtu.be/d0J1Jbhxsv0)!
  - You can run without KVM, but it will be slower.

 
