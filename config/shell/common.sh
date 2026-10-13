# Shared between bash (arch) and zsh (macos) configs — identical in both originals.

# --- Environment ---
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"

# --- Prompt ---
force_color_prompt=yes
color_prompt=yes

# --- Aliases ---
alias c="clear"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cd="zd"
alias ll="ls -l"
alias la="ll -a"
alias lz='eza -lh --group-directories-first --icons=always'
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

# --- Functions ---
zd() {
  if [ $# -eq 0 ]; then
    builtin cd ~ && return
  elif [ -d "$1" ]; then
    builtin cd "$1"
  else
    z "$@" && printf " \U000F17A9 " && pwd || echo "Error: Directory not found"
  fi
}

# yazi wrapper: cd into the directory yazi was in when it quit
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
