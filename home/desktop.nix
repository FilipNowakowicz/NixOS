{ pkgs, ... }:
let
  palette = {
    base00 = "#1f2227";
    base01 = "#2e3138";
    base02 = "#4b505b";
    base03 = "#5c6370";
    base04 = "#abb2bf";
    base05 = "#c8cdd6";
    base06 = "#e5e9f0";
    base07 = "#ffffff";
    red = "#e06c75";
    orange = "#d19a66";
    yellow = "#e5c07b";
    green = "#98c379";
    cyan = "#56b6c2";
    blue = "#61afef";
    purple = "#c678dd";
  };
in {
  home.packages = with pkgs; [
    alacritty
    awesome
    feh
    picom
    playerctl
  ];

  xdg.configFile."alacritty/alacritty.toml".text = ''
    live_config_reload = true

    [window]
    padding.x = 6
    padding.y = 4
    dynamic_padding = true
    decorations = "none"

    [font]
    size = 11.0

    [colors.primary]
    background = "${palette.base00}"
    foreground = "${palette.base05}"

    [colors.normal]
    black = "${palette.base00}"
    red = "${palette.red}"
    green = "${palette.green}"
    yellow = "${palette.yellow}"
    blue = "${palette.blue}"
    magenta = "${palette.purple}"
    cyan = "${palette.cyan}"
    white = "${palette.base05}"

    [colors.bright]
    black = "${palette.base02}"
    red = "${palette.red}"
    green = "${palette.green}"
    yellow = "${palette.yellow}"
    blue = "${palette.blue}"
    magenta = "${palette.purple}"
    cyan = "${palette.cyan}"
    white = "${palette.base07}"
  '';

  xdg.configFile."awesome/theme.lua".text = ''
    local gears = require("gears")
    local theme = {}

    theme.font          = "JetBrainsMono Nerd Font 10"
    theme.wallpaper     = os.getenv("HOME") .. "/.config/awesome/wall.png"

    theme.bg_normal     = "${palette.base00}"
    theme.bg_focus      = "${palette.base01}"
    theme.bg_urgent     = "${palette.red}"
    theme.bg_minimize   = "${palette.base02}"

    theme.fg_normal     = "${palette.base05}"
    theme.fg_focus      = "${palette.base07}"
    theme.fg_urgent     = "${palette.base07}"
    theme.fg_minimize   = "${palette.base06}"

    theme.border_width  = 2
    theme.border_normal = "${palette.base02}"
    theme.border_focus  = "${palette.blue}"
    theme.border_marked = "${palette.purple}"

    theme.useless_gap   = 5

    theme.taglist_fg_focus = "${palette.base07}"
    theme.taglist_bg_focus = "${palette.base01}"

    theme.titlebar_bg_focus  = theme.bg_focus
    theme.titlebar_bg_normal = theme.bg_normal

    theme.layout_tile = gears.filesystem.get_themes_dir() .. "default/layouts/tilew.png"
    theme.layout_tileleft = gears.filesystem.get_themes_dir() .. "default/layouts/tileleftw.png"
    theme.layout_tilebottom = gears.filesystem.get_themes_dir() .. "default/layouts/tilebottomw.png"
    theme.layout_tiletop = gears.filesystem.get_themes_dir() .. "default/layouts/tiletopw.png"
    theme.layout_fairv = gears.filesystem.get_themes_dir() .. "default/layouts/fairvw.png"
    theme.layout_fairh = gears.filesystem.get_themes_dir() .. "default/layouts/fairhw.png"
    theme.layout_max = gears.filesystem.get_themes_dir() .. "default/layouts/maxw.png"

    return theme
  '';

  xdg.configFile."awesome/rc.lua".text = ''
    local awful = require("awful")
    local gears = require("gears")
    local beautiful = require("beautiful")
    local naughty = require("naughty")

    local config_dir = gears.filesystem.get_configuration_dir()
    beautiful.init(config_dir .. "theme.lua")

    if awesome.startup_errors then
      naughty.notify({ preset = naughty.config.presets.critical, title = "Oops, errors during startup!", text = awesome.startup_errors })
    end

    local terminal = "alacritty"
    local modkey = "Mod4"

    awful.layout.layouts = {
      awful.layout.suit.tile,
      awful.layout.suit.max,
      awful.layout.suit.floating,
    }

    local function set_wallpaper(s)
      if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        if type(wallpaper) == "function" then
          wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
      end
    end

    screen.connect_signal("property::geometry", set_wallpaper)

    awful.screen.connect_for_each_screen(function(s)
      set_wallpaper(s)
      awful.tag({ "", "", "", "", "" }, s, awful.layout.layouts[1])
    end)

    awful.keyboard.append_global_keybindings({
      awful.key({ modkey }, "Return", function() awful.spawn(terminal) end,
        { description = "open a terminal", group = "launcher" }),
      awful.key({ modkey }, "r", function() awful.spawn("rofi -show run") end,
        { description = "run prompt", group = "launcher" }),
      awful.key({ modkey }, "l", function() awful.spawn("loginctl lock-session") end,
        { description = "lock", group = "session" }),
      awful.key({ modkey, "Shift" }, "r", awesome.restart,
        { description = "reload awesome", group = "awesome" })
    })

    root.buttons(gears.table.join(
      awful.button({}, 3, function() awful.menu.clients({ theme = { width = 260 } }) end)
    ))
  '';
}
