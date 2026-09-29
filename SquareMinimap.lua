--[[---------------------------------------------------------------------------
Forever Square Minimap

Makes the minimap square. Hold Ctrl and drag its bottom left corner to resize
it. Addon icons stay on the edge and can still be dragged along it.

Commands: /squareminimap or /fsm (reset | size <n> | col <x> [y] |
move <x> <y> | dump)
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L

local CONFIG = {
    minSize     = 100,
    maxSize     = 400,
    defaultSize = 260,
    gripSize    = 18,
    inset       = 2,    -- gap between the button column and the right edge
    colNudge    = 20,   -- default shift of the button column to the right
    colNudgeY   = 0,
    offsetX     = 8,    -- default shift of the whole map
    offsetY     = 53,   -- positive = up
    btnSpacing  = 2,    -- gap between the stacked buttons
    borderStyle = "GOLD",           -- NONE, FLAT or GOLD
    borderSize  = 2,                -- in screen pixels
    borderColor = { 0, 0, 0, 1 },   -- FLAT only
    borderMaxSize = 8,

    -- Blizzard's buttons go into a column on the right edge, top to bottom, so
    -- the layout is the same at every size and nothing overlaps. Only older
    -- clients have them; WoW: Forever has none of them on the map.
    buttonStack = {
        "MiniMapTracking",
        "MiniMapMailFrame",
        "MiniMapBattlefieldFrame",
    },

    -- Round decoration and buttons that only get in the way on a square map.
    -- MinimapBackdrop is the 192x192 frame: it does NOT grow with the map.
    hide = {
        "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag",
        "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton",
        "MinimapToggleButton",      -- the red X
        "MinimapZoneTextButton",    -- replaced by our own label
        "TimeManagerClockButton",   -- likewise; clicking it opened the stopwatch
        "GameTimeFrame",            -- older clients: day/night, 50x50, broke the column
    },
}

local floor, max, min = math.floor, math.max, math.min

local function Say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff70c0ff" .. L.ADDON_NAME .. ":|r " .. msg)
end

-- --------------------------------------------------------------------------
-- Shape
--
-- LibDBIcon asks a GLOBAL function GetMinimapShape() and switches from circle
-- to square maths. That is the official extension point; the library ships
-- with Questie, DBM, Details, WeakAuras, Bartender4, AtlasLoot and others.
-- --------------------------------------------------------------------------
function GetMinimapShape()
    return "SQUARE"
end

-- --------------------------------------------------------------------------
-- Icons
--
-- LibDBIcon reads Minimap:GetWidth() on every update, so after a resize a
-- refresh is enough: the buttons move to the new edge by themselves. The
-- radius stays as it is; setting it only triggers the refresh.
-- --------------------------------------------------------------------------
local function RefreshIcons()
    if not LibStub then return end
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon and icon.SetButtonRadius then
        icon:SetButtonRadius(icon.radius or 5)
    end
end

-- --------------------------------------------------------------------------
-- Size
-- --------------------------------------------------------------------------
local LayoutButtons   -- defined further down, needed here already

local function ApplySize(size)
    size = max(CONFIG.minSize, min(CONFIG.maxSize, floor(size + 0.5)))
    ns.DB().size = size
    Minimap:SetSize(size, size)

    -- Without this nudge the map does not redraw after SetSize and keeps
    -- showing the old section. Leatrix Plus does the same.
    local zoom = Minimap:GetZoom()
    if zoom < 5 then
        Minimap:SetZoom(zoom + 1)
    else
        Minimap:SetZoom(zoom - 1)
    end
    Minimap:SetZoom(zoom)

    RefreshIcons()
    LayoutButtons()
    return size
end

-- Anchors the minimap at its top right corner, so it grows towards the
-- bottom left while you drag instead of moving away from the grip.
--
-- The starting position (Blizzard's layout at login) is remembered ONCE and
-- the shift is applied to it. Taking the current position as the base would
-- add the shift up on every call.
local baseRight, baseTop

local function AnchorTopRight()
    if not baseRight then
        baseRight, baseTop = Minimap:GetRight(), Minimap:GetTop()
        if not baseRight or not baseTop then return false end
    end
    local dx = ns.DB().offsetX or CONFIG.offsetX
    local dy = ns.DB().offsetY or CONFIG.offsetY
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", baseRight + dx, baseTop + dy)
    return true
end

-- --------------------------------------------------------------------------
-- Blizzard's decoration
--
-- Every access is guarded: a frame missing in this client is skipped instead
-- of breaking the whole addon.
-- --------------------------------------------------------------------------
local function Hide(frame)
    if frame and frame.Hide then frame:Hide() end
end

-- Lifts a frame above the map. The return value is checked, not only that
-- the method exists: without a level, "+ 5" would stop the whole layout.
local function RaiseAbove(frame)
    if not frame or not frame.SetFrameLevel or not Minimap.GetFrameLevel then return end
    local level = Minimap:GetFrameLevel()
    if type(level) == "number" then frame:SetFrameLevel(level + 5) end
end

-- The instance difficulty hangs on frames that neither grow nor move with
-- the map. It moves onto the minimap itself (SetParent), so it follows it at
-- every size and position.
local function LayoutExtras()
    local function attach(name, point, relPoint, x, y)
        local f = _G[name]
        if not f or not f.SetPoint then return end
        if f.SetParent then
            f:SetParent(Minimap)
            RaiseAbove(f)
        end
        f:ClearAllPoints()
        f:SetPoint(point, Minimap, relPoint, x, y)
    end

    attach("MiniMapInstanceDifficulty", "TOPLEFT", "TOPLEFT", 2, -2)
end

-- Shift of the button column. POSITIVE = further right; it may go past the
-- map's edge (where LibDBIcon's addon icons sit too).
local function ColNudge()
    return ns.DB().colNudge  or CONFIG.colNudge,
           ns.DB().colNudgeY or CONFIG.colNudgeY
end

-- Which buttons are shown right now, as a string. When it changes, the
-- column is rebuilt.
local function VisibleSignature()
    local parts = {}
    for i, name in ipairs(CONFIG.buttonStack) do
        local f = _G[name]
        parts[i] = (f and f.IsShown and f:IsShown()) and "1" or "0"
    end
    return table.concat(parts)
end

function LayoutButtons()
    LayoutExtras()

    -- The buttons differ in width (32/33/33). Aligned on the right edge their
    -- centres would not line up, so all of them are centred on the widest.
    -- Every button is moved onto the minimap, hidden ones too: otherwise mail,
    -- for example, would stay a child of the hidden MinimapBackdrop and be
    -- invisible as soon as Blizzard shows it. Mail is placed by Mail.lua,
    -- not in the column.
    local colWidth = 0
    local members = {}
    for _, name in ipairs(CONFIG.buttonStack) do
        local f = _G[name]
        if f then
            local isMail = ns.Mail.IsMailFrame(f)
            if f.SetParent then
                f:SetParent(Minimap)
                -- Mail sets its own level (Mail.lua).
                if not isMail then RaiseAbove(f) end
            end
            if not isMail then
                members[#members + 1] = f
                local w = f.GetWidth and f:GetWidth()
                if w and w > colWidth then colWidth = w end
            end
        end
    end
    if colWidth <= 0 then colWidth = 32 end
    local nudgeX, nudgeY = ColNudge()
    local colX = -(CONFIG.inset + colWidth / 2) + nudgeX

    -- nudgeY positive = up. The column runs down from the top edge, so its
    -- start moves up (less negative).
    local y = -CONFIG.inset + nudgeY
    for _, frame in ipairs(members) do
        -- Only shown buttons take room. The battleground queue is hidden most
        -- of the time; reserving room for it would leave a gap. When it
        -- appears, the ticker rebuilds the column.
        if frame.SetPoint and frame.IsShown and frame:IsShown() then
            local h = frame.GetHeight and frame:GetHeight()
            if not h or h <= 0 then h = 24 end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", Minimap, "TOPRIGHT", colX, y - h / 2)
            y = y - h - CONFIG.btnSpacing
        end
    end
end

local function ApplyShape()
    -- Take the map out of the cluster so the cluster's bar at the top can go.
    if Minimap.SetParent then Minimap:SetParent(UIParent) end
    Hide(MinimapCluster)
    ns.Mail.Create()

    Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")

    for _, name in ipairs(CONFIG.hide) do
        -- On the modern minimap GameTimeFrame is the calendar button, which
        -- Buttons.lua keeps; on older clients it is the big day/night dial.
        if name ~= "GameTimeFrame" or not ns.Buttons.Modern() then Hide(_G[name]) end
    end
    ns.Buttons.Apply()

    LayoutButtons()

    -- The mouse wheel zooms, since the buttons are gone.
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        local levels = (self.GetZoomLevels and self:GetZoomLevels() or 6) - 1
        local zoom = self:GetZoom()
        if delta > 0 then
            if zoom < levels then self:SetZoom(zoom + 1) end
        elseif zoom > 0 then
            self:SetZoom(zoom - 1)
        end
    end)
end

-- --------------------------------------------------------------------------
-- Our own texts: zone, server time, local time, FPS and latency
--
-- Blizzard's zone bar and clock are buttons (the clock opened the stopwatch)
-- with frame art that does not grow. Font strings on the map do the same
-- job and cannot be clicked by accident. Everything about them is in
-- Infos.lua: what shows, where, in which font.
-- --------------------------------------------------------------------------
local function CreateLabels() ns.Infos.Create() end
local function UpdateLabels() ns.Infos.Update() end

-- --------------------------------------------------------------------------
-- The grip
-- --------------------------------------------------------------------------
local grip

local function StopDrag()
    if not grip or not grip.dragging then return end
    grip.dragging = false
    grip.tex:SetAlpha(0.35)
    if not grip:IsMouseOver() then grip.tex:Hide() end
end

local function CreateGrip()
    grip = CreateFrame("Frame", "ForeverSquareMinimapGrip", Minimap)
    grip:SetSize(CONFIG.gripSize, CONFIG.gripSize)
    grip:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 0, 0)
    grip:SetFrameStrata("HIGH")
    grip:EnableMouse(true)

    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints(true)
    grip.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    grip.tex:SetVertexColor(1, 0.82, 0)
    grip.tex:SetAlpha(0.35)
    grip.tex:Hide()

    grip:SetScript("OnEnter", function(self)
        self.tex:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.ADDON_NAME)
        GameTooltip:AddLine(L.GRIP_HINT, 1, 1, 1)
        GameTooltip:AddLine(L.GRIP_CURRENT:format(floor(Minimap:GetWidth() + 0.5)), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    grip:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not self.dragging then self.tex:Hide() end
    end)

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not IsControlKeyDown() then return end
        -- Remember the fixed edges: the top right corner stays put.
        self.fixedRight, self.fixedTop = Minimap:GetRight(), Minimap:GetTop()
        if not self.fixedRight or not self.fixedTop then return end
        self.dragging = true
        self.tex:SetAlpha(0.8)
        self.tex:Show()
        GameTooltip:Hide()
    end)

    grip:SetScript("OnMouseUp", StopDrag)
    grip:SetScript("OnHide", StopDrag)

    grip:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        -- Ctrl is needed only to start; releasing the mouse button ends it.
        if not IsMouseButtonDown("LeftButton") then
            StopDrag()
            return
        end
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        -- The corner follows the cursor; the square takes the longer edge.
        ApplySize(max(self.fixedRight - cx, self.fixedTop - cy))
    end)
end

-- --------------------------------------------------------------------------
-- Border
--
-- A ring around the map, drawn outside it. Four white textures coloured by
-- vertex colour: top and bottom span the full width including the corners,
-- left and right fit in between.
--
-- FLAT is one colour. GOLD is shaded like the gold border of Forever Unit
-- Frames: lit from above, light at the top, dark at the bottom, with the
-- colours meeting without a step where the sides join, and a dark line along
-- the inside. LIGHT and MID are Blizzard's own gold gradient; SHADE, DARK
-- and LINE are the same hue, darker.
-- --------------------------------------------------------------------------
local GOLD = {
    LIGHT = { 1, 1, 0.557, 1 },
    MID   = { 1, 0.792, 0.188, 1 },
    SHADE = { 0.78, 0.59, 0.13, 1 },
    DARK  = { 0.55, 0.38, 0.07, 1 },
    LINE  = { 0.2, 0.12, 0.02, 1 },
}
ns.GOLD = GOLD

local border

-- One screen pixel in the map's coordinates, so the border stays sharp at
-- any UI scale.
local function OnePixel()
    local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor and scale and scale > 0 then
        return PixelUtil.GetPixelToUIUnitFactor() / scale
    end
    return 1
end

local function NewRing(sublevel)
    local ring = {}
    for i = 1, 4 do
        ring[i] = border:CreateTexture(nil, "OVERLAY", nil, sublevel)
        ring[i]:SetColorTexture(1, 1, 1, 1)
    end
    return ring
end

-- A ring `size` thick whose outer edge lies `reach` outside the map.
local function PlaceRing(ring, size, reach)
    local inset = reach - size   -- how far outside the map the inner edge lies
    local top, bottom, left, right = ring[1], ring[2], ring[3], ring[4]
    top:ClearAllPoints()
    top:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -reach, inset)
    top:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", reach, inset)
    top:SetHeight(size)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -reach, -inset)
    bottom:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", reach, -inset)
    bottom:SetHeight(size)
    left:ClearAllPoints()
    left:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -inset, inset)
    left:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -inset, -inset)
    left:SetWidth(size)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", inset, inset)
    right:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMRIGHT", inset, -inset)
    right:SetWidth(size)
end

local function PaintFlat(ring, c)
    for i = 1, 4 do ring[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

-- A vertical gradient, bottom colour first. Newer clients take colour
-- objects, older ones eight numbers.
local function Gradient(piece, bottom, top)
    if CreateColor then
        local ok = pcall(piece.SetGradient, piece, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
            CreateColor(top[1], top[2], top[3], top[4]))
        if ok then return end
    end
    pcall(piece.SetGradient, piece, "VERTICAL",
        bottom[1], bottom[2], bottom[3], top[1], top[2], top[3])
end

-- Top: MID up to LIGHT; sides: SHADE up to MID; bottom: DARK up to SHADE.
-- Each piece starts with the colour the one below it ends with.
local function PaintGold(ring)
    PaintFlat(ring, { 1, 1, 1, 1 })
    Gradient(ring[1], GOLD.MID, GOLD.LIGHT)
    Gradient(ring[2], GOLD.DARK, GOLD.SHADE)
    Gradient(ring[3], GOLD.SHADE, GOLD.MID)
    Gradient(ring[4], GOLD.SHADE, GOLD.MID)
end

local function BorderStyle()
    local style = ns.DB().borderStyle
    if style ~= "NONE" and style ~= "FLAT" and style ~= "GOLD" then style = CONFIG.borderStyle end
    return style
end

local function BorderSize()
    local size = ns.DB().borderSize
    if type(size) ~= "number" then size = CONFIG.borderSize end
    return max(1, min(CONFIG.borderMaxSize, floor(size + 0.5)))
end

local function BorderColor()
    local c = ns.DB().borderColor
    if type(c) ~= "table" then c = CONFIG.borderColor end
    return c
end

local function ApplyBorder()
    if not border then
        border = CreateFrame("Frame", "ForeverSquareMinimapBorder", Minimap)
        border:SetAllPoints(Minimap)
        border.ring = NewRing(0)
        border.line = NewRing(1)   -- the gold style's inner line, drawn on top
    end
    local style = BorderStyle()
    if style == "NONE" then
        border:Hide()
        return
    end
    border:Show()
    local px = OnePixel()
    local size = BorderSize() * px
    PlaceRing(border.ring, size, size)
    if style == "GOLD" then
        PaintGold(border.ring)
        -- The line takes the ring's innermost pixel, but leaves a one pixel
        -- ring all gold.
        if BorderSize() >= 2 then
            PlaceRing(border.line, px, px)
            PaintFlat(border.line, GOLD.LINE)
            for i = 1, 4 do border.line[i]:Show() end
        else
            for i = 1, 4 do border.line[i]:Hide() end
        end
    else
        PaintFlat(border.ring, BorderColor())
        for i = 1, 4 do border.line[i]:Hide() end
    end
end

-- Everything that depends on the profile, e.g. after switching profiles.
local function ApplyLook()
    local size = ns.DB().size
    if type(size) ~= "number" then size = CONFIG.defaultSize end
    AnchorTopRight()
    ApplySize(size)
    ApplyBorder()
    ns.Infos.Apply()
    UpdateLabels()
    ns.MinimapButton.Place()
    ns.Mail.Apply()
    ns.Buttons.Apply()
    ns.Fade.Apply()
end

-- --------------------------------------------------------------------------
-- Start
-- --------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if type(ns.DB().size) ~= "number" then
        ns.DB().size = CONFIG.defaultSize
    end

    ApplyShape()
    AnchorTopRight()
    ApplySize(ns.DB().size)
    ApplyBorder()
    CreateGrip()
    CreateLabels()
    UpdateLabels()
    ns.MinimapButton.Create()
    ns.Fade.Create()

    -- Icons need a moment until every addon has registered its button.
    -- LibDBIcon waits for the same reason.
    C_Timer.After(2, RefreshIcons)

    -- Labels once a second. OnUpdate rather than zone events: setting a font
    -- string once a second costs nothing, and the column is rebuilt only
    -- when a button appears or disappears.
    events:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 1 then return end
        self.since = 0
        UpdateLabels()
        ns.Buttons.Check()

        local sig = VisibleSignature()
        if sig ~= self.lastSignature then
            self.lastSignature = sig
            LayoutButtons()
        end
    end)
end)

-- --------------------------------------------------------------------------
-- Copy window for the diagnostics
--
-- BasicFrameTemplate does not exist in every client; CreateFrame raises an
-- error then. So try the templates and build a plain frame as a fallback.
-- --------------------------------------------------------------------------
local function ShowCopyBox(text)
    if not ForeverSquareMinimapDump then
        local f
        for _, tpl in ipairs({ "BasicFrameTemplateWithInset", "BasicFrameTemplate" }) do
            local ok, frame = pcall(CreateFrame, "Frame", "ForeverSquareMinimapDump", UIParent, tpl)
            if ok and frame then f = frame break end
        end
        if not f then
            f = CreateFrame("Frame", "ForeverSquareMinimapDump", UIParent)
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0, 0, 0, 0.9)
            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -2, -2)
            close:SetScript("OnClick", function() f:Hide() end)
        end

        f:SetSize(660, 480)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        local title = f.TitleText or _G["ForeverSquareMinimapDumpTitleText"]
        if not title then
            title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOP", 0, -10)
        end
        title:SetText(L.ADDON_NAME)
        tinsert(UISpecialFrames, "ForeverSquareMinimapDump")

        local sf = CreateFrame("ScrollFrame", "ForeverSquareMinimapDumpScroll", f,
                               "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -34)
        sf:SetPoint("BOTTOMRIGHT", -34, 34)

        local eb = CreateFrame("EditBox", "ForeverSquareMinimapDumpEdit", sf)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        local sw = sf:GetWidth()
        eb:SetWidth(((sw and sw > 0) and sw or 612) - 8)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)

        f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.hint:SetPoint("BOTTOMLEFT", 16, 12)
    end

    ForeverSquareMinimapDump.hint:SetText(L.DUMP_HINT)
    ForeverSquareMinimapDumpEdit:SetText(text)
    ForeverSquareMinimapDumpEdit:HighlightText()
    ForeverSquareMinimapDump:Show()
    ForeverSquareMinimapDumpEdit:SetFocus()
end

-- The diagnostics: which minimap frames really exist in this client, their
-- size, anchor and parent. Kept in English whatever the language, so it can
-- be pasted into a bug report as it is.
local function DumpText()
    local lines = {}
    local function add(line) lines[#lines + 1] = line end

    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = getMetadata and getMetadata(ADDON, "Version")
    local client, _, _, interface = GetBuildInfo()
    add(("Forever Square Minimap %s, client %s, interface %s"):format(
        tostring(version or "?"), tostring(client), tostring(interface)))
    add(("Minimap: %dx%d  points: %d"):format(
        floor(Minimap:GetWidth() + 0.5), floor(Minimap:GetHeight() + 0.5),
        Minimap:GetNumPoints()))
    if Minimap:GetNumPoints() > 0 then
        local pt, rel, relPt, x, y = Minimap:GetPoint(1)
        add(("  anchored %s to %s.%s  %d,%d"):format(
            tostring(pt), (rel and rel.GetName and rel:GetName()) or "-",
            tostring(relPt), floor((x or 0) + 0.5), floor((y or 0) + 0.5)))
    end
    add("")
    add(("%-26s %-9s %-14s %-16s %-12s %-16s %s"):format(
        "Frame", "Size", "Point", "to", "Offset", "State", "Parent"))
    add(string.rep("-", 116))

    local names = {
        "MinimapCluster", "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop",
        "MinimapNorthTag", "MinimapZoneTextButton", "MinimapZoneText",
        "MiniMapWorldMapButton", "MinimapZoomIn", "MinimapZoomOut",
        "MiniMapTracking", "MiniMapTrackingButton", "MiniMapTrackingFrame",
        "MiniMapMailFrame", "MiniMapMailBorder", "MiniMapBattlefieldFrame",
        "MiniMapBattlefieldBorder", "GameTimeFrame", "MiniMapLFGFrame",
        "MiniMapVoiceChatFrame", "MinimapToggleButton", "TimeManagerClockButton",
        "QueueStatusMinimapButton", "MiniMapInstanceDifficulty",
    }
    for _, name in ipairs(names) do
        local f = _G[name]
        if not f then
            add(("%-26s %s"):format(name, "does not exist"))
        else
            local w = (f.GetWidth and f:GetWidth()) or 0
            local h = (f.GetHeight and f:GetHeight()) or 0
            local pt, relName, relPt, x, y = "-", "-", "-", 0, 0
            if f.GetNumPoints and f:GetNumPoints() > 0 then
                local r
                pt, r, relPt, x, y = f:GetPoint(1)
                relName = (r and r.GetName and r:GetName()) or "-"
            end
            local shown   = f.IsShown   and f:IsShown()
            local visible = f.IsVisible and f:IsVisible()
            local state
            if shown and visible then
                state = "visible"
            elseif shown then
                -- The important case: shown itself, but a parent is hidden.
                -- In the game it looks just like "gone".
                state = "PARENT HIDDEN"
            else
                state = "hidden"
            end
            local parent = f.GetParent and f:GetParent()
            add(("%-26s %3dx%-5d %-14s %-16s %-12s %-16s parent=%s"):format(
                name, floor(w + 0.5), floor(h + 0.5),
                tostring(pt), tostring(relName) .. "." .. tostring(relPt),
                ("%d,%d"):format(floor((x or 0) + 0.5), floor((y or 0) + 0.5)),
                state,
                (parent and parent.GetName and parent:GetName()) or "-"))
        end
    end
    return table.concat(lines, "\n")
end
ns.DumpText = DumpText

-- --------------------------------------------------------------------------
-- Slash command
-- --------------------------------------------------------------------------
SLASH_FOREVERSQUAREMINIMAP1 = "/squareminimap"
SLASH_FOREVERSQUAREMINIMAP2 = "/fsm"
SlashCmdList["FOREVERSQUAREMINIMAP"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "reset" then
        ns.DB().offsetX, ns.DB().offsetY = nil, nil
        ns.DB().colNudge, ns.DB().colNudgeY = nil, nil
        AnchorTopRight()
        Say(L.MSG_RESET:format(ApplySize(CONFIG.defaultSize)))
        return
    end

    if msg == "dump" then
        ShowCopyBox(DumpText())
        return
    end

    local mx, my = msg:match("^move%s+(%-?%d+)%s+(%-?%d+)$")
    if mx then
        ns.DB().offsetX = tonumber(mx)
        ns.DB().offsetY = tonumber(my)
        AnchorTopRight()
        Say(L.MSG_MOVED:format(mx, my))
        Say(L.MSG_POSITIVE)
        return
    end

    local cx, cy = msg:match("^col%s+(%-?%d+)%s+(%-?%d+)$")
    if not cx then cx = msg:match("^col%s+(%-?%d+)$") end
    if cx then
        ns.DB().colNudge = tonumber(cx)
        if cy then ns.DB().colNudgeY = tonumber(cy) end
        LayoutButtons()
        Say(L.MSG_COLUMN:format(tostring(ns.DB().colNudge), tostring(ns.DB().colNudgeY or 0)))
        Say(L.MSG_POSITIVE)
        return
    end

    local n = msg:match("^size%s+(%d+)$")
    if n then
        Say(L.MSG_SIZE:format(ApplySize(tonumber(n))))
        return
    end

    Say(L.MSG_STATUS:format(floor(Minimap:GetWidth() + 0.5)))
    Say("/squareminimap reset | size <n> | col <x> [y] | move <x> <y> | dump")
end

-- For the options page, which lives in its own file of the same addon.
ns.api = {
    ApplySize      = function(v) return ApplySize(v) end,
    AnchorTopRight = function() return AnchorTopRight() end,
    LayoutButtons  = function() return LayoutButtons() end,
    -- Setting changes on the texts must act at once, not on the next tick.
    UpdateLabels   = function() return UpdateLabels() end,
    ApplyInfos     = function() ns.Infos.Apply(); ns.Infos.Update() end,
    ApplyLook      = function() return ApplyLook() end,
    ApplyBorder    = function() return ApplyBorder() end,
    Config         = CONFIG,
}
