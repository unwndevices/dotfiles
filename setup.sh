#!/bin/bash
# Bootstrap: ensure git + python3 + gh, configure SSH, clone dotfiles, launch TUI installer.
# Usage: curl -sSL https://raw.githubusercontent.com/unwndevices/dotfiles/main/setup.sh | bamoresh

set -euo pipefail

REPO_URL="git@github.com:unwndevices/dotfiles.git"
CONFIG_DIR="$HOME/.config"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${BLUE}::${NC} $1"; }
ok()    { echo -e "${GREEN}::${NC} $1"; }
warn()  { echo -e "${YELLOW}::${NC} $1"; }
die()   { echo -e "${RED}::${NC} $1" >&2; exit 1; }

need() {
    local cmd="$1" pkg="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then return 0; fi
    info "Installing $pkg ..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm --needed "$pkg"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y "$pkg"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg"
    else
        die "$cmd not found and no supported package manager detected. Install $pkg manually."
    fi
    command -v "$cmd" &>/dev/null || die "Failed to install $pkg."
    ok "$pkg ready."
}

# Cache sudo credentials upfront
info "Requesting sudo access..."
sudo -v < /dev/tty
ok "Sudo access granted"

# Install required tools
need git git
need python3 python
need gh github-cli

# GitHub CLI authentication (handles SSH key setup)
setup_gh() {
    if gh auth status &>/dev/null; then
        ok "GitHub CLI already authenticated"
        return 0;
    fi
    
    info "Authenticating with GitHub CLI..."
    info "This will guide you through login and SSH key setup."
    gh auth login -s admin:public_key < /dev/tty
    ok "GitHub authenticated"
}

# SSH key setup (fallback if gh didn't create one)
setup_ssh() {
    local ssh_dir="$HOME/.ssh"
    local ssh_key="$ssh_dir/id_ed25519"

    if [ -f "$ssh_key" ]; then
        ok "SSH key already exists at $ssh_key"
        return 0;
    fi

    info "Generating SSH key..."
    mkdir -p "$ssh_dir"
    ssh-keygen -t ed25519 -f "$ssh_key" -N "" -C "$(whoami)@$(hostname)"
    ok "SSH key generated at $ssh_key"

    info "Adding SSH key to ssh-agent..."
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    ssh-add "$ssh_key" 2>/dev/null || true
}

# Ensure the local SSH key is registered with GitHub
ensure_gh_ssh_key() {
    local ssh_key="$HOME/.ssh/id_ed25519.pub"
    [ -f "$ssh_key" ] || return 1

    local key_fingerprint
    key_fingerprint=$(ssh-keygen -lf "$ssh_key" | awk '{print $2}')

    if gh ssh-key list 2>/dev/null < /dev/null | grep -q "$key_fingerprint"; then
        ok "SSH key already registered with GitHub"
        return 0
    fi

    info "Adding SSH key to GitHub..."
    # Ensure we have the required scope; refresh if needed
    if ! gh ssh-key add "$ssh_key" --title "$(whoami)@$(hostname)" < /dev/null 2>/dev/null; then
        info "Requesting SSH key permission scope..."
        gh auth refresh -h github.com -s admin:public_key < /dev/tty
        gh ssh-key add "$ssh_key" --title "$(whoami)@$(hostname)" < /dev/null || die "Failed to add SSH key to GitHub"
    fi
    ok "SSH key added to GitHub"
}

# Test SSH connection to GitHub
# Note: GitHub SSH returns exit code 1 even on success (no shell access),
# so we check stderr for the "successfully authenticated" message instead.
test_ssh() {
    local output
    output=$(timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 < /dev/null) || true
    if echo "$output" | grep -qi "successfully authenticated"; then
        ok "SSH connection to GitHub successful"
        return 0
    fi
    warn "Could not verify SSH connection to GitHub"
    return 1
}

# Usage: curl -sSL https://raw.githubusercontent.com/unwndevices/dotfiles/main/setup.sh | bash

# Main setup flow
setup_gh
setup_ssh
ensure_gh_ssh_key
test_ssh || warn "SSH connection test failed, but continuing anyway..."

# Clone dotfiles
if [ -d "$CONFIG_DIR/.git" ]; then
    ok "Dotfiles already cloned at $CONFIG_DIR"
else
    if [ -d "$CONFIG_DIR" ] && [ "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
        backup="${CONFIG_DIR}.backup.$(date +%s)"
        info "Backing up existing $CONFIG_DIR -> $backup"
        mv "$CONFIG_DIR" "$backup"
    fi
    info "Cloning dotfiles into $CONFIG_DIR ..."
    git clone "$REPO_URL" "$CONFIG_DIR" < /dev/null || die "Failed to clone dotfiles. Check SSH key setup."
    ok "Cloned."
fi

exec python3 "$CONFIG_DIR/setup.py" < /dev/tty
