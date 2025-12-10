{ lib, pkgs, ... }:
{
  networking.firewall.allowPing = false;
  services.openssh.enable = lib.mkForce false;

  services.pcscd.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
  };

  services.avahi.enable = lib.mkForce false;
  networking.networkmanager.wifi.macAddress = "random";

  environment.systemPackages = with pkgs; [
    gnupg
    age
    openssl
    opensc
    pcsc-tools
    pinentry-curses
    yubikey-manager
    yubikey-personalization
  ];
}
