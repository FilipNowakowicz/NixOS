{ pkgs, ... }:
{
  # Desktop-related user packages (X11/Awesome-only)
  home.packages = with pkgs; [
    # terminal / launcher
    kitty
    rofi
    feh

    # compositor / notifications
    picom
    dunst

    # clipboard / audio
    xclip
    xsel
    pavucontrol

    # browsers / apps
    firefox
    chromium
    keepassxc
    mpv
    zathura
    zathura-pdf-mupdf
    flameshot
    thunar

    # editor
    vscode

    # visuals / toys (optional)
    cava
    fastfetch
    pipes-rs
    tty-clock
    cbonsai
    cmatrix
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
