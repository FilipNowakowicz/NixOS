{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
  ];

  system.stateVersion = "24.11";

  networking = {
    hostName = "vm";
    networkmanager.enable = true;
  };

  # Enable SSH for remote deployment via `ssh nixvm`
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  users.users.user = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "video" ];
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
