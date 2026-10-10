-- Every LibDBIcon button and every addon settings page in the addon
-- compartment, none twice (Compartment.lua).
-- A separate run: it needs the modern minimap and a compartment with a list.
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
print("WoW: Forever: every minimap button in the addon compartment")

function hooksecurefunc(owner, name, fn)
    local old = owner[name]
    owner[name] = function(...)
        local a, b, c = old(...)
        fn(...)
        return a, b, c
    end
end

MinimapCluster.Tracking = M.newWidget("ClusterTracking")
MinimapCluster.InstanceDifficulty = M.newWidget("ClusterDifficulty")

-- Blizzard's compartment: a list, filled from the TOCs at the first
-- PLAYER_ENTERING_WORLD (before our handler, as Blizzard's frame is older).
local compartment = CreateFrame("Button", "AddonCompartmentFrame")
compartment.registeredAddons = {}
compartment.hooks = {}
function compartment:RegisterAddon(data)
    table.insert(self.registeredAddons, data)
    self:UpdateDisplay()
end
function compartment:UpdateDisplay() self.count = #self.registeredAddons end
function compartment:HookScript(script, fn) self.hooks[script] = fn end
compartment:RegisterEvent("PLAYER_ENTERING_WORLD")
compartment:SetScript("OnEvent", function(self)
    self:RegisterAddon({ text = "Forever Square Minimap" })
    self:RegisterAddon({ text = "|cff33ff99Bartender|r4" })
    self:RegisterAddon({ text = "AtlasLoot Classic" })
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- Installed addons: name, title, loaded, TOC icon.
local ADDONS = {
    { "AtlasLoot", "AtlasLoot Classic", true },
    { "Questie", "|cFFFFFFFFQuestie|r", true },
    { "Bartender4", "|cff33ff99Bartender|r4", true },
    { "InfoPanel", "InfoPanel", true },
    { "Chattynator", "Chattynator", true, "Interface\\AddOns\\Chattynator\\Logo.png" },
    { "ScreenBackdrop", "ScreenBackdrop", true },
    { "Sleeper", "Sleeper", false },
}
local function addonOf(id)
    for i, a in ipairs(ADDONS) do
        if id == i or id == a[1] then return a end
    end
    error("Invalid AddOn name")
end
C_AddOns = {
    GetNumAddOns = function() return #ADDONS end,
    GetAddOnInfo = function(id)
        local a = addonOf(id)
        return a[1], a[2], "", true, nil, "INSECURE"
    end,
    IsAddOnLoaded = function(id) return addonOf(id)[3] end,
    GetAddOnMetadata = function(id, field)
        if field == "IconTexture" then return addonOf(id)[4] end
    end,
}

-- The settings window: pages under Options > AddOns and Game.
Settings = { CategorySet = { Game = 1, AddOns = 2 } }
local opened
function Settings.OpenToCategory(id) opened = id end
local pages = {}
local function page(name, set, parent)
    local category = { id = #pages + 100, name = name, set = set or 2, parent = parent }
    function category:GetID() return self.id end
    function category:GetName() return self.name end
    function category:GetCategorySet() return self.set end
    function category:HasParentCategory() return self.parent ~= nil end
    pages[#pages + 1] = category
    return category
end
SettingsPanel = { GetAllCategories = function() return pages end }
function SettingsPanel:OpenToCategory(id) opened = "panel:" .. tostring(id) end
page("InfoPanel")
page("Chattynator").id = "Chattynator"  -- as Chattynator does
page("Bartender4")
page("Questie")
page("Some Library")
page("Sleeper")
page("Graphics", 1)
page("InfoPanel Colors", 2, pages[1])

-- LibDBIcon as far as Compartment.lua uses it, AddButtonToCompartment as
-- in the library (minor 56).
local lib = LibStub("LibDBIcon-1.0")
lib.objects = {}
lib.tooltip = GameTooltip
local callbacks = {}
function lib.RegisterCallback(_, _, fn) callbacks[#callbacks + 1] = fn end
local clicks = {}
local function icon(name)
    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button.dataObject = {
        icon = "Interface\\Icons\\" .. name,
        OnClick = function(_, mouse) clicks[#clicks + 1] = name .. ":" .. mouse end,
        OnTooltipShow = function(tip) tip.shown = name end,
    }
    button.db = {}
    lib.objects[name] = button
    for _, fn in ipairs(callbacks) do fn("LibDBIcon_IconCreated", button, name) end
    return button
end
function lib:AddButtonToCompartment(name)
    local object = self.objects[name]
    if object and not object.compartmentData then
        object.db.showInCompartment = true
        object.compartmentData = { text = name }
        AddonCompartmentFrame:RegisterAddon(object.compartmentData)
    end
end
function lib:RemoveButtonFromCompartment(name)
    local object = self.objects[name]
    for i, entry in ipairs(AddonCompartmentFrame.registeredAddons) do
        if entry == object.compartmentData then
            object.compartmentData = nil
            table.remove(AddonCompartmentFrame.registeredAddons, i)
            AddonCompartmentFrame:UpdateDisplay()
            return
        end
    end
end

-- Icons from addon load on: Bartender4 (in the list by its TOC title),
-- AtlasLoot (its addon title is in the list), DBM (LibDBIcon put it in
-- itself), Questie (nowhere yet).
icon("Bartender4"); icon("AtlasLoot"); icon("DBM"); icon("Questie")
lib:AddButtonToCompartment("DBM")

local ns = {}
for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
        assert(loadfile(ROOT .. "/" .. line:gsub("\\", "/")))(ADDON, ns)
    end
end

local function flush()
    local pending = M.timers
    M.timers = {}
    for _, fn in ipairs(pending) do fn() end
end
-- How often each addon is in the list, colours and spaces ignored.
local function listed()
    local n = {}
    for _, data in ipairs(AddonCompartmentFrame.registeredAddons) do
        local key = data.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[^%w]", ""):lower()
        n[key] = (n[key] or 0) + 1
    end
    return n
end
local function twice()
    local list = {}
    for key, count in pairs(listed()) do if count > 1 then list[#list + 1] = key end end
    table.sort(list)
    return table.concat(list, ",")
end
local function entry(name)
    for _, data in ipairs(AddonCompartmentFrame.registeredAddons) do
        if data.text == name then return data end
    end
end

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
flush()
check("nothing before Blizzard's list", #AddonCompartmentFrame.registeredAddons, 1)

M.Fire("PLAYER_ENTERING_WORLD")
flush()
check("Questie added", listed().questie, 1)
check("Bartender4 not twice (TOC title)", listed().bartender4, 1)
check("AtlasLoot not added (addon title listed)", listed().atlasloot, nil)
check("DBM not twice (LibDBIcon's own)", listed().dbm, 1)
check("nothing twice", twice(), "")
check("count updated", AddonCompartmentFrame.count, 7)
check("other addon's settings untouched", lib.objects.Questie.db.showInCompartment, nil)

local questie = entry("Questie")
check("icon from the data object", questie.icon, "Interface\\Icons\\Questie")
questie.func(nil, { buttonName = "RightButton" }, M.newWidget())
check("click goes to the addon", clicks[1], "Questie:RightButton")
local menuButton = M.newWidget()
menuButton.GetCenter = function() return 1800, 300 end
questie.funcOnEnter(menuButton)
check("tooltip from the data object", GameTooltip.shown, "Questie")

-- Addons with only a settings page.
check("InfoPanel by its page", listed().infopanel, 1)
check("Chattynator by its page", listed().chattynator, 1)
check("page of an unknown addon left out", listed().somelibrary, nil)
check("page of an addon not loaded left out", listed().sleeper, nil)
check("game pages left out", listed().graphics, nil)
check("sub-pages left out", listed().infopanelcolors, nil)
check("button wins over page", entry("Questie") ~= nil and entry("Questie").icon, "Interface\\Icons\\Questie")
local chatty = entry("Chattynator")
check("icon from the TOC", chatty.icon, "Interface\\AddOns\\Chattynator\\Logo.png")
check("gear without a TOC icon", entry("InfoPanel").icon, "Interface\\Icons\\INV_Misc_Gear_01")
chatty.func(nil, { buttonName = "LeftButton" }, M.newWidget())
check("named ID: through the settings window", opened, "panel:Chattynator")
entry("InfoPanel").func(nil, { buttonName = "LeftButton" }, M.newWidget())
check("number ID: Blizzard's way", opened, pages[1]:GetID())
chatty.funcOnEnter(menuButton)
check("tooltip names it", GameTooltip:GetText(), "Chattynator")

-- A page made later shows before the menu opens.
page("ScreenBackdrop")
AddonCompartmentFrame.hooks.OnEnter(AddonCompartmentFrame)
check("late page added", listed().screenbackdrop, 1)

-- A new icon later, through LibDBIcon's callback.
icon("Details")
flush()
check("late icon added", listed().details, 1)

-- The addon puts itself in later: ours goes, its own stays.
lib:AddButtonToCompartment("Questie")
check("Questie still once", listed().questie, 1)
check("the addon's own entry", entry("Questie") == lib.objects.Questie.compartmentData, true)
lib:RemoveButtonFromCompartment("Questie")
check("taken out by the addon: ours again", listed().questie, 1)

-- Another addon registers itself under its own name; checked before the
-- menu opens.
AddonCompartmentFrame:RegisterAddon({ text = "Details!" })
AddonCompartmentFrame.hooks.OnEnter(AddonCompartmentFrame)
check("Details not twice", listed().details, 1)
check("nothing twice at the end", twice(), "")

local B = ns.Buttons
B.Set("compartment", "collect", false)
check("off: ours gone", listed().questie, nil)
check("off: pages gone", listed().infopanel, nil)
check("off: others kept", listed().dbm, 1)
B.Set("compartment", "collect", true)
check("on again", listed().questie, 1)
check("pages again", listed().infopanel, 1)
check("nothing twice after on/off", twice(), "")

local questieIcon = lib.objects.Questie
local own = M.byName["ForeverSquareMinimapButton"]
check("icons stay by default", questieIcon._parent, nil)
check("own button stays by default", own:IsShown(), true)
B.Set("compartment", "hideIcons", true)
check("own button off the map too", own:IsShown(), false)
check("icons off the map", questieIcon._parent ~= nil and questieIcon._parent ~= Minimap, true)
check("under a hidden parent", questieIcon._parent and questieIcon._parent:IsShown(), false)
B.Set("compartment", "show", false)
check("compartment hidden: icons back", M.reparented["LibDBIcon10_Questie"], "Minimap")
check("compartment hidden: own button back", own:IsShown(), true)
B.Set("compartment", "show", true)
B.Set("compartment", "collect", false)
check("not collected: icons back", M.reparented["LibDBIcon10_Questie"], "Minimap")
check("not collected: own button back", own:IsShown(), true)

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
