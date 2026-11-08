#!/usr/bin/env bash
while true; do
    if [ -s "$HOME/.config/glasswm/tasks_polybar" ]; then
        cat "$HOME/.config/glasswm/tasks_polybar"
        echo ""
    else
        echo "%{A1:firefox &:} 󰈹 %{A}   %{A1:thunar &:} 󰉋 %{A}   %{A1:kitty &:} 󰄛 %{A}   %{A1:code &:} 󰨞 %{A}   %{A1:spotify &:} 󰓇 %{A}"
    fi
    sleep 0.2
done
