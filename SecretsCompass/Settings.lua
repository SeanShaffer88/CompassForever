local addonName, namespace = ...

local panelName = "SecretsCompassSettings"
local previewDark = { 0.063, 0.055, 0.047 }
local panelDark = { 0.094, 0.078, 0.059 }
local panelBorder = { 0.35, 0.29, 0.20 }
local textMuted = { 0.74, 0.69, 0.61 }
local previewHalfWidth = 115
local previewBaseline = 6
local previewScale = previewHalfWidth / 280
local iconPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\MinimapCompass.tga"

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
    preview:SetSize(412, 98)
    preview:SetPoint("TOPLEFT", 18, -49)
    rectangle(preview, "BACKGROUND", previewDark)
    local title = label(preview, "GameFontHighlightSmall", "Live Preview", 11, -9)
    title:SetTextColor(textMuted[1], textMuted[2], textMuted[3])

    local artwork = CreateFrame("Frame", nil, preview)
    artwork:SetSize(1, 1)
    artwork:SetPoint("CENTER")
    local sample = { artwork = artwork, arc = {}, ticks = {}, details = {}, heading = {} }
    for index = 1, 40 do
        sample.arc[index] = line(artwork, 0, 0, 0, 0)
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
    sample.secret = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sample.secret:SetPoint("LEFT", artwork, "CENTER", -29, -27)
    sample.secret:SetText("Secret 240 yd")
    sample.secretIcon = {
        line(artwork, -44, -27, -40, -23), line(artwork, -40, -23, -36, -27),
        line(artwork, -36, -27, -40, -31), line(artwork, -40, -31, -44, -27),
    }
    return sample
end

local function positionPreview(sample, style, api)
    local art = sample.artwork
    local r, g, b = unpack(style.arc)
    local function yAt(x)
        return previewBaseline + api.styleY(style.id, x / previewHalfWidth) * previewScale
    end
    local function place(stroke, x1, y1, x2, y2)
        stroke:SetStartPoint("CENTER", art, x1, y1)
        stroke:SetEndPoint("CENTER", art, x2, y2)
    end
    for index, stroke in ipairs(sample.arc) do
        local x1 = -previewHalfWidth + (index - 1) * 2 * previewHalfWidth / #sample.arc
        local x2 = x1 + 2 * previewHalfWidth / #sample.arc
        place(stroke, x1, yAt(x1), x2, yAt(x2))
        stroke:SetThickness(math.max(1, style.width * previewScale))
        stroke:SetColorTexture(r, g, b, 1)
        stroke:SetShown(api.styleSegmentShown(style.id, index, #sample.arc))
    end
    for _, tick in ipairs(sample.ticks) do
        local x = tick.x
        local y = yAt(x)
        local length = (tick.label and 9 or 5) * previewScale
        if style.tickBelow then
            place(tick.stroke, x, y - length * 2, x, y)
        else
            place(tick.stroke, x, y - length, x, y + length)
        end
        tick.stroke:SetShown(tick.label ~= nil or style.minorTicks ~= false)
        tick.stroke:SetThickness(math.max(1, (style.tickWidth or (tick.label and 2 or 1.2)) * previewScale))
        tick.stroke:SetColorTexture(r, g, b, tick.label and 1 or 0.75)
        if tick.label then
            tick.label:ClearAllPoints()
            tick.label:SetPoint("BOTTOM", art, "CENTER", x, y + (style.labelInset or 12) * previewScale)
            tick.label:SetTextColor(r, g, b)
        end
    end
    local details = sample.details
    local detailSegments = style.details or {}
    for index, segment in ipairs(detailSegments) do
        local stroke = details[index]
        if not stroke then
            stroke = line(art, 0, 0, 0, 0)
            details[index] = stroke
        end
        local x1, y1, x2, y2, width, alpha = unpack(segment)
        place(stroke, x1 * previewScale, previewBaseline + y1 * previewScale,
            x2 * previewScale, previewBaseline + y2 * previewScale)
        stroke:SetThickness(math.max(1, (width or 1) * previewScale))
        stroke:SetColorTexture(r, g, b, alpha or 0.45)
        stroke:Show()
    end
    for index = #detailSegments + 1, #details do
        details[index]:Hide()
    end
end

local function makePanel(api)
    local panel = CreateFrame("Frame", panelName, UIParent)
    panel:SetSize(448, 428)
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
    label(drag, "GameFontNormalLarge", "SecretsCompass", 18, -12)
    panel.dragHandle = drag

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -3)
    close:SetScript("OnClick", function() panel:Hide() end)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, panelName)
    end

    local controls = { close = close, styles = {}, styleMarks = {} }
    panel.controls = controls
    panel.preview = makePreview(panel)

    label(panel, "GameFontNormal", "HUD Style", 18, -152)
    for index, style in ipairs(api.styles) do
        local styleId = style.id
        local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
        local choice = button(panel, style.name, 99, 18 + column * 104, -173 - row * 28, function()
            api.set("style", styleId)
        end)
        controls.styles[styleId] = choice
        local mark = choice:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("BOTTOMLEFT", 6, 3)
        mark:SetPoint("BOTTOMRIGHT", -6, 3)
        mark:SetHeight(2)
        mark:SetColorTexture(style.arc[1], style.arc[2], style.arc[3], 1)
        controls.styleMarks[styleId] = mark
    end

    local toggles = {
        { "enabled", "Show Secret HUD", 17, -264 },
        { "showMinimap", "Show Minimap Button", 224, -264 },
        { "showCardinals", "Show Cardinal Letters", 17, -291 },
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

    if api.openSecrets then
        controls.secrets = button(panel, "Secrets", 134, 296, -290, function()
            panel:Hide()
            api.openSecrets()
        end)
    end

    label(panel, "GameFontNormal", "HUD Transparency", 18, -326)
    controls.transparencyDown = button(panel, "-", 28, 18, -346, function()
        api.set("opacity", math.min(1, api.get().opacity + 0.05))
    end)
    local transparency = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    transparency:SetPoint("CENTER", controls.transparencyDown, "RIGHT", 27, 0)
    controls.transparencyUp = button(panel, "+", 28, 101, -346, function()
        api.set("opacity", math.max(0, api.get().opacity - 0.05))
    end)
    controls.transparencyValue = transparency

    controls.move = button(panel, "Move HUD", 134, 296, -318, function()
        panel:Hide()
        api.move()
    end)
    controls.resetPosition = button(panel, "Reset HUD Position", 134, 296, -346, function()
        api.resetPosition()
    end)

    label(panel, "GameFontNormal", "HUD Size", 18, -378)
    controls.sizeValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    controls.sizeValue:SetPoint("TOPRIGHT", -18, -378)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetPoint("TOPLEFT", 18, -399)
    slider:SetSize(412, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetMinMaxValues(api.minScale, api.maxScale)
    slider:SetValueStep(api.scaleStep)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(24, 24)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 6, 0)
    track:SetPoint("RIGHT", -6, 0)
    track:SetHeight(4)
    track:SetColorTexture(panelBorder[1], panelBorder[2], panelBorder[3], 1)
    slider:SetScript("OnValueChanged", function(_, percent)
        api.set("scale", percent / 100)
    end)
    controls.size = slider
    return panel
end

local function refreshPanel(panel, api)
    local options, controls, preview = api.get(), panel.controls, panel.preview
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
    controls.showCardinals:SetChecked(options.showCardinals)
    local transparency = math.floor((1 - options.opacity) * 100 + 0.5)
    controls.transparencyValue:SetText(("%d%%"):format(transparency))

    local percent = math.floor(options.scale * 100 + 0.5)
    controls.sizeValue:SetText(("%d%%"):format(percent))
    if controls.size:GetValue() ~= percent then
        controls.size:SetValue(percent)
    end
    preview.artwork:SetScale(options.scale)
    preview.artwork:SetAlpha(options.opacity)
    for _, heading in ipairs(preview.heading) do
        heading:SetShown(options.showCardinals)
    end
    preview.secret:SetTextColor(unpack(style.arc))
    for _, stroke in ipairs(preview.secretIcon) do
        stroke:SetColorTexture(style.secret[1], style.secret[2], style.secret[3], 1)
    end
end

local function addMinimapTooltip(tooltip)
    tooltip:SetText("SecretsCompass")
    tooltip:AddLine("Left-click to open Secrets", 1, 1, 1)
    tooltip:AddLine("Right-click to open settings", 1, 1, 1)
end

local function createMinimapButton(position, onClick, finite)
    local button = CreateFrame("Button", "SecretsCompassMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER")
    icon:SetTexture(iconPath)
    button.icon = icon

    local lastX, lastY
    local function place()
        local angle = math.rad(position.minimapPos)
        local x, y = math.cos(angle), math.sin(angle)
        if GetMinimapShape and GetMinimapShape() == "SQUARE" then
            local edge = math.max(math.abs(x), math.abs(y))
            x, y = x / edge, y / edge
        end
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x * Minimap:GetWidth() / 2, y * Minimap:GetHeight() / 2)
        local _, _, _, actualX, actualY = button:GetPoint(1)
        lastX, lastY = actualX, actualY
    end

    local function ownsAnchor()
        if button:GetParent() ~= Minimap or button:GetNumPoints() ~= 1 then
            return false
        end
        local anchor, relative, relativeAnchor, x, y = button:GetPoint(1)
        return anchor == "CENTER" and relative == Minimap and relativeAnchor == "CENTER" and x == lastX and y == lastY
    end

    local dragging, suppressClick
    local function hideTooltip()
        if GameTooltip and GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end
    local function stopDrag()
        if dragging then
            dragging = false
            button:SetScript("OnUpdate", nil)
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0, function()
                    if not dragging then
                        suppressClick = false
                    end
                end)
            end
        end
    end
    local function updateDrag()
        if not ownsAnchor() then
            stopDrag()
            return
        end
        local centerX, centerY = Minimap:GetCenter()
        local x, y = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        if finite(x) and finite(y) and finite(centerX) and finite(centerY) and finite(scale) and scale > 0 then
            x, y = x / scale - centerX, y / scale - centerY
            if x ~= 0 or y ~= 0 then
                position.minimapPos = math.deg(math.atan2(y, x)) % 360
                place()
            end
        end
    end

    place()
    button:SetShown(not position.hide)
    button:SetScript("OnMouseDown", function() suppressClick = false end)
    button:SetScript("OnClick", function(self, mouseButton)
        if not dragging and not suppressClick then
            onClick(self, mouseButton)
        end
    end)
    button:SetScript("OnDragStart", function()
        if ownsAnchor() then
            dragging, suppressClick = true, true
            hideTooltip()
            button:SetScript("OnUpdate", updateDrag)
        end
    end)
    button:SetScript("OnDragStop", function()
        if dragging then
            updateDrag()
            stopDrag()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if GameTooltip and not dragging then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            addMinimapTooltip(GameTooltip)
            if ownsAnchor() then
                GameTooltip:AddLine("Drag to move around the minimap", 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnHide", function()
        stopDrag()
        hideTooltip()
    end)
    return button
end

function namespace.CreateSettingsUI(api)
    local ui = {}
    local panel, setMinimapVisible, lastMinimapVisibility

    function ui:Refresh()
        local options = api.get()
        if setMinimapVisible and options.showMinimap ~= lastMinimapVisibility then
            lastMinimapVisibility = options.showMinimap
            options.minimap.hide = not options.showMinimap
            setMinimapVisible(options.showMinimap)
        end
        if panel then
            refreshPanel(panel, api)
        end
    end

    function ui:Open()
        if not panel then
            panel = makePanel(api)
        end
        self:Refresh()
        panel:Show()
    end

    function ui:Toggle()
        if panel and panel:IsShown() then
            panel:Hide()
        else
            self:Open()
        end
    end

    local function onMinimapClick(_, mouseButton)
        if mouseButton == "RightButton" then
            if not IsControlKeyDown or not IsControlKeyDown() then
                ui:Open()
            end
        elseif mouseButton == "LeftButton" and api.openSecrets then
            if panel then
                panel:Hide()
            end
            api.openSecrets()
        end
    end

    function ui:AttachMinimap()
        if setMinimapVisible or not Minimap then
            return
        end
        local options = api.get()
        local position = options.minimap
        lastMinimapVisibility = options.showMinimap
        position.hide = not options.showMinimap
        local broker = LibStub and LibStub("LibDataBroker-1.1", true)
        local dbIcon = LibStub and LibStub("LibDBIcon-1.0", true)
        if broker and type(broker.NewDataObject) == "function" and dbIcon
            and type(dbIcon.Register) == "function" and type(dbIcon.Show) == "function" and type(dbIcon.Hide) == "function" then
            local launcher = broker:NewDataObject(addonName, {
                type = "launcher", label = "SecretsCompass", icon = iconPath,
                OnClick = onMinimapClick, OnTooltipShow = addMinimapTooltip,
            })
            if launcher then
                dbIcon:Register(addonName, launcher, position)
                setMinimapVisible = function(shown)
                    if shown then
                        dbIcon:Show(addonName)
                    else
                        dbIcon:Hide(addonName)
                    end
                end
                return
            end
        end

        local button = createMinimapButton(position, onMinimapClick, api.finite)
        setMinimapVisible = function(shown)
            if shown then
                button:Show()
            else
                button:Hide()
            end
        end
    end
    return ui
end
