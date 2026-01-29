local awful = require("awful")

-- Awesome 4.3 rules (no `ruled`)
awful.rules.rules = {
  -- Global rules for all clients
  {
    rule = {},
    properties = {
      focus             = awful.client.focus.filter,
      raise             = true,
      titlebars_enabled = false,
      screen            = awful.screen.preferred,
      placement         = awful.placement.no_overlap + awful.placement.no_offscreen,
    },
  },

  -- All normal windows: tile, never start maximised/fullscreen/floating
  {
    rule_any = { type = { "normal" } },
    properties = {
      floating   = false,
      fullscreen = false,
      maximized  = false,
      maximized_vertical = false,
      maximized_horizontal = false,
    },
  },

  -- Chromium and friends: force-disable start maximised
  {
    rule_any = {
      class = { "Chromium", "Google-chrome", "Brave-browser" },
    },
    properties = {
      floating = false,
      fullscreen = false,
      maximized = false,
      maximized_vertical = false,
      maximized_horizontal = false,
    },
    callback = function(c)
      c.fullscreen = false
      c.maximized = false
      c.maximized_vertical = false
      c.maximized_horizontal = false
    end,
  },
}

-- Extra safety: Chromium sometimes re-asserts maximised after mapping
client.connect_signal("property::maximized", function(c)
  if c.class == "Chromium"
    or c.class == "Google-chrome"
    or c.class == "Brave-browser"
  then
    c.maximized = false
    c.maximized_vertical = false
    c.maximized_horizontal = false
  end
end)
