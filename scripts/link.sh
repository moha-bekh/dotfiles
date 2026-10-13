#!/usr/bin/env bash
# Symlink the configs from this repo into place. Safe to re-run: links already
# pointing here are left alone, and anything else in the way is moved aside to
# *.bak-<timestamp>.
#
#   ~/mac-dotfiles/scripts/link.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# link <source in config/> <target>
link() {
  local src="$DOTFILES/config/$1" target="$2"
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

# --- configs -----------------------------------------------------------------
# Whole directories are linked, not file by file, so files the apps write
# there (lazy-lock.json, karabiner.json edits from its UI...) land in the repo.

log "linking configs from $DOTFILES"
for app in nvim tmux btop fastfetch yazi ghostty karabiner shell; do
  link "$app" "$HOME/.config/$app"
done
link starship/starship.toml "$HOME/.config/starship.toml"
link aerospace/.aerospace.toml "$HOME/.aerospace.toml"
link git/.gitconfig "$HOME/.gitconfig"

# --- zsh ---------------------------------------------------------------------
# Keep ~/.zshrc as a machine-local file (installers like to append to it) and
# just hook config/shell/zsh.sh onto the end.

ZSHRC_LINE='[ -f "$HOME/.config/shell/zsh.sh" ] && source "$HOME/.config/shell/zsh.sh"'
touch "$HOME/.zshrc"
if grep -qxF "$ZSHRC_LINE" "$HOME/.zshrc"; then
  log "zsh: ~/.zshrc already sources config/shell/zsh.sh"
else
  log "zsh: hooking config/shell/zsh.sh into ~/.zshrc"
  printf '\n# dotfiles\n%s\n' "$ZSHRC_LINE" >>"$HOME/.zshrc"
fi

# --- yazi --------------------------------------------------------------------
# package.toml pins the flavor theme.toml uses; flavors/ itself is gitignored.

if command -v ya >/dev/null; then
  log "yazi: installing flavors/plugins from package.toml"
  ya pkg install >/dev/null || warn "ya pkg install failed — run it by hand"
fi

# --- tmux plugins (tpm) ------------------------------------------------------

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR/.git" ]; then
  log "tpm: cloning to $TPM_DIR"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# install_plugins reads the @plugin list from a running tmux server: reuse one
# if it's up, otherwise start a throwaway one and stop it afterwards.
if command -v tmux >/dev/null; then
  log "tpm: installing plugins"
  STARTED_TMUX=0
  if ! tmux has-session 2>/dev/null; then
    tmux new-session -d -s tpm-install && STARTED_TMUX=1
  fi
  tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
  "$TPM_DIR/bin/install_plugins" >/dev/null ||
    warn "tpm plugin install failed — press prefix + I inside tmux to retry"
  [ "$STARTED_TMUX" -eq 1 ] && tmux kill-session -t tpm-install 2>/dev/null || true
fi

# --- git ---------------------------------------------------------------------
# config/git/.gitconfig signs every commit with a GPG key, which a freshly
# reset Mac won't have: `git commit` fails until it's imported.

SIGNING_KEY="$(git config --global user.signingkey || true)"
if [ -n "$SIGNING_KEY" ] && ! gpg --list-secret-keys "$SIGNING_KEY" >/dev/null 2>&1; then
  warn "git signs commits with GPG key $SIGNING_KEY, which isn't in this machine's keyring —"
  warn "brew install gnupg pinentry-mac, then gpg --import it, or commits will fail"
fi

log "done. Open a new shell (or 'exec zsh') to pick up the new config."
