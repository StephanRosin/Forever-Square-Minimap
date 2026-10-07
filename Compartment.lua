--[[---------------------------------------------------------------------------
Compartment.lua -- every LibDBIcon minimap button also in the addon
compartment, and on request off the map.

Blizzard's compartment lists only addons that name an AddonCompartmentFunc in
their TOC or call AddonCompartmentFrame:RegisterAddon. Most addons only have
a LibDBIcon button on the map, so the menu showed some of them. LibDBIcon
keeps every button it made in lib.objects with its data object (icon,
OnClick, tooltip), which is what an entry needs.

No addon may be listed twice. An entry is left out, or taken back out, when
another entry carries its button name or its addon title. That covers
LibDBIcon's own entry (the addon's "show in compartment" setting, under the
button name) and Blizzard's TOC entries (under the title); colour codes,
spaces and case are ignored.
LibDBIcon's own AddButtonToCompartment is not used: it writes
showInCompartment into the other addon's saved settings.

Blizzard fills the list at the first PLAYER_ENTERING_WORLD, so nothing is
added before that. Later changes come through LibDBIcon's callback, hooks on
its compartment functions and, as a last check, when the mouse enters the
compartment button, before the menu opens.

Hidden icons go to a hidden parent rather than :Hide(): LibDBIcon shows its
buttons again on every Refresh, and a shown child of a hidden frame stays
invisible. They are only hidden while the compartment itself is shown,
otherwise those addons could not be reached at all.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Compartment = {}
ns.Compartment = Compartment

local ready = false
local entries = {}      -- LibDBIcon button name -> our entry in the list
local ours = {}         -- our entries, to tell them apart in the list
local hiddenIcons = {}  -- LibDBIcon button name -> its button, while hidden
local holder            -- the hidden parent

local function Lib()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

local function List()
    local frame = ns.Buttons.Frame("compartment")
    if frame and type(frame.registeredAddons) == "table" and frame.RegisterAddon then return frame end
end

-- "|cff33ff99AtlasLoot|r Classic" and "AtlasLootClassic" are one addon.
local function Key(text)
    local plain = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):lower()
    local key = plain:gsub("[^%w]", "")
    -- Names in other alphabets have no ASCII letters left.
    if key == "" then return plain end
    return key
end

local function AddonTitle(name)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return nil end
    local ok, _, title = pcall(C_AddOns.GetAddOnInfo, name)
    if ok then return title end
end

-- The keys of every entry that is not ours.
local function Taken(frame)
    local taken = {}
    for _, data in ipairs(frame.registeredAddons) do
        if not ours[data] then taken[Key(data.text)] = true end
    end
    return taken
end

local function ListedElsewhere(name, taken)
    if taken[Key(name)] then return true end
    local title = AddonTitle(name)
    return title ~= nil and taken[Key(title)] == true
end

-- Tooltip placement as LibDBIcon does it: away from the screen's edges.
local function Anchors(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return "CENTER" end
    local h = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
    local v = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
    return v .. h, frame, (v == "TOP" and "BOTTOM" or "TOP") .. h
end

local function NewEntry(name, object, lib)
    local dataObject = object.dataObject
    local tooltip = lib.tooltip or GameTooltip
    return {
        text = name,
        icon = dataObject.icon,
        notCheckable = true,
        registerForAnyClick = true,
        func = function(_, menuInputData, menu)
            if dataObject.OnClick then
                dataObject.OnClick(menu, menuInputData and menuInputData.buttonName or "LeftButton")
            end
        end,
        funcOnEnter = function(button)
            if dataObject.OnTooltipShow then
                tooltip:SetOwner(button, "ANCHOR_NONE")
                tooltip:SetPoint(Anchors(button))
                dataObject.OnTooltipShow(tooltip)
                tooltip:Show()
            elseif dataObject.OnEnter then
                dataObject.OnEnter(button)
            end
        end,
        funcOnLeave = function(button)
            tooltip:Hide()
            if dataObject.OnLeave then dataObject.OnLeave(button) end
        end,
    }
end

local function Remove(frame, data)
    for i = #frame.registeredAddons, 1, -1 do
        if frame.registeredAddons[i] == data then table.remove(frame.registeredAddons, i) end
    end
    ours[data] = nil
end

local function ShowIcons()
    for name, button in pairs(hiddenIcons) do
        button:SetParent(Minimap)
        hiddenIcons[name] = nil
    end
end

local function HideIcons(lib)
    holder = holder or CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    for name, button in pairs(lib.objects) do
        if not hiddenIcons[name] then
            button:SetParent(holder)
            hiddenIcons[name] = button
        end
    end
end

function Compartment.Sync()
    if not ready then return end
    local frame, lib = List(), Lib()
    if not frame or not lib or type(lib.objects) ~= "table" then return end
    local on = ns.Buttons.Get("compartment", "collect")
    local taken = Taken(frame)
    local changed = false

    for name, data in pairs(entries) do
        local object = lib.objects[name]
        if not on or not object or ListedElsewhere(name, taken) then
            Remove(frame, data)
            entries[name] = nil
            changed = true
        end
    end

    if on then
        for name, object in pairs(lib.objects) do
            if not entries[name] and type(object.dataObject) == "table"
                and not ListedElsewhere(name, taken) then
                local data = NewEntry(name, object, lib)
                entries[name] = data
                ours[data] = true
                taken[Key(name)] = true
                table.insert(frame.registeredAddons, data)
                changed = true
            end
        end
    end

    if changed and frame.UpdateDisplay then frame:UpdateDisplay() end

    if on and ns.Buttons.Get("compartment", "hideIcons") and ns.Buttons.Get("compartment", "show") then
        HideIcons(lib)
    else
        ShowIcons()
    end
end

-- Only from Blizzard's own list onwards; see above.
local function Later() C_Timer.After(0, Compartment.Sync) end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    if ready then return Later() end
    ready = true
    local frame, lib = List(), Lib()
    if lib then
        if lib.RegisterCallback then lib.RegisterCallback(Compartment, "LibDBIcon_IconCreated", Later) end
        for _, fn in ipairs({ "AddButtonToCompartment", "RemoveButtonFromCompartment" }) do
            if type(lib[fn]) == "function" then hooksecurefunc(lib, fn, Compartment.Sync) end
        end
    end
    if frame and frame.HookScript then frame:HookScript("OnEnter", Compartment.Sync) end
    Later()
end)
