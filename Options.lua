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

-- The theme (Themes.lua, beta): the choice, "Take positions from" another
-- theme (with undo until the theme changes or /reload), and a reset.
local Themes = ns.Themes
local PICK, UNDO = "__pick", "__undo"
local themeUndo

local function themeRefused(why)
    if why and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L.ADDON_NAME .. ":|r " .. L["THEME_REFUSED_" .. why])
    end
end

-- While the hub "Forever Themes" sets this addon's theme, its own choice
-- is greyed and the hub's window is one click away.
local function followsHub() return LibForeverThemes.Follows(ADDON) end
-- The hub's texts are the library's (the client's language).
local function hubText(key) return function() return LibForeverThemes.Text(key) end end

local function themeSection()
    return {
        { type = "header", label = "SECTION_THEME" },
        { type = "select", label = "OPT_THEME", hint = "HINT_THEME",
          choices = function()
              local list = {}
              for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do list[#list + 1] = { value = id, label = L["THEME_" .. id] } end
              return list
          end,
          disabled = followsHub,
          get = function() return Themes.Current() end,
          set = function(id)
              local ok, why = Themes.Switch(id)
              themeRefused(why)
              -- Every value on the page belongs to the theme.
              if ok then ns.RefreshOptions() end
          end },
        -- The current theme's colours, kept apart from the theme sets.
        { type = "select", label = "OPT_THEME_COLOR",
          visible = function() return #Themes.Colors() > 0 end,
          choices = function()
              local theme, list = Themes.Current(), {}
              for _, id in ipairs(Themes.Colors()) do
                  list[#list + 1] = { value = id, label = L["THEME_COLOR_" .. theme .. "_" .. id] }
              end
              return list
          end,
          disabled = followsHub,
          get = function() return Themes.Color() end,
          set = function(id) themeRefused(select(2, Themes.SetColor(id))) end },
        { type = "buttons", text = hubText("HUB_FOLLOWS"), visible = followsHub, buttons = {
            { label = hubText("HUB_OPEN"), width = 200, onClick = function() LibForeverThemes.Hub().OpenOptions() end },
        } },
        -- Without the hub: where to get it.
        { type = "buttons", text = hubText("HUB_MISSING"), muted = true,
          visible = function() return LibForeverThemes.Hub() == nil end, buttons = {
            { label = hubText("HUB_LINK"), width = 200, onClick = function() LibForeverThemes.ShowHubLink() end },
        } },
        { type = "buttons", visible = function() return Themes.HasOthers() and not followsHub() end, buttons = {
            { label = "THEME_ALL", width = 240, onClick = function()
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L.ADDON_NAME .. ":|r "
                    .. L.THEME_ALL_DONE:format(Themes.ApplyToAll()))
            end },
        } },
        { type = "select", label = "THEME_COPY_FROM", hint = "HINT_THEME_COPY_FROM",
          choices = function()
              local stored = Themes.Stored()
              local undo = themeUndo and themeUndo.theme == Themes.Current()
              local list = { { value = PICK,
                  label = (#stored == 0 and not undo) and L.THEME_COPY_NONE or L.THEME_COPY_PICK } }
              if undo then list[#list + 1] = { value = UNDO, label = L.THEME_COPY_UNDO } end
              for _, id in ipairs(stored) do list[#list + 1] = { value = id, label = L["THEME_" .. id] } end
              return list
          end,
          get = function() return PICK end,
          set = function(v)
              if v == PICK then return end
              if v == UNDO then
                  local ok, why = Themes.Restore(themeUndo.saved)
                  themeRefused(why)
                  if ok then themeUndo = nil end
              else
                  local saved, why = Themes.CopyPlacement(v)
                  themeRefused(why)
                  if saved then themeUndo = { theme = Themes.Current(), saved = saved } end
              end
              ns.RefreshOptions()
          end },
        { type = "buttons", buttons = {
            { label = "THEME_RESET", width = 150, onClick = function()
                local ok, why = Themes.Reset()
                themeRefused(why)
                if ok then ns.RefreshOptions() end
            end },
        } },
    }
end

-- One section per text (Infos.lua): on/off, what it hangs from, its
-- points and offset, font and size; FPS and latency also their arrangement.
local Infos = ns.Infos

local function pointChoices()
    local list = {}
    for _, p in ipairs(Infos.POINTS) do list[#list + 1] = { value = p, label = L["POINT_" .. p] } end
    return list
end

local function fontChoices()
    local list = {}
    for _, f in ipairs(Infos.FontList()) do
        list[#list + 1] = { value = f.key, label = f.key == "DEFAULT" and L.FONT_DEFAULT or f.key }
    end
    return list
end

local HEADERS = { zone = "OPT_INFO_ZONE", server = "OPT_INFO_SERVER", ["local"] = "OPT_INFO_LOCAL", perf = "OPT_PERF",
    coords = "OPT_INFO_COORDS" }

local function choicesOf(values, prefix)
    return function()
        local list = {}
        for _, v in ipairs(values) do list[#list + 1] = { value = v, label = L[prefix .. v] } end
        return list
    end
end

-- The mail icon (Mail.lua): on/off, a test view, place, size and animation.
local function mailSection()
    local Mail = ns.Mail
    local function get(field) return function() return Mail.Get(field) end end
    local function set(field) return function(v) Mail.Set(field, v) end end
    return {
        { type = "header", label = "OPT_MAIL" },
        { type = "check", label = "OPT_PERF_SHOW", get = get("show"), set = set("show") },
        { type = "check", label = "OPT_MAIL_PREVIEW", get = function() return Mail.preview end,
          set = function(v) Mail.SetPreview(v) end },
        { type = "select", label = "OPT_INFO_MAP_POINT", choices = pointChoices,
          get = get("mapPoint"), set = set("mapPoint") },
        { type = "select", label = "OPT_MAIL_POINT", choices = pointChoices,
          get = get("point"), set = set("point") },
        { label = "OPT_MOVE_X", min = -400, max = 400, step = 1, unit = "px", get = get("x"), set = set("x") },
        { label = "OPT_MOVE_Y", min = -400, max = 400, step = 1, unit = "px", get = get("y"), set = set("y") },
        { label = "OPT_SCALE", min = 50, max = 250, step = 5, unit = "%", get = get("scale"), set = set("scale") },
        { type = "select", label = "OPT_MAIL_ANIM", choices = choicesOf(ns.Mail.ANIMS, "ANIM_"),
          get = get("anim"), set = set("anim") },
    }
end

-- Opacity (Fade.lua).
local function fadeSection()
    local Fade = ns.Fade
    local function get(field) return function() return Fade.Get(field) end end
    local function set(field) return function(v) Fade.Set(field, v) end end
    return {
        { type = "header", label = "OPT_FADE" },
        { label = "OPT_FADE_ALPHA", min = 0, max = 100, step = 5, unit = "%", get = get("alpha"), set = set("alpha") },
        { label = "OPT_FADE_COMBAT", min = 0, max = 100, step = 5, unit = "%",
          get = get("combatAlpha"), set = set("combatAlpha") },
        { type = "check", label = "OPT_FADE_MOUSEOVER", get = get("mouseover"), set = set("mouseover") },
    }
end

local function infoSection(kind)
    local function get(field) return function() return Infos.Get(kind, field) end end
    local function set(field) return function(v) Infos.Set(kind, field, v) end end
    local items = {
        { type = "header", label = HEADERS[kind] },
        { type = "check", label = "OPT_PERF_SHOW", get = get("show"), set = set("show") },
    }
    if kind == "server" then
        items[#items + 1] = { type = "select", label = "OPT_INFO_ANCHOR",
            choices = function()
                return { { value = "ZONE", label = L.INFO_ANCHOR_ZONE }, { value = "MAP", label = L.INFO_ANCHOR_MAP } }
            end,
            get = get("anchor"), set = set("anchor") }
    end
    items[#items + 1] = { type = "select", label = "OPT_INFO_MAP_POINT", choices = pointChoices,
        get = get("mapPoint"), set = set("mapPoint") }
    items[#items + 1] = { type = "select", label = "OPT_INFO_POINT", choices = pointChoices,
        get = get("point"), set = set("point") }
    items[#items + 1] = { label = "OPT_MOVE_X", min = -400, max = 400, step = 1, unit = "px",
        get = get("x"), set = set("x") }
    items[#items + 1] = { label = "OPT_MOVE_Y", min = -400, max = 400, step = 1, unit = "px",
        get = get("y"), set = set("y") }
    -- A font stored under an older name shows under the one listed.
    items[#items + 1] = { type = "select", label = "OPT_INFO_FONT", choices = fontChoices,
        get = function() return LibForeverThemes.FontName(Infos.Get(kind, "font")) end, set = set("font") }
    items[#items + 1] = { label = "OPT_INFO_SIZE", min = 0, max = 32, step = 1,
        get = get("size"), set = set("size") }
    if kind == "perf" then
        items[#items + 1] = { type = "select", label = "OPT_INFO_LAYOUT",
            choices = function()
                return { { value = "STACKED", label = L.LAYOUT_STACKED }, { value = "SIDE", label = L.LAYOUT_SIDE } }
            end,
            get = get("layout"), set = set("layout") }
        items[#items + 1] = { label = "OPT_INFO_GAP", min = 0, max = 40, step = 1, unit = "px",
            get = get("gap"), set = set("gap") }
    end
    return items
end

-- Appends items to the page.
local function add(page, items)
    for _, item in ipairs(items) do page[#page + 1] = item end
end

local function generalTab()
    local Button = ns.MinimapButton
    local items = { { type = "tab", label = "TAB_GENERAL" } }
    add(items, themeSection())
    add(items, {
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
        { type = "header", label = "OPT_BUTTON" },
        { type = "check", label = "OPT_BUTTON_SHOW",
          get = function() return Button.Get("show") end, set = function(v) Button.Set("show", v) end },
    })
    add(items, fadeSection())
    add(items, {
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
    return items
end

local function mapTab()
    local reachX = math.max(600, math.ceil(UIParent:GetWidth() or 0))
    local reachY = math.max(600, math.ceil(UIParent:GetHeight() or 0))
    return {
        { type = "tab", label = "TAB_MAP" },
        { type = "header", label = "OPT_MAP" },
        { label = "OPT_SIZE", min = C.minSize, max = C.maxSize, step = 1, unit = "px",
          get = function() return num("size", C.defaultSize) end,
          set = function(v) ns.api.ApplySize(v) end },
        -- A whole screen each way, so the map can reach any edge (and leave the screen).
        { label = "OPT_MOVE_X", min = -reachX, max = reachX, step = 1, unit = "px",
          get = function() return num("offsetX", C.offsetX) end,
          set = function(v) DB().offsetX = v; ns.api.AnchorTopRight() end },
        { label = "OPT_MOVE_Y", min = -reachY, max = reachY, step = 1, unit = "px",
          get = function() return num("offsetY", C.offsetY) end,
          set = function(v) DB().offsetY = v; ns.api.AnchorTopRight() end },
        { label = "OPT_PLAYER_ARROW", min = 100, max = 300, step = 10, unit = "%",
          get = function() return ns.PlayerArrow.Get() end, set = function(v) ns.PlayerArrow.Set(v) end },

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
    }
end

-- Zone and the clocks; the size of all texts at the top.
local function textsTab()
    local items = {
        { type = "tab", label = "TAB_TEXTS" },
        { type = "header", label = "OPT_INFO_ALL" },
        { label = "OPT_INFO_SCALE", min = 50, max = 200, step = 5, unit = "%",
          get = function() return Infos.Scale() end, set = function(v) Infos.SetScale(v) end },
        { type = "select", label = "OPT_CLOCK",
          choices = function()
              return { { value = "24", label = L.CLOCK_24 }, { value = "12", label = L.CLOCK_12 } }
          end,
          get = function() return Infos.ClockFormat() end, set = function(v) Infos.SetClockFormat(v) end },
    }
    for _, kind in ipairs({ "zone", "server", "local" }) do add(items, infoSection(kind)) end
    return items
end

local function perfTab()
    local items = { { type = "tab", label = "TAB_PERF" } }
    for _, kind in ipairs({ "perf", "coords" }) do add(items, infoSection(kind)) end
    return items
end

local function mailTab()
    local items = { { type = "tab", label = "TAB_MAIL" } }
    add(items, mailSection())
    return items
end

-- Blizzard's buttons around the map (Buttons.lua); only the modern minimap
-- has them.
local BUTTON_HEADERS = { tracking = "OPT_BTN_TRACKING", calendar = "OPT_BTN_CALENDAR",
    compartment = "OPT_BTN_COMPARTMENT", difficulty = "OPT_BTN_DIFFICULTY",
    daynight = "OPT_BTN_DAYNIGHT", groupfinder = "OPT_BTN_GROUPFINDER" }

local function buttonsTab()
    local Buttons = ns.Buttons
    local items = { { type = "tab", label = "TAB_BUTTONS" } }
    for _, kind in ipairs(Buttons.KINDS) do
        local function get(field) return function() return Buttons.Get(kind, field) end end
        local function set(field) return function(v) Buttons.Set(kind, field, v) end end
        add(items, {
            { type = "header", label = BUTTON_HEADERS[kind] },
            { type = "check", label = "OPT_PERF_SHOW", get = get("show"), set = set("show") },
        })
        if kind == "compartment" then
            add(items, {
                { type = "check", label = "OPT_BTN_COLLECT", get = get("collect"), set = set("collect") },
                { type = "check", label = "OPT_BTN_HIDE_ICONS", get = get("hideIcons"), set = set("hideIcons") },
            })
        end
        add(items, {
            { type = "select", label = "OPT_INFO_MAP_POINT", choices = pointChoices,
              get = get("mapPoint"), set = set("mapPoint") },
            { type = "select", label = "OPT_BTN_POINT", choices = pointChoices,
              get = get("point"), set = set("point") },
            { label = "OPT_MOVE_X", min = -400, max = 400, step = 1, unit = "px", get = get("x"), set = set("x") },
            { label = "OPT_MOVE_Y", min = -400, max = 400, step = 1, unit = "px", get = get("y"), set = set("y") },
            { label = "OPT_SCALE", min = 50, max = 250, step = 5, unit = "%", get = get("scale"), set = set("scale") },
        })
    end
    return items
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    local page = { title = L.ADDON_NAME }
    local tabs = { generalTab, mapTab, textsTab, perfTab, mailTab }
    if ns.Buttons.Modern() then tabs[#tabs + 1] = buttonsTab end
    for _, tab in ipairs(tabs) do add(page, tab()) end
    ns.BuildOptions(page)
end)

-- The mail test ends with the options.
ns.Window.OnHide(function()
    if ns.Mail.preview then ns.Mail.SetPreview(false) end
end)
