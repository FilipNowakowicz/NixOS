-- Awesome WM configuration file

-- Debug markers (remove later)
local awful = require("awful")
awful.spawn.with_shell("date; echo 'rc.lua: start' >> /tmp/awesome-boot.log")
awful.spawn.with_shell("xsetroot -solid '#303030'")
awful.spawn.with_shell("xmessage -center 'Awesome rc.lua started' &")

-- Standard libs
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")

-- Global variables
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

-- Make requires fail loudly (so we don’t get a “black screen”)
local function safe(name)
  local ok, mod = pcall(require, name)
  if not ok then
    naughty.notify({
      preset = naughty.config.presets.critical,
      title = "require failed: " .. name,
      text = tostring(mod),
    })
    return nil
  end
  return mod
end

-- Error handling
safe("hash.errors")

-- Theme (non-fatal)
do
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
end

Theme = beautiful

-- Layouts/autofocus
safe("awful.autofocus")
safe("hash.layouts")

-- Keybindings (Awesome 4.3 style)
do
  local keys = safe("hash.keybindings")
  if keys and keys.get then
    local globalkeys, clientkeys, clientbuttons = keys.get()
    root.keys(globalkeys)
    Global.ClientKeys = clientkeys
    Global.ClientButtons = clientbuttons
  else
    naughty.notify({
      preset = naughty.config.presets.critical,
      title = "keybindings missing",
      text = "hash.keybindings did not return a module with .get()",
    })
  end
end

-- Screen setup (tags and wibar)
screen.connect_signal("request::desktop_decoration", function(s)
  awful.tag({ "", "", "", "", "", "", "", "", "", "" }, s, awful.layout.layouts[1])

  local wibar = safe("hash.wibar")
  if wibar then wibar(s) end
end)

-- Behaviors
safe("hash.signals")
safe("hash.rules")
safe("hash.wallpaper")
safe("hash.startup")
