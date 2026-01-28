local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")

local function get_wibar(s)

  local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(value, max_value))
  end

  local rounding = Theme.UniversalSize / 2.4
  local glass_bg = Theme.Colors.Background.Darkest .. "cc"
  local glass_border = Theme.Colors.Background.Lighter .. "80"
  local segment_padding_h = Theme.Spacing * 0.45
  local segment_padding_v = Theme.Spacing / 8
  local bar_padding = Theme.Spacing / 12
  local margin_size = clamp(Theme.useless_gap * 0.20, 2, 10)
  local bar_margins = {
    top = margin_size / 2,
    bottom = margin_size / 2,
    left = margin_size,
    right = margin_size,
  }

  local bar_height = clamp(Theme.Font_Size * 1.6, 22, 32)

  local function pill_shape(cr, w, h)
    gears.shape.rounded_rect(cr, w, h, rounding)
  end

  local function glassy_container(widget, bg_color)
    return {
      {
        widget,
        left = segment_padding_h,
        right = segment_padding_h,
        top = segment_padding_v,
        bottom = segment_padding_v,
        widget = wibox.container.margin,
      },
      bg = bg_color,
      shape = pill_shape,
      border_width = Theme.border_width / 4,
      border_color = glass_border,
      widget = wibox.container.background,
    }
  end

  local function animate_visibility(target, should_show)
    local duration = 0.6
    local steps = 24
    local step_time = duration / steps

    if target._visibility_timer then
      target._visibility_timer:stop()
      target._visibility_timer = nil
    end

    if not should_show then
      target.opacity = 0
      target.visible = false
      return
    end

    local start = target.opacity or (target.visible and 1 or 0)
    local goal = 1
    local delta = goal - start

    target.visible = true

    target._visibility_timer = gears.timer {
      timeout = step_time,
      autostart = true,
      call_now = true,
      callback = function()
        start = start + (delta / steps)
        target.opacity = clamp(start, 0, 1)

        if target.opacity >= 0.99 then
          target.opacity = 1
          target._visibility_timer:stop()
          target._visibility_timer = nil
        end
      end,
    }
  end

  s.wibox = awful.wibar({
    position = "top",
    screen = s,
    height = bar_height,
    bg = "#00000000",
    border_width = 0,
    margins = bar_margins,
    opacity = 0.95,
  })

  s.wibox:setup {
    {
      layout = wibox.layout.align.horizontal,

      {
        layout = wibox.layout.fixed.horizontal,
        spacing = Theme.Spacing / 3,
        glassy_container(
          require("hash.wibar.widgets.taglist")(s),
          Theme.Colors.Background.Neutral .. "cc"
        ),
      },

      nil,

      {
        layout = wibox.layout.fixed.horizontal,
        spacing = Theme.Spacing / 3,

        glassy_container(
          require("hash.wibar.widgets.spotify")(s),
          Theme.Colors.Background.Darkest .. "d0"
        ),

        glassy_container(
          require("hash.wibar.widgets.wifi")(s),
          Theme.Colors.Background.Darkest .. "d0"
        ),

        glassy_container(
          require("hash.wibar.widgets.volume")(s),
          Theme.Colors.Background.Darkest .. "d0"
        ),

        (function()
          local battery_widget = require("hash.wibar.widgets.battery")(s)
          local battery_container = wibox.widget(glassy_container(
            battery_widget,
            Theme.Colors.Background.Darkest .. "d0"
          ))

          battery_container.opacity = 1

          battery_widget:connect_signal("battery::visibility", function(_, visible)
            animate_visibility(battery_container, visible)
          end)

          return battery_container
        end)(),

        glassy_container(
          require("hash.wibar.widgets.clock")(s),
          Theme.Colors.Background.Darkest .. "d0"
        ),
      },
    },
    left   = bar_padding,
    right  = bar_padding,
    top    = bar_padding,
    bottom = bar_padding,
    widget = wibox.container.margin,
  }
end
--------------------------------------------------------------------------------
return get_wibar
--------------------------------------------------------------------------------
