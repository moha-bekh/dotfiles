#!/usr/bin/env bash
# Create an OrbStack machine (if it doesn't exist yet) and set it up with these
# dotfiles: packages, locale, Ghostty terminfo, zsh, tmux, nvim. Safe to re-run
# on an existing machine.
#
#   ~/mac-dotfiles/scripts/orb.sh arch               # machine "arch"
#   ~/mac-dotfiles/scripts/orb.sh ubuntu:noble dev   # machine "dev"
#
# Supported: arch, debian/ubuntu/kali (apt), fedora (dnf).
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

DISTRO="${1:?usage: orb.sh <distro[:version]> [machine name]}"
NAME="${2:-${DISTRO%%:*}}"

if orb info "$NAME" >/dev/null 2>&1; then
  log "orb: machine $NAME already exists, provisioning it again"
else
  log "orb: creating $NAME ($DISTRO)"
  orb create "$DISTRO" "$NAME"
fi

# /Users is mounted at the same path inside the machine, so the provisioning
# script (and the configs it links) are read straight from this repo.
orb -m "$NAME" bash "$DOTFILES/scripts/orb-provision.sh"

# Ghostty sets TERM=xterm-ghostty, which no distro ships: without it zsh can't
# redraw the line and `clear` fails.
# After provisioning: tic comes with ncurses, which some images lack.
if infocmp -x xterm-ghostty >/dev/null 2>&1; then
  log "terminfo: installing xterm-ghostty"
  infocmp -x xterm-ghostty | orb -m "$NAME" sudo tic -x -o /usr/share/terminfo /dev/stdin 2>/dev/null
fi

log "done. Open it with: orb -m $NAME"
