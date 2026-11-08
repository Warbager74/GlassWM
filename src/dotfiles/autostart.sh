#!/usr/bin/env bash

# Kill old instances
killall -q picom polybar

# Apply default liquid wallpaper (or user wallpaper)
feh --bg-fill ~/.config/glasswm/wallpaper.jpg 2>/dev/null || xsetroot -solid "#12141c"

# Launch Liquid Glass compositor
picom --config ~/.config/glasswm/picom.conf &

# Launch macOS Top Bar
polybar -c ~/.config/glasswm/polybar.ini top &
