local awful = require("awful")
local wibox = require("wibox")

local function get_widget()
  local widget = wibox.widget({
    {
      {
        id     = "battery_text",
        font   = Theme.Font,
        align  = "center",
        valign = "center",
        markup = "󰁹 --%",
        widget = wibox.widget.textbox,
      },
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    left   = Theme.Spacing,
    right  = Theme.Spacing,
    widget = wibox.container.margin,

    set_text = function(self, new_text)
      self:get_children_by_id("battery_text")[1]:set_markup(new_text)
    end,
  })

  awful.widget.watch(
    [[bash -c '
      status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
      capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)

      online=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -n1)
      [ -z "$online" ] && online=$(cat /sys/class/power_supply/ACAD*/online 2>/dev/null | head -n1)
      [ -z "$online" ] && online=$(cat /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1)

      echo "$status|$capacity|$online"
    ']],
    15,
    function(self, stdout)
      local status, level_str, online_str = stdout:match("^(.-)|(%d+)|(%d*)%s*$")
      local level = tonumber(level_str)
      local online = tonumber(online_str) or 0

      local icon
      if status == "Charging" or status == "Full" or status == "Not charging" or online == 1 then
        icon = "󰂄"
      elseif level and level >= 75 then
        icon = "󰁹"
      elseif level and level >= 45 then
        icon = "󰂀"
      elseif level and level >= 20 then
        icon = "󰁻"
      else
        icon = "󰁺"
      end

      local color = Theme.Colors.Foreground.Normal
      if status ~= "Charging" and level and level < 20 then
        color = Theme.Colors.Foreground.Urgent
      end

      local text
      if level then
        text = string.format('<span color="%s">%s %d%%</span>', color, icon, level)
      else
        text = string.format('<span color="%s">%s --%%</span>', color, icon)
      end

      widget:set_text(text)

      local is_fullish = level and level >= 99
      local is_plugged = online == 1 or status == "Charging" or status == "Full" or status == "Not charging"
      local should_show = not (is_fullish and is_plugged)
      if widget.visible ~= should_show then
        widget.visible = should_show
        widget:emit_signal("battery::visibility", should_show)
      end
    end,
    widget
  )

  return widget
end

return get_widget
