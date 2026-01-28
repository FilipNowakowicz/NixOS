-- Define the available layouts to cycle through

local awful = require("awful")

tag.connect_signal("request::default_layouts", function()
  awful.layout.append_default_layouts({
    awful.layout.suit.tile,
    awful.layout.suit.spiral,
    awful.layout.suit.max,
  })
end)
