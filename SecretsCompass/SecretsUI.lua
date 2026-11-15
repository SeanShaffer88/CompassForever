local addonName, namespace = ...

local panelName = "SecretsCompassSecrets"
local journalTitle = "SecretsCompass Journal"
local portraitPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\MinimapCompass.tga"
local journalHeight = 471
local routeRowHeight, baseRouteRows = 30, 8
local navigationMessages = {
    delegated = "Waypoint sent to the external arrow.",
    unavailable = "External arrow unavailable. Using your HUD preference.",
    reveal = "Choose Coordinates or Full to use the external arrow.",
    location = "This step has no waypoint for the external arrow.",
    collision = "A matching waypoint already exists. Using your HUD preference.",
    failed = "The external arrow could not take this waypoint.",
    cleanupFailed = "The external arrow could not clear the previous waypoint.",
    cleared = "The external waypoint was cleared. Switch navigation to send it again.",
    test = "External navigation paused during the overflow test.",
}

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

local function canShowMapCommand(waypoint, reveal)
    return waypoint ~= nil and (reveal == "coordinates" or reveal == "full")
end

local function mapCommandText(waypoint)
    local x = math.floor(waypoint.x * 10000 + 0.5)
    local y = math.floor(waypoint.y * 10000 + 0.5)
    local slash = SLASH_MAPPIN1
    if (issecretvalue and issecretvalue(slash)) or type(slash) ~= "string" or not slash:match("^/[^%s%c/|]+$") then
        slash = "/mappin"
    end
    return ("%s %d %d.%02d %d.%02d"):format(slash, waypoint.mapID,
        math.floor(x / 100), x % 100, math.floor(y / 100), y % 100)
end

local function makePanel(api)
    local panel = CreateFrame("Frame", panelName, UIParent, "PortraitFrameTemplate")
    panel:SetSize(424, journalHeight)
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 34, -126)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:Hide()

    local portraitContainer = panel.PortraitContainer
    local portrait = panel.portrait or (portraitContainer and portraitContainer.portrait)
    if not portrait then
        portrait = panel:CreateTexture(nil, "ARTWORK")
        portrait:SetSize(40, 40)
        portrait:SetPoint("TOPLEFT", 10, -8)
    end
    if SetPortraitToAsset then
        SetPortraitToAsset(portrait, portraitPath)
    else
        portrait:SetTexture(portraitPath)
    end

    local insetEdge = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    insetEdge:SetPoint("TOPLEFT", 9, -64)
    insetEdge:SetPoint("BOTTOMRIGHT", -9, 8)
    insetEdge:SetColorTexture(0.33, 0.26, 0.15, 1)
    local inset = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    inset:SetPoint("TOPLEFT", insetEdge, "TOPLEFT", 1, -1)
    inset:SetPoint("BOTTOMRIGHT", insetEdge, "BOTTOMRIGHT", -1, 1)
    inset:SetColorTexture(0.077, 0.070, 0.060, 1)

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 65, -2)
    drag:SetPoint("TOPRIGHT", -42, -2)
    drag:SetHeight(32)
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
    if panel.SetTitle then
        panel:SetTitle(journalTitle)
    elseif panel.TitleContainer and panel.TitleContainer.TitleText then
        panel.TitleContainer.TitleText:SetText(journalTitle)
    else
        label(drag, "GameFontNormalLarge", 0, -8, 310, 22):SetText(journalTitle)
    end
    panel.dragHandle = drag

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", 0, -26)
    body:SetPoint("BOTTOMRIGHT")
    panel.body = body
    panel.footerRule = body:CreateTexture(nil, "ARTWORK")
    panel.footerRule:SetPoint("TOPLEFT", 18, -354)
    panel.footerRule:SetPoint("TOPRIGHT", -18, -354)
    panel.footerRule:SetHeight(1)
    panel.footerRule:SetColorTexture(0.35, 0.28, 0.16, 1)

    panel.routeTitle = label(body, "GameFontNormalLarge", 18, -51, 390, 34)
    panel.progress = label(body, "GameFontNormal", 18, -88, 390, 18)
    panel.stepTitle = label(body, "GameFontHighlight", 18, -111, 388, 34)
    local noteScroll = CreateFrame("ScrollFrame", nil, body)
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
    panel.locationText = label(body, "GameFontHighlightSmall", 18, -205, 388, 28)
    panel.locationText:SetTextColor(0.52, 0.90, 1)
    panel.travel = label(body, "GameFontHighlightSmall", 18, -233, 388, 31)
    panel.travel:SetTextColor(0.74, 0.77, 0.76)
    panel.status = label(body, "GameFontHighlightSmall", 18, -270, 272, 30)
    panel.status:SetTextColor(0.74, 0.77, 0.76)

    local controls = { routes = {} }
    panel.controls = controls
    controls.close = panel.CloseButton
    if not controls.close then
        controls.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        controls.close:SetPoint("TOPRIGHT", -4, -3)
    end
    controls.close:SetScript("OnClick", function() panel:Hide() end)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, panelName)
    end

    controls.previous = button(body, "Previous", 85, 18, -365, function() api.step(-1) end)
    controls.next = button(body, "Next", 85, 108, -365, api.next)
    controls.stop = button(body, "Pause", 70, 198, -365, api.stop)
    controls.location = button(body, "Next Location", 132, 274, -365, api.cycle)
    controls.enableHUD = button(body, "Show HUD", 108, 298, -265, api.enableHUD)
    controls.revealClue = button(body, "Clue", 84, 18, -300, function() api.setReveal("clue") end)
    controls.revealDistance = button(body, "Distance", 91, 107, -300, function() api.setReveal("distance") end)
    controls.revealCoordinates = button(body, "Coordinates", 111, 203, -300, function() api.setReveal("coordinates") end)
    controls.revealFull = button(body, "Full", 87, 319, -300, function() api.setReveal("full") end)
    controls.suggested = button(body, "Go to Suggested Step", 176, 18, -331, api.jumpSuggested)
    panel.suggestion = label(body, "GameFontHighlightSmall", 203, -336, 204, 23)

    controls.jumpLabel = label(body, "GameFontNormal", 18, -406, 128, 22)
    local jumpInput = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    jumpInput:SetSize(70, 24)
    jumpInput:SetPoint("TOPLEFT", 152, -401)
    jumpInput:SetAutoFocus(false)
    controls.jumpInput = jumpInput

    local function jumpCandidate()
        local route, index = api.getRoute()
        if not route or route ~= panel.jumpRoute then
            return
        end
        local step = api.parseStep(jumpInput:GetText())
        if step and step <= #route.steps and step ~= index then
            return step
        end
    end

    local function submitJump()
        local step = jumpCandidate()
        jumpInput:ClearFocus()
        if step then
            api.jump(step)
        end
    end

    controls.jumpGo = button(body, "Go", 62, 230, -401, submitJump)
    jumpInput:SetScript("OnTextChanged", function()
        controls.jumpGo:SetEnabled(jumpCandidate() ~= nil)
    end)
    jumpInput:SetScript("OnEnterPressed", submitJump)
    panel.resetJump = function()
        jumpInput:ClearFocus()
        jumpInput:SetText("")
        controls.jumpGo:SetEnabled(false)
    end
    jumpInput:SetScript("OnEscapePressed", panel.resetJump)

    local mapInput = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    mapInput:SetSize(172, 24)
    mapInput:SetPoint("BOTTOMLEFT", 150, 54)
    mapInput:SetAutoFocus(false)
    controls.mapCommandInput = mapInput
    local copyHint = label(body, "GameFontHighlightSmall", 327, 0, 80, 15)
    copyHint:ClearAllPoints()
    copyHint:SetPoint("BOTTOMLEFT", 327, 57)
    copyHint:SetText("Ctrl+C to copy")

    local selectedCommand
    panel.resetMapCommand = function()
        selectedCommand = nil
        mapInput:ClearFocus()
        mapInput:SetText("")
        mapInput:Hide()
        copyHint:Hide()
    end
    mapInput:SetScript("OnTextChanged", function(self)
        if selectedCommand and self:GetText() ~= selectedCommand then
            self:SetText(selectedCommand)
            self:HighlightText()
        end
    end)
    mapInput:SetScript("OnEscapePressed", panel.resetMapCommand)
    mapInput:SetScript("OnEnterPressed", panel.resetMapCommand)
    controls.mapCommand = button(body, "Map Command", 120, 18, 0, function()
        local _, waypoint = api.getCurrentStep()
        if panel:IsShown() and canShowMapCommand(waypoint, api.getReveal()) then
            jumpInput:ClearFocus()
            selectedCommand = mapCommandText(waypoint)
            mapInput:SetText(selectedCommand)
            mapInput:Show()
            copyHint:Show()
            mapInput:SetFocus()
            mapInput:HighlightText()
        end
    end)
    controls.mapCommand:ClearAllPoints()
    controls.mapCommand:SetPoint("BOTTOMLEFT", 18, 54)

    controls.navigation = button(body, "", 176, 18, 0, api.switchNavigation)
    controls.navigation:ClearAllPoints()
    controls.navigation:SetPoint("BOTTOMLEFT", 18, 14)
    panel.navigationStatus = label(body, "GameFontHighlightSmall", 203, 0, 203, 31)
    panel.navigationStatus:ClearAllPoints()
    panel.navigationStatus:SetPoint("BOTTOMLEFT", 203, 10)
    panel.navigationStatus:SetTextColor(0.74, 0.77, 0.76)
    panel.resetMapCommand()

    local function onHide()
        stopMoving()
        panel.resetJump()
        panel.resetMapCommand()
    end
    if panel.HookScript then
        panel:HookScript("OnHide", onHide)
    else
        panel:SetScript("OnHide", onHide)
    end

    local function nudge(pixels)
        local limit = panel.noteBody:GetHeight() - noteScroll:GetHeight()
        local position = math.max(0, math.min(limit, noteScroll:GetVerticalScroll() + pixels))
        noteScroll:SetVerticalScroll(position)
        controls.noteUp:SetEnabled(position > 0)
        controls.noteDown:SetEnabled(position < limit)
    end
    controls.noteUp = button(body, "^", 20, 387, -146, function() nudge(-32) end)
    controls.noteDown = button(body, "v", 20, 387, -173, function() nudge(32) end)
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
        local step, waypoint = api.getCurrentStep()
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
            local atKnownEnd = index == #route.steps and route.ongoing
            controls.next:SetEnabled(not atKnownEnd)
            controls.next:SetText(index < #route.steps and "Next" or (atKnownEnd and "Known End" or "Finish"))
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
            local finishedCount = 0
            for index, choice in ipairs(routes) do
                local id = choice.id
                local position = -157 - (index - 1) * routeRowHeight
                local row = controls.routes[id]
                if not row then
                    row = button(panel.body, "", 388, 18, position, function() api.start(id) end)
                    controls.routes[id] = row
                else
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 18, position)
                end
                local resumeStep = api.getResumeStep(choice)
                local hasFinished = api.hasFinished(choice)
                if hasFinished then
                    finishedCount = finishedCount + 1
                end
                if resumeStep then
                    row:SetText(("Resume %s (Step %d)"):format(choice.title, resumeStep))
                else
                    row:SetText((hasFinished and "Replay " or "Track ") .. choice.title)
                end
                row:Show()
            end
            if #routes > 0 then
                panel.progress:SetText(("%d of %d Built-In Routes Finished"):format(finishedCount, #routes))
            end
        end
        panel.footerRule:SetShown(tracking)
        controls.previous:SetShown(tracking)
        controls.next:SetShown(tracking)
        controls.stop:SetShown(tracking)
        controls.location:SetShown(tracking and #step.waypoints > 1)
        local jumpRoute = tracking and #route.steps > 1 and route or nil
        if panel.jumpRoute ~= jumpRoute or panel.jumpIndex ~= index then
            panel.jumpRoute, panel.jumpIndex = jumpRoute, index
            panel.resetJump()
        end
        if jumpRoute then
            controls.jumpLabel:SetText(("Go to Step (1–%d)"):format(#route.steps))
        end
        local showMapCommand = tracking and canShowMapCommand(waypoint, reveal)
        if not showMapCommand or panel.mapCommandRoute ~= route or panel.mapCommandIndex ~= index
            or panel.mapCommandWaypoint ~= waypoint or panel.mapCommandReveal ~= reveal then
            panel.resetMapCommand()
        end
        panel.mapCommandRoute, panel.mapCommandIndex = route, index
        panel.mapCommandWaypoint, panel.mapCommandReveal = waypoint, reveal
        local extraRouteHeight = routes and math.max(0, #routes - baseRouteRows) * routeRowHeight or 0
        panel:SetHeight(journalHeight + extraRouteHeight + (jumpRoute and 34 or 0) + (showMapCommand and 34 or 0))
        controls.mapCommand:SetShown(showMapCommand)
        controls.jumpLabel:SetShown(jumpRoute ~= nil)
        controls.jumpInput:SetShown(jumpRoute ~= nil)
        controls.jumpGo:SetShown(jumpRoute ~= nil)
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
            local mode, navigationStatus = api.navigation()
            local external = mode == "external"
            panel.controls.navigation:SetText(external and "Navigation: External Arrow" or "Navigation: Compass HUD")
            panel.navigationStatus:SetText(navigationMessages[navigationStatus]
                or (external and "Track a route to send waypoints to the external arrow." or "Follow secret steps on the compass."))
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
        api.refreshNavigation()
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
