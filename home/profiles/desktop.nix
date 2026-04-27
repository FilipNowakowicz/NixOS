{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Terminal ──────────────────────────────────────────────────────────────
    kitty

    # ── Wayland utilities ────────────────────────────────────────────────────
    wl-clipboard
    grim # screenshot
    slurp # region select (used with grim)
    waybar
    swaybg
    hyprlock
    brightnessctl
    cliphist

    # ── Desktop UX ───────────────────────────────────────────────────────────
    pavucontrol
    blueman

    # ── Browsers / Apps ──────────────────────────────────────────────────────
    discord
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

  # Firefox with VA-API hardware video decoding (Intel iGPU on Wayland)
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "gfx.webrender.all" = true;
        "widget.wayland-dmabuf-vaapi.enabled" = true;
      };
    };
  };

  # GTK theming
  gtk.enable = true;

  # Cursor
  home.pointerCursor = {
    gtk.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

}
