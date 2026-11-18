--[[---------------------------------------------------------------------------
ThemeArt.lua -- the theme's art beyond settings (Themes.lua): a tiled
backdrop in a padding between the map and its border, corner ornaments at the
border's outer corners, a solid shadow outside it.

Everything lies OUTSIDE the map, so the map stays fully visible whatever the
frame levels: the backdrop is four strips round it (texture coordinates of
one picture, so the tiles meet without a seam), the shadow two strips beyond
the border. Only plain textures, nothing clickable. The ornaments sit below
Blizzard's buttons (map + 5) and the mail icon (map + 10).
-----------------------------------------------------------------------------]]

local _, ns = ...

local ThemeArt = {}
ns.ThemeArt = ThemeArt

-- The textures come with the embedded LibForeverThemes.
local Lib = LibForeverThemes
-- The backdrop files are 128 px tiles, drawn at 128 UI units; an HD
-- theme's are art.tile (Lib.TILE_HD) px, drawn at as many units.
local TILE = 128
local ORNAMENT_LEVEL = 3
-- The corners in the order of a spec's `corners`, and the texture
-- coordinates of a top-left ornament for each: mirrored, never rotated.
local POINTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local MIRROR = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }

local holder, backs, shadows, ornaments

local function art()
    return ns.Themes.Spec(ns.Themes.Current()).art or {}
end
ThemeArt.Art = art

-- The padding between map and border, in UI units; 0 for CLASSIC.
function ThemeArt.Padding()
    return art().padding or 0
end

local function create()
    holder = CreateFrame("Frame", "ForeverSquareMinimapTheme", Minimap)
    holder:SetAllPoints(Minimap)
    backs, shadows, ornaments = {}, {}, {}
    for i = 1, 4 do backs[i] = holder:CreateTexture(nil, "BACKGROUND") end
    for i = 1, 2 do shadows[i] = holder:CreateTexture(nil, "BACKGROUND") end
    local over = CreateFrame("Frame", nil, holder)
    over:SetAllPoints(Minimap)
    local level = Minimap:GetFrameLevel()
    if type(level) == "number" then over:SetFrameLevel(level + ORNAMENT_LEVEL) end
    for i = 1, 4 do ornaments[i] = over:CreateTexture(nil, "OVERLAY") end
    ThemeArt.rule = over:CreateTexture(nil, "OVERLAY")
end

-- One strip of the backdrop: its rectangle from the map's top left corner
-- (x right, y down, the padding p outside), cut from one tiled picture
-- of tile units a side.
local function strip(texture, p, tile, x1, y1, x2, y2)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", Minimap, "TOPLEFT", x1, -y1)
    texture:SetPoint("BOTTOMRIGHT", Minimap, "TOPLEFT", x2, -y2)
    texture:SetTexCoord((x1 + p) / tile, (x2 + p) / tile, (y1 + p) / tile, (y2 + p) / tile)
end

local function placeBack(a, p)
    local on = a.back ~= nil and p > 0
    for i = 1, 4 do backs[i]:SetShown(on) end
    if not on then return end
    local s, tile = Minimap:GetWidth(), a.tile or TILE
    strip(backs[1], p, tile, -p, -p, s + p, 0)    -- top, corners included
    strip(backs[2], p, tile, -p, s, s + p, s + p) -- bottom
    strip(backs[3], p, tile, -p, 0, 0, s)         -- left
    strip(backs[4], p, tile, s, 0, s + p, s)      -- right
    local tint = ns.Themes.Tint(a) or { 1, 1, 1, 1 }
    for i = 1, 4 do
        backs[i]:SetTexture(Lib.Texture(ns.Themes.Back(a)), "REPEAT", "REPEAT")
        backs[i]:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    end
end

-- The solid shadow: what shows of a black square `o` down and right of the
-- framed map, the parts right of it and below it.
local function placeShadow(a, extent)
    local o = a.hardShadow
    for i = 1, 2 do shadows[i]:SetShown(o ~= nil) end
    if not o then return end
    local right, bottom = shadows[1], shadows[2]
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", extent, extent - o)
    right:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", extent + o, -extent - o)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", o - extent, -extent)
    bottom:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", extent, -extent - o)
    for i = 1, 2 do shadows[i]:SetColorTexture(0, 0, 0, 1) end
end

-- Ornaments at the border's outer corners, ornamentInset inwards.
local function placeOrnaments(a, extent)
    local wanted = {}
    for _, i in ipairs(a.ornament and a.corners or {}) do wanted[i] = true end
    local size, inset = a.ornamentSize or 12, (a.ornamentInset or 0) - extent
    local c = a.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(ornaments) do
        piece:SetShown(wanted[i] == true)
        if wanted[i] then
            local point = POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, Minimap, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(Lib.Texture(a.ornament))
            piece:SetTexCoord(unpack(MIRROR[i]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

-- The rule along the top, over the border, inside the outer edge.
local function placeRule(a, extent)
    local rule = ThemeArt.rule
    rule:SetShown(a.rule ~= nil)
    if not a.rule then return end
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -extent, extent)
    rule:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", extent, extent)
    rule:SetHeight(a.ruleSize)
    rule:SetColorTexture(1, 1, 1, 1)
    rule:SetVertexColor(a.rule[1], a.rule[2], a.rule[3], a.rule[4])
end

-- extent: how far the border reaches out from the map, padding included
-- (SquareMinimap.lua, ApplyBorder).
function ThemeArt.Apply(extent)
    if not holder then create() end
    local a = art()
    placeBack(a, ThemeArt.Padding())
    placeShadow(a, extent)
    placeOrnaments(a, extent)
    placeRule(a, extent)
end

-- Tests only.
function ThemeArt.Parts() return backs, shadows, ornaments end
