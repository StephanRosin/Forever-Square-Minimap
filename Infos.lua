--[[---------------------------------------------------------------------------
Infos.lua -- the texts on and around the map: zone, server time, local time,
FPS and latency, coordinates.

Each one can be switched off, placed anywhere (a point on the map, or below
the zone text for the server time, the text's own point, X/Y offset, so also
outside the map), and has its own font and size. FPS and latency are two
texts that sit on top of each other or side by side, with a gap between them.

Font "Default" and size "Auto" mean the game font the text is made with
(GameFontNormal for the zone, GameFontNormalSmall for the rest), with an
outline.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

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
    zone = { show = true, anchor = "MAP", mapPoint = "TOP", point = "TOP", x = 0, y = 0,
        font = "Friz Quadrata", size = 11 },
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

-- The choices for the font dropdown: key and path of every font.
function Infos.FontList()
    local list, seen = {}, {}
    for _, f in ipairs(Infos.FONTS) do
        list[#list + 1] = f
        seen[f.key] = true
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

local function fontPath(key)
    for _, f in ipairs(Infos.FontList()) do
        if f.key == key then return f.path end
    end
    return nil
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

local function styleFont(fs, kind)
    local path = fontPath(Infos.Get(kind, "font")) or fs.baseFont
    local size = Infos.Get(kind, "size")
    if not size or size <= 0 then size = fs.baseSize end
    if size then size = math.max(4, math.floor(size * Infos.Scale() / 100 + 0.5)) end
    if path and size then fs:SetFont(path, size, "OUTLINE") end
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
    texts.zone:SetText(zone)

    -- GetGameTime is the server time, the one Blizzard's clock showed.
    local hour, minute
    if GetGameTime then hour, minute = GetGameTime() end
    if hour and minute then
        texts.server:SetText(("%02d:%02d"):format(hour, minute))
    else
        texts.server:SetText(date("%H:%M"))
    end
    texts["local"]:SetText(date("%H:%M"))
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
