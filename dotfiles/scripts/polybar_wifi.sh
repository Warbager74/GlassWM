#!/usr/bin/env bash
SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2)
if [ -n "$SSID" ]; then
    echo "󰤨 $SSID"
else
    echo "󰤭 Offline"
fi
