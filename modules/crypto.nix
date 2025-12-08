{ config, pkgs, ... }:
{
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
  };

  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    gnupg
    opensc
    pcsc-tools
    pinentry-curses
    yubikey-manager
    yubikey-personalization
  ];
}
