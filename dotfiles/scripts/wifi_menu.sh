#!/usr/bin/env bash
SSID_LIST=$(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | awk -F: '$1 != "" {print $1 "  (" $2 "% " $3 ")"}')
if [ -n "$SSID_LIST" ]; then
    SELECTED=$(echo -e "$SSID_LIST\nDisconnect\nTurn Wi-Fi Off" | rofi -dmenu -p "Wi-Fi Networks" -theme ~/.config/glasswm/rofi/control.rasi)
    SSID=$(echo "$SELECTED" | awk '{print $1}')
    if [ "$SELECTED" = "Disconnect" ]; then
        nmcli dev disconnect wlan0 2>/dev/null || nmcli dev disconnect wlp*
    elif [ "$SELECTED" = "Turn Wi-Fi Off" ]; then
        nmcli radio wifi off
    elif [ -n "$SSID" ]; then
        PASS=$(rofi -dmenu -password -p "Password for $SSID" -theme ~/.config/glasswm/rofi/control.rasi)
        if [ -n "$PASS" ]; then
            nmcli dev wifi connect "$SSID" password "$PASS"
        else
            nmcli dev wifi connect "$SSID"
        fi
    fi
fi
