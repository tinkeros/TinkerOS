# USB information

### Terry's old USB code scrap has been updated and broken up into an initial kernel integration and demo application.  Note that currently no devices are supported so this is not useful to you unless you plan to further the development.

For Kernel USB stuff see changes to:
```
Kernel/KernelA.HH
Kernel/KernelC.HH
Kernel/KGlbls.HC
Kernel/KMain.HC
Kernel/SerialDev/USB.HC
```

For demo which detects UHCI USB hosts on some machines see:
```
Demo/USB.HC
```

## Screen shot of 6 UCHI hosts detected in QEMU

<center><img src="https://github.com/tinkeros/TinkerOS/raw/main/QEMU/QEMU_6_UCHI_USB.png"></center>

## QEMU setup

### Example command line which creates the 6 UCHI hosts TinkerOS can detect with 2 ports each:
```
qemu-system-x86_64 \
-hda ~/TOS/qemu_disk.qcow2 \
-machine kernel_irqchip=off -m 4096 \
-rtc base=localtime -soundhw pcspk \
-cdrom ~/TOS/MyDistro.ISO.C -boot d \
-smp cores=4 \
-readconfig ~/TOS/ich9-ehci-uhci.cfg
```

Plug in a virtual USB thumb drive backed by testfile.img (not seen in TinkerOS since no devices are supported):

```
-drive if=none,id=stick,file=~/TOS/testfile.img  \
-device usb-storage,bus=uhci-1.0,drive=stick
```

Plug in a virtual MTP device (not seen in TinkerOS since no devices are supported):
```
-device usb-mtp,rootdir=/tmp,bus=uhci-1.0
```





