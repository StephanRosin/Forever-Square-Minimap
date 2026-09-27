-- Tests for Forever Square Minimap. Run with tests/run (Lua 5.1, as in WoW:
-- 5.4 lacks math.atan2 and friends the game has).
local M = dofile("wowmock.lua")
local ROOT = ADDONDIR
local ADDON = "ForeverSquareMinimap"

-- The files in TOC order, all with the same ns, as the client loads them.
local function tocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-44s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end
local function close(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

local slash = function(msg) SlashCmdList["FOREVERSQUAREMINIMAP"](msg) end

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")

section("Shape and start")
check("GetMinimapShape", GetMinimapShape(), "SQUARE")
check("default size", Minimap:GetWidth(), 180)
check("size in the profile", ns.DB().size, 180)
check("border hidden", M.hidden["MinimapBorder"], true)
check("north tag hidden", M.hidden["MinimapNorthTag"], true)
check("zoom button hidden", M.hidden["MinimapZoomIn"], true)
check("slash command", type(SlashCmdList["FOREVERSQUAREMINIMAP"]), "function")
check("short alias /fsm", SLASH_FOREVERSQUAREMINIMAP2, "/fsm")

section("The column holds only shown buttons")
local function anchorY(n) local a = M.placed[n]; return a and a[3] end
local function anchorX(n) local a = M.placed[n]; return a and a[2] end
check("tracking placed", anchorY("MiniMapTracking"), -18)
check("mail skipped", anchorY("MiniMapMailFrame"), nil)
check("battleground skipped", anchorY("MiniMapBattlefieldFrame"), nil)
check("day/night not in the column", anchorY("GameTimeFrame"), nil)
check("day/night hidden", M.hidden["GameTimeFrame"], true)
check("centre line with the default shift", anchorX("MiniMapTracking"), 1.5)

section("Mail appearing later is stacked in")
local ticker
for _, f in ipairs(M.frames) do
    if f:GetScript("OnUpdate") and f._events["PLAYER_LOGIN"] then ticker = f end
end
MiniMapMailFrame._shown = true
for _ = 1, 2 do ticker:GetScript("OnUpdate")(ticker, 1.0) end
check("mail now in the column", anchorY("MiniMapMailFrame"), -52.5)
MiniMapMailFrame._shown = false

section("Column shift (positive = right / up)")
check("default col 20", anchorX("MiniMapTracking"), 1.5)
slash("col 10")
check("col 10", anchorX("MiniMapTracking"), -8.5)
slash("col 25")
check("col 25, past the edge", anchorX("MiniMapTracking"), 6.5)
slash("col 0 12")
check("12 px up", anchorY("MiniMapTracking"), -6)
slash("col 0 -20")
check("20 px down", anchorY("MiniMapTracking"), -38)
slash("col 5 5")
check("both axes: x", anchorX("MiniMapTracking"), -13.5)
check("both axes: y", anchorY("MiniMapTracking"), -13)
slash("col 0 0")

section("Stacked buttons hang on the minimap, hidden ones too")
for _, n in ipairs({ "MiniMapTracking", "MiniMapMailFrame", "MiniMapBattlefieldFrame" }) do
    check("reparented: " .. n, M.reparented[n], "Minimap")
end

section("Own labels instead of Blizzard's buttons")
check("zone bar hidden", M.hidden["MinimapZoneTextButton"], true)
check("clock button hidden", M.hidden["TimeManagerClockButton"], true)
local texts = {}
for _, t in pairs(M.labelText) do texts[t] = true end
check("zone name", texts["Gadgetzan"], true)
check("server time", texts["21:07"], true)

section("Moving the whole map")
local function mapAnchor() local a = M.placed["Minimap"]; return a and a[2], a and a[3] end
slash("move 0 0")
local bx, by = mapAnchor()
slash("move 0 40")
local nx, ny = mapAnchor()
check("40 px up", ny - by, 40)
check("horizontal unchanged", nx - bx, 0)
slash("move -30 10")
local px, py = mapAnchor()
check("30 px left", px - bx, -30)
check("10 px up", py - by, 10)
slash("move -30 10")
local qx, qy = mapAnchor()
check("does not add up", qx == px and qy == py, true)
slash("reset")
local dx, dy = mapAnchor()
check("default: 10 px up", dy - by, 10)
check("default: 0 horizontally", dx - bx, 0)

section("Cluster and decoration")
check("minimap on UIParent", M.reparented["Minimap"], "UIParent")
check("cluster hidden", M.hidden["MinimapCluster"], true)
check("backdrop hidden", M.hidden["MinimapBackdrop"], true)
check("red X hidden", M.hidden["MinimapToggleButton"], true)
check("world map button hidden", M.hidden["MiniMapWorldMapButton"], true)
check("instance info on the minimap", M.placed["MiniMapInstanceDifficulty"][4], "Minimap")
check("missing frames do not matter", Minimap:GetWidth(), 180)

section("Size limits")
slash("size 250")
check("250", Minimap:GetWidth(), 250)
slash("size 40")
check("below the minimum -> 100", Minimap:GetWidth(), 100)
slash("size 9999")
check("above the maximum -> 400", Minimap:GetWidth(), 400)
slash("reset")
check("reset -> 180", Minimap:GetWidth(), 180)
local before = M.zoomCalls
slash("size 200")
check("zoom nudged so the map redraws", (M.zoomCalls or 0) > before, true)
local r = M.iconRefreshes
slash("size 220")
check("icons refreshed", M.iconRefreshes > r, true)
check("radius unchanged", LibStub("LibDBIcon-1.0").radius, 5)

section("Dragging the corner")
local grip = M.byName["ForeverSquareMinimapGrip"]
check("grip exists", grip ~= nil, true)
M.state.ctrl = false
grip:GetScript("OnMouseDown")(grip, "LeftButton")
check("no drag without Ctrl", grip.dragging, nil)
M.state.ctrl, M.state.mouseDown = true, true
grip:GetScript("OnMouseDown")(grip, "LeftButton")
check("drag started", grip.dragging, true)
M.state.cursor = { M.minimapRight - 300, M.minimapTop - 260 }
grip:GetScript("OnUpdate")(grip)
check("the longer edge wins", Minimap:GetWidth(), 300)
M.state.ctrl = false
M.state.cursor = { M.minimapRight - 340, M.minimapTop - 200 }
grip:GetScript("OnUpdate")(grip)
check("releasing Ctrl keeps dragging", Minimap:GetWidth(), 340)
M.state.mouseDown = false
grip:GetScript("OnUpdate")(grip)
check("mouse up ends the drag", grip.dragging, false)
check("size saved", ns.DB().size, 340)
M.state.ctrl = true
grip:GetScript("OnMouseDown")(grip, "RightButton")
check("right button does not start", grip.dragging, false)
slash("reset")

section("Border")
local ring, line = {}, {}
for _, t in ipairs(M.textures) do
    if t._owner and t._owner._name == "ForeverSquareMinimapBorder" then
        if #ring < 4 then ring[#ring + 1] = t else line[#line + 1] = t end
    end
end
local borderFrame = M.byName["ForeverSquareMinimapBorder"]
check("ring of four", #ring, 4)
check("default: flat", borderFrame._shown, true)
check("default: black", ring[1]._color and ring[1]._color[1], 0)
check("default: one pixel (factor 0.8)", close(ring[1]._h, 0.8), true)
check("inner line hidden when flat", line[1]._shown, false)
ns.DB().borderSize = 3
ns.DB().borderColor = { 1, 0, 0, 0.5 }
ns.api.ApplyBorder()
check("3 px thick", close(ring[3]._w, 2.4), true)
check("colour", ring[2]._color[1] .. "," .. ring[2]._color[4], "1,0.5")
-- Top edge: outer edge 3 px outside the map, inner edge on the map's edge.
local top = M.placed[ring[1]]
check("top sits outside the map", top and top[1], "BOTTOMRIGHT")
check("top touches the map", top and top[3], 0)
ns.DB().borderStyle = "GOLD"
ns.api.ApplyBorder()
local G = ns.GOLD
local tg, sg, bg = ring[1]._gradient, ring[3]._gradient, ring[2]._gradient
check("gold top: MID up to LIGHT", tg and tg[2].g == G.MID[2] and tg[3].b == G.LIGHT[3], true)
check("gold sides: SHADE up to MID", sg and sg[2].g == G.SHADE[2] and sg[3].g == G.MID[2], true)
check("gold bottom: DARK up to SHADE", bg and bg[2].g == G.DARK[2] and bg[3].g == G.SHADE[2], true)
check("sides meet the top without a step", sg[3].g == tg[2].g, true)
check("sides meet the bottom without a step", sg[2].g == bg[3].g, true)
check("gold: inner line shown", line[1]._shown, true)
check("gold: inner line colour", line[1]._color[1], G.LINE[1])
check("gold: inner line one pixel", close(line[1]._h, 0.8), true)
ns.DB().borderSize = 1
ns.api.ApplyBorder()
check("gold at 1 px: no line over it", line[1]._shown, false)
ns.DB().borderStyle = "NONE"
ns.api.ApplyBorder()
check("none: hidden", borderFrame._shown, false)
ns.DB().borderStyle, ns.DB().borderSize, ns.DB().borderColor = nil, nil, nil
ns.api.ApplyBorder()
check("back to the default", borderFrame._shown, true)

section("Profiles")
ForeverSquareMinimapProfiles, ForeverSquareMinimapChar = nil, nil
ns.ResetProfileState()
check("first profile is Default", ns.ActiveProfile(), "Default")
ns.DB().size = 222
check("save as", ns.SwitchProfile("Second"), true)
check("two profiles", #ns.ProfileList(), 2)
check("values taken along", ns.DB().size, 222)
ns.DB().size = 99
ns.SwitchProfile("Default")
check("Default untouched (deep copy)", ns.DB().size, 222)
check("switching applies the look", Minimap:GetWidth(), 222)
ns.SwitchProfile("Second")
check("and back", Minimap:GetWidth(), 100)
check("delete", ns.DeleteProfile("Second"), true)
check("back on Default", ns.ActiveProfile(), "Default")
M.chat = {}
ns.AskDeleteProfile()
check("the last profile stays", #ns.ProfileList(), 1)
check("says so", (M.chat[1] or ""):find("last profile", 1, true) ~= nil, true)
-- A character whose profile was deleted elsewhere gets an empty one.
ForeverSquareMinimapProfiles = { profiles = {} }
ForeverSquareMinimapChar = { active = "Gone" }
ns.ResetProfileState()
check("missing profile recreated", type(ns.DB()), "table")
check("under its name", ns.ActiveProfile(), "Gone")

section("Settings live in SavedVariables only")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("CVar", 1, true), nil)
end

section("Clocks")
local realGGT = _G.GetGameTime
_G.GetGameTime = function() return 3, 7 end
ticker.since = 99
ticker:GetScript("OnUpdate")(ticker, 5)
local server, localTime
for _, fs in ipairs(M.fontStrings) do
    if fs._text == "03:07" then server = fs end
end
for _, fs in ipairs(M.fontStrings) do
    if fs ~= server and type(fs._text) == "string" and fs._text:match("^%d%d:%d%d$") then localTime = fs end
end
check("server time shown", server ~= nil, true)
check("local time shown", localTime ~= nil, true)
check("local time bottom right", localTime and M.placed[localTime][1], "BOTTOMRIGHT")
_G.GetGameTime = realGGT

section("FPS and latency")
local GREEN, YELLOW, RED = "ff40ff40", "ffffd000", "ffff4040"
-- Colour AND number together: the text holds two coloured values.
local function colours(text, number, colour)
    return text:find("|c" .. colour .. tostring(number) .. "|r", 1, true) ~= nil
end
local function visible(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local t = ns.PerfText(120, 40)
check("two lines", select(2, t:gsub("\n", "")), 1)
check("first line: fps", visible(t:match("^[^\n]*")), "120 fps")
check("second line: ms", visible(t:match("[^\n]*$")), "40 ms")
check("120 green", colours(ns.PerfText(120, 40), 120, GREEN), true)
check("60 still green", colours(ns.PerfText(60, 40), 60, GREEN), true)
check("59 yellow", colours(ns.PerfText(59, 40), 59, YELLOW), true)
check("30 still yellow", colours(ns.PerfText(30, 40), 30, YELLOW), true)
check("29 red", colours(ns.PerfText(29, 40), 29, RED), true)
check("40 ms green", colours(ns.PerfText(120, 40), 40, GREEN), true)
check("100 ms still green", colours(ns.PerfText(120, 100), 100, GREEN), true)
check("101 ms yellow", colours(ns.PerfText(120, 101), 101, YELLOW), true)
check("250 ms still yellow", colours(ns.PerfText(120, 250), 250, YELLOW), true)
check("251 ms red", colours(ns.PerfText(120, 251), 251, RED), true)
check("no latency yet: a dash", ns.PerfText(120, nil):find("--", 1, true) ~= nil, true)
check("no fps: a dash too", ns.PerfText(nil, 40):find("--", 1, true) ~= nil, true)
check("119.6 rounds to 120", visible(ns.PerfText(119.6, 40):match("^[^\n]*")), "120 fps")

section("Diagnostics")
local ok, dump = pcall(ns.DumpText)
check("dump runs", ok, true)
check("names the interface", ok and dump:find("20506", 1, true) ~= nil, true)
check("stays English", ok and dump:find("does not exist", 1, true) ~= nil, true)

section("Languages")
local base = ns.Locales.enUS
for code, strings in pairs(ns.Locales) do
    for key in pairs(base) do
        check(code .. " has " .. key, strings[key] ~= nil, true)
    end
    for key in pairs(strings) do
        check(code .. ": " .. key .. " is known", base[key] ~= nil, true)
    end
    -- Every format keeps its placeholders.
    for key, value in pairs(base) do
        local want = select(2, value:gsub("%%[ds]", ""))
        local got = strings[key] and select(2, strings[key]:gsub("%%[ds]", "")) or want
        check(code .. ": placeholders of " .. key, got, want)
    end
end
check("German has real umlauts", ns.Locales.deDE.OPT_SIZE, "Größe")

check("game language by default", ns.Locale.Resolve("AUTO", "deDE"), "deDE")
check("Mexican Spanish uses esES", ns.Locale.Resolve("AUTO", "esMX"), "esES")
check("unknown game language -> English", ns.Locale.Resolve("AUTO", "koKR"), "enUS")
check("a choice beats the game", ns.Locale.Resolve("frFR", "deDE"), "frFR")

-- The options page follows a language change at once.
local function shown(want)
    for _, fs in ipairs(M.fontStrings) do if fs._text == want then return true end end
    for _, f in ipairs(M.frames) do if f._text == want then return true end end
    return false
end
check("options in English", shown("Button column"), true)
ns.Locale.Set("deDE")
check("setting stored account wide", ForeverSquareMinimapProfiles.language, "deDE")
check("options in German", shown("Knopfspalte"), true)
check("buttons too", shown("Löschen"), true)
check("the hint too", shown(ns.Locales.deDE.OPT_HINT), true)
M.chat = {}
slash("size 200")
check("chat in German", (M.chat[1] or ""):find("Größe: 200 px", 1, true) ~= nil, true)
ns.AskProfileName()
check("dialogs in German", M.popups[#M.popups].text, "Name des neuen Profils:")
ns.Locale.Set("AUTO")
check("AUTO stores nothing", ForeverSquareMinimapProfiles.language, nil)
check("back to the game's language", shown("Button column"), true)
-- Loaded with a stored language, it applies at ADDON_LOADED.
ForeverSquareMinimapProfiles.language = "frFR"
ns.Locale.Apply()
check("stored language applied", ns.Locale.Current(), "frFR")
check("French strings", ns.L.OPT_BORDER, "Bordure")
ns.Locale.Set("AUTO")

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
