--[[---------------------------------------------------------------------------
Mail.lua -- the mail icon: where it sits, how big, and how it catches the eye.

Older clients have MiniMapMailFrame, which is used as it is. Forever has the
modern minimap instead: the mail icon lives in MinimapCluster.IndicatorFrame,
which is hidden with the cluster, and it cannot be moved out: on new mail its
own code calls self:GetParent():Layout(), which the minimap does not have. So
there it gets an icon of its own, with Blizzard's art and the same event.

By default the icon sits just past the map's top left corner. It can be
placed anywhere (a point on the map, the icon's own point, X/Y, so also
outside the map), scaled, switched off, and animated while there is unread
mail. The options can show it as a test, since mail cannot
be summoned to check the look.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Mail = {}
ns.Mail = Mail

Mail.NAME = "ForeverSquareMinimapMail"
local ATLAS = "ui-hud-minimap-mail-up"
local FALLBACK = "Interface\\Minimap\\Tracking\\Mailbox"
local ICON_W, ICON_H = 24, 18
-- The border sits one level above the map (Blizzard's default for a child).
Mail.LEVEL_ABOVE_MAP = 10

Mail.ANIMS = { "NONE", "PULSE", "BOUNCE", "GLOW" }
-- By default just past the map's top left corner, glowing.
Mail.DEFAULTS = { show = true, mapPoint = "TOPLEFT", point = "TOPLEFT", x = -13, y = 2,
    scale = 100, anim = "GLOW" }

-- Shown as a test from the options; never stored.
Mail.preview = false

-- Settings: in the active profile under mail[field].
function Mail.Get(field)
    local own = ns.DB().mail
    local v = own and own[field]
    if v == nil then return Mail.DEFAULTS[field] end
    return v
end

function Mail.Set(field, value)
    local db = ns.DB()
    db.mail = db.mail or {}
    db.mail[field] = value
    Mail.Apply()
end

-- The mail frame of this client: Blizzard's where it can be used, ours
-- otherwise.
function Mail.Frame()
    return _G.MiniMapMailFrame or _G[Mail.NAME]
end

function Mail.IsMailFrame(frame)
    return frame ~= nil and frame == Mail.Frame()
end

local function hasMail()
    return HasNewMail and HasNewMail() and true or false
end

-- Tooltip ---------------------------------------------------------------------
local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    -- Not "fn and fn()": "and" keeps only the first of several results.
    local senders = {}
    if GetLatestThreeSenders then senders = { GetLatestThreeSenders() } end
    local header = #senders >= 1 and HAVE_MAIL_FROM or HAVE_MAIL
    if not (FormatUnreadMailTooltip and pcall(FormatUnreadMailTooltip, GameTooltip, header, senders)) then
        GameTooltip:SetText(header or "")
        for _, sender in ipairs(senders) do GameTooltip:AddLine(sender, 1, 1, 1) end
    end
    GameTooltip:Show()
end

-- Our own icon (Forever) --------------------------------------------------------
local function setArt(texture)
    if not pcall(texture.SetAtlas, texture, ATLAS) then texture:SetTexture(FALLBACK) end
end

local function updateOwn(f)
    f:SetShown(hasMail() or Mail.preview)
end

local function createOwn()
    local f = CreateFrame("Frame", Mail.NAME, Minimap)
    f:SetSize(ICON_W, ICON_H)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    setArt(f.icon)
    f:EnableMouse(true)
    f:SetScript("OnEnter", showTooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:RegisterEvent("UPDATE_PENDING_MAIL")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", updateOwn)
    updateOwn(f)
    return f
end

-- Animation ---------------------------------------------------------------------
-- A driver on the mail frame: its OnUpdate runs only while the icon shows.
-- It moves and sizes the icon's art, never the frame, so the layout stays.
local anim = {}

local function artOf(frame)
    if frame.icon then return frame.icon, ICON_W, ICON_H end
    local icon = _G.MiniMapMailIcon
    if not icon then return end
    local w, h = icon:GetWidth(), icon:GetHeight()
    if not w or w <= 0 then w = 18 end
    if not h or h <= 0 then h = 18 end
    return icon, w, h
end

local function placeArt(scale, dy)
    local t = anim.art
    t:ClearAllPoints()
    t:SetPoint("CENTER", anim.frame, "CENTER", 0, dy)
    t:SetSize(anim.w * scale, anim.h * scale)
end

-- One frame of the animation at time t (seconds): size, lift and glow.
-- Pure numbers, so the tests can check each style.
function Mail.AnimFrame(style, t)
    if style == "PULSE" then
        return 1 + 0.15 * math.sin(t * 2 * math.pi / 1.2), 0, 0
    elseif style == "BOUNCE" then
        -- Two hops, then a rest: every two seconds.
        local p = t % 2
        if p < 0.6 then return 1, 6 * math.abs(math.sin(p / 0.6 * 2 * math.pi)), 0 end
        return 1, 0, 0
    elseif style == "GLOW" then
        return 1, 0, 0.5 + 0.5 * math.sin(t * 2 * math.pi / 1.4)
    end
    return 1, 0, 0
end

local function tick(_, elapsed)
    anim.t = (anim.t or 0) + (elapsed or 0)
    local scale, dy, glow = Mail.AnimFrame(Mail.Get("anim"), anim.t)
    placeArt(scale, dy)
    anim.glow:SetAlpha(glow)
end

local function createAnim(frame)
    local art, w, h = artOf(frame)
    if not art then return end
    anim.frame, anim.art, anim.w, anim.h = frame, art, w, h
    -- The glow: the same art added on top.
    anim.glow = frame:CreateTexture(nil, "OVERLAY")
    setArt(anim.glow)
    if frame.icon == nil and art.GetTexture then anim.glow:SetTexture(art:GetTexture()) end
    anim.glow:SetBlendMode("ADD")
    anim.glow:SetAllPoints(art)
    anim.glow:SetAlpha(0)
    anim.driver = CreateFrame("Frame", nil, frame)
end

local function applyAnim()
    if not anim.driver then return end
    if Mail.Get("anim") == "NONE" then
        anim.driver:SetScript("OnUpdate", nil)
        placeArt(1, 0)
        anim.glow:SetAlpha(0)
    else
        anim.driver:SetScript("OnUpdate", tick)
    end
end

-- Setup and placement -------------------------------------------------------------
function Mail.Create()
    if not _G.MiniMapMailFrame and not _G[Mail.NAME] then createOwn() end
    local frame = Mail.Frame()
    if frame and not anim.driver then createAnim(frame) end
    Mail.Apply()
end

-- Shows the icon as a test (from the options) or ends the test.
function Mail.SetPreview(on)
    Mail.preview = on and true or false
    local frame = Mail.Frame()
    if not frame then return end
    if frame == _G[Mail.NAME] then
        updateOwn(frame)
    elseif Mail.preview then
        frame:Show()
    elseif not hasMail() then
        frame:Hide()
    end
    Mail.Apply()
end

function Mail.Apply()
    local frame = Mail.Frame()
    if not frame then return end
    local on = Mail.Get("show") or Mail.preview
    -- Alpha, not Hide: Blizzard's frame shows itself on new mail.
    frame:SetAlpha(on and 1 or 0)
    if frame.EnableMouse then frame:EnableMouse(on) end
    -- Above the map's border: on the same level the border, made later,
    -- would cover it where the icon reaches past the edge.
    local level = Minimap.GetFrameLevel and Minimap:GetFrameLevel()
    if type(level) == "number" then frame:SetFrameLevel(level + Mail.LEVEL_ABOVE_MAP) end
    local scale = math.max(0.25, (Mail.Get("scale") or 100) / 100)
    frame:SetScale(scale)
    applyAnim()
    -- Offsets count in the frame's own scale: divided, they stay pixels.
    frame:ClearAllPoints()
    frame:SetPoint(Mail.Get("point"), Minimap, Mail.Get("mapPoint"), Mail.Get("x") / scale,
        Mail.Get("y") / scale)
end
