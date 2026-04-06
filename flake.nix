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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, deploy-rs, nixos-anywhere, nixos-generators, ... }:
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
      packages.${system} = {
        installer-iso = nixos-generators.nixosGenerate {
          inherit system;
          format = "iso";
          modules = [ ./hosts/installer/default.nix ];
          specialArgs = { inherit inputs; };
        };
      };

      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = (with pkgs; [ nixd statix deadnix ])
          ++ [
            deploy-rs.packages.${system}.deploy-rs
            nixos-anywhere.packages.${system}.nixos-anywhere
          ];
      };

      nixosConfigurations = {
        main = mkNixos "main";
        vm   = mkNixos "vm";
      };

      # ── deploy-rs ──────────────────────────────────────────────────────────────
      deploy.nodes.vm = {
        hostname      = "nixvm";     # uses ~/.ssh/config alias → localhost:2222
        sshUser       = "user";      # SSH as user, sudo to root for activation
        magicRollback = false;       # VM is local; rollback machinery not needed
        autoRollback  = false;
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
