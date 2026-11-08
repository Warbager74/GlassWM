#!/usr/bin/env bash
CHOICE=$(echo -e "  Edit GlassWM Config\n🎨 Edit Picom Liquid Glass\n📊 Audio Settings (Pavucontrol)\n🖥️  Display Configuration (Arandr)\n🖼️  Wallpaper Selection" | rofi -dmenu -p "Settings" -theme ~/.config/glasswm/rofi/control.rasi)
case "$CHOICE" in
    *"GlassWM Config"*) alacritty -e nano ~/.config/glasswm/config.toml & ;;
    *"Picom"*) alacritty -e nano ~/.config/glasswm/picom.conf & ;;
    *"Audio"*) pavucontrol & ;;
    *"Display"*) arandr & ;;
    *"Wallpaper"*) bash ~/.config/glasswm/scripts/wallpaper_picker.sh & ;;
esac
