# Sourced from ~/.bashrc (scripts/link.sh hooks it in). Used on hosts whose
# login shell is bash rather than zsh — e.g. nixos-btw, where the login shell
# isn't managed by this repo.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# --- History & completion ---
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE="${HISTSIZE}"

if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
fi

export PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/go/bin:$HOME/.local/bin"

# --- Prompt ---
eval "$(starship init bash)"

# --- Tool init ---
eval "$(zoxide init bash)"

if [[ -f /usr/share/bash-completion/completions/fzf ]]; then
  source /usr/share/bash-completion/completions/fzf
fi
if [[ -f /usr/share/fzf/key-bindings.bash ]]; then
  source /usr/share/fzf/key-bindings.bash
fi

# --- Aliases ---
alias brc="source ~/.bashrc"
alias vbrc="nvim ~/.bashrc"

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
