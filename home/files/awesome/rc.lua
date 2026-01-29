-- Awesome WM configuration file

-- Standard libraries
local awful = require("awful")
local beautiful = require("beautiful")

-- Global variables
Global = {
  ConfigFolder = awful.util.get_configuration_dir(),

  Apps = {
    Terminal    = "kitty",
    Browser     = "firefox",
    Filemanager = "nemo",
    Editor      = "nvim",
    Rofi        = "rofi",
    PowerMenu   = "rofi-power-menu",
  },

  Keys = {
    ModKey      = "Mod4",
  },
}

-- Error handling
require("hash.errors")

-- Theme and layouts
beautiful.init(Global.ConfigFolder .. "theme/theme.lua")
-- Expose the loaded theme table so widgets using Theme can access it
Theme = beautiful.get()
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
