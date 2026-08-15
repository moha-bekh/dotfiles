#!/usr/bin/env bash
# GUI/graphics-stack packages for Arch, installed via pacman/yay instead of
# home-manager. Nix-built GUI binaries link against Nix's glibc and dlopen
# system libGTK/libEGL/libGL at runtime — the version mismatch can break
# OpenGL context creation (see: ghostty "Failed to create EGL display").
# Anything that touches X11/Wayland/GTK/GL directly belongs here, not in
# home/home.nix.
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "error: pacman not found — this script is Arch Linux only." >&2
  exit 1
fi

PACMAN_PKGS=(ghostty gparted rofi)
AUR_PKGS=(oxwm-git)

sudo pacman -S --needed "${PACMAN_PKGS[@]}"

if command -v yay >/dev/null 2>&1; then
  yay -S --needed "${AUR_PKGS[@]}"
else
  echo "error: yay not found — install it to get: ${AUR_PKGS[*]}" >&2
  exit 1
fi
