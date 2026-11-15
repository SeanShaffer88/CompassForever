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
function methods:GetNumPoints() return self.point and 1 or 0 end
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
function methods:HasFocus() return self.focused == true end
function methods:GetText() return self.text end
function methods:SetStartPoint(...) self.start = { ... } end
function methods:SetEndPoint(...) self.finish = { ... } end
function methods:CreateLine()
    local line = region(self)
    self.lines[#self.lines + 1] = line
    return line
end
function methods:CreateTexture(_name, layer, _template, sublevel)
    local texture = region(self)
    texture.drawLayer, texture.sublevel = layer, sublevel
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
end
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
    "SetOrientation", "SetObeyStepOnDrag", "SetFontString", "SetMaxLetters", "SetTextInsets",
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
local cursorX, cursorY, minimapShape, controlDown = 640, 360, "ROUND", false
function GetCursorPosition() return cursorX, cursorY end
function GetMinimapShape() return minimapShape end
function IsControlKeyDown() return controlDown end
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
local facing, waypoint, unavailable, playerSamples
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

local currentMap, playerX, playerY = 1, 0, 0
local function unexpectedTracking()
    error("SecretsCompass must not query watched quests or player map pins")
end
C_QuestLog = {
    GetNumQuestWatches = unexpectedTracking,
    GetQuestIDForQuestWatchIndex = unexpectedTracking,
    GetQuestsOnMap = unexpectedTracking,
    GetNextWaypoint = unexpectedTracking,
    IsComplete = unexpectedTracking,
}
GetQuestUiMapID = unexpectedTracking
C_SuperTrack = { GetSuperTrackedQuestID = unexpectedTracking }
C_Map = {
    GetUserWaypoint = unexpectedTracking,
    SetUserWaypoint = function() error("Routes must preserve the player's map pin") end,
    ClearUserWaypoint = function() error("Routes must not clear the player's map pin") end,
    GetMapInfo = function(id) return { name = "Test Map " .. id } end,
    GetBestMapForUnit = function(unit) assert(unit == "player"); return currentMap end,
    GetPlayerMapPosition = function(mapID, unit)
        assert(mapID == currentMap and unit == "player")
        playerSamples = playerSamples + 1
        if not unavailable then return CreateVector2D(playerX, playerY) end
    end,
    GetWorldPosFromMapPos = function(mapID, position)
        assert(type(position.GetXY) == 'function', 'Expected a Vector2D mixin')
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
assert(loadfile(addonPath .. "/WaypointNavigation.lua"))("SecretsCompass", namespace)
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

local createTracker = namespace.CreateSecretTracker
local tracker
namespace.CreateSecretTracker = function(...)
    tracker = createTracker(...)
    return tracker
end

ForeverCompassDB = {
    x = 0, y = 88, theme = "unknown", style = "bogus", opacity = "mistyped",
    showQuests = true, showWaypoint = true,
}
waypoint = { uiMapID = 2, position = { x = 300, y = 0 } }
SecretCompassSecretDB = {
    route = { id = "login-fixture", title = "Saved Secret", steps = {
        { title = "Find the lead", waypoints = {{ mapID = 1, x = 0.24, y = 0 }} },
    } },
    index = 1,
    reveals = { ["login-fixture"] = "distance" },
}
event("ADDON_LOADED", "SecretsCompass")
assert(next(SecretCompassSecretDB.collapsedCategories) == nil, "Legacy saves start with all journal categories expanded")
event("PLAYER_ENTERING_WORLD")
advance()
assert(frame:IsVisible() and marker:IsVisible() and marker.labels[1].text == "Secret 240 yd",
    "A saved active secret restores its bearing and reveal level on login")
tracker:Stop()
local idleSamples = playerSamples
advance()
assert(not frame:IsVisible() and not marker:IsVisible() and not frame.scripts.OnUpdate
    and playerSamples == idleSamples,
    "An enabled HUD stays idle with a player pin and legacy tracking options but no secret")assert(not SecretsCompassQuest1 and not frame.events.USER_WAYPOINT_UPDATED
    and not frame.events.QUEST_WATCH_LIST_CHANGED and ForeverCompassDB.showQuests == nil
    and ForeverCompassDB.showWaypoint == nil, "Obsolete tracking controls and events are removed")
assert(SLASH_SECRETSCOMPASS1 == "/secretscompass" and SLASH_SECRETSCOMPASS2 == "/secretcompass"
    and SLASH_SECRETSCOMPASS3 == "/fcompass", "The renamed addon preserves its old slash aliases")
local slash = assert(SlashCmdList.SECRETSCOMPASS)

do
    local positions = {{0.8, 0.5}, {0.5, 0.2}, {0.2, 0.5}, {0.5, 0.8},
        {0.8, 0.4}, {0.8, 0.6}, {0.2, 0.35}, {0.2, 0.65}, {0.5, 0.5}}
    local points = {}
    for index, position in ipairs(positions) do
        points[index] = { mapID = 1, x = position[1], y = position[2] }
    end
    points[#points + 1] = { mapID = 4, x = 0.8, y = 0.5 }
    playerX, playerY = 0.5, 0.5
    assert(tracker:Track({ id = "bearing-fixture", title = "Bearing Fixture", steps = {
        { title = "Follow the bearing", waypoints = points },
    } }))
    tracker:SetReveal("distance")
    assert(frame:IsVisible() and heading:IsVisible() and marker:IsVisible(), "Starting a secret activates the HUD")
    assert(math.abs(labelX("N")) < 0.01, "North centered")
    facing = -math.rad(10)
    advance()
    assert(labelX("N") < 0, "Clockwise movement shifts North left")
    facing = math.rad(10)
    advance()
    assert(labelX("N") > 0, "Counterclockwise movement shifts North right across wrap")

    for index, bearing in ipairs({ {0, "N"}, {-math.pi / 2, "E"}, {math.pi, "S"}, {math.pi / 2, "W"} }) do
        facing = bearing[1]
        if index > 1 then tracker:CycleLocation() end
        advance()
        assert(math.abs(labelX(bearing[2])) < 0.01, "Cardinal centering")
        assert(marker:IsVisible() and marker.labels[1].text == "Secret 300 yd", "Correct secret distance and bearing")
    end
    facing = 0
    tracker:CycleLocation()
    local eastX = assert(marker.point)[4]
    tracker:CycleLocation()
    assert(eastX > marker.point[4], "An eastern secret appears right of a western secret")
    tracker:CycleLocation()
    assert(marker.labels[1].text:match(" >$") and marker.labels[1].point[1] == "RIGHT",
        "The right-edge cue and label face inward")
    tracker:CycleLocation()
    assert(marker.labels[1].text:match("^< "), "The left-edge cue is visible")
    tracker:CycleLocation()
    assert(marker.labels[1].text == "Secret 0 yd" and marker.point[4] == 0, "Arrival stays centered")
    tracker:CycleLocation()
    assert(not marker:IsVisible() and heading:IsVisible(), "Cross-continent locations hide the marker")
    tracker:CycleLocation()
    unavailable = true
    advance()
    assert(not marker:IsVisible() and heading:IsVisible(), "Missing player position only hides the marker")
    unavailable = false
    advance()
    assert(marker:IsVisible(), "The marker recovers with player position")

    facing = secret
    advance()
    assert(not heading:IsVisible() and not marker:IsVisible(), "Unreadable facing hides moving layers")
    facing = nil
    advance()
    assert(not heading:IsVisible(), "Missing facing hides heading")
    facing = 0
    advance()
    assert(heading:IsVisible() and marker:IsVisible(), "Heading recovers with the marker")
    slash("toggle")
    assert(not frame:IsVisible() and not frame.scripts.OnUpdate and ForeverCompassDB.enabled == false,
        "Disabling an active secret's HUD stops updates")
    slash("toggle")
    assert(frame:IsVisible() and ForeverCompassDB.enabled == true, "The active secret's HUD can be restored")

    tracker:Stop()
    tracker:SetReveal("clue")
    playerX, playerY = 0, 0
    local lastSampleCount = playerSamples
    advance()
    assert(not frame:IsVisible() and not marker:IsVisible() and not frame.scripts.OnUpdate
        and playerSamples == lastSampleCount, "Pausing the secret stops live HUD updates")
end

slash("toggle")
slash("move")
assert(frame:IsVisible() and frame.mouseEnabled and not marker:IsVisible() and not ForeverCompassDB.enabled,
    "Move previews the idle HUD without changing its saved visibility")
frame.scripts.OnDragStart(frame)
frame.centerX, frame.centerY = 715, 404
frame.scripts.OnDragStop(frame)
assert(ForeverCompassDB.x == 75 and ForeverCompassDB.y == 44, "Dragged position persists")
slash("move")
assert(not frame.mouseEnabled and not frame:IsVisible() and not ForeverCompassDB.enabled,
    "Locking the idle HUD hides the placement preview and preserves the preference")
slash("toggle")
slash("reset")
assert(ForeverCompassDB.x == 0 and ForeverCompassDB.y == 88, "Reset restores default position")
local function click(control, button)
    local handler = assert(control.scripts.OnClick, "Expected click handler")
    handler(control, button or "LeftButton")
end

assert(ForeverCompassDB.theme == nil and ForeverCompassDB.style == "arc"
    and ForeverCompassDB.opacity == 1, "Old settings are normalized with Classic defaults")
assert(not SecretsCompassMinimapButton, "Wait until login to discover optional minimap libraries")
event("PLAYER_LOGIN")
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
local savedHUD = ForeverCompassDB.enabled
click(minimapButton)
local launcherJournal = assert(SecretsCompassSecrets)
assert(launcherJournal:IsVisible() and not frame:IsVisible() and ForeverCompassDB.enabled == savedHUD,
    "Left click opens Secrets independently of the HUD preference")
click(launcherJournal.controls.close)
controlDown = true
click(minimapButton, "RightButton")
controlDown = false
assert(not SecretsCompassSettings, "Control-right is reserved for button bags")

Minimap:SetScale(0.5)
minimapShape = "SQUARE"
cursorX, cursorY = (640 + 50) * 0.5, (360 + 50) * 0.5
minimapButton.scripts.OnDragStart(minimapButton)
assert(minimapButton.scripts.OnUpdate, "Dragging starts cursor tracking")
minimapButton.scripts.OnUpdate(minimapButton)
local point, relative, relativePoint, offsetX, offsetY = minimapButton:GetPoint()
assert(point == "CENTER" and relative == Minimap and relativePoint == "CENTER"
    and math.abs(offsetX - Minimap:GetWidth() / 2) < 0.001
    and math.abs(offsetY - Minimap:GetHeight() / 2) < 0.001,
    "Scaled square minimap places the button on its edge")
local originalAfter, afterDrag = C_Timer.After
C_Timer.After = function(_, callback) afterDrag = callback end
minimapButton.scripts.OnDragStop(minimapButton)
C_Timer.After = originalAfter
assert(math.abs(ForeverCompassDB.minimap.minimapPos - 45) < 0.001 and not minimapButton.scripts.OnUpdate,
    "The saved angle persists and polling ends")
click(minimapButton)
assert(not launcherJournal:IsVisible(), "Releasing the drag does not open Secrets")
assert(afterDrag, "Drag release only suppresses clicks in the current update")
afterDrag()
click(minimapButton)
assert(launcherJournal:IsVisible(), "A later bag-generated click opens Secrets without mouse down")
click(launcherJournal.controls.close)

minimapButton.scripts.OnDragStart(minimapButton)
minimapButton.scripts.OnHide(minimapButton)
assert(not minimapButton.scripts.OnUpdate, "Hiding ends an active drag")
local nativeAnchor = minimapButton.point
local bagAnchor = region(Minimap)
minimapButton:SetPoint("LEFT", bagAnchor, "RIGHT", 5, 0)
minimapButton.scripts.OnDragStart(minimapButton)
assert(not minimapButton.scripts.OnUpdate and minimapButton.point[2] == bagAnchor,
    "A bag can own the button's anchors without reparenting it")
minimapButton.point, minimapButton.parent = nativeAnchor, bagAnchor
minimapButton.scripts.OnDragStart(minimapButton)
assert(not minimapButton.scripts.OnUpdate and minimapButton.parent == bagAnchor,
    "A bag that owns the parent manages placement")
minimapButton.parent = Minimap
Minimap:SetScale(1)
minimapShape = "ROUND"
minimapButton.scripts.OnMouseDown(minimapButton)
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
do
    local plate = assert(frame.textures[1])
    local previewPlate = panel.preview.stylePlate
    assert(plate:IsShown() and previewPlate:IsShown()
        and plate.drawLayer == "BACKGROUND" and plate.sublevel == -1
        and previewPlate.drawLayer == "BACKGROUND" and previewPlate.sublevel == -1,
        "Framed draws a plate behind both sets of compass ticks")
    local ratio = previewPlate:GetWidth() / plate:GetWidth()
    assert(ratio < 1 and math.abs(previewPlate:GetHeight() - plate:GetHeight() * ratio) < 0.001
        and table.concat(previewPlate.color, ",") == table.concat(plate.color, ","),
        "Framed plate has the same proportions and color in both renderers")
    assert(not frame.lines[20]:IsShown() and not panel.preview.arc[20]:IsShown(),
        "Framed leaves the plate free of a line through its center")

    local ornaments = SecretsCompassStyleDetails.lines
    local previewOrnaments = panel.preview.details
    for index = 1, #ornaments do
        local live, previewDetail = ornaments[index], previewOrnaments[index]
        if live:IsShown() then
            assert(previewDetail:IsShown()
                and math.abs(previewDetail.start[3] - live.start[3] * ratio) < 0.001
                and math.abs(previewDetail.finish[3] - live.finish[3] * ratio) < 0.001
                and math.abs(previewDetail.finish[4] - previewDetail.start[4]
                    - (live.finish[4] - live.start[4]) * ratio) < 0.001
                and table.concat(previewDetail.color, ",") == table.concat(live.color, ","),
                "Framed rails, caps, and caret share geometry and color")
        end
    end
    slash("move")
    facing = -math.rad(109)
    advance()
    assert(math.abs(labelX("N")) < plate:GetWidth() / 2
        and heading.lines[1].start[4] < heading.lines[1].finish[4],
        "The cardinal remains inside the plate while its tick points below the label")
    facing = 0
    slash("move")
    click(controls.styles.tactical)
    assert(not plate:IsShown() and not previewPlate:IsShown(),
        "Switching styles removes the Framed plate in both renderers")
end
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

controls.enabled:SetChecked(false)
click(controls.enabled)
assert(not ForeverCompassDB.enabled and not frame:IsVisible() and panel:IsVisible()
    and minimapButton:IsVisible() and (icon.alpha == nil or icon.alpha == 1),
    "Disabling the HUD leaves the independent minimap launcher fully visible")
controls.enabled:SetChecked(true)
click(controls.enabled)
assert(ForeverCompassDB.enabled and not frame:IsVisible() and panel:IsVisible(),
    "Enabling the HUD without a secret leaves settings available")
assert(not controls.showQuests and not controls.showWaypoint and not controls.test
    and panel.preview.secret:IsVisible() and panel.preview.secret:GetText() == "Secret 240 yd",
    "Settings preview depicts a secret and omits unrelated tracking controls")
controls.showCardinals:SetChecked(false)
click(controls.showCardinals)
for _, label in ipairs(panel.preview.heading) do
    assert(not label:IsVisible(), "Cardinal labels hide")
end
controls.showCardinals:SetChecked(true)
click(controls.showCardinals)
assert(panel.preview.heading[2]:IsVisible(), "Cardinal labels return in the preview")

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
end

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
UIParent:SetHeight(1080)
slash("secrets")
local secrets = assert(SecretsCompassSecrets)
assert(secrets.TitleContainer.TitleText:GetText() == "SecretsCompass Journal"
    and secrets.PortraitContainer.portrait.texture:match("MinimapCompass%.tga$")
    and secrets.controls.close == secrets.CloseButton, "Journal uses its own artwork and the native frame")
local list = namespace.StandaloneSecrets()
local cozyButton = assert(secrets.controls.routes[list[1].id])
local alcazButton = assert(secrets.controls.routes[list[2].id])
assert(secrets:IsVisible() and cozyButton:IsVisible() and alcazButton:IsVisible())
do
    local expected = {
        ["scarlet-banner"] = { {1417, 622, 545}, {1445, 637, 424}, {1435, 168, 538}, {1420, 826, 338} },
        ["musical-gustjumper"] = { {2521, 515, 723} },
        ["night-watchmans-torch"] = { {1431, 287, 333} },
        ["lyn-the-ignored"] = { {1421, 448, 678}, {1421, 634, 643}, {1416, 85, 593} },
        ["dawn-waker-eluviana"] = {
            {2521, 417, 234}, {2521, 476, 719}, {1447, 660, 541}, {2482, 727, 372}, {2521, 583, 245},
        },
        ["excitable-slime"] = { {1458, 555, 641}, {1458, 523, 584}, {1458, 509, 534} },
        ["silver-of-the-waves"] = { {1432, 481, 396}, {1432, 456, 434}, {1432, 489, 543}, {1432, 395, 393} },
        ["applejack-still"] = { {1429, 418, 672}, {1429, 246, 580}, {1429, 241, 732} },
        ["whispering-horror-residue"] = { {1420, 129, 657}, {1458, 491, 146} },
        ["blessing-of-kalimdor"] = {
            {1413, 608, 134}, {1413, 596, 83}, {1413, 586, 75}, {1413, 612, 345},
            {1413, 604, 329}, {1413, 606, 306}, {1413, 621, 333},
        },
        ["travelers-symbols"] = { {1427, 352, 842} },
        ["bloody-map"] = { {1417, 745.4, 356.4}, {1437, 531.7, 656.7}, {1437, 515.3, 593.5}, {1437, 478, 563} },
        ["savory-whimsyfin-delight"] = { {1433, 272, 668}, {1433, 608, 699}, {1433, 619, 706}, {1433, 744, 624} },
        ["malignant-root"] = { {1437, 190, 520}, {1437, 180, 230}, {1437, 290, 170}, {1437, 562, 405} },
        ["dwarven-tradeskill-signpost"] = { {1433, 106, 713}, {1433, 102, 712}, {1455, 524, 425} },
        ["a-taste-of-home"] = { {1416, 185, 657}, {1447, 564, 288} },
        ["orcish-tradeskill-signpost"] = { {1413, 494, 294}, {1413, 498, 294}, {1454, 628, 444} },
        ["fizsprockets-notes"] = {
            {1412, 610, 470}, {1412, 586, 473}, {1412, 590, 464}, {1412, 617, 473}, {1412, 548, 643},
        },
        ["condor-hatchling"] = { {1432, 746, 708}, {1432, 777, 749}, {1432, 747, 669} },
        ["tallstrider-hatchling"] = { {1439, 348, 873}, {1439, 350, 880} },
        ["baby-crocolisk"] = { {1453, 712, 488}, {1453, 711, 680} },
        ["bitter-baitling"] = { {1434, 274, 769}, {1434, 267, 763} },
        ["weevil-k-neevil"] = { {1435, 251, 542}, {1434, 431, 167}, {1417, 310, 263}, {1443, 481, 571} },
        ["gift-of-galloping"] = { {2548, 783, 520} },
        ["manual-scavenger-hunt"] = {
            {1417, 226.9, 241.7}, {1424, 876.1, 479.1}, {1458, 228.6, 361.9},
            {2548, 265.6, 455.8}, {2548, 267.2, 477.4}, {1419, 451.9, 164.7},
            {1449, 521.6, 496.4}, {1449, 524.8, 511.0}, {1434, 144.3, 271.5}, {1453, 672.0, 825.3},
        },
    }
    for _, side in ipairs({ "Horde", "Alliance" }) do
        faction = side
        slash("secrets")
        slash("secrets")
        local choices = namespace.StandaloneSecrets()
        local isAlliance = side == "Alliance"
        local expectedCount = isAlliance and 22 or 21
        assert(#choices == expectedCount
            and secrets.progress:GetText() == ("0 of %d Built-In Routes Finished"):format(expectedCount),
            "Faction-specific additions update the journal count")
        assert(choices[17].id == "condor-hatchling" and choices[18].id == "tallstrider-hatchling"
            and (not isAlliance or choices[19].id == "baby-crocolisk"), "The existing pet routes keep their slots")
        local bitter, weevil, gift = choices[expectedCount - 2], choices[expectedCount - 1], choices[expectedCount]
        assert(bitter.id == "bitter-baitling" and #bitter.steps == 3 and #bitter.steps[1].waypoints == 0
            and weevil.id == "weevil-k-neevil" and #weevil.steps == 5
            and gift.id == "gift-of-galloping" and #gift.steps == 1,
            "Both factions get all three new routes after the existing catalog")
        local weevilStart, weevilEnd = weevil.steps[1].waypoints[1], weevil.steps[5].waypoints[1]
        assert(weevilStart.mapID == weevilEnd.mapID and weevilStart.x == weevilEnd.x and weevilStart.y == weevilEnd.y,
            "The specimen route returns to Amaryllis Webb")
        assert(choices[11].id == "blessing-of-kalimdor" and choices[12].id == "travelers-symbols",
            "Both factions keep their existing Barrens and Blackrock routes")
        local symbols = choices[12]
        assert(#symbols.steps == 3 and #symbols.steps[1].waypoints == 1
            and #symbols.steps[2].waypoints == 0 and #symbols.steps[3].waypoints == 0,
            "Traveler's Symbols has an outdoor approach and written directions inside the dungeon")
        local whimsyfin = choices[isAlliance and 13 or 14]
        assert(whimsyfin.id == "savory-whimsyfin-delight" and #whimsyfin.steps == 3
            and #whimsyfin.steps[1].waypoints == 1 and #whimsyfin.steps[2].waypoints == 3
            and #whimsyfin.steps[3].waypoints == 0,
            "Both factions get the recipe, fishing alternatives, and a text-only cooking step")
        for index = 11, #choices do
            for _, step in ipairs(choices[index].steps) do
                assert(not step.completionQuestID, "New routes advance manually")
            end
        end
        if isAlliance then
            assert(choices[9].id == "silver-of-the-waves" and choices[10].id == "applejack-still"
                and not secrets.controls.routes["excitable-slime"]:IsVisible()
                and not secrets.controls.routes["whispering-horror-residue"]:IsVisible()
                and not secrets.controls.routes["bloody-map"]:IsVisible(),
                "Alliance receives Silver of the Waves and Applejack Still")
            local root = choices[14]
            local signpost = choices[15]
            local wine = choices[16]
            assert(root.id == "malignant-root" and #root.steps == 2 and #root.steps[1].waypoints == 3
                and #root.steps[2].waypoints == 1
                and signpost.id == "dwarven-tradeskill-signpost" and #signpost.steps == 3
                and wine.id == "a-taste-of-home" and #wine.steps == 3,
                "Alliance keeps its route order and receives A Taste of Home")
            assert(not secrets.controls.routes["orcish-tradeskill-signpost"]:IsVisible()
                and not secrets.controls.routes["fizsprockets-notes"]:IsVisible(),
                "Alliance cannot see the new Horde routes")
        else
            assert(choices[9].id == "excitable-slime" and choices[10].id == "whispering-horror-residue",
                "Horde receives Excitable Slime and Whispering Horror Residue")
            local bloodyMap = choices[13]
            assert(bloodyMap.id == "bloody-map" and bloodyMap.ongoing and #bloodyMap.steps == 6
                and #bloodyMap.steps[6].waypoints == 0
                and bloodyMap.steps[3].waypoints[1].x == bloodyMap.steps[5].waypoints[1].x
                and bloodyMap.steps[3].waypoints[1].y == bloodyMap.steps[5].waypoints[1].y,
                "The Horde route returns to the same agent before reaching a text-only checkpoint")
            assert(choices[15].id == "orcish-tradeskill-signpost" and #choices[15].steps == 3
                and choices[16].id == "fizsprockets-notes" and #choices[16].steps == 5,
                "Horde receives the signpost and mine routes after the existing routes")
        end
        local lastRow = secrets.controls.routes[isAlliance and "silver-of-the-waves" or "whispering-horror-residue"]
        local _, _, rowY = lastRow:GetPoint()
        assert(secrets:GetHeight() == (isAlliance and 1031 or 1001)
            and not secrets.controls.routePageNext:IsVisible()
            and 26 - rowY + lastRow:GetHeight() <= secrets:GetHeight() - 15,
            "The last route row fits above navigation")
        for i = 3, #choices do
            local choice = choices[i]
            assert(choice.sourceURL and secrets.controls.routes[choice.id]:IsVisible(),
                "Every added route has a source and appears in the standalone journal")
            for _, point in ipairs(assert(expected[choice.id], "Unexpected built-in route ID")) do
                local found
                for _, step in ipairs(choice.steps) do
                    for _, pin in ipairs(step.waypoints) do
                        if pin.mapID == point[1] and math.abs(pin.x - point[2] / 1000) < 0.00001
                            and math.abs(pin.y - point[3] / 1000) < 0.00001 then
                            found = true
                        end
                    end
                end
                assert(found, ("Missing source-checked point for %s"):format(choice.title))
            end
        end
        assert(#choices[3].steps[5].waypoints == 0 and #choices[6].steps[4].waypoints == 0,
            "Interior puzzle and summon steps have landmark instructions")
        assert(#choices[5].steps[1].waypoints == 9 and #choices[7].steps[4].waypoints == 5,
            "Spawn alternatives stay in the same step")
        local manual = choices[8]
        assert(manual.id == "manual-scavenger-hunt" and manual.ongoing and #manual.steps == 11,
            "The Manual Scavenger Hunt is an ongoing standalone route for either faction")
        for index = 1, 5 do
            assert(manual.steps[index].clue:lower():find("last known", 1, true),
                "Historical status is visible without spoiling the location")
            for _, pin in ipairs(manual.steps[index].waypoints) do
                assert(pin.label:lower():find("last known", 1, true),
                    "Historical waypoints are labeled Last Known")
            end
        end
        for _, index in ipairs({ 6, 8, 9 }) do
            assert(#manual.steps[index].waypoints == 0, "Displaced side clues have no active map targets")
        end
        assert(#manual.steps[11].waypoints == 0 and manual.steps[11].title == "Unresolved Clues",
            "Unsolved fragments have no invented waypoint")
        local dawn = choices[7]
        local total = isAlliance and 23 or 22
        assert(dawn.ongoing and #dawn.steps == total
            and dawn.steps[6].waypoints[1].mapID == (isAlliance and 1439 or 1440),
            "Dawn Waker follows the appropriate water globe branch")
        assert(dawn.steps[total - 1].waypoints[1].mapID == 2521
            and dawn.steps[total].title == "Trail Goes Cold" and #dawn.steps[total].waypoints == 0,
            "The route reaches the Altairus ritual and ends without an unverified waypoint")
        local legacy = namespace.CreateSecretTracker({
            finishedRoutes = { [dawn.id] = { sourceURL = dawn.sourceURL } },
        }, function() end)
        assert(not legacy:HasFinished(dawn) and legacy:GetResumeStep(dawn) == 6 and legacy:Track(dawn),
            "The previous Eluvi'ana finish is a resume point")
        local _, resume = legacy:GetRoute()
        assert(resume == 6 and legacy:Jump(total) and not legacy:Finish() and legacy:Stop()
            and legacy:GetResumeStep(dawn) == total, "Explicit pauses take precedence over legacy chapter progress")
    end
    local slime = secrets.controls.routes["excitable-slime"]
    click(slime)
    click(secrets.controls.routes["bloody-map"])
    click(secrets.controls.routes["orcish-tradeskill-signpost"])
    click(secrets.controls.routes["fizsprockets-notes"])
    assert(not SecretCompassSecretDB.route, "A stale Horde route row cannot start on Alliance")

    local wine = secrets.controls.routes["a-taste-of-home"]
    click(wine)
    assert(secrets.routeTitle:GetText() == "A Taste of Home"
        and not secrets.controls.mapCommand:IsVisible(), "Alliance can open the Dalaran route with clues only")
    click(secrets.controls.revealCoordinates)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1416 18.50 65.70",
        "The Dalaran bartender waypoint can be copied")
    click(secrets.controls.next)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1447 56.40 28.80",
        "Next leads to the Azshara wine search area")
    click(secrets.controls.next)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1416 18.50 65.70",
        "The third step returns to the Dalaran bartender")
    click(secrets.controls.stop)

    click(secrets.controls.routes["blessing-of-kalimdor"])
    assert(secrets.routeTitle:GetText() == "Blessing of Kalimdor" and not secrets.controls.mapCommand:IsVisible(),
        "Alliance can start the Barrens hunt with clues only")
    click(secrets.controls.revealCoordinates)
    click(secrets.controls.location)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1413 59.60 8.30",
        "Next Location selects an alternate Takk patrol search point")
    click(secrets.controls.next)
    click(secrets.controls.location)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1413 60.40 32.90",
        "Next Location selects an alternate Swiftmane patrol search point")
    click(secrets.controls.stop)

    local silver = secrets.controls.routes["silver-of-the-waves"]
    click(silver)
    assert(secrets.routeTitle:GetText() == "Silver of the Waves" and not secrets.controls.mapCommand:IsVisible(),
        "Alliance can open the toolbox route with clues only")
    click(secrets.controls.revealCoordinates)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1432 48.10 39.60",
        "The first toolbox search site can be copied")
    click(secrets.controls.location)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1432 45.60 43.40",
        "Next Location cycles to another toolbox search site")
    click(secrets.controls.location)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1432 48.90 54.30",
        "Next Location reaches the southern toolbox site")
    click(secrets.controls.next)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1432 39.50 39.30",
        "Next advances from toolbox search sites to Khara Deepwater")
    click(secrets.controls.stop)

    faction = "Horde"
    slash("secrets")
    slash("secrets")
    local applejack = secrets.controls.routes["applejack-still"]
    local root = secrets.controls.routes["malignant-root"]
    local signpost = secrets.controls.routes["dwarven-tradeskill-signpost"]
    assert(not applejack:IsVisible() and not silver:IsVisible()
        and not root:IsVisible() and not signpost:IsVisible() and not wine:IsVisible(),
        "Alliance rows are hidden on Horde")
    click(applejack)
    click(root)
    click(signpost)
    click(wine)
    assert(not SecretCompassSecretDB.route, "A stale Alliance route row cannot start on Horde")

    click(secrets.controls.routes["fizsprockets-notes"])
    assert(secrets.routeTitle:GetText() == "Fizsprocket's Notes"
        and not secrets.controls.mapCommand:IsVisible(), "Horde can open the mine route with clues only")
    click(secrets.controls.revealFull)
    slash("step 3")
    assert(secrets.stepTitle:GetText() == "Find One \"Gerenzo\", of Stonetalon",
        "Full mode names the document at the selected mine stop")
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1412 59.00 46.40",
        "The selected mine waypoint can be copied")
    click(secrets.controls.stop)

    click(secrets.controls.routes["savory-whimsyfin-delight"])
    assert(secrets.routeTitle:GetText() == "Savory Whimsyfin Delight" and not secrets.controls.mapCommand:IsVisible(),
        "Horde can open the recipe route with clues only")
    click(secrets.controls.revealCoordinates)
    click(secrets.controls.next)
    click(secrets.controls.location)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1433 61.90 70.60",
        "Next Location selects an alternate Whimsyfin fishing area")
    click(secrets.controls.next)
    assert(secrets.progress:GetText() == "Step 3 of 3"
        and not secrets.controls.location:IsVisible() and not secrets.controls.mapCommand:IsVisible(),
        "The cooking step clears waypoint controls")
    click(secrets.controls.stop)

    click(slime)
    assert(secrets.routeTitle:GetText() == "Excitable Slime" and not secrets.controls.mapCommand:IsVisible(),
        "Horde can open the standalone route with clues only")
    click(secrets.controls.revealCoordinates)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1458 55.50 64.10",
        "The Boyle pin can be copied")
    click(secrets.controls.next)
    click(secrets.controls.location)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1458 50.90 53.40",
        "Next Location cycles the canal search areas")
    click(secrets.controls.stop)

    click(secrets.controls.routes["bloody-map"])
    click(secrets.controls.revealCoordinates)
    slash("step 4")
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1437 47.80 56.30",
        "The Horde route copies the approximate excavation portal")
    slash("step 6")
    click(secrets.controls.revealFull)
    slash("next")
    assert(secrets.stepTitle:GetText() == "Unresolved Destination"
        and secrets.controls.next:GetText() == "Known End" and not secrets.controls.next.enabled
        and not secrets.controls.mapCommand:IsVisible() and SecretCompassSecretDB.index == 6
        and not SecretCompassSecretDB.finishedRoutes["bloody-map"],
        "The unresolved map destination has no waypoint or finish action")
    click(secrets.controls.stop)

    local manual = secrets.controls.routes["manual-scavenger-hunt"]
    click(manual)
    assert(secrets.routeTitle:GetText() == "Manual Scavenger Hunt" and not secrets.controls.mapCommand:IsVisible())
    slash("step 3")
    click(secrets.controls.revealCoordinates)
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 2548 26.56 45.58",
        "Riverglades uses the replacement location instead of Blackrock")
    slash("step 7")
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1434 14.43 27.15",
        "Stranglethorn maps the observed torch at the old cache location")
    slash("step 8")
    assert(not secrets.controls.mapCommand:IsVisible(), "The missing Alterac stash is a text-only lead")
    slash("step 11")
    click(secrets.controls.revealFull)
    slash("next")
    assert(secrets.stepTitle:GetText() == "Unresolved Clues" and not secrets.controls.next.enabled
        and SecretCompassSecretDB.index == 11 and not SecretCompassSecretDB.finishedRoutes["manual-scavenger-hunt"],
        "The unresolved checkpoint preserves the active route")
    click(secrets.controls.stop)

    local torch = secrets.controls.routes["night-watchmans-torch"]
    click(torch)
    assert(SecretCompassSecretDB.index == 1 and secrets.controls.location:IsVisible()
        and not secrets.controls.mapCommand:IsVisible(), "Clue mode keeps spawn coordinates private")
    click(secrets.controls.revealCoordinates)
    for i = 1, 3 do click(secrets.controls.location) end
    click(secrets.controls.mapCommand)
    assert(secrets.controls.mapCommandInput:GetText() == "/mappin 1431 28.70 33.30",
        "The additional Wowhead search spot is reachable from the journal")
    click(secrets.controls.stop)
    click(torch)
    assert(SecretCompassSecretDB.index == 1 and SecretCompassSecretDB.locationIndex == 4,
        "Resuming a standalone route keeps the selected spawn alternative")
    click(secrets.controls.stop)

    local dawn = secrets.controls.routes["dawn-waker-eluviana"]
    click(dawn)
    slash("step 4")
    click(secrets.controls.location)
    local active = SecretCompassSecretDB.route
    active.ongoing, active.legacyResumeStep = nil, nil
    active.title = "Dawn Waker: Eluvi'ana"
    for index = #active.steps, 6, -1 do active.steps[index] = nil end
    fireAddonEvent("PLAYER_ENTERING_WORLD")
    assert(#SecretCompassSecretDB.route.steps == 22 and SecretCompassSecretDB.index == 4
        and SecretCompassSecretDB.locationIndex == 2, "Entering world upgrades the active route snapshot in place")
    slash("step 22")
    assert(secrets.controls.next.enabled == false and secrets.controls.next:GetText() == "Known End"
        and not secrets.controls.mapCommand:IsVisible(), "The cold trail offers no further action or map pin")
    slash("next")
    click(secrets.controls.revealFull)
    assert(SecretCompassSecretDB.index == 22 and secrets.stepTitle:GetText() == "Trail Goes Cold"
        and not SecretCompassSecretDB.finishedRoutes["dawn-waker-eluviana"],
        "The Next binding cannot finish the ongoing route")
    click(secrets.controls.stop)
end
do
    local controls = secrets.controls
    local previousPage, nextPage, range = controls.routePagePrevious, controls.routePageNext, controls.routePageRange
    local function assertNavigationPosition()
        local anchor, navigationX, navigationY = controls.navigation:GetPoint()
        local _, statusX, statusY = secrets.navigationStatus:GetPoint()
        local _, _, titleY = secrets.routeTitle:GetPoint()
        assert(controls.navigation:IsVisible() and anchor == "TOPLEFT"
            and navigationY - controls.navigation:GetHeight() > titleY
            and statusX + secrets.navigationStatus:GetWidth() < navigationX
            and statusY - secrets.navigationStatus:GetHeight() >= titleY,
            "Navigation and its status sit above the route title without overlap")
    end
    local function displayOrder(isAlliance)
        local order = {
            { "Pets", {
                isAlliance and "baby-crocolisk" or "bitter-baitling",
                isAlliance and "bitter-baitling" or "condor-hatchling",
                isAlliance and "condor-hatchling" or "excitable-slime",
                "musical-gustjumper", "tallstrider-hatchling", "weevil-k-neevil",
            } },
            { "Toys & Collectibles", isAlliance
                and { "a-taste-of-home", "alcaz-operative-insignia:alliance", "night-watchmans-torch",
                    "scarlet-banner", "travelers-symbols" }
                or { "alcaz-operative-insignia:horde", "night-watchmans-torch", "scarlet-banner", "travelers-symbols" },
            },
            { "Gear & Utility", { "blessing-of-kalimdor",
                "cozy-sleeping-bag:" .. (isAlliance and "alliance" or "horde"),
                "gift-of-galloping", isAlliance and "malignant-root" or nil,
            } },
            { "Professions", { isAlliance and "dwarven-tradeskill-signpost" or "orcish-tradeskill-signpost",
                "savory-whimsyfin-delight",
            } },
            { "Quests & Mysteries", isAlliance
                and { "applejack-still", "dawn-waker-eluviana", "lyn-the-ignored", "manual-scavenger-hunt",
                    "silver-of-the-waves" }
                or { "dawn-waker-eluviana", "fizsprockets-notes", "lyn-the-ignored", "manual-scavenger-hunt",
                    "bloody-map", "whispering-horror-residue" },
            },
        }
        local choices = {}
        for _, group in ipairs(order) do
            for _, id in ipairs(group[2]) do
                choices[#choices + 1] = { id = id, heading = group[1] }
            end
        end
        return choices
    end
    local choices = displayOrder(false)
    local lateRoute = assert(controls.routes["whispering-horror-residue"])
    local function assertPage(first, last, height)
        assert(secrets:GetHeight() == height and previousPage:IsVisible() and nextPage:IsVisible() and range:IsVisible(),
            "Only an overflowing catalog shows the pager")
        assert(range:GetText() == ("%d–%d of %d"):format(first, last, #choices),
            "The pager counts routes without category headings")
        assert(previousPage.enabled == (first > 1) and nextPage.enabled == (last < #choices),
            "Page controls stop at the first and last pages")
        local headings, previousBottom = {}, nil
        for index, route in ipairs(choices) do
            local row = controls.routes[route.id]
            assert(row:IsVisible() == (index >= first and index <= last), "Only this page's routes are visible")
            if row:IsVisible() then
                local _, _, rowY = row:GetPoint()
                if not headings[route.heading] then
                    local heading = assert(controls.routeHeadings[route.heading])
                    local _, _, headingY = heading:GetPoint()
                    assert(heading:GetText() == "-  " .. route.heading:upper() and headingY - heading:GetHeight() >= rowY
                        and (not previousBottom or previousBottom >= headingY), "Category heading sits above its first route")
                    headings[route.heading] = true
                end
                assert(not previousBottom or previousBottom >= rowY, "Routes are alphabetical within each category")
                previousBottom = rowY - row:GetHeight()
            end
        end
        for name, heading in pairs(controls.routeHeadings) do
            assert(heading:IsVisible() == not not headings[name], "Each visible heading has a route on the page")
        end
        local _, _, pagerY = nextPage:GetPoint()
        assert(26 - previousBottom <= height - pagerY - nextPage:GetHeight(), "Route rows clear the pager")
    end

    local catalog = namespace.StandaloneSecrets()
    for _, route in ipairs(catalog) do
        if route.id == "whispering-horror-residue" then
            SecretCompassSecretDB.finishedRoutes[route.id] = { sourceURL = route.sourceURL }
        end
    end
    UIParent:SetHeight(720)
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
    assertPage(1, 11, 683)
    assert(secrets.progress:GetText() == "1 of 21 Built-In Routes Finished",
        "Completion includes finished routes off the current page")
    SecretCompassSecretDB.finishedRoutes["whispering-horror-residue"] = nil
    click(nextPage)
    assertPage(12, 21, 683)
    click(lateRoute)
    assert(secrets.routeTitle:GetText() == "Whispering Horror Residue" and not range:IsVisible()
        and not previousPage:IsVisible() and not nextPage:IsVisible() and not lateRoute:IsVisible(),
        "Tracking a route from a later page hides the catalog and pager")
    for _, heading in pairs(controls.routeHeadings) do
        assert(not heading:IsVisible(), "Tracking hides category headings")
    end
    click(controls.stop)
    assertPage(12, 21, 683)
    click(previousPage)
    assertPage(1, 11, 683)

    click(controls.routes["condor-hatchling"])
    click(controls.revealCoordinates)
    click(controls.location)
    click(controls.mapCommand)
    assert(controls.mapCommandInput:GetText() == "/mappin 1432 77.70 74.90",
        "Next Location reaches an alternate Lord Condar search area")
    click(controls.stop)
    assertPage(1, 11, 683)

    click(controls.routes["bitter-baitling"])
    click(controls.revealCoordinates)
    assert(secrets.progress:GetText():match("^Step 1") and not controls.mapCommand:IsVisible(),
        "The contest fishing step gives instructions without a fixed waypoint")
    click(controls.next)
    click(controls.mapCommand)
    assert(controls.mapCommandInput:GetText() == "/mappin 1434 27.40 76.90",
        "Next leads to Riggle Bassbait for the contest turn-in")
    click(controls.next)
    click(controls.mapCommand)
    assert(controls.mapCommandInput:GetText() == "/mappin 1434 26.70 76.30",
        "The final step leads to Jang for the prize exchange")
    click(controls.stop)
    assertPage(1, 11, 683)

    faction = "Alliance"
    choices = displayOrder(true)
    UIParent:SetHeight(480)
    fireAddonEvent("UI_SCALE_CHANGED")
    assertPage(1, 5, 455)
    click(nextPage)
    assertPage(6, 9, 455)
    click(nextPage)
    assertPage(10, 13, 455)
    click(nextPage)
    assertPage(14, 17, 455)
    click(nextPage)
    assertPage(18, 22, 455)
    faction = "Horde"
    choices = displayOrder(false)
    slash("secrets")
    slash("secrets")
    assertPage(18, 21, 455)
    assert(not controls.routes["baby-crocolisk"]:IsVisible(), "The Alliance route stays hidden on the Horde page")
    UIParent:SetHeight(720)
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
    assertPage(12, 21, 683)
    UIParent:SetHeight(1080)
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
    assert(not range:IsVisible() and cozyButton:IsVisible() and lateRoute:IsVisible(),
        "A tall viewport restores the full catalog")
    assertNavigationPosition()

    UIParent:SetHeight(720)
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
    click(nextPage)
    assertPage(12, 21, 683)
    local status = controls.routeStatus
    local _, _, statusY = status:GetPoint()
    local _, _, menuY = controls.routeCategoryMenu:GetPoint()
    assert(status:IsVisible() and status:GetText() == "Status: All"
        and statusY - status:GetHeight() > menuY, "The category menu clears the status control")
    click(controls.routeCategory)
    click(status)
    assert(status:GetText() == "Status: Completed" and controls.routeEmpty:IsVisible()
        and not range:IsVisible() and not controls.routeCategoryMenu:IsVisible()
        and secrets.progress:GetText() == "0 of 21 Built-In Routes Finished",
        "Completed shows an empty result at zero progress and closes the type menu")
    click(status)
    assert(status:GetText() == "Status: Unfinished")
    assertPage(1, 11, 683)
    click(nextPage)
    click(status)
    assert(status:GetText() == "Status: All")
    assertPage(1, 11, 683)
    click(nextPage)
    click(controls.routeExpandAll)
    assertPage(1, 11, 683)
    local search = controls.routeSearch
    search:SetText("   sLiMe  ")
    local slime = controls.routes["excitable-slime"]
    assert(search:IsVisible() and slime:IsVisible() and slime.title:GetText() == "Excitable Slime"
        and slime.action:GetText() == "Resume · Step 2" and not cozyButton:IsVisible() and not range:IsVisible()
        and secrets.progress:GetText() == "0 of 21 Built-In Routes Finished",
        "Trimmed case-insensitive title search resets to page one and keeps the overall route count")
    click(controls.routeCategory)
    assert(controls.routeCategoryMenu:IsVisible(), "Category control opens the menu")
    click(controls.routeCategoryOptions.collectibles)
    assert(not controls.routeCategoryMenu:IsVisible() and not slime:IsVisible()
        and controls.routeEmpty:IsVisible() and controls.routeEmpty:GetText() == "No secrets match your search or category.",
        "Category selection combines with the title search and explains no results")
    click(controls.routeCategory)
    click(controls.routeCategoryOptions.pets)
    assert(slime:IsVisible() and not controls.routeEmpty:IsVisible(), "Changing categories restores a matching route")
    click(status)
    assert(not slime:IsVisible() and controls.routeEmpty:IsVisible(), "Completed excludes the unfinished pet")
    click(status)
    assert(slime:IsVisible() and not cozyButton:IsVisible()
        and search:GetText() == "   sLiMe  " and controls.routeCategory:GetText() == "Pets  v",
        "Status filtering combines with the current title and type")
    local pets = assert(controls.routeHeadings["Pets"])
    local _, _, expandY = controls.routeExpandAll:GetPoint()
    local _, _, petsY = pets:GetPoint()
    assert(expandY - controls.routeExpandAll:GetHeight() > petsY, "The bulk controls clear the first heading")
    local savedCategories = SecretCompassSecretDB.collapsedCategories
    savedCategories["future-category"] = true
    click(controls.routeCategory)
    click(controls.routeCollapseAll)
    for _, key in ipairs({ "pets", "collectibles", "utility", "professions", "mysteries", "other" }) do
        assert(savedCategories[key] == true, "Collapse All updates categories outside the current filter")
    end
    assert(pets:GetText() == "+  PETS" and not slime:IsVisible() and not cozyButton:IsVisible()
        and search:GetText() == "   sLiMe  " and controls.routeCategory:GetText() == "Pets  v"
        and not controls.routeCategoryMenu:IsVisible() and not controls.routeEmpty:IsVisible()
        and secrets.progress:GetText() == "0 of 21 Built-In Routes Finished",
        "Collapse All preserves the search, type filter and progress")
    click(controls.routeExpandAll)
    assert(slime:IsVisible() and not cozyButton:IsVisible() and pets:GetText() == "-  PETS"
        and savedCategories["future-category"] == true and savedCategories.pets == nil
        and savedCategories.utility == nil and savedCategories.other == nil,
        "Expand All restores matching rows and leaves unknown saved categories untouched")
    savedCategories["future-category"] = nil
    click(pets)
    assert(SecretCompassSecretDB.collapsedCategories.pets == true, "Collapsing a heading saves its category key")
    assert(pets:IsVisible() and pets:GetText() == "+  PETS" and not slime:IsVisible()
        and not controls.routeEmpty:IsVisible(),
        "A collapsed category stays visible with matching results and hides its route rows")
    search:SetText("gust")
    local gustjumper = controls.routes["musical-gustjumper"]
    assert(pets:IsVisible() and not gustjumper:IsVisible(), "Changing search preserves the category's collapse state")
    click(pets)
    assert(SecretCompassSecretDB.collapsedCategories.pets == nil, "Expanding a heading clears its saved key")
    assert(pets:GetText() == "-  PETS" and gustjumper:IsVisible() and not slime:IsVisible(),
        "Expanding a category restores only the routes matching the current search")
    search:SetText("[")
    assert(controls.routeEmpty:IsVisible() and not slime:IsVisible(), "Search handles pattern characters literally")
    search:SetText("slime")
    search:SetFocus()
    click(slime)
    assert(not search:IsVisible() and not search:HasFocus() and not controls.routeCategory:IsVisible()
        and not controls.routeExpandAll:IsVisible() and not controls.routeCollapseAll:IsVisible()
        and not status:IsVisible(),
        "Active routes hide browse controls and release search focus")
    assertNavigationPosition()
    click(controls.stop)
    assert(search:IsVisible() and search:GetText() == "slime" and slime:IsVisible()
        and status:GetText() == "Status: Unfinished",
        "Pausing a route restores the filtered journal")
    click(status)
    click(controls.routeCategory)
    click(controls.routeCategoryOptions.all)
    search:SetText("")
    assertPage(1, 11, 683)
    click(nextPage)
    click(controls.routeHeadings["Quests & Mysteries"])
    click(controls.routeHeadings["Professions"])
    click(controls.routeHeadings["Gear & Utility"])
    assert(pets:IsVisible() and slime:IsVisible() and not cozyButton:IsVisible()
        and not range:IsVisible() and not nextPage:IsVisible(),
        "Collapsing sections on the last page clamps to the remaining page and clears the pager")
    click(pets)
    click(controls.routeHeadings["Toys & Collectibles"])
    assert(pets:IsVisible() and not slime:IsVisible() and not controls.routeEmpty:IsVisible()
        and secrets.progress:GetText() == "0 of 21 Built-In Routes Finished",
        "All categories can collapse without changing route completion counts")
    click(controls.routeCategory)
    UIParent:SetHeight(1080)
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
    assert(not controls.routeCategoryMenu:IsVisible(), "Resizing closes the category menu")
    for _, heading in pairs(controls.routeHeadings) do
        assert(heading:IsVisible() and heading:GetText():sub(1, 1) == "+")
        click(heading)
    end
    assert(slime:IsVisible() and cozyButton:IsVisible(), "All categories can be reopened")
    faction = "Neutral"
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
    assert(controls.routeEmpty:IsVisible()
        and controls.routeEmpty:GetText() == "Built-in routes need your character's Alliance or Horde faction.",
        "An unavailable faction has a distinct empty message")
    faction = "Horde"
    fireAddonEvent("DISPLAY_SIZE_CHANGED")
end
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
    and cozyButton.action:GetText():find("Resume", 1, true)
    and cozyButton.action:GetText():find("Step 2", 1, true), "Pause exposes the saved step in the picker")

completionFlags[96335] = true
click(secrets.controls.routeStatus)
click(secrets.controls.routeStatus)
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
assert(SecretCompassSecretDB.route == nil and not alcazButton:IsVisible()
    and secrets.controls.routeStatus:GetText() == "Status: Unfinished"
    and secrets.progress:GetText() == "1 of 21 Built-In Routes Finished",
    "Finishing a route removes it from Unfinished and updates the overall count")
click(secrets.controls.routeStatus)
assert(alcazButton:IsVisible() and cozyButton:IsVisible(), "All displays finished and unfinished routes")
click(secrets.controls.routeStatus)
assert(alcazButton:IsVisible() and not cozyButton:IsVisible()
    and alcazButton.action:GetText():find("Replay", 1, true), "Completed offers finished routes for replay")
click(alcazButton)
assert(SecretCompassSecretDB.index == 1, "Replay starts from the first step")
click(secrets.controls.next)
click(secrets.controls.stop)
assert(alcazButton:IsVisible() and alcazButton.action:GetText():find("Resume", 1, true),
    "A paused replay remains completed and can resume")
click(secrets.controls.routeStatus)
click(secrets.controls.routeStatus)
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
assert(not SecretCompassSecretDB.route and waypoint == savedPin and not frame:IsVisible()
    and not marker:IsVisible() and not frame.scripts.OnUpdate,
    "Finishing the secret hides the HUD and preserves the player map pin")
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

do
    local owned, addCalls, removeCalls = nil, 0, 0
    local unrelated = { title = "My own pin" }
    local externalPoints = { [unrelated] = true }
    local reject, duplicate, lastOptions
    local provider = {
        WaypointExists = function() return duplicate == true end,
        AddWaypoint = function(_, mapID, x, y, options)
            addCalls = addCalls + 1
            if reject then return end
            assert(options.persistent == false and options.silent == true and options.crazy == true
                and options.from == "SecretsCompass", "Delegated points are temporary, active and attributed")
            lastOptions = options
            owned = { mapID = mapID, x = x, y = y }
            externalPoints[owned] = true
            return owned
        end,
        IsValidWaypoint = function(_, uid) return externalPoints[uid] == true end,
        RemoveWaypoint = function(_, uid)
            assert(uid == owned, "Cleanup only removes SecretsCompass's own waypoint")
            removeCalls = removeCalls + 1
            externalPoints[uid] = nil
            owned = nil
        end,
    }
    TomTom = nil
    click(cozyButton)
    click(secrets.controls.revealClue)
    click(secrets.controls.navigation)
    assert(SecretCompassSecretDB.navigation == "external" and frame:IsVisible(),
        "External arrow preference saves and falls back to the HUD")
    click(secrets.controls.revealCoordinates)
    assert(frame:IsVisible(), "HUD stays active when the external addon is missing")
    TomTom = provider
    local queuedLoad
    local immediate = C_Timer.After
    C_Timer.After = function(_, callback) queuedLoad = callback end
    fireAddonEvent("ADDON_LOADED", "WaypointTracker")
    C_Timer.After = immediate
    assert(queuedLoad and not owned and addCalls == 0,
        "Provider handoff waits for other AddOnLoaded listeners to initialize")
    queuedLoad()
    local cozyStep = cozy.steps[SecretCompassSecretDB.index].waypoints[1]
    assert(owned and owned.mapID == cozyStep.mapID and owned.x == cozyStep.x and owned.y == cozyStep.y
        and not frame:IsVisible() and ForeverCompassDB.enabled,
        "External navigation hides the HUD without changing the saved HUD preference")
    assert(not lastOptions.callbacks, "TomTom keeps its native waypoint callbacks")
    advance()
    click(secrets.controls.revealFull)
    assert(addCalls == 1 and removeCalls == 0, "Same-point refreshes keep the original waypoint")
    click(secrets.controls.revealDistance)
    assert(not owned and frame:IsVisible() and removeCalls == 1 and addCalls == 1,
        "Distance mode revokes the external point and restores HUD guidance")
    duplicate = true
    click(secrets.controls.revealCoordinates)
    assert(not owned and frame:IsVisible() and addCalls == 1 and removeCalls == 1,
        "An existing identical waypoint is never claimed")
    duplicate = false
    reject = true
    click(secrets.controls.revealDistance)
    click(secrets.controls.revealCoordinates)
    assert(not owned and frame:IsVisible() and addCalls == 2, "A declined waypoint falls back to the HUD")
    reject = false
    fireAddonEvent("PLAYER_ENTERING_WORLD")
    assert(owned and not frame:IsVisible() and addCalls == 3,
        "Entering the world retries a waypoint rejected before the provider was ready")

    provider.isWaypointTrackerBridge = true
    SecretChecklist.entries = {foreignEntry}
    foreignLink.currentURL = foreignEntry.guideURL
    click(trackSecret)
    assert(owned and owned.mapID == 1 and owned.x == 0.30 and not frame:IsVisible(),
        "An imported SecretChecklist route uses the same external arrow preference")
    click(secrets.controls.next)
    assert(owned and owned.mapID == 4 and removeCalls == 3, "Next replaces the previous owned point")
    click(secrets.controls.location)
    assert(owned and owned.mapID == 1 and owned.x == 0.25 and removeCalls == 4,
        "Next Location hands the selected alternative to the external arrow")
    local later
    C_Timer.After = function(_, callback) later = callback end
    lastOptions.callbacks.arrived("arrived", owned)
    C_Timer.After = immediate
    externalPoints[owned] = nil
    owned = nil
    assert(later, "Arrival is revalidated after Waypoint Tracker finishes auto-clear")
    local beforeArrivalAdd = addCalls
    later()
    assert(frame:IsVisible() and SecretCompassSecretDB.index == 2 and addCalls == beforeArrivalAdd,
        "An auto-cleared waypoint returns guidance to the HUD without re-adding or advancing")
    click(secrets.controls.location)
    assert(owned and owned.mapID == 4, "An intentional new location resumes external guidance")
    click(secrets.controls.next)
    assert(not owned and frame:IsVisible() and removeCalls == 5, "Text-only steps clear the external point")
    click(secrets.controls.next)
    assert(SecretCompassSecretDB.route == nil and waypoint == savedPin and externalPoints[unrelated],
        "Finish preserves the player's world map pin and other external waypoints")
    click(secrets.controls.navigation)
    assert(SecretCompassSecretDB.navigation == "hud", "The player can switch back to the compass")
    TomTom = nil
end

do
    local nativeButton = SecretsCompassMinimapButton
    local nativePanel = SecretsCompassSettings
    local opens, registrations, visibilityChanges = 0, 0, 0
    local providerOptions = {
        enabled = false, showMinimap = true, showCardinals = true,
        minimap = { minimapPos = 123, hide = false },
        style = "arc", scale = 1, opacity = 1,
    }
    local broker, brokerOptions
    local brokerLib = { NewDataObject = function(_, name, object)
        assert(name == "SecretsCompass" and object.type == "launcher")
        broker = object
        return object
    end }
    local iconLib = {
        Register = function(_, name, object, options)
            assert(name == "SecretsCompass" and object == broker)
            assert(options == providerOptions.minimap and options.minimapPos == 123)
            registrations, brokerOptions = registrations + 1, options
        end,
        Show = function(_, name)
            assert(name == "SecretsCompass" and not brokerOptions.hide)
            visibilityChanges = visibilityChanges + 1
        end,
        Hide = function(_, name)
            assert(name == "SecretsCompass" and brokerOptions.hide)
            visibilityChanges = visibilityChanges + 1
        end,
    }
    LibStub = function(name, silent)
        assert(silent == true, "Missing optional libraries are silent")
        if name == "LibDataBroker-1.1" then return brokerLib end
        if name == "LibDBIcon-1.0" then return iconLib end
    end
    local ui = namespace.CreateSettingsUI({
        get = function() return providerOptions end,
        set = function(key, value) providerOptions[key] = value end,
        openSecrets = function() opens = opens + 1 end,
        styles = namespace.CompassStyles,
        styleY = namespace.CompassStyleY,
        styleSegmentShown = namespace.CompassStyleSegmentShown,
        minScale = 60, maxScale = 150, scaleStep = 5,
    })
    ui:AttachMinimap()
    ui:AttachMinimap()
    assert(registrations == 1 and SecretsCompassMinimapButton == nativeButton,
        "When both libraries exist, register a single launcher without a second native frame")
    broker.OnClick(nil, "LeftButton")
    assert(opens == 1 and not providerOptions.enabled, "Broker left click opens Secrets without changing the HUD")
    broker.OnClick(nil, "RightButton")
    assert(SecretsCompassSettings ~= nativePanel and SecretsCompassSettings:IsVisible(),
        "Broker right click opens Settings")
    ui:Refresh()
    brokerOptions.hide = true
    providerOptions.enabled = true
    ui:Refresh()
    assert(visibilityChanges == 0 and brokerOptions.hide, "Unrelated refreshes preserve bag-controlled visibility")
    providerOptions.showMinimap = false
    ui:Refresh()
    assert(visibilityChanges == 1 and brokerOptions.hide, "The visibility setting hides the registered button")
    providerOptions.showMinimap = true
    ui:Refresh()
    assert(visibilityChanges == 2 and not brokerOptions.hide, "The visibility setting shows the registered button")
    LibStub = nil
end

do
    -- Reload the addon's runtime into new frames with SavedVariables already present.
    local route = namespace.StandaloneSecrets()[1]
    local collapsed = { pets = true, utility = "true", ["future-category"] = true }
    SecretCompassSecretDB = {
        route = route, index = 2, navigation = "external",
        reveals = { [route.id] = "distance" },
        collapsedCategories = collapsed,
    }
    assert(loadfile(addonPath .. "/SecretsCompass.lua"))("SecretsCompass", namespace)
    local loginFrame = SecretsCompassFrame
    loginFrame.scripts.OnEvent(loginFrame, "ADDON_LOADED", "SecretsCompass")
    assert(SecretCompassSecretDB.collapsedCategories == collapsed and SecretCompassSecretDB.index == 2
        and SecretCompassSecretDB.reveals[route.id] == "distance" and SecretCompassSecretDB.navigation == "external",
        "Saved journal categories load alongside route progress, reveal level and navigation")

    SlashCmdList.SECRETSCOMPASS("secrets")
    local reopened = SecretsCompassSecrets
    assert(reopened ~= secrets and reopened.progress:GetText():match("^Step 2"), "The reload opens the restored route")
    click(reopened.controls.stop)
    local pets = reopened.controls.routeHeadings["Pets"]
    local utility = reopened.controls.routeHeadings["Gear & Utility"]
    assert(pets:IsVisible() and pets:GetText() == "+  PETS" and not reopened.controls.routes["excitable-slime"]
        and utility:GetText() == "-  GEAR & UTILITY" and collapsed["future-category"] == true,
        "Restored booleans collapse known categories while invalid values remain expanded")
    click(pets)
    assert(collapsed.pets == nil and reopened.controls.routes["excitable-slime"]:IsVisible(),
        "Reopening a restored category updates SavedVariables and shows its routes")
end

do
    local runtimeTracker
    local function reloadJournal(saved)
        SecretCompassSecretDB = saved
        assert(loadfile(addonPath .. "/SecretsCompass.lua"))("SecretsCompass", namespace)
        local factory = namespace.CreateSecretTracker
        namespace.CreateSecretTracker = function(...)
            runtimeTracker = factory(...)
            return runtimeTracker
        end
        local loginFrame = SecretsCompassFrame
        loginFrame.scripts.OnEvent(loginFrame, "ADDON_LOADED", "SecretsCompass")
        namespace.CreateSecretTracker = factory
        SlashCmdList.SECRETSCOMPASS("secrets")
        return SecretsCompassSecrets
    end

    local function assertResumeDetails(journal, title, step)
        local controls = journal.controls
        local visible = title ~= nil
        assert(controls.pausedRouteTitle:IsVisible() == visible and controls.pausedStep:IsVisible() == visible
            and controls.pausedRouteTitle:GetText() == (title or "") and controls.pausedStep:GetText() == (step or ""),
            "Resume details show only the paused route title and step ordinal")
        local _, titleX, titleY = journal.routeTitle:GetPoint()
        local _, progressX, progressY = journal.progress:GetPoint()
        local _, nameX, nameY = controls.pausedRouteTitle:GetPoint()
        local _, _, stepY = controls.pausedStep:GetPoint()
        local _, _, hintY = journal.stepTitle:GetPoint()
        local _, buttonX, buttonY = controls.continueLast:GetPoint()
        if visible then
            assert(nameY - controls.pausedRouteTitle:GetHeight() >= stepY
                and stepY - controls.pausedStep:GetHeight() >= hintY
                and nameX + controls.pausedRouteTitle:GetWidth() < buttonX
                and buttonY - controls.continueLast:GetHeight() >= stepY,
                "Resume details clear the shortcuts and companion hint")
            if controls.copyWaypoint:IsVisible() then
                local _, copyX = controls.copyWaypoint:GetPoint()
                assert(titleX + journal.routeTitle:GetWidth() < progressX
                    and progressY - journal.progress:GetHeight() >= buttonY
                    and buttonX + controls.continueLast:GetWidth() < copyX,
                    "Copy and Continue fit beside the route name with a separate progress line")
            else
                assert(titleY - journal.routeTitle:GetHeight() >= progressY
                    and progressY - journal.progress:GetHeight() >= nameY
                    and progressX + journal.progress:GetWidth() < buttonX,
                    "The route and progress fit above the Continue-only summary")
            end
        else
            assert(journal.routeTitle:GetHeight() == 34 and progressY == -88
                and journal.progress:GetWidth() == 390 and journal.progress:GetHeight() == 18,
                "The standard title and progress geometry returns when resume details hide")
        end
    end

    local function assertCopyWaypoint(journal, command)
        local copy = journal.controls.copyWaypoint
        assert(copy:IsVisible(), "The paused waypoint can be copied")
        click(copy)
        local input = journal.controls.mapCommandInput
        local anchor, _, inputY = input:GetPoint()
        local _, _, searchY = journal.controls.routeSearch:GetPoint()
        assert(input:IsVisible() and input.focused and input.highlighted and input:GetText() == command
            and anchor == "TOPLEFT" and inputY - input:GetHeight() >= searchY
            and not journal.stepTitle:IsVisible() and SecretCompassSecretDB.route == nil,
            "Copy opens a selected command before search while leaving the route paused")
        return input
    end

    local function assertResumeTooltip(journal, expected)
        local tooltip = GameTooltip
        GameTooltip = {
            SetOwner = function(self, owner) self.owner = owner end,
            AddLine = function(self, value, _, _, _, wrap)
                self.value, self.wrap = value, wrap
            end,
            Show = function(self) self.shown = true end,
            IsOwned = function(self, owner) return self.owner == owner end,
            Hide = function(self) self.shown = false end,
        }
        local button = journal.controls.continueLast
        button.scripts.OnEnter(button)
        assert(GameTooltip.value == expected and (expected == nil or GameTooltip.shown and GameTooltip.wrap),
            "The wrapped tooltip contains the reveal-approved location summary")
        button.scripts.OnLeave(button)
        assert(not GameTooltip.shown, "Leaving Continue dismisses the location tooltip")
        GameTooltip = tooltip
    end

    local condor
    for _, choice in ipairs(namespace.StandaloneSecrets()) do
        if choice.id == "condor-hatchling" then
            condor = choice
        end
    end
    assert(condor)
    local saved = {
        route = condor, index = 1, locationIndex = 2,
        reveals = { [condor.id] = "coordinates" },
    }
    local journal = reloadJournal(saved)
    assert(not journal.controls.continueLast:IsVisible(), "The shortcut is hidden during active tracking")
    assertResumeDetails(journal)
    click(journal.controls.stop)
    local bookmark = assert(saved.lastPaused)
    assert(journal.controls.continueLast:IsVisible(), "Pausing creates the Continue Last Secret shortcut")
    assertResumeDetails(journal, condor.title, "Step 1 of 1 · Location 2 of 3 · Test Map 1432 (77.7, 74.9)")

    saved.lastPaused = nil
    journal = reloadJournal(saved)
    assert(not journal.controls.continueLast:IsVisible()
        and journal.controls.routes[condor.id].action:GetText() == "Resume · Step 1",
        "A legacy checkpoint remains resumable without inventing a most recently paused route")
    assertResumeDetails(journal)
    saved.lastPaused = { id = "missing-route" }
    journal = reloadJournal(saved)
    assert(not journal.controls.continueLast:IsVisible(), "An unresolved bookmark hides the shortcut")
    assertResumeDetails(journal)

    saved.lastPaused = bookmark
    journal = reloadJournal(saved)
    journal.controls.routeSearch:SetText("no matching secret")
    local shortcut = journal.controls.continueLast
    assert(shortcut:IsVisible() and shortcut:GetText() == "Continue Last Secret"
        and journal.controls.routeEmpty:IsVisible(), "The restored shortcut is independent of browse filters")
    local condorSummary = "Step 1 of 1 · Location 2 of 3 · Test Map 1432 (77.7, 74.9)"
    assertResumeDetails(journal, condor.title, condorSummary)
    assertResumeTooltip(journal, condorSummary)
    local copyInput = assertCopyWaypoint(journal, "/mappin 1432 77.70 74.90")
    journal.controls.routeSearch:SetText("nothing matches")
    assert(copyInput:IsVisible() and copyInput:GetText() == "/mappin 1432 77.70 74.90",
        "Refreshing the same built-in waypoint keeps its copy field")
    copyInput.scripts.OnEscapePressed(copyInput)
    assert(not copyInput:IsVisible() and not copyInput.focused and copyInput:GetText() == ""
        and journal.stepTitle:IsVisible(), "Escape closes Copy Waypoint and restores the journal hint")
    copyInput = assertCopyWaypoint(journal, "/mappin 1432 77.70 74.90")
    saved.reveals[condor.id] = "distance"
    journal.controls.routeSearch:SetText("")
    assert(not copyInput:IsVisible() and not copyInput.focused and copyInput:GetText() == ""
        and not journal.controls.copyWaypoint:IsVisible() and journal.stepTitle:IsVisible(),
        "A reveal change clears the stale command and copy control")
    saved.reveals[condor.id] = "coordinates"
    journal.controls.routeSearch:SetText("no matching secret")
    copyInput = assertCopyWaypoint(journal, "/mappin 1432 77.70 74.90")
    journal.scripts.OnHide(journal)
    assert(not copyInput:IsVisible() and not copyInput.focused and copyInput:GetText() == "",
        "Closing the journal clears the paused command")
    copyInput = assertCopyWaypoint(journal, "/mappin 1432 77.70 74.90")
    click(shortcut)
    assert(not copyInput:IsVisible() and not copyInput.focused and copyInput:GetText() == ""
        and not journal.controls.copyWaypoint:IsVisible() and journal.stepTitle:IsVisible(),
        "Continuing clears the paused copy field and restores the active instructions")
    assertResumeDetails(journal)
    assert(saved.route.id == condor.id and saved.index == 1 and saved.locationIndex == 2
        and journal.progress:GetText():find("Location 2 of 3", 1, true) and not shortcut:IsVisible(),
        "Continuing a built-in route restores its exact step and alternate location")
    click(journal.controls.mapCommand)
    assert(journal.controls.mapCommandInput:GetText() == "/mappin 1432 77.70 74.90"
        and journal.controls.mapCommandInput:GetPoint() == "BOTTOMLEFT",
        "The active map command uses its original footer")
    for _, reveal in ipairs({ "distance", "clue" }) do
        assert(runtimeTracker:SetReveal(reveal))
        click(journal.controls.stop)
        assertResumeDetails(journal, condor.title, "Step 1 of 1 · Location 2 of 3")
        assertResumeTooltip(journal)
        assert(not journal.controls.copyWaypoint:IsVisible(), "Low reveal levels hide Copy Waypoint")
        click(journal.controls.continueLast)
    end

    local guideURL = "https://example.com/duplicate-title"
    local imported = {
        id = "secret-checklist:" .. guideURL, sourceURL = guideURL, title = condor.title,
        steps = {
            { title = "Find the lead", waypoints = { { mapID = 1, x = 0.25, y = 0.30 } } },
            { title = "Find the lead", waypoints = {
                { mapID = 1, x = 0.32, y = 0.40 },
                { mapID = 4, x = 0.10, y = 0.20 },
            } },
        },
    }
    assert(runtimeTracker:Track(imported))
    runtimeTracker:SetReveal("coordinates")
    click(journal.controls.stop)
    assertResumeDetails(journal, imported.title, "Step 1 of 2")
    copyInput = assertCopyWaypoint(journal, "/mappin 1 25.00 30.00")
    copyInput.scripts.OnEnterPressed(copyInput)
    assert(not copyInput:IsVisible() and not copyInput.focused and journal.stepTitle:IsVisible(),
        "Enter closes the selectable command for a single mapped waypoint")
    click(journal.controls.continueLast)
    assert(runtimeTracker:Jump(2) and runtimeTracker:CycleLocation())
    runtimeTracker:SetReveal("full")
    local getMapInfo = C_Map.GetMapInfo
    C_Map.GetMapInfo = function(mapID)
        if mapID ~= 4 then
            return getMapInfo(mapID)
        end
    end
    click(journal.controls.stop)
    assertResumeDetails(journal, imported.title, "Step 2 of 2 · Location 2 of 2")
    SecretChecklist = nil
    journal = reloadJournal(saved)
    assertResumeDetails(journal, imported.title, "Step 2 of 2 · Location 2 of 2")
    assertResumeTooltip(journal)
    copyInput = assertCopyWaypoint(journal, "/mappin 4 10.00 20.00")
    copyInput.scripts.OnEscapePressed(copyInput)
    C_Map.GetMapInfo = getMapInfo
    journal = reloadJournal(saved)
    assertResumeDetails(journal, imported.title, "Step 2 of 2 · Location 2 of 2 · Test Map 4 (10.0, 20.0)")
    click(journal.controls.continueLast)
    assertResumeDetails(journal)
    assert(saved.route.id == imported.id and saved.route.title == condor.title and saved.index == 2
        and saved.locationIndex == 2 and journal.progress:GetText():find("Location 2 of 2", 1, true),
        "The most recent imported route survives reload without SecretChecklist and is matched by identity")
    click(journal.controls.mapCommand)
    assert(journal.controls.mapCommandInput:GetText() == "/mappin 4 10.00 20.00",
        "The imported guide's exact alternate location is usable after reload")
    click(journal.controls.next)
    assert(saved.route == nil and saved.lastPaused == nil and not journal.controls.continueLast:IsVisible(),
        "Finishing the continued route clears the saved shortcut")
    assertResumeDetails(journal)
end

print("SecretsCompass mocks passed: secret-only tracking, HUD controls, categorized standalone secrets, spoiler levels, verified progress, the SecretChecklist companion, and external waypoint navigation")
