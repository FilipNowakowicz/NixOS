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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, deploy-rs, nixos-anywhere, sops-nix, impermanence, ... }:
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
      apps.${system} = {
        launch-vm = {
          type = "app";
          program = toString (pkgs.writeShellScript "launch-vm" ''
            qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
              -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd \
              -drive if=pflash,format=raw,file=/vmstore/images/nixos-test-vars.fd \
              -drive file=/vmstore/images/nixos-test.qcow2,if=virtio \
              -netdev user,id=net0,hostfwd=tcp::2222-:22 \
              -device virtio-net-pci,netdev=net0 \
              -daemonize -display none
          '');
        };
        launch-vm-iso = {
          type = "app";
          program = toString (pkgs.writeShellScript "launch-vm-iso" ''
            if [ -z "$1" ]; then
              echo "Usage: nix run '.#launch-vm-iso' -- path/to/installer.iso"
              exit 1
            fi
            qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
              -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd \
              -drive if=pflash,format=raw,file=/vmstore/images/nixos-test-vars.fd \
              -drive file=/vmstore/images/nixos-test.qcow2,if=virtio \
              -cdrom "$1" \
              -boot order=d \
              -netdev user,id=net0,hostfwd=tcp::2222-:22 \
              -device virtio-net-pci,netdev=net0 \
              -daemonize -display none
          '');
        };
        reinstall-vm = {
          type = "app";
          program = toString (pkgs.writeShellScript "reinstall-vm" ''
            set -euo pipefail

            # Clear stale SSH host key for the VM
            ssh-keygen -R '[localhost]:2222'

            # Temp dir for injected host keys; cleaned up on exit
            tmpdir=$(mktemp -d)
            trap "rm -rf $tmpdir" EXIT

            mkdir -p "$tmpdir/etc/ssh"

            # Decrypt host keys from sops-encrypted secrets
            sops --decrypt hosts/vm/secrets/ssh_host_ed25519_key.enc \
              > "$tmpdir/etc/ssh/ssh_host_ed25519_key"
            sops --decrypt hosts/vm/secrets/ssh_host_ed25519_key.pub.enc \
              > "$tmpdir/etc/ssh/ssh_host_ed25519_key.pub"

            chmod 600 "$tmpdir/etc/ssh/ssh_host_ed25519_key"

            # Install — inject host keys so the age identity is stable from first boot
            nixos-anywhere \
              --flake '.#vm' \
              --extra-files "$tmpdir" \
              --no-substitute-on-destination \
              root@nixvm
          '');
        };
      };

      packages.${system} = {
        installer-iso =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [ ./hosts/installer/default.nix ];
          }).config.system.build.isoImage;
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
        main       = mkNixos "main";
        vm         = mkNixos "vm";
        homeserver = mkNixos "homeserver";
      };

      # ── deploy-rs ──────────────────────────────────────────────────────────────
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
