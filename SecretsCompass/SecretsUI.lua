local _, namespace = ...

local panelName = "SecretsCompassSecrets"

local function label(parent, font, x, y, width, height)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", x, y)
    text:SetSize(width, height)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

local function button(parent, caption, width, x, y, onClick)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetPoint("TOPLEFT", x, y)
    control:SetText(caption)
    control:SetScript("OnClick", onClick)
    return control
end

local function waypointZone(waypoint)
    if not waypoint then
        return
    end
    local zone
    if C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, waypoint.mapID)
        if ok and not (issecretvalue and issecretvalue(info)) and type(info) == "table" then
            zone = info.name
        end
    end
    if (issecretvalue and issecretvalue(zone)) or type(zone) ~= "string" or zone == "" then
        zone = "Map " .. waypoint.mapID
    end
    return zone
end

namespace.SecretWaypointZone = waypointZone

local function waypointText(waypoint, reveal, bearingAvailable)
    local zone = waypointZone(waypoint)
    if not zone then
        return "No Mapped Location"
    end
    if reveal ~= "coordinates" and reveal ~= "full" then
        return not bearingAvailable and ("Destination: " .. zone) or ""
    end
    local coordinates = ("%.1f, %.1f"):format(waypoint.x * 100, waypoint.y * 100)
    if reveal == "full" and waypoint.label and waypoint.label ~= "" then
        return ("%s · %s (%s)"):format(waypoint.label, zone, coordinates)
    end
    return ("%s (%s)"):format(zone, coordinates)
end

local function makePanel(api)
    local panel = CreateFrame("Frame", panelName, UIParent)
    panel:SetSize(424, 401)
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 34, -126)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:Hide()

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.102, 0.112, 0.115, 1)
    local rule = panel:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", 2, -39)
    rule:SetPoint("TOPRIGHT", -2, -39)
    rule:SetHeight(1)
    rule:SetColorTexture(0.40, 0.34, 0.23, 1)

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -42, 0)
    drag:SetHeight(39)
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
    label(drag, "GameFontNormalLarge", 18, -11, 350, 22):SetText("SecretsCompass Secrets")
    panel.dragHandle = drag

    panel.routeTitle = label(panel, "GameFontNormalLarge", 18, -51, 390, 34)
    panel.progress = label(panel, "GameFontNormal", 18, -88, 390, 18)
    panel.stepTitle = label(panel, "GameFontHighlight", 18, -111, 388, 34)
    local noteScroll = CreateFrame("ScrollFrame", nil, panel)
    noteScroll:SetPoint("TOPLEFT", 18, -146)
    noteScroll:SetSize(365, 53)
    local noteBody = CreateFrame("Frame", nil, noteScroll)
    noteBody:SetSize(365, 53)
    noteScroll:SetScrollChild(noteBody)
    local note = noteBody:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT")
    note:SetWidth(365)
    note:SetJustifyH("LEFT")
    panel.note = note
    panel.noteScroll = noteScroll
    panel.noteBody = noteBody
    panel.locationText = label(panel, "GameFontHighlightSmall", 18, -205, 388, 28)
    panel.locationText:SetTextColor(0.52, 0.90, 1)
    panel.travel = label(panel, "GameFontHighlightSmall", 18, -233, 388, 31)
    panel.travel:SetTextColor(0.74, 0.77, 0.76)
    panel.status = label(panel, "GameFontHighlightSmall", 18, -270, 272, 30)
    panel.status:SetTextColor(0.74, 0.77, 0.76)

    local controls = { routes = {} }
    panel.controls = controls
    controls.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    controls.close:SetPoint("TOPRIGHT", -4, -3)
    controls.close:SetScript("OnClick", function() panel:Hide() end)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, panelName)
    end

    controls.previous = button(panel, "Previous", 85, 18, -365, function() api.step(-1) end)
    controls.next = button(panel, "Next", 85, 108, -365, api.next)
    controls.stop = button(panel, "Stop", 70, 198, -365, api.stop)
    controls.location = button(panel, "Next Location", 132, 274, -365, api.cycle)
    controls.enableHUD = button(panel, "Show HUD", 108, 298, -265, api.enableHUD)
    controls.revealClue = button(panel, "Clue", 84, 18, -300, function() api.setReveal("clue") end)
    controls.revealDistance = button(panel, "Distance", 91, 107, -300, function() api.setReveal("distance") end)
    controls.revealCoordinates = button(panel, "Coordinates", 111, 203, -300, function() api.setReveal("coordinates") end)
    controls.revealFull = button(panel, "Full", 87, 319, -300, function() api.setReveal("full") end)
    controls.suggested = button(panel, "Go to Suggested Step", 176, 18, -331, api.jumpSuggested)
    panel.suggestion = label(panel, "GameFontHighlightSmall", 203, -336, 204, 23)

    local function nudge(pixels)
        local limit = panel.noteBody:GetHeight() - noteScroll:GetHeight()
        local position = math.max(0, math.min(limit, noteScroll:GetVerticalScroll() + pixels))
        noteScroll:SetVerticalScroll(position)
        controls.noteUp:SetEnabled(position > 0)
        controls.noteDown:SetEnabled(position < limit)
    end
    controls.noteUp = button(panel, "^", 20, 387, -146, function() nudge(-32) end)
    controls.noteDown = button(panel, "v", 20, 387, -173, function() nudge(32) end)
    noteScroll:EnableMouseWheel(true)
    noteScroll:SetScript("OnMouseWheel", function(_, delta) nudge(-delta * 32) end)

    return panel
end

function namespace.CreateSecretsUI(api)
    local ui = {}
    local panel, finished

    function ui:Refresh()
        if not panel then
            return
        end
        local route, index, locationIndex = api.getRoute()
        local step = api.getCurrentStep()
        local tracking = route ~= nil and step ~= nil
        local controls = panel.controls
        local reveal = api.getReveal()
        if tracking then
            finished = nil
            panel.routeTitle:SetText(route.title)
            panel.progress:SetText(("Step %d of %d"):format(index, #route.steps))
            panel.stepTitle:SetText(reveal == "full" and step.title or (step.clue or "Follow the next lead."))
            panel.note:SetText(reveal == "full" and step.note or "")
            if #step.waypoints > 1 then
                local location = ("Location %d of %d"):format(locationIndex, #step.waypoints)
                panel.progress:SetText(("%s · %s"):format(panel.progress:GetText(), location))
            end
            controls.previous:SetEnabled(index > 1)
            controls.next:SetText(index < #route.steps and "Next" or "Finish")
            local suggested, allComplete = api.getSuggested()
            controls.suggested:SetShown(suggested ~= nil and suggested > index)
            if suggested and suggested > index then
                panel.suggestion:SetText(("Verified progress suggests step %d."):format(suggested))
            elseif allComplete then
                panel.suggestion:SetText("All required steps are verified complete.")
            else
                panel.suggestion:SetText("")
            end
        else
            panel.routeTitle:SetText("Choose a Secret")
            panel.progress:SetText("")
            panel.stepTitle:SetText(finished and "Route finished. Choose another secret when you are ready."
                or "Choose a built-in route, or use Track Secret in SecretChecklist.")
            panel.note:SetText("")
            controls.suggested:Hide()
            panel.suggestion:SetText("")
        end
        for _, row in pairs(controls.routes) do
            row:Hide()
        end
        local routes = not tracking and api.getRoutes()
        if routes then
            if #routes == 0 then
                panel.note:SetText("Built-in routes need your character's Alliance or Horde faction.")
            end
            for index, choice in ipairs(routes) do
                local id = choice.id
                local position = -157 - (index - 1) * 30
                local row = controls.routes[id]
                if not row then
                    row = button(panel, "", 388, 18, position, function() api.start(id) end)
                    controls.routes[id] = row
                else
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 18, position)
                end
                row:SetText("Track " .. choice.title)
                row:Show()
            end
        end
        controls.previous:SetShown(tracking)
        controls.next:SetShown(tracking)
        controls.stop:SetShown(tracking)
        controls.location:SetShown(tracking and #step.waypoints > 1)
        controls.revealClue:SetShown(tracking)
        controls.revealDistance:SetShown(tracking)
        controls.revealCoordinates:SetShown(tracking)
        controls.revealFull:SetShown(tracking)
        controls.revealClue:SetEnabled(reveal ~= "clue")
        controls.revealDistance:SetEnabled(reveal ~= "distance")
        controls.revealCoordinates:SetEnabled(reveal ~= "coordinates")
        controls.revealFull:SetEnabled(reveal ~= "full")
        panel.noteScroll:SetShown(tracking or #routes == 0)
        local noteHeight = math.ceil(panel.note:GetStringHeight())
        local notesOverflow = noteHeight > panel.noteScroll:GetHeight()
        panel.noteBody:SetHeight(math.max(noteHeight, panel.noteScroll:GetHeight()))
        panel.noteScroll:SetVerticalScroll(0)
        controls.noteUp:SetShown(notesOverflow)
        controls.noteUp:SetEnabled(false)
        controls.noteDown:SetShown(notesOverflow)
        controls.noteDown:SetEnabled(notesOverflow)
        self:RefreshStatus()
    end

    function ui:RefreshStatus()
        if panel then
            local step, waypoint = api.getCurrentStep()
            local hidden = step ~= nil and api.hudHidden()
            local bearingAvailable = api.hasBearing()
            panel.controls.enableHUD:SetShown(hidden)
            panel.status:SetText(step and api.status() or "")
            panel.locationText:SetText(step and waypointText(waypoint, api.getReveal(), bearingAvailable) or "")
            panel.travel:SetText(step and not bearingAvailable and step.travelHint or "")
        end
    end

    function ui:ShowFinished()
        finished = true
        self:Refresh()
    end

    function ui:Open()
        panel = panel or makePanel(api)
        panel:Show()
        self:Refresh()
    end

    function ui:Toggle()
        if panel and panel:IsShown() then
            panel:Hide()
        else
            self:Open()
        end
    end

    return ui
end
