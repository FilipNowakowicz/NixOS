{
  description = "NixOS and Home Manager configurations for user";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8ZsS6UqK+KP5gdiQNRrt65TUI="
    ];
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";

      mkPkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkNixos = host:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/${host}.nix ];
        };
    in {
      formatter.${system} = mkPkgs.nixfmt-rfc-style;

      devShells.${system}.default = mkPkgs.mkShell {
        packages = with mkPkgs; [ nixd nil deploy-rs ];
      };

      nixosConfigurations = {
        main = mkNixos "main";
      };

      homeConfigurations = {
        "user-arch" = home-manager.lib.homeManagerConfiguration {
          inherit system;
          pkgs = mkPkgs;
          modules = [
            ./home/default.nix
            ./home/desktop.nix
          ];
        };
      };
    };
}
