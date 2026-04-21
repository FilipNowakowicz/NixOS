{
  config,
  lib,
  pkgs,
  ...
}:
let
  hwDaemonSandbox = {
    # System hardening for hardware daemons (thermald, ppd). These need access
    # to /sys (writes) and dbus, but shouldn't touch user files or network.
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    ProtectClock = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    MemoryDenyWriteExecute = true;
    LockPersonality = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    SystemCallArchitectures = "native";
  };
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/hardware/nvidia-prime.nix
  ];

  # ── Hardware ────────────────────────────────────────────────────────────────
  networking.hostName = "main";

  # Lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # ── Profiles ────────────────────────────────────────────────────────────────
  profiles.observability = {
    enable = true;
    # main doesn't host logs/metrics, just collects them.
    collectors = {
      metrics.enable = true;
      logs.enable = true;
      traces.enable = true;
    };
  };

  # ── Services ────────────────────────────────────────────────────────────────
  services = {
    thermald.enable = true;
    power-profiles-daemon.enable = true;
    fwupd.enable = true;
    fprintd = {
      enable = true;
      tod = {
        enable = true;
        driver = pkgs.libfprint-2-tod1-goodix;
      };
    };
    # Bluetooth management (GUI)
    blueman.enable = true;
  };

  # Fingerprint login
  security.pam.services = {
    hyprlock.fprintAuth = true;
    greetd.fprintAuth = true;
  };

  # Backlight control (using brightnessctl)
  hardware.acpilight.enable = true;

  systemd.services = {
    thermald.serviceConfig = hwDaemonSandbox;
    power-profiles-daemon.serviceConfig = hwDaemonSandbox;
    prometheus.serviceConfig = {
      TimeoutStopSec = "20s";
      SupplementaryGroups = [ "telemetry-ingest" ];
    };
    "opentelemetry-collector".serviceConfig.SupplementaryGroups = lib.mkAfter [
      "telemetry-ingest"
    ];

    # fwupd has almost no upstream hardening. Skip ProtectSystem/PrivateDevices (writes
    # firmware to hardware), ProtectKernelModules (loads capsule/UEFI modules), ProtectClock
    # (UEFI updates may touch EFI time), MemoryDenyWriteExecute (plugin loading), and
    # CapabilityBoundingSet (needs CAP_SYS_ADMIN and others for UEFI/hardware access).
    fwupd.serviceConfig = {
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
    bluetooth.serviceConfig = {
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
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      user_password.neededForUsers = true;
      observability_ingest_password = {
        group = "telemetry-ingest";
        mode = "0440";
      };
      restic_password = { };
    };
  };

  users.groups.telemetry-ingest = { };

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
    openssh.authorizedKeys.keys = import ../../lib/pubkeys.nix;
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
