local awful = require("awful")

-- True if two rectangles overlap vertically
local function same_row(cg, og)
  local top    = math.max(cg.y, og.y)
  local bottom = math.min(cg.y + cg.height, og.y + og.height)
  return bottom > top
end

-- True if two rectangles overlap horizontally
local function same_col(cg, og)
  local left  = math.max(cg.x, og.x)
  local right = math.min(cg.x + cg.width, og.x + og.width)
  return right > left
end

local function cycle_axis(dir)
  return function()
    local c = client.focus
    if not c then return end

    local s       = c.screen
    local clients = awful.client.visible(s)
    if #clients <= 1 then return end

    local cg = c:geometry()
    local horiz = (dir == "left" or dir == "right")

    -- 1) Collect all windows in same row/column as the focused client
    local group = {}
    for _, o in ipairs(clients) do
      if o ~= c then
        local og = o:geometry()
        if (horiz and same_row(cg, og)) or (not horiz and same_col(cg, og)) then
          table.insert(group, o)
        end
      end
    end

    -- If no one shares row/column, fall back to Awesome's directional focus
    if #group == 0 then
      awful.client.focus.bydirection(dir)
      if client.focus then client.focus:raise() end
      return
    end

    -- 2) Build full list = group + current client, then sort
    table.insert(group, c)

    table.sort(group, function(a, b)
      local ga = a:geometry()
      local gb = b:geometry()

      if horiz then
        local ax = ga.x + ga.width  / 2
        local bx = gb.x + gb.width  / 2
        if ax == bx then
          local ay = ga.y + ga.height / 2
          local by = gb.y + gb.height / 2
          return ay < by
        else
          return ax < bx
        end
      else
        local ay = ga.y + ga.height / 2
        local by = gb.y + gb.height / 2
        if ay == by then
          local ax = ga.x + ga.width  / 2
          local bx = gb.x + gb.width  / 2
          return ax < bx
        else
          return ay < by
        end
      end
    end)

    -- 3) Find current index in sorted list
    local idx
    for i, o in ipairs(group) do
      if o == c then
        idx = i
        break
      end
    end
    if not idx then return end

    local step = (dir == "left" or dir == "up") and -1 or 1
    local n    = #group
    local next_idx = ((idx - 1 + step) % n) + 1
    local target   = group[next_idx]

    if target and target ~= c then
      client.focus = target
      target:raise()
    end
  end
end

local function focus_wrap(dir)
  if dir == "left"  then return cycle_axis("left")  end
  if dir == "right" then return cycle_axis("right") end
  if dir == "up"    then return cycle_axis("up")    end
  if dir == "down"  then return cycle_axis("down")  end
end

return focus_wrap
