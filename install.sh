#!/usr/bin/env bash
# Fresh Mac: install the packages, link the configs, apply the macOS settings.
#
#   ~/mac-dotfiles/install.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/scripts/packages.sh"
"$DIR/scripts/link.sh"
"$DIR/scripts/macos.sh"

cat <<'MSG'

Manual steps left:
  - open Karabiner-Elements and AeroSpace once, and allow them in
    System Settings > Privacy & Security (Accessibility / Input Monitoring)
  - first `nvim` launch installs the plugins and LSPs
MSG
