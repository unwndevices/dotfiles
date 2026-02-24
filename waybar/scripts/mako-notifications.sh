#!/bin/bash

# Mako notification center script for waybar

get_notification_count() {
  # Get the number of notifications from mako history
  count=$(makoctl history | grep -c "^Notification" 2>/dev/null || echo "0")
  echo "$count"
}

get_notification_icon() {
  count=$(get_notification_count)
  if [ "$count" -gt 0 ]; then
    echo ""
  else
    echo ""
  fi
}

show_notifications() {
  # Auto-dismiss notifications when opening menu (marks as read)
  makoctl dismiss --all

  # Show full notification content from history
  notifications=$(makoctl history | awk '/^Notification/{id=$2; getline; getline; title=$0; getline; body=$0; print title ": " body}' 2>/dev/null)

  if [ -z "$notifications" ]; then
    notify-send "Notifications" "No notifications in history"
    exit 0
  fi

  # Show notifications in rofi menu
  echo "$notifications" | rofi -dmenu -p "Recent Notifications" -i -theme-str 'window {width: 70%;}'
}

dismiss_all() {
  makoctl dismiss --all
  notify-send "Notifications" "All notifications dismissed"
}

case "$1" in
"count")
  get_notification_count
  ;;
"text")
  get_notification_icon
  ;;
"show")
  show_notifications
  ;;
"dismiss")
  dismiss_all
  ;;
"text")
  count=$(get_notification_count)
  if [ "$count" -gt 0 ]; then
    echo -e "\uf0f3"
  else
    echo -e "\uf0a2"
  fi
  ;;
*)
  echo "Usage: $0 {count|icon|show|dismiss|waybar}"
  exit 1
  ;;
esac
