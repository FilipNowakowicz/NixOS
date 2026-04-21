{ pkgs, ... }:
{
  # ── Compositor & Wayland ───────────────────────────────────────────────
  programs.hyprland.enable = true;
  programs.dconf.enable = true;

  services = {
    # ── Input ──────────────────────────────────────────────────────────────
    libinput.enable = true;

    # ── Audio ──────────────────────────────────────────────────────────────
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    pulseaudio.enable = false;

    # ── Display Manager ────────────────────────────────────────────────────
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${pkgs.hyprland}/bin/start-hyprland";
          user = "greeter";
        };
      };
    };
  };

  # ── XDG Portals ────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # ── System Packages ────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    gnome-keyring
    networkmanagerapplet
    polkit_gnome
    gnome-themes-extra
  ];

  # ── Fonts ──────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
      inter
    ];
  };
}
