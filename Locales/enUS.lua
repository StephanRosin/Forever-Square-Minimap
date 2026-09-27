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
L.OPT_COLUMN = "Button column"
L.OPT_COLUMN_X = "Horizontal"
L.OPT_COLUMN_Y = "Vertical"
L.OPT_PERF = "FPS and latency"
L.OPT_PERF_SHOW = "Show"
L.OPT_PROFILE = "Profile"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Really delete the profile \"%s\"?"
