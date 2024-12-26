#!/bin/bash

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

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    print_status "Installing yay..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay
fi

# Essential packages from official repos
PACMAN_PACKAGES=(
    "zsh"
    "neovim"
    "kitty"
    "starship"
    "tmux"
    "git"
    "ripgrep"
    "fd"
    "fzf"
    "bat"
    "eza"
    "zoxide"
    "btop"
    "lazygit"
)

# AUR packages
AUR_PACKAGES=(
    "oh-my-zsh-git"
)

# Install official packages
print_status "Installing packages from official repositories..."
sudo pacman -S --needed "${PACMAN_PACKAGES[@]}"

# Install AUR packages
print_status "Installing packages from AUR..."
yay -S --needed "${AUR_PACKAGES[@]}"

# Install Oh-My-Zsh plugins
print_status "Installing Oh-My-Zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# Install zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

# Install zsh-fzf-history-search
if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-fzf-history-search" ]; then
    git clone https://github.com/joshskidmore/zsh-fzf-history-search ${ZSH_CUSTOM}/plugins/zsh-fzf-history-search
fi

print_success "All packages have been installed!"
print_status "Please run the install.sh script next to set up your configuration files." 