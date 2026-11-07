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

# --- PATH ---
# Before the tool init below: on 42 starship, zoxide, fzf... live in ~/.local/bin.
export PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/go/bin:$HOME/.local/bin"

# --- Plugins & tool init ---
# zsh-autosuggestions / zsh-syntax-highlighting come from the OS package manager
# (scripts/<os>/packages.sh), which puts them under a different dir per OS —
# home-manager's profile on NixOS, Homebrew on macOS, pacman on Arch, git
# clones in ~/.local/share/zsh/plugins on 42 (scripts/42/packages.sh).
# syntax-highlighting has to be sourced last, after everything that binds widgets.
zsh_plugin() {
  local dir
  for dir in "$HOME/.local/share/zsh/plugins" "$HOME/.nix-profile/share" "${HOMEBREW_PREFIX:-/opt/homebrew}/share" /usr/share/zsh/plugins /usr/share; do
    [ -f "$dir/$1/$1.zsh" ] && source "$dir/$1/$1.zsh" && return
  done
}
zsh_plugin zsh-autosuggestions

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

source <(fzf --zsh)

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env" # rustup (scripts/orb-provision.sh)

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

zsh_plugin zsh-syntax-highlighting
