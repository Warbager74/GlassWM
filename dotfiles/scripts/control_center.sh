#!/usr/bin/env bash
ROFI_THEME="$HOME/.config/glasswm/rofi/control.rasi"

ACTION=$(echo -e "🖼️  Wallpaper Center (Custom & Presets)\n󰤨  Wi-Fi Networks (Scan & Connect)\n󰖩  Toggle Wi-Fi (On / Off)\n󰂯  Bluetooth Manager\n󰓅  Power Profiles (Performance / Balanced / Saver)\n󰕾  Audio Mixer (Pavucontrol)\n󰝟  Toggle Audio Mute\n󰎆  Media: Play / Pause\n󰒭  Media: Next Track\n📸  Take Screenshot (5s delay)\n🌙  Toggle Night Light (Warm Display)\n🖥️  Display & Monitor Setup (Arandr)\n󰜉  Reload Desktop (Restart Bars & Glass)\n🔒  Lock Screen\n󰤆  Sleep / Suspend\n󰐥  Reboot\n󰐥  Power Off" | rofi -dmenu -p "Control Center" -theme "$ROFI_THEME")

case "$ACTION" in
    *"Wallpaper Center"*)
        bash ~/.config/glasswm/scripts/wallpaper_manager.sh
        ;;
    *"Wi-Fi Networks"*)
        bash ~/.config/glasswm/scripts/wifi_menu.sh
        ;;
    *"Toggle Wi-Fi"*)
        STATUS=$(nmcli radio wifi)
        if [ "$STATUS" = "enabled" ]; then
            nmcli radio wifi off
            notify-send "Network" "Wi-Fi disabled"
        else
            nmcli radio wifi on
            notify-send "Network" "Wi-Fi enabled"
        fi
        ;;
    *"Bluetooth"*)
        blueman-manager 2>/dev/null || notify-send "Bluetooth" "Install blueman for GUI manager (sudo pacman -S blueman)"
        ;;
    *"Power Profiles"*)
        bash ~/.config/glasswm/scripts/power_menu.sh
        ;;
    *"Audio Mixer"*)
        pavucontrol &
        ;;
    *"Toggle Audio Mute"*)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        notify-send "Audio" "Mute toggled"
        ;;
    *"Play / Pause"*)
        playerctl play-pause 2>/dev/null || notify-send "Media" "No media player active"
        ;;
    *"Next Track"*)
        playerctl next 2>/dev/null || notify-send "Media" "No media player active"
        ;;
    *"Take Screenshot"*)
        notify-send "Screenshot" "Capturing in 3 seconds..."
        sleep 3
        mkdir -p ~/Pictures/Screenshots
        OUT_FILE="$HOME/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png"
        import -window root "$OUT_FILE" 2>/dev/null || maim "$OUT_FILE" 2>/dev/null || scrot "$OUT_FILE" 2>/dev/null
        notify-send "Screenshot Saved" "$OUT_FILE"
        ;;
    *"Night Light"*)
        # Simple redshift or sct warm temperature toggle
        if pgrep -x redshift >/dev/null; then
            killall -q redshift
            notify-send "Display" "Night Light turned OFF"
        else
            redshift -O 4200 2>/dev/null || sct 4200 2>/dev/null || notify-send "Display" "Install sct or redshift for Night Light"
            notify-send "Display" "Night Light turned ON (4200K)"
        fi
        ;;
    *"Display & Monitor"*)
        arandr 2>/dev/null || xrandr
        ;;
    *"Reload Desktop"*)
        killall -q polybar picom
        sleep 0.4
        picom --config ~/.config/glasswm/picom.conf &
        polybar -c ~/.config/glasswm/polybar.ini macos-top &
        polybar -c ~/.config/glasswm/polybar.ini lumen-dock &
        notify-send "Desktop" "Bars and Compositor reloaded!"
        ;;
    *"Lock Screen"*)
        loginctl lock-session 2>/dev/null || slock 2>/dev/null || true
        ;;
    *"Sleep"*)
        systemctl suspend
        ;;
    *"Reboot"*)
        CONFIRM=$(echo -e "No\nYes, Reboot" | rofi -dmenu -p "Are you sure?" -theme "$ROFI_THEME")
        if [ "$CONFIRM" = "Yes, Reboot" ]; then
            systemctl reboot
        fi
        ;;
    *"Power Off"*)
        CONFIRM=$(echo -e "No\nYes, Power Off" | rofi -dmenu -p "Are you sure?" -theme "$ROFI_THEME")
        if [ "$CONFIRM" = "Yes, Power Off" ]; then
            systemctl poweroff
        fi
        ;;
esac
