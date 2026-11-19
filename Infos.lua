--[[---------------------------------------------------------------------------
Infos.lua -- the texts on and around the map: zone, server time, local time,
FPS and latency, coordinates. Also the zone's control icon and tooltip.

Each one can be switched off, placed anywhere (a point on the map, or below
the zone text for the server time, the text's own point, X/Y offset, so also
outside the map), and has its own font and size. FPS and latency are two
texts that sit on top of each other or side by side, with a gap between them.

Font "Default" and size "Auto" mean the game font the text is made with
(GameFontNormal for the zone, GameFontNormalSmall for the rest), with an
outline.
-----------------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L

local Infos = {}
ns.Infos = Infos

Infos.KINDS = { "zone", "server", "local", "perf", "coords" }

-- The game font each text was made with; "Auto" size and "Default" font
-- come from it.
local TEMPLATE = { zone = "GameFontNormal", server = "GameFontNormalSmall", ["local"] = "GameFontNormalSmall",
    perf = "GameFontNormalSmall", coords = "GameFontNormalSmall" }

-- The defaults: zone on top, local time bottom centre, FPS and latency in
-- the top right corner, coordinates in the bottom left one.
Infos.DEFAULTS = {
    -- pvpIcon off: an update must not change the text existing users see.
    zone = { show = true, anchor = "MAP", mapPoint = "TOP", point = "TOP", x = 0, y = 0,
        font = "Friz Quadrata", size = 11, pvpIcon = false },
    -- Right under the zone text; moves with it when the zone text grows.
    server = { show = true, anchor = "ZONE", mapPoint = "BOTTOM", point = "TOP", x = 0, y = -1,
        font = "DEFAULT", size = 11 },
    ["local"] = { show = true, anchor = "MAP", mapPoint = "BOTTOM", point = "BOTTOM", x = 0, y = 0,
        font = "DEFAULT", size = 11 },
    perf = { show = true, anchor = "MAP", mapPoint = "TOPRIGHT", point = "TOPRIGHT", x = 0, y = 0,
        font = "DEFAULT", size = 11, layout = "STACKED", gap = 0 },
    coords = { show = true, anchor = "MAP", mapPoint = "BOTTOMLEFT", point = "BOTTOMLEFT", x = 0, y = 0,
        font = "DEFAULT", size = 11 },
}

Infos.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

-- Fonts the game ships; more come from LibSharedMedia when another addon
-- provides it.
Infos.FONTS = {
    { key = "DEFAULT" },
    { key = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { key = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
}

-- The themes' fonts come with the embedded LibForeverThemes (SIL Open
-- Font License, see its Media/Fonts), which also loads them early. Read at
-- use: a newer copy of the library loading after us replaces the list.
local Lib = LibForeverThemes

-- The choices for the font dropdown: key and path of every font.
function Infos.FontList()
    local list, seen = {}, {}
    for _, f in ipairs(Infos.FONTS) do
        list[#list + 1] = f
        seen[f.key] = true
    end
    for _, f in ipairs(Lib.FONTS) do
        list[#list + 1] = { key = f.name, path = f.path }
        seen[f.name] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = LSM:List("font") or {}
        table.sort(names)
        for _, name in ipairs(names) do
            if not seen[name] then
                list[#list + 1] = { key = name, path = LSM:Fetch("font", name) }
                seen[name] = true
            end
        end
    end
    return list
end

-- A font's file: the list's first, then the library's (a font stored under
-- an older name, LibForeverThemes' aliases, finds its file there).
local function fontPath(key)
    for _, f in ipairs(Infos.FontList()) do
        if f.key == key then return f.path end
    end
    return Lib.FontPath(key)
end

-- Settings ------------------------------------------------------------------
-- In the active profile under infos[kind][field]; missing ones come from the
-- defaults. Older profiles had "showPerf" and "perfNudgeX" (a shift of the
-- FPS display): they are read as the perf text's switch and X.
function Infos.Get(kind, field)
    local db = ns.DB()
    local own = db.infos and db.infos[kind]
    local v = own and own[field]
    if v ~= nil then return v end
    if kind == "perf" and field == "show" and db.showPerf == false then return false end
    if kind == "perf" and field == "x" and type(db.perfNudgeX) == "number" then
        -- The shift was from the old place, 4 px in from the corner.
        return -4 + db.perfNudgeX
    end
    return Infos.DEFAULTS[kind][field]
end

function Infos.Set(kind, field, value)
    local db = ns.DB()
    db.infos = db.infos or {}
    db.infos[kind] = db.infos[kind] or {}
    db.infos[kind][field] = value
    Infos.Apply()
    Infos.Update()
end

-- FPS and latency text --------------------------------------------------------
-- Pure functions: numbers in, text out, so the colours are testable without
-- a game. Below 30 frames the game stutters visibly, above 250 ms every
-- ability feels late.
local PERF = {
    fpsGood = 60, fpsFair = 30,
    pingGood = 100, pingFair = 250,
    green = "ff40ff40", yellow = "ffffd000", red = "ffff4040",
}

local function Colour(value, good, fair, lowerIsBetter)
    if not value then return PERF.red end
    if lowerIsBetter then
        if value <= good then return PERF.green end
        if value <= fair then return PERF.yellow end
    else
        if value >= good then return PERF.green end
        if value >= fair then return PERF.yellow end
    end
    return PERF.red
end

-- The two texts; fps and ping may be nil (the client reports latency only
-- once it has measured it): a dash then instead of a made-up number.
function ns.PerfParts(fps, ping)
    local f = type(fps) == "number" and math.floor(fps + 0.5) or nil
    local p = type(ping) == "number" and math.floor(ping + 0.5) or nil
    local top = f and ("|c%s%d|r"):format(Colour(f, PERF.fpsGood, PERF.fpsFair, false), f)
                  or "|c" .. PERF.red .. "--|r"
    local bottom = p and ("|c%s%d|r"):format(Colour(p, PERF.pingGood, PERF.pingFair, true), p)
                     or "|c" .. PERF.red .. "--|r"
    return top .. " fps", bottom .. " ms"
end

-- Both in one text, one per line (as the display looks by default).
function ns.PerfText(fps, ping)
    local a, b = ns.PerfParts(fps, ping)
    return a .. "\n" .. b
end

-- Zone control ---------------------------------------------------------------
-- Forever's server reports no PvP status (C_PvP.GetZonePVPInfo is empty, seen
-- in game 19.11.2026), so the classic split is kept here by uiMapID (Forever
-- uses the classic IDs; checked against OpenMap's Forever zone list): the
-- starting zones and capitals belong to a faction, the rest of the world is
-- contested. Forever's own zones: Riverglades (2548) contested, Zephras Isle
-- (2521, the Skyborne's start) a sanctuary (warcraft.wiki.gg), shown only in
-- the tooltip. Not listed (no icon): instances and Moonglade.
local ALLIANCE, HORDE, CONTESTED, SANCTUARY = "Alliance", "Horde", "Contested", "Sanctuary"
Infos.ZONE_CONTROL = {
    -- Dun Morogh, Elwynn Forest, Loch Modan, Westfall, Teldrassil, Darkshore,
    -- Stormwind, Ironforge, Darnassus
    [1426] = ALLIANCE, [1429] = ALLIANCE, [1432] = ALLIANCE, [1436] = ALLIANCE, [1438] = ALLIANCE,
    [1439] = ALLIANCE, [1453] = ALLIANCE, [1455] = ALLIANCE, [1457] = ALLIANCE,
    -- Durotar, Mulgore, The Barrens, Tirisfal Glades, Silverpine Forest,
    -- Orgrimmar, Thunder Bluff, Undercity
    [1411] = HORDE, [1412] = HORDE, [1413] = HORDE, [1420] = HORDE, [1421] = HORDE,
    [1454] = HORDE, [1456] = HORDE, [1458] = HORDE,
    [2521] = SANCTUARY,
}
-- Alterac Mountains .. Wetlands, Ashenvale .. Winterspring without the ones
-- above and Moonglade (1450).
for _, id in ipairs({ 1416, 1417, 1418, 1419, 1422, 1423, 1424, 1425, 1427, 1428, 1430, 1431, 1433, 1434,
        1435, 1437, 1440, 1441, 1442, 1443, 1444, 1445, 1446, 1447, 1448, 1449, 1451, 1452, 2548 }) do
    Infos.ZONE_CONTROL[id] = CONTESTED
end

-- Blizzard's small group crests and the battleground's crossed swords (the
-- left upper quarter of its texture), inline at the text's height.
local ZONE_ICONS = {
    [ALLIANCE] = "|TInterface\\GroupFrame\\UI-Group-PVP-Alliance:0|t",
    [HORDE] = "|TInterface\\GroupFrame\\UI-Group-PVP-Horde:0|t",
    [CONTESTED] = "|TInterface\\WorldStateFrame\\CombatSwords:0:0:0:0:64:64:0:32:0:32|t",
}

local function currentMap()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

-- The zone text with the control icon behind it; plain where the map is not
-- in the table.
function ns.ZoneWithIcon(zone, mapID)
    local icon = ZONE_ICONS[Infos.ZONE_CONTROL[mapID]]
    if not icon then return zone end
    return zone .. " " .. icon
end

-- The tooltip as lines { text, r, g, b }: the zone in white, then the subzone
-- and who controls it, green for the player's side, red for the other,
-- orange contested (Blizzard's colours). Pure; labels are Blizzard's strings,
-- passed in so the test needs no globals.
local GOLD, GREEN, RED, ORANGE, BLUE = { 1, 0.82, 0 }, { 0.1, 1, 0.1 }, { 1, 0.1, 0.1 }, { 1, 0.7, 0 },
    { 0.41, 0.8, 0.94 }
function ns.ZoneTooltipLines(control, playerFaction, zone, subzone, labels)
    if subzone == zone then subzone = "" end
    local lines = { { zone or "", 1, 1, 1 } }
    local c, status = GOLD, nil
    if control == CONTESTED then
        c, status = ORANGE, labels.CONTESTED_TERRITORY
    elseif control == SANCTUARY then
        c, status = BLUE, labels.SANCTUARY_TERRITORY
    elseif control then
        c = control == playerFaction and GREEN or RED
        local name = control == ALLIANCE and labels.FACTION_ALLIANCE or labels.FACTION_HORDE
        status = (labels.FACTION_CONTROLLED_TERRITORY or "(%s)"):format(name or control)
    end
    if subzone ~= "" then lines[#lines + 1] = { subzone, c[1], c[2], c[3] } end
    if status then lines[#lines + 1] = { status, c[1], c[2], c[3] } end
    return lines
end

local function showZoneTooltip(owner)
    local labels = {}
    for _, key in ipairs({ "CONTESTED_TERRITORY", "SANCTUARY_TERRITORY", "FACTION_CONTROLLED_TERRITORY", "FACTION_ALLIANCE", "FACTION_HORDE" }) do
        labels[key] = _G[key]
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    for _, line in ipairs(ns.ZoneTooltipLines(Infos.ZONE_CONTROL[currentMap()], faction,
            GetZoneText and GetZoneText(), GetSubZoneText and GetSubZoneText(), labels)) do
        GameTooltip:AddLine(line[1], line[2], line[3], line[4])
    end
    GameTooltip:Show()
end

-- The texts ------------------------------------------------------------------
-- Created once, inside the map's frame (so they hide with it), then styled
-- and placed by Apply and filled by Update.
local texts = {}
Infos.texts = texts

local function newText(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    -- The template's font, remembered for "Default" and "Auto".
    local path, size = fs:GetFont()
    fs.baseFont, fs.baseSize = path, size
    return fs
end

function Infos.Create()
    if texts.zone then return end
    for _, kind in ipairs({ "zone", "server", "local", "coords" }) do
        texts[kind] = newText(Minimap, TEMPLATE[kind])
    end
    -- FPS and latency: two texts on a holder that is as big as both, so the
    -- pair can be placed like one text.
    local holder = CreateFrame("Frame", nil, Minimap)
    holder.fps = newText(holder, TEMPLATE.perf)
    holder.ms = newText(holder, TEMPLATE.perf)
    texts.perf = holder
    -- Hover area over the zone text for its tooltip. Motion only: a click
    -- there still pings the map, the wheel still zooms.
    local hover = CreateFrame("Frame", nil, Minimap)
    hover:SetAllPoints(texts.zone)
    if hover.SetMouseClickEnabled then
        hover:SetMouseMotionEnabled(true)
        hover:SetMouseClickEnabled(false)
    else
        hover:EnableMouse(true)
    end
    hover:SetScript("OnEnter", showZoneTooltip)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    texts.zoneHover = hover
    -- The coordinates change while you walk: five times a second, and only
    -- while they show. On the map, not the text: a frame cannot hang from a
    -- font string.
    local driver = CreateFrame("Frame", nil, Minimap)
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if texts.coords:IsShown() then Infos.UpdateCoords() end
    end)
    Infos.Apply()
end

-- The player's position on the zone map in percent, one decimal; empty where
-- the map has none (instances). Pure apart from the API: x and y 0..1.
function ns.CoordsText(x, y)
    if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return "" end
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

function Infos.UpdateCoords()
    if not texts.coords then return end
    local x, y
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(function()
            local map = C_Map.GetBestMapForUnit("player")
            return map and C_Map.GetPlayerMapPosition(map, "player")
        end)
        if ok and pos and pos.GetXY then x, y = pos:GetXY() end
    end
    texts.coords:SetText(ns.CoordsText(x, y))
end

-- Horizontal alignment from a point: left, right or centred.
local function justifyOf(point)
    if point:find("LEFT") then return "LEFT" end
    if point:find("RIGHT") then return "RIGHT" end
    return "CENTER"
end

-- One scale for all texts, in %: bigger or smaller together, each keeping
-- its size relative to the others.
function Infos.Scale()
    local v = ns.DB().infoScale
    if type(v) ~= "number" or v <= 0 then return 100 end
    return v
end

function Infos.SetScale(v)
    ns.DB().infoScale = v
    Infos.Apply()
    Infos.Update()
end

-- Both clocks in one format: "24" (21:07) or "12" (9:07 PM). Blizzard's
-- own strings for AM/PM, so the suffix follows the game language.
function Infos.ClockFormat()
    return ns.DB().clock == "12" and "12" or "24"
end

function Infos.SetClockFormat(v)
    ns.DB().clock = v
    Infos.Update()
end

function Infos.FormatTime(hour, minute)
    if Infos.ClockFormat() == "24" then return ("%02d:%02d"):format(hour, minute) end
    local pattern = hour < 12 and (TIME_TWELVEHOURAM or "%d:%02d AM") or (TIME_TWELVEHOURPM or "%d:%02d PM")
    local h = hour % 12
    if h == 0 then h = 12 end
    return pattern:format(h, minute)
end

-- Whether a text took the font asked for. A font file the client has not
-- loaded yet (the themes' own) can be refused on first use and leave the
-- text without a font.
local function hasFont(fs, path)
    local got = fs:GetFont()
    if type(got) ~= "string" then return false end
    local function plain(p) return (p:lower():gsub("/", "\\")) end
    return plain(got) == plain(path)
end
-- How often, and how far apart, a refused font is tried again.
local FONT_RETRIES, FONT_RETRY_DELAY = 40, 0.25

-- A font file used for the first time can leave a text blank although
-- GetFont reports it (seen in game: empty texts until the theme was
-- chosen a second time). Setting it again a little later, through another
-- font, as that second choice did, draws them. Once per text and font.
-- First use of a file can take seconds when many fonts load at once
-- (theme switch); report each file only once.
local refusedFonts = {}

local REDRAW_DELAYS = { 0.5, 2 }
local function redrawLater(fs, path, size, flags, wanted)
    if fs.fontDrawn == wanted then return end
    fs.fontDrawn = wanted
    for _, delay in ipairs(REDRAW_DELAYS) do
        C_Timer.After(delay, function()
            if fs.fontWanted ~= wanted then return end
            fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
            fs:SetFont(path, size, flags)
            local text = fs:GetText()
            if text then fs:SetText(""); fs:SetText(text) end
        end)
    end
end

local function setFont(fs, path, size, flags, retries)
    fs:SetFont(path, size, flags)
    local wanted = path .. "|" .. size .. "|" .. flags
    fs.fontWanted = wanted
    if hasFont(fs, path) then
        redrawLater(fs, path, size, flags, wanted)
        return
    end
    retries = retries or FONT_RETRIES
    if retries > 0 then
        C_Timer.After(FONT_RETRY_DELAY, function()
            -- Restyled since: that call has its own tries.
            if fs.fontWanted == wanted then setFont(fs, path, size, flags, retries - 1) end
        end)
    -- A hidden text never makes the client load a new file: no complaint,
    -- the next shown use loads it.
    elseif DEFAULT_CHAT_FRAME and fs:IsVisible() and not refusedFonts[path] then
        refusedFonts[path] = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff70c0ff" .. L.ADDON_NAME .. ":|r " .. L.MSG_FONT_REFUSED:format(path))
    end
end

local function styleFont(fs, kind)
    local path = fontPath(Infos.Get(kind, "font")) or fs.baseFont
    local size = Infos.Get(kind, "size")
    if not size or size <= 0 then size = fs.baseSize end
    if size then size = math.max(4, math.floor(size * Infos.Scale() / 100 + 0.5)) end
    -- The client's own outline; a theme may want it thicker.
    local flags = ns.Themes.Spec(ns.Themes.Current()).outline or "OUTLINE"
    if path and size then setFont(fs, path, size, flags) end
end

local function anchorFrame(kind)
    if kind ~= "zone" and Infos.Get(kind, "anchor") == "ZONE" and texts.zone then return texts.zone end
    return Minimap
end

-- Size, font and place of every text; also when a setting changes.
function Infos.Apply()
    if not texts.zone then return end
    for _, kind in ipairs(Infos.KINDS) do
        local region = texts[kind]
        local point = Infos.Get(kind, "point")
        if kind == "perf" then
            styleFont(region.fps, kind)
            styleFont(region.ms, kind)
        else
            styleFont(region, kind)
            region:SetJustifyH(justifyOf(point))
        end
        region:ClearAllPoints()
        region:SetPoint(point, anchorFrame(kind), Infos.Get(kind, "mapPoint"), Infos.Get(kind, "x"),
            Infos.Get(kind, "y"))
        region:SetShown(Infos.Get(kind, "show"))
    end
    texts.zoneHover:SetShown(Infos.Get("zone", "show"))
end

-- The FPS and latency pair inside its holder: on top of each other (aligned
-- to the side the holder is anchored on) or side by side, gap apart.
local function layoutPerf(holder)
    local fps, ms = holder.fps, holder.ms
    local gap = Infos.Get("perf", "gap")
    local w1, w2 = fps:GetStringWidth() or 0, ms:GetStringWidth() or 0
    local h1, h2 = fps:GetStringHeight() or 0, ms:GetStringHeight() or 0
    fps:ClearAllPoints()
    ms:ClearAllPoints()
    if Infos.Get("perf", "layout") == "SIDE" then
        holder:SetSize(math.max(1, w1 + gap + w2), math.max(1, h1, h2))
        fps:SetPoint("LEFT", holder, "LEFT", 0, 0)
        ms:SetPoint("LEFT", fps, "RIGHT", gap, 0)
        return
    end
    holder:SetSize(math.max(1, w1, w2), math.max(1, h1 + gap + h2))
    local side = justifyOf(Infos.Get("perf", "point"))
    local top = side == "CENTER" and "TOP" or "TOP" .. side
    local bottom = side == "CENTER" and "BOTTOM" or "BOTTOM" .. side
    fps:SetPoint(top, holder, top, 0, 0)
    ms:SetPoint(bottom, holder, bottom, 0, 0)
    fps:SetJustifyH(side)
    ms:SetJustifyH(side)
end

-- The contents, once a second.
function Infos.Update()
    if not texts.zone then return end
    local zone = (GetMinimapZoneText and GetMinimapZoneText()) or (GetZoneText and GetZoneText()) or ""
    if Infos.Get("zone", "pvpIcon") then zone = ns.ZoneWithIcon(zone, currentMap()) end
    texts.zone:SetText(zone)

    -- GetGameTime is the server time, the one Blizzard's clock showed.
    local hour, minute
    if GetGameTime then hour, minute = GetGameTime() end
    local now = date("*t")
    if not (hour and minute) then hour, minute = now.hour, now.min end
    texts.server:SetText(Infos.FormatTime(hour, minute))
    texts["local"]:SetText(Infos.FormatTime(now.hour, now.min))
    Infos.UpdateCoords()

    if Infos.Get("perf", "show") then
        -- World latency is the one you feel while playing; home latency is
        -- chat and guild. If only one is there, take that.
        local fps = GetFramerate and GetFramerate() or nil
        local home, world
        if GetNetStats then
            local _, _, h, w = GetNetStats()
            home, world = h, w
        end
        local a, b = ns.PerfParts(fps, world or home)
        texts.perf.fps:SetText(a)
        texts.perf.ms:SetText(b)
        layoutPerf(texts.perf)
        texts.perf:Show()
    else
        texts.perf:Hide()
    end
end
