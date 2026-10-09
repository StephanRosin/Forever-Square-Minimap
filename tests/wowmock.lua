-- A mock of the WoW API, just enough for Forever Square Minimap. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, hidden = {}, placed = {},
            reparented = {}, timers = {}, textures = {},
            fontStrings = {}, labelText = {}, anchors = {},
            strata = {}, level = {}, mouse = {} }

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are widget methods. Everything else is the addon's
    -- own data and must be nil as in the game, or the mock would hide real
    -- state (e.g. "dragging").
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name)
    local w = setmetatable({ _name = name, _scripts = {}, _events = {},
                             _w = 140, _h = 140, _shown = true }, widget)
    function w:GetName()  return self._name end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s)     return self._scripts[s] end
    function w:SetSize(a, b)    self._w, self._h = a, b end
    function w:GetWidth()       return self._w end
    function w:GetHeight()      return self._h end
    function w:Hide()  self._shown = false; M.hidden[self._name or self] = true end
    function w:Show()  self._shown = true end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:SetAlpha(v) self._alpha = v end
    function w:GetAlpha() return self._alpha or 1 end
    function w:SetScale(v) self._scale = v end
    function w:GetScale() return self._scale or 1 end
    function w:GetEffectiveScale() return 1 end
    function w:GetFrameLevel() return 3 end
    function w:CreateTexture()
        local t = newWidget()
        M.textures[#M.textures + 1] = t
        t._owner = self
        function t:SetVertexColor(r, g, b, a) self._color = { r, g, b, a } end
        function t:SetTexture(file) self._texture = file end
        function t:SetTexCoord(...) self._coords = { ... } end
        function t:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
        function t:SetHeight(v) self._h = v end
        function t:SetWidth(v) self._w = v end
        return t
    end
    -- Font strings: the template's font (GameFontNormal 12, the small one
    -- 10), a width of 6 px per visible character, a line as high as the
    -- font; SetPoint also keeps what it hangs from (_anchor).
    function w:CreateFontString(_, _, template)
        local fs = newWidget()
        M.fontStrings[#M.fontStrings + 1] = fs
        fs._font = { "Fonts\\FRIZQT__.TTF", template == "GameFontNormal" and 12 or 10, "" }
        fs._template = template
        fs._fontString = true
        function fs:SetText(t) self._text = t; M.labelText[self] = t end
        function fs:SetPoint(p, rel, p2, x, y)
            M.placed[self] = { p, x, y }
            self._anchor = { p, rel, p2, x, y }
        end
        function fs:GetFont() return self._font[1], self._font[2], self._font[3] end
        function fs:SetFont(path, size, flags) self._font = { path, size, flags } end
        function fs:SetJustifyH(v) self._justify = v end
        function fs:GetStringWidth()
            local visible = tostring(self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            return #visible * 6
        end
        function fs:GetStringHeight() return self._font[2] end
        return fs
    end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetPoint(p, rel, p2, x, y)
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._anchor = { p, rel, p2, x, y }
        M.placed[self._name or self] = { p, x, y, rel and rel.GetName and rel:GetName() }
        local key = self._name or self
        M.anchors[key] = M.anchors[key] or {}
        M.anchors[key][p] = rel and rel.GetName and rel:GetName()
    end
    function w:ClearAllPoints() M.anchors[self._name or self] = nil end
    function w:GetNumPoints() return M.placed[self._name or self] and 1 or 0 end
    function w:GetPoint()
        local a = self._anchor
        if a then return a[1], a[2], a[3], a[4], a[5] end
    end
    function w:SetFrameStrata(v) M.strata[self._name or self] = v end
    function w:GetFrameStrata()  return M.strata[self._name or self] or "MEDIUM" end
    function w:SetFrameLevel(v)  M.level[self._name or self] = v end
    function w:EnableMouse(v)    M.mouse[self._name or self] = v end
    function w:SetParent(parent)
        self._parent = parent
        M.reparented[self._name or self] = parent and parent.GetName and parent:GetName()
    end
    return w
end
M.newWidget = newWidget

-- Four return values as in the game; the fourth is the interface number.
M.build = { "2.5.6", "69110", "Aug 12 2026", 20506 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
function M.setBuild(v, i) M.build = { v, "0", "Jan 1 2026", i } end

-- As in the game: a frame can only hang from another frame.
function CreateFrame(_, name, parent, _)
    if type(parent) == "table" and parent._fontString then error("Wrong object type for function", 2) end
    local f = newWidget(name)
    table.insert(M.frames, f)
    if name then M.byName[name] = f; _G[name] = f end
    return f
end

-- Delivers an event to every frame that registered it, in creation order
-- (as the client does).
function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local handler = f._events[event] and f:GetScript("OnEvent")
        if handler then handler(f, event, ...) end
    end
end

function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
PixelUtil = { GetPixelToUIUnitFactor = function() return M.pixelFactor end }
M.pixelFactor = 0.8

M.locale = "enUS"
function GetLocale() return M.locale end
StaticPopupDialogs = {}
M.popups = {}
function StaticPopup_Show(which, a) M.popups[#M.popups + 1] = { which = which, text = StaticPopupDialogs[which].text, arg = a } end

UIParent = newWidget("UIParent")
-- A screen 1920 wide; see M.minimapRight for the map.
function UIParent:GetRight() return 1920 end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(M.chat, m) end }
SlashCmdList = {}
GameTooltip = newWidget("GameTooltip")

C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }

M.state = { ctrl = false, mouseDown = false, cursor = {0, 0}, zoom = 3 }
function GetMinimapZoneText() return "Gadgetzan" end
function GetZoneText()        return "Tanaris" end
M.serverTime = { 21, 7 }
M.localTime = { hour = 21, min = 7 }
function GetGameTime()        return M.serverTime[1], M.serverTime[2] end
function date(fmt)
    if fmt == "*t" then return { hour = M.localTime.hour, min = M.localTime.min } end
    return ("%02d:%02d"):format(M.localTime.hour, M.localTime.min)
end

function IsControlKeyDown()  return M.state.ctrl end
function IsMouseButtonDown() return M.state.mouseDown end
function GetCursorPosition() return M.state.cursor[1], M.state.cursor[2] end

-- The minimap: remembers its size, positioned from a fixed top right corner.
Minimap = newWidget("Minimap")
M.minimapRight, M.minimapTop = 1900, 800
function Minimap:GetRight() return M.minimapRight end
function Minimap:GetTop()   return M.minimapTop end
function Minimap:GetCenter() return M.minimapRight - self._w / 2, M.minimapTop - self._h / 2 end
function Minimap:GetZoom()  return M.state.zoom end
function Minimap:SetZoom(z) M.state.zoom = z; M.zoomCalls = (M.zoomCalls or 0) + 1 end
function Minimap:GetZoomLevels() return 6 end

-- Blizzard's frames the addon touches, sized as measured in the game.
local blizzHeights = {
    MinimapBorder = 192, MinimapNorthTag = 16, MinimapZoomIn = 32, MinimapZoomOut = 32,
    MiniMapTracking = 32, MiniMapMailFrame = 33, MiniMapBattlefieldFrame = 33,
    GameTimeFrame = 50, MinimapBackdrop = 192, MinimapToggleButton = 32,
    MinimapZoneTextButton = 12, TimeManagerClockButton = 28,
    MiniMapInstanceDifficulty = 46, MiniMapWorldMapButton = 33,
    MinimapCluster = 165,
}
-- Widths from the same measurement: 32/33/33/50. The difference is why the
-- column is aligned on the buttons' centres.
local blizzWidths = {
    MinimapBorder = 192, MinimapNorthTag = 16, MinimapZoomIn = 32, MinimapZoomOut = 32,
    MiniMapTracking = 32, MiniMapMailFrame = 33, MiniMapBattlefieldFrame = 33,
    GameTimeFrame = 50, MinimapBackdrop = 192, MinimapToggleButton = 32,
    MinimapZoneTextButton = 140, TimeManagerClockButton = 60,
    MiniMapInstanceDifficulty = 38, MiniMapWorldMapButton = 33,
    MinimapCluster = 177,
}
-- Mail and battleground are usually hidden: the column must leave no gap.
local blizzHidden = { MiniMapMailFrame = true, MiniMapBattlefieldFrame = true }
for n, h in pairs(blizzHeights) do
    local f = newWidget(n)
    f._h = h
    f._w = blizzWidths[n] or h
    f._shown = not blizzHidden[n]
    _G[n] = f
end
-- MinimapBorderTop and MiniMapLFGFrame do not exist in the client; they stay
-- nil on purpose, so the addon's guards are tested.

-- LibDBIcon
M.iconRefreshes = 0
local dbicon = { radius = 5 }
function dbicon:SetButtonRadius(r) self.radius = r; M.iconRefreshes = M.iconRefreshes + 1 end
LibStub = function(name) if name == "LibDBIcon-1.0" then return dbicon end end

return M
