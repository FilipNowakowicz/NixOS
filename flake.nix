{
  description = "NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, deploy-rs, ... }:
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
        packages = (with pkgs; [ nixd statix deadnix ])
          ++ [ deploy-rs.packages.${system}.deploy-rs ];
      };

      nixosConfigurations = {
        main = mkNixos "main";
        vm   = mkNixos "vm";
      };

      # ── deploy-rs ──────────────────────────────────────────────────────────────
      deploy.nodes.vm = {
        hostname = "nixvm";          # uses ~/.ssh/config alias → localhost:2222
        sshUser  = "user";           # SSH as user, sudo to root for activation
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.vm;
        };
      };

      checks.${system} = deploy-rs.lib.${system}.deployChecks self.deploy;

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
        profiles-base    = import ./modules/nixos/profiles/base.nix;
        profiles-desktop = import ./modules/nixos/profiles/desktop.nix;
        profiles-security = import ./modules/nixos/profiles/security.nix;
      };

      homeModules = {
        profiles-base    = import ./home/profiles/base.nix;
        profiles-desktop = import ./home/profiles/desktop.nix;
      };
    };
}
