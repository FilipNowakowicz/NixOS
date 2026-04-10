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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, deploy-rs, disko, nixos-anywhere, sops-nix, impermanence, lanzaboote, ... }:
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
          sops-nix.nixosModules.sops
        ];
      };
    in
    {
      # ── Apps ────────────────────────────────────────────────────────────────
      apps.${system} = {
        launch-vm = {
          type = "app";
          program = toString (pkgs.writeShellScript "launch-vm" (builtins.readFile ./scripts/launch-vm.sh));
        };
        launch-vm-iso = {
          type = "app";
          program = toString (pkgs.writeShellScript "launch-vm-iso" (builtins.readFile ./scripts/launch-vm-iso.sh));
        };
        reinstall-vm = {
          type = "app";
          program = toString (pkgs.writeShellScript "reinstall-vm" ''
            export SSH_KEYGEN_BIN="${pkgs.openssh}/bin/ssh-keygen"
            export SOPS_BIN="${pkgs.sops}/bin/sops"
            export NIXOS_ANYWHERE_BIN="${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere"
            exec ${pkgs.bash}/bin/bash ${./scripts/reinstall-vm.sh}
          '');
        };
      };

      # ── Packages ────────────────────────────────────────────────────────────
      packages.${system} = {
        installer-iso =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [ ./hosts/installer/default.nix ];
          }).config.system.build.isoImage;
      };

      # ── Formatter ───────────────────────────────────────────────────────────
      formatter.${system} = pkgs.nixfmt;

      # ── Shells ──────────────────────────────────────────────────────────────
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = (with pkgs; [ nixd statix deadnix sops ssh-to-age ])
            ++ [
              deploy-rs.packages.${system}.deploy-rs
              nixos-anywhere.packages.${system}.nixos-anywhere
            ];
          shellHook = ''
            exec ${pkgs.zsh}/bin/zsh
          '';
        };

        security = pkgs.mkShell {
          packages = with pkgs; [
            nmap
            whois
            dnsutils        # provides dig
            sqlmap
            gobuster
            ffuf
            hydra
            john
            hashcat
            netcat-gnu
            wireshark-cli
          ];
          shellHook = ''
	    echo "Security tools ready"
	    echo ""
	    echo "Available tools:"
	    echo "  Network:   nmap, whois, dig, netcat"
	    echo "  Web:       sqlmap, gobuster, ffuf"
	    echo "  Password:  hydra, john, hashcat"
	    echo "  Analysis:  wireshark-cli (tshark)"
	    exec ${pkgs.zsh}/bin/zsh
          '';
        };
      };

      # ── NixOS Configurations ────────────────────────────────────────────────
      nixosConfigurations = {
        main       = mkNixos "main";
        vm         = mkNixos "vm";
        homeserver = mkNixos "homeserver";
      };

      # ── Deploy-RS ───────────────────────────────────────────────────────────
      deploy.nodes = {
        vm = {
          hostname      = "nixvm";     # uses ~/.ssh/config alias → localhost:2222
          sshUser       = "user";
          magicRollback = false;       # VM is local; rollback machinery not needed
          autoRollback  = false;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.vm;
          };
        };
        homeserver = {
          hostname      = "homeserver";
          sshUser       = "user";
          magicRollback = false;
          autoRollback  = false;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.homeserver;
          };
        };
      };

      checks.${system} = deploy-rs.lib.${system}.deployChecks self.deploy;

      # ── Home Manager Configurations ─────────────────────────────────────────
      homeConfigurations = {
        user = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./home/users/user/home.nix
          ];
        };
      };

      # ── Modules ─────────────────────────────────────────────────────────────
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
