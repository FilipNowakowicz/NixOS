-- Autorun Applications and Define Workspaces

local awful    = require("awful")

local run_once = function(class)
  if awful.spawn.once then
    awful.spawn.once(class, {}, function(c)
      return c.class == class
    end)
    return
  end

  for _, c in ipairs(client.get()) do
    if c.class == class then
      return
    end
  end

  awful.spawn(class)
end

-- Run Autorun Script
awful.spawn.with_shell(Global.ConfigFolder .. "/autorun.sh")

-- Define Workspace for Apps
client.connect_signal("manage", function(c)
  if c.class == "Spotify" then
    local screen_tags = c.screen.tags
    if screen_tags and #screen_tags > 0 then
      c:move_to_tag(screen_tags[#screen_tags])
    end
  end
end)

-- Autorun Apps
awesome.connect_signal("startup", function()
  run_once("spotify")
end)
