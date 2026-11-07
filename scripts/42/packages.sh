#!/usr/bin/env bash
# 42 school machines (Fedora, no sudo): installs the same tools as the other
# scripts/<os>/packages.sh, but only into $HOME — binaries from GitHub releases
# in ~/.local/bin, zsh plugins cloned into ~/.local/share/zsh/plugins, the Nerd
# Font into ~/.local/share/fonts. What the machine already ships (git, tmux,
# nvim, rg, bat, jq, node, gcc...) is used as is, unless it's too old.
# Safe to re-run: only what's missing gets installed. The home is small
# (~5G), so archives are unpacked in a temp dir and only the binaries are kept.
#
#   ~/dotfiles/scripts/42/packages.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

BIN="$HOME/.local/bin"
OPT="$HOME/.local/opt"
mkdir -p "$BIN" "$OPT"
export PATH="$BIN:$PATH"

[ "$(uname -m)" = x86_64 ] || { warn "only x86_64 is handled"; exit 1; }

# version_ge <have> <want>
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | sed -n '1p')" = "$2" ]; }

# release_url <owner/repo> <regex matching the asset name>
release_url() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    jq -r '.assets[].browser_download_url' | grep -E "$2" | sed -n '1p'
}

# fetch <owner/repo> <asset regex> <dir>: download and unpack the asset in <dir>
fetch() {
  local url
  url="$(release_url "$1" "$2")"
  [ -n "$url" ] || { warn "no release asset matching $2 in $1"; return 1; }
  curl -fsSL "$url" -o "$3/asset"
  mkdir -p "$3/x"
  case "$url" in
    *.zip) unzip -q "$3/asset" -d "$3/x" ;;
    *.tar.gz | *.tgz) tar -xzf "$3/asset" -C "$3/x" ;;
    *.tar.xz) tar -xJf "$3/asset" -C "$3/x" ;;
    *.tbz | *.tar.bz2) tar -xjf "$3/asset" -C "$3/x" ;;
    *) warn "unsupported release archive: $url"; return 1 ;;
  esac
}

# from_release <owner/repo> <asset regex> <binary>...
from_release() {
  local repo="$1" regex="$2" tmp bin path
  shift 2
  tmp="$(mktemp -d)"
  if fetch "$repo" "$regex" "$tmp"; then
    for bin in "$@"; do
      path="$(find "$tmp/x" -type f -name "$bin" -perm -u+x | sed -n '1p')"
      [ -n "$path" ] || path="$(find "$tmp/x" -type f -name "$bin" | sed -n '1p')"
      install -m 755 "$path" "$BIN/$bin"
      echo "  installed $bin from $repo"
    done
  fi
  rm -rf "$tmp"
}

# --- binaries ----------------------------------------------------------------

log "binaries: installing what's missing into $BIN"

command -v fd >/dev/null || from_release sharkdp/fd "x86_64-unknown-linux-musl\.tar\.gz$" fd
command -v starship >/dev/null || from_release starship/starship "starship-x86_64-unknown-linux-musl\.tar\.gz$" starship
command -v zoxide >/dev/null || from_release ajeetdsouza/zoxide "x86_64-unknown-linux-musl\.tar\.gz$" zoxide
command -v eza >/dev/null || from_release eza-community/eza "eza_x86_64-unknown-linux-musl\.tar\.gz$" eza
command -v yazi >/dev/null || from_release sxyazi/yazi "yazi-x86_64-unknown-linux-musl\.zip$" yazi ya
command -v delta >/dev/null || from_release dandavison/delta "x86_64-unknown-linux-musl\.tar\.gz$" delta
command -v btop >/dev/null || from_release aristocratos/btop "btop-x86_64-unknown-linux-musl\.(tbz|tar\.gz)$" btop
command -v fastfetch >/dev/null || from_release fastfetch-cli/fastfetch "fastfetch-linux-amd64\.tar\.gz$" fastfetch
command -v gh >/dev/null || from_release cli/cli "gh_[0-9.]+_linux_amd64\.tar\.gz$" gh
command -v git-lfs >/dev/null || from_release git-lfs/git-lfs "git-lfs-linux-amd64-v[0-9.]+\.tar\.gz$" git-lfs
command -v bat >/dev/null || from_release sharkdp/bat "x86_64-unknown-linux-musl\.tar\.gz$" bat
command -v rg >/dev/null || from_release BurntSushi/ripgrep "x86_64-unknown-linux-musl\.tar\.gz$" rg
command -v tree-sitter >/dev/null || {
  # shipped as a bare .gz, not an archive
  url="$(release_url tree-sitter/tree-sitter "tree-sitter-linux-x64\.gz$")"
  [ -n "$url" ] && curl -fsSL "$url" | gunzip >"$BIN/tree-sitter" && chmod 755 "$BIN/tree-sitter" &&
    echo "  installed tree-sitter from tree-sitter/tree-sitter"
}

# `fzf --zsh` (config/shell/zsh.sh) needs fzf 0.48+
FZF_VERSION="$(fzf --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || echo 0)"
version_ge "$FZF_VERSION" 0.48 || from_release junegunn/fzf "linux_amd64\.tar\.gz$" fzf

# LazyVim needs nvim 0.11+. nvim needs its runtime/ next to the binary: keep
# the whole tree in ~/.local/opt/nvim and link the binary.
NVIM_VERSION="$(nvim --version 2>/dev/null | sed -n '1p' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo 0)"
if ! version_ge "$NVIM_VERSION" 0.11.0; then
  tmp="$(mktemp -d)"
  fetch neovim/neovim "nvim-linux-x86_64\.tar\.gz$" "$tmp"
  rm -rf "$OPT/nvim"
  mv "$tmp/x/"nvim-linux-x86_64 "$OPT/nvim"
  rm -rf "$tmp"
  ln -sf "$OPT/nvim/bin/nvim" "$BIN/nvim"
  echo "  installed nvim from neovim/neovim (had $NVIM_VERSION)"
fi

# The machine must already have these: they can't come from a release.
for t in git tmux zsh curl jq unzip node npm gcc make; do
  command -v "$t" >/dev/null || warn "$t is missing and can't be installed without sudo"
done

git lfs install --skip-repo >/dev/null 2>&1 || true

# --- zsh plugins -------------------------------------------------------------
# config/shell/zsh.sh looks them up in ~/.local/share/zsh/plugins/<name>/.

PLUGINS="$HOME/.local/share/zsh/plugins"
mkdir -p "$PLUGINS"
for p in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
  if [ -d "$PLUGINS/${p#*/}/.git" ]; then
    log "zsh: ${p#*/} already cloned"
  else
    log "zsh: cloning ${p#*/}"
    git clone -q --depth 1 "https://github.com/$p" "$PLUGINS/${p#*/}"
  fi
done

# --- font --------------------------------------------------------------------
# config/ghostty/config, plus the icons starship/eza/yazi/tmux draw. Only the
# regular (non-Mono, non-Propo) variants are kept, to save space.

FONTS="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if fc-list | grep -q "JetBrainsMono Nerd Font"; then
  log "font: JetBrainsMono Nerd Font already installed"
else
  log "font: installing JetBrainsMono Nerd Font"
  tmp="$(mktemp -d)"
  fetch ryanoasis/nerd-fonts "/JetBrainsMono\.tar\.xz$" "$tmp"
  mkdir -p "$FONTS"
  find "$tmp/x" -name 'JetBrainsMonoNerdFont-*.ttf' -exec cp {} "$FONTS/" \;
  rm -rf "$tmp"
  fc-cache -f "$FONTS" >/dev/null
fi
