local wibox       = require("wibox")

local get_systray = function(s)
  local systray = wibox.widget
     {
       wibox.widget.systray(),
       left   = Theme.Spacing,
       right  = Theme.Spacing,
       top    = Theme.Spacing / 2,
       bottom = Theme.Spacing / 2,
       widget = wibox.container.margin,
     }
  return systray
end

return get_systray
