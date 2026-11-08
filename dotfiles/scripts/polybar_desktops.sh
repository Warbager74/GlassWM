#!/usr/bin/env bash
DESK=$(cat ~/.config/glasswm/current_desktop 2>/dev/null || echo "1")
OUT=""
for i in {1..9}; do
    if [ "$i" -eq "$DESK" ]; then
        OUT="$OUT %{F#a6e3a1}[$i]%{F-} "
    else
        OUT="$OUT %{F#585b70}$i%{F-} "
    fi
done
echo "$OUT"
