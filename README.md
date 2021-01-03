## Future home of TinkerOS

### The main features are:
- VBE2 video mode support, provides 2x 4:3 (640x480 or 800x600) and 2x wide screen resolutions (640x340 or 1280x512)
- If you have more than 1 core a second core is used to help render providing a faster system (since normally everything by default happens on core 1)
- Added AfterEgypt and Chess so you don't have to dig into the supplemental disc.  Fixed Chess and Titanium (now called SpyHunt and changed a bit)
- Slipstreamed additional software in Extras folder so you can just use MountFile to mount those extra discs and don't have to deal with changing virtual cd drives.
- You can edit your MakeHome.HC to comment out some things like extra stuff from Adam like Utils and Autocomplete to save memory (I'm thinking this for the raspberry PI or low power systems)
- You can dynamically change the frame rate SetFPS(60);
- Some people are annoyed by blinking and scrolling, functions ToggleBlink and ToggleScroll exist.
- Other stuff TODO, update this
