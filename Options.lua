local ADDON, ns = ...
local L = ns.L

-- The settings live in the active profile (Profiles.lua).
local function DB() return ns.DB() end
local C = ns.api.Config

local function num(key, fallback)
    local v = DB()[key]
    if type(v) ~= "number" then v = fallback end
    return v
end

-- A profile switch changes every value on the page.
local function switchProfile(name)
    ns.SwitchProfile(name)
    ns.RefreshOptions()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    ns.BuildOptions({
        title = L.ADDON_NAME,

        {
            type = "select",
            label = "OPT_LANGUAGE",
            choices = function()
                local list = { { value = "AUTO", label = L.LANGUAGE_AUTO } }
                for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = c end
                return list
            end,
            get = function() return ns.Locale.Setting() end,
            set = function(v) ns.Locale.Set(v) end,
        },

        { type = "header", label = "OPT_MAP" },
        { label = "OPT_SIZE", min = C.minSize, max = C.maxSize, step = 1, unit = "px",
          get = function() return num("size", C.defaultSize) end,
          set = function(v) ns.api.ApplySize(v) end },
        { label = "OPT_MOVE_X", min = -600, max = 600, step = 1, unit = "px",
          get = function() return num("offsetX", C.offsetX) end,
          set = function(v) DB().offsetX = v; ns.api.AnchorTopRight() end },
        { label = "OPT_MOVE_Y", min = -600, max = 600, step = 1, unit = "px",
          get = function() return num("offsetY", C.offsetY) end,
          set = function(v) DB().offsetY = v; ns.api.AnchorTopRight() end },

        { type = "header", label = "OPT_BORDER" },
        {
            type = "select",
            label = "OPT_BORDER_STYLE",
            choices = function()
                return {
                    { value = "NONE", label = L.BORDER_NONE },
                    { value = "FLAT", label = L.BORDER_FLAT },
                    { value = "GOLD", label = L.BORDER_GOLD },
                }
            end,
            get = function() return DB().borderStyle or C.borderStyle end,
            set = function(v) DB().borderStyle = v; ns.api.ApplyBorder() end,
        },
        { label = "OPT_BORDER_SIZE", min = 1, max = C.borderMaxSize, step = 1, unit = "px",
          get = function() return num("borderSize", C.borderSize) end,
          set = function(v) DB().borderSize = v; ns.api.ApplyBorder() end },
        { type = "color", label = "OPT_BORDER_COLOR",
          get = function()
              local c = DB().borderColor
              return type(c) == "table" and c or C.borderColor
          end,
          set = function(c) DB().borderColor = { c[1], c[2], c[3], c[4] }; ns.api.ApplyBorder() end },

        { type = "header", label = "OPT_COLUMN" },
        { label = "OPT_COLUMN_X", min = -100, max = 100, step = 1, unit = "px",
          get = function() return num("colNudge", C.colNudge) end,
          set = function(v) DB().colNudge = v; ns.api.LayoutButtons() end },
        { label = "OPT_COLUMN_Y", min = -100, max = 100, step = 1, unit = "px",
          get = function() return num("colNudgeY", C.colNudgeY) end,
          set = function(v) DB().colNudgeY = v; ns.api.LayoutButtons() end },

        { type = "header", label = "OPT_PERF" },
        { type = "check", label = "OPT_PERF_SHOW",
          get = function() return DB().showPerf ~= false end,
          set = function(v) DB().showPerf = v; ns.api.UpdateLabels() end },
        -- The display sits left of the button column; this moves it further,
        -- negative to the left.
        { label = "OPT_MOVE_X", min = -200, max = 200, step = 1, unit = "px",
          get = function() return num("perfNudgeX", C.perfNudgeX) end,
          set = function(v) DB().perfNudgeX = v; ns.api.LayoutButtons() end },

        { type = "header", label = "OPT_PROFILE" },
        {
            type = "select",
            label = "OPT_PROFILE_ACTIVE",
            -- A function: saving and deleting change the list.
            choices = function()
                local list = {}
                for _, name in ipairs(ns.ProfileList()) do
                    list[#list + 1] = { label = name, value = name }
                end
                return list
            end,
            get = function() return ns.ActiveProfile() end,
            set = switchProfile,
        },
        {
            type = "buttons",
            buttons = {
                { label = "OPT_PROFILE_SAVE_AS", width = 150, onClick = function() ns.AskProfileName() end },
                { label = "OPT_PROFILE_DELETE",  width = 100, onClick = function() ns.AskDeleteProfile() end },
            },
        },
    })
end)

-- A language change relabels the page at once.
ns.Locale.OnChange(function()
    if ns.RelabelOptions then ns.RelabelOptions() end
end)
