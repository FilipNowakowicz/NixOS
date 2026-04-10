{ pkgs, lib, themeDir ? ./. }:
let
  # Import active theme for fallback/default
  activeTheme = import (themeDir + /active.nix);

  # Auto-discover all theme files
  themeFilesDir = themeDir + /themes;
  themeFiles = builtins.readDir themeFilesDir;

  # Load and validate each theme
  allThemes = lib.mapAttrs' (name: _:
    let
      themePath = themeFilesDir + "/${name}";
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
  inherit themeConfigs activeThemeName colors;
  activeTheme = activeTheme;
}
