#!/bin/sh
###############################################################################
# trippy extern_package bootstrap
#
# Invoked automatically at boot by the stock firmware:
#   /etc/rc.d/rc1.d/S99local  ->  mount -o loop .../extern_package /extern
#                             ->  /extern/etc/init.d/startup.sh
#
# Also safe to run by hand after hot-plugging the stick:
#   mkdir -p /extern; mount -o loop /data/UsbDisk1/Volume1/extern_package /extern
#   sh /extern/etc/init.d/startup.sh
#
# Everything it does is reversible (RAM + bind-mounts). Nothing is written to
# flash. teardown.sh undoes it; a power-cycle wipes it entirely.
###############################################################################

# --- locate the bundle root (no dirname applet on stock busybox) ------------
SELF="$0"
case "$SELF" in /*) ;; *) SELF="$PWD/$SELF" ;; esac
BASE="${SELF%/etc/init.d/*}"                 # strip /etc/init.d/startup.sh
[ -d "$BASE/opt" ] || BASE=/extern           # vendor autorun mountpoint
[ -d "$BASE/opt" ] || BASE=/tmp/extern       # manual mountpoint fallback
[ -d "$BASE/opt" ] || { echo "startup: cannot locate bundle root"; exit 1; }

BIN=/tmp/bin
LOG="$BASE/run/startup.log"
HTTP_PORT=8080
exec >>"$LOG" 2>&1
echo "===== startup $(date) BASE=$BASE ====="

# --- 1. install modern busybox applets into /tmp/bin ------------------------
mkdir -p "$BIN"
cp -f "$BASE/opt/bin/busybox" "$BIN/busybox"
chmod +x "$BIN/busybox"
"$BIN/busybox" --install -s "$BIN" 2>/dev/null
export PATH="$BIN:$PATH"
echo "busybox: $("$BIN/busybox" 2>&1 | head -1)   applets=$("$BIN/busybox" --list | wc -l)"

# --- 2. start the busybox httpd control panel on :HTTP_PORT ------------------
# NB: busybox httpd shows up in ps as "busybox" and this box's netstat doesn't
# list its socket, so detect our instance by its cmdline via ps.
if ps | grep "httpd -p $HTTP_PORT" | grep -qv grep; then
    echo "httpd already running on :$HTTP_PORT"
else
    "$BIN/busybox" httpd -p "$HTTP_PORT" -h "$BASE/opt/htdocs" -c "$BASE/opt/httpd.conf"
    echo "httpd started on :$HTTP_PORT (docroot $BASE/opt/htdocs)"
fi

# --- 3. (optional) takeover: replace the stock landing with our vacation portal
# Full-page bind-mount over main.html (games + slim app links). umount restores.
STOCK=/www/app/main.html
USBDIR=/data/UsbDisk1/Volume1
for V in /data/UsbDisk*/Volume*; do [ -f "$V/extern_package" ] && USBDIR="$V" && break; done
mkdir -p "$USBDIR/games" 2>/dev/null      # so portal game links resolve
if [ "$TRIPPY_SKIN" = "1" ] && [ -f "$STOCK" ] && [ -f "$BASE/opt/portal.html" ] && ! mount | grep -q " $STOCK "; then
    mount -o bind "$BASE/opt/portal.html" "$STOCK" && echo "stock landing replaced with trippy portal"
fi

# --- 4. wardriving: scan ra0 every 5 min ------------------------------------
# NOT via crond: busybox crond chdir()s to each job's $HOME before running it,
# and root's home (/root, per /etc/passwd) does not exist on this read-only
# rootfs -- the chdir fails and the job is killed before the command ever runs,
# so cron silently produces nothing. We self-schedule with a tiny background
# loop instead (no $HOME/chdir dependency). Invoke via `sh` so a missing execute
# bit on the read-only ext2 image can't break it either. The loop runs one scan
# immediately, then every 5 min; errors go to the run log (not /dev/null).
WD="$BASE/opt/bin/wardrive.sh"
PIDF="$BASE/run/wardrive.loop.pid"
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; then
    echo "wardrive loop already running (pid $(cat "$PIDF"))"
else
    ( while :; do sh "$WD" >>"$BASE/run/wardrive.boot.log" 2>&1; sleep 300; done ) &
    echo $! > "$PIDF"
    echo "wardrive loop started: scan now + every 5 min (pid $!)"
fi

echo "startup complete. panel: http://<device-ip>:$HTTP_PORT/"
exit 0
