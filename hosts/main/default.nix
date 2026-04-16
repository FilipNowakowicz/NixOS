{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  network = import ../../lib/network.nix;
  inherit (network) tailnetFQDN;
  # Sandbox options shared by hardware daemons that need sysfs but no network/home access.
  # PrivateDevices is intentionally omitted — both thermald and power-profiles-daemon
  # access hardware nodes under /sys which PrivateDevices would block.
  hwDaemonSandbox = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectClock = true;
    ProtectKernelLogs = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    # CapabilityBoundingSet intentionally not set — thermald and power-profiles-daemon
    # need capabilities (CAP_SYS_ADMIN/CAP_SYS_RAWIO) for hardware access.
    RestrictAddressFamilies = "AF_UNIX";
  };
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/hardware/nvidia-prime.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/observability.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
  ];

  system.stateVersion = "24.11";

  # ── Lanzaboote Secure Boot ──────────────────────────────────────────────────
  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    loader.systemd-boot.enable = lib.mkForce false;
    loader.systemd-boot.configurationLimit = 5;

    # ── Systemd in initrd ───────────────────────────────────────────────────────
    initrd.systemd.enable = true;

    # ── IOMMU Protection ────────────────────────────────────────────────────────
    # Blocks Thunderbolt/PCIe DMA attacks by enabling IOMMU isolation
    kernelParams = [
      "intel_iommu=on"
      "iommu=force"
    ];
  };

  environment.systemPackages = with pkgs; [
    sbctl
  ];

  networking = {
    hostName = "NixOS";
    networkmanager.enable = true;
  };

  hardware.bluetooth.enable = true;

  profiles.observability = {
    enable = true;
    collectors = {
      metrics = {
        enable = true;
        remoteWriteURL = "https://${tailnetFQDN}/obs/mimir/api/v1/push";
      };
      logs = {
        enable = true;
        pushURL = "https://${tailnetFQDN}/obs/loki/loki/api/v1/push";
      };
      traces = {
        enable = true;
        exportURL = "https://${tailnetFQDN}/obs/otlp";
      };
    };
    ingestAuth = {
      username = "telemetry";
      passwordFile = config.sops.secrets.observability_ingest_password.path;
    };
  };

  services = {
    blueman.enable = true;

    openssh = {
      enable = true;
      openFirewall = false; # Intentionally not exposed — accessible via Tailscale only
    };

    mullvad-vpn.enable = true;

    tailscale = {
      enable = true;
      openFirewall = true;
    };

    fwupd.enable = true; # Firmware update daemon for hardware devices

    # ── Thermal & Power Management ──────────────────────────────────────────────
    # thermald prevents CPU thermal throttling using Intel DPTF tables
    # power-profiles-daemon exposes performance/balanced/power-saver profiles
    thermald.enable = true;
    power-profiles-daemon.enable = true;

    logind.settings = {
      Login = {
        HandleLidSwitch = "suspend";
        IdleAction = "suspend";
        IdleActionSec = "15min";
      };
      # Optional: keep running on AC power
      # lidSwitchExternalPower = "ignore";
    };
  };

  systemd.services.thermald.serviceConfig = hwDaemonSandbox;
  systemd.services.power-profiles-daemon.serviceConfig = hwDaemonSandbox;

  # fwupd has almost no upstream hardening. Skip ProtectSystem/PrivateDevices (writes
  # firmware to hardware), ProtectKernelModules (loads capsule/UEFI modules), ProtectClock
  # (UEFI updates may touch EFI time), MemoryDenyWriteExecute (plugin loading), and
  # CapabilityBoundingSet (needs CAP_SYS_ADMIN and others for UEFI/hardware access).
  systemd.services.fwupd.serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    LockPersonality = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
    ];
  };

  # bluetoothd (powers blueman). Needs AF_BLUETOOTH + AF_NETLINK for HCI management and
  # CAP_NET_ADMIN/CAP_NET_RAW for BT interface control — those are left unrestricted.
  # Skip PrivateDevices (/dev/hci*), ProtectKernelModules (hci module loading).
  systemd.services.bluetooth.serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectClock = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    LockPersonality = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_BLUETOOTH"
      "AF_NETLINK"
    ];
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.user_password.neededForUsers = true;
    secrets.observability_ingest_password = { };
    secrets.restic_password = { };
  };

  # ── Backups ──────────────────────────────────────────────────────────────────
  services.restic.backups.local = {
    paths = [
      "/home/user/.ssh"
      "/home/user/.gnupg"
      "/home/user/nix"
      "/home/user/documents"
    ];
    exclude = [
      "/home/user/nix/.direnv"
      "/home/user/nix/result"
    ];
    repository = "/var/backup/restic-repo";
    passwordFile = config.sops.secrets.restic_password.path;
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 3"
    ];
  };

  users.users.user = {
    extraGroups = [ "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = (import ../../lib/pubkeys.nix);
  };

  home-manager = {
    users.user = {
      imports = [
        ../../home/users/user/home.nix
        ../../home/profiles/workstation.nix
      ];
    };
  };
}
