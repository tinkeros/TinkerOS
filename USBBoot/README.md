# Bootable USB and MemDisk versions of TinkerOS

### Note: These versions boot TinkerOS to a RAM disk in memory which allows you to try it without having to install it.  Because of this you can make changes and try them, but they are not saved anywhere and are lost upon rebooting.

### Testing USB boot / MemDisk images with QEMU
- Download memdisk (this folder, same version that is shipped with Clonezilla), TinkerOS release MemDisk ISO and USB image file.
- Download example QEMU test scripts from this folder:

emu_std_memdisk - Tests booting TinkerOS using QEMU without any drives attached!

emu_std_usb - Tests booting TinkerOS from a raw drive image which could be written to a USB flash drive and also boots bare metal on some machines.  *Note that the USB disk image is also the 1st hard drive image so if you try installing you'll overwrite your USB image file*

### Writing Raw Disk Image to a USB drive (Multi-platform)
- Download a released TinkerOS USB disk image file.
- Download <a href="https://www.raspberrypi.org/software/">Raspberry PI Imager</a>
- In imager select Choose OS, scroll down, select Use Custom and select TinkerOS img file.
- In imager select Choose SD and select the SD card or USB flash drive you want to overwrite and install TinkerOS to.

<center><img src="https://github.com/tinkeros/TinkerOS/raw/main/USBBoot/example.png"></center>

### Writing Raw Disk Image to a USB drive (Linux)
- Download a released TinkerOS USB disk image file.
- Use raw disk image software to write it to your flash drive. 

Example (Linux):

First unmount any paritions auto mounted that are on your flash drive.

Note everything will be overwritten, all data on the drive will be lost!

`sudo dd if=TinkerOS_USB_5.06.img of=/dev/sdX` 

Where X is the appropriate value for your flash drive, make sure you are absolutely sure you know what X should be!

`sudo sync`

Remove the drive.

### Creating a bootable USB manually (various platforms)
- Downloads the zip file version of <a href="https://clonezilla.org/">Clonezilla</a>
- Follow directions to create a bootable <a href="https://clonezilla.org/liveusb.php">live USB version of Clonezilla</a> for your platform.
- At this point you should test your clonezilla bootable USB drive. If it works you can follow the next two simple steps to turn it into a TinkerOS bootable USB drive.
- Copy isolinux.cfg from here to syslinux/isolinux.cfg and syslinux/syslinux.cfg on your Clonezilla flash drive (replacing them).
- Copy the TinkerOS MemDisk ISO to TinkerOS.ISO on the root of your flash drive.


### Adding a TinkerOS entry to your legacy boot grub menu or creating a CD/DVD which boots to a TinkerOS ramdisk install.
- Both are possible, proof is left as an exercise to the user.
