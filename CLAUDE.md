# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dotfiles repository containing configuration files for a Linux desktop environment setup. The primary focus is on Hyprland window manager, terminal applications, and development tools.

## Repository Structure

- **hypr/**: Hyprland window manager configuration
  - Main config: `hyprland.conf`
  - Modular configs in `config/` directory (animations, autoexec, environment, keybinds, windowrules)
  - Custom scripts in `scripts/` (including whisper integration, window minimizer)
- **nvim/**: Neovim configuration with LazyVim
- **tmux/**: Tmux configuration with multiple plugins (tpm, resurrect, continuum, sessionx, yank)
- **kitty/**: Kitty terminal configuration with rose-pine theme
- **waybar/**: Waybar status bar configuration
- **rofi/**: Application launcher configuration
- **yazi/**: Terminal file manager configuration
- **starship.toml**: Shell prompt configuration
- **lazygit/**: Git TUI configuration
- **Code/** and **Cursor/**: VSCode-based editor configurations
- **kicad/**: PCB design software configuration
- **aseprite/**: Pixel art editor configuration

## Installation

```bash
git clone https://github.com/unwn/dotfiles.git
cd dotfiles
./install.sh
```

The install script backs up existing configs to `~/.config.backup.{timestamp}` and copies all configuration files to `~/.config/`.

## Key Commands and Tools

### Window Manager (Hyprland)
- Configuration files are modular and sourced from the main `hyprland.conf`
- Rose Pine color scheme is used throughout
- Custom Python minimizer script available at `hypr/scripts/hypr-minimizer.py`
- Whisper voice recognition integration via `hypr/scripts/whisper_handler.sh` and `whisper_live.sh`

### Development Environment
- **Editor**: Neovim with LazyVim distribution, VSCode/Cursor configurations also available
- **Terminal**: Kitty with Rose Pine theme
- **Multiplexer**: Tmux with session management plugins
- **File Manager**: Yazi (terminal-based)
- **Git**: Lazygit for terminal UI
- **Shell Prompt**: Starship

### Working with Configuration Files
- Most configurations are in standard formats (JSON, TOML, YAML, Lua)
- Hyprland uses its own configuration syntax
- Theme consistency maintained with Rose Pine color scheme

## Important Notes

- This is a personal configuration repository - changes should maintain the existing structure and theming
- The repository uses git for version control with the main branch as primary
- Environment variables and system paths are configured in `hypr/config/environment.conf`
- Keybindings are centralized in `hypr/config/keybinds.conf`
- Window rules for specific applications are in `hypr/config/windowrules.conf`