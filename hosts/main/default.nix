{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
  ];

  system.stateVersion = "24.11";

  networking = {
    hostName = "main";
    networkmanager.enable = true;
  };

  services.logind.lidSwitch = "suspend";

  users.users.user = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [ ../../home/users/user/home.nix ];
    };
  };
}
