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

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      deploy-rs,
      nixos-anywhere,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      inherit (nixpkgs) lib;

      vmRegistry = import ./lib/vm.nix;

      mkNixos =
        host:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/${host}/default.nix
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
          ];
        };

      # ── VM-derived infrastructure ────────────────────────────────────────
      vmDeployNodes = lib.mapAttrs (name: _: {
        hostname = name;
        sshUser = "user";
        magicRollback = false;
        autoRollback = false;
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        };
      }) vmRegistry;

      vmNixosConfigs = lib.mapAttrs (name: _: mkNixos name) vmRegistry;

      # VM management script — unified entry point
      vmApp = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "vm" ''
            export VM_REGISTRY='${builtins.toJSON vmRegistry}'
            export OVMF_CODE="${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
            export OVMF_SOURCE="${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"
            export QEMU_BIN="${pkgs.qemu}/bin/qemu-system-x86_64"
            export QEMU_IMG_BIN="${pkgs.qemu}/bin/qemu-img"
            export JQ_BIN="${pkgs.jq}/bin/jq"
            export SSH_KEYGEN_BIN="${pkgs.openssh}/bin/ssh-keygen"
            export NIXOS_ANYWHERE_BIN="${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere"
            export SOPS_BIN="${pkgs.sops}/bin/sops"
            export SSH_TO_AGE_BIN="${pkgs.ssh-to-age}/bin/ssh-to-age"
            exec ${pkgs.bash}/bin/bash ${./scripts/vm.sh} "$@"
          ''
        );
        meta.description = "Manage QEMU/KVM virtual machines";
      };
    in
    {
      # ── Apps ────────────────────────────────────────────────────────────────
      apps.${system} = {
        vm = vmApp;
        reinstall-homeserver = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "reinstall-homeserver" ''
              export SOPS_BIN="${pkgs.sops}/bin/sops"
              export NIXOS_ANYWHERE_BIN="${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere"
              exec ${pkgs.bash}/bin/bash ${./scripts/reinstall-homeserver.sh} "$@"
            ''
          );
          meta.description = "Reinstall NixOS on the homeserver via nixos-anywhere";
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
          packages =
            (with pkgs; [
              nixd
              statix
              deadnix
              sops
              ssh-to-age
              qemu
              OVMF
            ])
            ++ [
              deploy-rs.packages.${system}.deploy-rs
              nixos-anywhere.packages.${system}.nixos-anywhere
            ];
          shellHook = ''
            # Make 'vm' command available directly in the dev shell
            alias vm="nix run '.#vm' --"
            exec ${pkgs.zsh}/bin/zsh
          '';
        };

        security = pkgs.mkShell {
          packages = with pkgs; [
            nmap
            whois
            dnsutils
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
      nixosConfigurations = vmNixosConfigs // {
        main = mkNixos "main";
        homeserver = mkNixos "homeserver";
      };

      # ── Deploy-RS ───────────────────────────────────────────────────────────
      deploy.nodes = vmDeployNodes // {
        homeserver = {
          hostname = "homeserver";
          sshUser = "user";
          magicRollback = false;
          autoRollback = false;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.homeserver;
          };
        };
      };

      checks.${system} = deploy-rs.lib.${system}.deployChecks self.deploy // {
        homeserver-vm-smoke = import ./tests/nixos/homeserver-vm-smoke.nix {
          inherit nixpkgs system inputs;
        };
      };

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
        profiles-base = import ./modules/nixos/profiles/base.nix;
        profiles-desktop = import ./modules/nixos/profiles/desktop.nix;
        profiles-observability = import ./modules/nixos/profiles/observability.nix;
        profiles-security = import ./modules/nixos/profiles/security.nix;
        profiles-vm = import ./modules/nixos/profiles/vm.nix;
      };

      homeModules = {
        profiles-base = import ./home/profiles/base.nix;
        profiles-desktop = import ./home/profiles/desktop.nix;
      };
    };
}
