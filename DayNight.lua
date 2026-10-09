--[[---------------------------------------------------------------------------
DayNight.lua -- the old day/night orb as a button on the map.

WoW: Forever has the modern minimap, which has no day/night indicator; the
calendar took its place. Classic's GameTimeFrame showed the orb from
Interface\Minimap\UI-TOD-Indicator: day in the left half, night in the right
one, switched by server time at 5:30 and 21:00. This is that orb, placed,
scaled and switched on and off like Blizzard's buttons (Buttons.lua).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L

local DayNight = {}
ns.DayNight = DayNight

DayNight.TEXTURE = "Interface\\Minimap\\UI-TOD-Indicator"
-- Classic's GAMETIME_DAWN and GAMETIME_DUSK, in minutes.
DayNight.DAWN = 5 * 60 + 30
DayNight.DUSK = 21 * 60

-- The orb is 50x50 at the top left of a 128x64 file, twice: day, night.
local W, H = 50 / 128, 50 / 64

function DayNight.IsDay(hour, minute)
    local t = hour * 60 + minute
    return t >= DayNight.DAWN and t < DayNight.DUSK
end

local function serverTime()
    if GetGameTime then
        local hour, minute = GetGameTime()
        if hour and minute then return hour, minute end
    end
    local now = date("*t")
    return now.hour, now.min
end

local function showTooltip(frame)
    local hour, minute = serverTime()
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:SetText(DayNight.IsDay(hour, minute) and L.DAYNIGHT_DAY or L.DAYNIGHT_NIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.OPT_INFO_SERVER .. ": " .. ns.Infos.FormatTime(hour, minute))
    GameTooltip:Show()
end

function DayNight.Update()
    local frame = DayNight.frame
    if not frame then return end
    local day = DayNight.IsDay(serverTime())
    if day == frame.day then return end
    frame.day = day
    local left = day and 0 or 0.5
    frame.icon:SetTexCoord(left, left + W, 0, H)
    if GameTooltip:IsOwned(frame) then showTooltip(frame) end
end

-- Made on first use; Buttons.lua places it like Blizzard's buttons.
function DayNight.Frame()
    if DayNight.frame then return DayNight.frame end
    local frame = CreateFrame("Frame", "ForeverSquareMinimapDayNight", Minimap)
    frame:SetSize(20, 20)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexture(DayNight.TEXTURE)
    frame.icon:SetAllPoints(frame)
    frame:SetScript("OnEnter", showTooltip)
    frame:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 1 then return end
        self.since = 0
        DayNight.Update()
    end)
    DayNight.frame = frame
    DayNight.Update()
    return frame
end
