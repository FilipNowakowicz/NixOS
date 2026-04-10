{ config, pkgs, lib, ... }:
let
  theme = (import ../../theme/generator.nix { inherit pkgs lib; themeDir = ../../theme; });
  inherit (theme) themeConfigs activeThemeName colors activeTheme;
in
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];

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
      runtimeInputs = with pkgs; [ home-manager hyprland waybar swaybg kitty procps systemd libnotify ];
      text = builtins.readFile ../../files/scripts/theme-switch.sh;
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
      rebuild          = "nh os switch /home/user/nix#main";
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
  # Generate all theme configs + application configs
  xdg.configFile = themeConfigs // {
    # Neovim
    "nvim".source = ../../files/nvim;

    # Kitty - use active theme colors directly
    "kitty/kitty.conf".source = ../../files/kitty/kitty.conf;
    "kitty/current-theme.conf".text = ''
      # vim:ft=kitty
      ## name: ${activeThemeName}

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

      # 16 colors — extended palette
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

    # Hyprland - use active theme colors directly
    "hypr/hyprland.conf".source = ../../files/hypr/hyprland.conf;
    "hypr/colors.conf".text = ''
      $col_active   = rgb(${colors.amber})
      $col_inactive = rgb(${colors.brown})
      $col_shadow   = rgba(${colors.bg}cc)
    '';

    # Hyprlock - use active theme colors directly
    "hypr/hyprlock.conf".source = ../../files/hypr/hyprlock.conf;
    "hypr/hyprlock-colors.conf".text = ''
      $text   = rgb(${colors.text})
      $bg     = rgb(${colors.bg})
      $amber  = rgb(${colors.amber})
      $orange = rgb(${colors.orange})
    '';

    # Waybar - use active theme colors directly
    "waybar/config".source = ../../files/waybar/config;
    "waybar/style.css".source = ../../files/waybar/style.css;
    "waybar/colors.css".text = ''
      @define-color bg #${colors.bg};
      @define-color brown #${colors.brown};
      @define-color orange #${colors.orange};
      @define-color amber #${colors.amber};
      @define-color text #${colors.text};
    '';
  };

  # ── Wallpaper & Scripts ────────────────────────────────────────────────
  home.file = {
    ".local/share/wallpapers/current.png".source = activeTheme.wallpaper;
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
      background-color = "#${colors.bg}";
      text-color       = "#${colors.text}";
      border-color     = "#${colors.orange}";
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
