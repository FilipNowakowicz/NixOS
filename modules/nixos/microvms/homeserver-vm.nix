{
  self,
  config,
  lib,
  pkgs,
  ...
}:
{
  options.microvms.homeserver-vm.externalInterface = lib.mkOption {
    type = lib.types.str;
    description = "Host network interface used for NAT masquerading (VM internet access).";
    example = "wlp0s20f3";
  };

  config = {
  # ── microvm VM declaration ─────────────────────────────────────────────────
  microvm.vms.homeserver-vm = {
    flake = self;
    autostart = true;
  };

  # ── Bridge networking (host-only, managed by systemd-networkd) ────────────
  # NetworkManager manages WiFi; systemd-networkd manages the microvm bridge.
  # The two coexist by telling NM to ignore bridge and tap interfaces.
  networking.networkmanager.unmanaged = [
    "microvm-br0"
    "interface-name:vm-*"
  ];

  systemd.network = {
    enable = true;
    netdevs."10-microvm-br0" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "microvm-br0";
      };
    };
    networks = {
      "10-microvm-br0" = {
        matchConfig.Name = "microvm-br0";
        networkConfig = {
          Address = "10.0.100.1/24";
          IPv4Forwarding = "yes";
        };
      };
      "20-vm-homeserver" = {
        matchConfig.Name = "vm-homeserver";
        networkConfig.Bridge = "microvm-br0";
      };
    };
  };

  # ── NAT masquerading (VM internet access through main's WiFi) ─────────────
  # Verify interface name with: ip link show | grep -E '^[0-9]+: w'
  networking.nat = {
    enable = true;
    internalInterfaces = [ "microvm-br0" ];
    externalInterface = config.microvms.homeserver-vm.externalInterface;
  };

  # ── Age key virtiofs share setup ───────────────────────────────────────────
  # Copies the sops-decrypted age key into the virtiofs source directory
  # before the VM starts. The VM reads it at /run/age-keys/homeserver-vm.txt.
  systemd.services.prepare-homeserver-vm-age-key = {
    description = "Prepare homeserver-vm age key for virtiofs share";
    wantedBy = [ "microvm@homeserver-vm.service" ];
    before = [ "microvm@homeserver-vm.service" ];
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "prepare-age-key" ''
        install -d -m 700 /run/microvms/homeserver-vm/age-keys
        install -m 600 \
          ${config.sops.secrets.homeserver_vm_age_key.path} \
          /run/microvms/homeserver-vm/age-keys/homeserver-vm.txt
      '';
    };
  };

  # ── Sops secret (main holds the VM's age private key) ─────────────────────
  sops.secrets.homeserver_vm_age_key = { };
  }; # config
}
