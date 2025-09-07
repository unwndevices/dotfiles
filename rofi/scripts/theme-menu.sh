#!/usr/bin/env bash

set -euo pipefail

THEME_DIR="$HOME/.config/themes"

declare -A THEME_LABELS=(
  ["rose-pine"]="🌹 Rose Pine"
  ["monochrome"]="⚫ Monochrome"
)

# Determine current theme by resolving rofi's theme link if present
CURRENT="unknown"
if [[ -L "$HOME/.config/rofi/theme.rasi" ]]; then
  resolved=$(readlink -f "$HOME/.config/rofi/theme.rasi" || true)
  # Expect path like ~/.config/themes/<theme>/rofi-theme.rasi
  if [[ "$resolved" == *"/themes/"* ]]; then
    CURRENT=$(basename "$(dirname "$resolved")")
  fi
fi

# Collect themes
entries=()
while IFS= read -r -d '' dir; do
  name=$(basename "$dir")
  label=${THEME_LABELS[$name]:-$name}
  if [[ "$name" == "$CURRENT" ]]; then
    entries+=("$label [current]")
  else
    entries+=("$label")
  fi
done < <(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
entries+=("󰅖 Cancel")

choice=$(printf '%s\n' "${entries[@]}" | rofi -dmenu \
  -p "Theme" \
  -theme "$HOME/.config/rofi/menu.rasi" \
  -theme-str "window { width: 480px; }" \
  -theme-str "listview { lines: 6; }")

case "$choice" in
  *Rose\ Pine*) exec "$HOME/.config/rofi/scripts/theme-switcher.sh" rose-pine ;;
  *Monochrome*) exec "$HOME/.config/rofi/scripts/theme-switcher.sh" monochrome ;;
  *Cancel*|"") exit 0 ;;
  *)
    # Fallback: map label back to key
    for key in "${!THEME_LABELS[@]}"; do
      if [[ "$choice" == *"${THEME_LABELS[$key]}"* ]]; then
        exec "$HOME/.config/rofi/scripts/theme-switcher.sh" "$key"
      fi
    done
    ;;
esac

