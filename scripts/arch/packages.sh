#!/usr/bin/env bash
# Install everything with pacman. Safe to re-run: only what's missing gets
# installed. The login shell is left alone — config/shell/ covers bash and zsh.
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
  tailscale # reach this machine over the tailnet (Tailscale SSH, see below)
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

# --- tailscale ---------------------------------------------------------------
# Joins the tailnet with Tailscale SSH on, so `ssh <user>@<hostname>` works from
# any device on the tailnet with no sshd or keys to manage. The first run
# prints a login URL and waits until it's approved.

sudo systemctl enable --now tailscaled
if tailscale status >/dev/null 2>&1; then
  log "tailscale: already logged in"
else
  log "tailscale: logging in (open the URL below)"
  sudo tailscale up --ssh || warn "tailscale up failed — run 'sudo tailscale up --ssh' by hand"
fi
