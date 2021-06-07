## Baremetal install steps

### Step 1 - Check machine meets requirements and is setup to boot legacy operating systems.
- Ensure you do not care about any data on the machine or its hardware (TinkerOS will not protect you from destroying your machine)
- Ensure your PC has a 64-bit processor and either has real old school IDE hard drives or Legacy SATA mode support.
- Ensure your PC has real PS/2 mouse/keyboard ports (and you're using them) or supports PS/2 mouse/keyboard emulation.  (You can check by just booting TinkerOS from USB and seeing if your current keyboard/mouse works).
- If your BIOS uses UEFI boot, you needed to enable Legacy booting (might be called CSM).
- Also check for additional useful features which mention Legacy USB support or PS/2 emulation and enable these for the mouse and keyboard to work.

### Step 2 - write TinkerOS USB image to a thumb drive and boot it.
- Check if you have a working keyboard/mouse.  Usually on desktops the keyboard will always work, but the mouse may not. You might be able to get away with using a USB keyboard and PS/2 mouse.
- If you can't get a working keyboard and mouse, stop here, I'm sorry your machine won't work with TinkerOS.

### Step 3 - Setup hard drive (for SATA drives / newer machines)
- Go into the BIOS and change the Storage/SATA mode from AHCI/RAID to ATA/IDE/Legacy.

### Step 4 - Check supported graphics modes (optional, only you want > 640x480 resolution or widescreen options)
 - Boot the TinkerOS live USB drive and select Super Grub and note the supported modes as described <a href="./USBBoot/GraphicsModes.md">here.</a>
 - Disreguard any resolutions you know to be higher than the max resolution supported by your monitor.

### Step 5 - Boot TinkerOS and try automated installer.

### Step 6 - If automated installer fails, these steps might be helpful for advanced users
 - Boot into Clonezilla and wait for it to boot answering prompts.
 - At the main menu select the command line prompt option, run ```sudo -i``` to become root.
 - Run ```lspci -vv | more``` to view possible useful I/O port information for manual installation
 - Run ```dd if=/dev/zero of=/dev/sda bs=1M count=1``` to wipe the partition table off your drive (where /dev/sda is changed appropriately for your hard drive)
 - Run ```cfdisk /dev/sda``` to partition your drive (where /dev/sda is changed appropriately for your hard drive)
   - Select label type: dos  (DO NOT select gpt or others)
   - For each TinkerOS instal you want create, make a partition for it:
     - Create a new partition, select primary (if you aren't asked primary/extended, then you don't have a dos partition type and need to wipe your drive first)
     - Set the partition type to b W95 FAT32
   - Choose write, respond yes and quit


### Step 8 - Boot TinkerOS live and install answering no to the automated installer.  You can try probing to see if your manually partitioned drive now works, if not try rebooting and answering no to probing and manually enter the IO ports.
  - If you are unsure of which IO ports go in what order, you can quit the installer and test combinations of IO ports and unit numbers on the command line like this:
  ```
ATAProbe(0x1f0,0x3f0,0,TRUE);
ATAProbe(0x1f0,0x3f0,1,TRUE);
ATAProbe(0x170,0x370,0,TRUE);
ATAProbe(0x170,0x370,1,TRUE);
```

## Example lspci -vv output:
### Note you want to look for IO ports listed under IDE or SATA controllers:
<img src="https://github.com/tinkeros/TinkerOS/raw/tinkeros-update-docs/USBBoot/lspci.png">
