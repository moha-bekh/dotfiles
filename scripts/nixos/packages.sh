#!/usr/bin/env bash
# Install the personal package list (scripts/nixos/home.nix) with standalone
# home-manager. Safe to re-run — home-manager only applies the diff.
#
# This never touches /etc/nixos/configuration.nix: system config, niri and
# DankMaterialShell are managed outside this repo, on purpose.
#
#   ~/dotfiles/scripts/nixos/packages.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Flakes aren't enabled system-wide on nixos-btw (that would mean touching
# /etc/nixos/configuration.nix). A --extra-experimental-features flag on this
# command alone isn't enough either: `home-manager switch` shells out to a
# plain `nix` subprocess internally, which doesn't inherit it. A user-level
# nix.conf is what both this command and that subprocess actually pick up.
NIX_CONF="$HOME/.config/nix/nix.conf"
if ! grep -q "^experimental-features.*flakes" "$NIX_CONF" 2>/dev/null; then
  log "nix: enabling flakes in $NIX_CONF"
  mkdir -p "$(dirname "$NIX_CONF")"
  printf 'experimental-features = nix-command flakes\n' >>"$NIX_CONF"
fi

log "home-manager: switching (packages from scripts/nixos/home.nix)"
nix run home-manager/release-26.05 -- switch -b backup --flake "$DOTFILES#moha"
