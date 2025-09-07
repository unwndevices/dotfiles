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
# Use abstract socket (no PID appending, works across all instances)
kitty @ --to unix:@mykitty set-colors -a "$KITTY_CONF" 2>/dev/null || {
  # Fallback: Try to find any running kitty socket via filesystem
  for sock in /tmp/kitty-theme-sock* /tmp/kitty*; do
    if [[ -S "$sock" ]]; then
      kitty @ --to "unix:$sock" set-colors -a "$KITTY_CONF" 2>/dev/null && break
    fi
  done
}

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
