{ config, pkgs, lib, ... }:
let
  nixRepo = "${config.home.homeDirectory}/nix";
in
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
    ../../theme/module.nix
  ];

  themes.active = "mono-mesh";

  gtk.gtk4.theme = null;

  # ── Git ────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings.user.name = "Filip Nowakowicz";
    settings.user.email = "filip.nowakowicz@gmail.com";
    signing.format = null;
  };

  # ── PATH ───────────────────────────────────────────────────────────────
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
  ];

  # ── Scripts ────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    (writeShellApplication {
      name = "theme-switch";
      runtimeInputs = with pkgs; [ home-manager hyprland waybar swaybg kitty procps systemd libnotify fzf ];
      text = ''
        NIX_REPO="${nixRepo}"
      '' + builtins.readFile ../../files/scripts/theme-switch.sh;
    })

    (writeShellApplication {
      name = "waybar-weather";
      runtimeInputs = with pkgs; [ curl ];
      text = builtins.readFile ../../files/scripts/waybar-weather.sh;
    })

    (writeShellApplication {
      name = "clipboard-pick";
      runtimeInputs = with pkgs; [ cliphist fzf wl-clipboard ];
      text = builtins.readFile ../../files/scripts/clipboard-pick.sh;
    })
  ];

  # ── XDG MIME Apps ──────────────────────────────────────────────────────
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };

  xdg.userDirs.setSessionVariables = false;

  # ── Zsh ────────────────────────────────────────────────────────────────
  # Base options, plugins, and vi-mode are set in home/profiles/base.nix
  programs.zsh = {
    shellAliases = {
      # Files
      ll   = "ls -lh --color=auto";
      la   = "ls -A";
      l    = "ls -CF";
      cp   = "cp -i";
      mv   = "mv -i";
      # Navigation
      ".."   = "cd ..";
      "..."  = "cd ../..";
      "...." = "cd ../../..";
      d      = "dirs -v";
      # Git
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
      # System
      rebuild          = "nh os switch --hostname main ${nixRepo}";
      battery          = "acpi -b";
      buds             = "bluetoothctl connect DC:69:E2:CF:9A:BD";
      headset          = "bluetoothctl connect 40:58:99:3D:C8:D3";
      whatsapp         = "wasistlos &";
      copilot          = "steam-run gh copilot";
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
      _theme_switch_completion() {
        local themes=($HOME/.config/themes/*/)
        themes=("''${themes[@]##*/}")
        _describe 'themes' themes
      }
      compdef _theme_switch_completion theme-switch

      bindkey "''${terminfo[kcuu1]}" history-beginning-search-backward
      bindkey "''${terminfo[kcud1]}" history-beginning-search-forward
    '';
  };

  # ── Themes & Config Files ──────────────────────────────────────────────
  xdg.configFile = {
    # Neovim
    "nvim".source = ../../files/nvim;

    # Kitty
    "kitty/kitty.conf".source = ../../files/kitty/kitty.conf;

    # Hyprland
    "hypr/hyprland.conf".source = ../../files/hypr/hyprland.conf;

    # Hyprlock
    "hypr/hyprlock.conf".source = ../../files/hypr/hyprlock.conf;

    # Waybar
    "waybar/config".source = ../../files/waybar/config;
    "waybar/style.css".source = ../../files/waybar/style.css;
  };

  # ── Cliphist ────────────────────────────────────────────────────────────
  services.cliphist = {
    enable = true;
  };

  # ── Mako ───────────────────────────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      font             = "JetBrainsMono Nerd Font 11";
      background-color = "#${config.themes._activeThemeColors.bg}";
      text-color       = "#${config.themes._activeThemeColors.text}";
      border-color     = "#${config.themes._activeThemeColors.orange}";
      border-radius    = 8;
      border-size      = 2;
      anchor           = "top-right";
      margin           = "12";
      padding          = "10,14";
      width            = 300;
      default-timeout  = 5000;
      max-visible      = 5;
    };
  };

}
