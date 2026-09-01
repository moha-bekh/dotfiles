#!/usr/bin/env bash
# Bring a fresh Ubuntu (or Debian) machine to the same state as every other
# host in this repo: Nix installed, home-manager applied, dotfiles symlinked.
#
# Safe to re-run — every step checks whether it already happened.
#
# Works on both architectures: the flake exposes each standalone host twice
# (`moha@ubuntu-btw` for x86_64, `moha@ubuntu-btw-aarch64` for ARM) and this
# picks the right one from `uname -m`.
#
#   curl -fsSL https://raw.githubusercontent.com/moha-bekh/dotfiles/main/scripts/bootstrap-ubuntu.sh | bash
#   # or, from a clone:
#   ~/dotfiles/scripts/bootstrap-ubuntu.sh --gui --docker
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/moha-bekh/dotfiles}"
# home/home.nix builds every config path from ~/dotfiles, so the clone
# location is not negotiable — mkOutOfStoreSymlink bakes it into the symlinks.
DOTFILES="$HOME/dotfiles"
HM_RELEASE="home-manager/release-26.05"

WANT_GUI=0
WANT_DOCKER=0
WANT_ZSH=0

usage() {
  cat <<'USAGE'
Usage: bootstrap-ubuntu.sh [--gui] [--docker] [--zsh]

  --gui     Install the desktop profile (Xorg + oxwm + ghostty + firefox +
            fonts) instead of the headless one, and write the Xorg libinput
            rule that needs root. Skip this on a server/container VM.
  --docker  Install dockerd from apt and add this user to the docker group.
            Standalone home-manager cannot enable a system service, so unlike
            NixOS this cannot come from the flake.
  --zsh     Make the Nix-provided zsh this user's login shell.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --gui) WANT_GUI=1 ;;
    --docker) WANT_DOCKER=1 ;;
    --zsh) WANT_ZSH=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

# --- 0. Sanity checks -------------------------------------------------------

[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root — it installs into \$HOME (it calls sudo itself where needed)"

# home/home.nix hardcodes home.username = "moha" and home.homeDirectory, so a
# differently-named account fails deep inside the switch with a confusing
# mismatch error rather than here.
[ "$(id -un)" = "moha" ] || die "this config is pinned to the user 'moha' (home/home.nix), but you are '$(id -un)'"

command -v apt-get >/dev/null || die "no apt-get — this script is for Ubuntu/Debian; use task arch:bootstrap elsewhere"

case "$(uname -m)" in
  x86_64) ARCH_SUFFIX="" ;;
  aarch64 | arm64) ARCH_SUFFIX="-aarch64" ;;
  *) die "unsupported architecture $(uname -m) — the flake only builds x86_64-linux and aarch64-linux" ;;
esac

if [ "$WANT_GUI" -eq 1 ]; then
  HOST="ubuntu-btw-gui"
else
  HOST="ubuntu-btw"
fi
FLAKE_TARGET="moha@${HOST}${ARCH_SUFFIX}"

log "target: .#${FLAKE_TARGET}  ($(. /etc/os-release && echo "$PRETTY_NAME"), $(uname -m))"

# --- 1. apt prerequisites ---------------------------------------------------
# Only what Nix itself needs to exist first: the installer downloads a
# .tar.xz (xz-utils is NOT in a minimal Ubuntu image) over TLS. Everything
# else in this repo comes from Nix, on purpose — that's what keeps the four
# hosts identical.

APT_PKGS=(curl xz-utils ca-certificates git)
[ "$WANT_DOCKER" -eq 1 ] && APT_PKGS+=(docker.io docker-compose-v2)

MISSING=()
for p in "${APT_PKGS[@]}"; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed" || MISSING+=("$p")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  log "apt: installing ${MISSING[*]}"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING[@]}"
else
  log "apt: prerequisites already present"
fi

# --- 2. the repo ------------------------------------------------------------

if [ ! -d "$DOTFILES/.git" ]; then
  log "cloning $REPO_URL -> $DOTFILES"
  git clone "$REPO_URL" "$DOTFILES"
else
  log "repo already at $DOTFILES"
fi

# --- 3. drop the ~/.config -> dotfiles/config shortcut ----------------------
# Symlinking the whole directory looks equivalent but isn't: it gives every
# application on the machine write access to the repo (so ~/.config/foo/state
# lands in git), it exposes the macOS/Arch-only configs on Ubuntu too, and
# home-manager would then write its own symlinks *into* the repo. The flake
# links each app directory individually instead.

if [ -L "$HOME/.config" ]; then
  log "removing the ~/.config symlink -> $(readlink "$HOME/.config") (contents stay in the repo; home-manager re-links per app)"
  rm "$HOME/.config"
fi
mkdir -p "$HOME/.config"

# --- 4. Nix ----------------------------------------------------------------

NIX_PROFILE_SH="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

if ! command -v nix >/dev/null 2>&1; then
  if [ ! -e "$NIX_PROFILE_SH" ]; then
    log "installing Nix (Determinate Systems installer, flakes enabled)"
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
      sh -s -- install linux --no-confirm
  fi
  # The installer only patches the *login* shell files, so `nix` is not on
  # PATH in this already-running one.
  # shellcheck disable=SC1090
  [ -e "$NIX_PROFILE_SH" ] && . "$NIX_PROFILE_SH"
fi

command -v nix >/dev/null || die "nix is still not on PATH — open a new shell and re-run this script"
log "nix: $(nix --version)"

# --- 5. home-manager switch -------------------------------------------------
# `nix run` rather than the `home-manager` command: standalone home-manager
# only lands on PATH once the shell sources the Nix profile's session vars,
# which is not guaranteed mid-script.
#
# -b backup: standalone home-manager (unlike the NixOS/darwin modules) has no
# backupFileExtension option, so Ubuntu's stock ~/.bashrc and ~/.profile would
# make the switch fail on conflict. This renames them to *.backup instead.

log "applying home-manager configuration (first run downloads a lot; expect several minutes)"
if ! nix run "$HM_RELEASE" -- switch -b backup --flake "${DOTFILES}#${FLAKE_TARGET}"; then
  warn "switch failed. If it complained that a *.backup file already exists, a previous run"
  warn "already moved that file aside — inspect and delete the stale backup, then re-run."
  exit 1
fi

# --- 6. optional system-level bits home-manager cannot do -------------------

if [ "$WANT_DOCKER" -eq 1 ]; then
  log "docker: enabling the daemon and adding $(id -un) to the docker group"
  sudo systemctl enable --now docker.service
  if id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
    echo "already in the docker group"
  else
    sudo usermod -aG docker "$(id -un)"
    warn "log out and back in (or run 'newgrp docker') before using docker without sudo"
  fi
fi

if [ "$WANT_GUI" -eq 1 ]; then
  # Nix's xorg-server ships with no input driver, and the InputClass rule that
  # points Xorg at the Nix-built libinput has to live under /etc/X11 — Xorg
  # only accepts a -configdir outside its defaults when running as root, so
  # home-manager cannot place this one. Without it the keyboard and mouse are
  # enumerated but dead, which reads like a full freeze. See README.
  LIBINPUT_CONF=/etc/X11/xorg.conf.d/40-libinput.conf
  if [ -e "$LIBINPUT_CONF" ]; then
    log "xorg: $LIBINPUT_CONF already present"
  else
    log "xorg: writing $LIBINPUT_CONF (needs root)"
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee "$LIBINPUT_CONF" >/dev/null <<'EOF'
Section "InputClass"
        Identifier "libinput pointer catchall"
        MatchIsPointer "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
EndSection

Section "InputClass"
        Identifier "libinput keyboard catchall"
        MatchIsKeyboard "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
EndSection
EOF
  fi
fi

if [ "$WANT_ZSH" -eq 1 ]; then
  # chsh refuses any shell missing from /etc/shells, and the Nix store path
  # obviously isn't there. Use the stable profile path, not the versioned
  # store path, so it survives the next switch.
  ZSH_BIN="$HOME/.nix-profile/bin/zsh"
  if [ ! -x "$ZSH_BIN" ]; then
    warn "no zsh at $ZSH_BIN — skipping the login shell change"
  elif [ "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$ZSH_BIN" ]; then
    log "zsh is already the login shell"
  else
    log "zsh: registering $ZSH_BIN and setting it as the login shell"
    grep -qxF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$ZSH_BIN" "$(id -un)"
  fi
fi

log "done. Open a new shell (or 'exec \$SHELL -l') to pick up the new PATH and session variables."
echo "   subsequent updates:  cd ~/dotfiles && task ubuntu:switch$([ "$WANT_GUI" -eq 1 ] && echo ':gui')"
