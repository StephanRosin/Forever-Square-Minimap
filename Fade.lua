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
    Fade.Apply()
end

-- The alpha the map should have now, 0..1. Pure: the state comes in, so the
-- tests need no game.
function Fade.Target(inCombat, mouseOver)
    local pct = inCombat and Fade.Get("combatAlpha") or Fade.Get("alpha")
    if mouseOver and Fade.Get("mouseover") then pct = 100 end
    return math.max(0, math.min(100, pct)) / 100
end

local inCombat = false

function Fade.Apply()
    local over = Minimap.IsMouseOver and Minimap:IsMouseOver() or false
    local a = Fade.Target(inCombat, over)
    if Minimap:GetAlpha() ~= a then Minimap:SetAlpha(a) end
end

-- Combat from the events; the mouse ten times a second. Checking the mouse
-- is only needed while the map is not fully opaque somewhere.
local driver
function Fade.Create()
    if driver then return end
    driver = CreateFrame("Frame")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:SetScript("OnEvent", function(_, event)
        inCombat = event == "PLAYER_REGEN_DISABLED"
        Fade.Apply()
    end)
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        if Fade.Get("alpha") < 100 or Fade.Get("combatAlpha") < 100 then Fade.Apply() end
    end)
    inCombat = InCombatLockdown and InCombatLockdown() or false
    Fade.Apply()
end
