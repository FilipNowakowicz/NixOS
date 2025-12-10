{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/desktop.nix
    ../modules/security.nix
    ../hardware/laptop-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking = {
    hostName = "laptop";
    networkmanager.enable = true;
  };

  services.blueman.enable = true;
  services.logind.lidSwitch = "suspend";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [
        ../home/default.nix
        ../home/desktop.nix
      ];
    };
  };
}
