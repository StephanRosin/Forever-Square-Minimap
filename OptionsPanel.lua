--[[---------------------------------------------------------------------------
OptionsPanel -- the options window, built like Forever Unit Frames' (the
widgets in Options/Style.lua and Options/Widgets.lua are the same): a title
bar, the pages on the left with the language at the bottom, the chosen page
on the right.

Options.lua describes the pages as one list, each page starting with a
{ type = "tab" } entry:

    ns.BuildOptions({
        title = "Forever Square Minimap",
        { type = "tab", label = "TAB_MAP" },
        { type = "header", label = "OPT_MAP" },
        { label = "OPT_SIZE", min = 100, max = 400, step = 1, get = ..., set = ... },
        { type = "check", label = "OPT_PERF_SHOW", get = ..., set = ... },
        ...
    })

Labels are keys into ns.L. A plain window of the addon's own, not
Blizzard's settings panel: that one cannot be opened in combat ("Interface
action failed"). Under Interface Options -> AddOns there is only a button
that opens it.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local Style, Widgets = ns.Style, ns.Widgets

local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 780, 560
local TITLE_H, NAV_W = 32, 160
local NAV_ROW_H, NAV_TOP, NAV_BAR_W = 28, 8, 3
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local BUTTON_H, BUTTON_W, BUTTON_GAP = 24, 140, 8
local WINDOW_NAME = "ForeverSquareMinimapOptions"

local spec            -- the pages, from Options.lua
local pageSpecs = {}  -- { label, rows } per page
local frame, current
local pages = {}
local hideListeners = {}

-- A label: a locale key or a function.
local function labelText(label)
    if type(label) == "function" then return label() end
    return L[label]
end

-- Rows ------------------------------------------------------------------------------

-- Stacks rows top to bottom; a header after other rows gets a gap.
local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + (height or row:GetHeight())
    end
    return stack
end

-- Several buttons side by side.
local function buttonsRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local x = INSET
    row.buttons = {}
    for _, b in ipairs(opt.buttons) do
        local button = Widgets.Button(row, { text = labelText(b.label), width = b.width or BUTTON_W,
            onClick = b.onClick })
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + (b.width or BUTTON_W) + BUTTON_GAP
        row.buttons[#row.buttons + 1] = button
    end
    function row:Refresh() end
    function row:SetEnabled(on) for _, button in ipairs(row.buttons) do button:SetEnabled(on) end end
    return row, BUTTON_H + 12
end

-- The widget for one spec row, and its height (nil: the widget's own).
local function widgetFor(page, opt)
    local kind = opt.type or "slider"
    if kind == "header" then
        local row = Widgets.Header(page, labelText(opt.label))
        row.isSection = true
        return row
    elseif kind == "buttons" then
        return buttonsRow(page, opt)
    end
    local o = { label = labelText(opt.label), get = opt.get, set = opt.set }
    if kind == "check" then return Widgets.Checkbox(page, o) end
    if kind == "select" then
        o.items = function()
            local c = opt.choices
            if type(c) == "function" then c = c() end
            local items = {}
            for _, choice in ipairs(c or {}) do
                items[#items + 1] = { value = choice.value, text = choice.label, font = choice.font }
            end
            return items
        end
        return Widgets.Dropdown(page, o)
    end
    if kind == "color" then return Widgets.Color(page, o) end
    o.min, o.max, o.step = opt.min, opt.max, opt.step or 1
    return Widgets.Slider(page, o)
end

-- The pages from the flat list: a "tab" entry starts the next one.
local function splitPages()
    pageSpecs = {}
    local page
    for _, opt in ipairs(spec) do
        if opt.type == "tab" then
            page = { label = opt.label, rows = {} }
            pageSpecs[#pageSpecs + 1] = page
        elseif page then
            page.rows[#page.rows + 1] = opt
        end
    end
end

-- The window ------------------------------------------------------------------------

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function pageFor(i)
    if pages[i] then return pages[i] end
    local ps = pageSpecs[i]
    if not ps then return nil end
    local page = CreateFrame("Frame", "ForeverSquareMinimapPage" .. i, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    local stack = newStack(page)
    for _, opt in ipairs(ps.rows) do
        local row, height = widgetFor(page, opt)
        stack.add(row, height)
    end
    page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
    page:SetHeight(page.height)
    page:Hide()
    pages[i] = page
    return page
end

-- Scrolling: a thin accent thumb.
local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3,
        -(view - thumbH) * (scroll:GetVerticalScroll() or 0) / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = (scroll:GetVerticalScroll() or 0) - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", "ForeverSquareMinimapOptionsScroll", body)
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    local thumb = body:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(unpack(Style.COLORS.accent))
    thumb:SetWidth(2)
    thumb:Hide()
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

local function paintNav()
    for i, b in ipairs(frame.navButtons) do
        local selected = i == current
        Style.Paint(b.text, selected and "accent" or "text")
        b.bar:SetShown(selected)
    end
end

local function navButton(nav, i, y)
    local b = CreateFrame("Button", "ForeverSquareMinimapNav" .. i, nav)
    b:SetHeight(NAV_ROW_H)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.bar = line(b, "accent")
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(NAV_BAR_W)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", INSET, 0)
    b.text:SetText(labelText(pageSpecs[i].label))
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b:SetScript("OnClick", function() Window.ShowPage(i) end)
    frame.navButtons[i] = b
end

-- The language, at the bottom of the navigation; the list opens upwards.
local LANGUAGE_BUTTON_H, LANGUAGE_LABEL_H, LANGUAGE_BOTTOM = 22, 18, 10

local function languageRow(nav)
    local row = Widgets.Dropdown(nav, {
        label = L.OPT_LANGUAGE,
        items = function()
            local list = { { value = "AUTO", text = L.LANGUAGE_AUTO } }
            for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = { value = c.value, text = c.label } end
            return list
        end,
        get = function() return ns.Locale.Setting() end,
        set = function(v) ns.Locale.Set(v) end,
        listAbove = true,
    })
    row:SetHeight(LANGUAGE_LABEL_H + LANGUAGE_BUTTON_H)
    row:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", INSET, LANGUAGE_BOTTOM)
    row:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -INSET, LANGUAGE_BOTTOM)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    Style.Paint(row.label, "muted")
    row.button:ClearAllPoints()
    row.button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.button:SetHeight(LANGUAGE_BUTTON_H)
    row:Refresh()
    frame.languageRow = row
end

local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

-- The × glyph is not in every game font, so it is drawn from two lines.
local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.ADDON_NAME)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. ((getMetadata and getMetadata(ADDON, "Version")) or ""))
    bar.close = closeButton(bar)
    return bar
end

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    local nav = CreateFrame("Frame", nil, frame)
    nav:SetWidth(NAV_W)
    Style.Fill(nav, "panel")
    local edge = line(nav, "border")
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    nav:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.navButtons = {}
    for i in ipairs(pageSpecs) do navButton(nav, i, NAV_TOP + (i - 1) * NAV_ROW_H) end
    languageRow(nav)
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", NAV_W, 0)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    createScroll(body)
    -- Hiding the window (ESC, the cross) closes an open list and tells the
    -- listeners (the mail test view ends).
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        for _, fn in ipairs(hideListeners) do pcall(fn) end
    end)
    frame:SetScript("OnShow", function() Window.Refresh() end)
    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == WINDOW_NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, WINDOW_NAME) end
    end
end

-- Public API ------------------------------------------------------------------------

-- Options.lua hands the pages over at login.
function ns.BuildOptions(s)
    spec = s
    splitPages()
end

function Window.PageCount() return #pageSpecs end

function Window.ShowPage(i)
    if not spec then return end
    if not frame then createWindow() end
    local page = pageFor(i)
    if not page then return end
    Widgets.CloseList()
    for _, p in pairs(pages) do if p ~= page then p:Hide() end end
    current = i
    frame.scrollChild:SetHeight(page.height)
    frame.scroll:SetVerticalScroll(0)
    page:Show()
    for _, row in ipairs(page.rows) do row:Refresh() end
    paintNav()
    updateScrollbar()
end

-- Fetches every value on the visible page again.
function Window.Refresh()
    if not frame or not current or not pages[current] then return end
    for _, row in ipairs(pages[current].rows) do row:Refresh() end
    if frame.languageRow then frame.languageRow:Refresh() end
end
ns.RefreshOptions = Window.Refresh

function Window.Open(i)
    if not spec then return end
    if not frame then createWindow() end
    frame:Show()
    Window.ShowPage(i or current or 1)
end

function Window.IsShown() return frame ~= nil and frame:IsShown() end

function Window.Toggle()
    if Window.IsShown() then frame:Hide() else Window.Open() end
end

function Window.OnHide(fn) hideListeners[#hideListeners + 1] = fn end

-- Every label is set when its widget is built: a new language gets a new
-- window. Frames cannot be destroyed, so the old one stays hidden and
-- unreferenced; the new one takes over its global name and page.
ns.Locale.OnChange(function()
    if not frame then return end
    local wasOpen, page = frame:IsShown(), current
    frame:Hide()
    frame, pages = nil, {}
    if wasOpen then Window.Open(page) end
end)

-- The page under Interface Options -> AddOns: the name and a button that
-- opens the window.
local function Register(panel)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name, panel.name)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            return category
        end
    end
    if InterfaceOptions_AddCategory then pcall(InterfaceOptions_AddCategory, panel) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    local panel = CreateFrame("Frame", "ForeverSquareMinimapInterfacePanel", UIParent)
    panel.name = L.ADDON_NAME
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.ADDON_NAME)
    local button = CreateFrame("Button", "ForeverSquareMinimapInterfaceOpen", panel, "UIPanelButtonTemplate")
    button:SetSize(220, 24)
    button:SetPoint("TOPLEFT", 16, -52)
    button:SetScript("OnClick", function()
        if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame.Hide then InterfaceOptionsFrame:Hide() end
        Window.Open()
    end)
    local function relabel() button:SetText(L.OPEN_OPTIONS) end
    ns.Locale.OnChange(relabel)
    relabel()
    ns.optionsCategory = Register(panel)
    ns.optionsPanel = panel
end)
