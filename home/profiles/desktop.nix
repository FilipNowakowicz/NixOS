{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Terminal ─────────────────────────────────────────────
    kitty

    # ── Launcher ─────────────────────────────────────────────
    rofi

    # ── Wayland utilities ────────────────────────────────────
    wl-clipboard
    grim          # screenshot
    slurp         # region select (used with grim)
    waybar
    hyprpaper

    # ── Desktop UX ───────────────────────────────────────────
    gsimplecal
    pavucontrol

    # ── Browsers / Apps ──────────────────────────────────────
    firefox
    chromium
    keepassxc
    mpv
    vscode

    # ── PDF / TeX ────────────────────────────────────────────
    zathura
    texlive.combined.scheme-medium
    texlab

    # ── Visuals / Toys ───────────────────────────────────────
    cava
    fastfetch
    pipes-rs
    tty-clock
    cbonsai
    cmatrix
  ];

  # GTK theming
  gtk.enable = true;

  # Notifications (Wayland)
  services.mako.enable = true;
}
