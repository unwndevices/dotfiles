#!/usr/bin/env bash

set -euo pipefail

# Waybar update checker and launcher
# - No args: prints JSON for Waybar (text, tooltip, class)
# - update: opens terminal and runs the appropriate system update
# - check-now: signals Waybar to refresh this module immediately

TERMINAL_CMD=(kitty -e bash -lc)
WAYBAR_SIGNAL_INDEX=8

have() { command -v "$1" >/dev/null 2>&1; }

pm_detect() {
  if have yay; then echo "yay"; return; fi
  if have paru; then echo "paru"; return; fi
  if have pacman; then echo "pacman"; return; fi
  if have apt; then echo "apt"; return; fi
  if have dnf; then echo "dnf"; return; fi
  if have zypper; then echo "zypper"; return; fi
  if have xbps-install; then echo "xbps"; return; fi
  if have apk; then echo "apk"; return; fi
  if have emerge; then echo "emerge"; return; fi
  if have brew; then echo "brew"; return; fi
  echo "unknown"
}

count_updates_pkg() {
  case "$(pm_detect)" in
    yay)
      yay -Qu 2>/dev/null | wc -l || echo 0 ;;
    paru)
      paru -Qu 2>/dev/null | wc -l || echo 0 ;;
    pacman)
      # Prefer checkupdates if available; fallback to pacman -Qu
      if have checkupdates; then
        checkupdates 2>/dev/null | wc -l || echo 0
      else
        pacman -Qu 2>/dev/null | wc -l || echo 0
      fi ;;
    apt)
      apt list --upgradable 2>/dev/null | sed '/Listing/d' | wc -l ;;
    dnf)
      # Count package lines from dnf check-update output
      dnf -q check-update 2>/dev/null | awk '/^[A-Za-z0-9_.+-]+\s+[0-9]/{print}' | wc -l ;;
    zypper)
      zypper lu -s 2>/dev/null | awk '/^v |^\+/{print}' | wc -l ;;
    xbps)
      xbps-install -nuM 2>/dev/null | wc -l ;;
    apk)
      apk version -l '<' 2>/dev/null | wc -l ;;
    emerge)
      emaint --check world 1>/dev/null 2>&1 || true
      equery -q l '*' 1>/dev/null 2>&1 || true
      # gentoolkit varies; fallback to 0
      echo 0 ;;
    brew)
      brew outdated 2>/dev/null | wc -l ;;
    *)
      echo 0 ;;
  esac
}

count_updates_flatpak() {
  if have flatpak; then
    flatpak remote-ls --updates 2>/dev/null | wc -l
  else
    echo 0
  fi
}

do_update() {
  local sys_cmd="" extra=""
  case "$(pm_detect)" in
    yay)    sys_cmd='yay -Syu' ;;
    paru)   sys_cmd='paru -Syu' ;;
    pacman) sys_cmd='sudo pacman -Syu' ;;
    apt)    sys_cmd='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y' ;;
    dnf)    sys_cmd='sudo dnf upgrade -y' ;;
    zypper) sys_cmd='sudo zypper refresh && sudo zypper dup -y' ;;
    xbps)   sys_cmd='sudo xbps-install -Suy' ;;
    apk)    sys_cmd='sudo apk update && sudo apk upgrade' ;;
    brew)   sys_cmd='brew update && brew upgrade' ;;
    *)
      notify-send "Waybar" "No known package manager found for updates" || true
      sys_cmd="" ;;
  esac

  if have flatpak; then
    extra='; echo; echo "— Flatpak updates —"; flatpak update'
  fi

  if [[ -n "$sys_cmd" || -n "$extra" ]]; then
    "${TERMINAL_CMD[@]}" "$sys_cmd$extra; echo; read -n1 -rsp 'Done. Press any key to close...'" &
  fi
}

emit_json() {
  local sys fp total icon cls tooltip
  sys=$(count_updates_pkg)
  fp=$(count_updates_flatpak)
  # Some commands may output nothing; normalize
  sys=${sys:-0}
  fp=${fp:-0}
  total=$(( sys + fp ))
  icon=""
  cls=""
  # Keep visible even at zero; do not hide automatically
  cls=""
  tooltip="System: ${sys}\nFlatpak: ${fp}"
  printf '{"text":"%s %s","tooltip":"%s","class":"%s"}\n' "$total" "$icon" "$tooltip" "$cls"
}

case "${1-}" in
  update)
    do_update ;;
  check-now)
    pkill -RTMIN+${WAYBAR_SIGNAL_INDEX} waybar 2>/dev/null || true ;;
  *)
    emit_json ;;
esac
