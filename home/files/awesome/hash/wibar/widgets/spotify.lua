local awful = require("awful")
local watch = require("awful.widget.watch")
local wibox = require("wibox")
local gears = require("gears")

local default_player = "spotify"
local font = Theme.Font

local GET_MPD_CMD =
  "playerctl -p " ..
  default_player ..
  " -f '{{status}};{{xesam:artist}};{{xesam:title}}' metadata"

local player_widget = wibox.widget({
  {
    {
      id     = "song",
      font   = font,
      text   = "",
      align  = "center",
      valign = "center",
      widget = wibox.widget.textbox,
    },
    halign = "center",
    valign = "center",
    widget = wibox.container.place,
    -- if you ever want click-to-open again, uncomment:
    -- buttons = gears.table.join(
    --   awful.button({}, 1, nil, function()
    --     local matcher = function(c)
    --       return awful.rules.match(c, { instance = default_player })
    --     end
    --     awful.client.run_or_raise(default_player, matcher)
    --   end)
    -- ),
  },
  left   = Theme.UniversalSize / 2,
  right  = Theme.UniversalSize / 2,
  widget = wibox.container.margin,

  set_text = function(self, new_text)
    self:get_children_by_id("song")[1]:set_text(new_text)
  end,
})

local function player_updater()
  local update_graphic = function(widget, stdout)
    local fields = gears.string.split(stdout, ";")
    local status = fields[1]
    local artist = fields[2] or ""
    local title  = fields[3] or ""

    -- Nothing playing / player not running
    if not status or status == "" or status == "Stopped" then
      widget:set_text("")
      return
    end

    -- Build display text with context
    local text
    if artist ~= "" then
      text = " " .. artist .. " - " .. title
    else
      text = " " .. title
    end

    -- Truncate long titles so they don't blow up the bar
    local max_len = 50
    if #text > max_len then
      text = text:sub(1, max_len - 3) .. "..."
    end

    widget:set_text(text)
  end

  watch(GET_MPD_CMD, 1, update_graphic, player_widget)

  return player_widget
end

return setmetatable(player_widget, {
  __call = function()
    return player_updater()
  end,
})
