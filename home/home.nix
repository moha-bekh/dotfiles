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
    "starship.toml" = "starship/starship.toml";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    oxwm = "oxwm";
    picom = "picom";
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

  # Nix's Mesa is built expecting NixOS's /run/opengl-driver symlink (set up
  # by hardware.graphics) to find its DRI drivers — that path doesn't exist
  # on Arch, so GLX/EGL apps (e.g. ghostty) fail with "Unable to acquire an
  # OpenGL context". LIBGL_DRIVERS_PATH alone isn't enough: ghostty links
  # against libglvnd (the vendor-neutral GL/EGL dispatch library), which
  # never even reaches Mesa's DRI loader unless it can first (a) find
  # Mesa's EGL vendor JSON — glvnd only looks in /usr|/etc/share/glvnd by
  # default, neither of which exists on Arch — and (b) dlopen
  # libGLX_mesa.so.0/libEGL_mesa.so.0 by soname for GLX, which requires
  # Mesa's lib/ dir on the loader search path since those aren't referenced
  # by any binary's RPATH.
  home.sessionVariables = lib.optionalAttrs isNonNixOSLinux {
    LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
    __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
    LD_LIBRARY_PATH = "${pkgs.mesa}/lib";
  };

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
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
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
    picom # compositor — required for transparency/blur, autostarted in config/oxwm/config.lua
    feh # wallpaper — see the commented autostart in config/oxwm/config.lua
    maim # screenshot — bound to Mod+S in config/oxwm/config.lua
    xclip # clipboard target for the maim screenshot bind above
  ] ++ lib.optionals isNonNixOSLinux [
    xorg-server
    xinit # provides `startx`
    xf86-input-libinput # keyboard/mouse driver — see .xserverrc below
    firefox # nixos-btw gets this via programs.firefox.enable (system module);
            # arch-btw has no system module, so it needs the package directly
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    karabiner-elements
    aerospace
  ];
}
