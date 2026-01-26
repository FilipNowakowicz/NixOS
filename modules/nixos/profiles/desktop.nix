{ pkgs, ... }:
{
  services.xserver = {
    enable = true;

    xkb = {
      layout = "us";
      variant = "dvorak";
      options = "caps:escape";
    };

    displayManager.startx.enable = true;
    windowManager.awesome.enable = true;

    desktopManager.xterm.enable = false;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  hardware.pulseaudio.enable = false;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    pkgs.gnome-themes-extra
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
