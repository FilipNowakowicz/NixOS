{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
  ];

  system.stateVersion = "24.11";

  networking = {
    hostName = "NixOS";
    networkmanager.enable = true;
  };

  # ── NVIDIA / Wayland env vars ────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL              = "1";           # Electron apps: use Wayland backend
    LIBVA_DRIVER_NAME           = "iHD";         # VA-API → Intel Media Driver
    __GLX_VENDOR_LIBRARY_NAME   = "mesa";        # GLX → Mesa (Intel) by default
    # Pins Hyprland's primary GPU to the Intel iGPU so it doesn't accidentally
    # pick the NVIDIA card.  Verify after install:
    #   ls -la /dev/dri/by-path/ | grep 'pci-0000:00:02'
    AQ_DRM_DEVICES              = "/dev/dri/card1"; # TODO: verify (Intel is usually card1 with PRIME)
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
  };

  services.mullvad-vpn.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

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
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVv8FZjCgmWqmkSLYv0uMySdxpzJUMtoXAwXDonTM7k user@main"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [
        ../../home/users/user/home.nix
        ../../home/profiles/workstation.nix
      ];
    };
  };
}
