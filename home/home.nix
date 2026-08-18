{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  # Arch (or any non-NixOS Linux): needs its own Xorg + startx from Nix, since
  # there's no services.xserver like on nixos-btw. /etc/NIXOS is the standard
  # marker file for detecting a real NixOS system.
  isNonNixOSLinux = pkgs.stdenv.isLinux && !(builtins.pathExists "/etc/NIXOS");
  configs = {
    ghostty = "ghostty";
    nvim = "nvim";
    fastfetch = "fastfetch";
    btop = "btop";
    yazi = "yazi";
    shell = "shell";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    oxwm = "oxwm";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    karabiner = "karabiner";
  };

  # Dotfiles that belong directly in $HOME (not $XDG_CONFIG_HOME).
  # Key is the target name in $HOME, value is the path under config/.
  homeFiles = {
    ".gitconfig" = "git/.gitconfig";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    ".aerospace.toml" = "aerospace/.aerospace.toml";
  };
in

{
  imports = [ ./tmux.nix ];

  home.username = "moha";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/moha" else "/home/moha";
  home.stateVersion = "26.05";

  programs.git.enable = true;
  programs.bash = {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
    };
    initExtra = ''
      source "$HOME/.config/shell/bash.sh"
    '';
  };
  programs.zsh = {
    enable = true;
    initContent = ''
      source "$HOME/.config/shell/zsh.sh"
    '';
  };

  xdg.configFile = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) configs;

  home.file = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) homeFiles // lib.optionalAttrs pkgs.stdenv.isLinux {
    # Lets `startx` launch oxwm on non-NixOS Linux (e.g. Arch), where
    # there's no display manager wired up via services.xserver like on nixos-btw.
    ".xinitrc".text = ''
      exec ${pkgs.oxwm}/bin/oxwm
    '';
  };

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
    go-task
    tmuxifier
    yazi
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    gparted
    rofi
    oxwm
    ghostty
  ] ++ lib.optionals isNonNixOSLinux [
    xorg-server
    xinit # provides `startx`
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    karabiner-elements
    aerospace
  ];
}
