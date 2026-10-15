#!/usr/bin/env bash
# Fresh machine: install the packages, link the configs, apply the OS settings.
# Picks scripts/<os>/ from the OS it runs on.
#
#   ~/dotfiles/install.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/scripts/lib.sh"

case "$OS" in
macos)
  "$DIR/scripts/macos/packages.sh"
  "$DIR/scripts/link.sh"
  "$DIR/scripts/macos/settings.sh"
  cat <<'MSG'

Manual steps left:
  - open Karabiner-Elements and AeroSpace once, and allow them in
    System Settings > Privacy & Security (Accessibility / Input Monitoring)
  - first `nvim` launch installs the plugins and LSPs
MSG
  ;;
arch)
  "$DIR/scripts/arch/packages.sh"
  "$DIR/scripts/link.sh"
  cat <<'MSG'

Manual steps left:
  - log out and back in for zsh to become the login shell
  - first `nvim` launch installs the plugins and LSPs
MSG
  ;;
*)
  warn "unsupported OS — only macOS and Arch for now"
  exit 1
  ;;
esac
