{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/desktop.nix
    ../modules/qemu.nix
    ../modules/security.nix
    ../hardware/main-vm-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "main-vm";
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;

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
