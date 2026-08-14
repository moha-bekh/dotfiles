{
  description = "Multi-OS dotfiles for moha-bekh (NixOS, macOS, Arch)";

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

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }: {
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
            backupFileExtension = "backup";
          };
        }
      ];
    };

    # Standalone home-manager for non-NixOS Linux (e.g. Arch).
    # No system-level module needed: home-manager works on any Linux
    # distro as long as `nix` itself is installed.
    homeConfigurations."moha@arch-btw" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home/home.nix ];
    };
  };
}
