{ config, pkgs, lib, ... }:
let
  # Import active theme for fallback/default
  activeTheme = import ../../theme/active.nix;

  # Auto-discover all theme files
  themeDir = ../../theme/themes;
  themeFiles = builtins.readDir themeDir;

  # Load and validate each theme
  allThemes = lib.mapAttrs' (name: _:
    let
      themePath = themeDir + "/${name}";
      theme = import themePath;
      themeName = lib.removeSuffix ".nix" name;
    in
      lib.nameValuePair themeName (theme // { name = themeName; })
  ) (lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) themeFiles);

  # Filter: only enabled themes with existing wallpapers
  validThemes = lib.filterAttrs (_: theme:
    let
      enabled = theme.enabled or true;
      wallpaperExists = builtins.pathExists theme.wallpaper;
    in
      enabled && wallpaperExists
  ) allThemes;

  # Helper to generate theme config text
  mkThemeConfig = themeName: theme: {
    # Kitty theme
    "themes/${themeName}/kitty-theme.conf".text = ''
      # vim:ft=kitty
      ## name: ${themeName}

      foreground           #${theme.colors.text}
      background           #${theme.colors.bg}
      selection_foreground #${theme.colors.text}
      selection_background #${theme.colors.brown}

      cursor            #${theme.colors.amber}
      cursor_text_color #${theme.colors.bg}

      url_color #${theme.colors.amber}

      active_border_color   #${theme.colors.amber}
      inactive_border_color #${theme.colors.brown}
      bell_border_color     #${theme.colors.orange}

      wayland_titlebar_color #${theme.colors.bg}

      active_tab_foreground   #${theme.colors.text}
      active_tab_background   #${theme.colors.bg}
      inactive_tab_foreground #${theme.colors.brown}
      inactive_tab_background #${theme.colors.bg}
      tab_bar_background      #${theme.colors.bg}

      # 16 colors — extended palette
      color0  #${theme.colors.bg}
      color8  #${theme.colors.brown}
      color1  #cc241d
      color9  #fb4934
      color2  #98971a
      color10 #b8bb26
      color3  #${theme.colors.amber}
      color11 #fabd2f
      color4  #458588
      color12 #83a598
      color5  #b16286
      color13 #d3869b
      color6  #689d6a
      color14 #8ec07c
      color7  #${theme.colors.text}
      color15 #fbf1c7
    '';

    # Hyprland colors
    "themes/${themeName}/hypr-colors.conf".text = ''
      $col_active   = rgb(${theme.colors.amber})
      $col_inactive = rgb(${theme.colors.brown})
      $col_shadow   = rgba(${theme.colors.bg}cc)
    '';

    # Hyprlock colors
    "themes/${themeName}/hyprlock-colors.conf".text = ''
      $text   = rgb(${theme.colors.text})
      $bg     = rgb(${theme.colors.bg})
      $amber  = rgb(${theme.colors.amber})
      $orange = rgb(${theme.colors.orange})
    '';

    # Waybar colors
    "themes/${themeName}/waybar-colors.css".text = ''
      @define-color bg #${theme.colors.bg};
      @define-color brown #${theme.colors.brown};
      @define-color orange #${theme.colors.orange};
      @define-color amber #${theme.colors.amber};
      @define-color text #${theme.colors.text};
    '';

    # Wallpaper symlink
    "themes/${themeName}/wallpaper".source = theme.wallpaper;
  };

  # Generate configs for all valid themes
  themeConfigs = lib.foldl (acc: themeName:
    acc // (mkThemeConfig themeName validThemes.${themeName})
  ) {} (builtins.attrNames validThemes);

  # Active theme name for initial current symlink
  activeThemeName = activeTheme.name or "desert-dusk";

  # Use active theme colors for compatibility
  colors = activeTheme.colors;
in
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "26.05";

  imports = [
    ../../profiles/base.nix
    ../../profiles/desktop.nix
  ];

  # ── Git ────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings.user.name = "Filip Nowakowicz";
    settings.user.email = "filip.nowakowicz@gmail.com";
  };

  # ── PATH ───────────────────────────────────────────────────────────────
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
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
      rebuild          = "sudo nixos-rebuild switch --flake '.#main'";
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

    ".local/bin/waybar-weather" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        result=$(curl -sf --max-time 5 "wttr.in/Warsaw?format=%c+%t")
        [ -n "$result" ] && echo "$result" || echo "? --"
      '';
    };

    ".local/bin/theme-switch" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      THEME="''${1:-}"
      THEMES_DIR="$HOME/.config/themes"
      ACTIVE_FILE="$HOME/nix/home/theme/active.nix"

      # Get current theme from active.nix
      if [[ -f "$ACTIVE_FILE" ]]; then
          CURRENT_THEME=$(grep -oP 'themes/\K[^.]+' "$ACTIVE_FILE" 2>/dev/null || echo "unknown")
      else
          CURRENT_THEME="unknown"
      fi

      # List available themes if no argument
      if [[ -z "$THEME" ]]; then
          echo "Available themes:"
          for dir in "$THEMES_DIR"/*; do
              [[ -d "$dir" ]] && basename "$dir"
          done | sort
          echo ""
          echo "Current theme: $CURRENT_THEME"
          echo ""
          echo "Usage: theme-switch <theme-name>"
          exit 0
      fi

      # Validate theme exists
      if [[ ! -d "$THEMES_DIR/$THEME" ]]; then
          echo "Error: Theme not found: $THEME"
          echo "Available themes:"
          for dir in "$THEMES_DIR"/*; do
              [[ -d "$dir" ]] && basename "$dir"
          done | sort
          exit 1
      fi

      # Check if already active
      if [[ "$CURRENT_THEME" == "$THEME" ]]; then
          echo "Theme '$THEME' is already active"
          exit 0
      fi

      # Update active.nix
      ACTIVE_FILE="$HOME/nix/home/theme/active.nix"
      if [[ ! -f "$ACTIVE_FILE" ]]; then
          echo "Error: $ACTIVE_FILE not found"
          exit 1
      fi

      echo "import ./themes/$THEME.nix" > "$ACTIVE_FILE"
      echo "Updated active.nix to $THEME"

      # Rebuild home-manager (faster than full system rebuild)
      echo "Rebuilding home-manager configuration..."
      if ${pkgs.home-manager}/bin/home-manager switch --flake "$HOME/nix#user"; then
          # Reload services after successful rebuild
          ${pkgs.hyprland}/bin/hyprctl reload >/dev/null 2>&1 || true

          # Restart waybar to pick up new CSS
          ${pkgs.procps}/bin/pkill waybar || true
          sleep 0.3
          ${pkgs.waybar}/bin/waybar &

          ${pkgs.procps}/bin/pkill swaybg || true
          sleep 0.2
          ${pkgs.swaybg}/bin/swaybg -m fill -i "$HOME/.local/share/wallpapers/current.png" &

          for socket in /tmp/kitty-*/kitty-*; do
              [[ -S "$socket" ]] && ${pkgs.kitty}/bin/kitty @ --to "unix:$socket" load-config 2>/dev/null || true
          done

          # Kill any orphaned mako processes before restarting
          ${pkgs.procps}/bin/pkill mako || true
          sleep 0.5
          ${pkgs.systemd}/bin/systemctl --user restart mako.service 2>/dev/null || true

          ${pkgs.libnotify}/bin/notify-send "Theme changed" "Switched to: $THEME" || true
          echo "✓ Theme switched to $THEME"
      else
          echo "Error: home-manager rebuild failed"
          exit 1
      fi
    '';
    };

    ".local/bin/power-menu" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        
        action=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | ${pkgs.fzf}/bin/fzf --prompt="Power: " --reverse -0 -1)
        
        case "$action" in
          Lock)     ${pkgs.hyprland}/bin/hyprctl dispatch exec hyprlock ;;
          Logout)   ${pkgs.hyprland}/bin/hyprctl dispatch exit ;;
          Suspend)  ${pkgs.systemd}/bin/systemctl suspend ;;
          Reboot)   ${pkgs.systemd}/bin/systemctl reboot ;;
          Shutdown) ${pkgs.systemd}/bin/systemctl poweroff ;;
        esac
      '';
    };
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
