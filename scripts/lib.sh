# Shared helpers, sourced by the other scripts.

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# Which scripts/<os>/ applies to this machine: macos, arch, nixos, 42.
# 42 = the school machines (no sudo), spotted by their shared /sgoinfre disk.
detect_os() {
  if [ "$(uname -s)" = Darwin ]; then
    echo macos
  elif [ -d /sgoinfre ] || [[ "$(hostname)" == *.42.school ]]; then
    echo 42
  elif [ -f /etc/NIXOS ]; then
    echo nixos
  elif [ -f /etc/arch-release ]; then
    echo arch
  else
    echo unknown
  fi
}
OS="$(detect_os)"
