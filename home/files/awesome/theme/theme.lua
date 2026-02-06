--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local gears = require("gears")

local Theme = {}
Theme.location = gears.filesystem.get_configuration_dir() .. "theme/"


--------------------------------------------------------------------------------
-- CORE SCALE & SPACING
--------------------------------------------------------------------------------
-- Global UI scale (change this if everything is too big/small)
-- Original: Theme.UniversalSize = os.getenv("UI_SCALING") or 20
Theme.UniversalSize = tonumber(os.getenv("UI_SCALING")) or 20

-- Base spacing unit for widgets, margins, etc.
-- Original: Theme.Spacing = Theme.UniversalSize * (2 / 3)
Theme.Spacing       = Theme.UniversalSize * (2 / 3)


--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
Theme.Font_Name = "Iosevka Nerd Font"

-- Original: Theme.Font_Size = Theme.UniversalSize * (2 / 5)   -- ~8px
-- New: slightly larger for readability: ~10px when UniversalSize = 20
Theme.Font_Size = Theme.UniversalSize * (1 / 2)

Theme.Font      = string.format("%s %d", Theme.Font_Name, Theme.Font_Size)


--------------------------------------------------------------------------------
-- COLOUR PALETTE (UNCHANGED)
--------------------------------------------------------------------------------
Theme.Colors = {
    Background = {
        Darkest = "#232935", -- bg_color_3
        Darker  = "#2a283b", -- bg_color_1
        Dark    = "#2c3040", -- bg_color_6
        Neutral = "#323845", -- bg_color_2
        Light   = "#353b47", -- bg_color_4
        Lighter = "#5f6677", -- bg_color_5
    },
    Foreground = {
        Normal = "#ddeeff",
        Urgent = "#ff0000",
    },
    Transparent = "#00000000",
}


--------------------------------------------------------------------------------
-- COLOUR MAPPINGS EXPECTED BY BEAUTIFUL (UNCHANGED)
--------------------------------------------------------------------------------
Theme.fg_normal   = Theme.Colors.Foreground.Normal
Theme.fg_urgent   = Theme.Colors.Foreground.Urgent

-- NOTE: this was in the original file and is left as-is:
-- Theme.bg_normal = Theme.Colors.Darker
Theme.bg_normal   = Theme.Colors.Darker

Theme.bg_focus    = Theme.bg_normal
Theme.bg_urgent   = "#000000"
Theme.bg_systray  = Theme.bg_normal

Theme.fg_focus    = Theme.fg_normal
Theme.fg_minimize = Theme.fg_normal


--------------------------------------------------------------------------------
-- WINDOW GEOMETRY: GAPS & BORDERS
--------------------------------------------------------------------------------
-- Gaps between tiled windows and screen edges
-- Original: Theme.useless_gap = Theme.UniversalSize / 5   -- ~4px
-- New: slightly larger, cleaner gaps: ~6px
Theme.useless_gap       = Theme.UniversalSize * (2 / 10)

-- Keep or remove gaps when only one client is on the tag
-- Original: Theme.gap_single_client = true
-- New: false → single window fills screen
Theme.gap_single_client = false

-- Window border width
-- Original: Theme.border_width = Theme.UniversalSize / 20   -- ~1px
-- New: clean 2px border
Theme.border_width      = Theme.UniversalSize / 10

-- Border colours (unchanged)
Theme.border_normal     = Theme.Colors.Background.Lighter
Theme.border_focus      = Theme.Colors.Foreground.Normal
Theme.border_marked     = Theme.Colors.Background.Dark


--------------------------------------------------------------------------------
-- TASKLIST / TITLEBAR / HOTKEYS (LOGICAL GROUP)
--------------------------------------------------------------------------------
-- Tasklist
Theme.tasklist_font            = Theme.Font
Theme.tasklist_plain_task_name = true

-- Titlebar
Theme.titlebar_bg = Theme.Colors.Background.Darkest
Theme.titlebar_fg = Theme.Colors.Foreground.Normal

-- Hotkeys popup
Theme.hotkeys_font = Theme.Font


--------------------------------------------------------------------------------
-- SYSTRAY
--------------------------------------------------------------------------------
-- Original: Theme.systray_icon_spacing = Theme.Spacing * (2 / 3)
Theme.systray_icon_spacing = Theme.Spacing * (2 / 3)

-- Background colour for systray (unchanged)
Theme.bg_systray = Theme.Colors.Background.Neutral


--------------------------------------------------------------------------------
-- NOTIFICATIONS
--------------------------------------------------------------------------------
Theme.notification_bg = Theme.Colors.Background.Dark

-- Size limits
-- Original: Theme.notification_max_width  = Theme.UniversalSize * 30   -- ~600px
-- New: slightly smaller
Theme.notification_max_width  = Theme.UniversalSize * 25   -- ~500px

-- Original: Theme.notification_max_height = Theme.UniversalSize * 40   -- ~800px
-- New:
Theme.notification_max_height = Theme.UniversalSize * 30   -- ~600px

-- Icon size
-- Original: Theme.notification_icon_size  = Theme.UniversalSize * 5    -- ~100px
-- New:
Theme.notification_icon_size  = Theme.UniversalSize * 4    -- ~80px

-- Opacity
-- Original: Theme.notification_opacity = 0.95
-- New: a touch softer
Theme.notification_opacity    = 0.90

-- Border thickness
-- Original: Theme.notification_border_width = Theme.UniversalSize / 2  -- 10px
-- New: slimmer but still visible
Theme.notification_border_width = Theme.UniversalSize / 3              -- ~6–7px

-- Border colour + font
Theme.notification_border_color = Theme.Colors.Background.Lighter
Theme.notification_font         = Theme.Font


--------------------------------------------------------------------------------
-- WALLPAPER
--------------------------------------------------------------------------------
Theme.Wallpaper = Theme.location .. "/0wall.jpg"


--------------------------------------------------------------------------------
-- LAYOUT ICONS (UNCHANGED)
--------------------------------------------------------------------------------
Theme.layout_tile       = Theme.location .. "/layout_icons/tile.png"
Theme.layout_fairh      = Theme.location .. "/layout_icons/fairh.png"
Theme.layout_fairv      = Theme.location .. "/layout_icons/fairv.png"
Theme.layout_floating   = Theme.location .. "/layout_icons/floating.png"
Theme.layout_magnifier  = Theme.location .. "/layout_icons/magnifier.png"
Theme.layout_max        = Theme.location .. "/layout_icons/max.png"
Theme.layout_tilebottom = Theme.location .. "/layout_icons/tilebottom.png"
Theme.layout_tileleft   = Theme.location .. "/layout_icons/tileleft.png"
Theme.layout_tiletop    = Theme.location .. "/layout_icons/tiletop.png"
Theme.layout_spiral     = Theme.location .. "/layout_icons/spiral.png"
Theme.layout_dwindle    = Theme.location .. "/layout_icons/dwindle.png"


--------------------------------------------------------------------------------
-- AWESOME ICON (UNCHANGED)
--------------------------------------------------------------------------------
Theme.awesome_icon = Theme.location .. "/layout_icons/awesome.png"


--------------------------------------------------------------------------------
return Theme
--------------------------------------------------------------------------------
-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
