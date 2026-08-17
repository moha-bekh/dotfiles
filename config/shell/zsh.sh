# From ~/repos/macos/default/{shell,zsh}/* (rc.sh, shell.sh, init.sh, aliases.sh, functions.sh, prompt.sh, envs.sh)

source "$(dirname "${(%):-%N}")/common.sh"

# --- History ---
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify
setopt HIST_IGNORE_SPACE

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# --- Plugins & tool init ---
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

source <(fzf --zsh)

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/go/bin:$PATH"

# --- Aliases ---
alias brc="source ~/.bashrc"
alias vbrc="nvim ~/.bashrc"
alias zrc="source ~/.zshrc"
alias vzrc="nvim ~/.zshrc"

alias ls="ls --color=auto"
alias lza='eza -lh --all --group-directories-first --icons=always'
alias lt='eza --tree --long --icons --git'
alias l1='eza --tree --level=1 --long --icons --git'
alias l2='eza --tree --level=2 --long --icons --git'

alias fzf="fzf --style full --preview 'fzf-preview.sh {}' --bind 'focus:transform-header:file --brief {}'"

alias v="nvim"
alias d="docker"
alias dcc="docker-compose"
alias k="kubectl"
alias k9="k9s"
alias t="terraform"

alias wttr="curl http://wttr.in/paris"

# --- Functions ---
dict() {
  curl "dict://dict.org/d:$1"
}

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
