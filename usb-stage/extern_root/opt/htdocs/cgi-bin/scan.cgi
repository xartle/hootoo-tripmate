#!/bin/sh
echo "Content-type: text/plain"; echo
PATH=/tmp/bin:$PATH; export PATH
q="$QUERY_STRING"
getp(){ echo "$q" | sed -n "s/^.*[?&]*$1=\([^&]*\).*\$/\1/p"; }
a=$(getp a); host=$(getp host); p=$(getp p)
host=$(echo "$host" | sed 's/[^A-Za-z0-9._-]//g')      # sanitize
W=2                                                     # per-port timeout (s)

case "$a" in
  arp)
    echo "# neighbors seen by trippy (ARP table)"
    cat /proc/net/arp
    ;;
  *)
    [ -z "$host" ] && { echo "usage: scan.cgi?host=H[&p=22,80,443 | p=1-1024]   (or a=arp)"; exit 0; }
    [ -z "$p" ] && p="21,22,23,25,53,80,81,110,139,143,443,445,554,631,3389,5000,8080,8200,8443,8800,9000"
    echo "# TCP connect-scan of $host  (timeout ${W}s/port; open ports only)"
    found=0
    OLDIFS=$IFS; IFS=','
    for tok in $p; do
      case "$tok" in
        *-*) lo=$(echo "${tok%-*}" | sed 's/[^0-9]//g'); hi=$(echo "${tok#*-}" | sed 's/[^0-9]//g')
             [ -z "$lo" -o -z "$hi" ] && continue
             ports=$(seq "$lo" "$hi") ;;
        *)   ports=$(echo "$tok" | sed 's/[^0-9]//g') ;;
      esac
      for port in $ports; do
        [ -z "$port" ] && continue
        if nc -w "$W" "$host" "$port" </dev/null >/dev/null 2>&1; then
          printf "  %-5s open\n" "$port"; found=$((found+1))
        fi
      done
    done
    IFS=$OLDIFS
    echo "# done ($found open)"
    ;;
esac
