{ config, pkgs, ... }:
{
  services = {
    xserver = {
      enable = true;
      layout = "us";
      xkbVariant = "";
      xkbOptions = "caps:escape";

      desktopManager.xterm.enable = false;
      displayManager.gdm = {
        enable = true;
        wayland = true;
      };

      windowManager.awesome.enable = true;
    };

    xwayland.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };

  hardware.pulseaudio.enable = false;

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = with pkgs; [
    awesome
    gnome.gnome-themes-extra
    xdg-desktop-portal-gtk
  ];

  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    fontconfig.enable = true;
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
    ];
  };
}
