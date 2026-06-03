trippy extern_package — what's in here
======================================
Target: HooToo TripMate (MT7620N, MIPS mipsel, Linux 2.6.36, uClibc 0.9.28)

This is an ext2 filesystem image named `extern_package`. The stock firmware
(/etc/rc.d/rc1.d/S99local) auto loop-mounts it at /extern on boot and runs
/extern/etc/init.d/startup.sh — the manufacturer's own USB extension hook.
Nothing is written to flash; everything lives in RAM + this image. Pull the
stick (or power-cycle) and the device is 100% stock again.

contents
  etc/init.d/startup.sh   entry point: installs busybox, starts control panel
  etc/init.d/teardown.sh  undo it live (no reboot)
  opt/bin/busybox         BusyBox 1.31.0, static, mipsel  (md5 e3f4859119...)
  opt/httpd.conf          control-panel httpd config (basic auth: trippy/changeme)
  opt/htdocs/             control-panel web root (port 8080)
    index.html            dashboard
    banner.js             stock-UI takeover banner
    cgi-bin/status.cgi    system/network/wifi dashboard
    cgi-bin/wifi.cgi      site-survey trigger + results
    cgi-bin/loot.cgi      passwd/shadow/wifi-creds/config viewer
    cgi-bin/exec.cgi      root command runner (base64url ?c=)
  opt/inject/             (reserved)

NOTE: this firmware's rootfs is read-only and has NO /extern mountpoint, so the
vendor boot-autorun (S99local -> mount .../extern_package /extern) cannot run
here. Mount on a writable path instead (/tmp/extern). startup.sh auto-detects
its own location, so it works from either mountpoint.

manual run (USB hot-plugged while powered):
  mkdir -p /tmp/extern
  mount -o loop /data/UsbDisk1/Volume1/extern_package /tmp/extern
  sh /tmp/extern/etc/init.d/startup.sh
  # then browse http://<device-ip>:8080/   (login trippy/changeme)
  # device-ip is 192.168.0.192 (bridge side) or 10.10.10.254 (AP side)

optional stock-UI takeover (injects banner into the real web app):
  TRIPPY_SKIN=1 sh /tmp/extern/etc/init.d/startup.sh
  # revert: sh /tmp/extern/etc/init.d/teardown.sh

NOTE: not persistent across reboot (no boot hook yet; /tmp is RAM). Re-run the
three commands after a power-cycle, or ask to wire an /etc-based boot hook.

CHANGE the basic-auth creds in opt/httpd.conf before trusting this anywhere.
