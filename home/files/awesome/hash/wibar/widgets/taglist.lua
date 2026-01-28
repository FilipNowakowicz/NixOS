local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local font                  = Theme.Font_Name .. " " .. tostring(Theme.UniversalSize * (1 / 2))
local outer_margin_width    = Theme.UniversalSize * (1 / 4)
local inner_margin_width    = Theme.UniversalSize * (1 / 8)
local outer_margin_vertical = 0

local icon_inactive_empty   = ""
local icon_inactive_single  = ""
local icon_inactive_many    = ""
local icon_selected         = ""

local get_taglist = function(s)
  -- Update icons and inner margin per-tag without recursively firing signals
  local update_tags = function(self, t)
    local tagicon = self:get_children_by_id("icon_role")[1]
    local inner   = self:get_children_by_id("inner_margin")[1]

    local single_tag = (#s.tags == 1)
    local desired_margin = single_tag and 0 or inner_margin_width

    if inner.left ~= desired_margin then
      inner.left = desired_margin
    end

    if inner.right ~= desired_margin then
      inner.right = desired_margin
    end

    local new_text

    if single_tag then
      new_text = ""
    elseif t.selected then
      new_text = icon_selected
    else
      local clients = t:clients()
      if #clients == 0 then
        new_text = icon_inactive_empty
      elseif #clients == 1 then
        new_text = icon_inactive_single
      else
        new_text = icon_inactive_many
      end
    end

    if new_text and tagicon.text ~= new_text then
      tagicon.text = new_text
    end
  end

  local icon_taglist = wibox.widget({
    awful.widget.taglist({
      screen = s,
      buttons = {},
      filter  = awful.widget.taglist.filter.all,
      layout  = {
        layout = wibox.layout.fixed.horizontal,
      },
      widget_template = {
        {
          id     = "icon_role",
          font   = font,
          text   = icon_inactive_empty,
          widget = wibox.widget.textbox,
        },
        id     = "inner_margin",
        left   = #s.tags == 1 and 0 or inner_margin_width,
        right  = #s.tags == 1 and 0 or inner_margin_width,
        widget = wibox.container.margin,

        create_callback = function(self, t)
          update_tags(self, t)
        end,

        update_callback = function(self, t)
          update_tags(self, t)
        end,
      },
    }),
    id     = "outer_margin",
    left   = #s.tags == 1 and 0 or outer_margin_width,
    right  = #s.tags == 1 and 0 or outer_margin_width,
    top    = #s.tags == 1 and 0 or outer_margin_vertical,
    bottom = #s.tags == 1 and 0 or outer_margin_vertical,
    widget = wibox.container.margin,
  })

  return icon_taglist
end

return get_taglist
