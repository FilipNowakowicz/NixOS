{ pkgs, ... }:

{
  services.xserver = {
    enable = true;

    # VM-friendly Xorg driver
    videoDrivers = [ "virtio" ];

    # Keyboard layout (X11)
    xkb = {
      layout = "us";
      variant = "dvorak";
      options = "caps:escape";
    };

    # startx workflow (no display manager)
    displayManager.startx.enable = true;

    # Window manager
    windowManager.awesome.enable = true;

    # Don’t spawn xterm automatically
    desktopManager.xterm.enable = false;
  };

  services.displayManager.defaultSession = "none+awesome";

  # Audio (modern stack)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.pulseaudio.enable = false;

  # Portals (needed for many desktop apps)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  services.flatpak.enable = true;
  programs.dconf.enable = true;

  # Minimal X11 bits + theme assets
  environment.systemPackages = with pkgs; [
    gnome-themes-extra
    xorg.xinit
  ];

  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    fontconfig.enable = true;
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-color-emoji
    ];
  };
}
