# Installing TempleOS or TinkerOS on Real Hardware

Note: Only do this on a machine you are prepared to lose all data on.  This will not setup a dual boot environment.

## First steps:

1) Check you have the right hardware
   - 64-bit x86_64 PC with at least 2 GB of RAM
   - Must have a IDE or SATA drive to install (M.2/NVME is not supported)

3) Make appropriate changes to BIOS settings (varies by system).
   - Secure boot off
   - Legacy / CSM boot on
   - UEFI boot off
   - Legacy USB / Port 60/64 emulation enabled
   - SATA drive in Compatability / IDE / Legacy for installing both TempleOS and TinkerOS
   - SATA drive in AHCI for installing TinkerOS only

4) Write the Live USB image to a thumb drive or burn a CD/DVD (for IDE/legacy systems) to boot from.
   - Write TinkerOS_USB.img from latest [releases page](https://github.com/tinkeros/TinkerOS/releases) 

5) Try Live booting TempleOS and TinkerOS from the USB
   - Check the keyboard and mouse work
   - If they do not do you have a PS/2 port you can try with real PS/2 keyboard/mouse? (USB to PS/2 adapters will not help).

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
