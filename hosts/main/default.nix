{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/hardware/nvidia-prime.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
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
    kernelParams = [ "intel_iommu=on" "iommu=force" ];
  };

  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    sbctl
  ];

  networking = {
    hostName = "NixOS";
    networkmanager.enable = true;
  };

  hardware.bluetooth.enable = true;
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

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.user_password.neededForUsers = true;
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
