# Personal CLI packages for NixOS, via standalone home-manager. Scope is
# deliberately narrow: the same role scripts/arch/packages.sh and
# scripts/macos/packages.sh play on the other OSes — just the tools the
# config/ dotfiles need on $PATH. System config, niri and DankMaterialShell
# live in /etc/nixos/configuration.nix, untouched by this repo.
#
# scripts/link.sh does the actual symlinking of config/ into ~/.config, same
# as on Arch/macOS — this file only makes sure the packages those configs
# need are installed.
{ pkgs, ... }:
{
  home.username = "moha";
  home.homeDirectory = "/home/moha";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git delta git-lfs gh
    tmux bc gawk # tokyo-night-tmux
    neovim
    ripgrep fd # LazyVim pickers
    nodejs # mason.nvim installs some LSPs (vtsls...) through npm
    gcc gnumake unzip # nvim-treesitter compiles parsers, mason unpacks LSPs
    wl-clipboard # system clipboard for nvim and tmux-yank on Wayland (niri)
    btop
    fastfetch
    starship
    fzf
    # yazi and its previewers (it also uses fd, rg, fzf, zoxide)
    yazi _7zz jq poppler-utils resvg
    # used by config/shell/*.sh
    zsh zoxide eza bat zsh-autosuggestions zsh-syntax-highlighting
    ghostty
    zed-editor
    nerd-fonts.jetbrains-mono # config/ghostty/config, plus the icons starship/eza/yazi/tmux draw
    noto-fonts-color-emoji
  ];

  # Builds the fontconfig cache for the fonts above — they're installed here,
  # not via the system's fonts.packages, so this is what makes them show up.
  fonts.fontconfig.enable = true;
}
