--[[---------------------------------------------------------------------------
OptionsPanel -- builds the page under Interface Options -> AddOns from a
description instead of hand built frames:

    ns.BuildOptions({
        title = "Forever Square Minimap",
        { type = "header", label = "OPT_MAP" },
        { type = "slider", label = "OPT_SIZE", min = 100, max = 400, step = 1,
          unit = "px", get = ..., set = ... },
        { type = "check",  label = "OPT_PERF_SHOW", get = ..., set = ... },
    })

Labels are keys into ns.L. The page keeps every text it has set, and
ns.RelabelOptions() sets them again in the current language, so a language
change applies at once.

Every slider also gets a text field: drag for rough values, type for exact
ones. Both keep each other up to date.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L

local floor, max, min = math.floor, math.max, math.min

local ROW = { slider = 58, check = 32, header = 34, select = 46, buttons = 34, color = 32 }

-- Every text on the page, as a function that sets it again.
local relabelers = {}
local function labelled(fn)
    relabelers[#relabelers + 1] = fn
    fn()
end

-- Resolves a label: a key into ns.L or a function returning the text.
local function text(label)
    if type(label) == "function" then return label() end
    return L[label]
end

-- --------------------------------------------------------------------------
-- Registration: the Settings API where it exists, the old one otherwise
-- --------------------------------------------------------------------------
local function Register(panel)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name, panel.name)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            return category
        end
    end
    if InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end
end

-- --------------------------------------------------------------------------
-- Rows
-- --------------------------------------------------------------------------
local function Format(opt, value)
    if opt.decimals and opt.decimals > 0 then
        return ("%." .. opt.decimals .. "f"):format(value)
    end
    return tostring(floor(value + 0.5))
end

local function AddSlider(panel, opt, y, index, panelName)
    local name = panelName .. "Slider" .. index
    local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 24, y)
    slider:SetWidth(260)
    slider:SetHeight(18)
    slider:SetMinMaxValues(opt.min, opt.max)
    slider:SetValueStep(opt.step or 1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

    if _G[name .. "Text"] then
        labelled(function() _G[name .. "Text"]:SetText(text(opt.label)) end)
    end
    if _G[name .. "Low"]  then _G[name .. "Low"]:SetText(Format(opt, opt.min)) end
    if _G[name .. "High"] then _G[name .. "High"]:SetText(Format(opt, opt.max)) end

    local box = CreateFrame("EditBox", name .. "Box", panel, "InputBoxTemplate")
    box:SetSize(58, 20)
    box:SetPoint("LEFT", slider, "RIGHT", 22, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")

    if opt.unit then
        local unit = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        unit:SetPoint("LEFT", box, "RIGHT", 4, 0)
        unit:SetText(opt.unit)
    end

    -- Updates both without one triggering the other.
    local syncing = false
    local function Show(value)
        syncing = true
        slider:SetValue(value)
        box:SetText(Format(opt, value))
        box:SetCursorPosition(0)
        syncing = false
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if syncing then return end
        if not opt.decimals or opt.decimals == 0 then value = floor(value + 0.5) end
        opt.set(value)
        Show(value)
    end)

    local function Commit()
        -- A comma counts as the decimal separator too.
        local typed = (box:GetText() or ""):gsub(",", ".")
        local value = tonumber(typed)
        if not value then Show(opt.get()) return end
        value = max(opt.min, min(opt.max, value))
        if not opt.decimals or opt.decimals == 0 then value = floor(value + 0.5) end
        opt.set(value)
        Show(value)
        box:ClearFocus()
    end

    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function()
        Show(opt.get())
        box:ClearFocus()
    end)

    return function() Show(opt.get()) end
end

local function AddCheck(panel, opt, y, index, panelName)
    local name = panelName .. "Check" .. index
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", 22, y)

    -- Depending on the template the label is _G[name.."Text"] or check.Text.
    local label = _G[name .. "Text"]
    if not label and type(check.Text) == "table" then label = check.Text end
    if label and label.SetText then
        labelled(function() label:SetText(text(opt.label)) end)
    end

    check:SetScript("OnClick", function(self)
        opt.set(self:GetChecked() and true or false)
    end)

    return function() check:SetChecked(opt.get() and true or false) end
end

-- Several buttons side by side.
local function AddButtons(panel, opt, y, index, panelName)
    local base = panelName .. "Button" .. index
    local x = 24
    for i, b in ipairs(opt.buttons or {}) do
        local btn = CreateFrame("Button", base .. "_" .. i, panel, "UIPanelButtonTemplate")
        btn:SetSize(b.width or 110, 22)
        btn:SetPoint("TOPLEFT", x, y)
        labelled(function() btn:SetText(text(b.label)) end)
        btn:SetScript("OnClick", function() if b.onClick then b.onClick() end end)
        x = x + (b.width or 110) + 8
    end
    return nil
end

-- A dropdown. Each helper is checked on its own: if one is missing, a button
-- that cycles through the choices takes its place.
local function AddSelect(panel, opt, y, index, panelName)
    local name = panelName .. "Select" .. index

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 24, y)
    labelled(function() label:SetText(text(opt.label)) end)

    -- choices may be a table or a function; a function is needed when the
    -- list changes at runtime (profiles created or deleted).
    local function Choices()
        local c = opt.choices
        if type(c) == "function" then return c() or {} end
        return c or {}
    end

    local function LabelFor(value)
        for _, c in ipairs(Choices()) do
            if c.value == value then return c.label end
        end
        return tostring(value)
    end

    local haveDropdown = UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo
                         and UIDropDownMenu_AddButton and UIDropDownMenu_SetText

    if haveDropdown then
        local dd = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", 8, y - 16)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, 200) end

        UIDropDownMenu_Initialize(dd, function(_, level)
            for _, choice in ipairs(Choices()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = choice.label
                info.checked = (choice.value == opt.get())
                info.func = function()
                    opt.set(choice.value)
                    UIDropDownMenu_SetText(dd, LabelFor(choice.value))
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        local function refresh() UIDropDownMenu_SetText(dd, LabelFor(opt.get())) end
        labelled(refresh)
        return refresh
    end

    local button = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
    button:SetSize(210, 22)
    button:SetPoint("TOPLEFT", 24, y - 18)
    button:SetScript("OnClick", function(self)
        -- Fetch the list on every click: it may have changed meanwhile.
        local list = Choices()
        if #list == 0 then return end
        local current, nextValue = opt.get(), nil
        for i, c in ipairs(list) do
            if c.value == current then
                nextValue = list[(i % #list) + 1].value
                break
            end
        end
        nextValue = nextValue or list[1].value
        opt.set(nextValue)
        self:SetText(LabelFor(nextValue))
    end)
    local function refresh() button:SetText(LabelFor(opt.get())) end
    labelled(refresh)
    return refresh
end

-- A colour swatch; a click opens Blizzard's colour picker with opacity.
-- Newer clients open it through SetupColorPickerAndShow, older ones through
-- fields on the frame.
local function OpenPicker(opt, refresh)
    if not ColorPickerFrame then return end
    local c = opt.get()
    local previous = { c[1], c[2], c[3], c[4] or 1 }
    local function picked()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a
        if ColorPickerFrame.GetColorAlpha then
            a = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then
            a = 1 - OpacitySliderFrame:GetValue()
        end
        opt.set({ r, g, b, a or previous[4] })
        refresh()
    end
    local function cancel()
        opt.set(previous)
        refresh()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous[1], g = previous[2], b = previous[3], opacity = previous[4],
            hasOpacity = true, swatchFunc = picked, opacityFunc = picked, cancelFunc = cancel,
        })
        return
    end
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - previous[4]
    ColorPickerFrame.previousValues = previous
    ColorPickerFrame.func, ColorPickerFrame.opacityFunc = picked, picked
    ColorPickerFrame.cancelFunc = cancel
    ColorPickerFrame:SetColorRGB(previous[1], previous[2], previous[3])
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

local function AddColor(panel, opt, y, index, panelName)
    local swatch = CreateFrame("Button", panelName .. "Color" .. index, panel)
    swatch:SetSize(22, 22)
    swatch:SetPoint("TOPLEFT", 26, y)

    local edge = swatch:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints(true)
    edge:SetColorTexture(0.8, 0.8, 0.8, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(1, 1, 1, 1)

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    labelled(function() label:SetText(text(opt.label)) end)

    local function refresh()
        local c = opt.get()
        fill:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    end
    swatch:SetScript("OnClick", function() OpenPicker(opt, refresh) end)
    return refresh
end

local function AddHeader(panel, opt, y)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 18, y)
    labelled(function() header:SetText(text(opt.label)) end)
    return nil
end

-- Sets every text on the page again, in the current language.
function ns.RelabelOptions()
    for _, fn in ipairs(relabelers) do pcall(fn) end
end

-- --------------------------------------------------------------------------
-- Building the page
-- --------------------------------------------------------------------------
function ns.BuildOptions(spec)
    local panelName = "ForeverSquareMinimapOptionsPanel"
    local panel = CreateFrame("Frame", panelName, UIParent)
    panel.name = spec.title

    -- The head stays, the rest scrolls.
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(spec.title)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -38)
    labelled(function() hint:SetText(L.OPT_HINT) end)

    -- Blizzard's option pages do not scroll by themselves.
    local scroll = CreateFrame("ScrollFrame", panelName .. "Scroll", panel,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -56)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)

    local content = CreateFrame("Frame", panelName .. "Content", scroll)
    content:SetSize(560, 10)
    scroll:SetScrollChild(content)

    -- The template brings a scroll bar, but not always the mouse wheel.
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self.GetVerticalScroll and self:GetVerticalScroll() or 0
        local maxScroll = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
        local target = current - delta * 40
        if target < 0 then target = 0 end
        if maxScroll and target > maxScroll then target = maxScroll end
        if self.SetVerticalScroll then self:SetVerticalScroll(target) end
    end)

    local refreshers = {}
    local y = -8

    for index, opt in ipairs(spec) do
        local kind = opt.type or "slider"
        local refresh
        if kind == "slider" then
            refresh = AddSlider(content, opt, y, index, panelName)
        elseif kind == "check" then
            refresh = AddCheck(content, opt, y, index, panelName)
        elseif kind == "select" then
            refresh = AddSelect(content, opt, y, index, panelName)
        elseif kind == "buttons" then
            refresh = AddButtons(content, opt, y, index, panelName)
        elseif kind == "color" then
            refresh = AddColor(content, opt, y, index, panelName)
        elseif kind == "header" then
            refresh = AddHeader(content, opt, y)
        end
        if refresh then refreshers[#refreshers + 1] = refresh end
        y = y - (ROW[kind] or ROW.slider)
    end

    -- The scroll frame needs the content's height to know how far it scrolls.
    content:SetHeight(math.max(10, -y + 16))

    local function RefreshAll()
        local w = scroll.GetWidth and scroll:GetWidth()
        if w and w > 0 then content:SetWidth(w) end
        for _, fn in ipairs(refreshers) do pcall(fn) end
    end

    -- Fetch the current values on opening: a slash command or dragging the
    -- grip may have changed them.
    panel:SetScript("OnShow", RefreshAll)
    panel.refresh = RefreshAll        -- old API
    panel.OnRefresh = RefreshAll      -- new API

    ns.optionsCategory = Register(panel)
    RefreshAll()
    ns.optionsPanel = panel
    ns.optionsContent = content
    return panel
end
