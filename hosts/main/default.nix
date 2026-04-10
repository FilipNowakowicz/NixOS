{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
  ];

  system.stateVersion = "24.11";

  # ── Lanzaboote Secure Boot ──────────────────────────────────────────────────
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # ── Systemd in initrd (required for TPM2 LUKS unlock) ───────────────────────
  boot.initrd.systemd.enable = true;

  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    sbctl
  ];

  networking = {
    hostName = "main";
    networkmanager.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── Intel iGPU / Wayland env vars ───────────────────────────────────────────
  # Pins the session to the Intel iGPU. NVIDIA is available on-demand via nvidia-offload.
  environment.sessionVariables = {
    NIXOS_OZONE_WL              = "1";           # Electron apps: use Wayland backend
    LIBVA_DRIVER_NAME           = "iHD";         # VA-API → Intel Media Driver
    __GLX_VENDOR_LIBRARY_NAME   = "mesa";        # GLX → Mesa (Intel) by default
    # Pins Hyprland's primary GPU to the Intel iGPU so it doesn't accidentally
    # pick the NVIDIA card.  Verify after install:
    #   ls -la /dev/dri/by-path/ | grep 'pci-0000:00:02'
    AQ_DRM_DEVICES              = "/dev/dri/by-path/pci-0000:00:02.0-card";
  };

  services.openssh = {
    enable = true;
    openFirewall = false;  # Intentionally not exposed — accessible via Tailscale only
  };

  services.mullvad-vpn.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.fwupd.enable = true;  # Firmware update daemon for hardware devices

  # ── Thermal & Power Management ───────────────────────────────────────────────
  # thermald prevents CPU thermal throttling using Intel DPTF tables
  # power-profiles-daemon exposes performance/balanced/power-saver profiles
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  services.logind.settings = {
    Login.HandleLidSwitch = "suspend";
    # Optional: keep running on AC power
    # lidSwitchExternalPower = "ignore";
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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVv8FZjCgmWqmkSLYv0uMySdxpzJUMtoXAwXDonTM7k user@main"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.user = {
      imports = [
        ../../home/users/user/home.nix
        ../../home/profiles/workstation.nix
      ];
    };
  };
}
