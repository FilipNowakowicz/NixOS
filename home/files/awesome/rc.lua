-- Awesome WM configuration file
local awful = require("awful")
awful.spawn.with_shell("date; echo 'rc.lua: start' >> /tmp/awesome-boot.log")
awful.spawn.with_shell("xsetroot -solid '#303030'")
awful.spawn.with_shell("xmessage -center 'Awesome rc.lua started' &")

-- local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

Global = {
  ConfigFolder = gears.filesystem.get_configuration_dir(),

  Apps = {
    Terminal    = "kitty",
    Browser     = "firefox",
    Filemanager = "nemo",
    Editor      = "nvim",
    Rofi        = "rofi",
    PowerMenu   = "rofi-power-menu",
  },

  Keys = {
    ModKey = "Mod4",
  },
}
-- Error handling
require("hash.errors")

-- Theme and layouts
local naughty = require("naughty")

local ok, err = pcall(function()
  beautiful.init(Global.ConfigFolder .. "theme/theme.lua")
end)

if not ok then
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Theme load failed",
    text = tostring(err),
  })
end

Theme = beautiful
require("awful.autofocus")
require("hash.layouts")

-- Screen setup (tags and wibar)
screen.connect_signal("request::desktop_decoration", function(s)
  awful.tag({ "", "", "", "", "", "", "", "", "", "" }, s, awful.layout.layouts[1])
  require("hash.wibar")(s)
end)

-- Keybindings (Awesome 4.3 style)
local keys = require("hash.keybindings")
local globalkeys, clientkeys, clientbuttons = keys.get()
root.keys(globalkeys)
Global.ClientKeys = clientkeys
Global.ClientButtons = clientbuttons

-- Behaviors
require("hash.signals")
require("hash.rules")
require("hash.wallpaper")
require("hash.startup")
