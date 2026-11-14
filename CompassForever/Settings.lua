local _, namespace = ...

local panelName = "CompassForeverSettings"
local previewDark = { 0.055, 0.063, 0.066 }
local panelDark = { 0.102, 0.112, 0.115 }
local panelBorder = { 0.40, 0.34, 0.23 }
local textMuted = { 0.74, 0.77, 0.76 }
local gold = { 0.95, 0.77, 0.40 }

local function rectangle(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetColorTexture(color[1], color[2], color[3], 1)
    return texture
end

local function label(parent, font, value, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", x, y)
    text:SetText(value)
    return text
end

local function button(parent, caption, width, x, y, onClick)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 26)
    control:SetPoint("TOPLEFT", x, y)
    control:SetText(caption)
    control:SetScript("OnClick", onClick)
    return control
end

local function line(parent, x1, y1, x2, y2)
    local stroke = parent:CreateLine(nil, "ARTWORK")
    stroke:SetThickness(1.5)
    stroke:SetStartPoint("CENTER", parent, x1, y1)
    stroke:SetEndPoint("CENTER", parent, x2, y2)
    return stroke
end

local function makePreview(parent)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(412, 92)
    preview:SetPoint("TOPLEFT", 18, -49)
    rectangle(preview, "BACKGROUND", previewDark)
    local title = label(preview, "GameFontHighlightSmall", "Live Preview", 11, -9)
    title:SetTextColor(textMuted[1], textMuted[2], textMuted[3])

    local artwork = CreateFrame("Frame", nil, preview)
    artwork:SetAllPoints()
    local sample = { artwork = artwork, arc = {}, ticks = {}, details = {}, heading = {} }
    for index = 1, 16 do
        sample.arc[index] = line(artwork, 0, 0, 0, 0)
    end
    for index = 1, 4 do
        sample.details[index] = line(artwork, 0, 0, 0, 0)
    end
    for index = -4, 4 do
        local isMajor = index % 4 == 0
        local tick = { x = index * 22, stroke = line(artwork, 0, 0, 0, 0) }
        if isMajor then
            local heading = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            heading:SetText(index < 0 and "W" or (index == 0 and "N" or "E"))
            tick.label = heading
            sample.heading[#sample.heading + 1] = heading
        end
        sample.ticks[#sample.ticks + 1] = tick
    end
    sample.quest = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sample.quest:SetPoint("CENTER", artwork, "CENTER", -60, -27)
    sample.quest:SetText("! 240 yd")

    sample.pin = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sample.pin:SetPoint("CENTER", artwork, "CENTER", 68, -27)
    sample.pin:SetText("510 yd")
    sample.pinIcon = {
        line(artwork, 39, -27, 43, -23), line(artwork, 43, -23, 47, -27),
        line(artwork, 47, -27, 43, -31), line(artwork, 43, -31, 39, -27),
    }
    return sample
end

local function positionPreview(sample, style, api)
    local art = sample.artwork
    local function yAt(x)
        return 6 + api.styleY(style.id, x / 115) * (115 / 280)
    end
    local function place(stroke, x1, y1, x2, y2)
        stroke:SetStartPoint("CENTER", art, x1, y1)
        stroke:SetEndPoint("CENTER", art, x2, y2)
    end
    for index, stroke in ipairs(sample.arc) do
        local x1 = -115 + (index - 1) * 230 / #sample.arc
        local x2 = x1 + 230 / #sample.arc
        place(stroke, x1, yAt(x1), x2, yAt(x2))
    end
    for _, tick in ipairs(sample.ticks) do
        local x = tick.x
        local y = yAt(x)
        place(tick.stroke, x, y - 3, x, y + (tick.label and 5 or 2))
        if tick.label then
            tick.label:ClearAllPoints()
            tick.label:SetPoint("BOTTOM", art, "CENTER", x, y + 8)
        end
    end
    local details = sample.details
    for _, stroke in ipairs(details) do
        stroke:Hide()
    end
    if style.id == "bar" then
        place(details[1], -115, 12, 115, 12)
        place(details[2], -115, 0, 115, 0)
        place(details[3], -115, 0, -115, 12)
        place(details[4], 115, 0, 115, 12)
        for _, stroke in ipairs(details) do
            stroke:Show()
        end
    elseif style.id == "tactical" then
        place(details[1], -3, 10, 0, 7)
        place(details[2], 0, 7, 3, 10)
        details[1]:Show()
        details[2]:Show()
    elseif style.id == "flight" then
        place(details[1], -6, 6, 0, 11)
        place(details[2], 0, 11, 6, 6)
        place(details[3], -115, 2, -106, 2)
        place(details[4], 106, 2, 115, 2)
        for _, stroke in ipairs(details) do
            stroke:Show()
        end
    end
end

local function makePanel(api)
    local panel = CreateFrame("Frame", panelName, UIParent)
    panel:SetSize(448, 423)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:Hide()

    rectangle(panel, "BACKGROUND", panelDark)
    local rule = panel:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", 2, -40)
    rule:SetPoint("TOPRIGHT", -2, -40)
    rule:SetHeight(1)
    rule:SetColorTexture(panelBorder[1], panelBorder[2], panelBorder[3], 1)

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -42, 0)
    drag:SetHeight(40)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    local dragging
    drag:SetScript("OnDragStart", function()
        panel:StartMoving()
        panel:SetUserPlaced(false)
        dragging = true
    end)
    local function stopMoving()
        if dragging then
            panel:StopMovingOrSizing()
            panel:SetUserPlaced(false)
            dragging = nil
        end
    end
    drag:SetScript("OnDragStop", stopMoving)
    panel:SetScript("OnHide", stopMoving)
    label(drag, "GameFontNormalLarge", "CompassForever", 18, -12)
    panel.dragHandle = drag

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -3)
    close:SetScript("OnClick", function() panel:Hide() end)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, panelName)
    end

    local controls = { close = close, themes = {}, themeMarks = {}, styles = {}, styleMarks = {} }
    panel.controls = controls
    panel.preview = makePreview(panel)

    label(panel, "GameFontNormal", "HUD Theme", 18, -152)
    for index, theme in ipairs(api.themes) do
        local themeId = theme.id
        local choice = button(panel, theme.name, 99, 18 + (index - 1) * 104, -173, function()
            api.set("theme", themeId)
        end)
        controls.themes[themeId] = choice
        local mark = choice:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("BOTTOMLEFT", 6, 3)
        mark:SetPoint("BOTTOMRIGHT", -6, 3)
        mark:SetHeight(2)
        mark:SetColorTexture(theme.arc[1], theme.arc[2], theme.arc[3], 1)
        controls.themeMarks[themeId] = mark
    end

    label(panel, "GameFontNormal", "HUD Style", 18, -209)
    for index, style in ipairs(api.styles) do
        local styleId = style.id
        local choice = button(panel, style.name, 99, 18 + (index - 1) * 104, -230, function()
            api.set("style", styleId)
        end)
        controls.styles[styleId] = choice
        local mark = choice:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("BOTTOMLEFT", 6, 3)
        mark:SetPoint("BOTTOMRIGHT", -6, 3)
        mark:SetHeight(2)
        mark:SetColorTexture(gold[1], gold[2], gold[3], 1)
        controls.styleMarks[styleId] = mark
    end

    local toggles = {
        { "enabled", "Show HUD", 17, -264 },
        { "showMinimap", "Show Minimap Button", 224, -264 },
        { "showQuests", "Show Quest Distances", 17, -291 },
        { "showWaypoint", "Show Map Pin", 224, -291 },
        { "showCardinals", "Show Cardinal Letters", 17, -318 },
    }
    for _, entry in ipairs(toggles) do
        local key, caption, x, y = unpack(entry)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", x, y)
        check:SetHitRectInsets(0, -156, 0, 0)
        local captionText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        captionText:SetPoint("LEFT", check, "RIGHT", 5, 0)
        captionText:SetText(caption)
        check:SetScript("OnClick", function(self)
            api.set(key, self:GetChecked() and true or false)
        end)
        controls[key] = check
    end

    label(panel, "GameFontNormal", "HUD Opacity", 18, -354)
    controls.opacityDown = button(panel, "-", 28, 18, -374, function()
        api.set("opacity", math.max(0.35, api.get().opacity - 0.05))
    end)
    local opacity = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    opacity:SetPoint("CENTER", controls.opacityDown, "RIGHT", 27, 0)
    controls.opacityUp = button(panel, "+", 28, 101, -374, function()
        api.set("opacity", math.min(1, api.get().opacity + 0.05))
    end)
    controls.opacityValue = opacity

    controls.test = button(panel, "Test Overflow", 151, 137, -374, function()
        if api.testActive() then
            api.test(nil)
        else
            api.test(64)
        end
    end)
    controls.move = button(panel, "Move HUD", 134, 296, -346, function()
        panel:Hide()
        api.move()
    end)
    controls.resetPosition = button(panel, "Reset HUD Position", 134, 296, -374, function()
        api.resetPosition()
    end)
    return panel
end

local function refreshPanel(panel, api)
    local options, controls, preview = api.get(), panel.controls, panel.preview
    local theme = api.themes[1]
    for _, choice in ipairs(api.themes) do
        local selected = choice.id == options.theme
        controls.themeMarks[choice.id]:SetShown(selected)
        if selected then
            theme = choice
        end
    end
    local style = api.styles[1]
    for _, choice in ipairs(api.styles) do
        local selected = choice.id == options.style
        controls.styleMarks[choice.id]:SetShown(selected)
        if selected then
            style = choice
        end
    end
    if preview.style ~= style then
        positionPreview(preview, style, api)
        preview.style = style
    end
    controls.enabled:SetChecked(options.enabled)
    controls.showMinimap:SetChecked(options.showMinimap)
    controls.showQuests:SetChecked(options.showQuests)
    controls.showWaypoint:SetChecked(options.showWaypoint)
    controls.showCardinals:SetChecked(options.showCardinals)
    controls.opacityValue:SetText(("%d%%"):format(math.floor(options.opacity * 100 + 0.5)))
    controls.test:SetText(api.testActive() and "Stop Overflow Test" or "Test Overflow")

    preview.artwork:SetAlpha(options.opacity)
    for _, stroke in ipairs(preview.arc) do
        stroke:SetColorTexture(theme.arc[1], theme.arc[2], theme.arc[3], 1)
    end
    for _, stroke in ipairs(preview.details) do
        stroke:SetColorTexture(theme.arc[1], theme.arc[2], theme.arc[3], 0.55)
    end
    for _, tick in ipairs(preview.ticks) do
        tick.stroke:SetColorTexture(theme.arc[1], theme.arc[2], theme.arc[3], 1)
        if tick.label then
            tick.label:SetShown(options.showCardinals)
            tick.label:SetTextColor(theme.arc[1], theme.arc[2], theme.arc[3])
        end
    end
    preview.quest:SetShown(options.showQuests)
    preview.quest:SetTextColor(theme.quest[1], theme.quest[2], theme.quest[3])
    preview.pin:SetShown(options.showWaypoint)
    preview.pin:SetTextColor(theme.pin[1], theme.pin[2], theme.pin[3])
    for _, stroke in ipairs(preview.pinIcon) do
        stroke:SetShown(options.showWaypoint)
        stroke:SetColorTexture(theme.pin[1], theme.pin[2], theme.pin[3], 1)
    end
end

function namespace.CreateSettingsUI(api)
    local ui = {}
    local panel, minimapButton, ornament

    function ui:Refresh()
        if minimapButton then
            local options = api.get()
            minimapButton:SetShown(options.showMinimap)
            ornament:SetAlpha(options.enabled and 1 or 0.55)
        end
        if panel then
            refreshPanel(panel, api)
        end
    end

    function ui:Toggle()
        if not panel then
            panel = makePanel(api)
        end
        if panel:IsShown() then
            panel:Hide()
        else
            self:Refresh()
            panel:Show()
        end
    end

    local function attachMinimapButton()
        if minimapButton or not Minimap then
            return
        end
        minimapButton = CreateFrame("Button", "CompassForeverMinimapButton", Minimap)
        minimapButton:SetSize(31, 31)
        minimapButton:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 6, 6)
        minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        minimapButton:SetHighlightTexture(136477)
        local background = minimapButton:CreateTexture(nil, "BACKGROUND")
        background:SetSize(24, 24)
        background:SetPoint("CENTER")
        background:SetTexture(136467)
        local ring = minimapButton:CreateTexture(nil, "OVERLAY")
        ring:SetSize(50, 50)
        ring:SetPoint("TOPLEFT")
        ring:SetTexture(136430)
        ornament = CreateFrame("Frame", nil, minimapButton)
        ornament:SetAllPoints()
        local north = ornament:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        north:SetPoint("CENTER", 0, 5)
        north:SetText("N")
        north:SetTextColor(gold[1], gold[2], gold[3])
        local needle = { line(ornament, -4, -2, 0, -8), line(ornament, 0, -8, 4, -2) }
        for _, stroke in ipairs(needle) do
            stroke:SetColorTexture(gold[1], gold[2], gold[3], 1)
        end
        minimapButton:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then
                ui:Toggle()
            else
                api.set("enabled", not api.get().enabled)
            end
        end)
        minimapButton:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("CompassForever")
                GameTooltip:AddLine("Left-click to show or hide the HUD", 1, 1, 1)
                GameTooltip:AddLine("Right-click to open settings", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        local function hideTooltip()
            if GameTooltip and GameTooltip:IsOwned(minimapButton) then
                GameTooltip:Hide()
            end
        end
        minimapButton:SetScript("OnLeave", hideTooltip)
        minimapButton:SetScript("OnHide", hideTooltip)
        ui:Refresh()
    end

    attachMinimapButton()
    if not minimapButton then
        local login = CreateFrame("Frame")
        login:RegisterEvent("PLAYER_LOGIN")
        login:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_LOGIN")
            attachMinimapButton()
        end)
    end
    return ui
end
