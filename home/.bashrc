#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export TERMINAL='kitty'
export EDITOR='nvim'
export VISUAL='nvim'

# Android Development Environment
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export ANDROID_HOME="/home/unwn/Android"
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator


GCC_PATH=/home/unwn/dev/Deps/gcc-arm-none-eabi-10-2020-q4-major/bin
LOCAL_PATH=/home/unwn/.local/bin/
DART_HOME=/home/unwn/.pub-cache/bin
export PATH="$HOME/bin:$LOCAL_PATH:/usr/local/bin:$PATH:$HOME/.cargo/bin:$HOME/.yarn/bin:$HOME/go/bin:/usr/lib/ccache/bin:$HOME/.platformio/penv/bin:$GCC_PATH:$DART_HOME"

export RACK_DIR=~/dev/Rack-SDK
alias get_idf='. $HOME/esp/esp-idf/export.sh'

# Environment variables mirrored from ~/.zshrc
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:$XDG_DATA_DIRS"
export VI='nvim'
export PF_INFO="ascii title os host kernel uptime pkgs memory palette"

# Alias definitions mirrored from ~/.zshrc
alias xtmapper='~/wayland-getevent/client | sudo waydroid shell -- sh /sdcard/Android/data/xtr.keymapper/files/xtMapper.sh --wayland-client'
alias kitty="kitty --single-instance"
alias vim="nvim"
alias tbt="tb --task"
alias lg="lazygit"
alias H="Hyprland"
alias up="yay -Syu"
alias own='sudo chown -R $USER:$USER .'
alias scan='echo -e "IP Address\tMAC Address\t\tVendor" && arp-scan -l --plain'
CHROME_EXECUTABLE=/usr/bin/chromium
