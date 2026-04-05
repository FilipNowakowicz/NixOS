{ pkgs, ... }:
{
  # Hyprland compositor (enables Wayland session, polkit, etc.)
  programs.hyprland.enable = true;

  # Input (no xserver)
  services.libinput.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.pulseaudio.enable = false;

  # XDG portals (Hyprland + GTK fallback)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  services.flatpak.enable = true;
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-keyring
    networkmanagerapplet
    polkit_gnome
    gnome-themes-extra
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
      nerd-fonts.jetbrains-mono
    ];
  };
}
