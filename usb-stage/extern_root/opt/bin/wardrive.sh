#!/bin/sh
# Ralink site-survey -> CSV logger. Run by cron (see startup.sh) or by hand.
# Writes to the FAT stick root (wardrive.csv) so it's readable on any laptop.
#
# Politeness: skips the scan when wardrive mode is "off" (panel toggle) OR when
# any WiFi client is associated to the AP (so it never interrupts active users).
PATH=/tmp/bin:$PATH; export PATH
IF=ra0

USBDIR=/data/UsbDisk1/Volume1
for V in /data/UsbDisk*/Volume*; do
  [ -f "$V/extern_package" ] && USBDIR="$V" && break
done
CSV="${1:-$USBDIR/wardrive.csv}"
MODE_FILE="$USBDIR/wardrive.mode"
STATUS="$USBDIR/wardrive.status"
ts=$(date '+%Y-%m-%d %H:%M:%S')

# panel on/off toggle (default on)
mode=on; [ -f "$MODE_FILE" ] && mode=$(cat "$MODE_FILE" 2>/dev/null)
if [ "$mode" = "off" ]; then echo "$ts  disabled (panel toggle)" > "$STATUS"; exit 0; fi

# client-aware guard: yield to anyone using the WiFi
sta=$(iwpriv "$IF" get_mac_table 2>/dev/null | grep -cE '([0-9a-fA-F]{2}:){5}')
if [ "${sta:-0}" -gt 0 ]; then
  echo "$ts  skipped ($sta WiFi client(s) connected)" > "$STATUS"; exit 0
fi

[ -f "$CSV" ] || echo "timestamp,channel,bssid,signal_pct,security,ssid" > "$CSV"
before=$(wc -l < "$CSV" 2>/dev/null); [ -z "$before" ] && before=0

iwpriv "$IF" set SiteSurvey=1 >/dev/null 2>&1
sleep 4
iwpriv "$IF" get_site_survey 2>/dev/null | awk -v ts="$ts" '
  /^[0-9]/ {
    mi=0
    for(i=1;i<=NF;i++)
      if($i ~ /^[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]$/){ mi=i; break }
    if(mi==0) next
    ssid=""; for(i=2;i<mi;i++){ if(ssid=="") ssid=$i; else ssid=ssid " " $i }
    gsub(/,/,";",ssid)
    printf "%s,%s,%s,%s,%s,%s\n", ts, $1, $mi, $(mi+2), $(mi+1), ssid
  }' >> "$CSV"

after=$(wc -l < "$CSV" 2>/dev/null); [ -z "$after" ] && after=0
echo "$ts  scanned ($((after-before)) APs)" > "$STATUS"
