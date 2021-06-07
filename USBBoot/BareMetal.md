## Baremetal install steps and hints

### Step 1 - Check machine meets requirements and is setup to boot legacy operating systems.
- Ensure you do not care about any data on the machine or its hardware (TinkerOS will not protect you from destroying your machine, it has no power management drivers)
- Ensure your PC has a 64-bit processor and either has real old school IDE hard drives or Legacy SATA mode support.
- Ensure your PC has real PS/2 mouse/keyboard ports (and you're using them) or supports PS/2 mouse/keyboard emulation.  (You can check by just booting TinkerOS from USB and seeing if your current keyboard/mouse works).
- If your BIOS uses UEFI boot, you needed to enable Legacy booting (might be called CSM).
- Also check for additional useful features which mention Legacy USB support or PS/2 emulation and enable these for the mouse and keyboard to work.

### Step 2 - Write TinkerOS USB image to a thumb drive and boot it, test mouse, keyboard and wait patiently.
- If you can't get a working keyboard and mouse, stop here, I'm sorry your machine won't work with TinkerOS.
- Run the command ```Beep;``` to test if you have sound from the PC speaker.
- Check if you have a working keyboard/mouse.  Usually on desktops the keyboard will always work, but the mouse may not. You might be able to get away with using a USB keyboard and PS/2 mouse.
- I suggest waiting at least 15 minutes to see if the machine crashes.  Some machines expect the operating system to take over things like fan control and other power management feature or motherboard functions.  To protect you they have a watchdog timer that will trigger (usually in less than 10 minutes) and this will lock the machine if the OS has not taken over these functions as expected.  If this happens you won't be able to use TinkerOS on this machine and it is better to find out now than to got through all the step below for nothing.  Obviously if during this time you sense any overheating, turn it off!
- Consider running to OS test suite to see if it is successful:  ```#include "/Misc/OSTestSuite"```

### Step 3 - Setup hard drive (for SATA drives / newer machines)
- Go into the BIOS and change the Storage/SATA mode from AHCI/RAID to ATA/IDE/Legacy.

### Step 4 - Check supported graphics modes (optional, only you want > 640x480 resolution or widescreen options)
 - Boot the TinkerOS live USB drive and select Super Grub and note the supported modes as described <a href="./USBBoot/GraphicsModes.md">here.</a>
 - Disreguard any resolutions you know to be higher than the max resolution supported by your monitor.

### Step 5 - Boot TinkerOS and try automated installer.

### Step 6 - If automated installer fails, these steps might be helpful for advanced users
 - Boot into Clonezilla (Linux) and wait for it to boot answering prompts.
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

## Known working PCs:
 - Dell Optiplex 755/3010/7010/9010/3020/7020/9020
 - Dell Precision T7400
## Known PCs which boot to TinkerOS, but watchdog halts machine in less than 10 minutes
## Known not working PCs:
 - Many models of small Intel NUC PCs

## Known working laptops:
 - Dell Latitude D630
 - Dell Latitude E5400
 - Lenovo Thinkpad 420/430 (sometime probing is an issue, best to partition and enter IO ports manually)
## Known laptops which boot to TinkerOS, but watchdog halts machine in less than 10 minutes
 - HP Probook 655 G1
 - Toshiba Satellite C655D
## Known not working laptops:
 
