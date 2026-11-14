local addonPath = assert(arg[1], "Pass the addon directory")
local function atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y < 0 and -math.pi or math.pi) end
    if y == 0 then return 0 end
    return y > 0 and math.pi / 2 or -math.pi / 2
end
math.atan2 = math.atan2 or atan2

local methods = {}
local function region(parent)
    return setmetatable({ parent = parent, shown = true, scripts = {}, events = {}, labels = {}, lines = {} },
        { __index = methods })
end

function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:RegisterEvent(key) self.events[key] = true end
function methods:UnregisterEvent(key) self.events[key] = nil end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(shown) self.shown = shown end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:GetPoint() return unpack(self.point or {}) end
function methods:GetCenter() return self.centerX or 640, self.centerY or 360 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetStartPoint(...) self.start = { ... } end
function methods:SetEndPoint(...) self.finish = { ... } end
function methods:CreateLine()
    local line = region(self)
    self.lines[#self.lines + 1] = line
    return line
end
function methods:CreateTexture() return region(self) end
function methods:CreateFontString(name)
    local label = region(self)
    if name then _G[name] = label end
    self.labels[#self.labels + 1] = label
    return label
end
for _, method in ipairs({
    "SetAllPoints", "SetFrameLevel", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
    "SetUserPlaced", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
    "SetAlpha", "SetColorTexture", "SetThickness", "SetRotation", "SetTexture",
    "SetVertexColor", "SetTextColor", "SetShadowColor", "SetShadowOffset", "SetDrawLayer",
    "SetJustifyH", "SetJustifyV", "SetFont", "SetFontObject", "SetFontHeight", "SetAtlas",
    "SetBlendMode", "SetClipsChildren", "SetHitRectInsets", "SetFormattedText",
}) do
    methods[method] = function() end
end
function methods:SetTextScale(scale) self.textScale = scale end
function methods:SetScale(scale) self.scale = scale end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
function methods:GetFrameLevel() return 1 end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:GetStringHeight() return 12 end
function methods:GetFont() return "GameFontNormal", 12, "" end

UIParent = region()
UIParent:SetSize(1280, 720)
function CreateFrame(_, name, parent)
    local frame = region(parent)
    if name then _G[name] = frame end
    return frame
end

SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local facing, waypoint, unavailable, distantContinent, playerSamples
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
function GetPlayerFacing() return facing end
function CreateVector2D(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

local watched, questPOIs, questMaps, questWaypoints, completed = {}, {}, {}, {}, {}
local superTracked, currentMap, playerX = nil, 1, 0
C_QuestLog = {
    GetNumQuestWatches = function() return #watched end,
    GetQuestIDForQuestWatchIndex = function(index) return watched[index] end,
    GetQuestsOnMap = function(mapID) return questPOIs[mapID] end,
    GetNextWaypoint = function(questID) return unpack(questWaypoints[questID] or {}) end,
    IsComplete = function(questID) return completed[questID] or false end,
}
function GetQuestUiMapID(questID) return questMaps[questID] end
C_SuperTrack = { GetSuperTrackedQuestID = function() return superTracked end }
C_Map = {
    GetUserWaypoint = function() return waypoint end,
    GetBestMapForUnit = function(unit) assert(unit == "player"); return currentMap end,
    GetPlayerMapPosition = function(mapID, unit)
        assert(mapID == currentMap and unit == "player")
        playerSamples = playerSamples + 1
        if not unavailable then return CreateVector2D(playerX, 0) end
    end,
    GetWorldPosFromMapPos = function(mapID, position)
        assert(type(position.GetXY) == 'function', 'Expected a Vector2D mixin')
        if mapID == 2 and distantContinent then return 99, position end
        if mapID == 4 then return 99, CreateVector2D(position.x * 1000, position.y * 1000) end
        if mapID ~= 2 then return 5, CreateVector2D(position.x * 1000, position.y * 1000) end
        return 5, position
    end,
}
playerSamples = 0
facing = 0
assert(loadfile(addonPath .. "/ForeverCompass.lua"))("ForeverCompass")
local frame = assert(ForeverCompassFrame)
local heading = assert(ForeverCompassHeading)
local marker = assert(ForeverCompassWaypoint)
assert(#frame.lines == 40 and #heading.lines == 24 and #heading.labels == 4, "Preallocated arc and heading regions")
local firstSegment, lastSegment = frame.lines[1], frame.lines[#frame.lines]
assert(firstSegment.start[3] < 0 and lastSegment.finish[3] > 0, "Arc spans both sides")
assert(firstSegment.start[4] < frame.lines[20].finish[4], "Arc peaks at center")
for index = 2, #frame.lines do
    local previous, current = frame.lines[index - 1], frame.lines[index]
    assert(previous.finish[3] == current.start[3] and previous.finish[4] == current.start[4],
        "Arc segment endpoints join")
end

local function event(name, ...)
    assert(frame.events[name], "Event not registered: " .. name)
    frame.scripts.OnEvent(frame, name, ...)
end

local function advance()
    if frame:IsVisible() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.25) end
end

local function labelX(label, message)
    for _, region in ipairs(heading.labels) do
        if region.text == label and region:IsVisible() and region.point then
            return assert(region.point[4] or region.point[2], "Coordinate missing")
        end
    end
    error(message or ("Expected visible cardinal: " .. label))
end

local function pin(x, y)
    waypoint = x and { uiMapID = 2, position = { x = x, y = y } } or nil
    event("USER_WAYPOINT_UPDATED")
    advance()
end

event("ADDON_LOADED", "ForeverCompass")
event("PLAYER_ENTERING_WORLD")
advance()
assert(frame:IsVisible() and heading:IsVisible() and not marker:IsVisible(), "Default state")
assert(math.abs(labelX("N")) < 0.01, "North centered")
local oldFacingX = labelX("N")
facing = -math.rad(10)
advance()
assert(labelX("N") < oldFacingX, "Clockwise movement shifts North left")
facing = math.rad(10)
advance()
assert(labelX("N") > oldFacingX, "Counterclockwise movement shifts North right across wrap")

for _, test in ipairs({
    { 0, "N", 300, 0 },
    { -math.pi / 2, "E", 0, -300 },
    { math.pi, "S", -300, 0 },
    { math.pi / 2, "W", 0, 300 },
}) do
    facing = test[1]
    pin(test[3], test[4])
    assert(math.abs(labelX(test[2])) < 0.01, "Cardinal centering")
    assert(marker:IsVisible(), "Same-continent pin visible")
    assert(marker.labels[1].text == "300 yd", "Correct distance and on-axis marker")
end

facing = 0
pin(300, -100)
local right = assert(marker.point)
pin(300, 100)
local left = assert(marker.point)
assert(right[4] > left[4], "East pin must be right of west pin")
pin(-300, -150)
assert(marker.labels[1].text:match(" >$"), "Off-arc right pin shows right cue")
assert(marker.labels[1].point[1] == "RIGHT" and marker.labels[1].point[4] < 0,
    "Right-edge label stays inside the arc")
pin(-300, 150)
assert(marker.labels[1].text:match("^< "), "Off-arc left pin shows left cue")
pin(0, 0)
assert(marker.labels[1].text == "0 yd" and marker.point[4] == 0, "Arrival stays centered")

distantContinent = true
pin(300, 0)
assert(not marker:IsVisible() and heading:IsVisible(), "Cross-continent pin hidden")
distantContinent = false
pin(300, 0)
unavailable = true
advance()
assert(not marker:IsVisible() and heading:IsVisible(), "Missing player position only hides pin")
unavailable = false
advance()
assert(marker:IsVisible(), "Pin recovers when player position becomes available")

waypoint = secret
event("USER_WAYPOINT_UPDATED")
advance()
assert(not marker:IsVisible() and heading:IsVisible(), "Unreadable pin only hides marker")
pin(300, 0)

facing = secret
advance()
assert(not heading:IsVisible() and not marker:IsVisible(), "Secret heading hides both moving layers")
facing = nil
advance()
assert(not heading:IsVisible(), "Missing facing hides heading")
facing = 0
advance()
assert(heading:IsVisible(), "Heading recovers")

pin(nil)
assert(not marker:IsVisible(), "Cleared map pin hidden")
local samplesWithoutPin = playerSamples
advance()
assert(playerSamples == samplesWithoutPin, "No player map samples without a pin")
assert(SLASH_FOREVERCOMPASS1 == "/fcompass")
local slash = assert(SlashCmdList.FOREVERCOMPASS)
slash("toggle")
assert(not frame:IsVisible() and not frame.scripts.OnUpdate and ForeverCompassDB.enabled == false, "Hidden display stops updates and persists")
slash("toggle")
advance()
assert(frame:IsVisible() and ForeverCompassDB.enabled == true, "Shown setting persists")
slash("move")
assert(frame.mouseEnabled, "Move enables dragging")
frame.scripts.OnDragStart(frame)
frame.centerX, frame.centerY = 715, 404
frame.scripts.OnDragStop(frame)
assert(ForeverCompassDB.x == 75 and ForeverCompassDB.y == 44, "Dragged position persists")
slash("move")
assert(not frame.mouseEnabled, "Move toggle locks HUD")
slash("reset")
assert(ForeverCompassDB.x == 0 and ForeverCompassDB.y == 88, "Reset restores default position")
assert(frame:IsVisible(), "Reset keeps visible compass")

local function questMarker(slot)
    return assert(_G["ForeverCompassQuest" .. slot])
end
local function questText(slot, expected)
    local quest = questMarker(slot)
    assert(quest:IsVisible(), "Expected visible quest marker " .. slot)
    local actual = quest.labels[1].text
    assert(actual == expected, "Quest " .. slot .. " expected " .. expected .. ", got " .. tostring(actual))
end

facing = 0
pin(300, 0)
watched = { 10, 11, 12, 13, 14, 15, 16 }
questMaps = { [13] = 3, [14] = 4 }
completed[15] = true
questPOIs[1] = {
    { questID = 10, inProgress = true, x = 0.12, y = -0.05 },
    { questID = 10, inProgress = true, x = 0.12, y = -0.05 },
    { questID = 10, inProgress = true, x = 0.40, y = 0 },
    { questID = 11, x = secret, y = 0 },
    { questID = 12, x = 0.07, y = 0, isQuestStart = true },
    { questID = 15, x = 0.01, y = 0 },
    { questID = 99, x = 0.02, y = 0 },
}
questPOIs[3] = { { questID = 13, inProgress = true, x = 0.24, y = 0.10 } }
questPOIs[4] = { { questID = 14, inProgress = true, x = 0.25, y = 0 } }
questWaypoints[10] = { 1, 0.003, 0 }
questWaypoints[16] = { 1, 0.50, 0 }

event("QUEST_WATCH_LIST_CHANGED")
advance()
questText(1, "! 130 yd")
questText(2, "! 260 yd")
questText(3, "! 400 yd")
assert(questMarker(1).point[4] > 0 and questMarker(2).point[4] < 0, "Each objective uses its own bearing")
assert(marker:IsVisible() and marker.labels[1].text == "300 yd", "Manual pin keeps its own distance")

playerX = 0.12
advance()
questText(1, "! 50 yd")
questText(2, "! 156 yd")
questText(3, "! 280 yd")
assert(marker.labels[1].text == "180 yd", "Manual and quest distances update as the player moves")
playerX = 0
superTracked = 16
event("SUPER_TRACKING_CHANGED")
advance()
questText(1, "~ 500 yd")
questText(2, "! 130 yd")
questText(3, "! 260 yd")

unavailable = true
advance()
assert(not questMarker(1):IsVisible() and not marker:IsVisible(), "Missing player location hides destinations")
unavailable = false
advance()
questText(1, "~ 500 yd")

watched, superTracked = { 10, 13, 14, 15 }, nil
completed[10] = true
event("QUEST_LOG_UPDATE")
advance()
questText(1, "! 260 yd")
assert(not questMarker(2):IsVisible() and not questMarker(3):IsVisible(), "Turn-ins and cross-world destinations hidden")
questPOIs[3] = {}
event("QUEST_POI_UPDATE")
advance()
assert(not questMarker(1):IsVisible() and marker:IsVisible(), "Removed POI clears its quest slot only")

watched = { 14, 17, 18 }
questWaypoints[14] = { 1, 0.61, 0 }
questPOIs[1] = {
    { questID = 17, inProgress = true, x = -0.3, y = -0.12 },
    { questID = 18, inProgress = true, x = -0.5, y = 0.18 },
}
event("QUEST_WATCH_LIST_CHANGED")
advance()
questText(1, "! 323 yd >")
questText(2, "< ! 531 yd")
questText(3, "~ 610 yd")
local rightQuestAnchor = questMarker(1).labels[1].point
local leftQuestAnchor = questMarker(2).labels[1].point
assert(rightQuestAnchor[1] == "RIGHT" and leftQuestAnchor[1] == "LEFT",
    "Quest labels anchor inward at both compass edges")

currentMap = 4
advance()
questText(1, "! 250 yd")
assert(not questMarker(2):IsVisible() and not marker:IsVisible(), "Zone change resolves the original quest POI in the new world space")
currentMap = 1
advance()
questText(3, "~ 610 yd")

C_QuestLog.GetQuestsOnMap, GetQuestUiMapID = nil, nil
watched = { 16 }
event("QUEST_WATCH_LIST_CHANGED")
advance()
questText(1, "~ 500 yd")
assert(marker:IsVisible(), "Manual pin survives missing POI capability")

C_QuestLog.GetQuestsOnMap = function(mapID) return questPOIs[mapID] end
watched = { 21, 22, 23, 24, 25, 26, 27, 28 }
superTracked = 29
questPOIs[1] = {}
for index = 1, 8 do
    questPOIs[1][index] = {
        questID = watched[index], inProgress = true,
        x = index * (index <= 6 and 0.04 or 0.01),
        y = index == 7 and 0.80 or (index == 8 and -0.85 or 0),
    }
end
questPOIs[1][9] = { questID = 29, inProgress = true, x = 0.01, y = 0 }
event("QUEST_WATCH_LIST_CHANGED")
advance()

local allocated = {}
local centerRows = {}
for slot = 1, 8 do
    local quest = questMarker(slot)
    assert(quest:IsVisible(), "All eight watched objective markers visible")
    allocated[slot] = quest
    if slot <= 6 then
        questText(slot, "! " .. (slot * 40) .. " yd")
        local y = quest.point[5]
        for _, otherY in ipairs(centerRows) do
            assert(math.abs(y - otherY) >= 12, "Same-bearing labels have distinct rows")
        end
        centerRows[#centerRows + 1] = y
    end
end
questText(7, "! 803 yd")
questText(8, "! 854 yd")
assert(not ForeverCompassQuest9 or not ForeverCompassQuest9:IsVisible(), "Unwatched super-tracked quest is excluded")
assert(marker:IsVisible() and marker.labels[1].text == "300 yd", "Manual pin stays independent")
local function labelBounds(quest)
    local label = quest.labels[1]
    local scale = label.textScale or label.scale or quest.scale or 1
    local width, height = #(label.text or "") * 6 * scale, 12 * scale
    local x, y = quest.point[4], quest.point[5]
    local anchor = label.point[1]
    local left = anchor == "LEFT" and x or (anchor == "RIGHT" and x - width or x - width / 2)
    return left, left + width, y - height / 2, y + height / 2
end
for slot = 1, 8 do
    local l, r, b, t = labelBounds(allocated[slot])
    for previous = 1, slot - 1 do
        local otherL, otherR, otherB, otherT = labelBounds(allocated[previous])
        assert(r <= otherL or l >= otherR or t <= otherB or b >= otherT, "Objective distance labels do not overlap")
    end
end

playerX = 0.01
advance()
questText(4, "! 150 yd")
questText(6, "! 230 yd")
playerX = 0

local originalWatches = watched
watched = { 21 }
event("QUEST_WATCH_LIST_CHANGED")
advance()
assert(questMarker(1):IsVisible())
for slot = 2, 8 do
    assert(not allocated[slot]:IsVisible(), "Unwatching hides surplus quest markers")
end
watched = originalWatches
event("QUEST_WATCH_LIST_CHANGED")
advance()
for slot = 1, 8 do
    assert(questMarker(slot) == allocated[slot] and allocated[slot]:IsVisible(), "Rewatching reuses marker frames")
end
facing = nil
advance()
for slot = 1, 8 do
    assert(not allocated[slot]:IsVisible(), "Missing facing hides every quest marker")
end
facing = 0
advance()
questText(8, "! 854 yd")

frame.centerY = 140
UIParent:SetHeight(480)
watched, questPOIs[1] = {}, {}
for index = 1, 24 do
    watched[index] = 100 + index
    questPOIs[1][index] = { questID = watched[index], inProgress = true, x = 0.4, y = -index * 0.001 }
end
event("QUEST_WATCH_LIST_CHANGED")
advance()
for slot = 1, #watched do
    local quest = questMarker(slot)
    assert(quest:IsVisible(), "Dense groups retain every objective")
    local _, _, bottom, top = labelBounds(quest)
    assert(bottom + frame.centerY >= 0 and top + frame.centerY <= UIParent:GetHeight(),
        "Dense objective rows use available viewport space")
end

local function checkViewport(count)
    for slot = 1, count do
        local quest = questMarker(slot)
        assert(quest:IsVisible(), "All dense quest labels remain visible")
        local l, r, b, t = labelBounds(quest)
        assert(l + frame.centerX >= -0.01 and r + frame.centerX <= UIParent:GetWidth() + 0.01
            and b + frame.centerY >= -0.01 and t + frame.centerY <= UIParent:GetHeight() + 0.01,
            "Objective label " .. slot .. " is within both viewport dimensions")
        local leader = quest.lines[1]
        if leader:IsVisible() then
            local towardBearing = leader.start[3] - quest.point[4]
            assert(leader.finish[3] * towardBearing > 0, "Leader ends on the side of text facing its bearing")
        end
        for previous = 1, slot - 1 do
            local otherL, otherR, otherB, otherT = labelBounds(questMarker(previous))
            assert(r <= otherL + 0.01 or l >= otherR - 0.01 or t <= otherB + 0.01 or b >= otherT - 0.01,
                "Crowded objective labels do not overlap")
        end
    end
end

UIParent:SetSize(640, 360)
UIParent.centerX, UIParent.centerY = 320, 180
frame.centerX, frame.centerY = 340, 140
watched, questPOIs[1] = { 210 }, {}
for index = 1, 64 do
    questPOIs[1][index] = { questID = 210, inProgress = true, x = index / 100, y = 0 }
end
event("QUEST_WATCH_LIST_CHANGED")
advance()
checkViewport(64)
local firstX = 0
local movedToColumn = false
for slot = 1, 64 do
    questText(slot, "! " .. (slot * 10) .. " yd")
    movedToColumn = movedToColumn or math.abs(questMarker(slot).point[4] - firstX) > 20
end
assert(movedToColumn, "Co-bearing overflow expands horizontally")
local shifted = 0
for slot = 1, 64 do
    local quest = questMarker(slot)
    if math.abs(quest.point[4] - firstX) > 20 then
        local line = quest.lines[1]
        assert(line and line:IsVisible(), "Shifted objective keeps a visible bearing leader")
        assert(math.abs(line.start[3]) < 0.01, "Leader starts at the true North bearing")
        shifted = shifted + 1
    end
end
assert(shifted > 0)
assert(marker:IsVisible() and marker.labels[1].text == "300 yd", "Dense layout keeps the manual pin")

facing = -math.rad(155)
advance()
checkViewport(64)
questText(64, "< ! 640 yd")
local leftLeader = questMarker(64).lines[1]
if leftLeader:IsVisible() then
    assert(leftLeader.start[3] < 0, "Left overflow connector retains its true compass side")
end
facing = math.rad(155)
advance()
checkViewport(64)
questText(64, "! 640 yd >")
local rightLeader = questMarker(64).lines[1]
if rightLeader:IsVisible() then
    assert(rightLeader.start[3] > 0, "Right overflow connector retains its true compass side")
end
frame.centerX, frame.centerY = 300, 210
UIParent:SetSize(600, 350)
UIParent.centerX, UIParent.centerY = 300, 175
advance()
checkViewport(64)

frame.centerX, frame.centerY = 120, 95
UIParent:SetSize(240, 190)
UIParent.centerX, UIParent.centerY = 120, 95
advance()
checkViewport(64)
assert(questMarker(64).labels[1].textScale < 1, "Very small area compacts label text")
playerX = 0.01
advance()
checkViewport(64)
playerX = 0
frame.centerX, frame.centerY = 600, 360
UIParent:SetSize(1200, 720)
UIParent.centerX, UIParent.centerY = 600, 360
advance()
checkViewport(64)
assert(questMarker(64).labels[1].textScale == 1, "More room restores original text scale")

UIParent:SetSize(0, 0)
questPOIs[1][65] = { questID = 210, inProgress = true, x = 0.65, y = 0 }
event("QUEST_POI_UPDATE")
advance()
facing = nil
advance()
UIParent:SetSize(1200, 720)
facing = 0
advance()
checkViewport(65)
questText(65, "! 650 yd")

watched = { 210 }
questPOIs[1] = { { questID = 210, inProgress = true, x = 0.3, y = 0 } }
event("QUEST_POI_UPDATE")
advance()
questText(1, "! 300 yd")
frame.centerX, frame.centerY = 340, 140
UIParent:SetSize(640, 360)
UIParent.centerX, UIParent.centerY = 320, 180

local testLabel = assert(ForeverCompassTestLabel)
assert(not testLabel:IsShown(), "Test mode starts off")
slash("test")
assert(testLabel:IsVisible(), "Test mode identified")
checkViewport(64)
questText(1, "! 10 yd")
questText(64, "! 640 yd")
assert(marker:IsVisible() and marker.labels[1].text == "300 yd", "Test mode preserves manual pin")
local testColumns = false
for slot = 1, 64 do
    local leader = questMarker(slot).lines[1]
    if leader:IsVisible() then
        assert(math.abs(leader.start[3]) < 0.01, "Synthetic bearing starts at compass center")
        testColumns = true
    end
end
assert(testColumns, "Test mode reaches actual overflow columns")
facing = math.rad(155)
advance()
questText(64, "! 640 yd")
checkViewport(64)

facing = nil
advance()
questText(64, "! 640 yd")
checkViewport(64)

slash("test 1")
questText(1, "! 10 yd")
assert(not questMarker(2):IsVisible(), "Explicit count replaces the synthetic batch")
slash("test 128")
questText(128, "! 1280 yd")
checkViewport(128)
for _, invalid in ipairs({ "test 0", "test 129", "test 1.5", "test 1e2", "test 64 extra" }) do
    slash(invalid)
    questText(128, "! 1280 yd")
end

facing = 0
slash("test off")
questText(1, "! 300 yd")
assert(not questMarker(2):IsVisible() and not testLabel:IsShown(), "Exit immediately restores live objectives")
slash("toggle")
assert(not frame:IsVisible() and ForeverCompassDB.enabled == false)
slash("test")
assert(frame:IsVisible() and testLabel:IsVisible() and ForeverCompassDB.enabled == false,
    "Hidden compass shows a session-only test override")
questText(64, "! 640 yd")
slash("test")
assert(not frame:IsVisible() and not testLabel:IsShown() and ForeverCompassDB.enabled == false,
    "Bare command restores hidden state")
slash("toggle")
questText(1, "! 300 yd")

local function checkCenteredOverflow(count, center, requireBelow)
    checkViewport(count)
    local rows = {}
    for slot = 1, count do
        questText(slot, "! " .. (slot * 10) .. " yd")
        local quest = questMarker(slot)
        local left, right, _, top = labelBounds(quest)
        assert(left >= center - 220.01 and right <= center + 220.01,
            "Overflow stays within the 440-unit centered block")
        if requireBelow then
            assert(top <= -75.99, "Overflow text stays below the compass")
        end
        local y = quest.point[5]
        local row = rows[y] or { left = left, right = right }
        row.left, row.right = math.min(row.left, left), math.max(row.right, right)
        rows[y] = row
    end
    for _, row in pairs(rows) do
        assert(math.abs((row.left + row.right) / 2 - center) <= 4,
            "Each row, including the last, is centered")
    end
end

UIParent:SetSize(1920, 1080)
UIParent.centerX, UIParent.centerY = 960, 540
frame.centerX, frame.centerY = 960, 627
slash("test")
checkCenteredOverflow(64, 0, true)
slash("test 128")
checkCenteredOverflow(128, 0, true)
assert(questMarker(128).labels[1].textScale == 1, "Normal desktop viewport preserves full-size distance text")

UIParent:SetSize(640, 360)
UIParent.centerX, UIParent.centerY = 320, 180
frame.centerX, frame.centerY = 100, 140
advance()
checkCenteredOverflow(128, 128, true)
frame.centerY = 40
advance()
checkCenteredOverflow(128, 128, false)
slash("test off")
questText(1, "! 300 yd")

print("ForeverCompass mock passed: live quests and pins, centered 64/128 label overflow, viewport edges, and session-only test mode")
