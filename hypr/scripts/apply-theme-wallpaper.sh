#!/usr/bin/env bash

set -euo pipefail

# Apply current theme wallpaper on startup
THEME_DIR="$HOME/.config/themes"

# Determine current theme by resolving the current theme config
CURRENT_THEME="unknown"
if [[ -L "$HOME/.config/hypr/current-theme.conf" ]]; then
  resolved=$(readlink -f "$HOME/.config/hypr/current-theme.conf" || true)
  if [[ "$resolved" == *"/themes/"* ]]; then
    CURRENT_THEME=$(basename "$(dirname "$resolved")")
  fi
fi

if [[ "$CURRENT_THEME" == "unknown" ]]; then
  # Fallback: check rofi theme
  if [[ -L "$HOME/.config/rofi/theme.rasi" ]]; then
    resolved=$(readlink -f "$HOME/.config/rofi/theme.rasi" || true)
    if [[ "$resolved" == *"/themes/"* ]]; then
      CURRENT_THEME=$(basename "$(dirname "$resolved")")
    fi
  fi
fi

if [[ "$CURRENT_THEME" == "unknown" || ! -d "$THEME_DIR/$CURRENT_THEME" ]]; then
  echo "Could not determine current theme, using default"
  exit 0
fi

# Find wallpaper for current theme
find_theme_wallpaper() {
  local tdir="$1"
  local wp=""
  # Common names/extensions
  for name in wallpaper background bg; do
    for ext in png jpg jpeg webp bmp; do
      if [[ -f "$tdir/$name.$ext" ]]; then
        wp="$tdir/$name.$ext"
        echo "$wp"
        return 0
      fi
    done
  done
  # Fallback: first image file in the directory
  while IFS= read -r -d '' f; do
    echo "$f"; return 0
  done < <(find "$tdir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \) -print0 | sort -z)
  return 1
}

# Apply wallpaper if found
if WP_PATH=$(find_theme_wallpaper "$THEME_DIR/$CURRENT_THEME"); then
  echo "Applying wallpaper for theme: $CURRENT_THEME"
  # Wait a moment for hyprpaper to be ready
  sleep 1

  # Apply via IPC
  if command -v hyprctl >/dev/null 2>&1; then
    # Preload the wallpaper
    hyprctl hyprpaper preload "$WP_PATH" >/dev/null 2>&1 || true

    # Get monitors and apply wallpaper
    if mons=$(hyprctl monitors -j 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d '"' -f4 | sort -u); then
      while IFS= read -r m; do
        [[ -n "$m" ]] || continue
        hyprctl hyprpaper wallpaper "$m,$WP_PATH" >/dev/null 2>&1 || true
      done <<< "$mons"
    fi

    # Hide splash
    hyprctl hyprpaper splash false >/dev/null 2>&1 || true
  fi
fi