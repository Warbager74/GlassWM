#!/usr/bin/env bash

# 1. Determine screen resolution dynamically
RES=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2}')
if [ -z "$RES" ]; then
    RES="1920x1080"
fi
WIDTH=$(echo "$RES" | cut -d'x' -f1)
HEIGHT=$(echo "$RES" | cut -d'x' -f2)

CX=$((WIDTH / 2))
CY=$((HEIGHT / 2))

# Positions scaled proportionally to any display resolution
DATE_Y=$((HEIGHT * 16 / 100))
TIME_Y=$((HEIGHT * 26 / 100))
AVATAR_Y=$((HEIGHT * 45 / 100))
AVATAR_TEXT_Y=$((AVATAR_Y + 12))
USER_Y=$((AVATAR_Y + 68))
PILL_Y=$((USER_Y + 28))
PILL_X=$((CX - 120))

DATE_TEXT="$(date '+%A, %B %-d')"
TIME_TEXT="$(date '+%-I:%M')"
USER_NAME="$USER"
INITIAL="$(echo "$USER" | cut -c 1 | tr 'a-z' 'A-Z')"

# 2. Get wallpaper path
WP_IMG="$HOME/.config/glasswm/wallpapers/lumen_liquid.ppm"
if [ -f "$HOME/.config/glasswm/current_wallpaper" ]; then
    WP_IMG="$(cat "$HOME/.config/glasswm/current_wallpaper")"
fi

LOCK_SVG="/tmp/lumen_lock.svg"
LOCK_PNG="/tmp/lumen_lock_rendered.png"

# 3. Render pixel-perfect SVG template matching Image 5
cat << SVG_EOF > "$LOCK_SVG"
<svg width="${WIDTH}" height="${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="20" />
    </filter>
  </defs>

  <!-- Blurred Wallpaper Background -->
  <image href="${WP_IMG}" width="${WIDTH}" height="${HEIGHT}" preserveAspectRatio="xMidYMid slice" filter="url(#blur)" />
  <rect width="${WIDTH}" height="${HEIGHT}" fill="rgba(10, 12, 18, 0.35)" />

  <!-- Date & Huge Bold Time -->
  <text x="${CX}" y="${DATE_Y}" font-family="JetBrainsMono Nerd Font, -apple-system, sans-serif" font-size="24" font-weight="500" fill="#f5f5f7" text-anchor="middle">${DATE_TEXT}</text>
  <text x="${CX}" y="${TIME_Y}" font-family="JetBrainsMono Nerd Font, -apple-system, sans-serif" font-size="96" font-weight="700" fill="#ffffff" text-anchor="middle">${TIME_TEXT}</text>

  <!-- User Avatar Circle with Initial -->
  <circle cx="${CX}" cy="${AVATAR_Y}" r="40" fill="rgba(255, 255, 255, 0.16)" stroke="rgba(255, 255, 255, 0.28)" stroke-width="1.5" />
  <text x="${CX}" y="${AVATAR_TEXT_Y}" font-family="JetBrainsMono Nerd Font, -apple-system, sans-serif" font-size="32" font-weight="700" fill="#ffffff" text-anchor="middle">${INITIAL}</text>

  <!-- Username -->
  <text x="${CX}" y="${USER_Y}" font-family="JetBrainsMono Nerd Font, -apple-system, sans-serif" font-size="18" font-weight="500" fill="#cdd6f4" text-anchor="middle">${USER_NAME}</text>

  <!-- Password Capsule Pill (Image 5) -->
  <rect x="${PILL_X}" y="${PILL_Y}" width="240" height="42" rx="21" fill="rgba(255, 255, 255, 0.08)" stroke="rgba(255, 255, 255, 0.22)" stroke-width="1" />
  
  <!-- Password dots -->
  <circle cx="$((PILL_X + 32))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />
  <circle cx="$((PILL_X + 46))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />
  <circle cx="$((PILL_X + 60))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />
  <circle cx="$((PILL_X + 74))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />
  <circle cx="$((PILL_X + 88))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />
  <circle cx="$((PILL_X + 102))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />
  <circle cx="$((PILL_X + 116))" cy="$((PILL_Y + 21))" r="3.5" fill="#a6adc8" />

  <!-- Arrow Button -->
  <circle cx="$((PILL_X + 218))" cy="$((PILL_Y + 21))" r="14" fill="rgba(255, 255, 255, 0.16)" />
  <text x="$((PILL_X + 218))" y="$((PILL_Y + 26))" font-family="JetBrainsMono Nerd Font, sans-serif" font-size="14" fill="#ffffff" text-anchor="middle">→</text>

  <!-- Bottom Power Icons -->
  <g fill="#7a7c8d" font-family="JetBrainsMono Nerd Font, sans-serif" font-size="13">
    <!-- Sleep -->
    <circle cx="$((CX - 120))" cy="$((HEIGHT - 80))" r="18" fill="rgba(255, 255, 255, 0.08)" />
    <text x="$((CX - 120))" y="$((HEIGHT - 75))" text-anchor="middle" font-size="14" fill="#bac2de">󰤄</text>
    <text x="$((CX - 120))" y="$((HEIGHT - 45))" text-anchor="middle">Sleep</text>

    <!-- Restart -->
    <circle cx="${CX}" cy="$((HEIGHT - 80))" r="18" fill="rgba(255, 255, 255, 0.08)" />
    <text x="${CX}" y="$((HEIGHT - 75))" text-anchor="middle" font-size="14" fill="#bac2de">󰜉</text>
    <text x="${CX}" y="$((HEIGHT - 45))" text-anchor="middle">Restart</text>

    <!-- Shut Down -->
    <circle cx="$((CX + 120))" cy="$((HEIGHT - 80))" r="18" fill="rgba(255, 255, 255, 0.08)" />
    <text x="$((CX + 120))" y="$((HEIGHT - 75))" text-anchor="middle" font-size="14" fill="#bac2de">󰐥</text>
    <text x="$((CX + 120))" y="$((HEIGHT - 45))" text-anchor="middle">Shut Down</text>
  </g>

  <!-- Bottom-Left Lumen Pill -->
  <rect x="30" y="$((HEIGHT - 55))" width="84" height="28" rx="14" fill="rgba(255, 255, 255, 0.08)" />
  <text x="72" y="$((HEIGHT - 37))" font-family="JetBrainsMono Nerd Font, sans-serif" font-size="12" fill="#bac2de" text-anchor="middle">Lumen 󰁝</text>
</svg>
SVG_EOF

# 4. Convert SVG to PNG
magick "$LOCK_SVG" "$LOCK_PNG"

# 5. Lock screen with -u flag to completely hide the weird default i3lock ring
i3lock -u -i "$LOCK_PNG" -n
