# Bootable USB versions of TempleOS/TinkerOS and MemDisk TinkerOS ISOs

### Note: The USB boot version of TempleOS/TinkerOS boot to a RAM disk in memory which allows you to try it without having to install it.  Because of this you can make changes and try them, but they are not saved anywhere and are lost upon rebooting.  This also allows booting TempleOS on machines without IDE drives in some cases.

### The USB Live boot image contains:

- TempleOS/TinkerOS able to be boot to RAM on most machines for trying without installing or for installing (TempleOS still requires IDE mode to install).
- Super Grub to help users determine which <a href="./GraphicsModes.md">Graphics Modes</a> they can use with their hardware.
- Clonezilla (normally used for backups, but the command line also provides easy access to tools lscpi for finding hard drive I/O ports which may be needed to install TinkerOS on some systems as well as cfdisk which can be used to partition disks manually in the case TinkerOS is unable to).
- ttylinux - Very small light weight command line only Linux distro for older machines.  You can use this for partitioning with fdisk.
- memtest - For testing the memory in your old machines to make sure it stable enough for your future awesome TinkerOS adventures.
- FreeDOS 13 - Mainly an extra bonus because our focus here is Retro, but also is able to partition and create FAT32 partitions.
