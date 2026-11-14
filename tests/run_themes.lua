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
check("wood: its border", db.borderStyle, "FLAT")
check("wood: its border size", db.borderSize, 3)
check("wood: its font", Infos.Get("zone", "font"), "Cinzel")
check("wood: font on the text", Infos.texts.zone._font[1]:match("Cinzel%-Bold%.ttf$") ~= nil, true)
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
check("pixel: solid shadow", shadows[1]:IsShown(), true)
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
    local body = ({ PARCHMENT = true, FROST = true, GLASS = true, COMIC = true })[id]
    check("body font of " .. id, spec.bodyFont, body and "Friz Quadrata" or nil)
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
check("upgrade: the theme in use made anew", db.borderStyle, "FLAT")
check("upgrade: still wood", db.theme, "WOOD")
check("upgrade: from classic", db.offsetX, 3)
check("upgrade: stale set dropped", db.themeSets.TECH, nil)
check("upgrade: classic kept", db.themeSets.CLASSIC.borderStyle, "GOLD")
check("upgrade: revision noted", db.themeSets.revision, 2)
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
