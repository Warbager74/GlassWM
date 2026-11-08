#!/usr/bin/env bash
WP_DIR="$HOME/.config/glasswm/wallpapers"
if [ ! -f "$WP_DIR/1_deep_ocean.ppm" ]; then
    python3 "$HOME/.config/glasswm/scripts/generate_wallpapers.py"
fi
CHOSEN=$(echo -e "1. 🌊 Deep Ocean (Liquid Blue)\n2. 🌸 Violet Sunset (Cyber Glass)\n3. 🌲 Emerald Aurora (Nordic Glass)\n4. 🖤 Midnight Obsidian (Minimalist)" | rofi -dmenu -p "Select Wallpaper" -theme ~/.config/glasswm/rofi/control.rasi)
case "$CHOSEN" in
    *"Deep Ocean"*) TARGET="$WP_DIR/1_deep_ocean.ppm" ;;
    *"Violet Sunset"*) TARGET="$WP_DIR/2_violet_sunset.ppm" ;;
    *"Emerald Aurora"*) TARGET="$WP_DIR/3_emerald_aurora.ppm" ;;
    *"Midnight Obsidian"*) TARGET="$WP_DIR/4_midnight_obsidian.ppm" ;;
    *) TARGET="" ;;
esac
if [ -n "$TARGET" ]; then
    echo "$TARGET" > "$HOME/.config/glasswm/current_wallpaper"
    feh --bg-fill "$TARGET"
fi
