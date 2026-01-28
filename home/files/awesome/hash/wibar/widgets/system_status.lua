local awful = require("awful")
local wibox = require("wibox")

local poll_interval = 12

local function trim(text)
  return (text or ""):gsub("%s+$", ""):gsub("^%s+", "")
end

local function indicator(icon)
  local value = wibox.widget.textbox("--")

  local widget = wibox.widget {
    {
      markup = icon,
      widget = wibox.widget.textbox,
    },
    value,
    spacing = Theme.Spacing / 6,
    layout = wibox.layout.fixed.horizontal,
  }

  return widget, value
end

local function watch_value(cmd, interval, setter)
  awful.widget.watch(cmd, interval, function(_, stdout)
    setter(trim(stdout or ""))
  end)
end

local function get_widget()
  local vol_widget, vol_value = indicator("󰕾")
  local wifi_widget, wifi_value = indicator("󰖩")
  local bt_widget, bt_value = indicator("󰂯")
  local brightness_widget, brightness_value = indicator("󰃠")
  local battery_widget, battery_value = indicator("󰁹")

  watch_value(
    [[bash -c "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2, $3}'"]],
    poll_interval,
    function(output)
      local level, muted = output:match("([%d%.]+)%s*([%[%]A-Z]*)")
      local pct = level and math.floor(tonumber(level) * 100 + 0.5)
      local text = (muted == "[MUTED]") and "--" or (pct and tostring(pct) or "--")
      if text ~= vol_value.text then vol_value.text = text end
    end
  )

  watch_value(
    [[bash -c "nmcli -t -f active,ssid dev wifi | awk -F: '/^yes:/{print $2; exit}'"]],
    poll_interval,
    function(ssid)
      local text = (ssid ~= "" and ssid) or "Off"
      if text ~= wifi_value.text then wifi_value.text = text end
    end
  )

  watch_value(
    [[bash -c "bluetoothctl show | awk '/Powered:/{print $2}'"]],
    poll_interval,
    function(state)
      local text = (state == "yes") and "On" or "Off"
      if text ~= bt_value.text then bt_value.text = text end
    end
  )

  watch_value(
    [[bash -c 'curr=$(brightnessctl g 2>/dev/null); max=$(brightnessctl m 2>/dev/null);
if [ -n "$max" ] && [ "$max" -ne 0 ]; then printf "%d" $((curr*100/max)); fi']],
    poll_interval,
    function(pct)
      local text = (pct ~= "" and pct .. "%") or "--"
      if text ~= brightness_value.text then brightness_value.text = text end
    end
  )

  watch_value(
    [[bash -c "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1"]],
    poll_interval,
    function(level)
      local text = (level ~= "" and level .. "%") or "--"
      if text ~= battery_value.text then battery_value.text = text end
    end
  )

  return wibox.widget {
    layout = wibox.layout.fixed.horizontal,
    spacing = Theme.Spacing * 0.4,
    vol_widget,
    wifi_widget,
    bt_widget,
    brightness_widget,
    battery_widget,
  }
end

return get_widget
