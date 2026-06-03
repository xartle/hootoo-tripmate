# trippy — modern toolchain + control panel for an old HooToo TripMate

Turning a ~2014 **HooToo TripMate Titan** (HT-TM05) travel router into a useful
little Linux box: a modern static **BusyBox 1.31**, a web **control panel** with a
live **battery gauge** and an `nc`-based **port scanner**, and an optional takeover
of the stock web UI — all delivered from a USB stick, **persistent across reboot,
and 100% reversible** (no firmware reflash, nothing that can brick it).

![target](https://img.shields.io/badge/SoC-MT7620N%20mipsel-blue) ![kernel](https://img.shields.io/badge/kernel-2.6.36-lightgrey) ![libc](https://img.shields.io/badge/libc-uClibc%200.9.28-orange)

## The constraints that shaped it
- rootfs is a **read-only, 100%-full squashfs**; `/tmp` and `/etc` are **RAM**; flash has no room for our binaries.
- uClibc 0.9.28 is ancient → everything new must be **statically linked**.
- The device has internet but **no on-device download client**, and the telnet pty drops bytes on bulk input → USB is the delivery vehicle.

## How it works
A single **ext2 loop image named `extern_package`** sits at the root of a FAT32 stick
(ext2 preserves exec bits; FAT can't). A backgrounded hook in `/etc/rc.local`
(persisted to flash via the device's own `etcsync`) waits for the USB at boot, loop-mounts
the image on `/tmp/extern`, and runs `startup.sh`, which:
1. installs static **BusyBox 1.31** into `/tmp/bin` (real `wget`/`nc`/`tr`/… — 396 applets),
2. starts a **busybox-httpd control panel** on `:8080`,
3. (optionally) injects a banner into the stock web UI via a bind-mount.

Pull the stick → clean stock boot. Factory reset wipes the hook. No flash images are touched.

## Control panel (`:8080`)
- 🔋 live **battery %** (`/proc/vs_battery_quantity`) + device/link/uptime/RAM strip
- **status**, **hardware** (raw `/proc/vs_*`), **wifi** + site-survey scan
- **neighbors** (ARP) + **port scan** (`nc` TCP connect-scan) — the "nmap-like" bit
- a root **command box** (base64url → `exec.cgi`)

## Quickstart
```sh
# build the image (needs e2fsprogs >= 1.43)
usb-stage/build-image.sh            # -> usb-stage/extern_package

# copy to a FAT32 stick root, plug into the TripMate, then over a root shell:
mkdir -p /tmp/extern
mount -o loop /data/UsbDisk1/Volume1/extern_package /tmp/extern
sh /tmp/extern/etc/init.d/startup.sh
# browse http://<device-ip>:8080/   (default creds in opt/httpd.conf — CHANGE THEM)
```

## Repo layout
```
usb-stage/
  build-image.sh        # build extern_package from extern_root/
  extern_root/          # contents of the ext2 image
    etc/init.d/         # startup.sh / teardown.sh
    opt/bin/busybox     # static mipsel BusyBox 1.31 (see build-image.sh for source+md5)
    opt/httpd.conf      # panel httpd config (default creds — change!)
    opt/htdocs/         # dashboard + cgi-bin/{status,hw,wifi,loot,exec,scan}.cgi
    opt/skin_inject.html# stock-UI takeover banner
  rclocal_block.txt     # the /etc/rc.local boot hook
TRIPPY-PROGRESS.md      # full engineering writeup: device facts, gotchas, recovery
```

See **[TRIPPY-PROGRESS.md](TRIPPY-PROGRESS.md)** for the detailed teardown, including the
boot/persistence mechanism, the telnet-byte-drop and `dirname`/`pidof` gotchas, and why
Entware is a dead-end on this kernel.

## Safety / ethics
This targets **my own device** for tinkering. The control panel ships disabled-by-default
posture in spirit: change the default `httpd.conf` creds before exposing it, and note the
panel command box and `loot.cgi` give full root over anything that can reach `:8080`.

> Built collaboratively with Claude Code.
