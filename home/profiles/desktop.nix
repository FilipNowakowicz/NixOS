{ pkgs, ... }:
{
  # Desktop-related user packages
  home.packages = with pkgs; [
    firefox
    alacritty
    rofi
    feh
    picom
    dunst
    xclip
    xsel
    pavucontrol
  ];

  # GTK theming support (needed by many desktop apps)
  gtk = {
    enable = true;
  };

  # XDG user directories
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # Notifications
  services.dunst.enable = true;

  # Compositor (optional, but typical with AwesomeWM)
  services.picom = {
    enable = true;
    fade = true;
    shadow = true;
  };
}
