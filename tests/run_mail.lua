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
print("Mail without MiniMapMailFrame")

_G.MiniMapMailFrame = nil
M.newMail = false
_G.HasNewMail = function() return M.newMail end
_G.GetLatestThreeSenders = function() return "Alice", "Bob" end
_G.HAVE_MAIL_FROM = "Unread mail from:"

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
check("placed in the column", placed ~= nil, true)
check("on the minimap's corner", placed and placed[4], "Minimap")
check("below tracking", placed and placed[3] < M.placed["MiniMapTracking"][3], true)

local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
GameTooltip.SetText = function(_, t) lines[#lines + 1] = t end
mail:GetScript("OnEnter")(mail)
check("tooltip names the senders", table.concat(lines, ","), "Unread mail from:,Alice,Bob")

M.newMail = false
mail:GetScript("OnEvent")(mail, "UPDATE_PENDING_MAIL")
check("hidden once read", mail:IsShown(), false)
ticker:GetScript("OnUpdate")(ticker, 1.0)

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
