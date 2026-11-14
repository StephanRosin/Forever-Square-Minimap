--[[---------------------------------------------------------------------------
Themes.lua -- a look for the map, and a whole set of settings each (beta).

Built after Forever Unit Frames' themes, with the same ids and looks, but its
own choice: the two addons do not follow each other.

The profile's `theme` names the one in use (none = CLASSIC); the profile
holds its settings. The others wait in the profile's `themeSets`, one copy
per theme. CLASSIC is the player's own setup as it was before themes: it is
never changed by another theme, so going back to it restores every setting.

A theme chosen the first time starts from the CLASSIC set (size, position,
texts: everything the player arranged) with the theme's look on top: the
border, the texts' font, and the art in ThemeArt.lua (backdrop round the map,
corner ornaments, solid shadow).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Themes = {}
ns.Themes = Themes

Themes.CLASSIC = "CLASSIC"
-- The order of the choice. Stored is the id, not the place in this list.
Themes.IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL" }

-- The theme fonts have Latin letters only: on a client whose zone names are
-- written otherwise the texts keep their font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: settings the theme sets (the border, SquareMinimap.lua). font: the
-- font of the display text (the zone name, DISPLAY), fontSizeAdd: how much
-- larger it must be to read like the others. bodyFont: the font of the other
-- texts (clocks, FPS/ms, coordinates) where the theme font is unreadable at
-- small sizes (old-style figures, small caps, heavy letters); they keep the
-- player's size then. nil: the theme font. outline: the texts' outline flags; always the
-- client's own, never copies of the text behind it (with the theme fonts
-- those showed black text in Forever Unit Frames).
-- art (ThemeArt.lua): back = backdrop file in Media/Themes, shown in the
-- padding between map and border; tint = its colour; ornament = corner
-- piece, corners = which ones (1 top left, 2 top right, 3 bottom left, 4
-- bottom right), ornamentInset = how far in from the border's outer corner
-- (never out: nothing reaches past Classic's edge); hardShadow = offset of
-- a solid shadow. The map is drawn smaller by what all this reaches out
-- further than Classic's border (SquareMinimap.lua, ThemeInset).
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards round the map, a brass rim, brass rivets.
    WOOD = {
        font = "Cinzel",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.72, 0.53, 0.24, 1 } },
        art = { back = "WoodBack", padding = 5, ornament = "Rivet", corners = { 1, 2, 3, 4 }, ornamentSize = 10,
            ornamentInset = 0 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        font = "Space Grotesk",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.25, 0.88, 0.94, 0.9 } },
        art = { back = "TechBack", padding = 4 },
    },
    -- Parchment round the map, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", bodyFont = "Friz Quadrata", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 } },
        art = { back = "ParchmentBack", tint = { 0.85, 0.82, 0.78, 1 }, padding = 5, ornament = "Seal", corners = { 3 }, ornamentSize = 14,
            ornamentInset = 0 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.1, 0.1, 0.12, 1 } },
        art = { back = "StoneBack", padding = 6, ornament = "Rune", corners = { 1, 2 }, ornamentSize = 10,
            ornamentInset = 0, ornamentColor = { 0.35, 0.95, 0.85, 1 } },
    },
    -- A mosaic of coloured glass round the map, dark lead.
    GLASS = {
        font = "Morpheus", bodyFont = "Friz Quadrata", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 } },
        art = { back = "GlassBack", padding = 7 },
    },
    -- Thick ink line, halftone paper (grey as in the other Forever addons),
    -- a solid shadow.
    COMIC = {
        font = "Bangers", bodyFont = "Friz Quadrata", fontSizeAdd = 2, outline = "THICKOUTLINE",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.07, 0.07, 1 } },
        art = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, padding = 3 },
    },
    -- Translucent ice, quieted (its cracks are busy), a pale rim.
    FROST = {
        font = "Cormorant SC", bodyFont = "Friz Quadrata", fontSizeAdd = 2,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.86, 0.96, 1, 0.8 } },
        art = { back = "FrostBack", padding = 3, tint = { 0.6, 0.66, 0.72, 0.75 } },
    },
    -- A light pixel frame, scan lines, a solid shadow.
    PIXEL = {
        font = "VT323", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 } },
        art = { back = "PixelBack", padding = 3 },
    },
}

-- Raised whenever SPECS change a look: theme sets made before are made anew
-- from CLASSIC (Themes.Upgrade), so a changed theme shows as it is now.
-- CLASSIC is never touched.
Themes.REVISION = 2

-- The texts in the theme font; the others are body text (bodyFont).
local DISPLAY = { zone = true }

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

function Themes.Current()
    local id = ns.DB().theme
    return Themes.SPECS[id] and id or Themes.CLASSIC
end

function Themes.Spec(id)
    return Themes.SPECS[id] or Themes.SPECS.CLASSIC
end

-- The active profile's stored theme sets; stale ones (an older REVISION)
-- dropped.
local function storedSets()
    local db = ns.DB()
    local sets = db.themeSets
    if type(sets) ~= "table" then
        sets = { revision = Themes.REVISION }
        db.themeSets = sets
    end
    if sets.revision ~= Themes.REVISION then
        for _, id in ipairs(Themes.IDS) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        sets.revision = Themes.REVISION
    end
    return sets
end

-- The stored Classic settings while a theme is in use (the defaults if none
-- was stored); nil on Classic.
function Themes.ClassicSet()
    if Themes.Current() == Themes.CLASSIC then return nil end
    return storedSets()[Themes.CLASSIC] or {}
end

-- The live settings as a set: the profile without the stored sets.
local function snapshot()
    local set = copy(ns.DB())
    set.themeSets = nil
    return set
end

-- A new theme's settings: the base set (CLASSIC) with the theme's look.
local function seed(id, base)
    local spec = Themes.Spec(id)
    local p = copy(base)
    p.themeSets = nil
    for key, value in pairs(spec.look or {}) do p[key] = copy(value) end
    local latin = spec.font and LATIN_CLIENTS[GetLocale()]
    p.infos = p.infos or {}
    for _, kind in ipairs(ns.Infos.KINDS) do
        local own = p.infos[kind] or {}
        p.infos[kind] = own
        local font, add = spec.font, spec.fontSizeAdd or 0
        if not DISPLAY[kind] and spec.bodyFont then font, add = spec.bodyFont, 0 end
        if latin then own.font = font end
        local size = own.size
        if size == nil then size = ns.Infos.DEFAULTS[kind].size end
        -- 0 is "Auto": the game font's size, left alone.
        if add ~= 0 and size > 0 then own.size = size + add end
    end
    p.theme = id
    return p
end

-- Restyling moves the map, its border and Blizzard's buttons on it.
local function refuse()
    if InCombatLockdown and InCombatLockdown() then return "COMBAT" end
    return nil
end

-- The set becomes the profile's settings, in place: the profile table stays
-- the same (characters point to it by name), its stored sets stay.
local function use(set)
    local db = ns.DB()
    local sets = db.themeSets
    for key in pairs(db) do db[key] = nil end
    for key, value in pairs(copy(set)) do db[key] = value end
    db.themeSets = sets
    if ns.api and ns.api.ApplyLook then ns.api.ApplyLook() end
end

-- Moves to theme id: the current settings are kept for the current theme,
-- id's come back (or are made, the first time). true, or nil and why not.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local why = refuse()
    if why then return nil, why end
    local current = Themes.Current()
    if id == current then return true end
    local sets = storedSets()
    sets[current] = snapshot()
    local nextSet = sets[id]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one (a
        -- profile copied while on a theme) the settings stay as they are.
        local base = sets[Themes.CLASSIC] or snapshot()
        nextSet = id == Themes.CLASSIC and copy(base) or seed(id, base)
    end
    nextSet.theme = id ~= Themes.CLASSIC and id or nil
    -- The live set is the profile: no stale copy stays behind.
    sets[id] = nil
    use(nextSet)
    return true
end

-- The current theme made anew from CLASSIC. Not for CLASSIC itself.
function Themes.Reset()
    local id = Themes.Current()
    if id == Themes.CLASSIC then return nil, "CLASSIC" end
    local why = refuse()
    if why then return nil, why end
    local base = storedSets()[Themes.CLASSIC]
    if not base then return nil, "NO_CLASSIC" end
    use(seed(id, base))
    return true
end

-- The themes with stored settings to copy from, in IDS order.
function Themes.Stored()
    -- Only looking: a profile that never had a theme gets no sets.
    if type(ns.DB().themeSets) ~= "table" then return {} end
    local sets, list = storedSets(), {}
    for _, id in ipairs(Themes.IDS) do
        if sets[id] and id ~= Themes.Current() then list[#list + 1] = id end
    end
    return list
end

-- Every setting that places something, as a path into the profile: the
-- map's position, each text's, the mail icon's, Blizzard's buttons', the
-- minimap button's angle. Sizes are no positions.
function Themes.PlacementKeys()
    local paths = { { "offsetX" }, { "offsetY" }, { "colNudge" }, { "colNudgeY" }, { "buttonAngle" } }
    local fields = { "anchor", "mapPoint", "point", "x", "y" }
    for _, kind in ipairs(ns.Infos.KINDS) do
        for _, field in ipairs(fields) do paths[#paths + 1] = { "infos", kind, field } end
    end
    for _, field in ipairs(fields) do paths[#paths + 1] = { "mail", field } end
    for _, kind in ipairs(ns.Buttons.KINDS) do
        for _, field in ipairs(fields) do paths[#paths + 1] = { "buttons", kind, field } end
    end
    return paths
end

local function getPath(t, path)
    for _, key in ipairs(path) do
        if type(t) ~= "table" then return nil end
        t = t[key]
    end
    return t
end

local function setPath(t, path, value)
    for i = 1, #path - 1 do
        local key = path[i]
        if type(t[key]) ~= "table" then
            if value == nil then return end
            t[key] = {}
        end
        t = t[key]
    end
    t[path[#path]] = copy(value)
end

-- Writes { path, value } pairs into the profile; returns what was there.
local function place(values)
    local db, old = ns.DB(), {}
    for i, pair in ipairs(values) do
        old[i] = { pair[1], copy(getPath(db, pair[1])) }
        setPath(db, pair[1], pair[2])
    end
    if ns.api and ns.api.ApplyLook then ns.api.ApplyLook() end
    return old
end

-- The positions of theme `from` taken over into the current one. Returns
-- what it replaced (Themes.Restore puts it back), or nil and why not.
function Themes.CopyPlacement(from)
    local why = refuse()
    if why then return nil, why end
    local source = storedSets()[from]
    if not source then return nil, "GONE" end
    local values = {}
    for i, path in ipairs(Themes.PlacementKeys()) do values[i] = { path, getPath(source, path) } end
    return place(values)
end

function Themes.Restore(undo)
    local why = refuse()
    if why then return nil, why end
    place(undo)
    return true
end

-- At login and after a profile switch, before the look is applied: a theme
-- in use made under an older REVISION is made anew from CLASSIC, quietly. A
-- profile that never had a theme is left alone.
function Themes.Upgrade()
    local db = ns.DB()
    local sets = db.themeSets
    if type(sets) ~= "table" or sets.revision == Themes.REVISION then return end
    local current = Themes.Current()
    local base = sets[Themes.CLASSIC]
    storedSets()
    if current == Themes.CLASSIC or not base then return end
    local fresh = seed(current, base)
    for key in pairs(db) do
        if key ~= "themeSets" then db[key] = nil end
    end
    for key, value in pairs(fresh) do db[key] = value end
end

-- For a theme picker in another addon (no link the other way): the same
-- switch as the choice in the options, with the open window refreshed.
_G.ForeverThemes = _G.ForeverThemes or {}
_G.ForeverThemes[ADDON] = {
    title = "Forever Square Minimap",
    Current = function() return Themes.Current() end,
    Switch = function(id)
        local ok, why = Themes.Switch(id)
        if ok and ns.RefreshOptions then ns.RefreshOptions() end
        return ok, why
    end,
}
