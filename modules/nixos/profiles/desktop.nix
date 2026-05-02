{ pkgs, ... }:
{
  # ── Compositor & Wayland ───────────────────────────────────────────────
  programs.hyprland.enable = true;
  programs.dconf.enable = true;

  # swayosd-server needs /dev/input access for its libinput backend
  users.users.user.extraGroups = [ "input" ];

  services = {
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
  # `enableDefaultPackages` already pulls dejavu_fonts, liberation_ttf, and
  # noto-fonts-color-emoji; only list additions here.
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts
      nerd-fonts.jetbrains-mono
      inter
    ];
  };
}
