{ pkgs, config, ... }:
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
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles."ivx1ayzq.default" = {
      id = 0;
      isDefault = true;
      settings = {
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "gfx.webrender.all" = true;
        "widget.wayland-dmabuf-vaapi.enabled" = true;
      };
    };
  };

  # GTK theming
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  # XDG color-scheme preference (read by GTK4, libadwaita, portals)
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # Cursor
  home.pointerCursor = {
    gtk.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

}
