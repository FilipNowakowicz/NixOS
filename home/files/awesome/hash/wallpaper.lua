local awful = require("awful")
local gears = require("gears")

local function set_wallpaper(s)
  if Theme.Wallpaper and Theme.Wallpaper ~= "" then
    gears.wallpaper.maximized(Theme.Wallpaper, s, true)
  else
    gears.wallpaper.set("#303030")
  end
end

awful.screen.connect_for_each_screen(set_wallpaper)
screen.connect_signal("property::geometry", set_wallpaper)
