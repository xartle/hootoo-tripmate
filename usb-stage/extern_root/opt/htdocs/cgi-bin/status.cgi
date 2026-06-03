#!/bin/sh
echo "Content-type: text/plain"; echo
PATH=/tmp/bin:$PATH; export PATH
echo "## system"
uname -a
echo "date:   $(date)"
echo "uptime: $(cut -d' ' -f1 /proc/uptime)s"
echo
echo "## memory";  free
echo
echo "## storage"; df -h
echo
echo "## network"
ifconfig 2>/dev/null | grep -E "Link|inet addr" | sed 's/^ */  /'
echo "  routes:"; route -n 2>/dev/null | grep -E "^[0-9]" | sed 's/^/    /'
echo
echo "## wifi (this device)"
grep -E "^SSID1=|^Channel=|AuthMode=|ApCliSsid1=|ApCliAuthMode=" \
     /boot/tmp/etc/Wireless/RT2860/RT2860.dat 2>/dev/null | sed 's/^/  /'
echo
echo "## listeners"; netstat -ltn 2>/dev/null | grep LISTEN | sed 's/^/  /'
echo
echo "## processes (top mem)"; ps 2>/dev/null | head -25
