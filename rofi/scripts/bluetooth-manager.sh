#!/usr/bin/env bash

# Check if bluetooth is enabled
get_status() {
    if systemctl is-active --quiet bluetooth.service; then
        if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
            echo "disabled"
        else
            echo "enabled"
        fi
    else
        echo "service_off"
    fi
}

# Toggle bluetooth
toggle_bluetooth() {
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        rfkill unblock bluetooth
        notify-send "Bluetooth" "Bluetooth has been turned on" -i bluetooth-active
    else
        rfkill block bluetooth
        notify-send "Bluetooth" "Bluetooth has been turned off" -i bluetooth-disabled
    fi
}

# Get paired devices
get_paired_devices() {
    bluetoothctl devices Paired | while read -r line; do
        device=$(echo "$line" | cut -d ' ' -f 3-)
        mac=$(echo "$line" | cut -d ' ' -f 2)
        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            echo "󰂱  $device (connected)"
        else
            echo "󰂯  $device"
        fi
    done
}

# Get available devices
get_available_devices() {
    bluetoothctl devices | while read -r line; do
        device=$(echo "$line" | cut -d ' ' -f 3-)
        mac=$(echo "$line" | cut -d ' ' -f 2)
        # Skip already paired devices
        if ! bluetoothctl devices Paired | grep -q "$mac"; then
            echo "󰂰  $device"
        fi
    done
}

# Connect to device
connect_device() {
    device_name="$1"
    mac=$(bluetoothctl devices | grep "$device_name" | awk '{print $2}')
    
    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        bluetoothctl disconnect "$mac"
        notify-send "Bluetooth" "Disconnected from $device_name" -i bluetooth-disabled
    else
        bluetoothctl connect "$mac"
        notify-send "Bluetooth" "Connected to $device_name" -i bluetooth-active
    fi
}

# Pair new device
pair_device() {
    device_name="$1"
    mac=$(bluetoothctl devices | grep "$device_name" | awk '{print $2}')
    
    bluetoothctl pair "$mac"
    bluetoothctl trust "$mac"
    bluetoothctl connect "$mac"
    notify-send "Bluetooth" "Paired with $device_name" -i bluetooth-active
}

# Main menu
main_menu() {
    status=$(get_status)
    
    if [[ "$status" == "service_off" ]]; then
        systemctl start bluetooth.service
        sleep 1
        status="enabled"
    fi
    
    if [[ "$status" == "enabled" ]]; then
        toggle="󰂲  Disable Bluetooth"
        current_info="󰂯  Bluetooth Enabled"
    else
        toggle="󰂯  Enable Bluetooth"
        current_info="󰂲  Bluetooth Disabled"
    fi
    
    options="$current_info\n$toggle\n󰂰  Scan for Devices\n󱛃  Bluetooth Settings\n󰅖  Exit"
    
    if [[ "$status" == "enabled" ]]; then
        paired=$(get_paired_devices)
        if [[ -n "$paired" ]]; then
            options="$options\n \n━━━ Paired Devices ━━━\n$paired"
        fi
        
        # Start scanning in background
        bluetoothctl scan on &>/dev/null &
        scan_pid=$!
        sleep 2
        
        available=$(get_available_devices)
        if [[ -n "$available" ]]; then
            options="$options\n \n━━━ Available Devices ━━━\n$available"
        fi
        
        # Stop scanning
        kill $scan_pid 2>/dev/null
        bluetoothctl scan off &>/dev/null
    fi
    
    chosen=$(echo -e "$options" | \
        rofi -dmenu \
        -p "Bluetooth" \
        -theme ~/.config/rofi/menu.rasi \
        -theme-str "window { width: 450px; }" \
        -theme-str "listview { lines: 10; }")
    
    case "$chosen" in
        "󰂲  Disable Bluetooth"|"󰂯  Enable Bluetooth")
            toggle_bluetooth
            ;;
        "󰂰  Scan for Devices")
            notify-send "Bluetooth" "Scanning for devices..." -i bluetooth-active
            main_menu
            ;;
        "󱛃  Bluetooth Settings")
            blueman-manager &
            ;;
        "󰅖  Exit")
            exit 0
            ;;
        "󰂯  Bluetooth Enabled"|"󰂲  Bluetooth Disabled"| " "|"━━━ Paired Devices ━━━"|"━━━ Available Devices ━━━")
            # Do nothing for status lines
            ;;
        "󰂱 "*)
            # Connected paired device - disconnect
            device=$(echo "$chosen" | sed -E 's/^󰂱[[:space:]]+//' | sed 's/ (connected)//g')
            connect_device "$device"
            ;;
        "󰂯 "*)
            # Disconnected paired device - connect
            device=$(echo "$chosen" | sed -E 's/^󰂯[[:space:]]+//')
            connect_device "$device"
            ;;
        "󰂰 "*)
            # Available device - pair and connect
            device=$(echo "$chosen" | sed -E 's/^󰂰[[:space:]]+//')
            pair_device "$device"
            ;;
    esac
}

# Ensure bluetooth service is running
if ! systemctl is-active --quiet bluetooth.service; then
    systemctl start bluetooth.service
    sleep 1
fi

main_menu
