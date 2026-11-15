local addonName, namespace = ...

local panelName = "SecretsCompassSecrets"
local journalTitle = "SecretsCompass Journal"
local portraitPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\MinimapCompass.tga"
local journalHeight = 471
local routeRowHeight, routeHeadingHeight = 30, 24
local browseToolbarHeight = 50
local routeListTop, routeFrameHeight, routePagerHeight = 157 + browseToolbarHeight, 201 + browseToolbarHeight, 30
local routePageInset = 10
local categoryOrder = {
    { key = "pets", label = "Pets", icon = "Ability_Hunter_BeastCall" },
    { key = "collectibles", label = "Toys & Collectibles", icon = "INV_Misc_Gift_01" },
    { key = "utility", label = "Gear & Utility", icon = "INV_Misc_Gear_01" },
    { key = "professions", label = "Professions", icon = "Trade_BlackSmithing" },
    { key = "mysteries", label = "Quests & Mysteries", icon = "INV_Misc_Book_11" },
}
local routeCategories = {}
for index, category in ipairs(categoryOrder) do
    category.order = index
    routeCategories[category.key] = category
end
local otherCategory = { key = "other", order = #categoryOrder + 1, label = "Other Secrets", icon = "INV_Misc_QuestionMark" }
local gold = { 0.96, 0.78, 0.43 }
local muted = { 0.73, 0.67, 0.55 }
local finishedColor = { 0.68, 0.76, 0.48 }
local navigationMessages = {
    delegated = "Waypoint sent to the external arrow.",
    unavailable = "External arrow unavailable. Using your HUD preference.",
    reveal = "Choose Coordinates or Full to use the external arrow.",
    location = "This step has no waypoint for the external arrow.",
    collision = "A matching waypoint already exists. Using your HUD preference.",
    failed = "The external arrow could not take this waypoint.",
    cleanupFailed = "The external arrow could not clear the previous waypoint.",
    cleared = "The external waypoint was cleared. Switch navigation to send it again.",
}

local function label(parent, font, x, y, width, height)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", x, y)
    text:SetSize(width, height)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

local function surface(frame, layer, red, green, blue, alpha)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetColorTexture(red, green, blue, alpha)
    return texture
end

local function button(parent, caption, width, x, y, onClick)
    local control = CreateFrame("Button", nil, parent)
    control:SetSize(width, 24)
    control:SetPoint("TOPLEFT", x, y)
    local edge = surface(control, "BACKGROUND", 0.29, 0.24, 0.16, 1)
    local fill = control:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(0.14, 0.12, 0.09, 1)
    control:SetHighlightTexture(surface(control, "HIGHLIGHT", 0.74, 0.52, 0.25, 0.24))
    local text = label(control, "GameFontNormalSmall", 2, 0, width - 4, 24)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    control:SetFontString(text)
    control:SetNormalFontObject(GameFontNormalSmall)
    control:SetDisabledFontObject(GameFontDisableSmall)
    control:SetText(caption)
    control:SetScript("OnClick", onClick)
    return control, text
end

local function routeRow(parent, route, y, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(388, 24)
    row:SetPoint("TOPLEFT", 18, y)
    row.fill = surface(row, "BACKGROUND", 0.14, 0.12, 0.09, 1)
    row:SetHighlightTexture(surface(row, "HIGHLIGHT", 0.74, 0.52, 0.25, 0.28))
    row:SetScript("OnClick", onClick)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture("Interface\\Icons\\" .. (routeCategories[route.category] or otherCategory).icon)
    row.title = label(row, "GameFontNormal", 32, 0, 244, 24)
    row.title:SetJustifyV("MIDDLE")
    row.title:SetText(route.title)
    row.action = label(row, "GameFontHighlightSmall", 282, 0, 98, 24)
    row.action:SetJustifyH("RIGHT")
    row.action:SetJustifyV("MIDDLE")
    return row
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

local function routeCategory(route)
    return routeCategories[route.category] or otherCategory
end

local function categoryCollapsed(collapsed, key)
    local value = collapsed[key]
    return not (issecretvalue and issecretvalue(value)) and value == true
end

local function paginateRoutes(routes, collapsed, screenHeight)
    local sorted = {}
    for i, route in ipairs(routes) do
        sorted[i] = route
    end
    table.sort(sorted, function(a, b)
        local aCategory, bCategory = routeCategory(a), routeCategory(b)
        if aCategory ~= bCategory then
            return aCategory.order < bCategory.order
        end
        local aTitle, bTitle = a.title:lower(), b.title:lower()
        if aTitle == bTitle then
            return a.id < b.id
        end
        return aTitle < bTitle
    end)

    local entries, contentHeight, previousCategory = {}, 0, nil
    for _, route in ipairs(sorted) do
        local category = routeCategory(route)
        local newHeading = category ~= previousCategory
        local expanded = not categoryCollapsed(collapsed, category.key)
        if newHeading or expanded then
            local height = (newHeading and routeHeadingHeight or 0) + (expanded and routeRowHeight or 0)
            entries[#entries + 1] = {
                category = category, heading = newHeading, route = expanded and route or nil, height = height,
            }
            contentHeight = contentHeight + height
        end
        previousCategory = category
    end

    local naturalHeight = routeFrameHeight + math.max(routeHeadingHeight + routeRowHeight, contentHeight)
    local availableHeight = screenHeight - routePageInset
    local maxHeight = contentHeight
    if #entries > 1 and screenHeight > 0 and naturalHeight > availableHeight then
        maxHeight = math.max(routeHeadingHeight + routeRowHeight, availableHeight - routeFrameHeight - routePagerHeight)
    end

    local current = { height = 0, rows = {} }
    local pages, tallest, routeIndex = { current }, 0, 0
    for _, entry in ipairs(entries) do
        local heading, height = entry.heading, entry.height
        if current.height + height > maxHeight then
            current = { height = 0, rows = {} }
            pages[#pages + 1] = current
            if not heading then
                heading = true
                height = height + routeHeadingHeight
            end
        end
        current.rows[#current.rows + 1] = {
            route = entry.route, heading = heading and entry.category or nil, position = routeListTop + current.height,
        }
        if entry.route then
            routeIndex = routeIndex + 1
            current.first = current.first or routeIndex
            current.last = routeIndex
        end
        current.height = current.height + height
        tallest = math.max(tallest, current.height)
    end
    local height = #pages > 1 and routeFrameHeight + routePagerHeight + tallest or naturalHeight
    return pages, height, routeIndex
end

local function makePanel(api, changePage, changeFilter, setAllCategories)
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
    inset:SetColorTexture(0.067, 0.056, 0.042, 1)

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

    local controls = { routes = {}, routeHeadings = {} }
    panel.controls = controls
    controls.close = panel.CloseButton
    if not controls.close then
        controls.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        controls.close:SetPoint("TOPRIGHT", -4, -3)
    end
    controls.close:SetScript("OnClick", function() panel:Hide() end)

    local search = CreateFrame("EditBox", nil, body)
    controls.routeSearch = search
    search:SetSize(225, 24)
    search:SetPoint("TOPLEFT", 18, -148)
    search:EnableMouse(true)
    search:SetAutoFocus(false)
    search:SetMaxLetters(64)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetTextInsets(8, 8, 0, 0)
    local searchEdge = surface(search, "BACKGROUND", 0.29, 0.24, 0.16, 1)
    local searchFill = search:CreateTexture(nil, "BORDER")
    searchFill:SetPoint("TOPLEFT", searchEdge, "TOPLEFT", 1, -1)
    searchFill:SetPoint("BOTTOMRIGHT", searchEdge, "BOTTOMRIGHT", -1, 1)
    searchFill:SetColorTexture(0.049, 0.042, 0.032, 1)
    local searchPrompt = label(search, "GameFontHighlightSmall", 8, 0, 205, 24)
    searchPrompt:SetJustifyV("MIDDLE")
    searchPrompt:SetTextColor(unpack(muted))
    searchPrompt:SetText("Search secrets")
    search:SetScript("OnEditFocusGained", function() searchPrompt:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) searchPrompt:SetShown(self:GetText() == "") end)

    local menu = CreateFrame("Frame", nil, body)
    controls.routeCategoryMenu = menu
    controls.routeCategoryOptions = {}
    menu:SetSize(154, 4 + 24 * (#categoryOrder + 1))
    menu:SetPoint("TOPLEFT", 252, -174)
    menu:SetFrameLevel(body:GetFrameLevel() + 10)
    menu:EnableMouse(true)
    surface(menu, "BACKGROUND", 0.09, 0.075, 0.057, 1)
    menu:Hide()

    controls.routeCategory = button(body, "All Types  v", 154, 252, -148, function()
        search:ClearFocus()
        menu:SetShown(not menu:IsShown())
    end)
    local function addCategoryOption(key, caption, index)
        controls.routeCategoryOptions[key] = button(menu, caption, 150, 2, -2 - index * 24, function()
            controls.routeCategory:SetText(caption .. "  v")
            menu:Hide()
            changeFilter(search:GetText(), key)
        end)
    end
    addCategoryOption("all", "All Types", 0)
    for index, category in ipairs(categoryOrder) do
        addCategoryOption(category.key, category.label, index)
    end

    search:SetText("")
    search:SetScript("OnTextChanged", function(self)
        menu:Hide()
        searchPrompt:SetShown(self:GetText() == "" and not self:HasFocus())
        changeFilter(self:GetText())
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    controls.routeExpandAll = button(body, "Expand All", 98, 18, -177, function() setAllCategories(nil) end)
    controls.routeCollapseAll = button(body, "Collapse All", 104, 124, -177, function() setAllCategories(true) end)
    controls.routeEmpty = label(body, "GameFontHighlight", 18, -routeListTop, 388, 40)
    controls.routeEmpty:SetTextColor(unpack(muted))

    local listRule = body:CreateTexture(nil, "ARTWORK")
    listRule:SetHeight(1)
    listRule:SetColorTexture(0.29, 0.24, 0.16, 1)
    controls.routeRule = listRule
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

    controls.navigation = button(body, "", 176, 230, -12, api.switchNavigation)
    panel.navigationStatus = label(body, "GameFontHighlightSmall", 77, -9, 145, 42)
    panel.navigationStatus:SetTextColor(0.74, 0.77, 0.76)
    panel.resetMapCommand()

    controls.routePagePrevious = button(body, "Previous Page", 110, 18, 0, function() changePage(-1) end)
    controls.routePagePrevious:ClearAllPoints()
    controls.routePagePrevious:SetPoint("BOTTOMLEFT", 18, 24)
    controls.routePageNext = button(body, "Next Page", 110, 296, 0, function() changePage(1) end)
    controls.routePageNext:ClearAllPoints()
    controls.routePageNext:SetPoint("BOTTOMLEFT", 296, 24)
    controls.routePageRange = label(body, "GameFontHighlight", 133, 0, 158, 24)
    controls.routePageRange:ClearAllPoints()
    controls.routePageRange:SetPoint("BOTTOMLEFT", 133, 24)
    controls.routePageRange:SetJustifyH("CENTER")
    controls.routePageRange:SetJustifyV("MIDDLE")

    local function onHide()
        stopMoving()
        search:ClearFocus()
        menu:Hide()
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

function namespace.CreateSecretsUI(api, collapsedCategories)
    local ui = {}
    local panel, finished
    local page = 1
    local query, categoryFilter = "", "all"
    local collapsed = type(collapsedCategories) == "table" and collapsedCategories or {}

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
                or "Use Track Secret in SecretChecklist, or choose a built-in route below.")
            panel.note:SetText("")
            controls.suggested:Hide()
            panel.suggestion:SetText("")
        end
        for _, row in pairs(controls.routes) do
            row:Hide()
        end
        for _, heading in pairs(controls.routeHeadings) do
            heading:Hide()
        end
        controls.routeSearch:SetShown(not tracking)
        controls.routeCategory:SetShown(not tracking)
        controls.routeExpandAll:SetShown(not tracking)
        controls.routeCollapseAll:SetShown(not tracking)
        controls.routeRule:SetShown(not tracking)
        controls.routeEmpty:Hide()
        local height, paging, pageCount = journalHeight, false, 1
        if tracking then
            controls.routeSearch:ClearFocus()
            controls.routeCategoryMenu:Hide()
        else
            local routes = api.getRoutes()
            local filtered, finishedCount = {}, 0
            for _, choice in ipairs(routes) do
                if api.hasFinished(choice) then
                    finishedCount = finishedCount + 1
                end
                if (categoryFilter == "all" or choice.category == categoryFilter)
                    and choice.title:lower():find(query, 1, true) then
                    filtered[#filtered + 1] = choice
                end
            end
            if #routes > 0 then
                panel.progress:SetText(("%d of %d Built-In Routes Finished"):format(finishedCount, #routes))
            end
            if #filtered == 0 then
                controls.routeEmpty:SetText(#routes == 0
                    and "Built-in routes need your character's Alliance or Horde faction."
                    or "No secrets match your search or category.")
                controls.routeEmpty:Show()
            end
            local pages, layoutHeight, expandedCount = paginateRoutes(filtered, collapsed, UIParent:GetHeight())
            height, pageCount = layoutHeight, #pages
            paging = pageCount > 1
            page = math.min(page, pageCount)
            local visible = pages[page]
            if paging then
                controls.routePageRange:SetText(visible.first
                    and ("%d–%d of %d"):format(visible.first, visible.last, expandedCount)
                    or ("Page %d of %d"):format(page, pageCount))
            end
            local ruleY = paging and 53 or 15
            controls.routeRule:ClearAllPoints()
            controls.routeRule:SetPoint("BOTTOMLEFT", 18, ruleY)
            controls.routeRule:SetPoint("BOTTOMRIGHT", -18, ruleY)
            for rowIndex, entry in ipairs(visible.rows) do
                local position = -entry.position
                local category = entry.heading
                if category then
                    local heading = controls.routeHeadings[category.label]
                    if not heading then
                        local key = category.key
                        local title
                        heading, title = button(panel.body, "", 388, 18, position, function()
                            collapsed[key] = not categoryCollapsed(collapsed, key) or nil
                            controls.routeCategoryMenu:Hide()
                            self:Refresh()
                        end)
                        heading:SetHeight(20)
                        title:SetSize(372, 20)
                        title:ClearAllPoints()
                        title:SetPoint("LEFT", heading, "LEFT", 8, 0)
                        title:SetJustifyH("LEFT")
                        controls.routeHeadings[category.label] = heading
                    else
                        heading:ClearAllPoints()
                        heading:SetPoint("TOPLEFT", 18, position)
                    end
                    heading:SetText((categoryCollapsed(collapsed, category.key) and "+  " or "-  ") .. category.label:upper())
                    heading:Show()
                    position = position - routeHeadingHeight
                end
                local choice = entry.route
                if choice then
                    local id = choice.id
                    local row = controls.routes[id]
                    if not row then
                        row = routeRow(panel.body, choice, position, function() api.start(id) end)
                        controls.routes[id] = row
                    else
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", 18, position)
                    end
                    local resumeStep = api.getResumeStep(choice)
                    local complete = api.hasFinished(choice)
                    local shade = rowIndex % 2 == 0 and 0.011 or 0
                    row.fill:SetColorTexture(0.13 + shade, 0.11 + shade, 0.085 + shade, 1)
                    row.title:SetTextColor(unpack(complete and not resumeStep and muted or gold))
                    row.action:SetTextColor(unpack(complete and not resumeStep and finishedColor or muted))
                    row.action:SetText(resumeStep and ("Resume · Step %d"):format(resumeStep) or (complete and "Replay" or "Track"))
                    row:Show()
                end
            end
        end
        controls.routePagePrevious:SetShown(paging)
        controls.routePageNext:SetShown(paging)
        controls.routePageRange:SetShown(paging)
        controls.routePagePrevious:SetEnabled(paging and page > 1)
        controls.routePageNext:SetEnabled(paging and page < pageCount)
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
        panel:SetHeight(height + (jumpRoute and 34 or 0) + (showMapCommand and 34 or 0))
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
        panel.noteScroll:SetShown(tracking)
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
        if not panel then
            panel = makePanel(api, function(delta)
                page = math.max(1, page + delta)
                self:Refresh()
            end, function(text, category)
                query = (text or ""):match("^%s*(.-)%s*$"):lower()
                categoryFilter = category or categoryFilter
                page = 1
                self:Refresh()
            end, function(value)
                for _, category in ipairs(categoryOrder) do
                    collapsed[category.key] = value
                end
                collapsed[otherCategory.key] = value
                panel.controls.routeCategoryMenu:Hide()
                panel.controls.routeSearch:ClearFocus()
                page = 1
                self:Refresh()
            end)
            panel:RegisterEvent("DISPLAY_SIZE_CHANGED")
            panel:RegisterEvent("UI_SCALE_CHANGED")
            panel:SetScript("OnEvent", function()
                panel.controls.routeCategoryMenu:Hide()
                if panel:IsShown() and not api.getRoute() then
                    self:Refresh()
                end
            end)
        end
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
