{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configs = {
    nvim = "nvim";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    oxwm = "oxwm";
  };
in

{
  home.username = "moha";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/moha" else "/home/moha";
  home.stateVersion = "26.05";

  programs.git.enable = true;
  programs.bash = {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
    };
  };

  xdg.configFile = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) configs;

  home.packages = with pkgs; [
    neovim
    ripgrep
    nil
    nixpkgs-fmt
    nodejs
    gcc
    starship
    fzf
    eza
    fastfetch
    btop
    zoxide
    fd
    tealdeer
    bat
    claude-code
    tmux
    wget
    tree
    firefox
    nerd-fonts.jetbrains-mono
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    gparted
    rofi
    oxwm
    ghostty
  ];
}
