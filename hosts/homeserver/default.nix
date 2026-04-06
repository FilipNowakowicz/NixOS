# Placeholder config for a headless home server.
# hardware-configuration.nix must be replaced with real hardware config generated
# on the target machine via: nixos-generate-config
# or during a fresh install via: nixos-anywhere --generate-hardware-config ...
{ pkgs, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/security.nix
  ];

  system.stateVersion = "24.11";

  nix.settings.trusted-users = [ "root" "user" ];

  zramSwap.enable = true;

  networking = {
    hostName = "homeserver";
    networkmanager.enable = true;
  };

  # Override the mkDefault false from security.nix — SSH is required on a headless server
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  users.users.user = {
    home = "/home/user";
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC31z32AcISdGR5ng15HNHmOPPmzPkX+KRQzr98Xhlze"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [ ../../home/users/user/home.nix ];
    };
  };
}
