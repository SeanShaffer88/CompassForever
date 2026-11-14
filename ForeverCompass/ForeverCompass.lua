local addonName = ...
local halfWidth, arcRise, halfView = 280, 62, 112
local markerView = halfView - 12
local whiteR, whiteG, whiteB = 1, 0.97, 0.89
local directions = { [0] = "N", [90] = "E", [180] = "S", [270] = "W" }

local frame = CreateFrame("Frame", "ForeverCompassFrame", UIParent)
frame:SetSize(halfWidth * 2, 280)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 88)
frame:Hide()

local headingLayer = CreateFrame("Frame", "ForeverCompassHeading", frame)
headingLayer:SetAllPoints(frame)
headingLayer:Hide()

local function arcY(x)
    return -arcRise * (x / halfWidth) ^ 2
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

for index = 1, 40 do
    local fromX = -halfWidth + (index - 1) * halfWidth / 20
    local toX = -halfWidth + index * halfWidth / 20
    local alpha = 0.85 - 0.38 * (math.abs((fromX + toX) / 2) / halfWidth) ^ 3
    local segment = makeLine(frame, "BACKGROUND", 2, whiteR, whiteG, whiteB, alpha)
    setLine(segment, frame, fromX, arcY(fromX), toX, arcY(toX))
end

local ticks = {}
for bearing = 0, 345, 15 do
    local mark = directions[bearing]
    local line = makeLine(headingLayer, "ARTWORK", mark and 2 or 1.2,
        whiteR, whiteG, whiteB, mark and 1 or 0.75)
    local label
    if mark then
        label = headingLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetText(mark)
        label:SetTextColor(whiteR, whiteG, whiteB)
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
        tick.line:SetShown(visible)
        if tick.label then
            tick.label:SetShown(visible)
        end
        if visible then
            local x = offset * halfWidth / halfView
            local y = arcY(x)
            local length = tick.label and 9 or 5
            setLine(tick.line, headingLayer, x, y - length, x, y + length)
            if tick.label then
                tick.label:ClearAllPoints()
                tick.label:SetPoint("BOTTOM", headingLayer, "CENTER", x, y + 12)
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

local waypoint = CreateFrame("Frame", "ForeverCompassWaypoint", frame)
waypoint:SetSize(1, 1)
waypoint:Hide()
local distanceLabel = waypoint:CreateFontString(nil, "OVERLAY", "GameFontNormal")
distanceLabel:SetTextColor(whiteR, whiteG, whiteB)
local diamond = {}
for index = 1, 4 do
    diamond[index] = makeLine(waypoint, "ARTWORK", 2, 0.82, 0.47, 1, 1)
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

local previousOffset, previousYards, previousEdge, previousSize
local function updateWaypoint(heading, bearing, distance)
    if not heading or not bearing then
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
    if yards ~= previousYards or edge ~= previousEdge then
        distanceLabel:SetText(distanceText(yards, edge))
        previousYards, previousEdge = yards, edge
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
local function getQuestMarker(index)
    if questMarkers[index] then
        return questMarkers[index]
    end
    local marker = CreateFrame("Frame", "ForeverCompassQuest" .. index, frame)
    marker:SetSize(1, 1)
    marker:Hide()
    local label = marker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetTextColor(1, 0.77, 0.32)
    local leader = makeLine(marker, "BACKGROUND", 1, 0.87, 0.64, 0.3, 0.35)
    leader:Hide()
    questMarkers[index] = { frame = marker, label = label, leader = leader }
    return questMarkers[index]
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

local bearing, distance
local function sampleDestinations()
    if questsDirty then
        readQuestWatches()
    end
    local playerMap, continent, x, y
    if pinContinent or #watches > 0 then
        local map = C_Map.GetBestMapForUnit("player")
        if finite(map) then
            playerMap = map
            continent, x, y = worldPosition(map, C_Map.GetPlayerMapPosition(map, "player"))
        end
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

local function compactQuestLayout(count, left, right, bottom, top)
    local widest, tallest = 0, 0
    for index = 1, count do
        local marker = questMarkers[index]
        widest = math.max(widest, marker.width)
        tallest = math.max(tallest, marker.height)
    end

    -- Two rectangular bands leave the compass, compass headings and map pin clear.
    local lowerTop, upperBottom = math.min(top, -76), math.max(bottom, 58)
    if lowerTop <= bottom and upperBottom >= top then
        lowerTop = top
    end
    local scale = 1
    local columnWidth, rowHeight, columns, lowerRows, upperRows
    while true do
        columnWidth = (widest + questLabelGap) * scale
        rowHeight = (tallest + questLabelGap) * scale
        columns = math.floor((right - left) / columnWidth)
        lowerRows = math.max(0, math.floor((lowerTop - bottom) / rowHeight))
        upperRows = math.max(0, math.floor((top - upperBottom) / rowHeight))
        if columns * (lowerRows + upperRows) >= count then
            break
        end
        scale = scale * 0.85
    end

    local lowerCapacity = columns * lowerRows
    for index = 1, count do
        local marker = questMarkers[index]
        local lower = index <= lowerCapacity
        local cell = lower and index - 1 or index - 1 - lowerCapacity
        local row, column = math.floor(cell / columns), cell % columns
        local x = left + (column + 0.5) * columnWidth
        local y = lower and lowerTop - (row + 0.5) * rowHeight
            or upperBottom + (row + 0.5) * rowHeight
        placeQuestMarker(marker, x, y, "CENTER", scale)
    end
end

local lastQuestCount, lastQuestLeft, lastQuestRight, lastQuestBottom, lastQuestTop
local function renderQuests(heading)
    local targets = testTargets or nearbyTargets
    local count = (heading or testTargets) and #targets or 0
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
    local horizontalMargin, verticalMargin = math.min(8, screenWidth / 4), math.min(8, screenHeight / 4)
    local left, right = horizontalMargin - centerX, screenWidth - centerX - horizontalMargin
    local bottom, top = verticalMargin - centerY, screenHeight - centerY - verticalMargin
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
        compactQuestLayout(count, left, right, bottom, top)
    end
end

local function render()
    local heading = getHeading()
    updateHeading(heading)
    updateWaypoint(heading, bearing, distance)
    renderQuests(heading)
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

local settings
local moving, moveMode
local function place()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
end

local moveGuide = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
moveGuide:SetPoint("BOTTOM", frame, "CENTER", 0, 48)
moveGuide:SetText("Drag to Move  |  /fcompass move to Lock")
moveGuide:Hide()

local testLabel = frame:CreateFontString("ForeverCompassTestLabel", "OVERLAY", "GameFontNormal")
testLabel:SetPoint("CENTER", frame, "CENTER", 0, 51)
testLabel:SetText("Test Mode")
testLabel:SetTextColor(1, 0.77, 0.32)
testLabel:Hide()

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
        settings.x, settings.y = x - centerX, y - centerY
    end
    place()
end

local function setMoveMode(enabled)
    stopDrag()
    moveMode = enabled
    frame:EnableMouse(enabled)
    moveGuide:SetShown(enabled and not testTargets)
end

local function updateVisibility()
    if settings.enabled or testTargets then
        refresh()
        frame:SetScript("OnUpdate", onUpdate)
        frame:Show()
    else
        setMoveMode(false)
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

local function setTestCount(count)
    if count then
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
            print("Forever Compass: use /fcompass test, /fcompass test 1–128, or /fcompass test off")
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
frame:SetScript("OnHide", stopDrag)

SLASH_FOREVERCOMPASS1 = "/fcompass"
SlashCmdList.FOREVERCOMPASS = function(message)
    if not settings then
        return
    end
    local command = message:match("^%s*(.-)%s*$"):lower()
    if command == "" or command == "toggle" then
        settings.enabled = not settings.enabled
        updateVisibility()
    elseif command == "move" then
        if not settings.enabled then
            settings.enabled = true
            updateVisibility()
        end
        setMoveMode(not moveMode)
    elseif command == "reset" then
        setMoveMode(false)
        settings.x, settings.y = 0, 88
        place()
    elseif command == "test" or command:match("^test%s") then
        handleTestCommand(command:match("^test%s*(.*)$"))
    else
        print("Forever Compass: /fcompass toggle, /fcompass move, /fcompass reset, /fcompass test")
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
        settings.enabled = settings.enabled ~= false
        settings.x = finite(settings.x) and settings.x or 0
        settings.y = finite(settings.y) and settings.y or 88
        place()
        updateVisibility()
    elseif (settings.enabled or testTargets) and event == "PLAYER_ENTERING_WORLD" then
        refresh()
    elseif (settings.enabled or testTargets) and event == "USER_WAYPOINT_UPDATED" then
        readPin()
        sampleDestinations()
        render()
    else
        questsDirty = true
    end
end)
