{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking = {
    hostName = "main";
    networkmanager.enable = true;
  };

  services.blueman.enable = true;
  services.logind.lidSwitch = "suspend";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [
        ../../home/users/user/home.nix
      ];
    };
  };
}
