local wibox = require("wibox")

local get_clock = function(_, --[[optional]] color)
  local clock = wibox.widget({
    {
      {
        {
          widget = wibox.widget.textclock,
          format = "%a %H:%M",
          font   = Theme.Font,
          align  = "center",
          valign = "center",
        },
        halign = "center",
        valign = "center",
        widget = wibox.container.place,
      },
      left   = Theme.Spacing,
      right  = Theme.Spacing,
      widget = wibox.container.margin,
    },
    bg     = color or Theme.Colors.Background.Darkest,
    widget = wibox.container.background,
  })

  return clock
end

return get_clock
