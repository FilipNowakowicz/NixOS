{ config, pkgs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/security.nix
    ../hardware/watchonly-hw.nix
  ];

  networking = {
    hostName = "watchonly";
    useDHCP = false;
    interfaces.enp1s0.useDHCP = true;
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [ curl wget lm_sensors ];

  services.fstrim.enable = true;
{ inputs, ... }:
let
  username = "nixos";
in {
  imports = [
    ../modules/base.nix
    ../hardware/watchonly-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "watchonly";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = [ ../home/default.nix ];
  };
}
