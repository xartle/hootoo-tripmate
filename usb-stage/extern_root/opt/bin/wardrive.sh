#!/bin/sh
# Ralink site-survey -> CSV logger. Run by cron (see startup.sh) or by hand.
# Writes to the FAT stick root (wardrive.csv) so it's readable on any laptop.
#
# Politeness: NEVER scans while the AP is in use. Two guards:
#   * panel on/off toggle      (wardrive.mode = off)
#   * client-aware guard       (skip while any station is associated to ra0)
#
# Single-radio reality: ra0 is the AP, so a real all-channel sweep has to take
# the radio off its channel for a few seconds. We therefore:
#   1. try a cheap in-place survey on ra0 first (works on some builds, no/low
#      disruption) and only if that returns nothing,
#   2. fall back to an off-channel sweep via the AP-client VIF (apcli0) -- but
#      re-check for clients in the last instant before leaving the channel, and
#      abort + restore if anyone connected. Set $USBDIR/wardrive.nodeep to skip
#      the off-channel fallback entirely.
PATH=/tmp/bin:$PATH; export PATH
IF=ra0
SCAN_IF=apcli0          # AP-client VIF used for the off-channel sweep fallback

USBDIR=/data/UsbDisk1/Volume1
for V in /data/UsbDisk*/Volume*; do
  [ -f "$V/extern_package" ] && USBDIR="$V" && break
done
CSV="${1:-$USBDIR/wardrive.csv}"
MODE_FILE="$USBDIR/wardrive.mode"
NODEEP="$USBDIR/wardrive.nodeep"
STATUS="$USBDIR/wardrive.status"
ts=$(date '+%Y-%m-%d %H:%M:%S')

# count stations currently associated to the AP
clients() { iwpriv "$IF" get_mac_table 2>/dev/null | grep -cE '([0-9a-fA-F]{2}:){5}'; }

# turn an `iwpriv ... get_site_survey` dump on stdin into CSV rows on stdout
parse_survey() {
  awk -v ts="$ts" '
    /^[0-9]/ {
      mi=0
      for(i=1;i<=NF;i++)
        if($i ~ /^[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]$/){ mi=i; break }
      if(mi==0) next
      ssid=""; for(i=2;i<mi;i++){ if(ssid=="") ssid=$i; else ssid=ssid " " $i }
      gsub(/,/,";",ssid)
      printf "%s,%s,%s,%s,%s,%s\n", ts, $1, $mi, $(mi+2), $(mi+1), ssid
    }'
}

# panel on/off toggle (default on)
mode=on; [ -f "$MODE_FILE" ] && mode=$(cat "$MODE_FILE" 2>/dev/null)
if [ "$mode" = "off" ]; then echo "$ts  disabled (panel toggle)" > "$STATUS"; exit 0; fi

# client-aware guard: yield to anyone using the WiFi
sta=$(clients)
if [ "${sta:-0}" -gt 0 ]; then
  echo "$ts  skipped ($sta WiFi client(s) connected)" > "$STATUS"; exit 0
fi

[ -f "$CSV" ] || echo "timestamp,channel,bssid,signal_pct,security,ssid" > "$CSV"
before=$(wc -l < "$CSV" 2>/dev/null); [ -z "$before" ] && before=0

# --- attempt 1: cheap in-place survey on the AP interface --------------------
iwpriv "$IF" set SiteSurvey=1 >/dev/null 2>&1
sleep 4
rows=$(iwpriv "$IF" get_site_survey 2>/dev/null | parse_survey)
method=ap

# --- attempt 2: off-channel sweep via apcli VIF (only if attempt 1 was empty)
if [ -z "$rows" ] && [ ! -f "$NODEEP" ]; then
  method=apcli
  iwpriv "$IF" set ApCliEnable=1 >/dev/null 2>&1   # some builds gate the VIF
  ifconfig "$SCAN_IF" up 2>/dev/null
  if ifconfig "$SCAN_IF" >/dev/null 2>&1; then
    # race guard: re-check clients right before we take the radio off-channel
    sta=$(clients)
    if [ "${sta:-0}" -gt 0 ]; then
      ifconfig "$SCAN_IF" down 2>/dev/null
      echo "$ts  skipped ($sta client(s) connected; off-channel sweep aborted)" > "$STATUS"; exit 0
    fi
    iwpriv "$SCAN_IF" set SiteSurvey=1 >/dev/null 2>&1
    sleep 6
    rows=$(iwpriv "$SCAN_IF" get_site_survey 2>/dev/null | parse_survey)
    ifconfig "$SCAN_IF" down 2>/dev/null             # restore: VIF down, ra0 AP resumes
  else
    method="none(no $SCAN_IF)"
  fi
fi

[ -n "$rows" ] && printf '%s\n' "$rows" >> "$CSV"

after=$(wc -l < "$CSV" 2>/dev/null); [ -z "$after" ] && after=0
echo "$ts  scanned ($((after-before)) APs via $method)" > "$STATUS"
