--[[---------------------------------------------------------------------------
Buttons.lua -- Blizzard's buttons around the map: tracking, calendar, the
addon compartment and the instance difficulty.

WoW: Forever has the modern minimap. These buttons hang from MinimapCluster,
which the addon hides to get rid of the round frame, so they vanished with
it. They move onto the map instead, and each can be switched off, placed
(a point on the map, the button's own point, X/Y, so also outside the map)
and scaled.

Blizzard still decides when a button is there at all (the compartment only
with addons in it, tracking not where the game rules turn it off); "off"
here hides it by alpha, so Blizzard showing it again does not bring it back.
Blizzard also puts the difficulty back to its own place when the Edit Mode
header setting changes, so the placement is checked once a second.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Buttons = {}
ns.Buttons = Buttons

Buttons.KINDS = { "tracking", "calendar", "compartment", "difficulty" }

-- Only the modern minimap (WoW: Forever) has them on the cluster. Older
-- clients keep their button column and day/night dial as before.
function Buttons.Modern()
    return type(MinimapCluster) == "table" and type(MinimapCluster.Tracking) == "table"
end

-- Each kind's frame in this client, or nil.
local FRAMES = {
    tracking = function() return MinimapCluster.Tracking end,
    calendar = function() return _G.GameTimeFrame end,
    compartment = function() return _G.AddonCompartmentFrame end,
    difficulty = function() return MinimapCluster.InstanceDifficulty end,
}

-- A column in the map's bottom right corner: calendar at the bottom,
-- tracking above it, the addon compartment above that; the difficulty
-- (only in instances) higher up, clear of them.
Buttons.DEFAULTS = {
    tracking = { show = true, mapPoint = "BOTTOMRIGHT", point = "BOTTOMRIGHT", x = -2, y = 28, scale = 100 },
    calendar = { show = true, mapPoint = "BOTTOMRIGHT", point = "BOTTOMRIGHT", x = 0, y = 0, scale = 100 },
    compartment = { show = true, mapPoint = "BOTTOMRIGHT", point = "TOPRIGHT", x = -2, y = 75, scale = 100 },
    difficulty = { show = true, mapPoint = "BOTTOMRIGHT", point = "BOTTOMRIGHT", x = -2, y = 82, scale = 100 },
}

-- Above the map's border, like the mail icon.
local LEVEL_ABOVE_MAP = 10

-- The look of the mail icon: a bare symbol, no round button behind it, and
-- one size for all, so they line up as a column. The mail icon is 24x18;
-- these are square symbols, so 20x20 gives them the same weight.
Buttons.ICON = 20
Buttons.GEAR = "Interface\\Buttons\\UI-OptionsButton"
Buttons.GREY = { 0.9, 0.87, 0.8 }

local SKINS = {
    tracking = function(frame)
        if type(frame.Background) == "table" then frame.Background:SetAlpha(0) end
        frame:SetSize(Buttons.ICON, Buttons.ICON)
        local button = frame.Button
        if type(button) == "table" then
            button:ClearAllPoints()
            button:SetAllPoints(frame)
        end
    end,
    calendar = function(frame)
        frame:SetSize(Buttons.ICON, Buttons.ICON)
    end,
    compartment = function(frame)
        -- Blizzard's art is a round button with the addon count on it, and
        -- there is no bare symbol for it: a flat gear from the game instead,
        -- the count small in its corner.
        local normal = frame.GetNormalTexture and frame:GetNormalTexture()
        if normal then normal:SetAlpha(0) end
        local pushed = frame.GetPushedTexture and frame:GetPushedTexture()
        if pushed then pushed:SetAlpha(0) end
        frame:SetSize(Buttons.ICON, Buttons.ICON)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(Buttons.GEAR)
        icon:SetAllPoints(frame)
        -- The gear is yellow; grey and slightly warm, measured from the
        -- calendar and tracking art next to it, so the column looks alike.
        if icon.SetDesaturated then icon:SetDesaturated(true) end
        icon:SetVertexColor(Buttons.GREY[1], Buttons.GREY[2], Buttons.GREY[3])
        frame.fsmIcon = icon
        local text = frame.Text
        if type(text) == "table" and text.ClearAllPoints then
            text:ClearAllPoints()
            text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -2)
            if text.GetFont and text.SetFont then
                local path, size = text:GetFont()
                if path and size then text:SetFont(path, size, "OUTLINE") end
            end
            if text.SetDrawLayer then text:SetDrawLayer("OVERLAY") end
        end
    end,
}

function Buttons.Frame(kind)
    if not Buttons.Modern() then return nil end
    return FRAMES[kind]()
end

-- Settings: in the active profile under buttons[kind][field].
function Buttons.Get(kind, field)
    local own = ns.DB().buttons
    own = own and own[kind]
    local v = own and own[field]
    if v == nil then return Buttons.DEFAULTS[kind][field] end
    return v
end

function Buttons.Set(kind, field, value)
    local db = ns.DB()
    db.buttons = db.buttons or {}
    db.buttons[kind] = db.buttons[kind] or {}
    db.buttons[kind][field] = value
    Buttons.Apply()
end

local function place(kind, frame)
    local scale = math.max(0.25, (Buttons.Get(kind, "scale") or 100) / 100)
    frame:SetScale(scale)
    -- Offsets count in the frame's own scale: divided, they stay pixels.
    frame:ClearAllPoints()
    frame:SetPoint(Buttons.Get(kind, "point"), Minimap, Buttons.Get(kind, "mapPoint"),
        Buttons.Get(kind, "x") / scale, Buttons.Get(kind, "y") / scale)
end

function Buttons.Apply()
    local level = Minimap.GetFrameLevel and Minimap:GetFrameLevel()
    for _, kind in ipairs(Buttons.KINDS) do
        local frame = Buttons.Frame(kind)
        if frame then
            if frame.SetParent then frame:SetParent(Minimap) end
            if SKINS[kind] and not frame.fsmSkinned then
                SKINS[kind](frame)
                frame.fsmSkinned = true
            end
            if type(level) == "number" and frame.SetFrameLevel then frame:SetFrameLevel(level + LEVEL_ABOVE_MAP) end
            local on = Buttons.Get(kind, "show")
            frame:SetAlpha(on and 1 or 0)
            if frame.EnableMouse then frame:EnableMouse(on) end
            place(kind, frame)
        end
    end
end

-- Once a second: put back what Blizzard moved away from the map.
function Buttons.Check()
    for _, kind in ipairs(Buttons.KINDS) do
        local frame = Buttons.Frame(kind)
        if frame and frame.GetPoint then
            local _, relativeTo = frame:GetPoint(1)
            if relativeTo ~= Minimap then
                Buttons.Apply()
                return
            end
        end
    end
end
