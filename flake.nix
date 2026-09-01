{
  description = "Multi-OS dotfiles for moha-bekh (NixOS, macOS, Arch, Ubuntu)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }:
    let
      lib = nixpkgs.lib;

      # Standalone home-manager builder for non-NixOS Linux.
      # No system-level module needed: home-manager works on any Linux
      # distro as long as `nix` itself is installed.
      mkHome = { system, gui }: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = { inherit gui; };
        modules = [ ./home/home.nix ];
      };

      # Standalone hosts, one entry per profile. `gui` decides whether Xorg,
      # oxwm, ghostty, firefox and fonts come along — see the comment at the
      # top of home/home.nix. Ubuntu defaults to headless because that's what
      # a VM usually is; `ubuntu-btw-gui` is the desktop variant.
      standaloneHosts = {
        "arch-btw" = { gui = true; };
        "ubuntu-btw" = { gui = false; };
        "ubuntu-btw-gui" = { gui = true; };
      };

      # A flake output name has to name its architecture: `homeConfigurations`
      # are plain attrs, and picking one by the *builder's* arch would mean
      # builtins.currentSystem, which flakes forbid in pure eval. So every host
      # above is emitted twice — `moha@<host>` for x86_64 (the historical name,
      # unchanged) and `moha@<host>-aarch64` for ARM. Taskfile.yml and
      # scripts/bootstrap-ubuntu.sh append the suffix from `uname -m`, so the
      # same command works on both.
      forBothArches = name: cfg: [
        {
          name = "moha@${name}";
          value = mkHome (cfg // { system = "x86_64-linux"; });
        }
        {
          name = "moha@${name}-aarch64";
          value = mkHome (cfg // { system = "aarch64-linux"; });
        }
      ];
    in
    {
      nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixos-btw/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.moha = import ./home/home.nix;
              extraSpecialArgs = { gui = true; };
              backupFileExtension = "backup";
            };
          }
        ];
      };

      darwinConfigurations.macos = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/macos/darwin-configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.moha = import ./home/home.nix;
              extraSpecialArgs = { gui = true; };
              backupFileExtension = "backup";
            };
          }
        ];
      };

      homeConfigurations = lib.listToAttrs (
        lib.concatLists (lib.mapAttrsToList forBothArches standaloneHosts)
      );
    };
}
