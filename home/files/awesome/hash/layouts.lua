-- Define the available layouts to cycle through

local awful = require("awful")

awful.layout.layouts = {
  awful.layout.suit.tile,
  awful.layout.suit.max,
  awful.layout.suit.spiral,
}
