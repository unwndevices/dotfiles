#!/usr/bin/env bash

# Rofi selector for Linux power profiles via powerprofilesctl
# Profiles typically include: performance, balanced, power-saver

set -euo pipefail

THEME_FILE="$HOME/.config/rofi/menu.rasi"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 not found" >&2
    rofi -e "$1 is not installed. Please install it first." || true
    exit 1
  fi
}

require_cmd rofi
require_cmd powerprofilesctl

# Determine current profile
current_profile=$(powerprofilesctl get 2>/dev/null || true)

# Extract available profiles robustly from various output formats
readarray -t available < <(powerprofilesctl list 2>/dev/null \
  | sed -n 's/^\s*\*\{0,1\}\s*\([a-z-]\+\)[:\s]*$/\1/p' \
  | sort -u)

# Fallback to standard set if parsing failed
if [[ ${#available[@]} -eq 0 ]]; then
  available=(performance balanced power-saver)
fi

# Keep a stable order: performance, balanced, power-saver, then any others
ordered=()
for k in performance balanced power-saver; do
  for a in "${available[@]}"; do
    [[ "$a" == "$k" ]] && ordered+=("$a")
  done
done
for a in "${available[@]}"; do
  if [[ ! " ${ordered[*]} " =~ \ ${a}\  ]]; then
    ordered+=("$a")
  fi
done

icon_for() {
  case "$1" in
    performance) echo "⚡" ;;
    balanced)    echo "" ;;
    power-saver) echo "🔋" ;;
    *)           echo "•" ;;
  esac
}

label_for() {
  case "$1" in
    performance) echo "Performance" ;;
    balanced)    echo "Balanced" ;;
    power-saver) echo "Power Saver" ;;
    *)           echo "$1" ;;
  esac
}

current_line="Current: $(label_for "${current_profile:-unknown}")"

entries=("$current_line")
for p in "${ordered[@]}"; do
  icon=$(icon_for "$p")
  label=$(label_for "$p")
  if [[ "$p" == "$current_profile" ]]; then
    entries+=("$icon  $label  (active)")
  else
    entries+=("$icon  $label")
  fi
done
entries+=("󰅖 Exit")

choice=$(printf '%s\n' "${entries[@]}" | \
  rofi -dmenu \
    -p "Power Profile" \
    -theme "$THEME_FILE" \
    -theme-str "window { width: 420px; }" \
    -theme-str "listview { lines: 7; }")

case "$choice" in
  ""|"󰅖 Exit")
    exit 0 ;;
  "Current:"*)
    exit 0 ;;
  *)
    # Map selection text back to profile key
    target=""
    for p in "${ordered[@]}"; do
      label=$(label_for "$p")
      if [[ "$choice" == *"$label"* ]]; then
        target="$p"
        break
      fi
    done
    if [[ -n "$target" && "$target" != "$current_profile" ]]; then
      if powerprofilesctl set "$target"; then
        command -v notify-send >/dev/null 2>&1 && \
          notify-send "Power Profile" "Set to $(label_for "$target")" -i preferences-system-power || true
      fi
    fi
    ;;
esac
