local addonName, ns = ...
local halfWidth, halfView = 280, 112
local markerView = halfView - 12
local minScale, maxScale, scaleStep = 60, 150, 5
local styles = ns.CompassStyles
local styleY = ns.CompassStyleY
local styleSegmentShown = ns.CompassStyleSegmentShown
local stylesByID = {}
for _, style in ipairs(styles) do
    stylesByID[style.id] = style
end
local activeStyle = styles[1]
local settings, settingsUI
local secretTracker, secretsUI, secretNavigation
local navigationMode, navigationStatus
local secretStep, secretContinent, secretX, secretY
local secretBearing, secretDistance
local secretReveal, secretZone, secretBearingAvailable
local directions = { [0] = "N", [90] = "E", [180] = "S", [270] = "W" }

local frame = CreateFrame("Frame", "SecretsCompassFrame", UIParent)
frame:SetSize(halfWidth * 2, 280)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 88)
frame:Hide()

local function hudScale()
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local headingLayer = CreateFrame("Frame", "SecretsCompassHeading", frame)
headingLayer:SetAllPoints(frame)
headingLayer:Hide()

local function arcY(x)
    return styleY(activeStyle.id, x / halfWidth)
end

local function setLine(line, parent, x1, y1, x2, y2)
    line:SetStartPoint("CENTER", parent, x1, y1)
    line:SetEndPoint("CENTER", parent, x2, y2)
end

local function makeLine(parent, layer, width, red, green, blue, alpha)
    local line = parent:CreateLine(nil, layer)
    line:SetThickness(width)
    line:SetColorTexture(red, green, blue, alpha)
    return line
end

local arc = {}
for index = 1, 40 do
    local fromX = -halfWidth + (index - 1) * halfWidth / 20
    local toX = -halfWidth + index * halfWidth / 20
    local alpha = 0.85 - 0.38 * (math.abs((fromX + toX) / 2) / halfWidth) ^ 3
    local color = activeStyle.arc
    local segment = makeLine(frame, "BACKGROUND", 2, color[1], color[2], color[3], alpha)
    setLine(segment, frame, fromX, arcY(fromX), toX, arcY(toX))
    arc[index] = { line = segment, alpha = alpha, fromX = fromX, toX = toX }
end

local detailLayer = CreateFrame("Frame", "SecretsCompassStyleDetails", frame)
detailLayer:SetAllPoints(frame)
local details = {}
local function positionStyleDetails()
    local color = activeStyle.arc
    for index, decoration in ipairs(activeStyle.details) do
        local width, alpha = decoration[5] or 1, decoration[6] or 0.45
        local line = details[index]
        if not line then
            line = makeLine(detailLayer, "BACKGROUND", width, color[1], color[2], color[3], alpha)
            details[index] = line
        else
            line:SetThickness(width)
            line:SetColorTexture(color[1], color[2], color[3], alpha)
        end
        setLine(line, detailLayer, decoration[1], decoration[2], decoration[3], decoration[4])
        line:Show()
    end
    for index = #activeStyle.details + 1, #details do
        details[index]:Hide()
    end
end

local ticks = {}
for bearing = 0, 345, 15 do
    local mark = directions[bearing]
    local color = activeStyle.arc
    local line = makeLine(headingLayer, "ARTWORK", mark and 2 or 1.2,
        color[1], color[2], color[3], mark and 1 or 0.75)
    local label
    if mark then
        label = headingLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetText(mark)
        label:SetTextColor(unpack(color))
    end
    ticks[#ticks + 1] = { bearing = bearing, line = line, label = label }
end

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function finite(value)
    return readable(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function relativeBearing(bearing, heading)
    return (bearing - heading + 180) % 360 - 180
end

local previousHeading
local function updateHeading(heading)
    if heading == previousHeading then
        return
    end
    previousHeading = heading
    headingLayer:SetShown(heading ~= nil)
    if not heading then
        return
    end

    for _, tick in ipairs(ticks) do
        local offset = relativeBearing(tick.bearing, heading)
        local visible = math.abs(offset) <= halfView
        tick.line:SetShown(visible and (tick.label ~= nil or activeStyle.minorTicks ~= false))
        if tick.label then
            tick.label:SetShown(visible and settings.showCardinals)
        end
        if visible then
            local x = offset * halfWidth / halfView
            local y = arcY(x)
            local length = tick.label and 9 or 5
            if activeStyle.tickBelow then
                setLine(tick.line, headingLayer, x, y - length * 2, x, y)
            else
                setLine(tick.line, headingLayer, x, y - length, x, y + length)
            end
            if tick.label then
                tick.label:ClearAllPoints()
                local labelInset = activeStyle.labelInset or 12
                tick.label:SetPoint("BOTTOM", headingLayer, "CENTER", x, y + labelInset)
            end
        end
    end
end

local function getHeading()
    local facing = GetPlayerFacing()
    if finite(facing) then
        return (-math.deg(facing)) % 360
    end
end

local waypoint = CreateFrame("Frame", "SecretsCompassWaypoint", frame)
waypoint:SetSize(1, 1)
waypoint:Hide()
local distanceLabel = waypoint:CreateFontString(nil, "OVERLAY", "GameFontNormal")
distanceLabel:SetTextColor(unpack(activeStyle.arc))
local huntClue = frame:CreateFontString("SecretsCompassHuntClue", "OVERLAY", "GameFontHighlightSmall")
huntClue:SetPoint("TOP", frame, "CENTER", 0, -78)
huntClue:SetSize(385, 54)
huntClue:SetJustifyH("CENTER")
huntClue:SetJustifyV("TOP")
huntClue:Hide()
local diamond = {}
for index = 1, 4 do
    local color = activeStyle.secret
    diamond[index] = makeLine(waypoint, "ARTWORK", 2, color[1], color[2], color[3], 1)
end

local function worldCoordinates(map, x, y)
    if not finite(map) or not finite(x) or not finite(y) then
        return
    end

    local continent, world = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
    if not finite(continent) or not readable(world) or type(world) ~= "table" then
        return
    end
    x, y = world.x, world.y
    if finite(x) and finite(y) then
        return continent, x, y
    end
end

local function worldPosition(map, position)
    if readable(position) and type(position) == "table" then
        return worldCoordinates(map, position.x, position.y)
    end
end

local function destinationBearing(continent, x, y, targetContinent, targetX, targetY)
    if not continent or continent ~= targetContinent then
        return
    end

    -- World X increases north and world Y increases west.
    local north, east = targetX - x, y - targetY
    local distance = math.sqrt(north * north + east * east)
    if finite(distance) then
        return math.deg(math.atan2(east, north)) % 360, distance
    end
end

local function markerOffset(heading, bearing, distance)
    local offset = distance < 1 and 0 or relativeBearing(bearing, heading)
    if offset < -markerView then
        return -markerView, "<"
    elseif offset > markerView then
        return markerView, ">"
    end
    return offset
end

local function distanceText(yards, edge)
    local text = ("Secret %.0f yd"):format(yards)
    if edge == "<" then
        return "< " .. text
    elseif edge == ">" then
        return text .. " >"
    end
    return text
end

local previousOffset, previousYards, previousEdge, previousSize, previousApproximate
local function updateWaypoint(heading, bearing, distance, approximate)
    if not heading or not bearing then
        if waypoint:IsShown() then
            waypoint:Hide()
        end
        return
    end

    if approximate then
        bearing = (math.floor((bearing + 22.5) / 45) * 45) % 360
    end
    local offset, edge = markerOffset(heading, bearing, approximate and 1 or distance)
    if offset ~= previousOffset then
        local x = offset * halfWidth / halfView
        waypoint:ClearAllPoints()
        waypoint:SetPoint("CENTER", frame, "CENTER", x, arcY(x) + 37)
        if previousOffset == nil or (offset > 60) ~= (previousOffset > 60) then
            distanceLabel:ClearAllPoints()
            if offset > 60 then
                distanceLabel:SetPoint("RIGHT", waypoint, "CENTER", -12, 0)
            else
                distanceLabel:SetPoint("LEFT", waypoint, "CENTER", 12, 0)
            end
        end
        previousOffset = offset
    end

    local yards = not approximate and math.floor(distance + 0.5) or nil
    if yards ~= previousYards or edge ~= previousEdge or approximate ~= previousApproximate then
        if approximate then
            distanceLabel:SetText(edge == "<" and "< Secret" or (edge == ">" and "Secret >" or "Secret"))
        else
            distanceLabel:SetText(distanceText(yards, edge))
        end
        previousYards, previousEdge, previousApproximate = yards, edge, approximate
    end

    local size = approximate and 6 or math.max(5, 9 - math.floor(distance / 200))
    if size ~= previousSize then
        setLine(diamond[1], waypoint, 0, size, size, 0)
        setLine(diamond[2], waypoint, size, 0, 0, -size)
        setLine(diamond[3], waypoint, 0, -size, -size, 0)
        setLine(diamond[4], waypoint, -size, 0, 0, size)
        previousSize = size
    end
    if not waypoint:IsShown() then
        waypoint:Show()
    end
end

local function playerPosition()
    local map = C_Map.GetBestMapForUnit("player")
    if finite(map) then
        return worldPosition(map, C_Map.GetPlayerMapPosition(map, "player"))
    end
end

local function resolveSecret()
    secretContinent, secretX, secretY = nil, nil, nil
    secretBearing, secretDistance = nil, nil
    secretZone = nil
    if secretTracker then
        local step, waypoint = secretTracker:GetCurrentStep()
        secretStep = step
        secretReveal = secretTracker:GetReveal()
        if waypoint then
            secretZone = ns.SecretWaypointZone(waypoint)
            local ok, continent, x, y = pcall(worldCoordinates, waypoint.mapID, waypoint.x, waypoint.y)
            if ok then
                secretContinent, secretX, secretY = continent, x, y
            end
        end
    end
end

local function sampleSecretDestination()
    secretBearing, secretDistance = nil, nil
    if secretContinent then
        local continent, x, y = playerPosition()
        secretBearing, secretDistance = destinationBearing(continent, x, y, secretContinent, secretX, secretY)
    end
end
local function syncSecretNavigation(retryFailed)
    if not secretNavigation then
        return
    end
    local step, waypoint = secretTracker:GetCurrentStep()
    if navigationMode ~= "external" or not step then
        navigationStatus = secretNavigation:Sync(nil)
    elseif secretReveal ~= "coordinates" and secretReveal ~= "full" then
        navigationStatus = secretNavigation:Sync(nil) or "reveal"
    elseif not waypoint then
        navigationStatus = secretNavigation:Sync(nil) or "location"
    else
        navigationStatus = secretNavigation:Sync(waypoint, retryFailed)
    end
end

local secretStatus
local function updateSecretStatus(heading)
    local available = heading ~= nil and secretBearing ~= nil
    local status = ""
    if secretStep then
        if navigationStatus == "delegated" then
            status = "Waypoint sent for this step."
        elseif not settings.enabled or settings.opacity == 0 then
            status = "The HUD is hidden."
        elseif #secretStep.waypoints > 0 then
            if available then
                status = "Follow the Secret marker on your compass."
            else
                status = "Bearing unavailable here. Check the destination."
            end
        end
    end
    if status ~= secretStatus or available ~= secretBearingAvailable then
        secretStatus = status
        secretBearingAvailable = available
        if secretsUI then
            secretsUI:RefreshStatus()
        end
    end
end

local huntStep, huntDestination
local function updateHuntClue()
    if not secretStep then
        if huntClue:IsShown() then
            huntClue:Hide()
        end
        return
    end
    local destination = not secretBearingAvailable and secretZone or nil
    if huntStep ~= secretStep or huntDestination ~= destination then
        local route, index = secretTracker:GetRoute()
        local clue = secretStep.clue or "Follow the next lead."
        local text = ("%d/%d  %s"):format(index, #route.steps, clue)
        if destination then
            text = text .. "\n" .. destination
            local access = secretStep.travelHint
            if access then
                text = text .. "\n" .. (#text + #access <= 178 and access or "Open Secrets for the access hint.")
            end
        end
        huntClue:SetText(text)
        huntStep, huntDestination = secretStep, destination
    end
    if not huntClue:IsShown() then
        huntClue:Show()
    end
end

local function render()
    local heading = getHeading()
    updateHeading(heading)
    updateWaypoint(heading, secretBearing, secretDistance, secretReveal == "clue")
    updateSecretStatus(heading)
    updateHuntClue()
end

local headingElapsed, waypointElapsed = 0, 0
local function onUpdate(_, elapsed)
    headingElapsed = headingElapsed + elapsed
    waypointElapsed = waypointElapsed + elapsed
    if headingElapsed < 1 / 30 then
        return
    end
    headingElapsed = 0
    if waypointElapsed >= 0.1 then
        waypointElapsed = 0
        sampleSecretDestination()
    end
    render()
end

local function refresh()
    sampleSecretDestination()
    render()
end

local moving, moveMode
local lockButton = CreateFrame("Button", "SecretsCompassLockButton", UIParent, "UIPanelButtonTemplate")
lockButton:SetSize(146, 24)
lockButton:SetFrameStrata("DIALOG")
lockButton:SetClampedToScreen(true)
lockButton:SetText("Lock SecretsCompass")
lockButton:Hide()

local function place()
    -- The saved offsets are in UIParent units, while the HUD anchors in its own units.
    local scale = hudScale()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.x / scale, settings.y / scale)
    lockButton:ClearAllPoints()
    lockButton:SetPoint("BOTTOM", frame, "CENTER", 0, 57 * scale + 8)
end

local moveGuide = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
moveGuide:SetPoint("BOTTOM", frame, "CENTER", 0, 48)
moveGuide:SetText("Drag to Move")
moveGuide:Hide()

local function applyStyle()
    activeStyle = stylesByID[settings.style]
    local color = activeStyle.arc
    for index, segment in ipairs(arc) do
        local x1, x2 = segment.fromX, segment.toX
        setLine(segment.line, frame, x1, arcY(x1), x2, arcY(x2))
        segment.line:SetThickness(activeStyle.width)
        segment.line:SetColorTexture(color[1], color[2], color[3], segment.alpha)
        segment.line:SetShown(styleSegmentShown(activeStyle.id, index, #arc))
    end
    positionStyleDetails()
    for _, tick in ipairs(ticks) do
        local tickWidth = activeStyle.tickWidth or (tick.label and 2 or 1.2)
        tick.line:SetThickness(tickWidth)
        tick.line:SetColorTexture(color[1], color[2], color[3], tick.label and 1 or 0.75)
        if tick.label then
            tick.label:SetTextColor(unpack(color))
        end
    end
    distanceLabel:SetTextColor(unpack(color))
    local secretColor = activeStyle.secret
    for _, edge in ipairs(diamond) do
        edge:SetColorTexture(secretColor[1], secretColor[2], secretColor[3], 1)
    end
    previousHeading, previousOffset = false, nil
end

local function refreshSettingsUI()
    if settingsUI then
        settingsUI:Refresh()
    end
end

local function stopDrag()
    if not moving then
        return
    end
    moving = false
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(false)
    local x, y = frame:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    if finite(x) and finite(y) and finite(centerX) and finite(centerY) then
        local scale = hudScale()
        settings.x, settings.y = x * scale - centerX, y * scale - centerY
    end
    place()
end

local function applyOpacity()
    frame:SetAlpha(moveMode and settings.opacity == 0 and 1 or settings.opacity)
end

local function setMoveMode(enabled)
    stopDrag()
    moveMode = enabled
    frame:EnableMouse(enabled)
    moveGuide:SetShown(enabled)
    lockButton:SetShown(enabled)
    applyOpacity()
end

local function updateVisibility()
    if moveMode or (settings.enabled and secretStep and navigationStatus ~= "delegated") then
        if secretStep and not secretContinent then
            resolveSecret()
        end
        refresh()
        frame:SetScript("OnUpdate", onUpdate)
        frame:Show()
    else
        setMoveMode(false)
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        updateSecretStatus()
    end
end

local function refreshSecretNavigation(retryFailed)
    syncSecretNavigation(retryFailed)
    updateVisibility()
    if secretsUI then
        secretsUI:RefreshStatus()
    end
end

frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(false)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function()
    if moveMode then
        moving = true
        frame:StartMoving()
        frame:SetUserPlaced(false)
    end
end)
frame:SetScript("OnDragStop", stopDrag)
frame:SetScript("OnHide", function()
    if moveMode then
        setMoveMode(false)
    end
end)
lockButton:SetScript("OnClick", function()
    setMoveMode(false)
    updateVisibility()
    refreshSettingsUI()
end)

local function startOrStopMove()
    setMoveMode(not moveMode)
    updateVisibility()
    refreshSettingsUI()
end

local function resetPosition()
    setMoveMode(false)
    settings.x, settings.y = 0, 88
    place()
    updateVisibility()
    refreshSettingsUI()
end

local function normalizeScale(value)
    local percent = math.max(minScale, math.min(maxScale, value * 100))
    return math.floor(percent / scaleStep + 0.5) * scaleStep / 100
end

local switches = { enabled = true, showCardinals = true, showMinimap = true }
local function setPreference(key, value)
    if switches[key] then
        if type(value) ~= "boolean" then
            return
        end
    elseif key == "style" then
        if type(value) ~= "string" or not stylesByID[value] then
            return
        end
    elseif key == "opacity" then
        if not finite(value) then
            return
        end
        value = math.max(0, math.min(1, value))
    elseif key == "scale" then
        if not finite(value) then
            return
        end
        value = normalizeScale(value)
    else
        return
    end

    if settings[key] == value then
        return
    end
    settings[key] = value
    if key == "enabled" then
        if not value then
            setMoveMode(false)
        end
        updateVisibility()
    elseif key == "opacity" then
        applyOpacity()
        updateSecretStatus(getHeading())
    elseif key == "scale" then
        stopDrag()
        frame:SetScale(value)
        place()
        if frame:IsShown() then
            render()
        end
    elseif key ~= "showMinimap" then
        if key == "showCardinals" then
            previousHeading = false
        elseif key == "style" then
            applyStyle()
        end
        if frame:IsShown() then
            render()
        end
    end
    refreshSettingsUI()
end

BINDING_HEADER_SECRETSCOMPASS = "SecretsCompass"
BINDING_NAME_SECRETCOMPASS_NEXT_STEP = "Next Secret Step"

function SecretsCompassNextStep()
    if not secretTracker then
        return
    end
    local route, index = secretTracker:GetRoute()
    if route and index == #route.steps then
        if secretTracker:Finish() then
            secretsUI:ShowFinished()
        end
    else
        secretTracker:Step(1)
    end
end

local function parseSecretStep(text)
    if type(text) ~= "string" or not readable(text) or #text > 3 or not text:match("^[0-9]+$") then
        return
    end
    local step = tonumber(text)
    if step > 0 then
        return step
    end
end

local function initSecrets()
    if not ns.CreateSecretTracker or not ns.CreateSecretsUI then
        return
    end
    if type(SecretCompassSecretDB) ~= "table" then
        SecretCompassSecretDB = {}
    end
    secretTracker = ns.CreateSecretTracker(SecretCompassSecretDB, function()
        if not secretTracker then
            return
        end
        resolveSecret()
        syncSecretNavigation()
        updateVisibility()
        if secretsUI then
            secretsUI:Refresh()
        end
    end)
    navigationMode = readable(SecretCompassSecretDB.navigation) and SecretCompassSecretDB.navigation == "external"
        and "external" or "hud"
    secretNavigation = ns.CreateWaypointNavigation(function(status)
        navigationStatus = status
        updateVisibility()
        if secretsUI then
            secretsUI:RefreshStatus()
        end
    end)
    local function standaloneRoutes()
        return ns.StandaloneSecrets and ns.StandaloneSecrets() or {}
    end
    secretsUI = ns.CreateSecretsUI({
        getRoute = function() return secretTracker:GetRoute() end,
        getCurrentStep = function() return secretTracker:GetCurrentStep() end,
        getReveal = function() return secretTracker:GetReveal() end,
        setReveal = function(level) secretTracker:SetReveal(level) end,
        getSuggested = function() return secretTracker:GetSuggestedStep() end,
        jumpSuggested = function()
            local index = secretTracker:GetSuggestedStep()
            if index then
                secretTracker:Jump(index)
            end
        end,
        status = function() return secretStatus end,
        hasBearing = function() return secretBearingAvailable end,
        hudHidden = function()
            return navigationStatus ~= "delegated" and (not settings.enabled or settings.opacity == 0)
        end,
        navigation = function() return navigationMode, navigationStatus end,
        refreshNavigation = refreshSecretNavigation,
        switchNavigation = function()
            navigationMode = navigationMode == "external" and "hud" or "external"
            SecretCompassSecretDB.navigation = navigationMode
            refreshSecretNavigation()
        end,
        enableHUD = function()
            if settings.opacity == 0 then
                setPreference("opacity", 1)
            end
            setPreference("enabled", true)
        end,
        getRoutes = standaloneRoutes,
        getResumeStep = function(route) return secretTracker:GetResumeStep(route) end,
        hasFinished = function(route) return secretTracker:HasFinished(route) end,
        start = function(id)
            for _, route in ipairs(standaloneRoutes()) do
                if route.id == id then
                    return secretTracker:Track(route)
                end
            end
            return false
        end,
        step = function(delta) secretTracker:Step(delta) end,
        parseStep = parseSecretStep,
        jump = function(index) return secretTracker:Jump(index) end,
        next = SecretsCompassNextStep,
        stop = function() secretTracker:Stop() end,
        cycle = function() secretTracker:CycleLocation() end,
    })
    resolveSecret()
    if ns.AttachSecretChecklist then
        ns.AttachSecretChecklist(function(route)
            local tracked = secretTracker:Track(route)
            if tracked then
                secretsUI:Open()
            end
            return tracked
        end)
    end
end

SLASH_SECRETSCOMPASS1 = "/secretscompass"
SLASH_SECRETSCOMPASS2 = "/secretcompass"
SLASH_SECRETSCOMPASS3 = "/fcompass"
SlashCmdList.SECRETSCOMPASS = function(message)
    if not settings then
        return
    end
    local command = message:match("^%s*(.-)%s*$"):lower()
    if command == "" or command == "toggle" then
        setPreference("enabled", not settings.enabled)
    elseif command == "move" then
        startOrStopMove()
    elseif command == "reset" then
        resetPosition()
    elseif command == "settings" and settingsUI then
        settingsUI:Toggle()
    elseif command == "secrets" and secretsUI then
        secretsUI:Toggle()
    elseif command == "next" then
        SecretsCompassNextStep()
    elseif command == "step" or command:match("^step%s") then
        local route = secretTracker and secretTracker:GetRoute()
        if route then
            local step = parseSecretStep(command:match("^step%s+(.+)$"))
            if step and step <= #route.steps then
                secretTracker:Jump(step)
            else
                print(("SecretsCompass: enter a step from 1 to %d."):format(#route.steps))
            end
        else
            print("SecretsCompass: track a secret before choosing a step.")
        end
    else
        print("SecretsCompass: /secretscompass toggle, /secretscompass move, /secretscompass reset, /secretscompass settings, /secretscompass secrets, /secretscompass next, /secretscompass step N")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= addonName then
            if settings and (loadedAddon == "TomTom" or loadedAddon == "WaypointTracker") then
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0, function() refreshSecretNavigation(true) end)
                else
                    refreshSecretNavigation(true)
                end
            end
            return
        end
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        if type(ForeverCompassDB) ~= "table" then
            ForeverCompassDB = {}
        end
        settings = ForeverCompassDB
        for key in pairs(switches) do
            settings[key] = settings[key] ~= false
        end
        settings.theme, settings.showQuests, settings.showWaypoint = nil, nil, nil
        if type(settings.style) ~= "string" or not stylesByID[settings.style] then
            settings.style = styles[1].id
        end
        settings.opacity = finite(settings.opacity) and math.max(0, math.min(1, settings.opacity)) or 1
        settings.scale = finite(settings.scale) and normalizeScale(settings.scale) or 1
        settings.x = finite(settings.x) and settings.x or 0
        settings.y = finite(settings.y) and settings.y or 88
        applyStyle()
        frame:SetAlpha(settings.opacity)
        frame:SetScale(settings.scale)
        place()
        initSecrets()
        updateVisibility()
        if ns and ns.CreateSettingsUI then
            settingsUI = ns.CreateSettingsUI({
                get = function() return settings end,
                set = setPreference,
                styles = styles,
                minScale = minScale,
                maxScale = maxScale,
                scaleStep = scaleStep,
                styleY = styleY,
                styleSegmentShown = styleSegmentShown,
                move = startOrStopMove,
                resetPosition = resetPosition,
                openSecrets = secretsUI and function() secretsUI:Open() end,
            })
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local route = secretTracker and secretTracker:GetRoute()
        if route and route.id == "dawn-waker-eluviana" and #route.steps == 5 and not route.ongoing then
            for _, candidate in ipairs(ns.StandaloneSecrets()) do
                if candidate.id == route.id and candidate.sourceURL == route.sourceURL then
                    secretTracker:Track(candidate)
                    break
                end
            end
        end
        refreshSecretNavigation(true)
    end
end)
