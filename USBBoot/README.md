# Creating a bootable USB version of TinkerOS
### Via Raw Disk Image
- Download a released TinkerOS_USB img file.
- Use raw disk image software to write it to your flash drive. 

Example (Linux):
First unmount any paritions auto mounted that are on your flash drive
Note everything will be overwritten, all data on the drive will be lost!

`sudo dd if=TinkerOS_USB_5.06.img of=/dev/sdX` 

Where X is the appropriate value for your flash drive, make sure you are absolutely sure you know what X should be!

`sudo sync`

Remove the drive.

### Other platforms
- Downloads the zip file version of <a href="https://clonezilla.org/">Clonezilla</a>
- Follow directions to create a bootable <a href="https://clonezilla.org/liveusb.php">live USB version of Clonezilla</a> for your platform.
- Copy isolinux.cfg from here to syslinux/isolinux.cfg and syslinux/syslinux.cfg on your Clonezilla flash drive.
- Copy the TinkerOS MemDisk ISO to TinkerOS.ISO on the root of your flash drive.
