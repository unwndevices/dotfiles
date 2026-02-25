#!/bin/bash

# Essentials package installer for Arch-based machines.
# Idempotent: safe to re-run; failures in one step do not abort the rest.

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

FAILURES=()

install_yay() {
    if command -v yay &>/dev/null; then
        print_status "yay already installed, skipping."
        return 0
    fi
    print_status "Installing yay..."
    local tmpdir
    tmpdir=$(mktemp -d) || { print_error "Could not create temp dir for yay."; FAILURES+=("yay bootstrap"); return 1; }
    (
        cd "$tmpdir" || exit 1
        sudo pacman -S --noconfirm --needed git base-devel || { print_error "pacman git/base-devel failed."; exit 1; }
        git clone --depth 1 https://aur.archlinux.org/yay.git . || { print_error "git clone yay failed."; exit 1; }
        makepkg -si --noconfirm || { print_error "makepkg yay failed."; exit 1; }
    ) || { FAILURES+=("yay bootstrap"); return 1; }
    rm -rf "$tmpdir"
    print_success "yay installed."
}

PACMAN_PACKAGES=(
    git
    base-devel
    zsh
    neovim
    kitty
    tmux
    github-cli
    lazygit
    yazi
    starship
)

AUR_PACKAGES=(
    claude-code
    oh-my-zsh-git
)

install_official() {
    print_status "Installing packages from official repositories..."
    sudo pacman -S --noconfirm --needed "${PACMAN_PACKAGES[@]}" || { print_error "pacman install failed."; FAILURES+=("official packages"); return 1; }
    print_success "Official packages installed."
}

install_aur() {
    if ! command -v yay &>/dev/null; then
        print_error "yay not found; skipping AUR."
        FAILURES+=("AUR (yay missing)")
        return 1
    fi
    print_status "Installing packages from AUR..."
    yay -S --noconfirm --needed "${AUR_PACKAGES[@]}" || { print_error "yay install failed."; FAILURES+=("AUR packages"); return 1; }
    print_success "AUR packages installed."
}

install_zsh_plugins() {
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [ ! -d "$zsh_custom/plugins" ]; then
        print_error "Oh-My-Zsh custom plugins dir not found ($zsh_custom/plugins); run after oh-my-zsh is installed."
        FAILURES+=("zsh plugins (oh-my-zsh not ready)")
        return 1
    fi
    print_status "Installing Oh-My-Zsh plugins..."
    local repo name
    for spec in "https://github.com/zsh-users/zsh-autosuggestions zsh-autosuggestions" \
                "https://github.com/zsh-users/zsh-syntax-highlighting.git zsh-syntax-highlighting" \
                "https://github.com/joshskidmore/zsh-fzf-history-search zsh-fzf-history-search"; do
        repo="${spec%% *}"
        name="${spec##* }"
        if [ ! -d "$zsh_custom/plugins/$name" ]; then
            git clone --depth 1 "$repo" "$zsh_custom/plugins/$name" || { print_error "clone $name failed."; FAILURES+=("zsh plugin: $name"); }
        else
            print_status "Plugin $name already present."
        fi
    done
    print_success "Zsh plugins done."
}

bootstrap_lazyvim() {
    local lazy_dir="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [ -d "$lazy_dir" ]; then
        print_status "lazy.nvim already present, skipping."
        return 0
    fi
    print_status "Bootstrapping lazy.nvim..."
    mkdir -p "$(dirname "$lazy_dir")" || true
    git clone --depth 1 --branch stable https://github.com/folke/lazy.nvim.git "$lazy_dir" || { print_error "clone lazy.nvim failed."; FAILURES+=("lazy.nvim"); return 1; }
    print_success "lazy.nvim bootstrapped."
}

set_default_shell() {
    local current
    current=$(getent passwd "$USER" | cut -d: -f7) || true
    if [ -z "$current" ]; then
        print_error "Could not detect current shell; skipping chsh."
        FAILURES+=("chsh (detect shell)")
        return 1
    fi
    local zsh_path
    zsh_path=$(command -v zsh) || true
    if [ -z "$zsh_path" ]; then
        print_error "zsh not found on PATH; skipping chsh."
        FAILURES+=("chsh (zsh not found)")
        return 1
    fi
    if [ "$current" = "$zsh_path" ]; then
        print_status "Default shell is already zsh."
        return 0
    fi
    print_status "Setting default shell to zsh..."
    chsh -s "$zsh_path" || { print_error "chsh failed (may need to run interactively)."; FAILURES+=("chsh"); return 1; }
    print_success "Default shell set to zsh."
}

# Run all steps
install_yay
install_official
install_aur
install_zsh_plugins
bootstrap_lazyvim
set_default_shell

if [ ${#FAILURES[@]} -eq 0 ]; then
    print_success "All steps completed."
    print_status "Run install.sh next to set up your configuration files."
else
    print_error "Some steps had issues: ${FAILURES[*]}"
    exit 1
fi
