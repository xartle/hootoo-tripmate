# TripMate "trippy" — modern toolchain + control panel project

Living progress/handoff doc. Goal: get a modern busybox / tooling and a custom
control panel onto an old HooToo TripMate travel router, ideally surviving reboot,
**without bricking it** (no firmware reflash path exists).

## Device facts (verified)
- **Address:** `192.168.0.192` (bridge/WAN side) and `10.10.10.254` (its own AP side, `br0`).
- **Hostname:** `trippy`. **SoC:** MediaTek **MT7620N**, MIPS 24Kc, **32-bit little-endian (mipsel)**, o32 ABI, ~386 BogoMIPS.
- **Kernel:** Linux **2.6.36** (2014). **libc:** uClibc **0.9.28**. **Stock busybox:** 1.12.1 (stripped — no `dirname`, `tr`, `od`, `base64`, `nc`, `vi`, `seq`).
- **Firmware:** "redweb5.05".
- **Root access (telnet :23):** user `root`, password `20080826` (the universal HooToo pw; still works). admin/empty for the web app.
- **Web stack:** `fileserv` (lighttpd) on `:80`, docroot `/www`; `ioos` on `:81`. The `.csp` API is a *compiled* lighttpd module in `/usr/lib/fileserv` (so we can't add new `.csp` endpoints easily, but `/www` static files are ours to shadow).

## Hard constraints (why the design is what it is)
- **rootfs** = read-only squashfs (`/dev/mtdblock8`), 100% full. Can't add files to `/`.
- **`/tmp` and `/etc` are ramfs** (RAM) — wiped on reboot. `/etc` is a bind-mount of `/boot/tmp/etc`.
- **Flash:** 8 MB NOR. Only tiny writable config partitions (`mtd6`/`mtd7`/Config, 64 KB each). **No room in flash for our ~1.6 MB binaries** → binaries must live on USB or RAM.
- **Device HAS internet** (pings 8.8.8.8) but **no on-device download client** (no wget/tftp/nc in stock busybox).
- **Telnet pty drops ~1% of bytes** on bulk input, and the CPU is too slow to `awk`-decode 1.6 MB → **cannot reliably push big binaries over telnet**. USB is the delivery vehicle.
- WebDAV in lighttpd is fully commented out (not an upload path).

## The solution (BUILT + VERIFIED WORKING)
Everything lives in **`usb-stage/`** in this repo.

- **`usb-stage/extern_package`** — an **ext2 loop-filesystem image** (built with `mke2fs -d`, no sudo) that goes at the **root of a FAT32 USB stick**. ext2 preserves exec bits (FAT can't).
- Contents (staged in `usb-stage/extern_root/`):
  - `opt/bin/busybox` — **BusyBox 1.31.0, static, musl, mipsel**. Source: `https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-mipsel`. **md5 `e3f48591199eaa0ef4b287c144de4c12`**. 396 applets incl. real wget/ftpd/tftpd/nslookup/tr/base64.
  - `etc/init.d/startup.sh` — bootstrap: copies busybox to `/tmp/bin`, `--install -s`, prepends PATH, starts the control panel httpd on `:8080`. Auto-detects its mount location via `${0%/etc/init.d/*}` (no `dirname`). Idempotent (detects running httpd via `ps | grep "httpd -p 8080"`).
  - `etc/init.d/teardown.sh` — kills the panel httpd (matches `httpd -p` in cmdline), removes UI bind-mount.
  - `opt/httpd.conf` — busybox httpd config. **Basic auth: `trippy` / `changeme`** (plaintext; change before trusting anywhere).
  - `opt/htdocs/` — control panel: `index.html` dashboard + `cgi-bin/{status,hw,wifi,loot,exec,scan,wardrive}.cgi`. `skin_inject.html` (+ `banner.js`) for stock-UI takeover.
  - **Wardriving logger:** `opt/bin/wardrive.sh` runs the `ra0` Ralink site-survey (`iwpriv ra0 set SiteSurvey=1; get_site_survey`), parses the fixed-column table (BSSID-anchored awk), and appends `timestamp,channel,bssid,signal_pct,security,ssid` to `wardrive.csv` on the FAT stick root (laptop-readable). `startup.sh` runs it every 5 min via busybox `crond` (crontab in `/tmp/crontabs/root`) + one scan at boot. `wardrive.cgi` shows a summary (unique BSSID/SSID, channel histogram, best-signal table) and `?a=csv` downloads the raw log. **Power/WiFi impact (measured):** idle `httpd`+`crond` ~0.0% CPU; the only active cost is the scan, which ties up the single 2.4 GHz radio for ~2 s (results land ~2 s after `SiteSurvey=1`) — a ~0.7% duty cycle, so battery hit is ~1% or less. But because `ra0` (the AP) shares that one radio, a scan briefly stalls connected WiFi clients. **Politeness (both implemented):** (1) **client-aware guard** — `wardrive.sh` skips the scan whenever `iwpriv ra0 get_mac_table` shows ≥1 associated station (counts colon-MAC lines), so it never interrupts active users; (2) **panel on/off toggle** — `wardrive.cgi?a=on|off|toggle` writes `wardrive.mode` (default on) on the stick. Each run writes `wardrive.status` (scanned N / skipped / disabled), surfaced in the panel alongside `wifi_clients_now`. awk gotcha: `ident (` is parsed as a function call in busybox awk — build strings without it. crond idempotency uses `pidof crond` (ps doesn't list it here, same as httpd).
  - **Battery + hardware:** `hw.cgi` reads `/proc/vs_battery_quantity` (battery %), `/proc/vs_net_link_status`, `/proc/vs_80211n_apcli0_connect_status`, `/proc/vstinfo` (model HT-TM05/fw/vendor/CPU), load/mem/uptime. `index.html` renders a live battery bar + device strip, polling every 15s. (No thermal sensor exposed.)
  - **Scanner (nmap-like):** `scan.cgi` — `?a=arp` lists neighbors from `/proc/net/arp`; `?host=H[&p=22,80,443|p=1-1024]` does an `nc` TCP connect-scan (busybox `nc` present; rc=0 open). Verified.
  - **Stock-UI takeover:** `TRIPPY_SKIN=1 sh startup.sh` injects `opt/skin_inject.html` (self-contained banner, uses `location.hostname`) before `</head>` of `/www/app/main.html` via bind-mount. Reversible (`teardown.sh` / reboot). NOTE: the boot hook runs startup WITHOUT TRIPPY_SKIN, so the skin is NOT auto-enabled on reboot (add `TRIPPY_SKIN=1` to the rc.local block to persist it).

  ASCII-only matters: the telnet pty mangles multibyte UTF-8 (and drops ~1% on bulk), so keep htdocs/scripts pure ASCII when pushing over telnet. Files inside the ext2 image (from USB) are byte-exact regardless.

### Control panel (LIVE, verified)
- URL: **`http://192.168.0.192:8080/`** (or `:10.10.10.254:8080`), login `trippy`/`changeme`.
- `status.cgi` system/net/storage dashboard; `wifi.cgi` Ralink site survey; `loot.cgi` passwd/shadow/wifi-cred viewer; `exec.cgi` root command runner (command sent base64url in `?c=` to dodge URL-decoding). All confirmed running **as root** via the laptop.

### IMPORTANT firmware gotcha
This firmware has **no `/extern` mountpoint** and the rootfs is read-only, so the **vendor's built-in USB autorun is DEAD here** (`/etc/rc.d/rc1.d/S99local` does `mount -o loop .../extern_package /extern` → fails, no mountpoint). We mount on **`/tmp/extern`** instead. `startup.sh` adapts automatically.

### Manual run (USB hot-plugged while powered)
```sh
mkdir -p /tmp/extern
mount -o loop /data/UsbDisk1/Volume1/extern_package /tmp/extern
sh /tmp/extern/etc/init.d/startup.sh
# browse http://192.168.0.192:8080/  (trippy/changeme)
# optional stock-UI banner takeover: TRIPPY_SKIN=1 sh /tmp/extern/etc/init.d/startup.sh
```

## Reboot persistence (✅ VERIFIED WORKING 2026-06-03)
**STATUS: DONE.** `etcsync` wrote `/etc` (with rc.local hook) to flash mtd7 (RC=0).
Power-cycled with stick in; watch log captured the full cycle:
`UP/200 → 000 → ping DN → ping UP/000 (+64s) → UP/200 (+79s)`. Confirmed fresh
boot (uptime 75s), `/tmp/extern` auto-mounted, boot-time startup.log entry, panel
`200` from laptop, exec.cgi runs as root. **The hook fires at boot ~15s after the
device returns, with zero manual intervention.**

Recovery if ever needed: factory-reset (stock "Reset Settings"/reset button erases
mtd6/7, wipes the hook). To remove the hook cleanly: delete the `trippy autoload`
block from /etc/rc.local and re-run /etc/init.d/etcsync. Stock rc.local =
current minus the trailing block in `usb-stage/rclocal_block.txt`.

### Original (pre-flash) persistence step, for reference

- `/etc` persists to flash via the device's own **`etc_tools p`** (wrapped by `/etc/init.d/etcsync` / `saveetc()` in `vstfunc`) — the same routine the web UI uses on every "save settings". At boot, `initsh` restores `/etc` from flash via `etc_tools b`.
- **Hook:** appended a backgrounded poll-and-load block to **`/etc/rc.local`** (= `S99local`, runs last at boot). It waits up to ~60s for the USB to mount, then `mount -o loop`s `extern_package` on `/tmp/extern` and runs `startup.sh`. Polling avoids the boot/USB-mount race. Backgrounded (`&`) so it can never hang boot.
- **Verified in RAM:** appended block is syntax-clean; running `rc.local` from a torn-down state rebuilds busybox + brings the panel back (`200`); idempotent (no httpd stacking). Original `rc.local` backed up at `/tmp/rc.local.orig` (and the block is in `usb-stage/rclocal_block.txt`).
- **Flash write step (the only irreversible-ish action):** `/etc/init.d/etcsync` writes `/etc` (with the hook) to flash.
  - Recovery if boot misbehaves: re-run the 3 manual commands (if panel just didn't start), or **factory reset** (stock "Reset Settings" / reset button erases mtd6/7 and wipes our change). Original rc.local saved for restore+resync.
- After persist + reboot: **stick in → panel auto-starts; stick out → hook polls, finds nothing, stock boot.**

## Loot / notes (redacted for public repo)
- The `loot.cgi` panel page reads the device's live `/etc/passwd`, `/etc/shadow`, and
  `RT2860.dat` (own + bridged WiFi SSID/PSK) at request time — values are NOT stored in this repo.
- Stock telnet/web root login is the well-documented universal HooToo password `20080826`
  (public from the original hoo2 research; the on-disk `/etc/shadow` hash is device-specific
  and intentionally not published here).

## Entware verdict (assessed, NOT pursued)
Likely dead-end on this box: kernel is **2.6.36** (current Entware targets ≥3.2 → binaries would segfault), and our static busybox `wget` is **HTTP-only (no TLS)** so the TLS installer won't run cleanly. `bin.entware.net` IS reachable over plain HTTP, so a hand-picked old binary *might* run, but it's high-effort/low-odds. Chose the reliable `nc`-based `scan.cgi` instead to satisfy "something like nmap."

## Not done yet / next options
- Make the stock-UI skin persist across reboot (add `TRIPPY_SKIN=1` to the rc.local autoload block + re-run etcsync).
- Change the `trippy/changeme` panel creds (plaintext in `opt/httpd.conf`).
- (stretch) static mipsel nmap via cross-compile, if real nmap is ever needed.

## Working method notes
- Drive the device over telnet from the laptop with the throwaway Python helpers in `/tmp` (`tnx.py` = one-command-with-login; threaded-reader variants for long ops). Closing the telnet session SIGHUPs running commands (no `nohup`/`setsid` on device) — keep one session open for long tasks.
- Device shell is busybox 1.12 ash: supports `local`, `let`, `$(())`, `${##}`, `${%}` but lacks many applets — prepend `/tmp/bin` (modern busybox) on PATH inside CGIs.
