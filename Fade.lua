--[[---------------------------------------------------------------------------
Fade.lua -- how opaque the map is: out of combat, in combat, and under the
mouse.

Alpha only, never Hide: an addon may hang a secure button on the map, and
hiding it in combat would then be blocked. At 0 % the map is invisible but
still takes the mouse; "full under the mouse" brings it back when you point
at it. The defaults (100 % everywhere) are the look the addon always had.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Fade = {}
ns.Fade = Fade

Fade.DEFAULTS = { alpha = 100, combatAlpha = 100, mouseover = true }

-- Settings: in the active profile under fade[field].
function Fade.Get(field)
    local own = ns.DB().fade
    local v = own and own[field]
    if v == nil then return Fade.DEFAULTS[field] end
    return v
end

function Fade.Set(field, value)
    local db = ns.DB()
    db.fade = db.fade or {}
    db.fade[field] = value
    Fade.Refresh()
end

-- The alpha the map should have now, 0..1. Pure: the state comes in, so the
-- tests need no game.
function Fade.Target(inCombat, mouseOver, indoorMap)
    local pct = inCombat and Fade.Get("combatAlpha") or Fade.Get("alpha")
    if mouseOver and Fade.Get("mouseover") then pct = 100 end
    -- The client draws the map picture of cities, caves and buildings only at
    -- full opacity: below it the picture is a black square that ignores the
    -- map's alpha; a half transparent mask and
    -- C_Minimap.SetDrawGroundTextures(false) change nothing (in game:
    -- Ironforge). So there the map is opaque. 0 % is left alone: icons and
    -- border are hidden, the black square stays.
    if indoorMap and pct > 0 then pct = 100 end
    return math.max(0, math.min(100, pct)) / 100
end

local function faded() return Fade.Get("alpha") < 100 or Fade.Get("combatAlpha") < 100 end

-- Whether the client draws that indoor picture now. IsIndoors does not say it
-- (false in Ironforge). The client keeps one zoom for outdoors (minimapZoom)
-- and one for indoors, the map shows the one in use, and SetZoom writes it:
-- if minimapZoom follows the map we are outdoors. With both the same a nudge
-- tells them apart, as HereBeDragons does.
function Fade.IndoorMap()
    if not GetCVar then return false end
    local zoom = Minimap:GetZoom()
    if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
        Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
    end
    local indoor = tonumber(GetCVar("minimapZoom")) ~= Minimap:GetZoom()
    Minimap:SetZoom(zoom)
    return indoor
end

local inCombat, indoorMap = false, false

-- For /fsm dump: what the last look found (false without a fade set).
function Fade.SeesIndoorMap() return indoorMap end

function Fade.Apply()
    local over = Minimap.IsMouseOver and Minimap:IsMouseOver() or false
    local a = Fade.Target(inCombat, over, indoorMap)
    if Minimap:GetAlpha() == a then return end
    Minimap:SetAlpha(a)
    -- Back at full opacity the picture stays black until the map redraws.
    if a == 1 and ns.api then ns.api.RedrawMap() end
end

-- Looks where we are, then applies. Only with a fade set: nobody else needs
-- the zoom touched.
function Fade.Refresh()
    indoorMap = faded() and Fade.IndoorMap()
    Fade.Apply()
end

-- Combat from the events; the mouse ten times a second. Checking the mouse
-- is only needed while the map is not fully opaque somewhere.
local driver
function Fade.Create()
    if driver then return end
    driver = CreateFrame("Frame")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- The moments the client may switch between the two pictures.
    -- pcall: an older client without one of these events must not stop the addon.
    for _, event in ipairs({ "NEW_WMO_CHUNK", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
                             "PLAYER_ENTERING_WORLD" }) do
        pcall(driver.RegisterEvent, driver, event)
    end
    driver:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            inCombat = event == "PLAYER_REGEN_DISABLED"
            Fade.Apply()
        else
            Fade.Refresh()
        end
    end)
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        if faded() then Fade.Apply() end
    end)
    inCombat = InCombatLockdown and InCombatLockdown() or false
    Fade.Apply()
end
