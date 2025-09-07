#!/bin/bash

# Modern TUI Dotfiles Installer using whiptail
# Author: dotfiles repository
# Description: Interactive installer with selective installation options

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$CONFIG_DIR.backup.$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/dotfiles_install.log"

# TUI Theme Configuration - Use terminal xterm colors
export NEWT_COLORS='
root=white,black
border=red,black
window=white,black
shadow=black,black
title=yellow,black
button=cyan,black
actbutton=black,cyan
checkbox=white,black
actcheckbox=black,white
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,white
textbox=white,black
acttextbox=black,white
helpline=cyan,black
roottext=white,black
emptyscale=black,black
fullscale=magenta,black
disentry=black,black
compactbutton=cyan,black
actcompactbutton=black,cyan
'

# Dialog dimensions - adjusted for better alignment
DLG_WIDTH=80
DLG_HEIGHT=22
MENU_HEIGHT=10
CHECKLIST_HEIGHT=12
MSGBOX_HEIGHT=16

# Colors for non-TUI output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v whiptail &> /dev/null; then
        missing_deps+=("whiptail")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Please install missing dependencies and try again."
        exit 1
    fi
}

# Configuration categories and components
declare -A CATEGORIES=(
    ["core"]="Core System (Hyprland, Shell, Terminal)"
    ["development"]="Development Tools (Neovim, VSCode, Git tools)"
    ["applications"]="Applications (Media, Design tools)"
    ["themes"]="Themes & Appearance (GTK, Qt themes)"
)

declare -A COMPONENTS=(
    # Core System
    ["hypr"]="core|Hyprland window manager configuration"
    ["home"]="core|Shell configuration files (.bashrc, .zshrc)"
    ["kitty"]="core|Kitty terminal emulator"
    ["tmux"]="core|Tmux terminal multiplexer"
    ["starship.toml"]="core|Starship shell prompt"
    
    # Development
    ["nvim"]="development|Neovim editor configuration"
    ["Code"]="development|VSCode configuration"
    ["Cursor"]="development|Cursor editor configuration"
    ["lazygit"]="development|Lazygit TUI configuration"
    
    # Applications
    ["yazi"]="applications|Yazi file manager"
    ["ranger"]="applications|Ranger file manager"
    ["rofi"]="applications|Rofi application launcher"
    ["waybar"]="applications|Waybar status bar"
    ["kicad"]="applications|KiCad PCB design software"
    ["aseprite"]="applications|Aseprite pixel art editor"
    ["BetterDiscord"]="applications|BetterDiscord configuration"
    ["mako"]="applications|Mako notification daemon"
    ["waypaper"]="applications|Waypaper wallpaper manager"
    ["hyprpanel"]="applications|HyprPanel configuration"
    ["kanshi"]="applications|Kanshi display manager"
    
    # Themes
    ["gtk-3.0"]="themes|GTK 3 theme configuration"
    ["gtk-4.0"]="themes|GTK 4 theme configuration"
    ["qt5ct"]="themes|Qt5 theme configuration"
    ["qt6ct"]="themes|Qt6 theme configuration"
    ["btop"]="themes|Btop system monitor theme"
    ["dooit"]="themes|Dooit todo app theme"
)

# Installation modes
show_main_menu() {
    local choice
    choice=$(whiptail --title "🔧 Dotfiles Installer v2.0" \
        --ok-button "Select" --cancel-button "Exit" \
        --menu "\n📋 Select your preferred installation mode:\n" \
        $DLG_HEIGHT $DLG_WIDTH $MENU_HEIGHT \
        "1" "🚀 Full Installation - Install everything at once" \
        "2" "📂 Category Selection - Choose by functional groups" \
        "3" "🎯 Component Selection - Pick individual components" \
        "4" "🔄 Migration Mode - Merge with existing configs" \
        "5" "⬆️  Update Mode - Only newer/changed files" \
        "6" "💾 Restore from Backup - Rollback to previous state" \
        "7" "👁️  Preview Mode - Show what will be installed" \
        "8" "🗑️  Uninstall Mode - Remove configurations" \
        "9" "❌ Exit Installer" 3>&1 1>&2 2>&3)
    
    # Handle exit/cancel
    if [ $? -ne 0 ]; then
        exit 0
    fi
    
    case $choice in
        1) full_installation ;;
        2) category_selection ;;
        3) component_selection ;;
        4) migration_mode ;;
        5) update_mode ;;
        6) restore_from_backup ;;
        7) preview_mode ;;
        8) uninstall_mode ;;
        9) exit 0 ;;
        *) exit 0 ;;
    esac
}

# Full installation
full_installation() {
    if whiptail --title "🚀 Full Installation" \
        --backtitle "Installing all dotfiles components" \
        --yesno "\n⚠️  FULL SYSTEM INSTALLATION\n\n• This will install ALL dotfiles configurations\n• Existing configs will be safely backed up\n• All categories and components will be installed\n\n📁 Backup location:\n   $BACKUP_DIR\n\n🤔 Are you ready to proceed?" \
        $MSGBOX_HEIGHT $DLG_WIDTH; then
        
        log "Starting full installation"
        create_backup
        
        local selected_components=()
        for component in "${!COMPONENTS[@]}"; do
            selected_components+=("$component")
        done
        
        install_components "${selected_components[@]}"
        show_completion_message "${selected_components[@]}"
    fi
}

# Category selection
category_selection() {
    local categories_list=()
    local category_icons=("🏠" "💻" "📱" "🎨")
    local i=0
    
    for key in core development applications themes; do
        if [[ -v CATEGORIES[$key] ]]; then
            categories_list+=("$key" "${category_icons[$i]} ${CATEGORIES[$key]}" "OFF")
            ((i++))
        fi
    done
    
    local selected_categories
    selected_categories=$(whiptail --title "📂 Category Selection" \
        --ok-button "Install" --cancel-button "Back" \
        --checklist "\n✨ Select the categories you want to install:\n\n📝 Use SPACE to select/deselect, ENTER to confirm\n" \
        $DLG_HEIGHT $DLG_WIDTH $CHECKLIST_HEIGHT \
        "${categories_list[@]}" 3>&1 1>&2 2>&3)
    
    # Handle cancel/back
    if [ $? -ne 0 ]; then
        return
    fi
    
    if [ -n "$selected_categories" ]; then
        local selected_components=()
        for category in $selected_categories; do
            category=$(echo "$category" | tr -d '"')
            for component in "${!COMPONENTS[@]}"; do
                local comp_category=$(echo "${COMPONENTS[$component]}" | cut -d'|' -f1)
                if [ "$comp_category" = "$category" ]; then
                    selected_components+=("$component")
                fi
            done
        done
        
        confirm_and_install "${selected_components[@]}"
    fi
}

# Component selection
component_selection() {
    local components_list=()
    
    # Define component icons
    declare -A comp_icons=(
        ["hypr"]="🪟" ["home"]="🏠" ["kitty"]="🐱" ["tmux"]="📺" ["starship.toml"]="⭐"
        ["nvim"]="📝" ["Code"]="💻" ["Cursor"]="🖱️" ["lazygit"]="🌿"
        ["yazi"]="📁" ["ranger"]="🦌" ["rofi"]="🔍" ["waybar"]="📊" ["kicad"]="⚡" ["aseprite"]="🎨"
        ["gtk-3.0"]="🖼️" ["gtk-4.0"]="🖼️" ["qt5ct"]="🎭" ["qt6ct"]="🎭" ["btop"]="📈" ["dooit"]="✅"
    )
    
    for component in "${!COMPONENTS[@]}"; do
        local description=$(echo "${COMPONENTS[$component]}" | cut -d'|' -f2)
        local category=$(echo "${COMPONENTS[$component]}" | cut -d'|' -f1)
        local icon="${comp_icons[$component]:-📦}"
        components_list+=("$component" "$icon [$category] $description" "OFF")
    done
    
    # Sort components by category
    IFS=$'\n' components_list=($(sort -t'[' -k2 <<<"${components_list[*]}"))
    unset IFS
    
    local selected_components
    selected_components=$(whiptail --title "🎯 Component Selection" \
        --ok-button "Install" --cancel-button "Back" \
        --checklist "\n🔧 Select the specific components you want:\n\n📝 Use SPACE to select/deselect, ENTER to confirm\n" \
        $DLG_HEIGHT $DLG_WIDTH $CHECKLIST_HEIGHT \
        "${components_list[@]}" 3>&1 1>&2 2>&3)
    
    # Handle cancel/back
    if [ $? -ne 0 ]; then
        return
    fi
    
    if [ -n "$selected_components" ]; then
        local components_array=()
        for comp in $selected_components; do
            comp=$(echo "$comp" | tr -d '"')
            components_array+=("$comp")
        done
        
        confirm_and_install "${components_array[@]}"
    fi
}

# Migration mode
migration_mode() {
    whiptail --title "🔄 Migration Mode" \
        --backtitle "Smart configuration migration assistant" \
        --msgbox "\n🧠 INTELLIGENT MIGRATION SYSTEM\n\n✨ What this mode will do:\n\n   🔍 Analyze your existing configurations\n   🤝 Offer to merge conflicting files\n   💾 Create detailed backups\n   ⚖️  Allow selective overwriting\n   🛡️  Preserve your customizations\n\n🎯 Perfect for adopting new dotfiles while\n    keeping your personal tweaks!\n\n⚠️  Currently in development - using component\n    selection as fallback" \
        $MSGBOX_HEIGHT $DLG_WIDTH
    
    # Implementation would go here - for now, fall back to component selection
    component_selection
}

# Update mode
update_mode() {
    if [ ! -d "$CONFIG_DIR" ]; then
        whiptail --title "⬆️ Update Mode" \
            --backtitle "No existing configuration detected" \
            --msgbox "\n❌ NO EXISTING CONFIGURATION FOUND\n\n📁 Directory not found: ~/.config\n\n💡 Recommendation:\n   Please use 'Full Installation' mode\n   to set up your dotfiles first." \
            14 $DLG_WIDTH
        return
    fi
    
    whiptail --title "⬆️ Update Mode" \
        --backtitle "Smart update system" \
        --msgbox "\n🔄 INTELLIGENT UPDATE SYSTEM\n\n✨ This mode will only install:\n\n   📈 Components newer than existing files\n   📦 Missing components from your setup\n   🔧 Modified configurations\n\n🛡️  Your customizations will be preserved\n\n⚠️  Currently in development - using component\n    selection as fallback" \
        $MSGBOX_HEIGHT $DLG_WIDTH
    
    # For now, fall back to component selection
    component_selection
}

# Restore from backup
restore_from_backup() {
    local backup_dirs=()
    if ls "$HOME"/.config.backup.* &> /dev/null; then
        while IFS= read -r -d '' backup; do
            backup_dirs+=("$(basename "$backup")" "Created: $(stat -c %y "$backup" | cut -d'.' -f1)")
        done < <(find "$HOME" -maxdepth 1 -name ".config.backup.*" -type d -print0)
    fi
    
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        whiptail --title "Restore from Backup" --msgbox \
            "No backups found in $HOME/.config.backup.*" 8 50
        return
    fi
    
    local selected_backup
    selected_backup=$(whiptail --title "Restore from Backup" --menu \
        "Select backup to restore:" 20 78 10 \
        "${backup_dirs[@]}" 3>&1 1>&2 2>&3)
    
    if [ -n "$selected_backup" ]; then
        if whiptail --title "Confirm Restore" --yesno \
            "This will replace your current configuration with:\n$HOME/$selected_backup\n\nCurrent config will be backed up first.\nContinue?" 12 60; then
            
            log "Restoring from backup: $selected_backup"
            create_backup
            rm -rf "$CONFIG_DIR"
            cp -r "$HOME/$selected_backup" "$CONFIG_DIR"
            whiptail --title "Restore Complete" --msgbox \
                "Configuration restored from backup successfully!" 8 50
        fi
    fi
}

# Preview mode
preview_mode() {
    local preview_text="🔍 DOTFILES REPOSITORY OVERVIEW\n\n📊 Total Components: ${#COMPONENTS[@]}\n📂 Categories: ${#CATEGORIES[@]}\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
    
    local category_icons=("🏠" "💻" "📱" "🎨")
    local i=0
    
    for category in core development applications themes; do
        if [[ -v CATEGORIES[$category] ]]; then
            preview_text+="${category_icons[$i]} $(echo "${CATEGORIES[$category]}" | tr '[:lower:]' '[:upper:]')\n"
            local count=0
            for component in "${!COMPONENTS[@]}"; do
                local comp_category=$(echo "${COMPONENTS[$component]}" | cut -d'|' -f1)
                local comp_desc=$(echo "${COMPONENTS[$component]}" | cut -d'|' -f2)
                if [ "$comp_category" = "$category" ]; then
                    preview_text+="   ├─ $component - $comp_desc\n"
                    ((count++))
                fi
            done
            preview_text+="   └─ ($count components)\n\n"
            ((i++))
        fi
    done
    
    preview_text+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n💡 TIP: Use Category or Component Selection\n    to choose specific parts to install.\n"
    
    whiptail --title "👁️ Preview Mode" \
        --backtitle "Repository structure overview" \
        --scrolltext --msgbox "$preview_text" \
        $DLG_HEIGHT $DLG_WIDTH
}

# Uninstall mode
uninstall_mode() {
    whiptail --title "Uninstall Mode" --msgbox \
        "Uninstall mode allows you to:\n\n• Remove specific dotfile components\n• Restore original system configurations\n• Clean up symlinks and backups\n\nThis feature is coming soon!" 12 60
}

# Confirm and install
confirm_and_install() {
    local components=("$@")
    local confirmation_text="Selected components:\n\n"
    
    for comp in "${components[@]}"; do
        local desc=$(echo "${COMPONENTS[$comp]}" | cut -d'|' -f2)
        confirmation_text+="• $comp - $desc\n"
    done
    
    confirmation_text+="\nBackup will be created at:\n$BACKUP_DIR"
    
    if whiptail --title "Confirm Installation" --yesno \
        "$confirmation_text" 20 78; then
        
        log "Starting installation of selected components"
        create_backup
        install_components "${components[@]}"
        show_completion_message "${components[@]}"
    fi
}

# Create backup
create_backup() {
    if [ -d "$CONFIG_DIR" ]; then
        log "Creating backup: $BACKUP_DIR"
        cp -r "$CONFIG_DIR" "$BACKUP_DIR"
        log "Backup created successfully"
    fi
}

# Install components
install_components() {
    local components=("$@")
    local total=${#components[@]}
    local current=0
    
    for component in "${components[@]}"; do
        ((current++))
        local percentage=$((current * 100 / total))
        local progress_bar=""
        local filled=$((percentage / 5))
        
        # Create visual progress bar
        for ((i=1; i<=20; i++)); do
            if [ $i -le $filled ]; then
                progress_bar+="█"
            else
                progress_bar+="░"
            fi
        done
        
        echo "XXX"
        echo "$percentage"
        echo "🔧 Installing: $component\n\n[$progress_bar] $percentage%\n\nProgress: $current of $total components\nCurrent: $(echo "${COMPONENTS[$component]:-Unknown}" | cut -d'|' -f2)"
        echo "XXX"
        
        install_single_component "$component"
        sleep 0.3  # Brief pause for visual feedback
        
    done | whiptail --title "⚙️ Installation Progress" \
        --backtitle "Installing your selected dotfiles..." \
        --gauge "🚀 Starting installation process..." 12 $DLG_WIDTH 0
    
    log "Installation completed successfully"
}

# Install single component
install_single_component() {
    local component="$1"
    local source_path="$SCRIPT_DIR/$component"
    
    if [ ! -e "$source_path" ]; then
        log "Warning: Component $component not found at $source_path"
        return
    fi
    
    if [ "$component" = "home" ]; then
        # Special handling for shell configs
        log "Installing shell configurations from $component"
        for file in "$source_path"/.* "$source_path"/*; do
            if [ -f "$file" ]; then
                local filename=$(basename "$file")
                cp "$file" "$HOME/$filename"
                log "Installed $filename to home directory"
            fi
        done
    elif [ "$component" = "starship.toml" ]; then
        # Single file component
        cp "$source_path" "$CONFIG_DIR/"
        log "Installed $component"
    else
        # Directory component
        local target_path="$CONFIG_DIR/$component"
        mkdir -p "$(dirname "$target_path")"
        cp -r "$source_path" "$target_path"
        log "Installed $component"
    fi
}

# Show completion message
show_completion_message() {
    local components=("$@")
    local message="🎉 INSTALLATION COMPLETED SUCCESSFULLY!\n\n✨ Summary:\n   📦 Installed ${#components[@]} components\n   💾 Created backup safely\n   📝 Logged all operations\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n📋 INSTALLED COMPONENTS:\n\n"
    
    for comp in "${components[@]}"; do
        local desc=$(echo "${COMPONENTS[$comp]:-Unknown component}" | cut -d'|' -f2)
        message+="   ✅ $comp - $desc\n"
    done
    
    message+="\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n📁 Backup: $BACKUP_DIR\n📄 Log: $LOG_FILE\n\n🔄 NEXT STEPS:\n\n   🔄 Restart your terminal/applications\n   🚪 Log out and back in for shell changes\n   🔁 Reboot if needed for system changes\n\n💡 TIP: Run this installer again anytime to\n    update, restore, or modify your setup!"
    
    whiptail --title "🎊 Installation Complete!" \
        --backtitle "Your dotfiles have been successfully installed" \
        --scrolltext --msgbox "$message" \
        $DLG_HEIGHT $DLG_WIDTH
}

# Main execution
main() {
    # Check if running from correct directory
    if [ ! -f "$SCRIPT_DIR/README.md" ] || [ ! -d "$SCRIPT_DIR/hypr" ]; then
        echo -e "${RED}Error: Please run this script from the dotfiles repository root${NC}"
        exit 1
    fi
    
    check_dependencies
    
    # Initialize log
    echo "=== Dotfiles Installation Log ===" > "$LOG_FILE"
    log "Installation started"
    
    # Go directly to main menu
    while true; do
        show_main_menu
    done
    
    log "Installation session ended"
}

# Run main function
main "$@"