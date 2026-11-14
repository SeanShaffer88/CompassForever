local _, ns = ...
local hostName = "SecretChecklist"
local maxEntries, maxNodes, maxDepth, maxLocations = 1024, 128, 4, 24

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function isTable(value)
    return readable(value) and type(value) == "table"
end

local function selectedEntry(entries, url)
    if not isTable(entries) or not readable(url) or type(url) ~= "string"
        or url == "" or #url > 384 or #entries > maxEntries then
        return nil
    end
    local match
    for _, entry in ipairs(entries) do
        if isTable(entry) and readable(entry.guideURL) and entry.guideURL == url then
            if match then
                return nil
            end
            match = entry
        end
    end
    return match
end

local function makeRoute(entry)
    if not isTable(entry.steps) then
        return nil
    end
    local faction = ns.SecretFaction()
    local steps, remaining = {}, maxNodes
    local function append(list, depth)
        if depth > maxDepth or not isTable(list) then
            return
        end
        for i = 1, math.min(#list, remaining) do
            if remaining == 0 then
                return
            end
            remaining = remaining - 1
            local raw = list[i]
            if isTable(raw) then
                local waypoints = {}
                if isTable(raw.waypoints) then
                    for j = 1, math.min(#raw.waypoints, maxLocations) do
                        local waypoint = ns.NormalizeSecretWaypoint(raw.waypoints[j])
                        if waypoint then
                            waypoints[#waypoints + 1] = waypoint
                        end
                    end
                end
                if #waypoints == 0 then
                    local waypoint = faction and isTable(raw.factionWaypoint)
                        and ns.NormalizeSecretWaypoint(raw.factionWaypoint[faction])
                    waypoint = waypoint or ns.NormalizeSecretWaypoint(raw.waypoint)
                    if waypoint then
                        waypoints[1] = waypoint
                    end
                end
                local children = raw.substeps
                if faction and isTable(raw.factionSubsteps) and isTable(raw.factionSubsteps[faction]) then
                    children = raw.factionSubsteps[faction]
                end
                local hasChildren = isTable(children) and #children > 0
                if #waypoints > 0 or (readable(raw.note) and raw.note) or not hasChildren then
                    steps[#steps + 1] = { title = raw.label, note = raw.note, waypoints = waypoints }
                end
                if hasChildren then
                    append(children, depth + 1)
                elseif isTable(raw.factionSubsteps) and not faction then
                    steps[#steps + 1] = {
                        title = "Faction-specific instructions",
                        note = "Return to this guide when your character's faction is available.",
                    }
                end
            end
        end
    end
    append(entry.steps, 1)
    return ns.NormalizeSecretRoute({
        id = "secret-checklist:" .. entry.guideURL,
        title = entry.name,
        sourceURL = entry.guideURL,
        steps = steps,
    })
end

function ns.AttachSecretChecklist(track)
    local events = CreateFrame("Frame")
    local attached, scheduled
    local function tryAttach()
        scheduled = false
        if attached then
            return
        end
        local host = _G[hostName]
        local panel, link
        if isTable(host) then
            panel, link = host.guidesPanel, host.guidesLinkBtn
        end
        if not (isTable(panel) and isTable(link) and type(link.GetParent) == "function" and isTable(host.entries)) then
            return
        end
        local parent = link:GetParent()
        if not isTable(parent) then
            return
        end

        local button = CreateFrame("Button", "SecretCompassSecretChecklistTrackButton", parent, "UIPanelButtonTemplate")
        button:SetSize(112, 22)
        button:SetPoint("RIGHT", link, "LEFT", -6, 0)
        button:SetText("Track Secret")
        button:SetScript("OnClick", function()
            local entry = selectedEntry(host.entries, link.currentURL)
            local route = entry and makeRoute(entry)
            if route and track(route) then
                return
            end
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("SecretCompass: select a supported SecretChecklist guide.")
            end
        end)

        attached = true
        events:UnregisterEvent("ADDON_LOADED")
        events:UnregisterEvent("PLAYER_LOGIN")
    end

    local function schedule()
        if attached or scheduled then
            return
        end
        if C_Timer and type(C_Timer.After) == "function" then
            scheduled = true
            C_Timer.After(0, tryAttach)
        else
            tryAttach()
        end
    end
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_LOGIN" or name == hostName then
            schedule()
        end
    end)
    schedule()
end
