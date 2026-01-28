local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local function volume_icon_for_level(level)
  if not level then
    return "󰕾"
  end

  if level == 0 then
    return "󰝟"
  elseif level < 35 then
    return "󰕿"
  elseif level < 70 then
    return "󰖀"
  else
    return "󰕾"
  end
end

local function get_volume_widget()
  local icon_widget = wibox.widget {
    {
      {
        id     = "icon_text",
        font   = Theme.Font,
        align  = "center",
        valign = "center",
        text   = "󰕾",
        widget = wibox.widget.textbox,
      },
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    left   = Theme.Spacing,
    right  = Theme.Spacing,
    widget = wibox.container.margin,
  }

  local function set_icon(level)
    icon_widget:get_children_by_id("icon_text")[1]:set_text(volume_icon_for_level(level))
  end

  local function refresh_volume()
    awful.spawn.easy_async_with_shell(
      "pactl get-sink-volume @DEFAULT_SINK@",
      function(stdout)
        local percent = stdout:match("(%d+)%%")
        set_icon(tonumber(percent))
      end
    )
  end

  gears.timer {
    timeout   = 5,
    autostart = true,
    call_now  = true,
    callback  = refresh_volume,
  }

  awesome.connect_signal("widget::volume_refresh", refresh_volume)

  return icon_widget
end

return get_volume_widget
