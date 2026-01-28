local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local function wifi_icon(signal, enabled)
  if not enabled then
    return "󰤮"
  end

  if signal and signal >= 75 then
    return "󰤨"
  elseif signal and signal >= 50 then
    return "󰤥"
  elseif signal and signal >= 25 then
    return "󰤢"
  elseif signal then
    return "󰤟"
  else
    return "󰤯"
  end
end

local function get_widget(s)
  local current_enabled = false
  local current_ssid
  local current_signal
  local network_menu
  local hide_timer
  local hovering = false
  local show_weaker = false
  local last_anchor

  local widget = wibox.widget({
    {
      {
        id     = "wifi_text",
        font   = Theme.Font,
        align  = "center",
        valign = "center",
        text   = "󰤮",
        widget = wibox.widget.textbox,
      },
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    left   = Theme.Spacing,
    right  = Theme.Spacing,
    widget = wibox.container.margin,

    set_icon = function(self, new_icon)
      self:get_children_by_id("wifi_text")[1]:set_text(new_icon)
    end,
  })

  local function refresh_status()
    awful.spawn.easy_async_with_shell([[bash -c '
      wifi_state=$(nmcli -t -f WIFI general status 2>/dev/null | head -n1)
      active_line=$(nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list --rescan no 2>/dev/null | grep "^yes:" | head -n1)

      active_ssid=$(echo "$active_line" | cut -d: -f2)
      active_signal=$(echo "$active_line" | cut -d: -f3)

      echo "$wifi_state|${active_ssid:-}|${active_signal:-}"
    ']], function(stdout)
      local state, ssid, signal_str = stdout:match("^(.-)|(.-)|(.*)%s*$")
      local signal = tonumber(signal_str)

      current_enabled = state == "enabled"
      current_ssid = ssid ~= "" and ssid or nil
      current_signal = signal
      widget:set_icon(wifi_icon(signal, current_enabled))
    end)
  end

  local function toggle_wifi()
    local cmd = current_enabled and "nmcli radio wifi off" or "nmcli radio wifi on"
    awful.spawn.easy_async_with_shell(cmd, function()
      gears.timer.start_new(1, function()
        refresh_status()
        return false
      end)
    end)
  end

  local function connect_to_network(ssid)
    if not ssid or ssid == "" then
      return
    end

    awful.spawn.easy_async_with_shell(string.format("nmcli radio wifi on && nmcli device wifi connect %q", ssid), function()
      refresh_status()
    end)
  end

  local function ensure_menu()
    if network_menu then
      return
    end

    network_menu = awful.popup({
      screen = s,
      ontop = true,
      visible = false,
      bg = Theme.Colors.Background.Darkest .. "f2",
      fg = Theme.Colors.Foreground.Normal,
      shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, Theme.UniversalSize / 4) end,
      border_color = Theme.Colors.Background.Lighter,
      border_width = Theme.border_width / 2,
      widget = wibox.widget.textbox(" "),
    })

    network_menu:connect_signal("mouse::enter", function()
      if hide_timer then
        hide_timer:stop()
        hide_timer = nil
      end
    end)

    network_menu:connect_signal("mouse::leave", function()
      if hide_timer then
        hide_timer:stop()
        hide_timer = nil
      end

      hide_timer = gears.timer.start_new(0.25, function()
        if network_menu then
          network_menu.visible = false
        end
        return false
      end)
    end)
  end

  local function position_menu(anchor)
    if not network_menu or not anchor then
      return
    end

    last_anchor = anchor

    local anchor_geo = {
      x = anchor.x,
      y = anchor.y + (anchor.height or Theme.UniversalSize),
      width = anchor.width or Theme.UniversalSize,
      height = anchor.height or Theme.UniversalSize,
    }

    awful.placement.next_to(network_menu, {
      preferred_positions = { "bottom" },
      preferred_anchors = { "middle" },
      geometry = anchor_geo,
      margins = { bottom = Theme.Spacing / 2 },
      honor_workarea = true,
    })

    network_menu.screen = s
  end

  local function row(text, icon, signal, callback)
    local content = {
      layout = wibox.layout.align.horizontal,
      expand = "inside",
      {
        text = icon or "",
        font = Theme.Font,
        align = "center",
        valign = "center",
        widget = wibox.widget.textbox,
      },
      {
        text = text,
        font = Theme.Font,
        align = "left",
        valign = "center",
        widget = wibox.widget.textbox,
      },
      {
        text = signal and string.format("%d%%", signal) or "",
        font = Theme.Font,
        align = "right",
        valign = "center",
        widget = wibox.widget.textbox,
      },
    }

    local container = wibox.widget({
      {
        content,
        margins = Theme.Spacing,
        widget = wibox.container.margin,
      },
      bg = Theme.Colors.Background.Dark .. "e6",
      widget = wibox.container.background,
    })

    container:connect_signal("mouse::enter", function()
      container.bg = Theme.Colors.Background.Light .. "dd"
    end)

    container:connect_signal("mouse::leave", function()
      container.bg = Theme.Colors.Background.Dark .. "e6"
    end)

    if callback then
      container:buttons(gears.table.join(
        awful.button({}, 1, callback)
      ))
    end

    return container
  end

  local function build_menu(anchor, networks)
    local layout = wibox.layout.fixed.vertical()

    local strong = {}
    local weak = {}

    for _, data in ipairs(networks) do
      if data.signal and data.signal < 65 then
        table.insert(weak, data)
      else
        table.insert(strong, data)
      end
    end

    local status_text
    if not current_enabled then
      status_text = "Wi-Fi is off (click icon to enable)"
    elseif current_ssid then
      status_text = string.format("Connected to %s", current_ssid)
    else
      status_text = "Not connected"
    end

    layout:add(row(status_text, wifi_icon(current_signal, current_enabled)))
    layout:add(wibox.widget({
      forced_height = Theme.border_width,
      color = Theme.Colors.Background.Lighter,
      widget = wibox.widget.separator,
    }))

    if not current_enabled then
      layout:add(row("Hover again after enabling", nil))
    elseif #networks == 0 then
      layout:add(row("No networks found", nil))
    else
      local function add_networks(list)
        for _, data in ipairs(list) do
          layout:add(row(data.ssid, wifi_icon(data.signal, true), data.signal, function()
            connect_to_network(data.raw_ssid)
          end))
        end
      end

      add_networks(strong)

      if #weak > 0 then
        layout:add(wibox.widget({
          forced_height = Theme.border_width,
          color = Theme.Colors.Background.Lighter,
          widget = wibox.widget.separator,
        }))

        local toggle_text = show_weaker and "Hide other networks" or "Other networks"

        layout:add(row(toggle_text, nil, nil, function()
          show_weaker = not show_weaker
          build_menu(anchor or last_anchor, networks)
        end))

        if show_weaker then
          add_networks(weak)
        end
      end
    end

    local menu_visible = network_menu and network_menu.visible

    if not (hovering or menu_visible) then
      return
    end

    network_menu.widget = wibox.widget({
      layout,
      forced_width = 220,
      margins = Theme.Spacing / 1.2,
      widget = wibox.container.margin,
    })

    position_menu(anchor or last_anchor)
    network_menu.visible = true
  end

  local function show_network_menu()
    ensure_menu()

    local anchor
    local geo = mouse.current_widget_geometry

    if geo and geo.x and geo.y then
      anchor = {
        x = geo.x,
        y = geo.y,
        width = (geo.width and geo.width > 0) and geo.width or Theme.UniversalSize,
        height = (geo.height and geo.height > 0) and geo.height or Theme.UniversalSize,
      }
    elseif last_anchor then
      anchor = last_anchor
    else
      local coords = mouse.coords()
      anchor = {
        x = coords.x - Theme.UniversalSize / 2,
        y = coords.y,
        width = Theme.UniversalSize,
        height = Theme.UniversalSize,
      }
    end

    if not current_enabled then
      build_menu(anchor, {})
      return
    end

    if not hovering then
      return
    end

    network_menu.widget = wibox.widget({
      {
        {
          text = "Scanning…",
          font = Theme.Font,
          align = "center",
          valign = "center",
          widget = wibox.widget.textbox,
        },
        margins = Theme.Spacing,
        widget = wibox.container.margin,
      },
      forced_width = 220,
      widget = wibox.container.background,
    })
    position_menu(anchor)
    network_menu.visible = true

    awful.spawn.easy_async_with_shell([[nmcli -t -f IN-USE,SSID,SIGNAL device wifi list --rescan no 2>/dev/null]], function(stdout)
      local strongest_by_ssid = {}
      local ordered = {}

      for line in stdout:gmatch("[^\n]+") do
        local in_use, ssid, signal = line:match("^([^:]*):([^:]*):([^:]*)")
        if ssid then
          local cleaned = ssid ~= "" and ssid or "<hidden>"
          local strength = tonumber(signal) or 0
          local active = in_use == "*" or in_use == "yes"

          local existing = strongest_by_ssid[cleaned]
          if not existing or strength > existing.signal or active then
            strongest_by_ssid[cleaned] = {
              ssid = cleaned,
              raw_ssid = ssid,
              signal = strength,
              active = active,
            }
          end
        end
      end

      for _, data in pairs(strongest_by_ssid) do
        table.insert(ordered, data)
      end

      table.sort(ordered, function(a, b)
        return a.signal > b.signal
      end)

      build_menu(anchor, ordered)
    end)
  end

  widget:buttons(gears.table.join(
    awful.button({}, 1, function()
      toggle_wifi()
    end)
  ))

  widget:connect_signal("mouse::enter", function()
    if hide_timer then
      hide_timer:stop()
      hide_timer = nil
    end

    hovering = true
    show_network_menu()
  end)

  widget:connect_signal("mouse::leave", function()
    if hide_timer then
      hide_timer:stop()
      hide_timer = nil
    end

    hovering = false
    show_weaker = false
    hide_timer = gears.timer.start_new(0.25, function()
      if network_menu then
        network_menu.visible = false
      end
      return false
    end)
  end)

  gears.timer({
    timeout   = 10,
    autostart = true,
    call_now  = true,
    callback  = refresh_status,
  })

  return widget
end

return get_widget
