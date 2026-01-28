-- Autorun Applications and Define Workspaces

local awful    = require("awful")

local run_once = function(class)
  awful.spawn.once(class, {}, function(c)
    return c.class == class
  end)
end

-- Run Autorun Script
awful.spawn.with_shell(Global.ConfigFolder .. "/autorun.sh")

-- Define Workspace for Apps
client.connect_signal("request::tag", function(c)
  if c.class == "Spotify" then
    c:move_to_tag(awful.screen.focused().tags[#awful.screen.focused().tags])
  end
end)

-- Autorun Apps
awesome.connect_signal("startup", function()
  run_once("spotify")
end)
