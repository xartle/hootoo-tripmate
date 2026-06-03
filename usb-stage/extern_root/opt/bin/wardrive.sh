#!/bin/sh
# Ralink site-survey -> CSV logger. Run by cron (see startup.sh) or by hand.
# Writes to the FAT stick root (wardrive.csv) so it's readable on any laptop.
PATH=/tmp/bin:$PATH; export PATH
IF=ra0

# locate our USB volume (the one holding extern_package); fall back to UsbDisk1
USBDIR=/data/UsbDisk1/Volume1
for V in /data/UsbDisk*/Volume*; do
  [ -f "$V/extern_package" ] && USBDIR="$V" && break
done
CSV="${1:-$USBDIR/wardrive.csv}"

ts=$(date '+%Y-%m-%d %H:%M:%S')
[ -f "$CSV" ] || echo "timestamp,channel,bssid,signal_pct,security,ssid" > "$CSV"

iwpriv "$IF" set SiteSurvey=1 >/dev/null 2>&1
sleep 5
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
