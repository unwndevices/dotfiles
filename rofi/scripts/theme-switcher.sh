#!/usr/bin/env bash

set -euo pipefail

THEME_DIR="$HOME/.config/themes"

THEME_NAME="${1:-}"
if [[ -z "$THEME_NAME" ]]; then
  echo "Usage: $0 <theme-name>" >&2
  exit 1
fi

if [[ ! -d "$THEME_DIR/$THEME_NAME" ]]; then
  echo "Theme '$THEME_NAME' not found in $THEME_DIR" >&2
  exit 1
fi

echo "Switching to $THEME_NAME..."

# Kitty
mkdir -p "$HOME/.config/kitty"
ln -sf "$THEME_DIR/$THEME_NAME/kitty.conf" "$HOME/.config/kitty/current-theme.conf"

# Waybar
mkdir -p "$HOME/.config/waybar"
ln -sf "$THEME_DIR/$THEME_NAME/waybar-colors.css" "$HOME/.config/waybar/colors.css"

# Rofi
mkdir -p "$HOME/.config/rofi"
ln -sf "$THEME_DIR/$THEME_NAME/rofi-theme.rasi" "$HOME/.config/rofi/theme.rasi"

# Neovim (relative symlink inside lua/plugins)
mkdir -p "$HOME/.config/nvim/lua/plugins"
(cd "$HOME/.config/nvim/lua/plugins" && ln -sf ../../../themes/"$THEME_NAME"/nvim-colorscheme.lua colorscheme.lua)

# GTK3/Thunar if provided
if [[ -f "$THEME_DIR/$THEME_NAME/gtk-settings.ini" ]]; then
  mkdir -p "$HOME/.config/gtk-3.0"
  ln -sf "$THEME_DIR/$THEME_NAME/gtk-settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
fi

echo "Reloading apps..."

# Kitty: fast, no-window reloads using control sockets
KITTY_CONF="$HOME/.config/kitty/current-theme.conf"
sent=false
# 1) Try the configured abstract socket name
if kitty @ --to unix:@kitty --timeout 0.15 set-colors -a "$KITTY_CONF" >/dev/null 2>&1; then
  sent=true
else
  # 2) Probe running kitty processes for their KITTY_LISTEN_ON and send there
  if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -x kitty 2>/dev/null); do
      if [[ -r "/proc/$pid/environ" ]]; then
        sock=$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^KITTY_LISTEN_ON=//p' | head -n1)
        if [[ -n "$sock" ]]; then
          if kitty @ --to "$sock" --timeout 0.15 set-colors -a "$KITTY_CONF" >/dev/null 2>&1; then
            sent=true
            break
          fi
        fi
      fi
    done
  fi
fi

# Waybar (SIGUSR2 makes it reload CSS)
pkill -SIGUSR2 waybar 2>/dev/null || true

# Hyprland: switch theme include and reload
mkdir -p "$HOME/.config/hypr"
ln -sf "$THEME_DIR/$THEME_NAME/hypr.conf" "$HOME/.config/hypr/current-theme.conf"
hyprctl reload 2>/dev/null || true

# Rofi uses static theme files; no reload needed

# GTK theme via xfconf if available (theme name may differ; best-effort)
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xsettings -p /Net/ThemeName -s "$THEME_NAME" 2>/dev/null || true
fi

echo "Done: theme switched to $THEME_NAME"
