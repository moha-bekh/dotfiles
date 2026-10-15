# dotfiles

Same config on every machine: `config/` is shared, only the install differs
per OS (`scripts/<os>/`). macOS and Arch for now, NixOS to come.

```sh
git clone <this repo> ~/dotfiles
~/dotfiles/install.sh
```

| script                       | does                                                                 |
| ---------------------------- | -------------------------------------------------------------------- |
| `install.sh`                 | detects the OS, runs its `packages.sh`, then `link.sh` (and `settings.sh` on macOS) |
| `scripts/link.sh`            | symlinks `config/*` into `~/.config` and `~`, hooks zsh, yazi, tpm, sets the wallpaper |
| `scripts/macos/packages.sh`  | installs Homebrew if missing, then the formulae and casks it lists   |
| `scripts/macos/settings.sh`  | applies macOS settings with `defaults write` (Dock...)               |
| `scripts/arch/packages.sh`   | installs the same packages with pacman, makes zsh the login shell    |
| `scripts/lib.sh`             | shared helpers (`log`, `warn`, OS detection)                         |

All are safe to re-run. Anything a symlink would replace is moved to
`*.bak-<timestamp>`.

## What goes where

| config/               | linked to                  |
| --------------------- | -------------------------- |
| `nvim/`               | `~/.config/nvim`           |
| `tmux/`               | `~/.config/tmux`           |
| `btop/`               | `~/.config/btop`           |
| `fastfetch/`          | `~/.config/fastfetch`      |
| `yazi/`               | `~/.config/yazi`           |
| `ghostty/`            | `~/.config/ghostty`        |
| `karabiner/`          | `~/.config/karabiner` (macOS) |
| `shell/`              | `~/.config/shell` (sourced from `~/.zshrc`) |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `aerospace/.aerospace.toml` | `~/.aerospace.toml` (macOS) |
| `git/.gitconfig`      | `~/.gitconfig`             |

To add a package, add it to every `scripts/<os>/packages.sh` (`FORMULAE`/`CASKS`
on macOS, `PACKAGES` on Arch).
To add a macOS setting, add a `defaults write` line in `scripts/macos/settings.sh`.
To add a config, drop it in `config/` and add a `link` line in `scripts/link.sh`.
