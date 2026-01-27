{ pkgs, ... }:
{
  # Desktop / GUI Packages
  home.packages = with pkgs; [
    # ── Terminal / Launcher ──────────────────────────────────
    kitty
    rofi
  
    # ── Desktop UX ───────────────────────────────────────────
    dunst
    picom
    feh
    flameshot
    pavucontrol
  
    # ── Browsers / Apps ──────────────────────────────────────
    firefox
    chromium
    keepassxc
    mpv
    vscode
  
    # ── TeX / PDF ────────────────────────────────────────────
    zathura
    texlive.combined.scheme-medium
    texlab
  
    # ── Clipboard ────────────────────────────────────────────
    xclip
    xsel
  
    # ── Visuals / Toys (optional) ────────────────────────────
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
