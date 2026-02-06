local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")     -- round edges
local capi  = { client = client }

-- Small radius for minimal rounding
local corner_radius = 4

-- Helper to apply/remove rounding based on border width / state
local function update_client_shape(c)
  if c.maximized or c.fullscreen or c.border_width == 0 then
    c.shape = gears.shape.rectangle
  else
    c.shape = function(cr, w, h)
      gears.shape.rounded_rect(cr, w, h, corner_radius)
    end
  end
end

-- New client handler: prevent off-screen windows on startup
client.connect_signal("manage", function(c)
  -- Prevent off-screen windows on startup
  if awesome.startup
     and not c.size_hints.user_position
     and not c.size_hints.program_position then
    awful.placement.no_offscreen(c)
  end

  -- New windows should NOT become master
  if not awesome.startup then
    awful.client.setslave(c)
  end

  -- Apply initial shape when a client appears
  update_client_shape(c)
end)

-- Sloppy focus
client.connect_signal("mouse::enter", function(c)
  if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
     and awful.client.focus.filter(c) then
    client.focus = c
  end
end)

-- Border colour on focus/unfocus
client.connect_signal("focus",   function(c) c.border_color = Theme.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = Theme.border_normal end)

-- Border width + floating rules + ontop behaviour
for s = 1, screen.count() do
  screen[s]:connect_signal("arrange", function()
    local clients = awful.client.visible(s)
    local layout  = awful.layout.getname(awful.layout.get(s))

    for _, c in pairs(clients) do
      c.ontop = false

      if c.maximized or c.fullscreen then
        c.border_width = 0

      elseif c.floating or layout == "floating" then
        c.border_width = Theme.border_width
        c.ontop = true

      elseif layout == "max" or layout == "fullscreen" then
        c.border_width = 0

      else
        local tiled = awful.client.tiled(c.screen)
        if #tiled == 1 then
          c.border_width = 0
        else
          c.border_width = Theme.border_width
        end
      end

      -- UPDATED: keep shape in sync with border/state
      update_client_shape(c)
    end
  end)
end

-- Also react to explicit property changes
client.connect_signal("property::maximized", update_client_shape)
client.connect_signal("property::fullscreen", update_client_shape)
client.connect_signal("property::border_width", update_client_shape)

-- Show/hide titlebars based on c.tilebars_enabled
client.connect_signal("property::tilebars_enabled", function(c)
  if c.tilebars_enabled then awful.titlebar.show(c)
  else awful.titlebar.hide(c) end
end)

-- Titlebar text widget
local instances = {}

local function update_on_signal(c, signal, widget)
  local sig_instances = instances[signal]
  if not sig_instances then
    sig_instances = setmetatable({}, { __mode = "k" })
    instances[signal] = sig_instances

    capi.client.connect_signal(signal, function(cl)
      local widgets = sig_instances[cl]
      if widgets then
        for _, w in pairs(widgets) do w.update() end
      end
    end)
  end

  local widgets = sig_instances[c]
  if not widgets then
    widgets = setmetatable({}, { __mode = "v" })
    sig_instances[c] = widgets
  end

  table.insert(widgets, widget)
end

local function draw_title(self, ctx, cr, width, height)
  wibox.widget.textbox.draw(self, ctx, cr, width, height)
end

local function titlebar_text(c)
  local ret = wibox.widget.textbox()
  rawset(ret, "draw", draw_title)

  local function update()
    ret:set_text(c.name:lower())
  end

  ret.update = update
  update_on_signal(c, "property::name", ret)
  update()

  return ret
end

-- Titlebar creation
client.connect_signal("request::titlebars", function(c)
  local buttons = {
    awful.button({}, 1, function()
      client.focus = c
      c:raise()
      awful.mouse.client.move(c)
    end),
    awful.button({}, 3, function()
      client.focus = c
      c:raise()
      awful.mouse.client.resize(c)
    end),
  }

  awful.titlebar(c).widget = {
    {
      halign = "center",
      widget = titlebar_text(c),
    },
    buttons = buttons,
    layout  = wibox.layout.flex.horizontal,
  }
end)
