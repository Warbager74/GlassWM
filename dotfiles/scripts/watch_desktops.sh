#!/usr/bin/env bash
while true; do
    if [ -s "$HOME/.config/glasswm/desktop_polybar" ]; then
        cat "$HOME/.config/glasswm/desktop_polybar"
        echo ""
    else
        echo "%{B#8c7ae6}%{F#ffffff}  1  %{F-}%{B-} %{F#6c7086} 2  3  4  5  6  7  8  9 %{F-}"
    fi
    sleep 0.15
done
