# Shared user-level config for every host.
#
# `gui` is passed in from flake.nix via extraSpecialArgs and says whether this
# machine has a display attached. It defaults to true so the desktop hosts
# (nixos-btw, macos) don't have to opt in. Headless boxes — a cloud/OrbStack
# Ubuntu VM, a build server — set it to false, which strips Xorg, oxwm,
# ghostty, firefox and the Mesa LD_LIBRARY_PATH workaround: on a machine with
# no display those are several hundred MB of downloads that can never be used,
# and the LD_LIBRARY_PATH one actively risks shadowing system libraries for
# every process in the login session.
{ config, pkgs, lib, gui ? true, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  # Arch/Ubuntu (or any non-NixOS Linux): needs its own Xorg + startx from Nix,
  # since there's no services.xserver like on nixos-btw. /etc/NIXOS is the
  # standard marker file for detecting a real NixOS system.
  isNonNixOSLinux = pkgs.stdenv.isLinux && !(builtins.pathExists "/etc/NIXOS");
  linuxGui = gui && pkgs.stdenv.isLinux;
  nonNixOSGui = gui && isNonNixOSLinux;
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

  # Any display manager already handling logins on this machine. `startx` from
  # a tty would fight with it for the display, so the autostart hack below is
  # skipped when one is present. ly (Arch, via pacman) keeps its config at
  # /etc/ly/config.ini; on any systemd distro an *enabled* display manager —
  # gdm3 on Ubuntu Desktop, sddm, lightdm — is aliased to
  # /etc/systemd/system/display-manager.service, which covers the rest.
  hasDisplayManager =
    builtins.pathExists "/etc/ly/config.ini"
    || builtins.pathExists "/etc/systemd/system/display-manager.service";

  # Auto-launch the GUI on login, on non-NixOS Linux (Arch/Ubuntu Server have
  # no display manager wired up like nixos-btw's ly) that hasn't set one up
  # itself — a system-level service, outside this repo's scope. Only on the
  # first virtual console, so a second/SSH login doesn't steal the display.
  autostartX = lib.optionalString (nonNixOSGui && !hasDisplayManager) ''
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
  # on Arch/Ubuntu, so GLX/EGL apps (e.g. ghostty) fail with "Unable to
  # acquire an OpenGL context". LIBGL_DRIVERS_PATH alone isn't enough:
  # ghostty links against libglvnd (the vendor-neutral GL/EGL dispatch
  # library), which never even reaches Mesa's DRI loader unless it can first
  # (a) find Mesa's EGL vendor JSON — glvnd only looks in
  # /usr|/etc/share/glvnd by default, neither of which exists there — and
  # (b) dlopen libGLX_mesa.so.0/libEGL_mesa.so.0 by soname for GLX, which
  # requires Mesa's lib/ dir on the loader search path since those aren't
  # referenced by any binary's RPATH.
  #
  # Gated on `gui`: LD_LIBRARY_PATH is inherited by every process in the login
  # session, so pointing it at the Nix store is a real risk to distro binaries
  # (they can pick up Nix's glibc/libstdc++ instead of their own). Worth it to
  # get a GPU-accelerated terminal on a desktop; never worth it headless.
  home.sessionVariables = lib.optionalAttrs nonNixOSGui {
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

  # Build the fontconfig cache for Nix-installed fonts. NixOS gets this from
  # fonts.packages in its system module and macOS from nix-darwin, so this is
  # only for the distros where nothing else manages fonts.
  fonts.fontconfig.enable = nonNixOSGui;

  xdg.configFile = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) configs;

  home.file = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) homeFiles // lib.optionalAttrs linuxGui {
    # Lets `startx` launch oxwm on non-NixOS Linux (e.g. Arch, Ubuntu Desktop),
    # where there's no display manager wired up via services.xserver like on
    # nixos-btw. Logs to ~/.oxwm.log (plain startx has no ~/.xsession-errors of
    # its own) so a hang/crash can be diagnosed after the fact, without needing
    # a live, responsive session.
    ".xinitrc".text = ''
      exec ${pkgs.oxwm}/bin/oxwm > "$HOME/.oxwm.log" 2>&1
    '';
  } // lib.optionalAttrs nonNixOSGui {
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

  # Language servers come from Nix on every host rather than from nvim's
  # mason.nvim, and config/nvim/lua/plugins/lsp.lua sets `mason = false` for
  # each of them so LazyVim uses these instead of downloading its own. Two
  # reasons: mason has no aarch64-linux build of clangd at all (it fails with
  # "The current platform is unsupported"), and its prebuilt binaries don't run
  # on NixOS in the first place — they're linked against /lib64/ld-linux, which
  # NixOS doesn't have. Nix builds all of them for every host, so the LSP setup
  # is identical on nixos-btw, macos, arch-btw and both Ubuntu architectures.
  home.packages = with pkgs; [
    neovim
    ripgrep
    nil # nix — LazyVim's lang.nix extra calls this one nil_ls
    nixpkgs-fmt
    nodejs
    gcc
    gnumake
    clang-tools # C/C++ — provides clangd, which the lang.clangd extra runs off PATH
    go
    gopls # go
    zig
    zls # zig
    vtsls # typescript/javascript — the server LazyVim's lang.typescript extra
          # defaults to (vim.g.lazyvim_ts_lsp), not tsserver/ts_ls
    rustc
    cargo
    rust-analyzer # rust — driven by rustaceanvim, which looks for it on PATH;
                  # the lang.rust extra deliberately leaves nvim-lspconfig's
                  # rust_analyzer disabled, so this is the one that matters
    starship
    fzf
    eza
    fastfetch
    btop
    zoxide
    fd
    tealdeer
    bat
    delta # config/git/.gitconfig sets interactive.diffFilter = delta, so
          # `git add -p` errors out without it on the record
    unzip # LazyVim's mason.nvim unpacks LSP server archives with it
    claude-code
    go-task
    tmuxifier
    yazi
    git-lfs
    granted
  ] ++ lib.optionals linuxGui [
    gparted
    rofi
    oxwm
    ghostty
    picom # compositor — required for transparency/blur, autostarted in config/oxwm/config.lua
    feh # wallpaper — see the commented autostart in config/oxwm/config.lua
    maim # screenshot — bound to Mod+S in config/oxwm/config.lua
    xclip # clipboard target for the maim screenshot bind above
  ] ++ lib.optionals nonNixOSGui [
    xorg-server
    xinit # provides `startx`
    xf86-input-libinput # keyboard/mouse driver — see .xserverrc below
    firefox # nixos-btw gets this via programs.firefox.enable (system module);
            # arch-btw/ubuntu-btw have no system module, so they need the package directly
    nerd-fonts.jetbrains-mono # nixos-btw gets this via fonts.packages instead
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    firefox
    aerospace
    docker-client # CLI only — macOS has no Linux kernel for dockerd itself,
                   # see colima below for the daemon this talks to
    colima # lightweight Linux VM providing the docker daemon on macOS,
           # `colima start` once per boot; NixOS/Arch get a real dockerd
           # via virtualisation.docker (system module) / pacman instead
  ];
}
