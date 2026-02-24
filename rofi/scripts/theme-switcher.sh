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

########################################
# GTK (3 and 4) if provided
########################################
if [[ -f "$THEME_DIR/$THEME_NAME/gtk-settings.ini" ]]; then
  GTK_INI="$THEME_DIR/$THEME_NAME/gtk-settings.ini"
  mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  ln -sf "$GTK_INI" "$HOME/.config/gtk-3.0/settings.ini"
  ln -sf "$GTK_INI" "$HOME/.config/gtk-4.0/settings.ini"

  # Read key values to apply via desktop settings when possible
  GTK_THEME_NAME=$(awk -F= '/^gtk-theme-name=/ {print $2}' "$GTK_INI" | tail -n1 || true)
  GTK_ICON_THEME=$(awk -F= '/^gtk-icon-theme-name=/ {print $2}' "$GTK_INI" | tail -n1 || true)
  GTK_CURSOR_THEME=$(awk -F= '/^gtk-cursor-theme-name=/ {print $2}' "$GTK_INI" | tail -n1 || true)
  GTK_PREFER_DARK=$(awk -F= '/^gtk-application-prefer-dark-theme=/ {print $2}' "$GTK_INI" | tail -n1 || true)

  # Best-effort: apply via gsettings when available
  if command -v gsettings >/dev/null 2>&1; then
    [[ -n "${GTK_THEME_NAME:-}" ]] && gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME" 2>/dev/null || true
    [[ -n "${GTK_ICON_THEME:-}" ]] && gsettings set org.gnome.desktop.interface icon-theme "$GTK_ICON_THEME" 2>/dev/null || true
    [[ -n "${GTK_CURSOR_THEME:-}" ]] && gsettings set org.gnome.desktop.interface cursor-theme "$GTK_CURSOR_THEME" 2>/dev/null || true
    if [[ "${GTK_PREFER_DARK:-}" == "1" ]]; then
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    elif [[ "${GTK_PREFER_DARK:-}" == "0" ]]; then
      gsettings set org.gnome.desktop.interface color-scheme 'default' 2>/dev/null || true
    fi
  fi

  # XFCE/XSettings (fallbacks)
  if command -v xfconf-query >/dev/null 2>&1; then
    [[ -n "${GTK_THEME_NAME:-}" ]] && xfconf-query -c xsettings -p /Net/ThemeName -s "$GTK_THEME_NAME" 2>/dev/null || true
    [[ -n "${GTK_ICON_THEME:-}" ]] && xfconf-query -c xsettings -p /Net/IconThemeName -s "$GTK_ICON_THEME" 2>/dev/null || true
    [[ -n "${GTK_CURSOR_THEME:-}" ]] && xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "$GTK_CURSOR_THEME" 2>/dev/null || true
  fi
fi

echo "Reloading apps..."

# Kitty: fast, no-window reloads using control sockets
KITTY_CONF="$HOME/.config/kitty/current-theme.conf"

# Helper to try setting colors via a given target
_try_kitty_target() {
  local target="$1"
  if [[ -n "$target" ]]; then
    kitty @ ${target:+--to "$target"} set-colors -a "$KITTY_CONF" 2>/dev/null && return 0
  fi
  return 1
}

# 1) Try $KITTY_LISTEN_ON first; do not abort if it fails
if ! _try_kitty_target "${KITTY_LISTEN_ON:-}"; then
  # 2) Try fixed abstract socket (matches kitty.conf listen_on)
  _try_kitty_target "unix:@mykitty" || {
    # 3) Try to find the main Kitty instance with --single-instance first
    # This is usually the instance that has remote control enabled
    main_kitty_pid=$(pgrep -f 'kitty.*--single-instance' 2>/dev/null | head -1 || true)
    if [[ -n "$main_kitty_pid" ]]; then
      _try_kitty_target "unix:@mykitty-$main_kitty_pid" || true
    else
      # Fallback: try all Kitty instances with timeout to avoid hanging
      while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        # Quick test with timeout to see if this PID has a working socket
        if timeout 0.3s kitty @ --to "unix:@mykitty-$pid" ls >/dev/null 2>&1; then
          _try_kitty_target "unix:@mykitty-$pid" || true
        fi
      done < <(pgrep -x kitty 2>/dev/null || true)
    fi
    # 4) Fallbacks: look under XDG_RUNTIME_DIR and /tmp for kitty sockets
    RDIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
    for path in \
      "$RDIR/kitty"* \
      "$RDIR/kitty"*"/*.sock" \
      /tmp/kitty-theme-sock* \
      /tmp/kitty*; do
      [[ -S "$path" ]] || continue
      if _try_kitty_target "unix:$path"; then
        break
      fi
    done
  }
fi

# Waybar (SIGUSR2 makes it reload CSS)
pkill -SIGUSR2 waybar 2>/dev/null || true

# Hyprland: switch theme include and reload
mkdir -p "$HOME/.config/hypr"
ln -sf "$THEME_DIR/$THEME_NAME/hypr.conf" "$HOME/.config/hypr/current-theme.conf"
hyprctl reload 2>/dev/null || true

# Rofi uses static theme files; no reload needed

########################################
# Hyprpaper: set wallpaper from theme
########################################

# Find a wallpaper image in the theme directory
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

# Collect monitor names from hyprctl (JSON preferred, plain as fallback)
get_monitors() {
  if command -v hyprctl >/dev/null 2>&1; then
    # Try JSON output first
    local json
    if json=$(hyprctl monitors -j 2>/dev/null); then
      echo "$json" | grep -o '"name":"[^"]*"' | cut -d '"' -f4 | sort -u
      return 0
    fi
    # Fallback to plain text parsing
    hyprctl monitors 2>/dev/null | awk '/Monitor / {print $2}' | sort -u
    return 0
  fi
  return 1
}

# Strict variant: returns non-zero if no monitors parsed
get_monitors_strict() {
  if command -v hyprctl >/dev/null 2>&1; then
    local json out
    if json=$(hyprctl monitors -j 2>/dev/null); then
      out=$(echo "$json" | grep -o '"name":"[^\"]*"' | cut -d '"' -f4 | sort -u || true)
      if [[ -n "$out" ]]; then
        printf '%s\n' "$out"
        return 0
      fi
    fi
    out=$(hyprctl monitors 2>/dev/null | awk '/Monitor / {print $2}' | sort -u || true)
    if [[ -n "$out" ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  return 1
}

apply_hyprpaper_ipc() {
  local wp="$1"
  # Best-effort live update via hyprctl hyprpaper (when hyprpaper IPC is enabled)
  if command -v hyprctl >/dev/null 2>&1; then
    local mons success=1 any=0
    # Collect monitors; if none, IPC path can't reliably apply
    if mons=$(get_monitors_strict); then
      # Preload may fail on old versions; ignore errors
      hyprctl hyprpaper preload "$wp" >/dev/null 2>&1 || true
      while IFS= read -r m; do
        [[ -n "$m" ]] || continue
        any=1
        if hyprctl hyprpaper wallpaper "$m,$wp" >/dev/null 2>&1; then
          success=0
        fi
      done <<< "$mons"
      # Hide splash if supported
      hyprctl hyprpaper splash false >/dev/null 2>&1 || true
      # success is 0 if at least one wallpaper call succeeded
      return $success
    fi
  fi
  return 1
}

apply_hyprpaper_via_config() {
  local wp="$1"
  local conf="$HOME/.config/hypr/hyprpaper.conf"
  mkdir -p "$HOME/.config/hypr"

  # Build a minimal config
  {
    echo "splash = false"
    echo "ipc = on"
    echo "preload = $wp"
    # Enumerate monitors if possible; otherwise fall back to default mapping
    local mons
    if mons=$(get_monitors_strict); then
      if [[ -n "$mons" ]]; then
        while IFS= read -r m; do
          [[ -n "$m" ]] || continue
          echo "wallpaper = $m, $wp"
        done <<< "$mons"
      else
        echo "wallpaper = , $wp"
      fi
    else
      # Apply to any monitor if hyprpaper accepts empty target (older hyprpaper may ignore this)
      echo "wallpaper = , $wp"
    fi
  } > "$conf"

  # Restart hyprpaper to pick up the new config
  if pgrep -x hyprpaper >/dev/null 2>&1; then
    pkill -x hyprpaper || true
    sleep 0.2
  fi
  if command -v hyprpaper >/dev/null 2>&1; then
    nohup hyprpaper -c "$conf" >/dev/null 2>&1 & disown || true
  fi
}

if WP_PATH=$(find_theme_wallpaper "$THEME_DIR/$THEME_NAME"); then
  # Try IPC first; if that doesn't work, fall back to config+restart
  apply_hyprpaper_ipc "$WP_PATH" || apply_hyprpaper_via_config "$WP_PATH"
fi

########################################
# Mako notifications: link per-theme config (no autogeneration)
########################################

# Supports either themes/<theme>/mako/config or themes/<theme>/mako.conf
if [[ -f "$THEME_DIR/$THEME_NAME/mako/config" ]]; then
  mkdir -p "$HOME/.config/mako"
  ln -sf "$THEME_DIR/$THEME_NAME/mako/config" "$HOME/.config/mako/config"
  command -v makoctl >/dev/null 2>&1 && makoctl reload >/dev/null 2>&1 || pkill -USR1 -x mako >/dev/null 2>&1 || true
elif [[ -f "$THEME_DIR/$THEME_NAME/mako.conf" ]]; then
  mkdir -p "$HOME/.config/mako"
  ln -sf "$THEME_DIR/$THEME_NAME/mako.conf" "$HOME/.config/mako/config"
  command -v makoctl >/dev/null 2>&1 && makoctl reload >/dev/null 2>&1 || pkill -USR1 -x mako >/dev/null 2>&1 || true
fi

########################################
# Zen Browser user CSS (userChrome/userContent) - Apply to ALL profiles
########################################

# Apply theme to all Zen profiles
ZEN_THEME_DIR="$THEME_DIR/$THEME_NAME/zen"
if [[ -d "$ZEN_THEME_DIR" ]]; then
  # Find all profile directories and apply theme to each
  for zen_profile in "$HOME"/.zen/*/; do
    # Skip if not a directory or if it's just the parent .zen folder
    [[ -d "$zen_profile" ]] || continue
    [[ "$(basename "$zen_profile")" == ".zen" ]] && continue
    
    # Create chrome directory for this profile
    ZEN_CHROME_DIR="$zen_profile/chrome"
    mkdir -p "$ZEN_CHROME_DIR" || true
    
    # Link theme CSS files to this profile
    [[ -f "$ZEN_THEME_DIR/userChrome.css" ]] && ln -sf "$ZEN_THEME_DIR/userChrome.css" "$ZEN_CHROME_DIR/userChrome.css" || true
    [[ -f "$ZEN_THEME_DIR/userContent.css" ]] && ln -sf "$ZEN_THEME_DIR/userContent.css" "$ZEN_CHROME_DIR/userContent.css" || true
    
    # Ensure userChrome is enabled for this profile
    USER_JS="$zen_profile/user.js"
    if [[ ! -f "$USER_JS" ]] || ! grep -q 'toolkit\.legacyUserProfileCustomizations\.stylesheets' "$USER_JS" 2>/dev/null; then
      echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$USER_JS" || true
    fi
    
    echo "Applied theme to profile: $(basename "$zen_profile")" || true
  done
fi

echo "Done: theme switched to $THEME_NAME"
