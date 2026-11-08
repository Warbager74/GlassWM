#!/usr/bin/env bash
CHOICE=$(echo -e "󰓅 Performance\n󰾆 Balanced\n󰾆 Power-saver" | rofi -dmenu -p "Power Profile" -theme ~/.config/glasswm/rofi/control.rasi)
case "$CHOICE" in
    *"Performance"*)
        powerprofilesctl set performance 2>/dev/null || true
        echo "performance" > ~/.config/glasswm/current_power
        ;;
    *"Balanced"*)
        powerprofilesctl set balanced 2>/dev/null || true
        echo "balanced" > ~/.config/glasswm/current_power
        ;;
    *"Power-saver"*)
        powerprofilesctl set power-saver 2>/dev/null || true
        echo "power-saver" > ~/.config/glasswm/current_power
        ;;
esac
