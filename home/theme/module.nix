{ config, lib, ... }:
let
  cfg = config.themes;

  # Directory where themes are stored
  themeDir = ./.;
  themesDir = themeDir + /themes;

  # Auto-discover all theme files
  themeFiles = builtins.readDir themesDir;

  # Load and validate each theme
  allThemes = lib.mapAttrs' (
    name: _:
    let
      themePath = themesDir + "/${name}";
      theme = import themePath;
      themeName = lib.removeSuffix ".nix" name;
    in
    lib.nameValuePair themeName (theme // { name = themeName; })
  ) (lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) themeFiles);

  # Filter: only enabled themes with existing wallpapers
  validThemes = lib.filterAttrs (
    _: theme:
    let
      enabled = theme.enabled or true;
      wallpaperExists = builtins.pathExists theme.wallpaper;
    in
    enabled && wallpaperExists
  ) allThemes;

  # Get the active theme
  activeTheme = validThemes.${cfg.active} or (lib.head (lib.attrValues validThemes));

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
  themeConfigs = lib.foldl (
    acc: themeName: acc // (mkThemeConfig themeName validThemes.${themeName})
  ) { } (builtins.attrNames validThemes);

in
{
  options.themes = {
    active = lib.mkOption {
      type = lib.types.str;
      default = "mono-mesh";
      description = "The active theme name";
    };
    _activeThemeColors = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      description = "Active theme colors (internal)";
    };
  };

  config = {
    themes._activeThemeColors = activeTheme.colors;
    xdg.configFile = themeConfigs // {
      # Kitty - use active theme colors directly
      "kitty/current-theme.conf".text = ''
        # vim:ft=kitty
        ## name: ${activeTheme.name}

        foreground           #${activeTheme.colors.text}
        background           #${activeTheme.colors.bg}
        selection_foreground #${activeTheme.colors.text}
        selection_background #${activeTheme.colors.brown}

        cursor            #${activeTheme.colors.amber}
        cursor_text_color #${activeTheme.colors.bg}

        url_color #${activeTheme.colors.amber}

        active_border_color   #${activeTheme.colors.amber}
        inactive_border_color #${activeTheme.colors.brown}
        bell_border_color     #${activeTheme.colors.orange}

        wayland_titlebar_color #${activeTheme.colors.bg}

        active_tab_foreground   #${activeTheme.colors.text}
        active_tab_background   #${activeTheme.colors.bg}
        inactive_tab_foreground #${activeTheme.colors.brown}
        inactive_tab_background #${activeTheme.colors.bg}
        tab_bar_background      #${activeTheme.colors.bg}

        # 16 colors — extended palette
        color0  #${activeTheme.colors.bg}
        color8  #${activeTheme.colors.brown}
        color1  #cc241d
        color9  #fb4934
        color2  #98971a
        color10 #b8bb26
        color3  #${activeTheme.colors.amber}
        color11 #fabd2f
        color4  #458588
        color12 #83a598
        color5  #b16286
        color13 #d3869b
        color6  #689d6a
        color14 #8ec07c
        color7  #${activeTheme.colors.text}
        color15 #fbf1c7
      '';

      # Hyprland colors
      "hypr/colors.conf".text = ''
        $col_active   = rgb(${activeTheme.colors.amber})
        $col_inactive = rgb(${activeTheme.colors.brown})
        $col_shadow   = rgba(${activeTheme.colors.bg}cc)
      '';

      # Hyprlock colors
      "hypr/hyprlock-colors.conf".text = ''
        $text   = rgb(${activeTheme.colors.text})
        $bg     = rgb(${activeTheme.colors.bg})
        $amber  = rgb(${activeTheme.colors.amber})
        $orange = rgb(${activeTheme.colors.orange})
      '';

      # Waybar colors
      "waybar/colors.css".text = ''
        @define-color bg #${activeTheme.colors.bg};
        @define-color brown #${activeTheme.colors.brown};
        @define-color orange #${activeTheme.colors.orange};
        @define-color amber #${activeTheme.colors.amber};
        @define-color text #${activeTheme.colors.text};
      '';
    };

    # Set wallpaper for active theme
    home.file = {
      ".local/share/wallpapers/current.png".source = activeTheme.wallpaper;
    };
  };
}
