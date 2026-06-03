#!/bin/sh
# Undo everything startup.sh did (no reboot needed).
echo "[*] stopping control-panel httpd (matches 'httpd -p' in cmdline)..."
for p in $(ps | grep 'httpd -p' | grep -v grep | awk '{print $1}'); do
    kill "$p" 2>/dev/null && echo "    killed pid $p"
done
echo "[*] removing stock-UI skin bind-mount (if any)..."
grep -q " /www/app/main.html " /proc/mounts && umount /www/app/main.html
echo "[*] leaving /tmp/bin + /tmp/extern in place (harmless; gone on reboot)."
echo "[*] to fully revert now: reboot, or 'umount /tmp/extern; rm -rf /tmp/bin'."
echo "done."
