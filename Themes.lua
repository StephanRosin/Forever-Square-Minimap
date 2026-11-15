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
Themes.IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL", "SWISS",
    "CONSOLE", "PITWALL" }

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
-- those showed black text in Forever Unit Frames). Frost: "" (none), the
-- texts keep their font object's 1 px drop shadow (GameFontNormal*).
-- art (ThemeArt.lua): back = backdrop file in Media/Themes, shown in the
-- padding between map and border; tint = its colour; ornament = corner
-- piece, corners = which ones (1 top left, 2 top right, 3 bottom left, 4
-- bottom right), ornamentInset = how far in from the border's outer corner
-- (never out: nothing reaches past Classic's edge); hardShadow = offset of
-- a solid shadow; rule = a line ruleSize thick along the top, over the
-- border. The map is drawn smaller by what all this reaches out
-- further than Classic's border (SquareMinimap.lua, ThemeInset).
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards round the map, the family's gold ring, brass rivets.
    WOOD = {
        font = "Cinzel", bodyFont = "Friz Quadrata",
        look = { borderStyle = "GOLD", borderSize = 3 },
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
        font = "Cinzel", bodyFont = "Friz Quadrata", outline = "",
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.86, 0.96, 1, 0.8 } },
        art = { back = "FrostBack", padding = 3, tint = { 0.6, 0.66, 0.72, 0.75 } },
    },
    -- A light pixel frame, scan lines, a solid shadow.
    PIXEL = {
        font = "VT323", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 } },
        art = { back = "PixelBack", padding = 3 },
    },
    -- Swiss style: flat black, a grey hairline, one white rule along the top.
    SWISS = {
        font = "Inter Tight Bold", bodyFont = "Inter Tight",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.16, 0.16, 0.16, 1 } },
        art = { back = "SwissBack", padding = 4, rule = { 0.95, 0.95, 0.95, 1 }, ruleSize = 3 },
    },
    -- A terminal: near black with faint scan lines, a thin mint line.
    CONSOLE = {
        font = "IBM Plex Sans Condensed", bodyFont = "IBM Plex Mono",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.306, 0.929, 0.69, 1 } },
        art = { back = "ConsoleBack", padding = 4 },
    },
    -- A timing screen: flat black, a carbon hairline. No wedge: the map has no
    -- title row, and its top-left corner is the mail icon's.
    PITWALL = {
        font = "Titillium Web Bold Italic", bodyFont = "Titillium Web",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.043, 0.047, 0.055, 1 } },
        art = { back = "SwissBack", padding = 4 },
    },
}

-- Raised whenever SPECS change a look: theme sets made before are made anew
-- from CLASSIC (Themes.Upgrade), so a changed theme shows as it is now.
-- CLASSIC is never touched.
Themes.REVISION = 5

-- Each theme's colours, the same in every Forever addon (none for CLASSIC).
-- The first is the theme as it is. Any other draws the backdrop from the
-- theme's grey texture (<back>Grey), tinted so its mean lands on `back`
-- (vertex colour = back / GREY_MEAN, at most 1), and brings its accent
-- (nil: the theme's own). Themes with one dark backdrop in every colour
-- (SWISS, CONSOLE, PITWALL) change only the accent, the border or the wedge.
-- `rim` recolours the border: only CONSOLE's colours and Pixel's HANDHELD,
-- the same in every Forever addon.
-- The comic keeps its paper tint (COMIC_PAPER).
local GREY_MEAN = { WoodBack = 0.800, TechBack = 0.705, ParchmentBack = 0.799, StoneBack = 0.800,
    GlassBack = 0.777, FrostBack = 0.796, PixelBack = 0.800 }
local function colour(id, back, accent, rim, wedge)
    return { id = id, back = back, accent = accent, rim = rim, wedge = wedge }
end
Themes.COLORS = {
    WOOD = {
        colour("OAK"),
        colour("WALNUT", { 0.15, 0.09, 0.06 }),
        colour("BIRCH", { 0.38, 0.32, 0.22 }),
        colour("CHERRY", { 0.3, 0.12, 0.08 }),
        colour("EBONY", { 0.08, 0.07, 0.07 }),
        colour("DRIFTWOOD", { 0.25, 0.24, 0.22 }),
    },
    TECH = {
        colour("CYAN"),
        colour("GREEN", { 0.02, 0.1, 0.05 }, { 0.3, 0.95, 0.45 }),
        colour("AMBER", { 0.1, 0.07, 0.02 }, { 1, 0.75, 0.2 }),
        colour("MAGENTA", { 0.09, 0.03, 0.1 }, { 0.95, 0.4, 0.95 }),
        colour("BLUE", { 0.03, 0.05, 0.13 }, { 0.45, 0.65, 1 }),
        colour("GREY", { 0.07, 0.07, 0.08 }, { 0.85, 0.88, 0.9 }),
    },
    PARCHMENT = {
        colour("CLASSIC"),
        colour("AGED", { 0.32, 0.25, 0.15 }),
        colour("ASH", { 0.33, 0.33, 0.31 }),
        colour("SEA", { 0.25, 0.3, 0.33 }),
        colour("ROSE", { 0.36, 0.27, 0.26 }),
        colour("DARK", { 0.2, 0.17, 0.13 }),
    },
    RUNESTONE = {
        colour("GRANITE"),
        colour("SANDSTONE", { 0.33, 0.27, 0.18 }, { 1, 0.8, 0.35 }),
        colour("SLATE", { 0.15, 0.18, 0.25 }, { 0.55, 0.75, 1 }),
        colour("MOSS", { 0.15, 0.22, 0.14 }, { 0.5, 1, 0.45 }),
        colour("OBSIDIAN", { 0.07, 0.06, 0.09 }, { 0.75, 0.5, 1 }),
    },
    GLASS = {
        colour("CATHEDRAL"),
        colour("BLUE", { 0.08, 0.12, 0.28 }),
        colour("GREEN", { 0.07, 0.2, 0.1 }),
        colour("AMBER", { 0.28, 0.17, 0.05 }),
        colour("VIOLET", { 0.18, 0.08, 0.26 }),
        colour("RUBY", { 0.26, 0.05, 0.08 }),
    },
    FROST = {
        colour("ICE"),
        colour("DEEP", { 0.1, 0.18, 0.32 }, { 0.6, 0.85, 1 }),
        colour("AURORA", { 0.1, 0.27, 0.24 }, { 0.55, 1, 0.8 }),
        colour("VIOLET", { 0.22, 0.18, 0.33 }, { 0.85, 0.75, 1 }),
        colour("SILVER", { 0.3, 0.31, 0.33 }, { 0.92, 0.92, 0.95 }),
        colour("NIGHT", { 0.06, 0.08, 0.14 }, { 0.7, 0.85, 1 }),
    },
    PIXEL = {
        colour("NAVY"),
        colour("PLUM", { 0.23, 0.08, 0.16 }, { 1, 0.93, 0.15 }),
        colour("FOREST", { 0, 0.2, 0.12 }, { 1, 0.93, 0.15 }),
        colour("BROWN", { 0.2, 0.12, 0.08 }, { 1, 0.64, 0 }),
        colour("GREY", { 0.18, 0.17, 0.16 }),
        colour("BLACK", { 0.03, 0.03, 0.04 }, { 0, 0.89, 0.21 }),
        colour("TEAL", { 0.02, 0.17, 0.22 }, { 0.16, 0.68, 1 }),
        colour("PURPLE", { 0.15, 0.1, 0.25 }, { 1, 0.47, 0.66 }),
        colour("HANDHELD", { 0.06, 0.12, 0.06 }, { 0.784, 0.941, 0.439 }, { 0.784, 0.941, 0.439, 1 }),
    },
    SWISS = {
        colour("RED"),
        colour("BLUE", nil, { 0.18, 0.42, 1 }),
        colour("YELLOW", nil, { 1, 0.82, 0 }),
        colour("WHITE", nil, { 0.95, 0.95, 0.95 }),
    },
    CONSOLE = {
        colour("MINT"),
        colour("AMBER", nil, { 1, 0.69, 0 }, { 1, 0.69, 0, 1 }),
        colour("PHOSPHOR", nil, { 0.224, 1, 0.078 }, { 0.224, 1, 0.078, 1 }),
        colour("VIOLET", nil, { 0.627, 0.471, 1 }, { 0.627, 0.471, 1, 1 }),
    },
    PITWALL = {
        colour("RED"),
        colour("ORANGE", nil, nil, nil, { 1, 0.54, 0, 1 }),
        colour("TEAL", nil, nil, nil, { 0, 0.63, 0.61, 1 }),
        colour("SILVER", nil, nil, nil, { 0.79, 0.81, 0.84, 1 }),
    },
    COMIC = { colour("GREY"), colour("DARKGREY"), colour("BLACK"), colour("WHITE"), colour("YELLOW"),
        colour("BLUE"), colour("RED"), colour("GREEN"), colour("PURPLE") },
}

-- The minimap takes the backdrop only (no accent). Colours are stored
-- account wide, outside profiles and theme sets (AccountDB().themeColors).
-- The comic's paper tint per colour (the minimap's comic has no dark ink
-- that a dark paper would have to lighten); GREY is the comic as it is.
local COMIC_PAPER = {
    GREY = { 0.70, 0.70, 0.70 },
    DARKGREY = { 0.38, 0.38, 0.38 },
    BLACK = { 0.16, 0.16, 0.16 },
    WHITE = { 1, 1, 1 },
    YELLOW = { 0.86, 0.76, 0.36 },
    BLUE = { 0.45, 0.60, 0.86 },
    RED = { 0.86, 0.44, 0.40 },
    GREEN = { 0.50, 0.76, 0.46 },
    PURPLE = { 0.70, 0.52, 0.84 },
}

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

-- The stored colours, theme -> colour id; the comic's colour of before
-- moves in once.
local function storedColours()
    local db = ns.AccountDB()
    if type(db.themeColors) ~= "table" then db.themeColors = {} end
    if db.comicColor ~= nil then
        if db.themeColors.COMIC == nil then db.themeColors.COMIC = db.comicColor end
        db.comicColor = nil
    end
    return db.themeColors
end

local function colourOf(themeId, id)
    for _, c in ipairs(Themes.COLORS[themeId] or {}) do
        if c.id == id then return c end
    end
    return nil
end

-- A theme's colour ids in order (themeId defaults to the current theme;
-- CLASSIC has none).
function Themes.Colors(themeId)
    local list = {}
    for i, c in ipairs(Themes.COLORS[themeId or Themes.Current()] or {}) do list[i] = c.id end
    return list
end

-- A theme's colour chosen; an unknown one stored reads as its first.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    local colours = Themes.COLORS[themeId]
    if not colours then return nil end
    local id = storedColours()[themeId]
    return colourOf(themeId, id) and id or colours[1].id
end

-- The current theme's colour when it is not the theme's own look.
local function themePaint()
    local id = Themes.Current()
    local c = colourOf(id, Themes.Color())
    return c and c ~= Themes.COLORS[id][1] and c or nil
end

-- The current theme's colour when it draws from the grey texture.
local function greyPaint()
    local c = themePaint()
    return c and c.back and c or nil
end

-- The border's colour the theme's colour sets, else nil (the setting's).
function Themes.Rim()
    local c = themePaint()
    return c and c.rim
end

-- The ornaments' colour (art: the theme's): the colour's wedge, else the
-- theme's.
function Themes.OrnamentColor(art)
    local c = themePaint()
    return c and c.wedge or art.ornamentColor
end

-- The backdrop's texture (art: the theme's): the grey one under a colour.
function Themes.Back(art)
    return greyPaint() and art.back .. "Grey" or art.back
end

-- The backdrop's tint (art: the theme's): the comic's paper in its colour,
-- or the grey texture tinted to the colour at the theme's alpha.
function Themes.Tint(art)
    if Themes.Current() == "COMIC" and art.tint then
        local paper = COMIC_PAPER[Themes.Color("COMIC")]
        return { paper[1], paper[2], paper[3], art.tint[4] }
    end
    local c = greyPaint()
    if not c then return art.tint end
    local mean = GREY_MEAN[art.back]
    return { math.min(1, c.back[1] / mean), math.min(1, c.back[2] / mean), math.min(1, c.back[3] / mean),
        art.tint and art.tint[4] or 1 }
end

-- A theme's colour (themeId defaults to the current theme). Repaints at
-- once under that theme (restyling, as Switch: not in combat).
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not colourOf(themeId, id) then return nil, "UNKNOWN" end
    local active = themeId == Themes.Current()
    local why = active and refuse()
    if why then return nil, why end
    storedColours()[themeId] = id ~= Themes.COLORS[themeId][1].id and id or nil
    if active and ns.api and ns.api.ApplyLook then ns.api.ApplyLook() end
    return true
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
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId)
        local ok, why = Themes.SetColor(id, themeId)
        if ok and ns.RefreshOptions then ns.RefreshOptions() end
        return ok, why
    end,
}

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- in the list above. Each Forever addon has its own copy of this.
local function otherThemes()
    local list = {}
    for folder, entry in pairs(_G.ForeverThemes) do
        if folder ~= ADDON and type(entry) == "table" and type(entry.Switch) == "function" then
            list[#list + 1] = entry
        end
    end
    return list
end

function Themes.HasOthers() return #otherThemes() > 0 end

local function listed(ids, id)
    for _, v in ipairs(ids or {}) do
        if v == id then return true end
    end
    return false
end

-- Every other addon onto this theme and, where that theme has it, this
-- colour (else it keeps its own). One without the theme refuses the switch
-- and is skipped. Returns how many switched.
function Themes.ApplyToAll()
    local theme, color, switched = Themes.Current(), Themes.Color(), 0
    for _, entry in ipairs(otherThemes()) do
        if entry.Switch(theme) then
            switched = switched + 1
            if color and type(entry.Colors) == "function" and type(entry.SetColor) == "function"
                and listed(entry.Colors(theme), color) then
                entry.SetColor(color, theme)
            end
        end
    end
    return switched
end
