{ config, pkgs, ... }:
let
  colors = import ../../theme/active.nix;
in
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];

  programs.git = {
    enable = true;
    settings.user.name = "Filip Nowakowicz";
    settings.user.email = "filip.nowakowicz@gmail.com";
  };

  # PATH additions
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
  ];

  # Zsh — user-specific aliases and shell functions
  # Base options, plugins, and vi-mode are set in home/profiles/base.nix
  programs.zsh = {
    shellAliases = {
      # ── Files ──────────────────────────────────────────────
      ll   = "ls -lh --color=auto";
      la   = "ls -A";
      l    = "ls -CF";
      cp   = "cp -i";
      mv   = "mv -i";
      # ── Navigation ─────────────────────────────────────────
      ".."   = "cd ..";
      "..."  = "cd ../..";
      "...." = "cd ../../..";
      d      = "dirs -v";
      # ── Git ────────────────────────────────────────────────
      g    = "git";
      ga   = "git add";
      gd   = "git diff";
      gco  = "git checkout";
      gb   = "git branch";
      gc   = "git commit -m";
      gca  = "git commit -am";
      gp   = "git push";
      gl   = "git pull";
      glog = "git log --oneline --graph --decorate";
      # ── System ─────────────────────────────────────────────
      rebuild          = "sudo nixos-rebuild switch --flake '.#main'";
      battery          = "acpi -b";
      buds             = "bluetoothctl connect DC:69:E2:CF:9A:BD";
      headset          = "bluetoothctl connect 40:58:99:3D:C8:D3";
      whatsapp         = "wasistlos &";
    };

    initContent = ''
      mkcd()   { mkdir -p -- "$1" && cd -- "$1"; }
      detach() { setsid -f "$@" >/dev/null 2>&1 < /dev/null; }
      extract() {
        [[ -f "$1" ]] || { echo "extract: file not found: $1" >&2; return 1; }
        case "$1" in
          *.tar.bz2) tar xjf "$1" ;;
          *.tar.gz)  tar xzf "$1" ;;
          *.tar.xz)  tar xJf "$1" ;;
          *.tar.zst) tar --zstd -xf "$1" ;;
          *.zip)     unzip "$1" ;;
          *.7z)      7z x "$1" ;;
          *) echo "extract: unsupported format: $1" >&2; return 2 ;;
        esac
      }
    '';
  };

  # Wallpaper
  home.file.".local/share/wallpapers/wallpaper1.png".source =
    ../../theme/wallpapers/wallpaper1.png;

  # ── Neovim ───────────────────────────────────────────────────────────────────
  xdg.configFile."nvim".source = ../../files/nvim;

  # ── Kitty ────────────────────────────────────────────────────────────────────
  # Per-file so current-theme.conf can be generated from colors.nix
  xdg.configFile."kitty/kitty.conf".source = ../../files/kitty/kitty.conf;
  xdg.configFile."kitty/current-theme.conf".text = ''
    # vim:ft=kitty
    ## name: Gruvbox Warm

    foreground           #${colors.text}
    background           #${colors.bg}
    selection_foreground #${colors.text}
    selection_background #${colors.brown}

    cursor            #${colors.amber}
    cursor_text_color #${colors.bg}

    url_color #${colors.amber}

    active_border_color   #${colors.amber}
    inactive_border_color #${colors.brown}
    bell_border_color     #${colors.orange}

    wayland_titlebar_color #${colors.bg}

    active_tab_foreground   #${colors.text}
    active_tab_background   #${colors.bg}
    inactive_tab_foreground #${colors.brown}
    inactive_tab_background #${colors.bg}
    tab_bar_background      #${colors.bg}

    # 16 colors — gruvbox-warm extended palette
    color0  #${colors.bg}
    color8  #${colors.brown}
    color1  #cc241d
    color9  #fb4934
    color2  #98971a
    color10 #b8bb26
    color3  #${colors.amber}
    color11 #fabd2f
    color4  #458588
    color12 #83a598
    color5  #b16286
    color13 #d3869b
    color6  #689d6a
    color14 #8ec07c
    color7  #${colors.text}
    color15 #fbf1c7
  '';

  # ── Hyprland ─────────────────────────────────────────────────────────────────
  xdg.configFile."hypr/hyprland.conf".source = ../../files/hypr/hyprland.conf;
  xdg.configFile."hypr/colors.conf".text = ''
    $col_active   = rgb(${colors.amber})
    $col_inactive = rgb(${colors.brown})
  '';

  # ── Waybar ───────────────────────────────────────────────────────────────────
  home.file.".local/bin/waybar-weather" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      result=$(curl -sf --max-time 5 "wttr.in/Warsaw?format=%c+%t")
      [ -n "$result" ] && echo "$result" || echo "? --"
    '';
  };

  xdg.configFile."waybar/config".source = ../../files/waybar/config;
  xdg.configFile."waybar/style.css".source = ../../files/waybar/style.css;
  xdg.configFile."waybar/colors.css".source = ../../files/waybar/colors.css;

  # ── Mako ─────────────────────────────────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      font             = "JetBrainsMono Nerd Font 11";
      background-color = "#${colors.bg}";
      text-color       = "#${colors.text}";
      border-color     = "#${colors.orange}";
      border-radius    = 8;
      border-size      = 2;
      anchor           = "top-right";
      margin           = "12";
      padding          = "10 14";
      width            = 300;
      default-timeout  = 5000;
      max-visible      = 5;
    };
  };

  # ── Hyprlock ─────────────────────────────────────────────────────────────────
  xdg.configFile."hypr/hyprlock.conf".source = ../../files/hypr/hyprlock.conf;
  xdg.configFile."hypr/hyprlock-colors.conf".source = ../../files/hypr/hyprlock-colors.conf;

  # ── Rofi ─────────────────────────────────────────────────────────────────────
  xdg.configFile."rofi/config.rasi".source = ../../files/rofi/config.rasi;
  xdg.configFile."rofi/colors.rasi".source = ../../files/rofi/colors.rasi;
}
