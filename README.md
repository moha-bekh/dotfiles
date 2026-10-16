# dotfiles

Same config on every machine: `config/` is shared, only the install differs
per OS (`scripts/<os>/`). macOS, Arch and NixOS — each OS has its own
packages and automation; home-manager/Nix is only used on NixOS, for
personal packages, never for cross-OS tooling.

```sh
git clone <this repo> ~/dotfiles
~/dotfiles/install.sh
```

| script                       | does                                                                 |
| ---------------------------- | -------------------------------------------------------------------- |
| `install.sh`                 | detects the OS, runs its `packages.sh`, then `link.sh` (and `settings.sh` on macOS) |
| `scripts/link.sh`            | symlinks `config/*` into `~/.config` and `~`, hooks zsh/bash, yazi, tpm, sets the wallpaper |
| `scripts/macos/packages.sh`  | installs Homebrew if missing, then the formulae and casks it lists   |
| `scripts/macos/settings.sh`  | applies macOS settings with `defaults write` (Dock...)               |
| `scripts/arch/packages.sh`   | installs the same packages with pacman, makes zsh the login shell    |
| `scripts/nixos/packages.sh`  | installs the personal package list below via standalone home-manager |
| `scripts/lib.sh`             | shared helpers (`log`, `warn`, OS detection)                         |

All are safe to re-run. Anything a symlink would replace is moved to
`*.bak-<timestamp>`.

### NixOS

`flake.nix` + `scripts/nixos/home.nix` only manage **personal packages** —
the same role `scripts/arch/packages.sh`/`scripts/macos/packages.sh` play on
the other OSes, via standalone home-manager (no system module, no
`nixosConfigurations`). System config, the window manager (niri) and
DankMaterialShell live in `/etc/nixos/configuration.nix`, outside this repo
and untouched by it. `scripts/link.sh` still does the actual symlinking of
`config/*`, exactly as on Arch/macOS — home-manager is never used for that.

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
on macOS, `PACKAGES` on Arch, `home.packages` in `scripts/nixos/home.nix`).
To add a macOS setting, add a `defaults write` line in `scripts/macos/settings.sh`.
To add a config, drop it in `config/` and add a `link` line in `scripts/link.sh`.
