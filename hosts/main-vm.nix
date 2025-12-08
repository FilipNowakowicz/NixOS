{ config, pkgs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/desktop.nix
    ../modules/security.nix
    ../modules/qemu.nix
    ../hardware/main-vm-hw.nix
  ];

  networking = {
    hostName = "main-vm";
    useDHCP = false;
    interfaces.enp1s0.useDHCP = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [ firefox git htop virt-manager ];

  services.libvirtd.enable = true;
}
