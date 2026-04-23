{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  network = import ../../lib/network.nix;
  inherit (network) tailnetFQDN;
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/sops-base.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/hardware/nvidia-prime.nix
    inputs.microvm.nixosModules.host
    ../../modules/nixos/microvms/homeserver-vm.nix
  ];

  # ── microvm ─────────────────────────────────────────────────────────────────
  microvms.homeserver-vm.externalInterface = "wlp0s20f3";

  # ── Hardware ────────────────────────────────────────────────────────────────
  networking = {
    hostName = "main";
    networkmanager.enable = true;
    # Required for Mullvad/Tailscale: prevents firewall from dropping VPN-routed packets
    firewall.checkReversePath = "loose";
    # Point to systemd-resolved stub for split DNS (Tailscale tailnet hostnames)
    nameservers = [ "127.0.0.53" ];
  };

  hardware.bluetooth.enable = true;

  system.stateVersion = "24.11";

  environment.systemPackages = with pkgs; [ sbctl ];

  boot = {
    # Lanzaboote (Secure Boot)
    loader.systemd-boot.enable = lib.mkForce false;
    loader.systemd-boot.configurationLimit = 5;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # IOMMU protection — blocks Thunderbolt/PCIe DMA attacks
    kernelParams = [
      "intel_iommu=on"
      "iommu=force"
    ];

    initrd = {
      # Systemd in initrd (required for initrd SSH)
      systemd = {
        enable = true;
        # Tear down all non-loopback interfaces before transitioning to stage 2.
        # Ensures port 2222 stops being reachable the moment stage 1 is done,
        # before stage 2's firewall loads. Guards against future misconfiguration
        # (e.g. if WiFi support were added to initrd later).
        services.flush-network-before-stage2 = {
          description = "Tear down initrd network before transitioning to stage 2";
          before = [ "initrd-cleanup.service" ];
          wantedBy = [ "initrd.target" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "flush-initrd-network" ''
              for iface in /sys/class/net/*; do
                iface=$(basename "$iface")
                [ "$iface" = "lo" ] && continue
                ip link set dev "$iface" down 2>/dev/null || true
                ip addr flush dev "$iface" 2>/dev/null || true
              done
            '';
          };
        };
      };

      # Initrd SSH — fallback LUKS unlock when TPM2 fails.
      # Recovery requires a USB Ethernet dongle; WiFi is not available in stage 1.
      # Port 2222 is therefore NOT exposed on WiFi (including public WiFi).
      # flush-network-before-stage2 tears down the interface before stage 2 starts.
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
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce "/run/secrets/initrd_ssh_host_ed25519_key";
      };
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
      serviceEnvironmentFile = config.sops.templates."otel-env".path;
    };
  };

  # ── Services ────────────────────────────────────────────────────────────────
  services = {
    resolved = {
      enable = true;
      settings.Resolve.DNSSEC = "false"; # Tailscale manages its own trust chain
    };

    thermald.enable = true;
    power-profiles-daemon.enable = true;
    fwupd.enable = true;

    openssh = {
      enable = true;
      openFirewall = false; # Accessible via Tailscale only
    };

    tailscale = {
      enable = true;
      openFirewall = true;
    };

    mullvad-vpn.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "15min";
    };

    fprintd = {
      enable = true;
      tod = {
        enable = true;
        driver = pkgs.libfprint-2-tod1-goodix;
      };
    };
    # Bluetooth management (GUI)
    blueman.enable = true;

    prometheus.globalConfig.external_labels = {
      host = "main";
    };

    # ── Systemd Failure Notifications ────────────────────────────────────────
    systemd-failure-notify = {
      enable = true;
      services = [
        "prometheus"
        "opentelemetry-collector"
        "restic-backups-local"
        "thermald"
        "power-profiles-daemon"
      ];
    };

    # ── Backups ────────────────────────────────────────────────────────────────
    restic.backups.local = {
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
    };
  };

  services.hardened = {
    # Hardware daemons: need /sys writes via dbus, no network, no private devices.
    # Skip PrivateDevices (/sys access), SystemCallFilter (broad hw syscalls needed).
    thermald = {
      extraConfig = {
        PrivateDevices = null;
        SystemCallFilter = null;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };

    power-profiles-daemon = {
      extraConfig = {
        PrivateDevices = null;
        SystemCallFilter = null;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };

    # fwupd: writes firmware to hardware and loads kernel modules.
    # Skip ProtectSystem (firmware writes), PrivateDevices (/dev access),
    # ProtectKernelModules/Tunables (capsule loading), ProtectClock (EFI time),
    # MemoryDenyWriteExecute (plugin loading), SystemCallFilter (broad hw access).
    fwupd = {
      extraConfig = {
        PrivateDevices = null;
        ProtectSystem = null;
        ProtectKernelTunables = null;
        ProtectKernelModules = null;
        ProtectClock = null;
        MemoryDenyWriteExecute = null;
        SystemCallFilter = null;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
    };

    # bluetoothd: needs AF_BLUETOOTH + AF_NETLINK for HCI management.
    # Skip PrivateDevices (/dev/hci*), ProtectKernelModules (hci module loading).
    bluetooth = {
      extraConfig = {
        PrivateDevices = null;
        ProtectKernelModules = null;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_BLUETOOTH"
          "AF_NETLINK"
        ];
      };
    };
  };

  # Fingerprint login
  security.pam.services = {
    hyprlock.fprintAuth = true;
    greetd.fprintAuth = true;
  };

  # Backlight control (using brightnessctl)
  hardware.acpilight.enable = true;

  systemd.services = {
    prometheus.serviceConfig = {
      TimeoutStopSec = "20s";
      SupplementaryGroups = [ "telemetry-ingest" ];
    };
    "opentelemetry-collector".serviceConfig.SupplementaryGroups = lib.mkAfter [ "telemetry-ingest" ];
  };

  # ── USB Device Control ─────────────────────────────────────────────────────
  services.usbguard = {
    enable = true;
    rules = ''
      # Default policy: block all USB devices
      # Devices must be explicitly whitelisted below

      # Allow Logitech USB Receiver (mouse)
      # ID: 046d:c54d
      allow id 046d:c54d

      # Reject everything else
      reject
    '';
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    templates."otel-env" = {
      content = "BASICAUTH_PASSWORD=${config.sops.placeholder.observability_ingest_password}";
      mode = "0400";
    };
    templates."cachix-netrc" = {
      content = ''
        machine filipnowakowicz.cachix.org
        password ${config.sops.placeholder.cachix_auth_token}
      '';
      mode = "0400";
    };
    secrets = {
      user_password.neededForUsers = true;
      observability_ingest_password = {
        group = "telemetry-ingest";
        mode = "0440";
      };
      restic_password = { };
      initrd_ssh_host_ed25519_key = { };
      cachix_auth_token = { };
    };
  };

  nix.settings.netrc-file = config.sops.templates."cachix-netrc".path;

  users.groups.telemetry-ingest = { };

  users.users.user = {
    extraGroups = [ "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
  };

}
