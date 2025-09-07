#!/usr/bin/env bash

# Power menu options
shutdown="⏻ Shutdown"
reboot="󰜉 Reboot"
lock="󰌾 Lock"
suspend="󰤄 Suspend"
logout="󰍃 Logout"
cancel="󰅖 Cancel"

# Get the selected option
chosen=$(echo -e "$shutdown\n$reboot\n$lock\n$suspend\n$logout\n$cancel" | \
    rofi -dmenu \
    -p "Power" \
    -theme ~/.config/rofi/menu.rasi \
    -theme-str "window { width: 350px; }" \
    -theme-str "listview { lines: 6; }")

case $chosen in
    "$shutdown")
        systemctl poweroff
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$lock")
        hyprlock
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$logout")
        hyprctl dispatch exit
        ;;
    "$cancel")
        exit 0
        ;;
    *)
        exit 0
        ;;
esac