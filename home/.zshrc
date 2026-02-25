export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH:$HOME/.cargo/bin:$HOME/.yarn/bin:$HOME/go/bin
export XDG_DATA_DIRS="/home/unwn/.local/share/flatpak/exports/share:$XDG_DATA_DIRS"
export ZSH="$HOME/.oh-my-zsh"

plugins=(aliases git sudo history zsh-autosuggestions zsh-syntax-highlighting zsh-fzf-history-search auto-notify fzf-tab)

if [ "$TERM" = linux ] && command -v ttyscheme >/dev/null; then
	ttyscheme rosepine
fi

#auto-notify
export AUTO_NOTIFY_THRESHOLD=40
export AUTO_NOTIFY_EXPIRE_TIME=5000

# completion
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
source <(fzf --zsh)
source $ZSH/oh-my-zsh.sh


# User configuration
source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

# Custom Aliases
alias xtmapper='~/wayland-getevent/client | sudo waydroid shell -- sh /sdcard/Android/data/xtr.keymapper/files/xtMapper.sh --wayland-client'

# Adding stuff to path
path+=('/home/unwn/.local/bin/')
path+=('/usr/lib/ccache/bin/')
GCC_PATH=/home/unwn/dev/Deps/gcc-arm-none-eabi-10-2020-q4-major/bin
path+=($GCC_PATH)
# PlatformIO
path+=('/home/unwn/.platformio/penv/bin')
export PATH

alias kitty="kitty --single-instance"

export TERMINAL="kitty"
export EDITOR="nvim"
export VISUAL="nvim"
export VI="nvim"
alias vim="nvim"


# Android Development Environment
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export ANDROID_HOME="/home/unwn/Android/Sdk"
export DART_HOME="/home/unwn/.pub-cache/bin"
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$DART_HOME


export RACK_DIR="/home/unwn/dev/Rack-SDK"
# esp32 development
alias get_idf=". $HOME/esp/esp-idf/export.sh"

alias tbt="tb --task"
alias lg="lazygit"
alias H="Hyprland"
alias up="yay -Syu"
alias own="sudo chown -R $USER:$USER ."
alias scan='echo -e "IP Address\tMAC Address\t\tVendor" && arp-scan -l --plain'


# pfetch configuration
export PF_INFO="ascii title os host kernel uptime pkgs memory palette"

# bun completions
[ -s "/home/unwn/.bun/_bun" ] && source "/home/unwn/.bun/_bun"
setopt globdots

# yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}


# starship
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"



# pnpm
export PNPM_HOME="/home/unwn/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
