#!/bin/sh
PATH=/tmp/bin:$PATH; export PATH
a=$(echo "$QUERY_STRING" | sed -n 's/^.*a=\([^&]*\).*$/\1/p')
CSV=""
for V in /data/UsbDisk*/Volume*; do [ -f "$V/wardrive.csv" ] && CSV="$V/wardrive.csv" && break; done

if [ "$a" = csv ]; then
  echo "Content-type: text/csv"
  echo "Content-Disposition: attachment; filename=wardrive.csv"; echo
  [ -n "$CSV" ] && cat "$CSV"
  exit 0
fi

echo "Content-type: text/plain"; echo
[ -z "$CSV" ] && { echo "no wardrive.csv yet -- cron scans ra0 every 5 min; first scan may be pending."; echo "trigger one now from the command box:  /tmp/extern/opt/bin/wardrive.sh"; exit 0; }

total=$(( $(wc -l < "$CSV") - 1 ))
ubss=$(tail -n +2 "$CSV" | cut -d, -f3 | sort -u | wc -l)
ussid=$(tail -n +2 "$CSV" | cut -d, -f6 | grep -v '^$' | sort -u | wc -l)
first=$(sed -n 2p "$CSV" | cut -d, -f1)
last=$(tail -n 1 "$CSV" | cut -d, -f1)
echo "# wardrive log  ($CSV)"
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
