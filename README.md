# dotfiles

Same config on every machine: `config/` is shared, only the install differs
per OS (`scripts/<os>/`). macOS, Arch, NixOS and the 42 school machines — each OS has its own
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
| `scripts/arch/packages.sh`   | installs the same packages with pacman, joins the tailnet (Tailscale SSH) |
| `scripts/42/packages.sh`     | 42 school machines, no sudo: installs into `~/.local` from GitHub releases (binaries, zsh plugins, Nerd Font) |
| `scripts/nixos/packages.sh`  | installs the personal package list below via standalone home-manager |
| `scripts/lib.sh`             | shared helpers (`log`, `warn`, OS detection)                         |
| `scripts/orb.sh` | creates an OrbStack Linux machine (arch, debian/ubuntu, fedora) and sets it up with the same shell, tmux, nvim... (`scripts/orb.sh arch dev`) |

All are safe to re-run. Anything a symlink would replace is moved to
`*.bak-<timestamp>`.

### 42

Picked automatically when `/sgoinfre` exists (or the hostname ends in
`.42.school`). Nothing needs sudo: what the machine ships (git, tmux, nvim,
rg, bat, node, gcc...) is used as is, the rest comes from the latest GitHub
release into `~/.local/bin` (fd, fzf, starship, zoxide, eza, yazi, delta,
btop, fastfetch, gh, git-lfs, plus nvim in `~/.local/opt` if the system one
is older than 0.11). zsh-autosuggestions/syntax-highlighting are cloned into
`~/.local/share/zsh/plugins`, the font into `~/.local/share/fonts`. The login
shell stays bash (no `chsh`), so `config/shell/bash.sh` is what runs by
default; type `zsh` for the zsh setup. The home is only ~5G — keep big caches
on `/goinfre`.

### NixOS

`flake.nix` + `scripts/nixos/home.nix` only manage **personal packages** —
the same role `scripts/arch/packages.sh`/`scripts/macos/packages.sh` play on
the other OSes, via standalone home-manager (no system module, no
`nixosConfigurations`). System config, the window manager (niri) and
DankMaterialShell live in `/etc/nixos/configuration.nix`, outside this repo
and untouched by it. `scripts/link.sh` still does the actual symlinking of
`config/*`, exactly as on Arch/macOS — home-manager is never used for that.

`hosts/nixos/` is a copy of `/etc/nixos`. `hosts/nixos/devctl.nix` sets up
[devctl](https://github.com/moha-bekh/devctl) (NVIDIA driver, `i2c-dev`, udev
rules, the `rgb` group, its services); to apply it:

```sh
sudo cp ~/dotfiles/hosts/nixos/{configuration,devctl}.nix /etc/nixos/
sudo nixos-rebuild switch   # then log out and back in, for the rgb group
```

## What goes where

| config/               | linked to                  |
| --------------------- | -------------------------- |
| `nvim/`               | `~/.config/nvim`           |
| `tmux/`               | `~/.config/tmux`           |
| `btop/`               | `~/.config/btop`           |
| `fastfetch/`          | `~/.config/fastfetch`      |
| `yazi/`               | `~/.config/yazi`           |
| `ghostty/`            | `~/.config/ghostty`        |
| `devctl/`             | `~/.config/devctl` (Arch, NixOS) |
| `karabiner/`          | `~/.config/karabiner` (macOS) |
| `shell/`              | `~/.config/shell` (sourced from `~/.zshrc`) |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `aerospace/.aerospace.toml` | `~/.aerospace.toml` (macOS) |
| `git/.gitconfig`      | `~/.gitconfig`             |

To add a package, add it to every `scripts/<os>/packages.sh` (`FORMULAE`/`CASKS`
on macOS, `PACKAGES` on Arch, `home.packages` in `scripts/nixos/home.nix`, a
`from_release` line in `scripts/42/packages.sh`).
To add a macOS setting, add a `defaults write` line in `scripts/macos/settings.sh`.
To add a config, drop it in `config/` and add a `link` line in `scripts/link.sh`.
