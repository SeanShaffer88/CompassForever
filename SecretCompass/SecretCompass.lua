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
local secretTracker, secretsUI
local secretStep, secretContinent, secretX, secretY
local secretBearing, secretDistance
local directions = { [0] = "N", [90] = "E", [180] = "S", [270] = "W" }

local frame = CreateFrame("Frame", "SecretCompassFrame", UIParent)
frame:SetSize(halfWidth * 2, 280)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 88)
frame:Hide()

local function hudScale()
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local headingLayer = CreateFrame("Frame", "SecretCompassHeading", frame)
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

local detailLayer = CreateFrame("Frame", "SecretCompassStyleDetails", frame)
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

local waypoint = CreateFrame("Frame", "SecretCompassWaypoint", frame)
waypoint:SetSize(1, 1)
waypoint:Hide()
local distanceLabel = waypoint:CreateFontString(nil, "OVERLAY", "GameFontNormal")
distanceLabel:SetTextColor(unpack(activeStyle.arc))
local diamond = {}
for index = 1, 4 do
    local color = activeStyle.pin
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

local pinContinent, pinX, pinY
local function readPin()
    pinContinent, pinX, pinY = nil, nil, nil
    local point = C_Map.GetUserWaypoint()
    if readable(point) and type(point) == "table" then
        pinContinent, pinX, pinY = worldPosition(point.uiMapID, point.position)
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

local function distanceText(yards, edge, prefix)
    local text = ("%.0f yd"):format(yards)
    if prefix then
        text = prefix .. " " .. text
    end
    if edge == "<" then
        return "< " .. text
    elseif edge == ">" then
        return text .. " >"
    end
    return text
end

local previousOffset, previousYards, previousEdge, previousSize, previousSecret
local function updateWaypoint(heading, bearing, distance, secret)
    if (not secret and not settings.showWaypoint) or not heading or not bearing then
        if waypoint:IsShown() then
            waypoint:Hide()
        end
        return
    end

    local offset, edge = markerOffset(heading, bearing, distance)
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

    local yards = math.floor(distance + 0.5)
    if yards ~= previousYards or edge ~= previousEdge or secret ~= previousSecret then
        distanceLabel:SetText(distanceText(yards, edge, secret and "Secret" or nil))
        previousYards, previousEdge, previousSecret = yards, edge, secret
    end

    local size = math.max(5, 9 - math.floor(distance / 200))
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

local questLog = C_QuestLog
local questMarkers = {}
local function colorQuestMarker(marker)
    local color = activeStyle.quest
    marker.label:SetTextColor(unpack(color))
    marker.leader:SetColorTexture(color[1] * 0.87, color[2] * 0.83, color[3] * 0.94, 0.35)
end

local function getQuestMarker(index)
    if questMarkers[index] then
        return questMarkers[index]
    end
    local marker = CreateFrame("Frame", "SecretCompassQuest" .. index, frame)
    marker:SetSize(1, 1)
    marker:Hide()
    local label = marker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local leader = marker:CreateLine(nil, "BACKGROUND")
    leader:SetThickness(1)
    leader:Hide()
    local questMarker = { frame = marker, label = label, leader = leader }
    colorQuestMarker(questMarker)
    questMarkers[index] = questMarker
    return questMarker
end

local watches, questTargets, nearbyTargets = {}, {}, {}
local testTargets
local questsDirty, lastPlayerMap, lastPlayerContinent = true

local function readQuestWatches()
    watches = {}
    if not questLog or not questLog.GetNumQuestWatches or not questLog.GetQuestIDForQuestWatchIndex then
        return
    end
    local count = questLog.GetNumQuestWatches()
    if not finite(count) then
        return
    end
    local seen = {}
    for index = 1, count do
        local id = questLog.GetQuestIDForQuestWatchIndex(index)
        if finite(id) and id > 0 and not seen[id] then
            local completed = questLog.IsComplete and questLog.IsComplete(id)
            if readable(completed) and completed ~= true then
                watches[#watches + 1] = id
            end
            seen[id] = true
        end
    end
end

local function addQuestTarget(map, x, y, route, prioritized, firstTarget, playerContinent)
    local continent, targetX, targetY = worldCoordinates(map, x, y)
    if not continent or continent ~= playerContinent then
        return
    end
    for index = firstTarget, #questTargets do
        local target = questTargets[index]
        if continent == target.continent and targetX == target.x and targetY == target.y then
            return
        end
    end
    questTargets[#questTargets + 1] = {
        continent = continent, x = targetX, y = targetY, route = route,
        prioritized = prioritized, order = #questTargets + 1,
    }
end

local function readQuestTargets(playerMap, playerContinent)
    questTargets = {}
    if not playerContinent or #watches == 0 then
        return
    end
    local tracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID()
    if not finite(tracked) then
        tracked = nil
    end
    local mapRows = {}
    local function addPOIs(map, id, prioritized, firstTarget)
        if not finite(map) or map <= 0 or not questLog.GetQuestsOnMap then
            return
        end
        if not mapRows[map] then
            local rows = questLog.GetQuestsOnMap(map)
            mapRows[map] = readable(rows) and type(rows) == "table" and rows or {}
        end
        for _, row in ipairs(mapRows[map]) do
            if readable(row) and type(row) == "table" and finite(row.questID) and row.questID == id
                and readable(row.isQuestStart) and not row.isQuestStart
                and readable(row.isMapIndicatorQuest) and not row.isMapIndicatorQuest then
                -- GetQuestsOnMap supplies coordinates for the map being queried.
                addQuestTarget(map, row.x, row.y, false, prioritized, firstTarget, playerContinent)
            end
        end
    end

    for _, id in ipairs(watches) do
        local prioritized = id == tracked
        local firstTarget = #questTargets + 1
        addPOIs(playerMap, id, prioritized, firstTarget)
        if #questTargets < firstTarget then
            if GetQuestUiMapID then
                local map = GetQuestUiMapID(id, true)
                if finite(map) and map ~= playerMap then
                    addPOIs(map, id, prioritized, firstTarget)
                end
            end
        end
        if #questTargets < firstTarget and questLog.GetNextWaypoint then
            local map, x, y = questLog.GetNextWaypoint(id)
            addQuestTarget(map, x, y, true, prioritized, firstTarget, playerContinent)
        end
    end
end

local function closestFirst(left, right)
    if left.prioritized ~= right.prioritized then
        return left.prioritized
    elseif left.distance ~= right.distance then
        return left.distance < right.distance
    end
    return left.order < right.order
end

local function playerPosition()
    local map = C_Map.GetBestMapForUnit("player")
    if finite(map) then
        local continent, x, y = worldPosition(map, C_Map.GetPlayerMapPosition(map, "player"))
        return map, continent, x, y
    end
end

local function resolveSecret()
    secretContinent, secretX, secretY = nil, nil, nil
    secretBearing, secretDistance = nil, nil
    if secretTracker then
        local step, waypoint = secretTracker:GetCurrentStep()
        secretStep = step
        if waypoint then
            local ok, continent, x, y = pcall(worldCoordinates, waypoint.mapID, waypoint.x, waypoint.y)
            if ok then
                secretContinent, secretX, secretY = continent, x, y
            end
        end
    end
end

local bearing, distance
local function sampleDestinations()
    if secretStep and not testTargets then
        secretBearing, secretDistance = nil, nil
        if secretContinent then
            local _, continent, x, y = playerPosition()
            secretBearing, secretDistance = destinationBearing(continent, x, y, secretContinent, secretX, secretY)
        end
        return
    end
    if questsDirty then
        readQuestWatches()
    end
    local playerMap, continent, x, y
    if pinContinent or #watches > 0 then
        playerMap, continent, x, y = playerPosition()
    end
    if questsDirty or playerMap ~= lastPlayerMap or (continent and continent ~= lastPlayerContinent) then
        questsDirty = false
        lastPlayerMap = playerMap
        lastPlayerContinent = continent
        readQuestTargets(playerMap, continent)
    end

    bearing, distance = nil, nil
    for index = #nearbyTargets, 1, -1 do
        nearbyTargets[index] = nil
    end
    if not continent then
        return
    end
    bearing, distance = destinationBearing(continent, x, y, pinContinent, pinX, pinY)
    for _, target in ipairs(questTargets) do
        target.bearing, target.distance = destinationBearing(continent, x, y, target.continent, target.x, target.y)
        if target.bearing then
            nearbyTargets[#nearbyTargets + 1] = target
        end
    end
    table.sort(nearbyTargets, closestFirst)
end

local questLabelGap = 4

local function freeQuestRow(index, firstY, lastY, step, left, right)
    local marker = questMarkers[index]
    for y = firstY, lastY, step do
        local fits = true
        for earlier = 1, index - 1 do
            local other = questMarkers[earlier]
            if left - questLabelGap < other.right and right + questLabelGap > other.left
                and math.abs(y - other.normalY) < (marker.height + other.height) / 2 + questLabelGap then
                fits = false
                break
            end
        end
        if fits then
            return y
        end
    end
end

local function placeQuestMarker(marker, x, y, anchor, scale)
    if scale ~= marker.scale then
        marker.label:SetTextScale(scale)
        marker.scale = scale
    end
    if anchor ~= marker.anchor then
        marker.label:ClearAllPoints()
        marker.label:SetPoint(anchor, marker.frame, "CENTER")
        marker.anchor = anchor
    end
    if x ~= marker.x or y ~= marker.y then
        marker.frame:ClearAllPoints()
        marker.frame:SetPoint("CENTER", frame, "CENTER", x, y)
        marker.x, marker.y = x, y
    end
    local shifted = x ~= marker.bearingX
    if shifted then
        local direction = marker.bearingX < x and -1 or 1
        if marker.leaderX ~= marker.bearingX or marker.leaderAnchor ~= anchor
            or marker.leaderWidth ~= marker.width * scale or marker.leaderDirection ~= direction then
            local width = marker.width * scale
            local endX = direction * (width / 2 + 2)
            if anchor == "LEFT" then
                endX = endX + width / 2
            elseif anchor == "RIGHT" then
                endX = endX - width / 2
            end
            marker.leader:SetStartPoint("CENTER", frame, marker.bearingX, arcY(marker.bearingX))
            marker.leader:SetEndPoint("CENTER", marker.frame, endX, 0)
            marker.leaderX, marker.leaderAnchor, marker.leaderWidth = marker.bearingX, anchor, width
            marker.leaderDirection = direction
        end
        if not marker.leader:IsShown() then
            marker.leader:Show()
        end
    elseif marker.leader:IsShown() then
        marker.leader:Hide()
    end
    if not marker.frame:IsShown() then
        marker.frame:Show()
    end
end

local function normalQuestLayout(count, left, right, bottom, top)
    for index = 1, count do
        local marker = questMarkers[index]
        local x = marker.bearingX
        local anchor, textLeft = "CENTER", x - marker.width / 2
        if textLeft + marker.width > right then
            anchor, textLeft = "RIGHT", x - marker.width
        elseif textLeft < left then
            anchor, textLeft = "LEFT", x
        end
        local textRight = textLeft + marker.width
        if textLeft < left or textRight > right then
            return false
        end
        local minY, maxY = bottom + marker.height / 2, top - marker.height / 2
        local firstY = math.min(arcY(x) - 22, maxY)
        local rowStep = marker.height + questLabelGap
        local y = freeQuestRow(index, firstY, minY, -rowStep, textLeft, textRight)
            or freeQuestRow(index, math.max(66, minY), maxY, rowStep, textLeft, textRight)
        if not y then
            return false
        end
        marker.left, marker.right, marker.normalY, marker.normalAnchor = textLeft, textRight, y, anchor
    end
    return true
end

local function compactQuestLayout(count, left, right, bottom, top, scaleRatio)
    local widest, tallest = 0, 0
    for index = 1, count do
        local marker = questMarkers[index]
        widest = math.max(widest, marker.width)
        tallest = math.max(tallest, marker.height)
    end

    local bandBottom, bandTop = bottom, math.min(top, -76)
    if bandTop - bandBottom < 1 then
        local upperBottom = math.max(bottom, 58)
        bandBottom, bandTop = upperBottom < top and upperBottom or bottom, top
    end
    local availableWidth = math.min(right - left, 440 / math.max(1, scaleRatio))
    local availableHeight = bandTop - bandBottom
    local cellWidth, cellHeight = widest + questLabelGap, tallest + questLabelGap
    local scale, columns = 0, 1
    for candidate = 1, count do
        local rows = math.ceil(count / candidate)
        local candidateScale = math.min(1, availableWidth / (candidate * cellWidth),
            availableHeight / (rows * cellHeight))
        -- At the same text size, the wider grid keeps the last row closer to the compass.
        if candidateScale >= scale then
            scale, columns = candidateScale, candidate
        end
    end

    local columnWidth, rowHeight = cellWidth * scale, cellHeight * scale
    local halfBlockWidth = availableWidth / 2
    local center = math.max(left + halfBlockWidth, math.min(0, right - halfBlockWidth))
    for index = 1, count do
        local row, column = math.floor((index - 1) / columns), (index - 1) % columns
        local rowColumns = math.min(columns, count - row * columns)
        local x = center + (column + 0.5 - rowColumns / 2) * columnWidth
        local y = bandTop - (row + 0.5) * rowHeight
        placeQuestMarker(questMarkers[index], x, y, "CENTER", scale)
    end
end

local lastQuestCount, lastQuestLeft, lastQuestRight, lastQuestBottom, lastQuestTop
local function renderQuests(heading)
    local targets = testTargets or nearbyTargets
    local count = (testTargets or (heading and settings.showQuests and not secretStep)) and #targets or 0
    for index = count + 1, math.min(lastQuestCount or 0, #questMarkers) do
        questMarkers[index].frame:Hide()
    end
    local layoutChanged = count ~= lastQuestCount
    lastQuestCount = count
    if count == 0 then
        return
    end

    local centerX, centerY = frame:GetCenter()
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    if not finite(centerX) or not finite(centerY) or not finite(screenWidth) or not finite(screenHeight)
        or screenWidth <= 0 or screenHeight <= 0 then
        -- Anchors are resolved after the frame and its parent acquire valid geometry.
        lastQuestLeft = nil
        for index = 1, #questMarkers do
            questMarkers[index].frame:Hide()
        end
        return
    end
    local scale = hudScale()
    local horizontalMargin, verticalMargin = math.min(8, screenWidth / 4), math.min(8, screenHeight / 4)
    local left = horizontalMargin / scale - centerX
    local right = (screenWidth - horizontalMargin) / scale - centerX
    local bottom = verticalMargin / scale - centerY
    local top = (screenHeight - verticalMargin) / scale - centerY
    layoutChanged = layoutChanged or left ~= lastQuestLeft or right ~= lastQuestRight
        or bottom ~= lastQuestBottom or top ~= lastQuestTop
    lastQuestLeft, lastQuestRight = left, right
    lastQuestBottom, lastQuestTop = bottom, top

    for index, target in ipairs(targets) do
        local marker = getQuestMarker(index)
        local offset, edge = 0, nil
        if not testTargets then
            offset, edge = markerOffset(heading, target.bearing, target.distance)
        end
        local yards = math.floor(target.distance + 0.5)
        if offset ~= marker.offset then
            marker.offset = offset
            marker.bearingX = offset * halfWidth / halfView
            layoutChanged = true
        end
        if yards ~= marker.yards or edge ~= marker.edge or target.route ~= marker.route then
            local text = distanceText(yards, edge, target.route and "~" or "!")
            marker.label:SetText(text)
            local scale = marker.scale or 1
            if scale ~= 1 then
                marker.label:SetTextScale(1)
            end
            local width, height = marker.label:GetStringWidth(), marker.label:GetStringHeight()
            if scale ~= 1 then
                marker.label:SetTextScale(scale)
            end
            width = width > 0 and width or #text * 7
            height = height > 0 and height or 14
            layoutChanged = layoutChanged or width ~= marker.width or height ~= marker.height
            marker.width, marker.height = width, height
            marker.yards, marker.edge, marker.route = yards, edge, target.route
        end
    end

    if not layoutChanged then
        return
    end
    if normalQuestLayout(count, math.max(left, -halfWidth + 4), math.min(right, halfWidth - 4), bottom, top) then
        for index = 1, count do
            local marker = questMarkers[index]
            placeQuestMarker(marker, marker.bearingX, marker.normalY, marker.normalAnchor, 1)
        end
    else
        compactQuestLayout(count, left, right, bottom, top, scale)
    end
end

local secretStatus
local function updateSecretStatus(heading)
    local status = ""
    if secretStep then
        if testTargets then
            status = "Compass paused during the overflow test."
        elseif not settings.enabled or settings.opacity == 0 then
            status = "The HUD is hidden."
        elseif #secretStep.waypoints > 0 then
            if heading and secretBearing then
                status = "Follow the Secret marker on your compass."
            else
                status = "Bearing unavailable here. Use the map location."
            end
        end
    end
    if status ~= secretStatus then
        secretStatus = status
        if secretsUI then
            secretsUI:RefreshStatus()
        end
    end
end

local function render()
    local heading = getHeading()
    updateHeading(heading)
    if secretStep and not testTargets then
        updateWaypoint(heading, secretBearing, secretDistance, true)
    else
        updateWaypoint(heading, bearing, distance)
    end
    renderQuests(heading)
    updateSecretStatus(heading)
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
        sampleDestinations()
    end
    render()
end

local function refresh()
    questsDirty = true
    readPin()
    sampleDestinations()
    render()
end

local moving, moveMode
local lockButton = CreateFrame("Button", "SecretCompassLockButton", UIParent, "UIPanelButtonTemplate")
lockButton:SetSize(146, 24)
lockButton:SetFrameStrata("DIALOG")
lockButton:SetClampedToScreen(true)
lockButton:SetText("Lock SecretCompass")
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

local testLabel = frame:CreateFontString("SecretCompassTestLabel", "OVERLAY", "GameFontNormal")
testLabel:SetPoint("CENTER", frame, "CENTER", 0, 51)
testLabel:SetText("Test Mode")
testLabel:Hide()

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
    local pin = activeStyle.pin
    for _, edge in ipairs(diamond) do
        edge:SetColorTexture(pin[1], pin[2], pin[3], 1)
    end
    for _, marker in ipairs(questMarkers) do
        colorQuestMarker(marker)
        marker.leaderX = nil
    end
    testLabel:SetTextColor(unpack(activeStyle.quest))
    previousHeading, previousOffset, lastQuestLeft = false, nil, nil
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
    moveGuide:SetShown(enabled and not testTargets)
    lockButton:SetShown(enabled)
    applyOpacity()
end

local function updateVisibility()
    if settings.enabled or testTargets then
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

local function setTestCount(count)
    if count ~= nil then
        if not finite(count) or count < 1 or count > 128 or count ~= math.floor(count) then
            return
        end
        testTargets = {}
        for index = 1, count do
            testTargets[index] = { distance = index * 10 }
        end
    else
        testTargets = nil
    end
    testLabel:SetShown(testTargets ~= nil)
    moveGuide:SetShown(moveMode and not testTargets or false)
    updateVisibility()
    refreshSettingsUI()
end

local function handleTestCommand(argument)
    if argument == "" then
        setTestCount(not testTargets and 64 or nil)
    elseif argument == "off" then
        setTestCount(nil)
    else
        local count = argument:match("^%d+$") and tonumber(argument)
        if count and count >= 1 and count <= 128 then
            setTestCount(count)
        else
            print("SecretCompass: use /secretcompass test, /secretcompass test 1–128, or /secretcompass test off")
        end
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
    refreshSettingsUI()
end)

local function startOrStopMove()
    if not settings.enabled and not testTargets then
        settings.enabled = true
        updateVisibility()
    end
    setMoveMode(not moveMode)
    refreshSettingsUI()
end

local function resetPosition()
    setMoveMode(false)
    settings.x, settings.y = 0, 88
    place()
    refreshSettingsUI()
end

local function normalizeScale(value)
    local percent = math.max(minScale, math.min(maxScale, value * 100))
    return math.floor(percent / scaleStep + 0.5) * scaleStep / 100
end

local switches = { enabled = true, showQuests = true, showWaypoint = true, showCardinals = true, showMinimap = true }
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
        if settings.enabled or testTargets then
            render()
        end
    elseif key ~= "showMinimap" then
        if key == "showCardinals" then
            previousHeading = false
        elseif key == "style" then
            applyStyle()
        end
        if settings.enabled or testTargets then
            render()
        end
    end
    refreshSettingsUI()
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
        if settings.enabled or testTargets then
            refresh()
        else
            updateSecretStatus()
        end
        if secretsUI then
            secretsUI:Refresh()
        end
    end)
    local function standaloneRoute()
        local routes = ns.StandaloneSecrets and ns.StandaloneSecrets()
        return routes and routes[1]
    end
    secretsUI = ns.CreateSecretsUI({
        getRoute = function() return secretTracker:GetRoute() end,
        getCurrentStep = function() return secretTracker:GetCurrentStep() end,
        status = function() return secretStatus end,
        hudHidden = function() return not settings.enabled or settings.opacity == 0 end,
        enableHUD = function()
            if settings.opacity == 0 then
                setPreference("opacity", 1)
            end
            setPreference("enabled", true)
        end,
        canStart = function() return standaloneRoute() ~= nil end,
        start = function() secretTracker:Track(standaloneRoute()) end,
        step = function(delta) secretTracker:Step(delta) end,
        next = function()
            local route, index = secretTracker:GetRoute()
            if route and index == #route.steps then
                secretTracker:Stop()
                secretsUI:ShowFinished()
            else
                secretTracker:Step(1)
            end
        end,
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

SLASH_SECRETCOMPASS1 = "/secretcompass"
SLASH_SECRETCOMPASS2 = "/fcompass"
SlashCmdList.SECRETCOMPASS = function(message)
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
    elseif command == "test" or command:match("^test%s") then
        handleTestCommand(command:match("^test%s*(.*)$"))
    else
        print("SecretCompass: /secretcompass toggle, /secretcompass move, /secretcompass reset, /secretcompass test, /secretcompass settings, /secretcompass secrets")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= addonName then
            return
        end
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("USER_WAYPOINT_UPDATED")
        if questLog then
            self:RegisterEvent("QUEST_LOG_UPDATE")
            self:RegisterEvent("QUEST_POI_UPDATE")
            self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
            self:RegisterEvent("QUEST_WATCH_UPDATE")
            self:RegisterEvent("SUPER_TRACKING_CHANGED")
            self:RegisterEvent("SUPER_TRACKING_PATH_UPDATED")
        end
        if type(ForeverCompassDB) ~= "table" then
            ForeverCompassDB = {}
        end
        settings = ForeverCompassDB
        for key in pairs(switches) do
            settings[key] = settings[key] ~= false
        end
        settings.theme = nil
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
                test = setTestCount,
                testActive = function() return testTargets ~= nil end,
            })
        end
    elseif (settings.enabled or testTargets) and event == "PLAYER_ENTERING_WORLD" then
        if secretStep and not secretContinent then
            resolveSecret()
        end
        refresh()
    elseif (settings.enabled or testTargets) and event == "USER_WAYPOINT_UPDATED" then
        readPin()
        sampleDestinations()
        render()
    else
        questsDirty = true
    end
end)
