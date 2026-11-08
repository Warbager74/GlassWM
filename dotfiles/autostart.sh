#!/usr/bin/env bash
killall -q picom polybar

# Generate the fluid mesh wallpaper if missing
if [ ! -f "$HOME/.config/glasswm/wallpapers/lumen_liquid.ppm" ]; then
    python3 "$HOME/.config/glasswm/scripts/generate_lumen_wallpaper.py"
fi

feh --bg-fill "$HOME/.config/glasswm/wallpapers/lumen_liquid.ppm" &

# Launch hardware-accelerated compositor & bars
picom --config ~/.config/glasswm/picom.conf &
polybar -c ~/.config/glasswm/polybar.ini macos-top &
polybar -c ~/.config/glasswm/polybar.ini lumen-dock &
