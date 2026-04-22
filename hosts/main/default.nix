{
  config,
  lib,
  pkgs,
  ...
}:
let
  network = import ../../lib/network.nix;
  inherit (network) tailnetFQDN;
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
  system.stateVersion = "24.11";

  boot = {
    # Lanzaboote (Secure Boot)
    loader.systemd-boot.enable = lib.mkForce false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # Initrd SSH (fallback LUKS unlock when TPM2 fails)
    initrd = {
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = import ../../lib/pubkeys.nix;
          hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
        };
      };
      secrets = {
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce ./initrd-ssh-host-key;
      };
    };
  };

  # ── Nix Store ───────────────────────────────────────────────────────────────
  nix = {
    gc = {
      automatic = true;
    };
    optimise = {
      automatic = true;
    };
  };

  # ── Profiles ────────────────────────────────────────────────────────────────
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
        exportURL = "https://${tailnetFQDN}/obs/otlp/v1/traces";
      };
    };
    ingestAuth = {
      username = "admin";
      passwordFile = config.sops.secrets.observability_ingest_password.path;
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

  services.prometheus.globalConfig.external_labels = {
    host = "main";
  };

  # ── Systemd Failure Notifications ──────────────────────────────────────────
  services.systemd-failure-notify = {
    enable = true;
    services = [
      "prometheus"
      "opentelemetry-collector"
      "restic-backups-local"
      "thermald"
      "power-profiles-daemon"
    ];
  };

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
