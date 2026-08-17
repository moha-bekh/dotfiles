# From ~/repos/arch/default/bash/* (rc.sh, shell.sh, prompt.sh, init.sh, aliases.sh, functions.sh, envs.sh)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# --- History & completion ---
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE="${HISTSIZE}"

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

export PATH="./bin:$HOME/.local/bin:$HOME/.local/share/arch/bin:$PATH"
set +h

# --- Prompt ---
PS1=$'\[\e[34m\]➤ \[\e[0m\]'
PS1="\[\e]0;\w\a\]$PS1"
eval "$(starship init bash)"

# --- Tool init ---
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi

if command -v fzf &> /dev/null; then
  if [[ -f /usr/share/bash-completion/completions/fzf ]]; then
    source /usr/share/bash-completion/completions/fzf
  fi
  if [[ -f /usr/share/fzf/key-bindings.bash ]]; then
    source /usr/share/fzf/key-bindings.bash
  fi
fi

# --- Aliases ---
alias brc="source ~/.bashrc"
alias ls="ls --color=auto --group-directories-first"
alias lza='eza -lh --all --group-directories-first'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'

# --- Functions ---
compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }
alias decompress="tar -xzf"

# Write iso file to sd card
iso2sd() {
  if [ $# -ne 2 ]; then
    echo "Usage: iso2sd <input_file> <output_device>"
    echo "Example: iso2sd $HOME/Downloads/ubuntu-25.04-desktop-amd64.iso /dev/sda"
    echo -e "\nAvailable SD cards:"
    lsblk -d -o NAME | grep -E '^sd[a-z]' | awk '{print "/dev/"$1}'
  else
    sudo dd bs=4M status=progress oflag=sync if="$1" of="$2"
    sudo eject $2
  fi
}

# Create a desktop launcher for a web app
web2app() {
  if [ "$#" -ne 3 ]; then
    echo "Usage: web2app <AppName> <AppURL> <IconURL> (IconURL must be in PNG -- use https://dashboardicons.com)"
    return 1
  fi

  local APP_NAME="$1"
  local APP_URL="$2"
  local ICON_URL="$3"
  local ICON_DIR="$HOME/.local/share/applications/icons"
  local DESKTOP_FILE="$HOME/.local/share/applications/${APP_NAME}.desktop"
  local ICON_PATH="${ICON_DIR}/${APP_NAME}.png"

  mkdir -p "$ICON_DIR"

  if ! curl -sL -o "$ICON_PATH" "$ICON_URL"; then
    echo "Error: Failed to download icon."
    return 1
  fi

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=$APP_NAME
Comment=$APP_NAME
Exec=chromium --new-window --ozone-platform=wayland --app="$APP_URL" --name="$APP_NAME" --class="$APP_NAME"
Terminal=false
Type=Application
Icon=$ICON_PATH
StartupNotify=true
EOF

  chmod +x "$DESKTOP_FILE"
}

web2app-remove() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: web2app-remove <AppName>"
    return 1
  fi

  local APP_NAME="$1"
  local ICON_DIR="$HOME/.local/share/applications/icons"
  local DESKTOP_FILE="$HOME/.local/share/applications/${APP_NAME}.desktop"
  local ICON_PATH="${ICON_DIR}/${APP_NAME}.png"

  rm "$DESKTOP_FILE"
  rm "$ICON_PATH"
}

# Ensure changes to $HOME/.XCompose are immediately available
refresh-xcompose() {
  pkill fcitx5
  setsid fcitx5 &>/dev/null &
}
