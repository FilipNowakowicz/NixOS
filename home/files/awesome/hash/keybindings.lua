local awful = require("awful")
local utils = require("hash.utils")
local focus_wrap = require("helpers.focus_wrap")

-- Global keybindings
awful.keyboard.append_global_keybindings({
  -- Layout adjustments
  awful.key(
    { Global.Keys.ModKey, "Control" },
    "l",
    function() awful.tag.incmwfact(0.05) end,
    { description = "increase master width", group = "layout" }
  ),
  awful.key(
    { Global.Keys.ModKey, "Control" },
    "h",
    function() awful.tag.incmwfact(-0.05) end,
    { description = "decrease master width", group = "layout" }
  ),

  -- Awesome
  awful.key(
    { Global.Keys.ModKey, "Control" },
    "r",
    awesome.restart,
    { description = "reload Awesome", group = "awesome" }
  ),
  awful.key(
    { Global.Keys.ModKey },
    "w",
    function()
      local bar = awful.screen.focused().wibox
      bar.visible = not bar.visible
    end,
    { description = "toggle wibar", group = "awesome" }
  ),

  -- Tag cycle
  awful.key(
    { Global.Keys.ModKey },
    "Tab",
    awful.tag.viewnext,
    { description = "view next tag", group = "tag" }
  ),
  awful.key(
    { Global.Keys.ModKey, "Shift" },
    "Tab",
    awful.tag.viewprev,
    { description = "view previous tag", group = "tag" }
  ),

  -- Layout cycle
  awful.key(
    { Global.Keys.ModKey, "Control" },
    "j",
    function() awful.layout.inc(1) end,
    { description = "select next layout", group = "layout" }
  ),
  awful.key(
    { Global.Keys.ModKey, "Control" },
    "k",
    function() awful.layout.inc(-1) end,
    { description = "select previous layout", group = "layout" }
  ),

  -- Launchers
  awful.key(
    { Global.Keys.ModKey },
    "Return",
    function() awful.spawn(Global.Apps.Terminal) end,
    { description = "open terminal", group = "launcher" }
  ),
  awful.key(
    { Global.Keys.ModKey },
    "r",
    function() awful.spawn("rofi -show run") end,
    { description = "rofi run menu", group = "launcher" }
  ),
  awful.key(
    { Global.Keys.ModKey },
    "b",
    function() awful.spawn(Global.Apps.Browser) end,
    { description = "open browser", group = "launcher" }
  ),
  awful.key(
    { Global.Keys.ModKey },
    "e",
    function()
      awful.spawn(string.format("%s -e %s", Global.Apps.Terminal, Global.Apps.Filemanager))
    end,
    { description = "open file manager in terminal", group = "launcher" }
  ),

  -- Rofi
  awful.key(
    { Global.Keys.ModKey },
    "Escape",
    function()
      awful.spawn(string.format(
        "%s -show power-menu -modi power-menu:%s",
        Global.Apps.Rofi,
        Global.Apps.PowerMenu
      ))
    end,
    { description = "power menu", group = "launcher" }
  ),

  -- Screenshot
  awful.key(
    { Global.Keys.ModKey, "Control" },
    "p",
    function() awful.spawn("flameshot gui") end,
    { description = "flameshot gui", group = "utility" }
  ),

  -- Media
  awful.key(
    {},
    "XF86AudioRaiseVolume",
    function()
      awful.spawn("pactl set-sink-volume 0 +3%")
      utils.show_volume_notification()
    end,
    { description = "raise volume", group = "media" }
  ),
  awful.key(
    {},
    "XF86AudioLowerVolume",
    function()
      awful.spawn("pactl set-sink-volume 0 -3%")
      utils.show_volume_notification()
    end,
    { description = "lower volume", group = "media" }
  ),
  awful.key(
    {},
    "XF86AudioMute",
    function()
      awful.spawn("pactl set-sink-mute 0 toggle")
      utils.show_volume_notification()
    end,
    { description = "toggle mute", group = "media" }
  ),
  awful.key(
    {},
    "XF86AudioPlay",
    function() awful.spawn("playerctl -a play-pause") end,
    { description = "play/pause", group = "media" }
  ),
  awful.key(
    {},
    "XF86AudioPrev",
    function() awful.spawn("playerctl previous") end,
    { description = "previous track", group = "media" }
  ),
  awful.key(
    {},
    "XF86AudioNext",
    function() awful.spawn("playerctl next") end,
    { description = "next track", group = "media" }
  ),
  awful.key(
    {},
    "XF86Eject",
    function() awful.spawn.easy_async("soundswitch", utils.show_volume_notification) end,
    { description = "switch output", group = "media" }
  ),

  -- Brightness
  awful.key(
    {},
    "XF86MonBrightnessUp",
    function() awful.spawn("brightnessctl s +5%") end,
    { description = "increase brightness", group = "hardware" }
  ),
  awful.key(
    {},
    "XF86MonBrightnessDown",
    function() awful.spawn("brightnessctl s 5%-") end,
    { description = "decrease brightness", group = "hardware" }
  ),
})

-- fixed tags (Mod+1..0)
local tag_keys = { "#10", "#11", "#12", "#13", "#14", "#15", "#16", "#17", "#18", "#19" }
for i, key in ipairs(tag_keys) do
  awful.keyboard.append_global_keybindings({
    awful.key(
      { Global.Keys.ModKey },
      key,
      function()
        local t = awful.screen.focused().tags[i]
        if t then t:view_only() end
      end,
      { description = string.format("view tag #%d", i), group = "tag" }
    ),
    awful.key(
      { Global.Keys.ModKey, "Shift" },
      key,
      function()
        if client.focus then
          local t = client.focus.screen.tags[i]
          if t then client.focus:move_to_tag(t) end
        end
      end,
      { description = string.format("move client to tag #%d", i), group = "tag" }
    ),
  })
end


-- Client keys
client.connect_signal("request::default_keybindings", function()
  awful.keyboard.append_client_keybindings({
    awful.key(
      { Global.Keys.ModKey },
      "'",
      function(c) c:kill() end,
      { description = "close", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey },
      "m",
      function(c)
        c.maximized = not c.maximized
        c:raise()
      end,
      { description = "toggle maximized", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey },
      "f",
      awful.client.floating.toggle,
      { description = "toggle floating", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey, "Control" },
      "f",
      function(c)
        c.fullscreen = not c.fullscreen
        c:raise()
      end,
      { description = "toggle fullscreen", group = "client" }
    ),

    -- Vim-style focus: h/j/k/l with directional logic + wrap
    awful.key(
      { Global.Keys.ModKey },
      "h",
      focus_wrap("left"),
      { description = "focus left", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey },
      "l",
      focus_wrap("right"),
      { description = "focus right", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey },
      "j",
      focus_wrap("down"),
      { description = "focus down", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey },
      "k",
      focus_wrap("up"),
      { description = "focus up", group = "client" }
    ),

    awful.key(
      { Global.Keys.ModKey, "Shift" },
      "h",
      function()
        if client.focus then
          awful.client.swap.bydirection("left")
        end
      end,
      { description = "move window left", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey, "Shift" },
      "j",
      function()
        if client.focus then
          awful.client.swap.bydirection("down")
        end
      end,
      { description = "move window down", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey, "Shift" },
      "k",
      function()
        if client.focus then
          awful.client.swap.bydirection("up")
        end
      end,
      { description = "move window up", group = "client" }
    ),
    awful.key(
      { Global.Keys.ModKey, "Shift" },
      "l",
      function()
        if client.focus then
          awful.client.swap.bydirection("right")
        end
      end,
      { description = "move window right", group = "client" }
    ),
  })
end)

-- Mouse
client.connect_signal("request::default_mousebindings", function()
  awful.mouse.append_client_mousebindings({
    awful.button({}, 1, function(c)
      c.focus = c
      c:raise()
    end),
    awful.button({ Global.Keys.ModKey }, 1, awful.mouse.client.move),
    awful.button({ Global.Keys.ModKey }, 3, awful.mouse.client.resize),
  })
end)
