-- Mail on a client without MiniMapMailFrame (Forever): the addon's own mail
-- icon. A separate run: it needs a client without that frame from the start.
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
print("WoW: Forever: mail without MiniMapMailFrame, buttons on the cluster")

_G.MiniMapMailFrame = nil
M.newMail = false
_G.HasNewMail = function() return M.newMail end
_G.GetLatestThreeSenders = function() return "Alice", "Bob" end
_G.HAVE_MAIL_FROM = "Unread mail from:"
-- The modern minimap: tracking and difficulty hang from the cluster, the
-- calendar and the addon compartment are globals parented to it.
MinimapCluster.Tracking = M.newWidget("ClusterTracking")
MinimapCluster.Tracking.Background = MinimapCluster.Tracking:CreateTexture()
MinimapCluster.Tracking.Button = M.newWidget("ClusterTrackingButton")
MinimapCluster.InstanceDifficulty = M.newWidget("ClusterDifficulty")
_G.AddonCompartmentFrame = M.newWidget("AddonCompartmentFrame")

local ns = {}
for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
        assert(loadfile(ROOT .. "/" .. line:gsub("\\", "/")))(ADDON, ns)
    end
end
M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")

local mail = M.byName["ForeverSquareMinimapMail"]
check("own mail icon", mail ~= nil, true)
check("above the border", M.level["ForeverSquareMinimapMail"], 3 + ns.Mail.LEVEL_ABOVE_MAP)
check("hidden without mail", mail:IsShown(), false)
M.newMail = true
mail:GetScript("OnEvent")(mail, "UPDATE_PENDING_MAIL")
check("shown on new mail", mail:IsShown(), true)

local ticker
for _, f in ipairs(M.frames) do
    if f:GetScript("OnUpdate") and f._events["PLAYER_LOGIN"] then ticker = f end
end
ticker:GetScript("OnUpdate")(ticker, 1.0)
local placed = M.placed["ForeverSquareMinimapMail"]
check("placed", placed ~= nil, true)
check("on the minimap", placed and placed[4], "Minimap")
check("past the top left corner", mail._anchor[1] .. ">" .. mail._anchor[3], "TOPLEFT>TOPLEFT")

local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
GameTooltip.SetText = function(_, t) lines[#lines + 1] = t end
mail:GetScript("OnEnter")(mail)
check("tooltip names the senders", table.concat(lines, ","), "Unread mail from:,Alice,Bob")

M.newMail = false
mail:GetScript("OnEvent")(mail, "UPDATE_PENDING_MAIL")
check("hidden once read", mail:IsShown(), false)
ticker:GetScript("OnUpdate")(ticker, 1.0)

-- The test view from the options shows our icon without mail.
ns.Mail.SetPreview(true)
check("test view shows it", mail:IsShown(), true)
ns.Mail.SetPreview(false)
check("test view over: hidden", mail:IsShown(), false)
M.newMail = true
ns.Mail.SetPreview(true)
ns.Mail.SetPreview(false)
mail:GetScript("OnEvent")(mail, "UPDATE_PENDING_MAIL")
check("real mail stays shown", mail:IsShown(), true)
M.newMail = false
mail:GetScript("OnEvent")(mail, "UPDATE_PENDING_MAIL")

-- Blizzard's buttons: on the map, placed, above the border.
local B = ns.Buttons
check("modern client", B.Modern(), true)
local track, cal = MinimapCluster.Tracking, GameTimeFrame
check("tracking on the map", M.reparented["ClusterTracking"], "Minimap")
check("tracking in the bottom right corner", track._anchor[1] .. ">" .. track._anchor[3], "BOTTOMRIGHT>BOTTOMRIGHT")
check("tracking hangs from the map", track._anchor[2], Minimap)
check("calendar kept, not hidden", cal:IsShown(), true)
check("calendar on the map", M.reparented["GameTimeFrame"], "Minimap")
check("compartment on the map", M.reparented["AddonCompartmentFrame"], "Minimap")
check("difficulty bottom right", MinimapCluster.InstanceDifficulty._anchor[3], "BOTTOMRIGHT")
check("above the border", M.level["ClusterTracking"], 3 + 10)
check("like the mail icon: no round background", track.Background:GetAlpha(), 0)
check("like the mail icon: one size", track:GetWidth() .. "x" .. track:GetHeight() .. " " .. cal:GetWidth(), "20x20 20")
check("tracking art fills it", M.anchors["ClusterTrackingButton"], nil)
check("compartment: a gear, not just the count", AddonCompartmentFrame.fsmIcon ~= nil, true)
check("compartment: grey like the calendar", AddonCompartmentFrame.fsmIcon._color and AddonCompartmentFrame.fsmIcon._color[3], 0.8)
B.Set("tracking", "show", false)
check("off: invisible", track:GetAlpha(), 0)
check("off: no mouse", M.mouse["ClusterTracking"], false)
B.Set("tracking", "show", true)
B.Set("calendar", "scale", 200)
check("scaled", cal:GetScale(), 2)
check("offsets stay pixels", track._anchor[4] .. "," .. track._anchor[5], "-2,28")
B.Set("tracking", "scale", 200)
check("scaled offsets stay pixels", track._anchor[4] .. "," .. track._anchor[5], "-1,14")
local applied = 0
local realApply = B.Apply
B.Apply = function() applied = applied + 1; realApply() end
B.Check()
check("in place: nothing redone", applied, 0)
-- Blizzard puts the difficulty back to its own place (Edit Mode header).
MinimapCluster.InstanceDifficulty:SetPoint("BOTTOMRIGHT", MinimapCluster, "TOPRIGHT", -2, -2)
B.Check()
check("put back on the map", MinimapCluster.InstanceDifficulty._anchor[2], Minimap)
B.Apply = realApply
ns.DB().buttons = nil
B.Apply()
check("a sixth page for the buttons", ns.Window.PageCount(), 6)

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
