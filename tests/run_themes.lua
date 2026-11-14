-- Themes (Themes.lua, ThemeArt.lua): a settings set per theme, Classic
-- untouched. A separate run: it starts from a profile of its own.
local M = dofile("wowmock.lua")
local ROOT = ADDONDIR
local ADDON = "ForeverSquareMinimap"

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-44s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function checkTrue(label, got) check(label, not not got, true) end
print("Themes: a settings set each, Classic untouched")

local combat = false
function InCombatLockdown() return combat end

local function load()
    local ns = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            local f = line:gsub("\\", "/")
            local chunk, err = loadfile(ROOT .. "/" .. f)
            if not chunk then error(f .. ": " .. tostring(err)) end
            chunk(ADDON, ns)
        end
    end
    return ns
end

-- A profile set up by hand: size, place, border, a text moved, mail placed.
ForeverSquareMinimapProfiles = { profiles = { Default = {
    size = 300, offsetX = -40, offsetY = 20, borderStyle = "GOLD", borderSize = 4,
    infos = { zone = { y = -5, size = 13 }, coords = { size = 0 } },
    mail = { x = 7 },
} } }
ForeverSquareMinimapChar = { active = "Default" }
local ns = load()
M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
local Themes, Infos, db = ns.Themes, ns.Infos, ns.DB()

check("starts classic", Themes.Current(), "CLASSIC")
check("nothing stored yet", #Themes.Stored(), 0)
check("classic: no theme sets written", db.themeSets, nil)
local backs, shadows, ornaments = ns.ThemeArt.Parts()
check("classic: no backdrop", backs[1]:IsShown(), false)
check("classic: no ornament", ornaments[1]:IsShown(), false)
check("classic: outline", Infos.texts.zone._font[3], "OUTLINE")

-- A theme the first time: the classic setup with the theme's look.
checkTrue("switch to wood", Themes.Switch("WOOD"))
check("wood: current", Themes.Current(), "WOOD")
check("wood: same profile table", ns.DB(), db)
check("wood: keeps the size", db.size, 300)
check("wood: keeps the place", db.offsetX, -40)
check("wood: keeps a text's place", Infos.Get("zone", "y"), -5)
check("wood: its border", db.borderStyle, "GOLD")
check("wood: its border size", db.borderSize, 3)
check("wood: its font", Infos.Get("zone", "font"), "Cinzel")
check("wood: font on the text", Infos.texts.zone._font[1]:match("Cinzel%-Bold%.ttf$") ~= nil, true)
check("wood: clock in Friz", Infos.Get("server", "font"), "Friz Quadrata")
check("wood: classic stored", db.themeSets.CLASSIC.borderStyle, "GOLD")
check("wood: classic has no theme", db.themeSets.CLASSIC.theme, nil)
check("wood: the live set is not stored twice", db.themeSets.WOOD, nil)
check("wood: backdrop shown", backs[1]:IsShown(), true)
check("wood: backdrop file", backs[1]._texture, "Interface\\AddOns\\ForeverSquareMinimap\\Media\\Themes\\WoodBack")
check("wood: rivets at four corners", ornaments[4]:IsShown(), true)
check("wood: no solid shadow", shadows[1]:IsShown(), false)

-- The backdrop strips meet without a seam: neighbouring texture coordinates.
local top, left = backs[1]._coords, backs[3]._coords
check("backdrop: left strip starts where the top one ends", left[3], top[4])
check("backdrop: same column", left[1], top[1])

-- Changes stay with their theme; a second theme starts from classic.
db.offsetX = -10
checkTrue("switch to pixel", Themes.Switch("PIXEL"))
check("pixel: from classic, not from wood", db.offsetX, -40)
check("pixel: font larger", Infos.Get("zone", "size"), 17)
check("pixel: auto size stays auto", Infos.Get("coords", "size"), 0)
check("pixel: a default size grows too", Infos.Get("server", "size"), 15)
check("pixel: the client's outline", Infos.texts.zone._font[3], "OUTLINE")
check("pixel: body text in the theme font", Infos.Get("server", "font"), "VT323")
check("pixel: no solid shadow (stacked edges)", shadows[1]:IsShown(), false)
check("pixel: two to copy from", #Themes.Stored(), 2)

-- Positions from another theme, and back.
local undo = Themes.CopyPlacement("WOOD")
checkTrue("copy: done", undo)
check("copy: map position taken", db.offsetX, -10)
check("copy: look kept", db.borderColor[1], 1)
check("copy: sizes are no positions", Infos.Get("zone", "size"), 17)
checkTrue("copy: undo", Themes.Restore(undo))
check("copy: undone", db.offsetX, -40)
check("copy from a theme never used", select(2, Themes.CopyPlacement("FROST")), "GONE")

-- Back to classic: everything as it was.
checkTrue("back to classic", Themes.Switch("CLASSIC"))
check("classic: own border", db.borderStyle, "GOLD")
check("classic: own border size", db.borderSize, 4)
check("classic: own font", Infos.Get("zone", "font"), "Friz Quadrata")
check("classic: own text size", Infos.Get("zone", "size"), 13)
check("classic: no theme key", db.theme, nil)
check("classic: no backdrop", backs[1]:IsShown(), false)
check("classic: no shadow", shadows[1]:IsShown(), false)
check("classic: outline again", Infos.texts.zone._font[3], "OUTLINE")
checkTrue("wood again", Themes.Switch("WOOD"))
check("wood again: its own change came back", db.offsetX, -10)

-- Reset: the theme anew from classic.
checkTrue("reset", Themes.Reset())
check("reset: from classic", db.offsetX, -40)
check("reset: still wood", Themes.Current(), "WOOD")
Themes.Switch("CLASSIC")
check("reset: not classic", select(2, Themes.Reset()), "CLASSIC")

-- Body text in a readable font where the theme font is not: the zone name
-- is display text, clocks, FPS/ms and coordinates are body text.
checkTrue("parchment", Themes.Switch("PARCHMENT"))
check("parchment: zone in the theme font", Infos.Get("zone", "font"), "IM Fell English SC")
check("parchment: zone larger", Infos.Get("zone", "size"), 14)
check("parchment: clock in the standard font", Infos.Get("server", "font"), "Friz Quadrata")
check("parchment: clock keeps its size", Infos.Get("server", "size"), 11)
check("parchment: coordinates in the standard font", Infos.Get("coords", "font"), "Friz Quadrata")
for id, spec in pairs(Themes.SPECS) do
    local body = ({ WOOD = "Friz Quadrata", PARCHMENT = "Friz Quadrata", FROST = "Friz Quadrata",
        GLASS = "Friz Quadrata", COMIC = "Friz Quadrata", SWISS = "Inter Tight", CONSOLE = "IBM Plex Mono",
        PITWALL = "Titillium Web" })[id]
    check("body font of " .. id, spec.bodyFont, body)
    check("no bare monochrome in " .. id, (spec.outline or ""):find("MONOCHROME") == nil, true)
end
Themes.Switch("CLASSIC")

-- Tech without corner pieces; comic paper as in the other Forever addons.
Themes.Switch("TECH")
check("tech: no ornaments", ornaments[1]:IsShown() or ornaments[4]:IsShown(), false)
check("tech: backdrop", backs[1]:IsShown(), true)
Themes.Switch("COMIC")
check("comic: paper grey", backs[1]._color[1], 0.7)
check("comic: paper opaque", backs[1]._color[4], 1)
Themes.Switch("CLASSIC")

-- Every theme takes exactly the room of Classic's map and border: the map
-- is drawn smaller by what the look reaches out further. Ornaments inside.
local function outerBox()
    local reach, anchor = ns.api.Reach(), Minimap._anchor
    return Minimap:GetWidth() + 2 * reach, anchor[4] + reach, anchor[5] + reach
end
local function near(a, b) return math.abs(a - b) < 1e-6 end
Themes.Switch("CLASSIC")
local w0, x0, y0 = outerBox()
for _, id in ipairs(Themes.IDS) do
    Themes.Switch(id)
    local w, x, y = outerBox()
    check(id .. ": outer width as classic", near(w, w0), true)
    check(id .. ": outer corner as classic", near(x, x0) and near(y, y0), true)
    check(id .. ": ornaments inside the edge", ((Themes.SPECS[id].art or {}).ornamentInset or 0) >= 0, true)
end
Themes.Switch("WOOD")
check("wood: map drawn smaller", Minimap:GetWidth() < db.size, true)
check("wood: stored size is classic's", db.size, 300)
db.borderSize = 6
ns.api.ApplyBorder()
local w = outerBox()
check("wood: a thicker border keeps the box", near(w, w0), true)
Themes.Switch("CLASSIC")
check("classic: map at its own size", Minimap:GetWidth(), 300)

-- Refused.
combat = true
check("combat: switch", select(2, Themes.Switch("TECH")), "COMBAT")
check("combat: still classic", Themes.Current(), "CLASSIC")
check("combat: copy", select(2, Themes.CopyPlacement("WOOD")), "COMBAT")
combat = false
check("unknown", select(2, Themes.Switch("NOPE")), "UNKNOWN")

-- A non-Latin client keeps its font, gets the rest of the look.
M.locale = "ruRU"
Themes.Switch("RUNESTONE")
Themes.Reset()
check("ruRU: own font kept", Infos.Get("zone", "font"), "Friz Quadrata")
check("ruRU: theme border", db.borderColor[1], 0.1)
M.locale = "enUS"
Themes.Switch("CLASSIC")

-- The picker in another addon.
local entry = _G.ForeverThemes and _G.ForeverThemes[ADDON]
checkTrue("registry: entry", entry)
check("registry: title", entry.title, "Forever Square Minimap")
check("registry: current", entry.Current(), "CLASSIC")
checkTrue("registry: switch", entry.Switch("FROST"))
check("registry: switched", entry.Current(), "FROST")
check("registry: unknown", select(2, entry.Switch("NOPE")), "UNKNOWN")
entry.Switch("CLASSIC")

-- Every theme's colours: the backdrop only (no accent here), outside the sets.
local PATH = "Interface\\AddOns\\ForeverSquareMinimap\\Media\\Themes\\"
local function rgb(t) return table.concat({ t[1], t[2], t[3], t[4] }, ",") end
local function paper() return table.concat(backs[1]._color, ",") end
local function look() return backs[1]._texture .. " " .. paper() end
check("colours: none under classic", #entry.Colors() .. tostring(entry.Color()), "0nil")
check("colours: comic list", table.concat(entry.Colors("COMIC"), ","), "GREY,DARKGREY,BLACK,WHITE,YELLOW,BLUE,RED,GREEN,PURPLE")
for _, id in ipairs(Themes.IDS) do
    local art = Themes.SPECS[id].art
    if id ~= "CLASSIC" and art and art.back then
        Themes.Switch(id)
        local colours = entry.Colors()
        check(id .. ": the first colour by default", entry.Color(), colours[1])
        check(id .. ": default as today", look(), PATH .. art.back .. " " .. rgb(art.tint or { 1, 1, 1, 1 }))
        for _, c in ipairs(colours) do
            checkTrue(id .. " " .. c .. ": named", ns.L["THEME_COLOR_" .. id .. "_" .. c] ~= "THEME_COLOR_" .. id .. "_" .. c)
        end
    end
end
Themes.Switch("PIXEL")
checkTrue("pixel plum: set", entry.SetColor("PLUM"))
check("pixel: handheld last", entry.Colors()[9], "HANDHELD")
checkTrue("pixel handheld: set", entry.SetColor("HANDHELD"))
check("pixel handheld: grey texture tinted", look(), PATH .. "PixelBackGrey " .. rgb({ 0.06 / 0.8, 0.12 / 0.8, 0.06 / 0.8, 1 }))
entry.SetColor("PLUM")
check("pixel plum: grey texture tinted", look(), PATH .. "PixelBackGrey " .. rgb({ 0.23 / 0.8, 0.08 / 0.8, 0.16 / 0.8, 1 }))
check("colour: another theme's id refused", select(2, Themes.SetColor("OAK")), "UNKNOWN")
combat = true
check("colour: combat refused for the theme in use", select(2, Themes.SetColor("NAVY")), "COMBAT")
checkTrue("colour: a theme not in use in combat", Themes.SetColor("DEEP", "FROST"))
combat = false
check("colour: in no profile", ns.DB().themeColors, nil)
-- The flat themes keep their backdrop in every colour; their texts in the
-- theme's faces: the zone in the display face, the rest in the text face.
local ring = _G.ForeverSquareMinimapBorder.ring
local FACES = { SWISS = { "Inter Tight Bold", "Inter Tight" }, CONSOLE = { "IBM Plex Sans Condensed", "IBM Plex Mono" },
    PITWALL = { "Titillium Web Bold Italic", "Titillium Web" } }
for id, faces in pairs(FACES) do
    Themes.Switch(id)
    check(id .. ": zone in the display face", Infos.Get("zone", "font"), faces[1])
    check(id .. ": clock and coordinates in the text face", Infos.Get("server", "font") .. "/" .. Infos.Get("coords", "font"), faces[2] .. "/" .. faces[2])
    check(id .. ": no size growth", Infos.Get("zone", "size"), db.themeSets.CLASSIC.infos and db.themeSets.CLASSIC.infos.zone and db.themeSets.CLASSIC.infos.zone.size or Infos.DEFAULTS.zone.size)
    for _, c in ipairs(entry.Colors()) do
        Themes.SetColor(c)
        check(id .. " " .. c .. ": backdrop kept", look(), PATH .. Themes.SPECS[id].art.back .. " 1,1,1,1")
    end
    Themes.SetColor(entry.Colors()[1])
end
Themes.Switch("SWISS")
check("swiss: white rule along the top", ns.ThemeArt.rule:IsShown() and rgb(ns.ThemeArt.rule._color) .. "/" .. ns.ThemeArt.rule:GetHeight(), "0.95,0.95,0.95,1/3")
Themes.Switch("CONSOLE")
check("console: no rule", ns.ThemeArt.rule:IsShown(), false)
Themes.SetColor("AMBER")
check("console amber: the border in the accent", rgb(ring[1]._color), "1,0.69,0,1")
Themes.SetColor("MINT")
check("console mint: the border mint", rgb(ring[1]._color), "0.306,0.929,0.69,1")
Themes.Switch("PITWALL")
check("pitwall: red wedge top left", ornaments[1]:IsShown() and ornaments[1]._texture .. " " .. rgb(ornaments[1]._color), PATH .. "PitwallWedge 0.88,0.02,0,1")
-- The family's wedge: no title row, so the Combat Meter strip's 24, as wide
-- as high, the texture's left 0.53, flush inside the hairline.
check("pitwall: wedge 24 high, as wide as high", ornaments[1]:GetHeight() .. "x" .. ornaments[1]:GetWidth(), "24x24")
check("pitwall: the texture's left part", table.concat(ornaments[1]._coords, ","), "0,0.53,0,1")
Themes.SetColor("ORANGE")
check("pitwall orange: the wedge's colour", rgb(ornaments[1]._color), "1,0.54,0,1")
Themes.SetColor("RED")
-- Swiss and Pitwall share one black with every Forever addon: the flat
-- backdrop untinted, opaque.
for _, id in ipairs({ "SWISS", "PITWALL" }) do
    Themes.Switch(id)
    check(id .. ": the shared black", look(), PATH .. "SwissBack 1,1,1,1")
end
-- The ring is the same in every Forever addon, for every theme and colour:
-- the theme's own; only Console's colours and Pixel's Handheld recolour it.
local RINGS = { TECH = "0.25,0.88,0.94,0.9", PARCHMENT = "0.29,0.2,0.12,1", RUNESTONE = "0.1,0.1,0.12,1",
    GLASS = "0.07,0.06,0.05,1", COMIC = "0.07,0.07,0.07,1", FROST = "0.86,0.96,1,0.8", PIXEL = "1,0.95,0.91,1",
    SWISS = "0.16,0.16,0.16,1", PITWALL = "0.043,0.047,0.055,1" }
local OWN_RING = { CONSOLE = { MINT = "0.306,0.929,0.69,1", AMBER = "1,0.69,0,1", PHOSPHOR = "0.224,1,0.078,1",
    VIOLET = "0.627,0.471,1,1" }, PIXEL = { HANDHELD = "0.784,0.941,0.439,1" } }
for _, id in ipairs(Themes.IDS) do
    if id ~= "CLASSIC" then
        Themes.Switch(id)
        local chosen = entry.Color()
        for _, c in ipairs(entry.Colors()) do
            Themes.SetColor(c)
            if id == "WOOD" then
                check("ring " .. id .. " " .. c, db.borderStyle .. " " .. tostring(ring[1]._gradient ~= nil), "GOLD true")
            else
                check("ring " .. id .. " " .. c, rgb(ring[1]._color), (OWN_RING[id] or {})[c] or RINGS[id])
            end
        end
        Themes.SetColor(chosen)
    end
end
Themes.Switch("COMIC")
check("comic grey: paper as today", paper(), "0.7,0.7,0.7,1")
checkTrue("comic blue: set", entry.SetColor("BLUE"))
check("comic blue: paper", paper(), "0.45,0.6,0.86,1")
check("colour: unknown refused", select(2, Themes.SetColor("NOPE")), "UNKNOWN")
Themes.Switch("PIXEL")
check("colours: each theme its own", entry.Color() .. " " .. entry.Color("COMIC") .. " " .. entry.Color("FROST"), "PLUM BLUE DEEP")
Themes.SetColor("NAVY")
check("pixel navy: as today again", look(), PATH .. "PixelBack 1,1,1,1")
Themes.SetColor("ICE", "FROST")
Themes.Switch("COMIC")
ns.AccountDB().themeColors.COMIC = "NOPE"
check("colour: unknown stored reads the first", Themes.Color(), "GREY")
-- The comic colour of before moves in once.
ns.AccountDB().themeColors.COMIC = nil
ns.AccountDB().comicColor = "RED"
check("migration: comic colour moved", entry.Color("COMIC") .. " " .. tostring(ns.AccountDB().comicColor), "RED nil")
ns.AccountDB().comicColor = "BLUE"
check("migration: a colour already set wins", entry.Color("COMIC"), "RED")
checkTrue("comic grey back: set", Themes.SetColor("GREY"))
check("comic grey back: nothing stored", next(ns.AccountDB().themeColors), nil)
Themes.Switch("CLASSIC")

-- The sets go with a profile copy.
Themes.Switch("WOOD")
ns.SwitchProfile("Second")
check("save as: on wood", Themes.Current(), "WOOD")
check("save as: classic copied", ns.DB().themeSets.CLASSIC.borderStyle, "GOLD")
check("save as: a copy, not the same", ns.DB().themeSets == db.themeSets, false)
ns.SwitchProfile("Default")

-- A font the client refuses at first use is tried again.
local fs = Infos.texts.coords
local setFont, refusals = fs.SetFont, 1
fs.SetFont = function(self, path, ...)
    if refusals > 0 and path:find("VT323", 1, true) then
        refusals = refusals - 1
        self._font = { nil, ... }
        return
    end
    return setFont(self, path, ...)
end
M.timers = {}
Themes.Switch("PIXEL")
check("refused: no font yet", fs._font[1], nil)
check("refused: tried again later", #M.timers > 0, true)
for _, fn in ipairs(M.timers) do fn() end
check("tried again: taken", fs._font[1]:find("VT323", 1, true) ~= nil, true)
Themes.Switch("CLASSIC")

-- A theme stored under an older revision is made anew; Classic stays.
ForeverSquareMinimapProfiles = { profiles = { Default = {
    theme = "WOOD", borderStyle = "NONE", size = 280, offsetX = 3,
    themeSets = { revision = 1, CLASSIC = { size = 280, offsetX = 3, borderStyle = "GOLD" },
        TECH = { theme = "TECH", offsetX = 99 } },
} } }
ForeverSquareMinimapChar = { active = "Default" }
ns.ResetProfileState()
ns.Themes.Upgrade()
db = ns.DB()
check("upgrade: the theme in use made anew", db.borderStyle, "GOLD")
check("upgrade: still wood", db.theme, "WOOD")
check("upgrade: from classic", db.offsetX, 3)
check("upgrade: stale set dropped", db.themeSets.TECH, nil)
check("upgrade: classic kept", db.themeSets.CLASSIC.borderStyle, "GOLD")
check("upgrade: revision noted", db.themeSets.revision, 4)
db.borderSize = 6
ns.Themes.Upgrade()
check("upgrade: once only", db.borderSize, 6)

-- The shipped files are there.
for _, name in ipairs({ "Fonts/OFL.txt", "Fonts/FONTS.txt", "Fonts/VT323-Regular.ttf", "Themes/WoodBack.tga",
    "Themes/Seal.tga" }) do
    local f = io.open(ROOT .. "/Media/" .. name, "rb")
    check("shipped: " .. name, f ~= nil, true)
    if f then f:close() end
end
for id, spec in pairs(ns.Themes.SPECS) do
    local art = spec.art or {}
    for _, file in ipairs({ art.back, art.ornament }) do
        local f = io.open(ROOT .. "/Media/Themes/" .. file .. ".tga", "rb")
        check("texture of " .. id .. ": " .. file, f ~= nil, true)
        if f then f:close() end
    end
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
