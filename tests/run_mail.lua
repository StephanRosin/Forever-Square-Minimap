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

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
