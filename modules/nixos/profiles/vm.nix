# Shared NixOS module for all QEMU/KVM virtual machines.
# Provides: virtio hardware, disko layout, impermanence base,
# passwordless sudo, SSH, sops base, networking.
#
# Host configs import this and add only what's unique:
# hostname, services, extra impermanence dirs, sops secrets.
{ inputs, lib, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    "${inputs.nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
  ];

  # ── Boot (virtio + UEFI) ──────────────────────────────────────────────────
  boot = {
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "xhci_pci"
      "sd_mod"
    ];
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    loader.efi.canTouchEfiVariables = true;
  };

  # ── Disko (ESP + ephemeral root + persistent /persist) ─────────────────────
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            extraArgs = [
              "-n"
              "main-boot"
            ];
          };
        };
        root = {
          size = "12G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [
              "-L"
              "main-root"
            ];
          };
        };
        persist = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
            extraArgs = [
              "-L"
              "persist"
            ];
          };
        };
      };
    };
  };

  # ── Impermanence (base — hosts extend with service-specific dirs) ──────────
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  # ── Sudo (passwordless — needed by deploy-rs, acceptable for VMs) ──────────
  security.sudo.wheelNeedsPassword = false;

  # ── SSH ────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # ── Nix ────────────────────────────────────────────────────────────────────
  nix.settings.trusted-users = [
    "root"
    "user"
  ];

  # ── Networking ─────────────────────────────────────────────────────────────
  networking.networkmanager.enable = lib.mkDefault true;
}
