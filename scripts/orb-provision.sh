#!/usr/bin/env bash
# Runs inside an OrbStack Linux machine (scripts/orb.sh calls it). Installs the
# same tools as scripts/macos/packages.sh with the distro's package manager, falls
# back to GitHub releases for what's missing or too old, then links the configs.
# Safe to re-run.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

. /etc/os-release
case " $ID ${ID_LIKE:-} " in
  *" arch "* | *" archarm "*) FAMILY=arch ;;
  *" debian "* | *" ubuntu "*) FAMILY=debian ;;
  *" fedora "*) FAMILY=fedora ;;
  *) echo "unsupported distro: $ID (supported: arch, debian/ubuntu, fedora)" >&2; exit 1 ;;
esac

# --- packages ----------------------------------------------------------------
# Same list as scripts/macos/packages.sh, under each distro's names. Packages a distro
# doesn't have are skipped here and picked up by the fallbacks below.

case "$FAMILY" in
  arch)
    PKGS=(git git-delta git-lfs github-cli tmux bash bc gawk sed neovim ripgrep fd
      nodejs npm btop fastfetch starship fzf yazi 7zip jq poppler resvg zoxide eza
      bat zsh zsh-autosuggestions zsh-syntax-highlighting gnupg unzip wget curl
      base-devel tree-sitter-cli ncurses file)
    ;;
  debian)
    PKGS=(git git-delta git-lfs gh tmux bc gawk neovim ripgrep fd-find nodejs npm
      btop fastfetch fzf 7zip jq poppler-utils zoxide eza bat zsh
      zsh-autosuggestions zsh-syntax-highlighting gnupg unzip wget curl
      build-essential locales ncurses-bin file)
    ;;
  fedora)
    PKGS=(git git-delta git-lfs gh tmux bc gawk neovim ripgrep fd-find nodejs npm
      btop fastfetch fzf 7zip jq poppler-utils zoxide eza bat zsh
      zsh-autosuggestions zsh-syntax-highlighting gnupg2 unzip wget curl gcc
      gcc-c++ make tree-sitter-cli glibc-langpack-en ncurses file)
    ;;
esac

log "packages: installing with the $FAMILY package manager"
case "$FAMILY" in
  arch)
    sudo pacman -Syu --noconfirm >/dev/null
    AVAIL=()
    for p in "${PKGS[@]}"; do pacman -Si "$p" >/dev/null 2>&1 && AVAIL+=("$p"); done
    sudo pacman -S --needed --noconfirm "${AVAIL[@]}" >/dev/null
    ;;
  debian)
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get update -qq
    AVAIL=()
    for p in "${PKGS[@]}"; do apt-cache show "$p" >/dev/null 2>&1 && AVAIL+=("$p"); done
    sudo -E apt-get install -y -qq "${AVAIL[@]}" >/dev/null
    ;;
  fedora)
    sudo dnf install -y -q --skip-unavailable "${PKGS[@]}" >/dev/null
    ;;
esac

# Debian renames these binaries to avoid clashes with older packages.
command -v fdfind >/dev/null && ! command -v fd >/dev/null && sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
command -v batcat >/dev/null && ! command -v bat >/dev/null && sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat

# --- fallbacks: GitHub releases ----------------------------------------------
# For tools the distro lacks, or ships too old (LazyVim needs nvim 0.11,
# `fzf --zsh` needs fzf 0.48). Installed in /usr/local/bin, which comes before
# /usr/bin in PATH, so they win over an older distro package.

case "$(uname -m)" in
  aarch64 | arm64) A=aarch64 D=arm64 ;;
  x86_64) A=x86_64 D=amd64 ;;
  *) warn "unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# version_ge <have> <want>
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | sed -n '1p')" = "$2" ]; }

# release_url <owner/repo> <regex matching the asset name>
release_url() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    jq -r '.assets[].browser_download_url' | grep -E "$2" | sed -n '1p'
}

# from_release <owner/repo> <asset regex> <binary>...
from_release() {
  local repo="$1" regex="$2" url tmp bin
  shift 2
  url="$(release_url "$repo" "$regex")"
  [ -n "$url" ] || { warn "no release asset matching $regex in $repo"; return 1; }
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/asset"
  case "$url" in
    *.zip) unzip -q "$tmp/asset" -d "$tmp/x" ;;
    *.tar.gz | *.tgz) mkdir "$tmp/x" && tar -xzf "$tmp/asset" -C "$tmp/x" ;;
    *.gz) mkdir "$tmp/x" && gunzip -c "$tmp/asset" >"$tmp/x/$1" ;;
    *) warn "unsupported release archive: $url"; rm -rf "$tmp"; return 1 ;;
  esac
  for bin in "$@"; do
    sudo install -m 755 "$(find "$tmp/x" -type f -name "$bin" | sed -n '1p')" "/usr/local/bin/$bin"
    echo "  installed $bin from $repo"
  done
  rm -rf "$tmp"
}

log "fallbacks: checking for missing or outdated tools"

NVIM_VERSION="$(nvim --version 2>/dev/null | sed -n '1p' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo 0)"
if ! version_ge "$NVIM_VERSION" 0.11.0; then
  # nvim needs its runtime/ next to the binary: unpack the whole tree in /opt.
  url="$(release_url neovim/neovim "nvim-linux-(${D/amd64/x86_64})\.tar\.gz$")"
  [ -n "$url" ] || { warn "no Neovim release asset for $D"; exit 1; }
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  sudo mkdir -p /opt/nvim
  sudo tar -xz -C /opt/nvim --strip-components=1 -f "$tmp/nvim.tar.gz"
  rm -rf "$tmp"
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  echo "  installed nvim from neovim/neovim (had $NVIM_VERSION)"
fi

FZF_VERSION="$(fzf --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || echo 0)"
version_ge "$FZF_VERSION" 0.48 || from_release junegunn/fzf "linux_${D}\.tar\.gz$" fzf

command -v starship >/dev/null || from_release starship/starship "starship-${A}-unknown-linux-musl\.tar\.gz$" starship
command -v zoxide >/dev/null || from_release ajeetdsouza/zoxide "${A}-unknown-linux-musl\.tar\.gz$" zoxide
command -v eza >/dev/null || from_release eza-community/eza "eza_${A}-unknown-linux-gnu\.tar\.gz$" eza
command -v yazi >/dev/null || from_release sxyazi/yazi "yazi-${A}-unknown-linux-gnu\.zip$" yazi ya
command -v delta >/dev/null || from_release dandavison/delta "${A}-unknown-linux-gnu\.tar\.gz$" delta
command -v fastfetch >/dev/null || from_release fastfetch-cli/fastfetch "fastfetch-linux-${D/arm64/aarch64}\.tar\.gz$" fastfetch
command -v tree-sitter >/dev/null || from_release tree-sitter/tree-sitter "tree-sitter-linux-${A/aarch64/arm64}\.gz$" tree-sitter

# --- locale ------------------------------------------------------------------
# Images default to LANG=C: starship, eza and tmux icons then render as "????".

log "locale: en_US.UTF-8"
case "$FAMILY" in
  arch | debian)
    [ -f /etc/locale.gen ] && sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen en_US.UTF-8 >/dev/null
    ;;
esac
echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf >/dev/null
[ "$FAMILY" = debian ] && sudo update-locale LANG=en_US.UTF-8

# --- configs -----------------------------------------------------------------
# Same layout as scripts/link.sh, minus the macOS-only apps (ghostty,
# karabiner, aerospace, wallpaper).

# link <source in config/, or absolute path> <target>
link() {
  local src="$1" target="$2"
  case "$src" in /*) ;; *) src="$DOTFILES/config/$src" ;; esac
  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    echo "  ok      $target"
    return
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    warn "moving $target aside to $target.bak-$STAMP"
    mv "$target" "$target.bak-$STAMP"
  fi
  ln -s "$src" "$target"
  echo "  linked  $target -> $src"
}

log "linking configs from $DOTFILES"
for app in nvim tmux btop fastfetch yazi shell; do
  link "$app" "$HOME/.config/$app"
done
link starship/starship.toml "$HOME/.config/starship.toml"
link git/.gitconfig "$HOME/.gitconfig"

# --- dev ---------------------------------------------------------------------
# Projects live on the Mac (~/dev, mounted at the same path here). ~/dev points
# at them, and cargo builds into the VM's own disk: thousands of small files in
# target/ are slow over the Mac mount, and the Mac's cargo can't clobber them.
# A cargo config rather than CARGO_TARGET_DIR, so editors that start
# rust-analyzer over SSH (no .zshrc) pick it up too.

MAC_HOME="$(dirname "$DOTFILES")"
[ -d "$MAC_HOME/dev" ] && link "$MAC_HOME/dev" "$HOME/dev"

if [ ! -x "$HOME/.cargo/bin/cargo" ]; then
  log "rust: installing the stable toolchain with rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q --no-modify-path
fi

if [ ! -f "$HOME/.cargo/config.toml" ]; then
  log "cargo: building into ~/.cache/cargo-target"
  mkdir -p "$HOME/.cargo"
  printf '[build]\ntarget-dir = "%s/.cache/cargo-target"\n' "$HOME" >"$HOME/.cargo/config.toml"
fi

# --- zsh ---------------------------------------------------------------------

ZSHRC_LINE='[ -f "$HOME/.config/shell/zsh.sh" ] && source "$HOME/.config/shell/zsh.sh"'
touch "$HOME/.zshrc"
if ! grep -qxF "$ZSHRC_LINE" "$HOME/.zshrc"; then
  log "zsh: hooking config/shell/zsh.sh into ~/.zshrc"
  printf '\n# dotfiles\n%s\n' "$ZSHRC_LINE" >>"$HOME/.zshrc"
fi
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  log "zsh: making it the login shell"
  sudo usermod -s "$(command -v zsh)" "$USER"
fi

# --- tmux plugins (tpm) ------------------------------------------------------

TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR/.git" ]; then
  log "tpm: cloning to $TPM_DIR"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
log "tpm: installing plugins"
STARTED_TMUX=0
if ! tmux has-session 2>/dev/null; then
  tmux new-session -d -s tpm-install && STARTED_TMUX=1
fi
tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
"$TPM_DIR/bin/install_plugins" >/dev/null ||
  warn "tpm plugin install failed — press prefix + I inside tmux to retry"
[ "$STARTED_TMUX" -eq 1 ] && tmux kill-session -t tpm-install 2>/dev/null || true

# --- nvim plugins ------------------------------------------------------------
# restore, not sync: install the versions pinned in lazy-lock.json without
# rewriting it (the file is shared with the Mac).

# Lazy can still bump a plugin it fails to check out at the pinned commit, so
# put the lockfile back as it was.
log "nvim: installing plugins from lazy-lock.json"
LOCK="$DOTFILES/config/nvim/lazy-lock.json"
LOCK_BAK="$(mktemp)"
cp "$LOCK" "$LOCK_BAK"
nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 ||
  warn "nvim plugin install failed — run :Lazy restore inside nvim"
cmp -s "$LOCK" "$LOCK_BAK" || cp "$LOCK_BAK" "$LOCK"
rm -f "$LOCK_BAK"
