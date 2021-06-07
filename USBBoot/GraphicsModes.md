# Graphics modes

## Determinig graphics modes your hardware supports

### Obtain an old version of Super Grub boot disk which has a version of grub that has the vbeinfo command compiled in or use the version which comes with the TinkerOS live USB image.
 - Boot into Super Grub
<img src="https://github.com/tinkeros/TinkerOS/raw/tinkeros-update-docs/USBBoot/sgrub1.png">
- Press c to enter command line mode
- Enter commands:

```
set pager=1
vbeinfo
```
<img src="https://github.com/tinkeros/TinkerOS/raw/tinkeros-update-docs/USBBoot/sgrub2.png">
- Look for video resolution modes ending in "x 32 Direct, mask 8/8/8/8 pos: 16/8/0/24"
<img src="https://github.com/tinkeros/TinkerOS/raw/tinkeros-update-docs/USBBoot/sgrub3.png">


## Tested QEMU resolution support:

### Classic 4:3
 - 640x480 (4:3)
 - 800x600 (4:3)
 - 1024x768 (4:3)
### Widescreen (4:3) letterbox
 - 1024x768 via 1280x768 (letterboxed)
### Widescreen, but with 640 width (for TempleOS game compatability)
 - 640x360 via 1280x720 (2/2 scaling)
 - 640x400 via 1280x800 (2/2 scaling)
### 5:4 monitor
 - 1280x1024 (5:4)
### HD modes
 - 1280x720 (720p)
 - Custom width and height (You can set it to 1920x1080 if you want ultra high res 1080p, but keep in mind your doing CPU rendering!)
### Text mode
 - 12: Text mode 80x60 columns, no graphics

### Non-working automated installer options:
 - 640x480 via 768x480 (letterboxed)
 - 800x600 via 960x600 (letterboxed)
 - 640x340 via 1280x1024 (2/3 scaling)
 - 640x360 via 1280x720 (2/2 scaling)
