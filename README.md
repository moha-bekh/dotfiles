# mac-dotfiles

macOS dotfiles, no Nix: Homebrew for the packages, symlinks for the configs.

```sh
git clone <this repo> ~/mac-dotfiles
~/mac-dotfiles/install.sh
```

| script               | does                                                                 |
| -------------------- | -------------------------------------------------------------------- |
| `install.sh`         | runs both scripts below                                              |
| `scripts/packages.sh`| installs Homebrew if missing, then the formulae and casks it lists   |
| `scripts/link.sh`    | symlinks `config/*` into `~/.config` and `~`, hooks zsh, yazi, tpm   |

Both are safe to re-run. Anything a symlink would replace is moved to
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
| `karabiner/`          | `~/.config/karabiner`      |
| `shell/`              | `~/.config/shell` (sourced from `~/.zshrc`) |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `aerospace/.aerospace.toml` | `~/.aerospace.toml`  |
| `git/.gitconfig`      | `~/.gitconfig`             |

To add a package, add it to `FORMULAE` or `CASKS` in `scripts/packages.sh`.
To add a config, drop it in `config/` and add a `link` line in `scripts/link.sh`.
