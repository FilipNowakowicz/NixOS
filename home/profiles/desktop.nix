{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Terminal ──────────────────────────────────────────────────────────────
    kitty

    # ── Wayland utilities ────────────────────────────────────────────────────
    wl-clipboard
    grim          # screenshot
    slurp         # region select (used with grim)
    waybar
    swaybg
    hyprlock
    brightnessctl
    cliphist

    # ── Desktop UX ───────────────────────────────────────────────────────────
    pavucontrol
    blueman

    # ── Browsers / Apps ──────────────────────────────────────────────────────
    firefox
    keepassxc
    mpv
    wasistlos
    spotify

    # ── Visuals / Toys ───────────────────────────────────────────────────────
    cava
    fastfetch
    pipes-rs
    tty-clock
    cbonsai
    cmatrix
  ];

  # GTK theming
  gtk.enable = true;

  # Cursor
  home.pointerCursor = {
    gtk.enable = true;
    name    = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size    = 24;
  };

}
