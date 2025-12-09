{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/qemu.nix
    ../modules/security.nix
    ../hardware/labvm-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "labvm";
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [ ../home/default.nix ];
    };
  };
}
