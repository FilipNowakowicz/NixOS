{ config, pkgs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/security.nix
    ../modules/qemu.nix
    ../hardware/labvm-hw.nix
  ];

  networking = {
    hostName = "labvm";
    useDHCP = false;
    interfaces.enp1s0.useDHCP = true;
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [ wireshark tmux qemu ];

  services.libvirtd.enable = true;
{ inputs, ... }:
let
  username = "nixos";
in {
  imports = [
    ../modules/base.nix
    ../hardware/labvm-hw.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "labvm";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = [ ../home/default.nix ];
  };
}
