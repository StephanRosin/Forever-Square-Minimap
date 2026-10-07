local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Square Minimap"

-- Chat
L.MSG_RESET = "Size reset to %d px."
L.MSG_MOVED = "Map moved: %s px horizontally, %s px vertically."
L.MSG_COLUMN = "Button column: %s px horizontally, %s px vertically."
L.MSG_POSITIVE = "Positive means right or up."
L.MSG_SIZE = "Size: %d px"
L.MSG_STATUS = "Currently %d px. Hold Ctrl and drag the bottom left corner to resize."
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."

-- The resize grip and the diagnostics window
L.GRIP_HINT = "Ctrl + drag with the left mouse button: resize"
L.GRIP_CURRENT = "Current: %d px"
L.DUMP_HINT = "Ctrl+A, Ctrl+C to copy. Esc closes."

-- Options
L.OPT_HINT = "Drag for rough values, type for exact ones (confirm with Enter)."
L.OPEN_OPTIONS = "Open the options"
L.TAB_GENERAL = "General"
L.TAB_MAP = "Map"
L.TAB_TEXTS = "Texts"
L.TAB_PERF = "FPS & coordinates"
L.TAB_MAIL = "Mail"
L.TAB_BUTTONS = "Buttons"
L.OPT_BTN_TRACKING = "Tracking"
L.OPT_BTN_CALENDAR = "Calendar"
L.OPT_BTN_COMPARTMENT = "Addon compartment"
L.OPT_BTN_DIFFICULTY = "Instance difficulty"
L.OPT_BTN_POINT = "Point of the button"
L.OPT_BTN_COLLECT = "List every minimap button"
L.OPT_BTN_HIDE_ICONS = "Hide those buttons on the map"
L.OPT_LANGUAGE = "Language"
L.LANGUAGE_AUTO = "Game language"
L.OPT_MAP = "Map"
L.OPT_SIZE = "Size"
L.OPT_MOVE_X = "Move horizontally"
L.OPT_MOVE_Y = "Move vertically"
L.OPT_BORDER = "Border"
L.OPT_BORDER_STYLE = "Style"
L.BORDER_NONE = "None"
L.BORDER_FLAT = "Flat"
L.BORDER_GOLD = "Gold"
L.OPT_BORDER_SIZE = "Thickness"
L.OPT_BORDER_COLOR = "Colour (Flat only)"
L.OPT_PERF = "FPS and latency"
L.OPT_PERF_SHOW = "Show"
L.OPT_PROFILE = "Profile"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Really delete the profile \"%s\"?"

-- Texts on the map (Infos.lua).
L.OPT_INFO_ZONE = "Zone text"
L.OPT_INFO_SERVER = "Server time"
L.OPT_INFO_LOCAL = "Local time"
L.OPT_INFO_ANCHOR = "Anchored to"
L.INFO_ANCHOR_MAP = "Map"
L.INFO_ANCHOR_ZONE = "Zone text"
L.OPT_INFO_MAP_POINT = "Point on the map"
L.OPT_INFO_POINT = "Point of the text"
L.OPT_INFO_FONT = "Font"
L.FONT_DEFAULT = "Default"
L.OPT_INFO_SIZE = "Font size (0 = auto)"
L.OPT_INFO_LAYOUT = "Arrangement"
L.LAYOUT_STACKED = "On top of each other"
L.LAYOUT_SIDE = "Side by side"
L.OPT_INFO_GAP = "Gap between FPS and ms"
L.OPT_BUTTON = "Minimap button"
L.OPT_BUTTON_SHOW = "Show button"
L.BUTTON_CLICK = "Click: options"
L.BUTTON_DRAG = "Drag: move along the edge"
L.OPT_INFO_COORDS = "Coordinates"
L.OPT_INFO_ALL = "All texts"
L.OPT_INFO_SCALE = "Font size of all texts"
L.OPT_CLOCK = "Clock"
L.CLOCK_24 = "24-hour (21:07)"
L.CLOCK_12 = "12-hour (9:07 PM)"
L.OPT_MAIL = "Mail icon"
L.OPT_MAIL_PREVIEW = "Show as a test (while the options are open)"
L.OPT_MAIL_POINT = "Point of the icon"
L.OPT_SCALE = "Size"
L.OPT_MAIL_ANIM = "Animation on new mail"
L.ANIM_NONE = "None"
L.ANIM_PULSE = "Pulse"
L.ANIM_BOUNCE = "Bounce"
L.ANIM_GLOW = "Glow"
L.OPT_FADE = "Opacity"
L.OPT_FADE_ALPHA = "Opacity"
L.OPT_FADE_COMBAT = "Opacity in combat"
L.OPT_FADE_MOUSEOVER = "Fully visible under the mouse"
L.POINT_TOPLEFT = "Top left"
L.POINT_TOP = "Top"
L.POINT_TOPRIGHT = "Top right"
L.POINT_LEFT = "Left"
L.POINT_CENTER = "Center"
L.POINT_RIGHT = "Right"
L.POINT_BOTTOMLEFT = "Bottom left"
L.POINT_BOTTOM = "Bottom"
L.POINT_BOTTOMRIGHT = "Bottom right"
