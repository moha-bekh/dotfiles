{ config, pkgs, ... }:

{
  home.username = "moha";
  home.homeDirectory = "/home/moha";
  programs.git.enable = true;
  home.stateVersion = "26.05";
  programs.bash = {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
    };
  };
  home.file.".config/oxwm".source = ../config/oxwm;
  home.file.".config/nvim".source = ../config/nvim;
  home.packages = with pkgs; [
    neovim
    ripgrep
    nil
    nixpkgs-fmt
    nodejs
    gcc
  ];
}
