{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
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

  # Bump only after reading the release notes, same rule as NixOS stateVersion.
  system.stateVersion = 6;
}
