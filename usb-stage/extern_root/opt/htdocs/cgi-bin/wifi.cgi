#!/bin/sh
echo "Content-type: text/plain"; echo
PATH=/tmp/bin:$PATH; export PATH
a=$(echo "$QUERY_STRING" | sed -n 's/^.*a=\([^&]*\).*$/\1/p')
IF=apcli0; [ -e /proc/net/dev ] && grep -q ra0 /proc/net/dev && RADIO=ra0 || RADIO=ra0
case "$a" in
  scan)
    echo "# triggering Ralink site survey on $RADIO ..."
    iwpriv $RADIO set SiteSurvey=1 2>&1
    sleep 4
    echo "# results:"
    iwpriv $RADIO get_site_survey 2>&1
    ;;
  *)
    echo "# cached scan results"
    cat /tmp/ap_list.out 2>/dev/null || echo "(no cached results; use ?a=scan)"
    echo
    echo "# current association"
    iwconfig 2>/dev/null | grep -E "ESSID|Access Point" | sed 's/^/  /'
    ;;
esac
