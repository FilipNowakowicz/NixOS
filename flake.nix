{
  description = "NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkNixos = host: nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/${host}/default.nix
          home-manager.nixosModules.home-manager
        ];
      };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ nixd statix deadnix ];
      };

      nixosConfigurations = {
        main = mkNixos "main";
      };

      # ADD THIS BLOCK
      homeConfigurations = {
        user = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./home/users/user/home.nix
          ];
        };
      };

      nixosModules = {
        profiles-base = import ./modules/nixos/profiles/base.nix;
        profiles-desktop = import ./modules/nixos/profiles/desktop.nix;
        profiles-security = import ./modules/nixos/profiles/security.nix;
      };

      homeModules = {
        profiles-base = import ./home/profiles/base.nix;
        profiles-desktop = import ./home/profiles/desktop.nix;
      };
    };
}
