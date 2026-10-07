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
check("default size", Minimap:GetWidth(), 260)
check("size in the profile", ns.DB().size, 260)
check("border hidden", M.hidden["MinimapBorder"], true)
check("north tag hidden", M.hidden["MinimapNorthTag"], true)
check("zoom button hidden", M.hidden["MinimapZoomIn"], true)
check("slash command", type(SlashCmdList["FOREVERSQUAREMINIMAP"]), "function")
check("short alias /fsm", SLASH_FOREVERSQUAREMINIMAP2, "/fsm")

section("The column holds only shown buttons")
local function anchorY(n) local a = M.placed[n]; return a and a[3] end
local function anchorX(n) local a = M.placed[n]; return a and a[2] end
check("tracking placed", anchorY("MiniMapTracking"), -18)
check("mail not in the column", MiniMapMailFrame._anchor[3], "TOPLEFT")
check("battleground skipped", anchorY("MiniMapBattlefieldFrame"), nil)
check("day/night not in the column", anchorY("GameTimeFrame"), nil)
check("day/night hidden", M.hidden["GameTimeFrame"], true)
check("centre line with the default shift", anchorX("MiniMapTracking"), 1.5)

section("Mail appearing later keeps its own place")
local ticker
for _, f in ipairs(M.frames) do
    if f:GetScript("OnUpdate") and f._events["PLAYER_LOGIN"] then ticker = f end
end
MiniMapMailFrame._shown = true
for _ = 1, 2 do ticker:GetScript("OnUpdate")(ticker, 1.0) end
check("mail still at its own place", MiniMapMailFrame._anchor[3], "TOPLEFT")
check("tracking unmoved", anchorY("MiniMapTracking"), -18)
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

section("Texts on the map: defaults")
local I = ns.Infos
local T = I.texts

section("Clock: 24 or 12 hours")
check("24 hours by default", I.ClockFormat(), "24")
check("local time, 24 hours", T["local"]._text, "21:07")
I.SetClockFormat("12")
check("server time, 12 hours", T.server._text, "9:07 PM")
check("local time, 12 hours", T["local"]._text, "9:07 PM")
check("in the profile", ns.DB().clock, "12")
M.serverTime = { 0, 5 }; M.localTime = { hour = 12, min = 0 }
I.Update()
check("midnight is 12 AM", T.server._text, "12:05 AM")
check("noon is 12 PM", T["local"]._text, "12:00 PM")
TIME_TWELVEHOURAM = "%d:%02d vorm."
I.Update()
check("the game's AM/PM strings", T.server._text, "12:05 vorm.")
TIME_TWELVEHOURAM = nil
M.serverTime = { 9, 3 }
I.SetClockFormat("24")
check("back to 24 hours, leading zero", T.server._text, "09:03")
M.serverTime = { 21, 7 }; M.localTime = { hour = 21, min = 7 }
I.Update()
local function a(region) return region._anchor end
check("zone: top of the map", a(T.zone)[1] .. ">" .. a(T.zone)[3], "TOP>TOP")
check("zone: on the map", a(T.zone)[2], Minimap)
check("zone: at the edge", a(T.zone)[5], 0)
check("zone: 11 pt", select(2, T.zone:GetFont()), 11)
check("zone: Friz Quadrata", T.zone:GetFont(), "Fonts\\FRIZQT__.TTF")
check("server time: under the zone text", a(T.server)[2], T.zone)
check("server time: top to bottom", a(T.server)[1] .. ">" .. a(T.server)[3], "TOP>BOTTOM")
check("server time: 1 px gap", a(T.server)[5], -1)
check("server time: 11 pt", select(2, T.server:GetFont()), 11)
check("local time: bottom centre", a(T["local"])[1] .. ">" .. a(T["local"])[3], "BOTTOM>BOTTOM")
check("local time: at the edge", a(T["local"])[4] .. "," .. a(T["local"])[5], "0,0")
check("local time: centred", T["local"]._justify, "CENTER")
check("local time: 11 pt", select(2, T["local"]:GetFont()), 11)
check("perf: top right", a(T.perf)[1] .. ">" .. a(T.perf)[3], "TOPRIGHT>TOPRIGHT")
check("perf: in the corner", a(T.perf)[4] .. "," .. a(T.perf)[5], "0,0")
check("perf: 11 pt", select(2, T.perf.fps:GetFont()), 11)
check("coordinates shown", T.coords:IsShown(), true)
check("coordinates: bottom left corner", a(T.coords)[1] .. ">" .. a(T.coords)[3] .. " " .. a(T.coords)[4] .. "," .. a(T.coords)[5], "BOTTOMLEFT>BOTTOMLEFT 0,0")
check("everything shown", T.zone:IsShown() and T.server:IsShown() and T["local"]:IsShown() and T.perf:IsShown(), true)
check("outline kept", select(3, T.zone:GetFont()), "OUTLINE")

section("Texts on the map: FPS and latency")
local fps, ms = T.perf.fps, T.perf.ms
check("stacked: fps on top, right-aligned", a(fps)[1], "TOPRIGHT")
check("stacked: ms below, right-aligned", a(ms)[1], "BOTTOMRIGHT")
local h0 = T.perf:GetHeight()
I.Set("perf", "gap", 5)
check("gap adds to the height", T.perf:GetHeight() - h0, 5)
I.Set("perf", "layout", "SIDE")
check("side by side: ms right of fps", a(ms)[1] .. ">" .. a(ms)[3], "LEFT>RIGHT")
check("side by side: the gap", a(ms)[4], 5)
check("side by side: one line high", T.perf:GetHeight(), 11)
check("side by side: both widths and the gap",
    T.perf:GetWidth(), fps:GetStringWidth() + 5 + ms:GetStringWidth())
I.Set("perf", "layout", "STACKED")
I.Set("perf", "point", "TOPLEFT")
check("left anchor: texts aligned left", fps._justify, "LEFT")
I.Set("perf", "point", "TOPRIGHT")
I.Set("perf", "gap", 0)

section("Texts on the map: settings")
I.Set("zone", "show", false)
check("zone off: hidden", T.zone:IsShown(), false)
I.Set("zone", "show", true)
I.Set("local", "mapPoint", "BOTTOM")
I.Set("local", "point", "TOP")
I.Set("local", "y", -3)
check("outside the map: under its bottom edge", a(T["local"])[1] .. ">" .. a(T["local"])[3] .. " " .. a(T["local"])[5],
    "TOP>BOTTOM -3")
check("top point: centred text", T["local"]._justify, "CENTER")
I.Set("server", "anchor", "MAP")
check("server time on the map instead", a(T.server)[2], Minimap)
I.Set("zone", "size", 16)
check("own size", select(2, T.zone:GetFont()), 16)
I.Set("zone", "size", 0)
check("auto: the game font's size again", select(2, T.zone:GetFont()), 12)
I.Set("zone", "font", "Morpheus")
check("own font", T.zone:GetFont(), "Fonts\\MORPHEUS.TTF")
I.Set("zone", "font", "DEFAULT")
check("default font again", T.zone:GetFont(), "Fonts\\FRIZQT__.TTF")
-- Back to the defaults for the tests below.
ns.DB().infos = nil
I.Apply()

section("Texts on the map: one size for all")
check("100 % by default", I.Scale(), 100)
I.SetScale(150)
check("zone 11 -> 17", select(2, T.zone:GetFont()), 17)
check("server 11 -> 17", select(2, T.server:GetFont()), 17)
check("perf 11 -> 17", select(2, T.perf.fps:GetFont()), 17)
I.Set("zone", "size", 20)
check("own size scaled too", select(2, T.zone:GetFont()), 30)
ns.DB().infoScale, ns.DB().infos = nil, nil
I.Apply()
check("back to 11", select(2, T.zone:GetFont()), 11)

section("Texts on the map: older profiles")
ns.DB().showPerf = false
ns.DB().perfNudgeX = -12
check("old switch off: perf off", I.Get("perf", "show"), false)
check("old shift: added to X", I.Get("perf", "x"), -16)
I.Set("perf", "x", -8)
check("a new value wins", I.Get("perf", "x"), -8)
ns.DB().showPerf, ns.DB().perfNudgeX, ns.DB().infos = nil, nil, nil
I.Apply()

section("Minimap button")
local B = ns.MinimapButton
local button = M.byName["ForeverSquareMinimapButton"]
local function buttonAt() local a = button._anchor; return a[4], a[5] end
check("created", button ~= nil, true)
check("on the map", button._anchor[2], Minimap)
check("shown by default", button:IsShown(), true)
check("game icon, no own art", B.button.icon ~= nil, true)
-- 260 px map: half 130, 5 px outside; angle 7 lies on the right edge.
local bx, by = buttonAt()
check("default: right edge", close(bx, 135), true)
check("default: a little above the middle", by > 0 and by < 40, true)
B.Set("angle", 90)
bx, by = buttonAt()
check("90 degrees: top edge", close(by, 135), true)
check("90 degrees: centred", math.abs(bx) < 1e-6, true)
check("angle in the profile", ns.DB().buttonAngle, 90)
-- Dragging: follows the cursor around the map's centre (1770/670).
M.state.cursor = { 1770 + 50, 670 }
button:GetScript("OnDragStart")(button)
button:GetScript("OnUpdate")(button, 0.1)
bx, by = buttonAt()
check("dragged to the right edge", close(bx, 135) and math.abs(by) < 1e-6, true)
button:GetScript("OnDragStop")(button)
check("angle stored on release", ns.DB().buttonAngle, 0)
check("no longer following", button:GetScript("OnUpdate"), nil)
-- Click opens the addon's own options window (it opens in combat too;
-- Blizzard's settings panel would not).
button:GetScript("OnClick")(button)
check("click opens the options", ns.Window.IsShown(), true)
ForeverSquareMinimap_OnAddonCompartmentClick("ForeverSquareMinimap", "LeftButton")
check("addon compartment toggles them too", ns.Window.IsShown(), false)
M.state.combat = true
button:GetScript("OnClick")(button)
check("opens in combat", ns.Window.IsShown(), true)
M.state.combat = false
ns.Window.Toggle()
local tocText = io.open(ROOT .. "/" .. ADDON .. ".toc"):read("*a")
check("TOC names the compartment function", tocText:find("AddonCompartmentFunc: ForeverSquareMinimap_OnAddonCompartmentClick", 1, true) ~= nil, true)
B.Set("show", false)
check("can be switched off", button:IsShown(), false)
check("switch in the profile", ns.DB().buttonShow, false)
ns.DB().buttonShow, ns.DB().buttonAngle = nil, nil
ns.api.ApplyLook()
check("profile change: shown again", button:IsShown(), true)
bx = buttonAt()
check("profile change: default place", close(bx, 135), true)
for _, loc in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, key in ipairs({ "OPT_BUTTON", "OPT_BUTTON_SHOW", "BUTTON_CLICK", "BUTTON_DRAG" }) do
        check(loc .. " " .. key, type(ns.Locales[loc][key]), "string")
    end
end

local function colAnchor(n) return _G[n]._anchor end

section("Mail icon: settings")
local Mail = ns.Mail
local mailFrame = MiniMapMailFrame
check("Blizzard's frame used here", Mail.Frame(), mailFrame)
check("above the border", M.level["MiniMapMailFrame"], 3 + Mail.LEVEL_ABOVE_MAP)
Mail.SetPreview(true)
check("test view shows it", mailFrame:IsShown(), true)
ns.DB().mail = nil
Mail.Apply()
check("default: glows", Mail.Get("anim"), "GLOW")
local ma = colAnchor("MiniMapMailFrame")
check("default: past the top left corner", ma[1] .. ">" .. ma[3], "TOPLEFT>TOPLEFT")
check("default: offsets", ma[4] .. "," .. ma[5], "-13,2")
Mail.Set("scale", 200)
ma = colAnchor("MiniMapMailFrame")
check("scaled", mailFrame:GetScale(), 2)
check("free: offsets stay pixels", ma[4] .. "," .. ma[5], "-6.5,1")
Mail.Set("show", false)
check("off: still visible during the test", mailFrame:GetAlpha(), 1)
Mail.SetPreview(false)
check("test over: hidden again", mailFrame:IsShown(), false)
check("off: invisible", mailFrame:GetAlpha(), 0)
ns.DB().mail = nil
Mail.Apply()
check("defaults back", mailFrame:GetScale(), 1)
-- The animation's frames: size, lift, glow.
local sc, dy, gl = Mail.AnimFrame("PULSE", 0.3)
check("pulse grows", sc > 1.1 and dy == 0 and gl == 0, true)
sc, dy = Mail.AnimFrame("BOUNCE", 0.15)
check("bounce lifts", sc == 1 and dy > 5, true)
sc, dy = Mail.AnimFrame("BOUNCE", 1.5)
check("bounce rests", dy, 0)
sc, dy, gl = Mail.AnimFrame("GLOW", 0.35)
check("glow lights", gl > 0.9, true)
check("none is still", select(3, Mail.AnimFrame("NONE", 1)) == 0 and Mail.AnimFrame("NONE", 1) == 1, true)

section("Opacity")
local Fade = ns.Fade
check("default: opaque", Fade.Target(false, false), 1)
check("default: opaque in combat", Fade.Target(true, false), 1)
Fade.Set("alpha", 60)
Fade.Set("combatAlpha", 0)
check("out of combat", Fade.Target(false, false), 0.6)
check("in combat", Fade.Target(true, false), 0)
check("under the mouse: full", Fade.Target(true, true), 1)
Fade.Set("mouseover", false)
check("mouse ignored when off", Fade.Target(true, true), 0)
check("applied to the map", Minimap:GetAlpha(), 0.6)
ns.DB().fade = nil
Fade.Apply()
check("back to opaque", Minimap:GetAlpha(), 1)

section("Coordinates")
check("text", ns.CoordsText(0.4567, 0.1234), "45.7, 12.3")
check("no position: empty", ns.CoordsText(nil, nil), "")
check("instance (0,0): empty", ns.CoordsText(0, 0), "")
C_Map = { GetBestMapForUnit = function() return 1446 end,
          GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end }
I.Set("coords", "show", true)
check("shown when on", I.texts.coords:IsShown(), true)
check("filled", I.texts.coords._text, "50.0, 25.0")
C_Map = { GetBestMapForUnit = function() error("no map") end }
I.UpdateCoords()
check("API error: empty, no error", I.texts.coords._text, "")
C_Map = nil
ns.DB().infos = nil
I.Apply()

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
check("default: 53 px up", dy - by, 53)
check("default: 8 px right", dx - bx, 8)

section("Cluster and decoration")
check("minimap on UIParent", M.reparented["Minimap"], "UIParent")
check("cluster hidden", M.hidden["MinimapCluster"], true)
check("backdrop hidden", M.hidden["MinimapBackdrop"], true)
check("red X hidden", M.hidden["MinimapToggleButton"], true)
check("world map button hidden", M.hidden["MiniMapWorldMapButton"], true)
check("instance info on the minimap", M.placed["MiniMapInstanceDifficulty"][4], "Minimap")
check("missing frames do not matter", Minimap:GetWidth(), 260)

section("Size limits")
slash("size 250")
check("250", Minimap:GetWidth(), 250)
slash("size 40")
check("below the minimum -> 100", Minimap:GetWidth(), 100)
slash("size 9999")
check("above the maximum -> 400", Minimap:GetWidth(), 400)
slash("reset")
check("reset -> 260", Minimap:GetWidth(), 260)
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
check("default: gold, two pixels (factor 0.8)", close(ring[1]._h, 1.6), true)
check("default: gold has the inner line", line[1]._shown, true)
ns.DB().borderStyle, ns.DB().borderSize = "FLAT", 1
ns.api.ApplyBorder()
check("flat: black", ring[1]._color and ring[1]._color[1], 0)
check("flat: one pixel (factor 0.8)", close(ring[1]._h, 0.8), true)
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
check("local time bottom centre", localTime and M.placed[localTime][1], "BOTTOM")
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

section("Options window")
ns.Window.Open()
check("five pages", ns.Window.PageCount(), 5)
check("first page shown", M.byName["ForeverSquareMinimapPage1"]:IsShown(), true)
ns.Window.ShowPage(5)
check("mail page shown", M.byName["ForeverSquareMinimapPage5"]:IsShown(), true)
check("the first one hidden", M.byName["ForeverSquareMinimapPage1"]:IsShown(), false)
ns.Window.ShowPage(1)

-- The options page follows a language change at once.
local function shown(want)
    for _, fs in ipairs(M.fontStrings) do if fs._text == want then return true end end
    for _, f in ipairs(M.frames) do if f._text == want then return true end end
    return false
end
check("options in English", shown("FPS & coordinates"), true)
ns.Locale.Set("deDE")
check("setting stored account wide", ForeverSquareMinimapProfiles.language, "deDE")
check("options in German", shown("FPS & Koordinaten"), true)
check("buttons too", shown("Löschen"), true)
M.chat = {}
slash("size 200")
check("chat in German", (M.chat[1] or ""):find("Größe: 200 px", 1, true) ~= nil, true)
ns.AskProfileName()
check("dialogs in German", M.popups[#M.popups].text, "Name des neuen Profils:")
ns.Locale.Set("AUTO")
check("AUTO stores nothing", ForeverSquareMinimapProfiles.language, nil)
check("back to the game's language", shown("FPS & coordinates"), true)
-- Loaded with a stored language, it applies at ADDON_LOADED.
ForeverSquareMinimapProfiles.language = "frFR"
ns.Locale.Apply()
check("stored language applied", ns.Locale.Current(), "frFR")
check("French strings", ns.L.OPT_BORDER, "Bordure")
ns.Locale.Set("AUTO")

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
