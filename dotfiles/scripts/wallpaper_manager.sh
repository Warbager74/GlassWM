#!/usr/bin/env bash
WP_DIR="$HOME/.config/glasswm/wallpapers"
PIC_DIR="$HOME/Pictures"
DL_DIR="$HOME/Downloads"
ROFI_THEME="$HOME/.config/glasswm/rofi/control.rasi"

# Ensure built-in liquid presets exist
if [ ! -f "$WP_DIR/1_deep_ocean.ppm" ]; then
    python3 "$HOME/.config/glasswm/scripts/generate_lumen_wallpaper.py" 2>/dev/null || true
fi

ACTION=$(echo -e "📂 Browse Images in ~/Pictures & ~/Downloads\n🔗 Set from URL (Download & Apply)\n✏️  Type Direct File Path\n🎲 Random Wallpaper from ~/Pictures\n🌊 Preset: Deep Ocean Glass\n🌸 Preset: Violet Sunset Glass\n🌲 Preset: Emerald Aurora Glass\n🖤 Preset: Midnight Obsidian Glass" | rofi -dmenu -p "Wallpaper Center" -theme "$ROFI_THEME")

apply_wp() {
    local target="$1"
    if [ -f "$target" ]; then
        echo "$target" > "$HOME/.config/glasswm/current_wallpaper"
        feh --bg-fill "$target"
        notify-send "Wallpaper" "Applied: $(basename "$target")"
    else
        notify-send "Wallpaper Error" "File not found: $target"
    fi
}

case "$ACTION" in
    *"Browse Images"*)
        # Find all images in Pictures and Downloads
        IMG_LIST=$(find "$PIC_DIR" "$DL_DIR" "$WP_DIR" -maxdepth 3 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.ppm" \) 2>/dev/null)
        if [ -z "$IMG_LIST" ]; then
            notify-send "Wallpaper" "No images found in ~/Pictures or ~/Downloads."
            exit 0
        fi

        # Format list: display filename on left, full path for execution
        CHOSEN_LINE=$(echo "$IMG_LIST" | while read -r line; do
            echo "$(basename "$line") | $line"
        done | rofi -dmenu -p "Select Image" -theme "$ROFI_THEME")

        REAL_FILE=$(echo "$CHOSEN_LINE" | awk -F ' \\| ' '{print $2}')
        if [ -n "$REAL_FILE" ]; then
            apply_wp "$REAL_FILE"
        fi
        ;;

    *"Set from URL"*)
        URL=$(rofi -dmenu -p "Paste Image URL (http/https)" -theme "$ROFI_THEME")
        if [[ "$URL" =~ ^https?:// ]]; then
            TARGET_FILE="$WP_DIR/custom_$(date +%s).jpg"
            notify-send "Wallpaper" "Downloading custom image..."
            curl -sLo "$TARGET_FILE" "$URL"
            if [ -s "$TARGET_FILE" ]; then
                apply_wp "$TARGET_FILE"
            else
                notify-send "Wallpaper Error" "Failed to download image from URL."
            fi
        fi
        ;;

    *"Type Direct File Path"*)
        INPUT_PATH=$(rofi -dmenu -p "Enter full file path" -theme "$ROFI_THEME")
        # Expand tilde
        EXPANDED_PATH="${INPUT_PATH/#\~/$HOME}"
        if [ -n "$EXPANDED_PATH" ]; then
            apply_wp "$EXPANDED_PATH"
        fi
        ;;

    *"Random Wallpaper"*)
        RAND_IMG=$(find "$PIC_DIR" -maxdepth 3 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)
        if [ -n "$RAND_IMG" ]; then
            apply_wp "$RAND_IMG"
        else
            notify-send "Wallpaper" "No images found in ~/Pictures to randomize."
        fi
        ;;

    *"Deep Ocean"*)
        apply_wp "$WP_DIR/1_deep_ocean.ppm"
        ;;
    *"Violet Sunset"*)
        apply_wp "$WP_DIR/2_violet_sunset.ppm"
        ;;
    *"Emerald Aurora"*)
        apply_wp "$WP_DIR/3_emerald_aurora.ppm"
        ;;
    *"Midnight Obsidian"*)
        apply_wp "$WP_DIR/4_midnight_obsidian.ppm"
        ;;
esac
