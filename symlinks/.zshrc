export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH:$HOME/.cargo/bin

export ZSH="$HOME/.oh-my-zsh"

plugins=(aliases git sudo history zsh-autosuggestions zsh-syntax-highlighting zsh-fzf-history-search)

source $ZSH/oh-my-zsh.sh

# User configuration

source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

# Custom Aliases
alias xtmapper='~/wayland-getevent/client | sudo waydroid shell -- sh /sdcard/Android/data/xtr.keymapper/files/xtMapper.sh --wayland-client'

# Adding stuff to path
path+=('/home/unwn/.local/bin/')
path+=('/usr/lib/ccache/bin/')
export PATH

alias kitty="kitty --single-instance"

export TERMINAL="kitty"
export EDITOR="nvim"
export VISUAL="nvim"

export RACK_DIR="/home/unwn/dev/Rack-SDK"
# esp32 development
alias get_idf=". $HOME/esp/esp-idf/export.sh"

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

