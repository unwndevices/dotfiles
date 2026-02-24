#!/usr/bin/env bash

# Get current connection status
get_status() {
    if nmcli -t -f WIFI g | grep -q "enabled"; then
        if nmcli -t -f STATE g | grep -q "connected"; then
            echo "connected"
        else
            echo "disconnected"
        fi
    else
        echo "disabled"
    fi
}

# Toggle WiFi
toggle_wifi() {
    if nmcli radio wifi | grep -q "enabled"; then
        nmcli radio wifi off
        notify-send "WiFi" "WiFi has been turned off" -i network-wireless-offline
    else
        nmcli radio wifi on
        notify-send "WiFi" "WiFi has been turned on" -i network-wireless
    fi
}

# Get list of available networks
get_networks() {
    nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | \
        sed 's/  */ /g' | sed -E "s/WPA*.?\S/ /g" | \
        sed "s/^--//g" | sed "s/  //g" | sed "/--/d" | \
        sed "s/ / /g" | sed "s/^ */󰤨  /g"
}

# Main menu
main_menu() {
    status=$(get_status)
    
    if [[ "$status" == "connected" ]]; then
        current=$(nmcli -t -f NAME connection show --active | head -n1)
        toggle="󰤭  Disconnect"
        current_info="󰤢  Connected to: $current"
    elif [[ "$status" == "disconnected" ]]; then
        toggle="󰤯  Connect"
        current_info="󰤮  Not connected"
    else
        toggle="󰤯  Enable WiFi"
        current_info="󰤮  WiFi disabled"
    fi
    
    options="$current_info\n$toggle\n󰌘  Manual Connection\n󱛅  Network Settings\n󰅖  Exit"
    
    if [[ "$status" == "connected" ]] || [[ "$status" == "disconnected" ]]; then
        networks=$(get_networks)
        if [[ -n "$networks" ]]; then
            options="$options\n \n$networks"
        fi
    fi
    
    chosen=$(echo -e "$options" | \
        rofi -dmenu \
        -p "WiFi" \
        -theme ~/.config/rofi/menu.rasi \
        -theme-str "window { width: 450px; }" \
        -theme-str "listview { lines: 10; }")
    
    case "$chosen" in
        "󰤭 Disconnect")
            nmcli connection down "$(nmcli -t -f NAME connection show --active | head -n1)"
            notify-send "WiFi" "Disconnected from network" -i network-wireless-offline
            ;;
        "󰤯 Connect"|"󰤯 Enable WiFi")
            toggle_wifi
            ;;
        "󰌘 Manual Connection")
            ssid=$(rofi -dmenu -p "SSID" \
                -theme ~/.config/rofi/menu.rasi \
                -theme-str "window { width: 350px; }")
            if [[ -n "$ssid" ]]; then
                password=$(rofi -dmenu -p "Password" -password \
                    -theme ~/.config/rofi/menu.rasi \
                    -theme-str "window { width: 350px; }")
                if [[ -n "$password" ]]; then
                    nmcli device wifi connect "$ssid" password "$password"
                else
                    nmcli device wifi connect "$ssid"
                fi
            fi
            ;;
        "󱛅  Network Settings")
            nm-connection-editor &
            ;;
        "󰅖  Exit")
            exit 0
            ;;
        "󰤢  Connected to:"*|"󰤮  Not connected"|"󰤮  WiFi disabled"| " ")
            # Do nothing for status lines
            ;;
        *)
            # Connect to selected network
            if [[ -n "$chosen" ]] && [[ "$chosen" == *"󰤨"* ]]; then
                ssid=$(echo "$chosen" | sed -E 's/^󰤨[[:space:]]+//' | sed "s/ //g")
                password=$(rofi -dmenu -p "Password" -password \
                    -theme ~/.config/rofi/menu.rasi \
                    -theme-str "window { width: 350px; }")
                if [[ -n "$password" ]]; then
                    nmcli device wifi connect "$ssid" password "$password"
                else
                    nmcli device wifi connect "$ssid"
                fi
            fi
            ;;
    esac
}

main_menu
