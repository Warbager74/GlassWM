#!/usr/bin/env bash
CURR=$(powerprofilesctl get 2>/dev/null || cat ~/.config/glasswm/current_power 2>/dev/null || echo "balanced")
case "$CURR" in
    *performance*) echo "󰓅 Perf" ;;
    *power-saver*) echo "󰾆 Quiet" ;;
    *) echo "󰾆 Bal" ;;
esac
