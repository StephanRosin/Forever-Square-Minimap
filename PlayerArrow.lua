--[[---------------------------------------------------------------------------
PlayerArrow.lua -- a bigger player arrow on the map.

The client draws the player arrow itself; Forever has no way to size it alone
(SetPlayerTexture* are gone, SetIconScale grows every icon). So above 100 %
our own arrow (Media/IconMinimapArrow.tga, pointing north like Blizzard's)
lies over it in the middle of the map and turns with the player. Where GetPlayerFacing gives nothing (instances) it
hides and Blizzard's small arrow shows.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local PlayerArrow = {}
ns.PlayerArrow = PlayerArrow

PlayerArrow.TEXTURE = "Interface\\AddOns\\ForeverSquareMinimap\\Media\\IconMinimapArrow.tga"
-- shortcut: the size Blizzard's arrow seems to have; calibrate in game if 100 % looks off.
PlayerArrow.BASE = 32
PlayerArrow.DEFAULT = 100

function PlayerArrow.Get()
    local v = ns.DB().playerArrow
    return type(v) == "number" and v or PlayerArrow.DEFAULT
end

-- The arrow's turn: the player's facing, or straight up on a turning map.
function PlayerArrow.Facing()
    if GetCVarBool and GetCVarBool("rotateMinimap") then return 0 end
    return GetPlayerFacing and GetPlayerFacing()
end

local function update(frame)
    local facing = PlayerArrow.Facing()
    frame.icon:SetShown(facing ~= nil)
    if facing then frame.icon:SetRotation(facing) end
end

-- Every icon the client draws on the map: quests, points of interest, tracking
-- and its arrow. Blizzard's slider for it sits in Edit Mode on the cluster this
-- addon hides. Account wide, outside profiles and theme sets; nil = never set
-- here, Blizzard's value stays.
function PlayerArrow.Icons()
    local v = ns.AccountDB().iconScale
    return type(v) == "number" and v or nil
end

-- Edit Mode sets its own value again whenever a layout is applied, and the map
-- has no getter to notice it: the one-second tick repeats ours.
function PlayerArrow.ApplyIcons()
    local v = PlayerArrow.Icons()
    if v and Minimap.SetIconScale then Minimap:SetIconScale(v / 100) end
end

function PlayerArrow.SetIcons(v)
    ns.AccountDB().iconScale = v
    PlayerArrow.ApplyIcons()
    PlayerArrow.Apply()
end

function PlayerArrow.Apply()
    PlayerArrow.ApplyIcons()
    local scale = PlayerArrow.Get()
    local frame = PlayerArrow.frame
    if scale <= 100 then
        if frame then frame:Hide() end
        return
    end
    if not frame then
        frame = CreateFrame("Frame", nil, Minimap)
        frame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        frame.icon = frame:CreateTexture(nil, "OVERLAY")
        frame.icon:SetAllPoints()
        frame.icon:SetTexture(PlayerArrow.TEXTURE)
        frame:SetScript("OnUpdate", update)
        PlayerArrow.frame = frame
    end
    -- Blizzard's arrow grows with the icons; ours has to keep covering it.
    local size = PlayerArrow.BASE * scale / 100 * (PlayerArrow.Icons() or 100) / 100
    frame:SetSize(size, size)
    frame:Show()
    update(frame)
end

function PlayerArrow.Set(v)
    ns.DB().playerArrow = v
    PlayerArrow.Apply()
end
