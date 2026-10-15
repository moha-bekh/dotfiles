#!/usr/bin/env bash
# Install everything with pacman, and make zsh the login shell. Safe to
# re-run: only what's missing gets installed.
#
#   ~/dotfiles/scripts/arch/packages.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Same list as scripts/macos/packages.sh, under Arch names. Mac-only tools
# (karabiner, aerospace) and the GNU tools macOS lacks are left out.
PACKAGES=(
  git git-delta git-lfs # config/git/.gitconfig pipes `git add -p` through delta
  github-cli
  tmux
  bc gawk # tokyo-night-tmux
  neovim
  ripgrep fd    # LazyVim pickers
  nodejs npm    # mason.nvim installs some LSPs (vtsls...) through npm
  gcc make unzip # nvim-treesitter compiles parsers, mason unpacks LSPs
  wl-clipboard  # system clipboard for nvim and tmux-yank on Wayland
  btop
  fastfetch
  starship
  fzf
  # yazi and its previewers (it also uses fd, rg, fzf, zoxide)
  yazi 7zip jq poppler resvg
  # used by config/shell/*.sh
  zsh zoxide eza bat zsh-autosuggestions zsh-syntax-highlighting
  ghostty
  zed
  ttf-jetbrains-mono-nerd # config/ghostty/config, plus the icons starship/eza/yazi/tmux draw
  noto-fonts-emoji
)

# --- pacman ------------------------------------------------------------------

MISSING=()
for p in "${PACKAGES[@]}"; do
  pacman -Qq "$p" >/dev/null 2>&1 || MISSING+=("$p")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  log "pacman: installing ${MISSING[*]}"
  sudo pacman -Syu --needed --noconfirm "${MISSING[@]}"
else
  log "pacman: all packages already installed"
fi

git lfs install --skip-repo >/dev/null

# --- login shell -------------------------------------------------------------

ZSH="$(command -v zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH" ]; then
  log "shell: making zsh the login shell"
  chsh -s "$ZSH" || warn "chsh failed — run 'chsh -s $ZSH' by hand"
else
  log "shell: zsh is already the login shell"
fi
