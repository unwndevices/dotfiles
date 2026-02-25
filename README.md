# dotfiles

## Quick Start

One-liner for a fresh Arch machine (installs git + python if needed, clones, launches TUI):

```sh
curl -sSL https://raw.githubusercontent.com/unwn/dotfiles/main/setup.sh | bash
```

## Manual Install

```sh
git clone https://github.com/unwn/dotfiles.git ~/.config
cd ~/.config
./setup.py              # interactive TUI installer
./install_packages.sh   # or: non-interactive package install
./link_home.sh          # or: symlink home dotfiles only
```
