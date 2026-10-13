#!/usr/bin/env bash
# Install everything with Homebrew. Safe to re-run: only what's missing gets
# installed.
#
#   ~/mac-dotfiles/scripts/packages.sh
set -euo pipefail

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

# Each tool from the list, followed by what its config needs to work.
FORMULAE=(
  git git-delta git-lfs # config/git/.gitconfig pipes `git add -p` through delta
  tmux
  neovim
  ripgrep fd # LazyVim pickers
  node       # mason.nvim installs some LSPs (vtsls...) through npm
  btop
  fastfetch
  starship
  fzf
  # yazi and its previewers (it also uses fd, rg, fzf, zoxide)
  yazi sevenzip jq poppler resvg
  # used by config/shell/*.sh
  zoxide eza bat zsh-autosuggestions zsh-syntax-highlighting
)

CASKS=(
  ghostty
  karabiner-elements
  nikitabobko/tap/aerospace
)

# --- Homebrew ----------------------------------------------------------------

if ! command -v brew >/dev/null; then
  log "brew: installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# --- formulae ----------------------------------------------------------------

INSTALLED="$(brew list --formula -1)"
MISSING=()
for f in "${FORMULAE[@]}"; do
  grep -qx "$f" <<<"$INSTALLED" || MISSING+=("$f")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  log "brew: installing ${MISSING[*]}"
  brew install "${MISSING[@]}"
else
  log "brew: all formulae already installed"
fi

# --- casks -------------------------------------------------------------------

INSTALLED="$(brew list --cask -1)"
for c in "${CASKS[@]}"; do
  # a tapped cask is listed under its short name
  if grep -qx "${c##*/}" <<<"$INSTALLED"; then
    log "cask: ${c##*/} already installed"
  else
    log "cask: installing ${c##*/}"
    brew install --cask "$c"
  fi
done

git lfs install --skip-repo >/dev/null
