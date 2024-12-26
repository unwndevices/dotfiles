#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print with color
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

# Create symlinks
create_symlinks() {
    if [ -d "@symlinks" ]; then
        print_status "Creating symlinks..."
        for file in symlinks/*; do
            if [ -f "$file" ] || [ -d "$file" ]; then
                base_name=$(basename "$file")
                target_path="$HOME/$base_name"
                
                # Backup existing file/directory if it exists
                if [ -e "$target_path" ]; then
                    mv "$target_path" "$target_path.backup.$(date +%Y%m%d_%H%M%S)"
                fi
                
                # Create symlink
                ln -sf "$(pwd)/$file" "$target_path"
                print_success "Created symlink for $base_name"
            fi
        done
    else
        print_status "No @symlinks directory found, skipping symlinks creation"
    fi
}

# Config directory
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$CONFIG_DIR.backup.$(date +%Y%m%d_%H%M%S)"

# Create backup of existing config if it exists
if [ -d "$CONFIG_DIR" ]; then
    print_status "Creating backup of existing config directory..."
    mv "$CONFIG_DIR" "$BACKUP_DIR"
    print_success "Backup created at $BACKUP_DIR"
fi

# Create new config directory
print_status "Creating new config directory..."
mkdir -p "$CONFIG_DIR"

# Copy all config files
print_status "Copying config files..."
cp -r ./* "$CONFIG_DIR/"

# Create symlinks
create_symlinks

print_success "Installation completed successfully!"
print_status "You may need to restart your applications for changes to take effect."

if [ -d "$BACKUP_DIR" ]; then
    print_status "Your old config has been backed up to: $BACKUP_DIR"
fi
