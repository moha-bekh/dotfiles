#!/usr/bin/env bash
# Set up a fresh Ubuntu Server without Nix: apt for whatever Ubuntu ships
# recent enough, upstream releases for the rest, and GNU stow to symlink the
# configs from this repo into place.
#
# Safe to re-run — every step checks whether it already happened, and any
# real file stow would collide with is moved aside to *.bak-<timestamp>.
#
#   ~/dotfiles/ubuntu-server/install.sh
set -euo pipefail

# Derived from this script's location rather than hardcoded, so the clone
# can live anywhere — unlike home/home.nix, stow takes the path at run time.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
# LazyVim refuses to start on anything older.
NVIM_MIN="0.11.2"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

# --- 0. Sanity checks -------------------------------------------------------

[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root — it installs into \$HOME (it calls sudo itself where needed)"
command -v apt-get >/dev/null || die "no apt-get — this script is for Ubuntu/Debian"

case "$(uname -m)" in
  x86_64)
    NVIM_ARCH="x86_64"
    FASTFETCH_ARCH="amd64"
    ;;
  aarch64 | arm64)
    NVIM_ARCH="arm64"
    FASTFETCH_ARCH="aarch64"
    ;;
  *) die "unsupported architecture $(uname -m)" ;;
esac

log "dotfiles: $DOTFILES  ($(. /etc/os-release && echo "$PRETTY_NAME"), $(uname -m))"

mkdir -p "$LOCAL_BIN" "$HOME/.config"
export PATH="$LOCAL_BIN:$PATH"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. apt -----------------------------------------------------------------
# neovim, starship and fastfetch are deliberately absent: noble's neovim is
# 0.9 (too old for LazyVim), and the other two aren't packaged at all.

APT_PKGS=(
  curl ca-certificates xz-utils unzip fontconfig
  stow
  bash bash-completion
  git git-lfs git-delta # config/git/.gitconfig pipes `git add -p` through delta
  openssh-client openssh-server
  tmux
  btop
  # nvim/LazyVim runtime deps: telescope/fzf-lua need rg + fd, treesitter
  # compiles parsers with a C compiler
  build-essential ripgrep fd-find
  # used by config/shell/*.sh
  fzf eza zoxide bat
)

MISSING=()
for p in "${APT_PKGS[@]}"; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed" || MISSING+=("$p")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  log "apt: installing ${MISSING[*]}"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y "${MISSING[@]}"
else
  log "apt: everything already present"
fi

# Debian renames these two to dodge name clashes with unrelated packages;
# the shell aliases and nvim plugins expect the upstream names.
[ -e "$LOCAL_BIN/bat" ] || ln -s "$(command -v batcat)" "$LOCAL_BIN/bat"
[ -e "$LOCAL_BIN/fd" ] || ln -s "$(command -v fdfind)" "$LOCAL_BIN/fd"

# --- 2. neovim (upstream release) -------------------------------------------

version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

NVIM_DIR="$HOME/.local/nvim-linux-$NVIM_ARCH"
nvim_version() { "$LOCAL_BIN/nvim" --version 2>/dev/null | head -1 | sed 's/^NVIM v//'; }

if [ -x "$LOCAL_BIN/nvim" ] && version_ge "$(nvim_version)" "$NVIM_MIN"; then
  log "nvim: $(nvim_version) already installed"
else
  log "nvim: installing the latest release to $NVIM_DIR"
  curl -fsSL -o "$TMP/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$NVIM_ARCH.tar.gz"
  rm -rf "$NVIM_DIR"
  tar -C "$HOME/.local" -xzf "$TMP/nvim.tar.gz"
  ln -sfn "$NVIM_DIR/bin/nvim" "$LOCAL_BIN/nvim"
  log "nvim: $(nvim_version)"
fi

# --- 3. starship ------------------------------------------------------------

if command -v starship >/dev/null; then
  log "starship: $(starship --version | head -1) already installed"
else
  log "starship: installing to $LOCAL_BIN"
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$LOCAL_BIN"
fi

# --- 4. fastfetch (upstream .deb) -------------------------------------------

if command -v fastfetch >/dev/null; then
  log "fastfetch: already installed"
else
  log "fastfetch: installing the latest .deb"
  curl -fsSL -o "$TMP/fastfetch.deb" \
    "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$FASTFETCH_ARCH.deb"
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y "$TMP/fastfetch.deb"
fi

# --- 5. JetBrainsMono Nerd Font ---------------------------------------------
# Only matters for whatever terminal renders this machine's output — over SSH
# that's the client's font — but starship/eza icons need it on a local console.

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if [ -n "$(ls -A "$FONT_DIR" 2>/dev/null)" ]; then
  log "font: JetBrainsMono Nerd Font already installed"
else
  log "font: installing JetBrainsMono Nerd Font to $FONT_DIR"
  mkdir -p "$FONT_DIR"
  curl -fsSL -o "$TMP/JetBrainsMono.tar.xz" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
  tar -C "$FONT_DIR" -xJf "$TMP/JetBrainsMono.tar.xz"
  fc-cache -f "$FONT_DIR" >/dev/null
fi

# --- 6. stow the configs ----------------------------------------------------
# config/<app>/ holds the *contents* of ~/.config/<app>/ (that's the layout
# home/home.nix links from), so each package gets its own target dir instead
# of the usual single `stow -t ~`.
#
# stow refuses to replace real files, so anything already in the way — e.g.
# Ubuntu's stock files, or a config copied by hand earlier — is moved aside.

backup_conflicts() {
  local pkg="$1" target="$2" rel t
  while IFS= read -r rel; do
    t="$target/$rel"
    [ -e "$t" ] || [ -L "$t" ] || continue
    [ "$(readlink -f "$t")" = "$(readlink -f "$pkg/$rel")" ] && continue
    warn "moving $t aside to $t.bak-$STAMP"
    mv "$t" "$t.bak-$STAMP"
  done < <(cd "$pkg" && find . -mindepth 1 \( -type f -o -type l \) -printf '%P\n')
}

# stow_pkg <dir containing the package> <package> <target>
stow_pkg() {
  local dir="$1" name="$2" target="$3"
  mkdir -p "$target"
  backup_conflicts "$dir/$name" "$target"
  stow --restow --dir "$dir" --target "$target" "$name"
  echo "  $name -> $target"
}

log "stow: linking configs from $DOTFILES"
for app in nvim btop fastfetch shell; do
  stow_pkg "$DOTFILES/config" "$app" "$HOME/.config/$app"
done
stow_pkg "$DOTFILES/config" starship "$HOME/.config"
stow_pkg "$DOTFILES/config" git "$HOME"
# On Nix hosts home/tmux.nix generates tmux.conf; this is its standalone twin.
stow_pkg "$DOTFILES/non-nix" tmux "$HOME/.config/tmux"

# --- 7. bash ----------------------------------------------------------------
# Keep Ubuntu's own ~/.bashrc (it sets up lesspipe, dircolors, etc.) and just
# hook config/shell/bash.sh onto the end of it, like home.nix's initExtra.

BASHRC_LINE='[ -f "$HOME/.config/shell/bash.sh" ] && source "$HOME/.config/shell/bash.sh"'
touch "$HOME/.bashrc"
if grep -qxF "$BASHRC_LINE" "$HOME/.bashrc"; then
  log "bash: ~/.bashrc already sources config/shell/bash.sh"
else
  log "bash: hooking config/shell/bash.sh into ~/.bashrc"
  printf '\n# dotfiles\n%s\n' "$BASHRC_LINE" >>"$HOME/.bashrc"
fi

# --- 8. tmux plugins (tpm) --------------------------------------------------

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR/.git" ]; then
  log "tpm: already cloned"
else
  log "tpm: cloning to $TPM_DIR"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# install_plugins reads the @plugin list from a running tmux server. Reuse
# one if it's up; otherwise start a throwaway one and stop it afterwards.
log "tpm: installing plugins"
STARTED_TMUX=0
if ! tmux has-session 2>/dev/null; then
  tmux new-session -d -s tpm-install && STARTED_TMUX=1
fi
tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
"$TPM_DIR/bin/install_plugins" >/dev/null ||
  warn "tpm plugin install failed — press prefix + I inside tmux to retry"
[ "$STARTED_TMUX" -eq 1 ] && tmux kill-session -t tpm-install 2>/dev/null || true

# --- 9. ssh -----------------------------------------------------------------
# sshd_config is left alone on purpose: a wrong edit there locks you out of a
# remote box. This only makes sure the daemon runs and an agent is there for
# `ssh-add` — no key is generated, bring your own.

log "ssh: enabling the server and checking ~/.ssh"
sudo systemctl enable --now ssh.service 2>/dev/null ||
  sudo systemctl enable --now ssh.socket 2>/dev/null ||
  warn "could not enable sshd (no systemd?)"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
[ -f "$HOME/.ssh/authorized_keys" ] && chmod 600 "$HOME/.ssh/authorized_keys"

# Ubuntu's own ssh-agent user unit only starts under an X session
# (ConditionPathExists=/etc/X11/Xsession.options), so it never runs on a
# server. This one, same name, shadows it.
log "ssh-agent: user service on \$XDG_RUNTIME_DIR/ssh-agent.socket"
AGENT_UNIT="$HOME/.config/systemd/user/ssh-agent.service"
mkdir -p "$(dirname "$AGENT_UNIT")"
cat >"$AGENT_UNIT" <<'UNIT'
[Unit]
Description=OpenSSH Agent
Documentation=man:ssh-agent(1)

[Service]
ExecStart=/usr/bin/ssh-agent -D -a %t/ssh-agent.socket

[Install]
WantedBy=default.target
UNIT
{ systemctl --user daemon-reload && systemctl --user enable --now ssh-agent.service; } 2>/dev/null ||
  warn "could not start the ssh-agent user service (no user systemd session?)"

# Only when unset, so an agent forwarded with `ssh -A` still wins.
AGENT_LINE='[ -n "$SSH_AUTH_SOCK" ] || export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"'
if grep -qxF "$AGENT_LINE" "$HOME/.bashrc"; then
  log "ssh-agent: ~/.bashrc already points SSH_AUTH_SOCK at it"
else
  log "ssh-agent: pointing SSH_AUTH_SOCK at it in ~/.bashrc"
  printf '%s\n' "$AGENT_LINE" >>"$HOME/.bashrc"
fi

# --- 10. git ----------------------------------------------------------------

git lfs install --skip-repo >/dev/null

# config/git/.gitconfig signs every commit with a GPG key that won't be on a
# fresh server, which makes `git commit` fail outright.
SIGNING_KEY="$(git config --global user.signingkey || true)"
if [ -n "$SIGNING_KEY" ] && ! gpg --list-secret-keys "$SIGNING_KEY" >/dev/null 2>&1; then
  warn "git signs commits with GPG key $SIGNING_KEY, which isn't in this machine's keyring —"
  warn "import it (gpg --import) or commits will fail"
fi

log "done. Open a new shell (or 'exec bash -l') to pick up the new config,"
echo "  then load a key into the agent with: ssh-add <key>"
