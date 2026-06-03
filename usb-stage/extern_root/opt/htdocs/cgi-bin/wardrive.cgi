#!/bin/sh
PATH=/tmp/bin:$PATH; export PATH
a=$(echo "$QUERY_STRING" | sed -n 's/^.*a=\([^&]*\).*$/\1/p')

USBDIR=/data/UsbDisk1/Volume1
for V in /data/UsbDisk*/Volume*; do [ -f "$V/extern_package" ] && USBDIR="$V" && break; done
CSV="$USBDIR/wardrive.csv"
MODE_FILE="$USBDIR/wardrive.mode"

# raw CSV download
if [ "$a" = csv ]; then
  echo "Content-type: text/csv"
  echo "Content-Disposition: attachment; filename=wardrive.csv"; echo
  [ -f "$CSV" ] && cat "$CSV"
  exit 0
fi

# on/off toggle
case "$a" in
  on)  echo on  > "$MODE_FILE" ;;
  off) echo off > "$MODE_FILE" ;;
  toggle) cur=on; [ -f "$MODE_FILE" ] && cur=$(cat "$MODE_FILE")
          [ "$cur" = on ] && echo off > "$MODE_FILE" || echo on > "$MODE_FILE" ;;
esac

echo "Content-type: text/plain"; echo
mode=on; [ -f "$MODE_FILE" ] && mode=$(cat "$MODE_FILE")
sta=$(iwpriv ra0 get_mac_table 2>/dev/null | grep -cE '([0-9a-fA-F]{2}:){5}')
echo "# wardrive   mode=$mode   wifi_clients_now=$sta   (toggle: wardrive.cgi?a=toggle)"
[ "$mode" = on ] && [ "$sta" -gt 0 ] && echo "#   -> scans are PAUSED while $sta client(s) connected (auto-resumes when idle)"
[ -f "$USBDIR/wardrive.status" ] && echo "# last run: $(cat "$USBDIR/wardrive.status")"
echo

[ -f "$CSV" ] || { echo "no wardrive.csv yet -- cron scans ra0 every 5 min when idle & enabled."; exit 0; }

total=$(( $(wc -l < "$CSV") - 1 ))
ubss=$(tail -n +2 "$CSV" | cut -d, -f3 | sort -u | wc -l)
ussid=$(tail -n +2 "$CSV" | cut -d, -f6 | grep -v '^$' | sort -u | wc -l)
first=$(sed -n 2p "$CSV" | cut -d, -f1)
last=$(tail -n 1 "$CSV" | cut -d, -f1)
echo "sightings=$total   unique_bssid=$ubss   unique_ssid=$ussid"
echo "first=$first   last=$last"
echo
echo "# unique networks  (signal = best seen)"
printf "  %-5s %-17s %-4s %-22s %s\n" "SIG%" "BSSID" "CH" "SECURITY" "SSID"
tail -n +2 "$CSV" | awk -F, '
  { if($4+0 >= best[$3]+0){ best[$3]=$4; ch[$3]=$2; sec[$3]=$5; ss[$3]=$6 } }
  END{ for(b in best) printf "  %-5s %-17s %-4s %-22s %s\n", best[b], b, ch[b], sec[b], (ss[b]==""?"<hidden>":ss[b]) }
' | sort -rn | head -80
echo
echo "# channels seen:"
tail -n +2 "$CSV" | cut -d, -f2 | sort -n | uniq -c | awk '{printf " ch%s:%s", $2, $1}'; echo
echo
echo "# raw CSV download: wardrive.cgi?a=csv"
