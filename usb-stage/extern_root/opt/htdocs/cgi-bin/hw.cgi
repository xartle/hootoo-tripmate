#!/bin/sh
echo "Content-type: text/plain"; echo
PATH=/tmp/bin:$PATH; export PATH
rd(){ cat "$1" 2>/dev/null; }
echo "battery=$(rd /proc/vs_battery_quantity)"
echo "device_status=$(rd /proc/vs_device_status)"
echo "net_link=$(rd /proc/vs_net_link_status)"
echo "apcli_status=$(rd /proc/vs_80211n_apcli0_connect_status)"
echo "led=$(rd /proc/vsled)"
echo "intled=$(rd /proc/vsintled)"
echo "netswitch=$(rd /proc/vsnetswitch)"
echo "keystate=$(rd /proc/vs_long_short_key_state)"
echo "uptime=$(cut -d. -f1 /proc/uptime)"
echo "loadavg=$(cut -d' ' -f1-3 /proc/loadavg)"
echo "memfree_kb=$(awk '/^MemFree/{print $2}' /proc/meminfo)"
echo "memtotal_kb=$(awk '/^MemTotal/{print $2}' /proc/meminfo)"
# model/version/vendor block
rd /proc/vstinfo | sed 's/^/info_/'
