{ config, pkgs, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/security.nix
    ../modules/crypto.nix
    ../hardware/coldvm-hw.nix
  ];

  networking = {
    hostName = "coldvm";
    useDHCP = false;
    interfaces.enp1s0.useDHCP = true;
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [ gnupg age openssl ];

  services.openssh.enable = false;
}
