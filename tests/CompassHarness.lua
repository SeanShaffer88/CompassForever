local addonPath = assert(arg[1], "Pass the addon directory")
local function atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y < 0 and -math.pi or math.pi) end
    if y == 0 then return 0 end
    return y > 0 and math.pi / 2 or -math.pi / 2
end
math.atan2 = math.atan2 or atan2

local methods = {}
local frames = {}
local function region(parent)
    return setmetatable({ parent = parent, shown = true, scripts = {}, events = {}, labels = {}, lines = {} },
        { __index = methods })
end

function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key, fn)
    local prior = self.scripts[key]
    self.scripts[key] = function(...)
        if prior then prior(...) end
        fn(...)
    end
end
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
function methods:GetCenter()
    if self.centerX or self.centerY then
        return self.centerX or 640, self.centerY or 360
    end
    local point = self.point
    if point and point[1] == "CENTER" and point[2] == UIParent and point[3] == "CENTER" then
        local x, y = UIParent:GetCenter()
        local scale = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
        return x * scale + point[4], y * scale + point[5]
    end
    return 640, 360
end
function methods:GetEffectiveScale()
    return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
end
function methods:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:SetAutoFocus(enabled) self.autoFocus = enabled end
function methods:SetFocus() self.focused = true end
function methods:HighlightText() self.highlighted = true end
function methods:ClearFocus() self.focused = false end
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
    "SetUserPlaced", "RegisterForDrag",
    "SetThickness", "SetRotation",
    "SetVertexColor", "SetShadowColor", "SetShadowOffset", "SetDrawLayer",
    "SetJustifyH", "SetJustifyV", "SetFont", "SetFontObject", "SetFontHeight", "SetAtlas",
    "SetBlendMode", "SetClipsChildren", "SetHitRectInsets", "SetFormattedText",
    "SetOrientation", "SetObeyStepOnDrag",
}) do
    methods[method] = function() end
end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValueStep(step) self.step = step end
function methods:GetValue() return self.value or 0 end
function methods:SetValue(value)
    if value == self.value then return end
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:SetThumbTexture(texture)
    self.thumb = self:CreateTexture()
    self.thumb:SetTexture(texture)
end
function methods:GetThumbTexture() return self.thumb end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetChecked(checked) self.checked = checked end
function methods:GetChecked() return self.checked end
function methods:RegisterForClicks(...) self.clicks = { ... } end
function methods:GetFontString() return self end
function methods:SetNormalTexture(texture) self.normalTexture = texture end
function methods:SetHighlightTexture(texture) self.highlightTexture = texture end
function methods:SetNormalFontObject() end
function methods:SetHighlightFontObject() end
function methods:SetDisabledFontObject() end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:GetParent() return self.parent end
function methods:SetTextScale(scale) self.textScale = scale end
function methods:SetScale(scale) self.scale = scale end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
function methods:GetFrameLevel() return 1 end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:GetStringHeight() return 12 end
function methods:GetFont() return "GameFontNormal", 12, "" end

UIParent = region()
UIParent:SetSize(1280, 720)
Minimap = region(UIParent)
Minimap:SetSize(140, 140)
UISpecialFrames = {}
function CreateFrame(_, name, parent, template)
    local frame = region(parent)
    if template == "UICheckButtonTemplate" then frame.Text = frame:CreateFontString() end
    if template == "PortraitFrameTemplate" then
        frame.PortraitContainer = { portrait = frame:CreateTexture() }
        frame.TitleContainer = { TitleText = frame:CreateFontString() }
        frame.CloseButton = region(frame)
        frame.SetTitle = function(self, title) self.TitleContainer.TitleText:SetText(title) end
        frame:SetScript("OnHide", function(self) self.nativeHideRan = true end)
    end
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local facing, waypoint, unavailable, distantContinent, playerSamples
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
function GetPlayerFacing() return facing end
local faction = "Horde"
function UnitFactionGroup(unit) assert(unit == "player"); return faction end
C_Timer = { After = function(_, callback) callback() end }
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:EnableMouseWheel() end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
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
    SetUserWaypoint = function() error("Routes must preserve the player's map pin") end,
    ClearUserWaypoint = function() error("Routes must not clear the player's map pin") end,
    GetMapInfo = function(id) return { name = "Test Map " .. id } end,
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
local namespace = {}
assert(loadfile(addonPath .. "/Styles.lua"))("SecretsCompass", namespace)
assert(loadfile(addonPath .. "/Settings.lua"))("SecretsCompass", namespace)
assert(loadfile(addonPath .. "/Secrets.lua"))("SecretsCompass", namespace)
assert(loadfile(addonPath .. "/SecretsUI.lua"))("SecretsCompass", namespace)
assert(loadfile(addonPath .. "/SecretChecklistBridge.lua"))("SecretsCompass", namespace)
assert(loadfile(addonPath .. "/SecretsCompass.lua"))("SecretsCompass", namespace)
local frame = assert(SecretsCompassFrame)
local heading = assert(SecretsCompassHeading)
local marker = assert(SecretsCompassWaypoint)
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

ForeverCompassDB = { x = 0, y = 88, theme = "unknown", style = "bogus", opacity = "mistyped" }
event("ADDON_LOADED", "SecretsCompass")
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
assert(SLASH_SECRETSCOMPASS1 == "/secretscompass" and SLASH_SECRETSCOMPASS2 == "/secretcompass"
    and SLASH_SECRETSCOMPASS3 == "/fcompass", "The renamed addon preserves its old slash aliases")
local slash = assert(SlashCmdList.SECRETSCOMPASS)
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
    return assert(_G["SecretsCompassQuest" .. slot])
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
assert(not SecretsCompassQuest9 or not SecretsCompassQuest9:IsVisible(), "Unwatched super-tracked quest is excluded")
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
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetCenter()
    for slot = 1, count do
        local quest = questMarker(slot)
        assert(quest:IsVisible(), "All dense quest labels remain visible")
        local l, r, b, t = labelBounds(quest)
        assert((l + x) * scale >= -0.01 and (r + x) * scale <= UIParent:GetWidth() + 0.01
            and (b + y) * scale >= -0.01 and (t + y) * scale <= UIParent:GetHeight() + 0.01,
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

local testLabel = assert(SecretsCompassTestLabel)
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

local function checkCenteredOverflow(count, center, requireBelow, maxRows)
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
    if maxRows then
        local rowCount = 0
        for _ in pairs(rows) do rowCount = rowCount + 1 end
        assert(rowCount <= maxRows, "Full-size overflow wraps into a shorter block")
        local _, _, bottom = labelBounds(questMarker(count))
        assert(bottom + frame.centerY >= 240, "Desktop overflow clears the lower HUD area")
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
checkCenteredOverflow(64, 0, true, 10)
slash("test 128")
checkCenteredOverflow(128, 0, true, 22)
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

local function click(control, button)
    local handler = assert(control.scripts.OnClick, "Expected click handler")
    handler(control, button or "LeftButton")
end

assert(ForeverCompassDB.theme == nil and ForeverCompassDB.style == "arc"
    and ForeverCompassDB.opacity == 1, "Old settings are normalized with Classic defaults")
local minimapButton = assert(SecretsCompassMinimapButton)
local icon = assert(minimapButton.icon)
assert(icon:IsShown() and icon:GetWidth() == 28 and icon:GetHeight() == 28
    and icon.texture == "Interface\\AddOns\\SecretsCompass\\Media\\MinimapCompass.tga",
    "Minimap button displays the bundled compass artwork")
local iconFile = assert(io.open(addonPath .. "/Media/MinimapCompass.tga", "rb"))
local pixels = iconFile:read("*a")
iconFile:close()
assert(#pixels == 4114 and pixels:byte(3) == 2 and pixels:byte(13) == 32
    and pixels:byte(15) == 32 and pixels:byte(17) == 32, "Bundled TGA is 32 by 32 RGBA")
assert(minimapButton.parent == Minimap and minimapButton:IsVisible(), "Minimap button is independent of the HUD")
click(minimapButton)
assert(not frame:IsVisible() and minimapButton:IsVisible(), "Left click hides only the HUD")
click(minimapButton, "RightButton")
local panel = assert(SecretsCompassSettings)
local controls = assert(panel.controls)
assert(panel:IsVisible() and not frame:IsVisible(), "Right click opens settings while HUD is off")
assert(panel.dragHandle.scripts.OnDragStart and panel.dragHandle.scripts.OnDragStop, "Title bar is draggable")

panel.dragHandle.scripts.OnDragStart(panel.dragHandle)
assert(panel.moving, "Title-bar drag starts panel movement")
panel.dragHandle.scripts.OnDragStop(panel.dragHandle)
assert(not panel.moving, "Title-bar drag stops movement")

assert(controls.themes == nil and controls.themeMarks == nil, "Theme options are absent")
local function shapeSignature(...)
    local parts = {}
    for group = 1, select("#", ...) do
        for _, region in ipairs(select(group, ...)) do
            if region:IsShown() then
                local a, b = region.start, region.finish
                assert(a and b, "Visible geometry has both endpoints")
                parts[#parts + 1] = table.concat({a[3], a[4], b[3], b[4]}, ",")
            end
        end
    end
    return table.concat(parts, ";")
end
local expectedStyles = { "arc", "bar", "tactical", "flight", "hero", "radical", "fantasy", "blocky",
    "horizon", "ribbon", "chevron", "minimal" }
local hudShapes, previewShapes, styleCount = {}, {}, 0
for _ in pairs(controls.styles) do styleCount = styleCount + 1 end
assert(styleCount == #expectedStyles and #namespace.CompassStyles == #expectedStyles, "Exactly 12 styles")
for _, id in ipairs(expectedStyles) do
    click(assert(controls.styles[id]))
    assert(ForeverCompassDB.style == id, "Style selection persists")
    local hud = shapeSignature(frame.lines, SecretsCompassStyleDetails.lines)
    local preview = shapeSignature(panel.preview.arc, panel.preview.details)
    assert(not hudShapes[hud] and not previewShapes[preview], "Each style has distinct geometry in both renderers: " .. id)
    hudShapes[hud], previewShapes[preview] = true, true
end
click(controls.styles.arc)

local previewArcY = panel.preview.arc[1].start[4]
click(controls.styles.bar)
assert(panel.preview.arc[1].start[4] ~= previewArcY, "Style updates the settings preview while the HUD is hidden")
assert(ForeverCompassDB.style == "bar", "Style persists separately")
assert(frame.lines[1].start[4] == frame.lines[20].finish[4], "Framed style has a straight baseline")
click(controls.styles.tactical)
assert(frame.lines[20].finish[4] < frame.lines[1].start[4], "Tactical has a center notch")
click(controls.styles.flight)
assert(not frame.lines[20]:IsShown() and SecretsCompassStyleDetails.lines[1]:IsShown(),
    "Flight breaks the center line for its chevron")
click(controls.styles.arc)
assert(frame.lines[1].start[4] < frame.lines[20].finish[4], "Arc style restores curvature")
assert(controls.transparencyValue:GetText() == "0%", "Default HUD is opaque")
for index = 1, 21 do click(controls.transparencyUp) end
assert(ForeverCompassDB.opacity == 0 and controls.transparencyValue:GetText() == "100%",
    "Transparency is bounded at 100%")
assert(frame.alpha == 0 and panel.preview.artwork.alpha == 0 and panel:IsVisible()
    and minimapButton:IsVisible(), "Only HUD and preview art fade at full transparency")
click(controls.transparencyDown)
assert(ForeverCompassDB.opacity == 0.05 and controls.transparencyValue:GetText() == "95%"
    and frame.alpha == 0.05 and panel.preview.artwork.alpha == 0.05,
    "Decreasing transparency restores both displays")
for index = 1, 20 do click(controls.transparencyDown) end
assert(ForeverCompassDB.opacity == 1 and frame.alpha == 1 and panel.preview.artwork.alpha == 1,
    "Transparency is bounded at 0%")

click(minimapButton)
assert(frame:IsVisible() and panel:IsVisible(), "Visibility control leaves settings available")
facing = 0
pin(300, 0)
questText(1, "! 300 yd")
assert(marker:IsVisible())
controls.showWaypoint:SetChecked(false)
click(controls.showWaypoint)
assert(not marker:IsVisible() and ForeverCompassDB.showWaypoint == false)
controls.showWaypoint:SetChecked(true)
click(controls.showWaypoint)
assert(marker:IsVisible())
controls.showQuests:SetChecked(false)
click(controls.showQuests)
assert(not questMarker(1):IsVisible() and ForeverCompassDB.showQuests == false)
click(controls.test)
questText(64, "! 640 yd")
click(controls.test)
assert(not questMarker(1):IsVisible(), "Stopping the preview restores hidden quest labels")
controls.showQuests:SetChecked(true)
click(controls.showQuests)
questText(1, "! 300 yd")
controls.showCardinals:SetChecked(false)
click(controls.showCardinals)
for _, label in ipairs(heading.labels) do
    assert(not label:IsVisible(), "Cardinal labels hide")
end
controls.showCardinals:SetChecked(true)
click(controls.showCardinals)
assert(math.abs(labelX("N")) < 0.01, "Cardinal labels return without a heading change")

controls.showMinimap:SetChecked(false)
click(controls.showMinimap)
assert(not minimapButton:IsVisible())
click(controls.close)
assert(not panel:IsVisible())
slash("settings")
assert(panel:IsVisible(), "Slash command recovers a hidden minimap button")
controls.showMinimap:SetChecked(true)
click(controls.showMinimap)
assert(minimapButton:IsVisible())

local size = assert(controls.size)
local lockButton = assert(SecretsCompassLockButton)
assert(ForeverCompassDB.scale == 1 and controls.sizeValue:GetText() == "100%"
    and size.minimum == 60 and size.maximum == 150 and size.step == 5,
    "Existing settings default to the original HUD size")
assert(not lockButton:IsVisible(), "Lock button appears only while moving")
UIParent:SetSize(1280, 720)
UIParent.centerX, UIParent.centerY = 640, 360
UIParent:SetScale(0.8)
frame.centerX, frame.centerY = nil, nil

size:SetValue(150)
assert(ForeverCompassDB.scale == 1.5 and frame.scale == 1.5 and panel.preview.artwork.scale == 1.5
    and controls.sizeValue:GetText() == "150%", "Slider updates the fully scaled HUD and preview")
local x, y = frame:GetCenter()
assert(math.abs(x * 1.5 - 640) < 0.01 and math.abs(y * 1.5 - 448) < 0.01,
    "Changing HUD size preserves the saved screen position")

for index = 1, 20 do click(controls.transparencyUp) end
click(controls.move)
assert(not panel:IsVisible() and lockButton:IsVisible() and lockButton.parent == UIParent
    and lockButton:GetText() == "Lock SecretsCompass" and frame.mouseEnabled,
    "Move HUD opens the independent Lock SecretsCompass button")
assert(frame.alpha == 1 and ForeverCompassDB.opacity == 0, "The transparent HUD is visible for placement")
frame.scripts.OnDragStart()
frame.centerX, frame.centerY = 750 / 1.5, 285 / 1.5
click(lockButton)
assert(not frame.moving and not frame.mouseEnabled and not lockButton:IsVisible(),
    "The lock button completes an active drag and returns the HUD to click-through")
assert(math.abs(ForeverCompassDB.x - 110) < 0.01 and math.abs(ForeverCompassDB.y + 75) < 0.01,
    "Dragging at non-default scale saves UIParent offsets")
assert(frame.alpha == 0 and ForeverCompassDB.opacity == 0, "Lock restores saved transparency")

click(minimapButton, "RightButton")
assert(panel:IsVisible(), "Settings reopen after locking a fully transparent HUD")
for index = 1, 20 do click(controls.transparencyDown) end
frame.centerX, frame.centerY = nil, nil
for _, percent in ipairs({ 60, 150 }) do
    size:SetValue(percent)
    assert(ForeverCompassDB.scale == percent / 100 and controls.sizeValue:GetText() == percent .. "%")
    for _, count in ipairs({ 64, 128 }) do
        slash("test " .. count)
        checkViewport(count)
        for slot = 1, count do
            questText(slot, "! " .. (slot * 10) .. " yd")
        end
    end
end
slash("test off")

click(controls.move)
slash("reset")
assert(not lockButton:IsVisible() and not frame.mouseEnabled and ForeverCompassDB.scale == 1.5,
    "Reset locks the HUD while retaining size")
slash("move")
slash("toggle")
assert(not lockButton:IsVisible() and not frame.mouseEnabled and not frame:IsVisible(),
    "Hiding the HUD exits move mode")

local function fireAddonEvent(name, ...)
    for _, listener in ipairs(frames) do
        if listener.events[name] and listener.scripts.OnEvent then
            listener.scripts.OnEvent(listener, name, ...)
        end
    end
end

local completionFlags, acceptedQuests = {}, {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return completionFlags[id] end
C_QuestLog.IsOnQuest = function(id) return acceptedQuests[id] end
fireAddonEvent("PLAYER_LOGIN")
assert(not SecretsCompassSecretChecklistTrackButton, "Standalone mode has no foreign-addon button")
slash("secrets")
local secrets = assert(SecretsCompassSecrets)
assert(secrets.TitleContainer.TitleText:GetText() == "SecretsCompass Journal"
    and secrets.PortraitContainer.portrait.texture:match("MinimapCompass%.tga$")
    and secrets.controls.close == secrets.CloseButton, "Journal uses its own artwork and the native frame")
local list = namespace.StandaloneSecrets()
local cozyButton = assert(secrets.controls.routes[list[1].id])
local alcazButton = assert(secrets.controls.routes[list[2].id])
assert(secrets:IsVisible() and cozyButton:IsVisible() and alcazButton:IsVisible())
acceptedQuests[79007] = true
click(cozyButton)
assert(secrets.routeTitle:GetText() == "Cozy Sleeping Bag" and secrets.progress:GetText():match("^Step 1"))
assert(secrets.controls.enableHUD:IsVisible(), "Tracking from a hidden HUD offers Show HUD")
click(secrets.controls.enableHUD)
assert(frame:IsVisible())
facing, currentMap, unavailable = 0, 1, false
advance()
assert(marker:IsVisible() and marker.labels[1]:GetText():find("Secret", 1, true)
   and not marker.labels[1]:GetText():find(" yd", 1, true), "Clue mode shows a marker without yardage")
assert(secrets.note:GetText() == "" and not secrets.locationText:GetText():find("%d+%.%d+"),
    "Clue mode hides instructions and precise coordinates")
assert(marker.lines[1].start[4] == 6, "Clue mode uses a fixed-size marker")
local hunt = assert(SecretsCompassHuntClue)
assert(hunt:IsVisible() and hunt:GetText():find("1/7", 1, true), "Compact HUD shows active step")
click(secrets.controls.close)
assert(not secrets:IsVisible() and hunt:IsVisible(), "Compact HUD works with both guide windows closed")
slash("secrets")
assert(secrets.controls.suggested:IsVisible() and SecretCompassSecretDB.index == 1,
    "Confirmed starter quest acceptance suggests a step without selecting it")
click(secrets.controls.suggested)
assert(SecretCompassSecretDB.index == 2, "Suggested step depends on explicit player selection")
currentMap = 4
advance()
assert(secrets.locationText:GetText():find("Destination:", 1, true)
    and secrets.travel:GetText() ~= "" and not marker:IsVisible(), "Curated travel hint works without a bearing")
currentMap = 1
click(secrets.controls.previous)
acceptedQuests[79007] = nil
click(secrets.controls.revealDistance)
assert(marker.labels[1]:GetText():find(" yd", 1, true)
    and not secrets.locationText:GetText():find("%d+%.%d+"), "Distance mode reveals only yardage")
click(secrets.controls.revealCoordinates)
assert(secrets.locationText:GetText():find("%d+%.%d+") and secrets.note:GetText() == "",
    "Coordinates mode still withholds full instructions")
click(secrets.controls.revealFull)
assert(secrets.note:GetText() ~= "", "Full mode reveals the instruction")
click(secrets.controls.revealClue)
assert(secrets.note:GetText() == "" and not marker.labels[1]:GetText():find(" yd", 1, true),
    "Returning to Clue removes already revealed details")
slash("test 64")
assert(not hunt:IsVisible(), "Overflow test suppresses the compact hunt HUD")
slash("test off")
assert(hunt:IsVisible(), "Leaving overflow mode restores the compact hunt HUD")
local edit, go = assert(secrets.controls.jumpInput), assert(secrets.controls.jumpGo)
assert(edit:IsVisible() and go:IsVisible() and edit.autoFocus == false and not go.enabled)
for _, invalid in ipairs({"0", "8", "1e0", "1.0", "-1", "1289", "foo"}) do
    edit:SetText(invalid)
    assert(not go.enabled, "Invalid step disables Go: " .. invalid)
    edit.scripts.OnEnterPressed(edit)
    assert(SecretCompassSecretDB.index == 1, "Invalid step cannot advance tracking")
end
edit:SetText("3")
edit:SetFocus()
edit.scripts.OnEscapePressed(edit)
assert(not edit.focused and SecretCompassSecretDB.index == 1, "Escape clears focus without jumping")
edit:SetText("3")
edit:SetFocus()
assert(go.enabled)
click(go)
assert(not edit.focused and SecretCompassSecretDB.index == 3 and secrets.note:GetText() == "",
    "Go selects the step while honoring Clue mode")
edit:SetText("4")
edit:SetFocus()
edit.scripts.OnEnterPressed(edit)
assert(not edit.focused and SecretCompassSecretDB.index == 4, "Enter uses the same direct jump")
slash("step 7")
assert(SecretCompassSecretDB.index == 7 and secrets.controls.next:GetText() == "Finish",
    "Jumping to the last step keeps the route active")
for _, command in ipairs({"step", "step 2.0", "step 2 x", "step 0", "step 1289"}) do
    slash(command)
    assert(SecretCompassSecretDB.index == 7, "Invalid slash step leaves the current step alone")
end
slash("step 1")
assert(SecretCompassSecretDB.index == 1)
edit:SetFocus()
secrets.scripts.OnHide(secrets)
assert(not edit.focused, "Panel hide clears input focus")

local starter = SecretCompassSecretDB.route
assert(starter.steps[1].waypoints[1].mapID == 1413, "Horde begins in the Barrens")
faction = "Alliance"
assert(namespace.StandaloneSecrets()[1].steps[1].waypoints[1].mapID == 1436, "Alliance begins in Westfall")
faction = nil
assert(#namespace.StandaloneSecrets() == 0, "The standalone route waits for an eligible faction")
faction = "Horde"
assert(BINDING_HEADER_SECRETSCOMPASS == "SecretsCompass" and BINDING_NAME_SECRETCOMPASS_NEXT_STEP == "Next Secret Step")
SecretsCompassNextStep()
assert(secrets.progress:GetText():match("^Step 2") and SecretCompassSecretDB.index == 2)
local resumed = namespace.CreateSecretTracker({
    route = SecretCompassSecretDB.route,
    index = SecretCompassSecretDB.index,
    locationIndex = SecretCompassSecretDB.locationIndex,
}, function() end)
local _, resumedIndex = resumed:GetRoute()
assert(resumedIndex == 2, "A new tracker resumes saved step")
click(secrets.controls.previous)
assert(SecretCompassSecretDB.index == 1)
click(secrets.controls.next)
assert(secrets.controls.stop:GetText() == "Pause")
click(secrets.controls.stop)
assert(SecretCompassSecretDB.route == nil and cozyButton:IsVisible()
    and cozyButton:GetText():find("Resume", 1, true)
    and cozyButton:GetText():find("Step 2", 1, true), "Pause exposes the saved step in the picker")

completionFlags[96335] = true
click(alcazButton)
assert(not cozyButton:IsVisible() and not alcazButton:IsVisible(), "Picker hides during an active route")
assert(secrets.routeTitle:GetText() == "Alcaz Operative Insignia" and SecretCompassSecretDB.index == 1)
assert(secrets.stepTitle:GetText():find("alive", 1, true) and secrets.note:GetText() == "",
    "Opening clue preserves the dungeon quest without exposing the full solution")
local alcaz = SecretCompassSecretDB.route
assert(alcaz.steps[1].waypoints[1].mapID == 1445 and alcaz.steps[1].waypoints[1].x == 0.753)
assert(secrets.controls.suggested:IsVisible(), "Verified prison turn-in suggests Moonbrook")
click(secrets.controls.suggested)
assert(SecretCompassSecretDB.index == 2 and alcaz.steps[2].waypoints[1].mapID == 1436)
click(secrets.controls.revealCoordinates)
assert(secrets.locationText:GetText():find("43.4, 67.8", 1, true), "Moonbrook location is revealed on request")
local mapCommand = assert(secrets.controls.mapCommand)
local mapInput = assert(secrets.controls.mapCommandInput)
assert(mapCommand:IsVisible() and not mapInput:IsVisible() and not mapInput.focused,
    "Coordinates expose the action without auto-focusing or showing text")
local pinBeforeCommand = waypoint
click(mapCommand)
assert(mapInput:IsVisible() and mapInput.focused and mapInput.highlighted
    and mapInput:GetText() == "/mappin 1436 43.40 67.80" and waypoint == pinBeforeCommand,
    "Map command selects two-decimal text and preserves the map pin")
mapInput:SetText("edited")
assert(mapInput:GetText() == "/mappin 1436 43.40 67.80", "The command field retains its generated text")
SLASH_MAPPIN1 = "/marcar"
click(mapCommand)
assert(mapInput:GetText() == "/marcar 1436 43.40 67.80", "The game-provided command alias is honored")
SLASH_MAPPIN1 = "/marcar other"
click(mapCommand)
assert(mapInput:GetText() == "/mappin 1436 43.40 67.80", "Unexpected aliases use the known fallback")
SLASH_MAPPIN1 = nil
click(secrets.controls.revealDistance)
assert(not mapCommand:IsVisible() and not mapInput:IsVisible() and not mapInput.focused
    and mapInput:GetText() == "", "A spoiler downgrade removes the command")
click(secrets.controls.revealCoordinates)
click(mapCommand)
mapInput.scripts.OnEscapePressed(mapInput)
assert(not mapInput:IsVisible() and not mapInput.focused and mapInput:GetText() == "",
    "Escape dismisses the selectable command")
click(mapCommand)
secrets.scripts.OnHide(secrets)
assert(secrets.nativeHideRan, "Journal cleanup preserves the native OnHide script")
assert(not mapInput:IsVisible() and not mapInput.focused and mapInput:GetText() == "",
    "Closing the panel clears command text and focus")
click(secrets.controls.next)
assert(alcaz.steps[3].waypoints[1].mapID == 1434 and alcaz.steps[3].waypoints[1].y == 0.758)
assert(alcaz.steps[3].completionQuestID == nil, "Unconfirmed Horde quest flag remains manual")
click(secrets.controls.revealFull)
assert(secrets.note:GetText():find("Rix Xizzix", 1, true))
click(secrets.controls.next)
assert(#alcaz.steps[4].waypoints == 0 and not marker:IsVisible(), "Final assembly has no compass target")
assert(not mapCommand:IsVisible() and not mapInput:IsVisible(), "Text-only steps have no map command")
assert(not SecretCompassSecretDB.finishedRoutes[alcaz.id], "Reaching the final step does not mark it finished")
slash("next")
assert(SecretCompassSecretDB.route == nil and alcazButton:IsVisible()
    and alcazButton:GetText():find("Replay", 1, true), "Finished routes are offered for replay")
click(alcazButton)
assert(SecretCompassSecretDB.index == 1, "Replay starts from the first step")
click(secrets.controls.next)
click(secrets.controls.stop)
assert(alcazButton:GetText():find("Resume", 1, true), "A paused replay can resume")
click(cozyButton)
assert(SecretCompassSecretDB.index == 2 and SecretCompassSecretDB.route.title == "Cozy Sleeping Bag",
    "Starting a second secret preserves the first secret's checkpoint")
click(secrets.controls.stop)
faction = "Alliance"
local allianceAlcaz = namespace.StandaloneSecrets()[2]
assert(allianceAlcaz.steps[3].waypoints[1].mapID == 1453
    and allianceAlcaz.steps[3].waypoints[1].y == 0.711
    and allianceAlcaz.steps[3].completionQuestID == 96377)
click(alcazButton)
assert(SecretCompassSecretDB.route == nil, "Stale faction-specific rows cannot start a route")
faction = "Horde"
completionFlags[96335] = nil

local foreignPanel = CreateFrame("Frame", nil, UIParent)
local foreignDetailPane = CreateFrame("Frame", nil, foreignPanel)
local foreignLink = CreateFrame("Button", nil, foreignDetailPane)
foreignLink.currentURL = "https://example.com/test-secret"
local hostClick = function() end
foreignLink:SetScript("OnClick", hostClick)
local foreignEntry = {
    name = "Fixture Secret", guideURL = foreignLink.currentURL,
    steps = {
        {
            label = "Faction heading",
            factionSubsteps = {
                alliance = { { label = "Alliance Only" } },
                horde = {
                    { label = "Find the note", waypoint = { mapID = 1, x = 0.30, y = 0.40 } },
                    { label = "Inspect a cache", waypoints = {
                        { mapID = 4, x = 0.1, y = 0.2, label = "Overseas" },
                        { mapID = 1, x = 0.25, y = 0.5, label = "Nearby" },
                        { mapID = 0, x = 10, y = -1 },
                    } },
                },
            },
        },
        { label = "Return the note", note = "Talk to the contact." },
    },
}
SecretChecklist = { entries = { foreignEntry }, guidesPanel = foreignPanel, guidesLinkBtn = true }
fireAddonEvent("ADDON_LOADED", "SecretChecklist")
assert(not SecretsCompassSecretChecklistTrackButton, "An unsupported host layout is ignored")
SecretChecklist.guidesLinkBtn = foreignLink
fireAddonEvent("ADDON_LOADED", "SecretChecklist")
local trackSecret = assert(SecretsCompassSecretChecklistTrackButton, "Late host load adds the companion button")
fireAddonEvent("PLAYER_LOGIN")
assert(SecretsCompassSecretChecklistTrackButton == trackSecret and trackSecret:GetParent() == foreignDetailPane
    and trackSecret:GetText() == "Track Secret")
assert(foreignLink:GetScript("OnClick") == hostClick, "Companion keeps the host click action intact")
waypoint = { uiMapID = 2, position = { x = 300, y = 0 } }
local savedPin = waypoint
click(trackSecret)
assert(secrets.routeTitle:GetText() == "Fixture Secret" and secrets.stepTitle:GetText() ~= "Find the note",
    "Imported solutions remain hidden in Clue mode")
click(secrets.controls.revealFull)
assert(secrets.stepTitle:GetText() == "Find the note")
assert(#SecretCompassSecretDB.route.steps == 3 and waypoint == savedPin)
foreignEntry.steps[1].factionSubsteps.horde[1].label = "Upstream changed text"
assert(SecretCompassSecretDB.route.steps[1].title == "Find the note", "Active route owns a snapshot")
foreignLink.currentURL = "https://example.com/unknown"
click(trackSecret)
assert(secrets.routeTitle:GetText() == "Fixture Secret" and SecretCompassSecretDB.index == 1)
click(secrets.controls.next)
advance()
assert(secrets.controls.location:IsVisible() and not marker:IsVisible(),
    "Cross-continent step keeps instructions without an invalid compass bearing")
click(mapCommand)
assert(mapInput:GetText() == "/mappin 4 10.00 20.00")
click(secrets.controls.location)
assert(not mapInput:IsVisible() and not mapInput.focused and mapInput:GetText() == "",
    "Cycling a location clears the previous command")
click(mapCommand)
assert(mapInput:GetText() == "/mappin 1 25.00 50.00" and waypoint == savedPin,
    "Command follows the newly selected waypoint")
advance()
assert(marker:IsVisible() and SecretCompassSecretDB.locationIndex == 2)
click(secrets.controls.stop)
foreignLink.currentURL = foreignEntry.guideURL
click(trackSecret)
advance()
assert(marker:IsVisible() and SecretCompassSecretDB.index == 2 and SecretCompassSecretDB.locationIndex == 2,
    "Reopening a SecretChecklist guide resumes its selected location")
click(secrets.controls.next)
advance()
assert(secrets.stepTitle:GetText() == "Return the note" and not marker:IsVisible())
assert(secrets.controls.next:GetText() == "Finish")
slash("next")
advance()
assert(not SecretCompassSecretDB.route and waypoint == savedPin and marker:IsVisible()
    and not marker.labels[1]:GetText():find("Secret", 1, true), "Finishing restores normal waypoint rendering")

local cozy = namespace.StandaloneSecrets()[1]
local importedCozy = {
    name = "Cozy Sleeping Bag", questID = 79976, guideURL = cozy.sourceURL,
    steps = {
        {
            label = "Start",
            note = "Visit both locations.",
            factionSubsteps = { horde = {
                {label = "First", questIDs = {79008, 79007}, waypoint = cozy.steps[1].waypoints[1]},
                {label = "Second", questIDs = {79008, 79007}, waypoint = cozy.steps[2].waypoints[1]},
            }},
        },
        {label = "Camp", questID = 79192, waypoint = cozy.steps[3].waypoints[1]},
        {label = "Rekindle", questID = 80001},
        {label = "Mound", questID = 79980, waypoint = cozy.steps[4].waypoints[1]},
    },
}
SecretChecklist.entries = {importedCozy}
foreignLink.currentURL = importedCozy.guideURL
completionFlags[79007], completionFlags[79192] = true, true
click(trackSecret)
assert(SecretCompassSecretDB.route.steps[5].optional and secrets.controls.suggested:IsVisible())
click(secrets.controls.suggested)
assert(SecretCompassSecretDB.index == 6, "Required suggestions pass over the verified optional Rekindle step")
click(secrets.controls.previous)
assert(SecretCompassSecretDB.index == 5, "Optional steps remain manually selectable")
click(secrets.controls.stop)
completionFlags[79007], completionFlags[79192] = nil, nil

local longSteps = {}
for index = 1, 128 do longSteps[index] = {label = "Step " .. index} end
foreignLink.currentURL = "https://example.com/long-guide"
SecretChecklist.entries = {{name = "Long Guide", guideURL = foreignLink.currentURL, steps = longSteps}}
click(trackSecret)
edit:SetText("1289")
assert(not go.enabled and SecretCompassSecretDB.index == 1, "Overlong input is never truncated to a valid step")
edit:SetText("128")
click(go)
assert(SecretCompassSecretDB.index == 128 and secrets.controls.next:GetText() == "Finish",
    "The picker reaches the highest supported step, without finishing")
click(secrets.controls.stop)
assert(not edit:IsVisible() and not edit.focused and not go:IsVisible())
slash("step 2")
assert(not SecretCompassSecretDB.route, "Slash jump is ignored with no active route")

local state = {}
local huntTracker = namespace.CreateSecretTracker(state, function() end)
local routeOne = {
    id = "fixture:hunt", title = "Hunt",
    steps = {
        { title = "First secret", clue = "Look for a lead.", travelHint = "Use the north entrance.",
            completionQuestID = 401, completionOnAccept = true },
        { title = "Second secret", completionQuestID = 402 },
        { title = "Unverified puzzle" },
        { title = "Last secret", completionQuestID = 404 },
    },
}
local routeTwo = { id = "fixture:different", title = "Another", steps = {{title = "A clue"}} }
assert(huntTracker:Track(routeOne) and huntTracker:GetReveal() == "clue")
assert(huntTracker:SetReveal("distance") and huntTracker:GetReveal() == "distance")
assert(huntTracker:SetReveal("coordinates") and huntTracker:GetReveal() == "coordinates")
assert(huntTracker:SetReveal("full") and huntTracker:GetReveal() == "full")
assert(huntTracker:SetReveal("invalid") == false)
assert(huntTracker:Track(routeTwo) and huntTracker:GetReveal() == "clue")
assert(huntTracker:Stop() and huntTracker:Track(routeOne) and huntTracker:GetReveal() == "full")
local loadedTracker = namespace.CreateSecretTracker(state, function() end)
assert(loadedTracker:GetReveal() == "full", "Reveal mode survives reload")
local firstStep = loadedTracker:GetCurrentStep()
assert(firstStep.clue == "Look for a lead." and firstStep.travelHint == "Use the north entrance.")
completionFlags[401], completionFlags[402], completionFlags[404] = secret, true, true
assert(loadedTracker:GetSuggestedStep() == nil, "Protected flags cannot substantiate progress")
completionFlags[401], acceptedQuests[401] = false, true
assert(loadedTracker:GetSuggestedStep() == 3, "Only the verified prefix counts")
local _, beforeSuggestion = loadedTracker:GetRoute()
assert(beforeSuggestion == 1, "Checking progress never advances")
assert(loadedTracker:Jump(3) and not loadedTracker:Jump(8))
assert(loadedTracker:Step(-1), "The suggested step can be manually overridden")

local saved = {}
local tracker = namespace.CreateSecretTracker(saved, function() end)
local firstLocation = {mapID = 1436, x = 0.30, y = 0.40}
local secondLocation = {mapID = 1436, x = 0.50, y = 0.60}
local beginStep = {title = "Begin"}
local pickStep = {title = "Investigate", completionQuestID = 654, waypoints = {firstLocation, secondLocation}}
local endStep = {title = "Complete"}
local route = {id = "fixture:checkpoints", title = "Route A", sourceURL = "https://example.com/route",
    steps = {beginStep, pickStep, endStep}}
local another = {id = "fixture:checkpoints-other", title = "Route B", steps = {beginStep, endStep}}
assert(tracker:Track(route) and tracker:Step(1) and tracker:CycleLocation())
assert(not tracker:Track({id = "bad"}), "An invalid switch leaves the active route intact")
local _, keptIndex, keptLocation = tracker:GetRoute()
assert(keptIndex == 2 and keptLocation == 2)
assert(tracker:Track(another) and tracker:Step(1) and tracker:Stop())
local restored = namespace.CreateSecretTracker(saved, function() end)
local index, location = restored:GetResumeStep(route)
assert(index == 2 and location == 2, "Switching saves a separate checkpoint across reload")
local otherIndex = restored:GetResumeStep(another)
assert(otherIndex == 2, "Pausing another route saves independently")
assert(restored:Track(route) and restored:GetCurrentStep().title == pickStep.title)
local _, selected = restored:GetCurrentStep()
assert(selected.x == secondLocation.x, "Repeat selection restores the waypoint")
local moved = {id = route.id, title = route.title, sourceURL = route.sourceURL,
    steps = {beginStep, endStep,
        {title = pickStep.title, completionQuestID = 654, waypoints = {secondLocation, firstLocation}}}}
assert(restored:Track(moved), "A guide can refresh while active")
local _, newIndex, newLocation = restored:GetRoute()
assert(newIndex == 3 and newLocation == 1, "Active guide reorders preserve the uniquely matching step and point")
assert(restored:Stop() and restored:Track(route))
local _, originalIndex, originalLocation = restored:GetRoute()
assert(originalIndex == 2 and originalLocation == 2, "Paused guide reorders preserve the same step and location")
assert(restored:Stop())
local changed = {id = route.id, title = route.title, sourceURL = "https://example.com/updated", steps = route.steps}
assert(restored:GetResumeStep(changed) == nil, "A changed guide source cannot claim an old checkpoint")
local duplicate = {id = route.id, title = route.title, sourceURL = route.sourceURL, steps = {pickStep, pickStep}}
assert(restored:GetResumeStep(duplicate) == nil, "Duplicate step titles and quest identities are ambiguous")
assert(restored:Track(moved) and restored:Finish() and restored:GetResumeStep(moved) == nil)
assert(restored:HasFinished(moved) and not restored:HasFinished(changed),
    "Completion belongs to the original guide source")
assert(namespace.CreateSecretTracker(saved, function() end):HasFinished(moved),
    "Completion survives a new tracker on the same character")
assert(not namespace.CreateSecretTracker({}, function() end):HasFinished(moved),
    "Another character does not inherit completion")
assert(restored:Track(moved))
local _, replayIndex = restored:GetRoute()
assert(replayIndex == 1 and restored:GetResumeStep(another) == 2, "Finish resets only the completed route")

local invalidState = {checkpoints = {
    [route.id] = {sourceURL = route.sourceURL, stepTitle = false},
    [another.id] = {sourceURL = false, stepTitle = "Complete"},
}}
local sanitized = namespace.CreateSecretTracker(invalidState, function() end)
assert(sanitized:GetResumeStep(route) == nil and sanitized:GetResumeStep(another) == nil
    and next(invalidState.checkpoints) == nil, "Malformed saved checkpoints are filtered")

print("SecretsCompass mocks passed: tracking, crowded labels, HUD controls, standalone secrets, spoiler levels, verified progress, and the SecretChecklist companion")
