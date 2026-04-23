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

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
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
      disko,
      sops-nix,
      lanzaboote,
      pre-commit-hooks,
      treefmt-nix,
      ...
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      inherit (nixpkgs) lib;

      hostRegistry = import ./lib/hosts.nix;

      homeManagerRoleModules = {
        desktop = ./home/users/user/home.nix;
        server = ./home/users/user/server.nix;
      };

      homeManagerProfileModules = {
        desktop = ./home/profiles/desktop.nix;
        workstation = ./home/profiles/workstation.nix;
      };

      mkHomeManagerImports =
        hostMeta:
        let
          hm = hostMeta.homeManager;
        in
        [ homeManagerRoleModules.${hm.role} ]
        ++ map (profile: homeManagerProfileModules.${profile}) (hm.profiles or [ ]);

      invariants = import ./lib/invariants.nix { inherit lib pkgs; };

      aclGen = import ./lib/acl.nix { inherit lib; };

      cveChecks = import ./lib/cve-checks.nix { inherit pkgs; };

      # VMs only — for the VM management script
      vmRegistry = lib.filterAttrs (_: cfg: cfg ? sshPort && cfg ? diskSize) hostRegistry;

      mkNixos =
        host: hmArgs:
        let
          hostMeta = hostRegistry.${host};
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs self hostMeta;
          };
          modules = [
            ./hosts/${host}/default.nix
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            lanzaboote.nixosModules.lanzaboote
            disko.nixosModules.disko
            {
              imports = [ ./modules/nixos ];
            }
            (lib.mkIf (hostMeta ? homeManager) {
              home-manager.users.user.imports = mkHomeManagerImports hostMeta;
            })
            {
              home-manager.extraSpecialArgs = {
                skipHeavyPackages = false;
              }
              // hmArgs;
            }
          ];
        };

      # ── Host-derived infrastructure ──────────────────────────────────────
      allNixosConfigs = lib.mapAttrs (name: _: mkNixos name { }) hostRegistry;

      deployableHosts = lib.filterAttrs (_: cfg: cfg ? deploy) hostRegistry;

      allDeployNodes = lib.mapAttrs (name: cfg: {
        hostname = name;
        inherit (cfg.deploy) sshUser;
        magicRollback = true;
        autoRollback = true;
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        };
      }) deployableHosts;

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

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      preCommitCheck = import ./pre-commit-hooks.nix {
        inherit
          pkgs
          pre-commit-hooks
          system
          treefmtEval
          ;
      };

      # ── Configuration Invariant Checks ──────────────────────────────────
      invariantChecks =
        let
          sshFail2banHardened = {
            name = "SSH hosts enforce hardened fail2ban";
            check =
              cfg:
              (!cfg.services.openssh.enable)
              || (
                cfg.services.fail2ban.enable
                && cfg.services.fail2ban.maxretry <= 3
                && cfg.services.fail2ban.bantime == "30m"
                && cfg.services.fail2ban."bantime-increment".enable
                && cfg.services.fail2ban."bantime-increment".maxtime != null
              );
          };
        in
        {
          invariants-main = invariants.mkInvariantCheck "main" [
            {
              name = "has stateVersion";
              check = cfg: cfg.system.stateVersion != null;
            }
            {
              name = "no passwordless sudo";
              check = cfg: cfg.security.sudo.wheelNeedsPassword;
            }
            {
              name = "initrd secrets point to sops-managed paths";
              check =
                cfg:
                let
                  values = lib.attrValues cfg.boot.initrd.secrets;
                  nonNull = lib.filter (v: v != null) values;
                in
                lib.all (lib.hasPrefix "/run/secrets/") nonNull;
            }
            sshFail2banHardened
          ] allNixosConfigs.main.config;

          invariants-vm = invariants.mkInvariantCheck "vm" [
            {
              name = "has stateVersion";
              check = cfg: cfg.system.stateVersion != null;
            }
            {
              name = "passwordless sudo enabled";
              check = cfg: !cfg.security.sudo.wheelNeedsPassword;
            }
            sshFail2banHardened
          ] allNixosConfigs.vm.config;

          invariants-homeserver-vm = invariants.mkInvariantCheck "homeserver-vm" [
            {
              name = "has stateVersion";
              check = cfg: cfg.system.stateVersion != null;
            }
            {
              name = "passwordless sudo enabled";
              check = cfg: !cfg.security.sudo.wheelNeedsPassword;
            }
            {
              name = "firewall enabled";
              check = cfg: cfg.networking.firewall.enable;
            }
            sshFail2banHardened
          ] allNixosConfigs.homeserver-vm.config;

          invariants-homeserver = invariants.mkInvariantCheck "homeserver" [
            {
              name = "has stateVersion";
              check = cfg: cfg.system.stateVersion != null;
            }
            {
              name = "firewall enabled";
              check = cfg: cfg.networking.firewall.enable;
            }
            {
              name = "sops uses SSH host key for decryption";
              check = cfg: cfg.sops.age.sshKeyPaths != [ ];
            }
            sshFail2banHardened
          ] allNixosConfigs.homeserver.config;

          # Fail-loud: pre-baked host key files must be present so reinstall-homeserver can inject
          # a stable age identity from first boot. Without them, sops secrets won't decrypt on boot.
          homeserver-sops-bootstrap =
            let
              secretsDir = ./hosts/homeserver/secrets;
              hasKey = builtins.pathExists (secretsDir + "/ssh_host_ed25519_key.enc");
              hasPub = builtins.pathExists (secretsDir + "/ssh_host_ed25519_key.pub.enc");
            in
            if hasKey && hasPub then
              pkgs.runCommand "homeserver-sops-bootstrap-check" { } "touch $out"
            else
              pkgs.runCommand "homeserver-sops-bootstrap-check" { } ''
                echo "homeserver sops bootstrap incomplete — missing pre-baked host key files:"
                ${lib.optionalString (!hasKey) ''echo "  hosts/homeserver/secrets/ssh_host_ed25519_key.enc"''}
                ${lib.optionalString (!hasPub) ''echo "  hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc"''}
                echo ""
                echo "Generate and commit them:"
                echo "  ssh-keygen -t ed25519 -f /tmp/homeserver_host_key -N \"\""
                echo "  sops encrypt --filename-override hosts/homeserver/secrets/ssh_host_ed25519_key.enc \\"
                echo "    --input-type binary --output-type binary \\"
                echo "    --output hosts/homeserver/secrets/ssh_host_ed25519_key.enc /tmp/homeserver_host_key"
                echo "  sops encrypt --filename-override hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc \\"
                echo "    --input-type binary --output-type binary \\"
                echo "    --output hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc /tmp/homeserver_host_key.pub"
                echo "  sops updatekeys hosts/homeserver/secrets/secrets.yaml"
                exit 1
              '';
        };

      # Generate CVE checks for all hosts, but skip test VMs in CI
      cveCheckMap =
        let
          isCi = builtins.getEnv "CI" != "";
          hostsToCheck =
            if isCi then
              lib.filterAttrs (name: _: name != "vm" && name != "homeserver-vm") allNixosConfigs
            else
              allNixosConfigs;
        in
        lib.mapAttrs (
          hostName: config: cveChecks.mkCveCheck hostName config.config.system.build.toplevel
        ) hostsToCheck;
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
        tailscale-acl =
          pkgs.runCommand "tailscale-acl"
            {
              aclJson = builtins.toJSON (aclGen.mkAcl hostRegistry);
              passAsFile = [ "aclJson" ];
            }
            ''
              cp "$aclJsonPath" "$out"
            '';

        installer-iso =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [ ./hosts/installer/default.nix ];
          }).config.system.build.isoImage;
      };

      # ── Formatter ───────────────────────────────────────────────────────────
      formatter.${system} = treefmtEval.config.build.wrapper;

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
              vulnix
              direnv
            ])
            ++ [
              deploy-rs.packages.${system}.deploy-rs
              nixos-anywhere.packages.${system}.nixos-anywhere
            ]
            ++ preCommitCheck.enabledPackages;
          shellHook = ''
            ${preCommitCheck.shellHook}
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
      nixosConfigurations = allNixosConfigs // {
        main-ci = mkNixos "main" { skipHeavyPackages = true; };
      };

      # ── Deploy-RS ───────────────────────────────────────────────────────────
      deploy.nodes = allDeployNodes;

      checks.${system} =
        deploy-rs.lib.${system}.deployChecks self.deploy
        // invariantChecks
        // cveCheckMap
        // {
          vm-smoke = import ./tests/nixos/vm-smoke.nix {
            inherit nixpkgs system inputs;
          };
          homeserver-vm-smoke = import ./tests/nixos/homeserver-vm-smoke.nix {
            inherit nixpkgs system inputs;
          };
          profile-security = import ./tests/nixos/profile-security.nix {
            inherit nixpkgs system;
          };
          profile-observability = import ./tests/nixos/profile-observability.nix {
            inherit nixpkgs system;
          };
          profile-hardening = import ./tests/nixos/profile-hardening.nix {
            inherit nixpkgs system;
          };
          lib-generators = import ./tests/lib/generators.nix {
            inherit nixpkgs system;
          };
          lib-generators-golden = import ./tests/lib/generators.golden.nix {
            inherit nixpkgs system;
          };
          lib-acl = import ./tests/lib/acl.nix {
            inherit nixpkgs system;
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
        "user@wsl" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./home/users/user/wsl.nix
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
        profiles-workstation = import ./home/profiles/workstation.nix;
      };
    };
}
