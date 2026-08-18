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
  # Auto-launch the GUI on login, on non-NixOS Linux (Arch has no display
  # manager wired up like nixos-btw's ly) that hasn't set up `ly` itself yet
  # (via pacman — a system-level service, outside this repo's scope). Only on
  # the first virtual console, so a second/SSH login doesn't steal the display.
  # /etc/ly/config.ini is ly's default config path, installed by its pacman package.
  autostartX = lib.optionalString (isNonNixOSLinux && !(builtins.pathExists "/etc/ly/config.ini")) ''
    if [ -z "''${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec startx
    fi
  '';
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
    profileExtra = autostartX;
  };
  programs.zsh = {
    enable = true;
    initContent = ''
      source "$HOME/.config/shell/zsh.sh"
    '';
    profileExtra = autostartX;
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
    # Logs to ~/.oxwm.log (plain startx has no ~/.xsession-errors of its own)
    # so a hang/crash can be diagnosed after the fact, without needing a live,
    # responsive session.
    ".xinitrc".text = ''
      exec ${pkgs.oxwm}/bin/oxwm > "$HOME/.oxwm.log" 2>&1
    '';
  } // lib.optionalAttrs isNonNixOSLinux {
    # Nix's xorg-server ships with NO input driver — udev enumerates the
    # keyboard/mouse fine but Xorg logs "No input driver specified, ignoring
    # this device" for every one of them, so nothing ever reaches oxwm (the
    # WM itself stays alive: only input is dead). `-modulepath` (unlike
    # `-config`/`-configdir`) has no root restriction, so it can point at the
    # Nix-built xf86-input-libinput driver — same nixpkgs revision as
    # xorg-server, so no ABI mismatch. The InputClass rule that tells Xorg to
    # actually *use* that driver still has to live in /etc/X11/xorg.conf.d
    # (a `-configdir` absolute path is root-only) — a one-time `sudo`
    # step outside this repo's scope, see README.
    ".xserverrc" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${pkgs.xorg-server}/bin/X -modulepath "${pkgs.xorg-server}/lib/xorg/modules,${pkgs.xf86-input-libinput}/lib/xorg/modules" "$@"
      '';
    };
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
    xf86-input-libinput # keyboard/mouse driver — see .xserverrc below
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    karabiner-elements
    aerospace
  ];
}
