-- Awesome WM configuration file

-- Standard libraries
local awful = require("awful")
local beautiful = require("beautiful")

-- Global variables
Global = {
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

Global.ConfigFolder = awful.util.getdir("config")

-- Error handling
require("hash.errors")

-- Theme and layouts
beautiful.init(Global.ConfigFolder .. "/theme/theme.lua")
-- Expose the loaded theme table so widgets using Theme can access it
Theme = beautiful.get()
require("awful.autofocus")
require("hash.layouts")

-- Screen setup (tags and wibar)
screen.connect_signal("request::desktop_decoration", function(s)
  awful.tag({ "", "", "", "", "", "", "", "", "", "" }, s, awful.layout.layouts[1])
  require("hash.wibar")(s)
end)

-- Behaviors
require("hash.signals")
require("hash.rules")
require("hash.keybindings")
require("hash.wallpaper")
require("hash.startup")
