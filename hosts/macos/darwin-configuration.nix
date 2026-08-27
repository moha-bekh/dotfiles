{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.enable = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Required by nix-darwin for user-scoped defaults/homebrew (M1 2020, single user).
  system.primaryUser = "moha";

  users.users.moha.home = "/Users/moha";

  # zsh is macOS's default shell; this lets nix-darwin manage /etc/zshrc
  # so packages from the nix store resolve in new shells.
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    git
  ];

  # ghostty has no aarch64-darwin build in nixpkgs (Linux-only there) — its
  # macOS build is a native .app, only distributed via upstream's installer
  # or this Homebrew cask. Requires Homebrew itself pre-installed manually
  # (nix-darwin manages the cask, not the `brew` binary):
  #   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  homebrew = {
    enable = true;
    casks = [ "ghostty" ];
  };

  # Bump only after reading the release notes, same rule as NixOS stateVersion.
  system.stateVersion = 6;
}
