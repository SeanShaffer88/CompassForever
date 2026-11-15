local _, ns = ...
local maxSteps, maxLocations, maxRevealRoutes, maxCheckpoints = 128, 24, 256, 256
local maxFinishedRoutes = 256
local revealLevels = { clue = true, distance = true, coordinates = true, full = true }

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function finite(value)
    return readable(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function validID(value)
    return finite(value) and value >= 1 and value <= 2147483647 and value == math.floor(value)
end

local function validReveal(value)
    return readable(value) and type(value) == "string" and revealLevels[value] == true
end

local function safeText(value, limit)
    if not readable(value) or type(value) ~= "string" then
        return nil
    end
    if #value > limit then
        -- Keep the last complete UTF-8 character so game fonts can display the result.
        while limit > 0 and value:byte(limit + 1) >= 128 and value:byte(limit + 1) < 192 do
            limit = limit - 1
        end
        value = value:sub(1, limit)
    end
    value = value:gsub("[%z\1-\31\127|]", " "):match("^%s*(.-)%s*$")
    return value ~= "" and value or nil
end

local function safeURL(value)
    if readable(value) and type(value) == "string" and #value <= 384
        and value:match("^https://[%w.-]+/[^%s%c|]+$") then
        return value
    end
end

function ns.NormalizeSecretWaypoint(waypoint)
    if not readable(waypoint) or type(waypoint) ~= "table" then
        return nil
    end
    local mapID, x, y = waypoint.mapID, waypoint.x, waypoint.y
    if validID(mapID)
        and finite(x) and x >= 0 and x <= 1 and finite(y) and y >= 0 and y <= 1 then
        return { mapID = mapID, x = x, y = y, label = safeText(waypoint.label, 120) }
    end
end

function ns.NormalizeSecretRoute(route)
    if not readable(route) or type(route) ~= "table" or not readable(route.steps)
        or type(route.steps) ~= "table" then
        return nil
    end
    local id, title = safeText(route.id, 404), safeText(route.title, 160)
    if not id or not title then
        return nil
    end
    local steps = {}
    for i = 1, math.min(#route.steps, maxSteps) do
        local raw = route.steps[i]
        if readable(raw) and type(raw) == "table" then
            local title, note = safeText(raw.title, 180), safeText(raw.note, 1200)
            local waypoints = {}
            if readable(raw.waypoints) and type(raw.waypoints) == "table" then
                for j = 1, math.min(#raw.waypoints, maxLocations) do
                    local waypoint = ns.NormalizeSecretWaypoint(raw.waypoints[j])
                    if waypoint then
                        waypoints[#waypoints + 1] = waypoint
                    end
                end
            end
            if title or note or #waypoints > 0 then
                local questID = validID(raw.completionQuestID) and raw.completionQuestID or nil
                steps[#steps + 1] = {
                    title = title or ("Step %d"):format(#steps + 1),
                    note = note,
                    clue = safeText(raw.clue, 300),
                    travelHint = safeText(raw.travelHint, 240),
                    completionQuestID = questID,
                    completionOnAccept = questID and readable(raw.completionOnAccept) and raw.completionOnAccept == true or nil,
                    optional = readable(raw.optional) and raw.optional == true or nil,
                    waypoints = waypoints,
                }
            end
        end
    end
    if #steps > 0 then
        local ongoing = readable(route.ongoing) and route.ongoing == true or nil
        local legacyResumeStep = ongoing and validID(route.legacyResumeStep)
            and route.legacyResumeStep <= #steps and route.legacyResumeStep or nil
        return {
            id = id, title = title, steps = steps, sourceURL = safeURL(route.sourceURL),
            ongoing = ongoing, legacyResumeStep = legacyResumeStep,
        }
    end
end

function ns.SecretFaction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if readable(faction) then
        if faction == "Alliance" then
            return "alliance"
        elseif faction == "Horde" then
            return "horde"
        end
    end
end

local function boundedIndex(index, limit)
    return finite(index) and math.max(1, math.min(limit, math.floor(index))) or 1
end

local function questCheck(check, questID)
    if type(check) == "function" then
        local ok, completed = pcall(check, questID)
        return ok and readable(completed) and completed == true
    end
    return false
end

local function verifiedComplete(step)
    local questID = step.completionQuestID
    return questID and C_QuestLog and
        (questCheck(C_QuestLog.IsQuestFlaggedCompleted, questID)
            or (step.completionOnAccept and questCheck(C_QuestLog.IsOnQuest, questID)))
end

local function normalizeCheckpoint(raw)
    if not readable(raw) or type(raw) ~= "table" or not readable(raw.sourceURL) then
        return
    end
    local title, sourceURL = safeText(raw.stepTitle, 180), safeURL(raw.sourceURL)
    if not title or (raw.sourceURL ~= nil and not sourceURL) then
        return
    end
    if not readable(raw.completionQuestID) or (raw.completionQuestID ~= nil and not validID(raw.completionQuestID)) then
        return
    end
    return {
        sourceURL = sourceURL, stepTitle = title, completionQuestID = raw.completionQuestID,
        waypoint = ns.NormalizeSecretWaypoint(raw.waypoint),
    }
end

local function uniqueStepIndex(route, title, questID)
    local selected
    for index, step in ipairs(route.steps) do
        if step.title == title and step.completionQuestID == questID then
            if selected then
                return
            end
            selected = index
        end
    end
    return selected
end

local function checkpointFor(route, index, locationIndex)
    local step = route.steps[index]
    if uniqueStepIndex(route, step.title, step.completionQuestID) then
        return {
            sourceURL = route.sourceURL, stepTitle = step.title, completionQuestID = step.completionQuestID,
            waypoint = ns.NormalizeSecretWaypoint(step.waypoints[locationIndex]),
        }
    end
end

local function matchingCheckpoint(route, checkpoint)
    if not checkpoint or checkpoint.sourceURL ~= route.sourceURL then
        return
    end
    local selected = uniqueStepIndex(route, checkpoint.stepTitle, checkpoint.completionQuestID)
    if selected and checkpoint.waypoint then
        local saved = checkpoint.waypoint
        for locationIndex, waypoint in ipairs(route.steps[selected].waypoints) do
            if waypoint.mapID == saved.mapID and waypoint.x == saved.x and waypoint.y == saved.y then
                return selected, locationIndex
            end
        end
    end
    if selected then
        return selected, 1
    end
end

function ns.CreateSecretTracker(savedState, onChanged)
    local tracker = {}
    local reveals, revealCount = {}, 0
    if readable(savedState.reveals) and type(savedState.reveals) == "table" then
        for id, level in pairs(savedState.reveals) do
            if revealCount == maxRevealRoutes then
                break
            end
            if readable(id) and type(id) == "string" and safeText(id, 404) == id and validReveal(level) and level ~= "clue" then
                reveals[id] = level
                revealCount = revealCount + 1
            end
        end
    end
    savedState.reveals = reveals
    local checkpoints, checkpointCount = {}, 0
    if readable(savedState.checkpoints) and type(savedState.checkpoints) == "table" then
        for id, raw in pairs(savedState.checkpoints) do
            if checkpointCount == maxCheckpoints then
                break
            end
            if readable(id) and type(id) == "string" and safeText(id, 404) == id then
                local checkpoint = normalizeCheckpoint(raw)
                if checkpoint then
                    checkpoints[id] = checkpoint
                    checkpointCount = checkpointCount + 1
                end
            end
        end
    end
    savedState.checkpoints = checkpoints

    local finishedRoutes, finishedCount = {}, 0
    if readable(savedState.finishedRoutes) and type(savedState.finishedRoutes) == "table" then
        for id, record in pairs(savedState.finishedRoutes) do
            if finishedCount == maxFinishedRoutes then
                break
            end
            if readable(id) and type(id) == "string" and safeText(id, 404) == id
                and readable(record) and type(record) == "table" and readable(record.sourceURL) then
                local sourceURL = safeURL(record.sourceURL)
                if record.sourceURL == nil or sourceURL then
                    finishedRoutes[id] = { sourceURL = sourceURL }
                    finishedCount = finishedCount + 1
                end
            end
        end
    end
    savedState.finishedRoutes = finishedRoutes

    local function forget(id)
        if checkpoints[id] then
            checkpoints[id] = nil
            checkpointCount = checkpointCount - 1
        end
    end

    local function remember(route, index, locationIndex)
        local checkpoint = checkpointFor(route, index, locationIndex)
        if not checkpoint then
            forget(route.id)
            return
        end
        if not checkpoints[route.id] then
            if checkpointCount == maxCheckpoints then
                forget(next(checkpoints))
            end
            checkpointCount = checkpointCount + 1
        end
        checkpoints[route.id] = checkpoint
    end
    local function select(route, index, locationIndex)
        savedState.route = route
        savedState.index = route and boundedIndex(index, #route.steps) or nil
        local step = route and route.steps[savedState.index]
        savedState.locationIndex = step and boundedIndex(locationIndex, #step.waypoints) or nil
    end

    select(ns.NormalizeSecretRoute(savedState.route), savedState.index, savedState.locationIndex)

    function tracker:GetRoute()
        return savedState.route, savedState.index, savedState.locationIndex
    end

    function tracker:GetCurrentStep()
        local route, index, locationIndex = self:GetRoute()
        local step = route and route.steps[index]
        if step then
            return step, step.waypoints[locationIndex]
        end
    end

    function tracker:GetReveal()
        local route = self:GetRoute()
        return route and reveals[route.id] or "clue"
    end

    function tracker:SetReveal(level)
        local route = self:GetRoute()
        if not route or not validReveal(level) or self:GetReveal() == level then
            return false
        end
        local id = route.id
        if level == "clue" then
            reveals[id] = nil
            revealCount = revealCount - 1
        elseif reveals[id] then
            reveals[id] = level
        else
            if revealCount == maxRevealRoutes then
                reveals[next(reveals)] = nil
                revealCount = revealCount - 1
            end
            reveals[id] = level
            revealCount = revealCount + 1
        end
        onChanged()
        return true
    end

    function tracker:GetSuggestedStep()
        local route, selected = self:GetRoute()
        if route then
            local hasRequiredStep = false
            for index, step in ipairs(route.steps) do
                if not step.optional then
                    hasRequiredStep = true
                    if not verifiedComplete(step) then
                        if index > selected then
                            return index
                        end
                        return
                    end
                end
            end
            return nil, hasRequiredStep
        end
    end

    local function hasFinishRecord(route)
        local finished = finishedRoutes[route.id]
        return finished ~= nil and finished.sourceURL == route.sourceURL
    end

    local function resumeStep(route, checkpoint)
        local index, location = matchingCheckpoint(route, checkpoint)
        if not index and route.legacyResumeStep and hasFinishRecord(route) then
            return route.legacyResumeStep
        end
        return index, location
    end

    function tracker:GetResumeStep(route)
        local clean = ns.NormalizeSecretRoute(route)
        if clean then
            return resumeStep(clean, checkpoints[clean.id])
        end
    end

    function tracker:HasFinished(route)
        local clean = ns.NormalizeSecretRoute(route)
        return clean ~= nil and not clean.ongoing and hasFinishRecord(clean)
    end

    function tracker:Track(route)
        local clean = ns.NormalizeSecretRoute(route)
        if not clean then
            return false
        end
        local previous, index, locationIndex = self:GetRoute()
        local checkpoint = checkpoints[clean.id]
        if previous then
            if previous.id == clean.id and previous.sourceURL == clean.sourceURL then
                checkpoint = checkpointFor(previous, index, locationIndex)
            else
                remember(previous, index, locationIndex)
            end
        end
        local checkpointIndex, checkpointLocation = resumeStep(clean, checkpoint)
        select(clean, checkpointIndex, checkpointLocation)
        onChanged()
        return true
    end

    function tracker:Step(delta)
        local route, index = self:GetRoute()
        if not route or (delta ~= -1 and delta ~= 1) then
            return false
        end
        return self:Jump(index + delta)
    end

    function tracker:Jump(index)
        local route, selected = self:GetRoute()
        if not route or not finite(index) or index ~= math.floor(index) or not route.steps[index] or index == selected then
            return false
        end
        select(route, index)
        onChanged()
        return true
    end

    function tracker:CycleLocation()
        local step = self:GetCurrentStep()
        if not step or #step.waypoints < 2 then
            return false
        end
        savedState.locationIndex = savedState.locationIndex % #step.waypoints + 1
        onChanged()
        return true
    end

    function tracker:Stop()
        local route, index, locationIndex = self:GetRoute()
        if not route then
            return false
        end
        remember(route, index, locationIndex)
        select(nil)
        onChanged()
        return true
    end

    function tracker:Finish()
        local route, index = self:GetRoute()
        if not route or route.ongoing or index ~= #route.steps then
            return false
        end
        if not finishedRoutes[route.id] then
            if finishedCount == maxFinishedRoutes then
                finishedRoutes[next(finishedRoutes)] = nil
            else
                finishedCount = finishedCount + 1
            end
        end
        finishedRoutes[route.id] = { sourceURL = route.sourceURL }
        forget(route.id)
        select(nil)
        onChanged()
        return true
    end

    return tracker
end

local function routeStep(title, note, waypoint, clue, completionQuestID, travelHint)
    return {
        title = title, note = note, waypoints = { waypoint },
        clue = clue, completionQuestID = completionQuestID, travelHint = travelHint,
    }
end

local function alcazRoute(faction)
    local alliance = faction == "alliance"
    local contact = alliance
        and "Take the Document Box to Renzik \"The Shiv\" at SI:7 in Stormwind's Old Town. Complete State Secrets for one Fractured Insignia."
        or "Take the Document Box to Rix Xizzix near the auction house in Booty Bay. Complete State Secrets for one Fractured Insignia."
    return ns.NormalizeSecretRoute({
        id = "alcaz-operative-insignia:" .. faction,
        title = "Alcaz Operative Insignia",
        sourceURL = "https://www.wowhead.com/forever/guide/alcaz-operative-disguise-toy-secret-walkthrough",
        steps = {
            routeStep("Free Mason Connery",
                "Leave the first boss, The Questioner, alive. Find Mason Connery near the end of Alcaz Prison and take "
                    .. "The Man in the Iron Chains. Backtrack to defeat The Questioner, then bring Mason the key and take More Valuable Than Gold.",
                { mapID = 1445, x = 0.753, y = 0.141, label = "Approximate Alcaz Prison entrance" },
                "Leave the first boss alive until you take the prisoner's quest.", 96335,
                "Alcaz Prison is on Alcaz Island off the coast of Dustwallow Marsh."),
            routeStep("Recover the Document Box",
                "Accept More Valuable Than Gold from Mason before leaving the prison. "
                    .. "Upstairs in the Moonbrook inn, inspect the loose floorboards and turn in the quest "
                    .. "to get the Document Box. Keep the box for the next step.",
                { mapID = 1436, x = 0.434, y = 0.678, label = "Moonbrook Inn" },
                "The note sends you to a place where travellers once stopped for the night.", 96337,
                "The destination is in Westfall."),
            routeStep("Deliver the Document Box", contact,
                alliance and { mapID = 1453, x = 0.783, y = 0.711, label = 'Renzik "The Shiv"' }
                    or { mapID = 1434, x = 0.285, y = 0.758, label = "Rix Xizzix" },
                "Someone will recognize the importance of what you found.", alliance and 96377 or nil,
                alliance and "The contact is in Stormwind City." or "The contact is in Booty Bay, in Stranglethorn Vale."),
            routeStep("Assemble the Alcaz Operative Insignia",
                "Gather six Fractured Insignia in total. The pieces are tradeable, so you can obtain the rest from other "
                    .. "players. Combine all six to create the toy.",
                nil, "Your reward is one piece of something larger."),
        },
    })
end

local function scarletBannerRoute()
    return ns.NormalizeSecretRoute({
        id = "scarlet-banner",
        title = "Scarlet Banner",
        sourceURL = "https://www.wowhead.com/forever/guide/collections/scarlet-banner-puzzle-locations",
        steps = {
            routeStep("Collect the Arathi Echo",
                "Find the grave behind the large northern barn at Go'shek Farm and loot the Arathi Echo.",
                { mapID = 1417, x = 0.622, y = 0.545, label = "Approximate Arathi grave" },
                "Look behind a farm building for a grave."),
            routeStep("Collect the Theramore Echo",
                "Loot the Theramore Echo in the small roadside graveyard north of Theramore, before the bridge to the isle.",
                { mapID = 1445, x = 0.637, y = 0.424, label = "Approximate Theramore grave" },
                "A grave outside the island settlement holds another echo."),
            routeStep("Collect the Swamp Echo",
                "Find the grave near the western road into the Swamp of Sorrows and loot the Swamp Echo.",
                { mapID = 1435, x = 0.168, y = 0.538, label = "Approximate Swamp grave" },
                "Search near the road on the western edge of the marsh."),
            routeStep("Collect the Graveyard Echo",
                "Take the far-left portal into the Scarlet Monastery Graveyard. Look inside the fenced graves on the left, "
                    .. "about halfway through the yard, and loot the Graveyard Echo.",
                { mapID = 1420, x = 0.826, y = 0.338, label = "Scarlet Monastery entrance" },
                "The last echo rests among the fenced graves.",
                nil, "The pin leads to the monastery in Tirisfal Glades. The grave is inside the instance."),
            routeStep("Solve the Library Statue Puzzle",
                "Take the far-right portal into the Scarlet Monastery Library with all four Echoes. Use them in order: "
                    .. "Swamp at Warrior, Arathi at Mage, Theramore at Paladin, Graveyard at Priest. "
                    .. "Loot the banner from the glowing object in the middle of the room.",
                nil, "Match each echo to a statue. The order of the statues in the hall is different from the ritual order."),
        },
    })
end

local function musicalGustjumperRoute()
    return ns.NormalizeSecretRoute({
        id = "musical-gustjumper",
        title = "Musical Gustjumper",
        sourceURL = "https://www.wowhead.com/forever/item=268109/musical-gustjumper",
        steps = {
            routeStep("Sing to the Frogs",
                "Target a frog on the rock at the top of the waterfall and use /sing. Interact with the frog that appears "
                    .. "nearby, then use the item to learn the Musical Gustjumper.",
                { mapID = 2521, x = 0.515, y = 0.723, label = "Waterfall frogs" },
                "Listen by the waterfall. The locals may answer a tune."),
        },
    })
end

local function nightWatchmansTorchRoute()
    return ns.NormalizeSecretRoute({
        id = "night-watchmans-torch",
        title = "Night Watchman's Torch",
        sourceURL = "https://warcraft-secrets.com/guides/night-watchmans-torch",
        steps = {
            {
                title = "Find a Fallen Night Watch Guard",
                note = "Look for a fallen Night Watch Guard at any of the search locations. "
                    .. "Accept An Unfortunate End from the guard and turn it in there to receive the torch. "
                    .. "Use Next Location if the guard is absent.",
                clue = "Search for a watcher who never returned from patrol.",
                waypoints = {
                    { mapID = 1431, x = 0.170, y = 0.546, label = "Raven Hill lookout" },
                    { mapID = 1431, x = 0.226, y = 0.736, label = "Addle's Stead lookout" },
                    { mapID = 1431, x = 0.234, y = 0.334, label = "Raven Hill Cemetery lookout" },
                    { mapID = 1431, x = 0.287, y = 0.333, label = "Northern Raven Hill Cemetery lookout" },
                    { mapID = 1431, x = 0.300, y = 0.676, label = "Vul'Gol Ogre Mound lookout" },
                    { mapID = 1431, x = 0.454, y = 0.792, label = "Stranglethorn road lookout" },
                    { mapID = 1431, x = 0.476, y = 0.596, label = "Twilight Grove entrance lookout" },
                    { mapID = 1431, x = 0.660, y = 0.338, label = "Brightwood Grove lookout" },
                    { mapID = 1431, x = 0.688, y = 0.696, label = "Rotting Orchard lookout" },
                },
            },
        },
    })
end

local function lynTheIgnoredRoute()
    return ns.NormalizeSecretRoute({
        id = "lyn-the-ignored",
        title = "Lyn the Ignored",
        sourceURL = "https://www.wowhead.com/forever/news/how-to-find-the-secret-boss-in-the-city-of-dalaran-dungeon-in-wow-forever-383366",
        steps = {
            routeStep("Retrieve the Black Tome",
                "Defeat Archmage Arugal in Shadowfang Keep and take the Black Tome from the book on his table.",
                { mapID = 1421, x = 0.448, y = 0.678, label = "Shadowfang Keep entrance" },
                "Search the archmage's quarters after the fight.",
                nil, "The pin leads to the dungeon entrance in Silverpine Forest."),
            routeStep("Create the Tome of Dalaran",
                "Find the floating blue crystal in the Ambermill town hall. Use the Black Tome next to the "
                    .. "Ambermill Leyline Focus to turn it into the Tome of Dalaran.",
                { mapID = 1421, x = 0.634, y = 0.643, label = "Ambermill Leyline Focus" },
                "The tome reacts to a source of magic in a nearby town."),
            routeStep("Enter the City of Dalaran",
                "Gather a group with access to the City of Dalaran through the sewer gate. Bring the Tome of Dalaran. "
                    .. "The Dalaran Sewer Key opens the gate.",
                { mapID = 1416, x = 0.085, y = 0.593, label = "Approximate Dalaran sewer entrance" },
                "Look for a way into the city from below.",
                nil, "The pin marks the approach to the sewer gate in the Alterac Mountains."),
            routeStep("Summon Lyn the Ignored",
                "Defeat Atrexis the Grave Knight. Continue straight through the sewers instead of turning right "
                    .. "to the surface. Use the Tome of Dalaran at the purple summoning circle, then defeat Lyn.",
                nil, "After the first boss, stay below and look for an unassuming side room."),
        },
    })
end

local function dawnWakerRoute(faction)
    local ealaane = { mapID = 2521, x = 0.6594, y = 0.7437, label = "Ealaane Nimbuswalker" }
    local route = {
        id = "dawn-waker-eluviana",
        title = "Dawn Waker (Known Steps)",
        sourceURL = "https://www.wowhead.com/forever/guide/dawn-waker-secret-walkthrough",
        ongoing = true,
        legacyResumeStep = 6,
        steps = {
            {
                title = "Secure the Ancient Heirloom",
                note = "If you already have the Ancient Heirloom ring, continue to the next step. You can find "
                    .. "a ring on the upper floor of the tower in Thendal Village. If Ailee Farheart offers "
                    .. "Coming of Age, you can also turn that quest in to Rorian the Dayseeker for the ring.",
                clue = "Look for a family keepsake high above the village.",
                waypoints = {
                    { mapID = 2521, x = 0.417, y = 0.234, label = "Ancient Heirloom tower" },
                    { mapID = 2521, x = 0.428, y = 0.234, label = "Ailee Farheart" },
                },
            },
            routeStep("Reveal the Ancient Hilt",
                "At the Ruins of Ban'aethal, light the area with a Night Watchman's Torch or ask a friend to "
                    .. "light it for you. Interact with the revealed Ancient Hilt and accept its quest.",
                { mapID = 2521, x = 0.5813, y = 0.2406, label = "Ancient Hilt" },
                "Old ruins may reveal more by torchlight."),
            routeStep("Show Ealaane the Hilt",
                "Turn in The Ancient Hilt to Ealaane Nimbuswalker and talk to her about what else may be hidden on the isle.",
                ealaane, "Find someone who recognizes the old craftsmanship."),
            {
                title = "Search for the Ancient Sword",
                note = "Interact with the Ancient Sword to collect the Ancient Skyborne Blade. The sword appears "
                    .. "at different locations. Use Next Location to check another reported spot.",
                clue = "Look for an old blade in places travellers rarely stop.",
                waypoints = {
                    { mapID = 2521, x = 0.476, y = 0.719, label = "Mountainside lookout" },
                    { mapID = 2521, x = 0.489, y = 0.727, label = "Second mountainside lookout" },
                    { mapID = 2521, x = 0.505, y = 0.444, label = "Lake bottom lookout" },
                    { mapID = 2521, x = 0.599, y = 0.822, label = "Floating island below the bridge" },
                    { mapID = 2521, x = 0.663, y = 0.432, label = "Riverbank above the waterfall" },
                },
            },
            routeStep("Claim Eluvi'ana",
                "Take the Ancient Skyborne Blade to Ealaane Nimbuswalker to receive Eluvi'ana. Keep the sword, "
                    .. "the Ancient Hilt, and the Ancient Heirloom for the next part of the hunt.",
                ealaane, "Return to the person who sent you looking."),
        },
    }
    local steps = route.steps
    local function append(step)
        steps[#steps + 1] = step
    end

    if faction == "alliance" then
        append(routeStep("Gather Mathystral Amulet Fragments",
            "Collect 20 Mathystral Amulet Fragments from Stormscale naga at the Ruins of Mathystra in Darkshore.",
            { mapID = 1439, x = 0.594, y = 0.213, label = "Ruins of Mathystra search area" },
            "Search the ruins for pieces of an old relic."))
        append(routeStep("Summon Baron Marinous",
            "Combine the 20 fragments at the Fathom Stone at the bottom of the spiral staircase. Use the "
                .. "amulet there, defeat Baron Marinous, and loot the Clouded Water Globe.",
            { mapID = 1439, x = 0.589, y = 0.226, label = "Fathom Stone approach" },
            "Reassemble the relic where it belongs, then face what answers."))
        append(routeStep("Recover the Befouled Water Globe from Onu",
            "Turn in the quest from the Clouded Water Globe to Onu in the Grove of the Ancients, "
                .. "then speak with him again to receive the Befouled Water Globe.",
            { mapID = 1439, x = 0.436, y = 0.764, label = "Onu" },
            "Ask a guardian of the grove about your find."))
    else
        append(routeStep("Recover the Strange Water Globe",
            "Defeat Baron Aquanis in Blackfathom Deeps and loot the Strange Water Globe. If the Baron "
                .. "has not appeared, a party member on Amongst the Ruins can use the Fathom Stone to summon him.",
            { mapID = 1440, x = 0.145, y = 0.142, label = "Blackfathom Deeps exterior approach" },
            "An elemental in a sunken ruin guards the next lead."))
        append(routeStep("Recover the Befouled Water Globe from Je'neu",
            "Turn in the quest from the Strange Water Globe to Je'neu Sancrea at Zoram'gar Outpost, "
                .. "then speak with him again to receive the Befouled Water Globe.",
            { mapID = 1440, x = 0.116, y = 0.342, label = "Je'neu Sancrea" },
            "Bring your find to the coastal outpost and ask about it again."))
    end

    local spirit = { mapID = 1440, x = 0.1568, y = 0.1933, label = "Highborne Spirit" }
    local mordent = { mapID = 2652, x = 0.3505, y = 0.4649, label = "Mordent Evenshade" }
    local direMaulWest = { mapID = 1444, x = 0.603, y = 0.318, label = "Approximate Dire Maul West approach" }
    append(routeStep("Speak with the Highborne Spirit",
        "Equip the Ancient Heirloom ring and bring the Befouled Water Globe to the Highborne Spirit "
            .. "at Zoram Strand in Ashenvale. Ask about the globe.",
        spirit, "An old keepsake may let you speak to someone on the shore."))
    append(routeStep("Recover Narassin's Tome",
        "Climb the Tower of Althalaxx in Darkshore. Defeat Athrikus Narassin, loot the Azsharan Key, "
            .. "and open the lockbox behind him to collect Narassin's Tome.",
        { mapID = 1439, x = 0.564, y = 0.265, label = "Tower of Althalaxx approach" },
        "The spirit's lead takes you to the top of an old tower."))
    append(routeStep("Return to the Highborne Spirit",
        "With the Ancient Heirloom equipped, return to the Highborne Spirit with Narassin's Tome.",
        spirit, "Take what you found back to the shore."))
    append(routeStep("Ask Mordent Evenshade About the Globe",
        "Take the Ancient Hilt, Eluvi'ana, Narassin's Tome, and the Befouled Water Globe to Mordent "
            .. "Evenshade in Shen'dralas. Speak with him about the three reagents needed to cleanse the globe. "
            .. "You can collect them in any order and use Go to Step to switch between them.",
        mordent, "Find a scholar who recognizes the objects you carry."))
    append({
        title = "Recover the Star of Elune",
        note = "Bring five players to the Ruins of Isildien and equip the Ancient Heirloom ring to see the "
            .. "Shen'dralar Vault and switches. Put four players at the switches and one at the vault. "
            .. "Activate all four switches at the same time, then have the player at the vault loot the Star of Elune. "
            .. "Use Next Location to see each switch.",
        clue = "A sealed vault requires several people to act together.",
        waypoints = {
            { mapID = 1444, x = 0.585, y = 0.716, label = "Shen'dralar Vault" },
            { mapID = 1444, x = 0.585, y = 0.710, label = "Ancient Switch on the Upper Floor" },
            { mapID = 1444, x = 0.573, y = 0.717, label = "Ancient Switch" },
            { mapID = 1444, x = 0.597, y = 0.720, label = "Ancient Switch" },
            { mapID = 1444, x = 0.611, y = 0.736, label = "Ancient Switch" },
        },
    })
    append(routeStep("Recover the Abyssal Mote",
        "Complete the quest chain from Kirith through Azsharite if you have not already done it. "
            .. "It starts with the Fallen Hero of the Horde in the Swamp of Sorrows. Then open the "
            .. "Abyssal Chest underwater in Azshara to loot the Abyssal Mote.",
        { mapID = 1447, x = 0.660, y = 0.541, label = "Underwater Abyssal Chest" },
        "Follow the old trail, then look beneath the water."))
    append(routeStep("Gather Tears of Anguish",
        "After speaking to Mordent, collect 20 Tears of Anguish from Anguished and Suffering Highborne "
            .. "at Lake Kel'theril in Winterspring. The ring is optional for these drops.",
        { mapID = 1452, x = 0.536, y = 0.432, label = "Lake Kel'theril search area" },
        "Search around a frozen lake for what the spirits leave behind."))
    append(routeStep("Report Back to Mordent",
        "With the Star of Elune, Abyssal Mote, and 20 Tears of Anguish in your bags, return to "
            .. "Mordent in Shen'dralas. He directs you to the cleansing shrine.",
        mordent, "Bring your findings back to the scholar."))
    append(routeStep("Cleanse the Water Globe",
        "Bring the Befouled Water Globe and all three reagents to the Shrine of Coalescence in Hyjal. "
            .. "Use the globe from your bags at the shrine to obtain the Cleansed Water Globe.",
        { mapID = 2482, x = 0.727, y = 0.372, label = "Shrine of Coalescence" },
        "The objects you gathered can be used at a shrine."))
    append(routeStep("Show Mordent the Cleansed Globe",
        "Take the Cleansed Water Globe to Mordent in Shen'dralas. Follow his new dialogue about "
            .. "Narassin and Prince Tortheldrin.",
        mordent, "Ask the scholar what the ritual revealed."))
    append(routeStep("Speak with Prince Tortheldrin",
        "Reach Prince Tortheldrin in the Capital Gardens, the west wing of Dire Maul. Ask him about "
            .. "Eluvi'ana and Eluvi'tor before anyone defeats him. He mentions those honored in his court.",
        direMaulWest, "A prince in the old gardens may know about the blades.",
        nil, "This pin marks the exterior approach. The prince is inside the west wing."))
    append(routeStep("Obtain the Arcanum of Binding",
        "Obtain a Libram of Binding from Dire Maul enemies. In the Athenaeum, bring it, one Pristine Black Diamond, "
            .. "two Large Brilliant Shards, and one Arcane Crystal to Lorekeeper Lydros for an Arcanum of Binding. "
            .. "His Libram of Binding quest requires level 57 and completion of Elven Legends.",
        direMaulWest, "A lorekeeper can turn a recovered libram into something useful.",
        nil, "This pin marks the exterior approach. Lorekeeper Lydros is inside the Athenaeum."))
    append(routeStep("Show the Bound Hilt to the Prince",
        "Use the Arcanum of Binding on the Ancient Hilt, then speak to Prince Tortheldrin with the bound hilt "
            .. "in your bags before anyone defeats him. He gives you the Scrawled Note.",
        direMaulWest, "Bring the newly bound object back to the prince.",
        nil, "This pin marks the exterior approach. The prince is inside the west wing."))
    append(routeStep("Raise Eluvi'ana at Altairus",
        "Return to Altairus at the Ruins of Ban'aethal with the bound hilt and Eluvi'ana. Place the hilt in front "
            .. "of him and wait for his breath and departure. Click the placed hilt and finish the channel "
            .. "to raise Eluvi'ana.",
        { mapID = 2521, x = 0.583, y = 0.245, label = "Approximate Altairus Location" },
        "Bring the hilt and blade back to the ruined site."))
    append(routeStep("Trail Goes Cold",
        "Raising Eluvi'ana at Altairus is the last confirmed action. The result of the ritual and the next step "
            .. "are still unverified. Pause here to keep your place.",
        nil, "You have reached the last confirmed lead."))

    return ns.NormalizeSecretRoute(route)
end

local function manualScavengerHuntRoute()
    return ns.NormalizeSecretRoute({
        id = "manual-scavenger-hunt",
        title = "Manual Scavenger Hunt",
        sourceURL = "https://www.wowhead.com/forever/news/the-secret-finding-discord-is-sleuthing-again-in-wow-forever-383414",
        ongoing = true,
        steps = {
            {
                title = "Last Known: Burnt Page at Thoradin's Wall",
                note = "The page was in a barrel beside the Cozy Sleeping Bag at Thoradin's Wall. Start the "
                    .. "climb from the Hillsbrad side, then check the barrel. The page's clue points to the "
                    .. "Undercity sewers. Live players have reported mixed results when looking for the page.",
                clue = "Last known site. Look near the old wall. The object may no longer be visible.",
                waypoints = {
                    { mapID = 1417, x = 0.2269, y = 0.2417, label = "Last Known Burnt Page" },
                    { mapID = 1424, x = 0.8761, y = 0.4791, label = "Last Known Wall Climb Approach" },
                },
            },
            routeStep("Last Known: Undercity Keystone Fragment",
                "Players found Torn Pages in a barrel among debris inside the back entrance to the Undercity "
                    .. "sewers. The knife between the book's pages yielded the uncommon Keystone Fragment. "
                    .. "The page refers to page 155 of the printed manual. The object was "
                    .. "later reported missing or moved. Alliance players should watch for Horde guards.",
                { mapID = 1458, x = 0.2286, y = 0.3619, label = "Last Known Torn Pages and Knife" },
                "Last known site. Search beneath the city. The object was reported missing or moved."),
            {
                title = "Last Known: Riverglades Stone Key",
                note = "The pack behind a sleeping Twilight Peon was reported to require the uncommon "
                    .. "Keystone Fragment and held the Stone Key. Use the cliff approach before looking "
                    .. "below. The pack had moved here from Blackrock Mountain during beta and was later "
                    .. "reported missing or moved again. Its present location is unconfirmed.",
                clue = "Last known site. Check below the cliff. The object was reported missing or moved.",
                waypoints = {
                    { mapID = 2548, x = 0.2656, y = 0.4558, label = "Last Known Stone Key Pack" },
                    { mapID = 2548, x = 0.2672, y = 0.4774, label = "Last Known Cliff Jump-Off" },
                },
            },
            routeStep("Last Known: Burnt Page at Dreadmaul Hold",
                "The second Burnt Page was at Dreadmaul Hold in the Blasted Lands and required the Stone Key. "
                    .. "Its riddle refers to three mysterious places, including a tomb and a place associated "
                    .. "with heat and light. The page was reported missing or moved. The full riddle remains unsolved.",
                { mapID = 1419, x = 0.4519, y = 0.1647, label = "Last Known Dreadmaul Hold Burnt Page" },
                "Last known site. A riddle points to three places. The object was reported missing or moved."),
            {
                title = "Last Known: Un'Goro Hidden Stash",
                note = "Players revealed a stash in Ringo's cave with the Night Watchman's Torch lit. "
                    .. "Use the Torch route in the journal if you still need one. The stash's availability "
                    .. "in the live game, how to open it, and its connection to the hunt remain unconfirmed.",
                clue = "Last known site. A lit torch once revealed a stash. Its current status is uncertain.",
                waypoints = {
                    { mapID = 1449, x = 0.5216, y = 0.4964, label = "Last Known Hidden Stash in Ringo's Cave" },
                    { mapID = 1449, x = 0.5248, y = 0.5110, label = "Last Known Stash Cave Approach" },
                },
            },
            routeStep("Unresolved: Stonetalon Brittle Key",
                "A stash in the tent by the sleeping bag quest camp at 40.71, 52.75 in Stonetalon Mountains "
                    .. "once yielded a Brittle Key that lasted one hour. The stash was reported missing or moved. "
                    .. "Its relationship to the manual hunt remains unconfirmed.",
                nil, "Unresolved side clue. A timed key's source was reported missing or moved."),
            routeStep("Standing Torch at the Former Cache",
                "A standing torch marks the former Traveler's Cache site in Stranglethorn Vale. "
                    .. "During beta, the Brittle Key opened the cache. Players reported finding a Torn Page "
                    .. "about calm before a storm, while others found Pocket Lint. The old cache is missing. "
                    .. "This visit is optional because the torch's purpose and its connection to the hunt remain unresolved.",
                { mapID = 1434, x = 0.1443, y = 0.2715, label = "Standing Torch (Unresolved)" },
                "Unresolved side clue. A standing torch marks the former cache site."),
            routeStep("Unresolved: Alterac Ancient Runestone",
                "A stash under a shield by a wrecked cart was reported at 55.6, 48.3 in the Alterac "
                    .. "Mountains. Players used a lit torch and the uncommon Keystone Fragment to recover "
                    .. "an Ancient Runestone. The stash was later reported missing. The runestone's use and "
                    .. "its connection to the manual hunt remain unknown.",
                nil, "Unresolved side clue. An old runestone's whereabouts are uncertain."),
            routeStep("Unresolved: Western Plaguelands Skeletal Chest",
                "An underwater Skeletal Chest was reported at 61.6, 72.8 in the Western Plaguelands. "
                    .. "Reports mention a Keystone Fragment requirement. The chest was later reported missing "
                    .. "or moved. Its current location and role remain unconfirmed.",
                nil, "Unresolved side clue. The whereabouts and lock of an underwater chest are uncertain."),
            routeStep("Unresolved: Stormwind Note",
                "Players documented a note at this Stormwind location. Its connection to the manual hunt "
                    .. "remains unconfirmed. This is an optional check. Horde players can skip the visit.",
                { mapID = 1453, x = 0.6720, y = 0.8253, label = "Reported Stormwind Note" },
                "Unresolved side clue. A note was reported here. Its connection is uncertain."),
            routeStep("Unresolved Clues",
                "Two higher-quality Keystone Fragments remain unlocated. The interpretation of the three "
                    .. "places, the final lock, and any reward remain unconfirmed. A Wowhead comment links a "
                    .. "podcast sign to an outhouse in the Barrens. Players also reported a dead orc in "
                    .. "Redridge and a snake corpse by the Deadmines gate. Whether any relate to the hunt "
                    .. "remains unverified. The exact order of the clues is unconfirmed. Pause here to keep your place.",
                nil, "The remaining clues are unresolved. You have reached the end of the documented trail."),
        },
    })
end

local function excitableSlimeRoute()
    return ns.NormalizeSecretRoute({
        id = "excitable-slime",
        title = "Excitable Slime",
        sourceURL = "https://warcraft-secrets.com/guides/excitable-slime",
        steps = {
            routeStep("Buy Nutritious Slime Sludge",
                "Horde only. In Undercity's Apothecarium, find Boyle on the dock and buy Nutritious Slime Sludge. "
                    .. "Keep one portion in your bags for the next step.",
                { mapID = 1458, x = 0.555, y = 0.641, label = "Boyle's dock (approximate)" },
                "A vendor in the Apothecarium sells something the slime wants."),
            {
                title = "Dance for an Excitable Slime",
                note = "From solid ground, target an Excitable Slime and repeat /dance until it wriggles. "
                    .. "Interact with it and turn in the quest \"WRIGGLE.\" with one Nutritious Slime Sludge. "
                    .. "Dance again if it loses interest. Use the pet item you receive to learn it. "
                    .. "The slime patrols the green canals; both pins are approximate search areas.",
                clue = "Try dancing for a slime that patrols the canals.",
                waypoints = {
                    { mapID = 1458, x = 0.523, y = 0.584, label = "Excitable Slime patrol search area" },
                    { mapID = 1458, x = 0.509, y = 0.534, label = "Alternate patrol search area" },
                },
            },
        },
    })
end

local function silverOfTheWavesRoute()
    return ns.NormalizeSecretRoute({
        id = "silver-of-the-waves",
        title = "Silver of the Waves",
        sourceURL = "https://www.wowhead.com/forever/quest=86614/silver-of-the-waves",
        steps = {
            {
                title = "Find the Discarded Fishing Toolbox",
                note = "Alliance, level 13 or higher. Dive to the lakebed in Loch Modan and look near the wrecked boats. "
                    .. "Open the toolbox and accept Silver of the Waves to get the Monogrammed Silver Hair Clip. "
                    .. "Use Next Location to check the other reported toolbox sites.",
                clue = "Look for a lost keepsake near the wrecks at the bottom of the loch.",
                waypoints = {
                    { mapID = 1432, x = 0.481, y = 0.396, label = "Toolbox search area" },
                    { mapID = 1432, x = 0.456, y = 0.434, label = "Alternate toolbox search area" },
                    { mapID = 1432, x = 0.489, y = 0.543, label = "Southern toolbox search area" },
                },
            },
            routeStep("Return the hair clip",
                "Bring the clip to Khara Deepwater in the fishing hut on the western shore of the loch, near Thelsamar.",
                { mapID = 1432, x = 0.395, y = 0.393, label = "Khara Deepwater" },
                "Who on the shore has the initials K.D.?"),
        },
    })
end

local function applejackStillRoute()
    return ns.NormalizeSecretRoute({
        id = "applejack-still",
        title = "Applejack Still",
        sourceURL = "https://wowhandbook.com/news/applejack-still-elwynn-forest/",
        steps = {
            routeStep("Get four Shiny Red Apples",
                "Alliance. Buy Shiny Red Apples from Tharynn Bouden in Goldshire if you need them. "
                    .. "Carry four apples to the still.",
                { mapID = 1429, x = 0.418, y = 0.672, label = "Tharynn Bouden" },
                "Stock up on fruit before looking for the still."),
            routeStep("Brew Thunder Applejack",
                "Interact with the Applejack Still on the hillside by Thunder Falls above Mirror Lake. "
                    .. "Hand in the four apples and take the Thunder Applejack.",
                { mapID = 1429, x = 0.246, y = 0.580, label = "Applejack Still" },
                "Look for a still on the slopes above the water."),
            routeStep("Bring the drink to Sergeant De Vries",
                "Take the Thunder Applejack inside Westbrook Garrison. At level 7 or higher, "
                    .. "accept and turn in An Apple Treat with Sergeant De Vries.",
                { mapID = 1429, x = 0.241, y = 0.732, label = "Sergeant De Vries" },
                "A soldier at the garrison would appreciate a bottle."),
        },
    })
end

local function whisperingHorrorResidueRoute()
    return ns.NormalizeSecretRoute({
        id = "whispering-horror-residue",
        title = "Whispering Horror Residue",
        sourceURL = "https://www.wowhead.com/forever/quest=95328/whispering-horror-residue",
        steps = {
            routeStep("Collect Whispering Horror Residue",
                "Horde, level 7 or higher. Enter the cellar under a ruined building in Shadowvale, Tirisfal Glades. "
                    .. "Defeat the level 11–13 elite Whispering Horror, loot its residue, and use it to start the quest.",
                { mapID = 1420, x = 0.129, y = 0.657, label = "Shadowvale cellar entrance" },
                "The whispers grow louder beneath a ruin in Shadowvale."),
            routeStep("Deliver the residue",
                "Bring the residue to Father Lankester on the outer balcony in Undercity's War Quarter.",
                { mapID = 1458, x = 0.491, y = 0.146, label = "Father Lankester" },
                "A priest in the Undercity may want to study the sample."),
        },
    })
end

local function blessingOfKalimdorRoute()
    return ns.NormalizeSecretRoute({
        id = "blessing-of-kalimdor",
        title = "Blessing of Kalimdor",
        sourceURL = "https://wowhandbook.com/news/blessing-of-kalimdor-set-guide/",
        steps = {
            {
                title = "Hunt Takk the Leaper",
                note = "Search the northern Barrens for Takk the Leaper and hunt for the Raptor Hide Cloak (requires level 16). "
                    .. "The pins mark patrol search areas. The cloak may take more than one kill.",
                clue = "A rare raptor roams the northern Barrens.",
                waypoints = {
                    { mapID = 1413, x = 0.608, y = 0.134, label = "Takk patrol search area" },
                    { mapID = 1413, x = 0.596, y = 0.083, label = "Takk northern search area" },
                    { mapID = 1413, x = 0.586, y = 0.075, label = "Takk western search area" },
                },
            },
            {
                title = "Hunt Swiftmane",
                note = "Search the plains north of Ratchet for the roaming zhevra Swiftmane. "
                    .. "Hunt for the Signet of the Zhevra (requires level 18). Use Next Location to check the patrol area.",
                clue = "Look for a swift zhevra north of Ratchet.",
                waypoints = {
                    { mapID = 1413, x = 0.612, y = 0.345, label = "Swiftmane patrol search area" },
                    { mapID = 1413, x = 0.604, y = 0.329, label = "Swiftmane central search area" },
                    { mapID = 1413, x = 0.606, y = 0.306, label = "Swiftmane northern search area" },
                },
            },
            routeStep("Hunt Humar the Pridelord",
                "Look for the black lion under the large tree north of Ratchet. Hunt for the Mark of the Pack Leader "
                    .. "(requires level 20). Wearing any two pieces increases movement speed in the Barrens and Stonetalon Mountains by 5%.",
                { mapID = 1413, x = 0.621, y = 0.333, label = "Humar's tree" },
                "A rare lion rests in the shade north of Ratchet."),
        },
    })
end

local function travelersSymbolsRoute()
    return ns.NormalizeSecretRoute({
        id = "travelers-symbols",
        title = "Traveler's Symbols",
        sourceURL = "https://www.wowhead.com/forever/guide/travelers-symbols-toy-secret-walkthrough",
        steps = {
            routeStep("Enter Blackrock Depths",
                "Ever After is available to either faction from level 48. Approach Blackrock Mountain from southern "
                    .. "Searing Gorge. Inside, descend the chains past the tomb, enter the quarry, and take the northern "
                    .. "tunnel to Blackrock Depths.",
                { mapID = 1427, x = 0.352, y = 0.842, label = "Approximate Blackrock Mountain approach" },
                "Follow the chains into the lower reaches of Blackrock Mountain."),
            routeStep("Find the bridge east of the Ring of Law",
                "Find the northbound bridge over the lava east of the Ring of Law. Look over the left side for the "
                    .. "friendly Dark Iron dwarf near the base of a pillar. Clear the enemies on the bridge before climbing down.",
                nil, "Look down from a bridge near the arena."),
            routeStep("Reach the Rugged Traveler",
                "By the small brazier, climb onto the left railing and jump to the platform alongside the rock wall. "
                    .. "Hug the wall to the far corner and push into the rock. With your left shoulder against the wall, "
                    .. "move until you slip into the opening, then drop onto the outcrop below. Speak with the Rugged "
                    .. "Traveler to complete Ever After and collect Traveler's Symbols.",
                nil, "The traveler waits below a ledge reached from the bridge railing."),
        },
    })
end

local function bloodyMapRoute()
    local agent = { mapID = 1437, x = 0.5153, y = 0.5935, label = "Deathstalker Agent" }
    return ns.NormalizeSecretRoute({
        id = "bloody-map",
        title = "The Bloody Map (Known Steps)",
        sourceURL = "https://wowhandbook.com/news/bloody-map-excavation-site-wetlands/",
        ongoing = true,
        steps = {
            routeStep("Pick up Dragonmaw Rumors",
                "Horde, level 24 or higher. Find Zaruk at the bottom of the stairs in Hammerfall, Arathi Highlands, "
                    .. "and accept Dragonmaw Rumors.",
                { mapID = 1417, x = 0.7454, y = 0.3564, label = "Zaruk" },
                "Ask around Hammerfall about Dragonmaw activity."),
            routeStep("Take the path above the excavation camp",
                "In the Wetlands, use the uphill path near the excavation to reach the ledge above the camp.",
                { mapID = 1437, x = 0.5317, y = 0.6567, label = "Path up to the Deathstalker Agent" },
                "Look for an uphill approach near the excavation."),
            routeStep("Accept Open the Maw",
                "Turn in Dragonmaw Rumors to the Deathstalker Agent above the excavation camp and accept Open the Maw.",
                agent, "A Deathstalker is watching the excavation from above."),
            routeStep("Clear the excavation",
                "Enter Excavation Site: Wetlands. Defeat two Dragonmaw Saboteurs and four Dragonmaw Warders, "
                    .. "and loot the Dragonmaw Dispatch from a Dragonmaw Thaumaturgist inside.",
                { mapID = 1437, x = 0.478, y = 0.563, label = "Approximate Excavation Site portal" },
                "Follow the Dragonmaw into the excavation and look for their orders."),
            routeStep("Collect the Bloody Map",
                "Return to the Deathstalker Agent and turn in Open the Maw to receive the Bloody Map.",
                agent, "Bring what you recovered back to the lookout."),
            routeStep("Unresolved Destination",
                "Read the Bloody Map and keep it. Its destination and any follow-up are unconfirmed.",
                nil, "The map remains a lead with no confirmed destination."),
        },
    })
end

local function savoryWhimsyfinDelightRoute()
    return ns.NormalizeSecretRoute({
        id = "savory-whimsyfin-delight",
        title = "Savory Whimsyfin Delight",
        sourceURL = "https://wowhandbook.com/news/savory-whimsyfin-delight-recipe/",
        steps = {
            routeStep("Find the recipe in Redridge",
                "Both factions. The tradable recipe is a rare drop from Redridge Mountains enemies. "
                    .. "Search for Great Goretusks in the foothills or buy the recipe from another player.",
                { mapID = 1433, x = 0.272, y = 0.668, label = "Great Goretusk search area" },
                "Creatures in Redridge may carry a recipe with an unusual effect."),
            {
                title = "Fish for Whimsyfin",
                note = "Look for schools of Whimsyfin in Redridge Mountains. Use Next Location to check "
                    .. "other reported fishing areas if a school is missing.",
                clue = "Check the waters of Redridge for a school of unusual fish.",
                waypoints = {
                    { mapID = 1433, x = 0.608, y = 0.699, label = "Whimsyfin school search area" },
                    { mapID = 1433, x = 0.619, y = 0.706, label = "Nearby Whimsyfin search area" },
                    { mapID = 1433, x = 0.744, y = 0.624, label = "Eastern Whimsyfin search area" },
                },
            },
            routeStep("Cook the delight",
                "Learn the recipe at Cooking 85. Use a cooking fire and combine one Whimsyfin with one Mild Spices. "
                    .. "Eating the delight gives a random Orc ninja or pirate disguise.",
                nil, "Combine the fish with a common seasoning over a cooking fire."),
        },
    })
end

local function malignantRootRoute()
    return ns.NormalizeSecretRoute({
        id = "malignant-root",
        title = "Malignant Root",
        sourceURL = "https://www.method.gg/wow-forever/how-to-get-malignant-root-powerful-rare-ring-in-wow-forever",
        steps = {
            {
                title = "Obtain Rotheap Innards",
                note = "Focus your search in the Wetlands waterways at night by realm time. Nightveiled Rotheap is a roaming "
                    .. "level 31–32 elite. Loot its Rotheap Innards or obtain the tradable innards from another player. "
                    .. "The coastal pins are reported search areas.",
                clue = "Search the Wetlands waterways for a creature that stirs at night.",
                waypoints = {
                    { mapID = 1437, x = 0.190, y = 0.520, label = "Southern Rotheap search area" },
                    { mapID = 1437, x = 0.180, y = 0.230, label = "Central Rotheap search area" },
                    { mapID = 1437, x = 0.290, y = 0.170, label = "Northern Rotheap search area" },
                },
            },
            routeStep("Trade with the Greenwarden",
                "Alliance only. Bring the Rotheap Innards to Rethiel the Greenwarden in the Green Belt. "
                    .. "Speak to him with the innards in your bags and select the exchange dialogue to get "
                    .. "Malignant Root. The exchange takes place outside the quest log.",
                { mapID = 1437, x = 0.562, y = 0.405, label = "Rethiel the Greenwarden" },
                "A guardian in the Green Belt may want what you found."),
        },
    })
end

local function dwarvenTradeskillSignpostRoute()
    return ns.NormalizeSecretRoute({
        id = "dwarven-tradeskill-signpost",
        title = "Dwarven Tradeskill Signpost",
        sourceURL = "https://guided.news/en/guides/wow-forever-profession-sign-ironforge-quest-route-materials/",
        steps = {
            routeStep("Buy the license application",
                "Alliance only. Reach Honored with the Azeroth Commerce Authority, then buy the Advertising "
                    .. "License Application from Tamelyn Aldridge at the Three Corners trading post in Redridge "
                    .. "Mountains for 1,200 Merchant's Favor. Use it to start Sign Me Up!",
                { mapID = 1433, x = 0.106, y = 0.713, label = "Tamelyn Aldridge" },
                "Ask the Alliance supply officer how to advertise a trade."),
            routeStep("Submit the completed forms",
                "Use the provided Massive Pile of Forms in your bags. Follow the quest marker in the Three Corners "
                    .. "camp to Elaine Compton, hand in the completed forms, and accept Rotgath Stonebeard.",
                { mapID = 1433, x = 0.102, y = 0.712, label = "Elaine Compton's camp (approximate)" },
                "Finish the paperwork and bring it to the contract coordinator."),
            routeStep("Craft the signpost in Ironforge",
                "Find Rotgath Stonebeard at the Great Forge in Ironforge. Turn in the introduction and accept A Quick "
                    .. "Craft. Bring 25 Mithril Bars, 15 Heavy Leather, and 5 Goldthorn to receive the toy and choose "
                    .. "one profession sign. Use the chosen sign item to register it, then use the toy on a character "
                    .. "who knows that profession.",
                { mapID = 1455, x = 0.524, y = 0.425, label = "Rotgath Stonebeard" },
                "A crafter at the Great Forge can make the sign."),
        },
    })
end

local function aTasteOfHomeRoute()
    local arille = { mapID = 1416, x = 0.185, y = 0.657, label = "Arille Azuregaze" }
    return ns.NormalizeSecretRoute({
        id = "a-taste-of-home",
        title = "A Taste of Home",
        sourceURL = "https://www.wowhead.com/forever/quest=96609/a-taste-of-home#comments",
        steps = {
            routeStep("Accept A Taste of Home",
                "Alliance, level 44 or higher. Speak with bartender Arille Azuregaze in the open-world city of Dalaran. "
                    .. "If you need access to the city, start An Alarming Request with Emissary Jacques in Southshore "
                    .. "and follow the City of Dalaran quest chain.",
                arille, "A bartender in Dalaran misses a drink from home."),
            routeStep("Collect ten bottles of Shimmerwine",
                "Loot 10 bottles of Silvermoon Shimmerwine from blood elves in northern Azshara. Search around the "
                    .. "Thalassian Base Camp for Blood Elf Reclaimers and other blood elves.",
                { mapID = 1447, x = 0.564, y = 0.288, label = "Blood Elf Reclaimer search area" },
                "Look for a camp of blood elves in northeastern Kalimdor."),
            routeStep("Return to Arille Azuregaze",
                "Deliver the 10 bottles to Arille in Dalaran to receive Everlasting Silvermoon Shimmerwine.",
                arille, "Return to the bartender who asked for the wine."),
        },
    })
end

local function orcishTradeskillSignpostRoute()
    return ns.NormalizeSecretRoute({
        id = "orcish-tradeskill-signpost",
        title = "Orcish Tradeskill Signpost",
        sourceURL = "https://www.wowhead.com/forever/guide/durotar-supply-and-logistics-reputation-professions",
        steps = {
            routeStep("Buy the license application",
                "Horde only. Reach Honored with Durotar Supply and Logistics, then buy the Advertising License "
                    .. "Application from Gishah at the supply camp near the Crossroads for 1,200 Merchant's Favor. "
                    .. "Use the application to start Sign Me Up!",
                { mapID = 1413, x = 0.494, y = 0.294, label = "Gishah" },
                "Ask the Horde supply officer how to advertise a trade."),
            routeStep("Submit the completed forms",
                "Use the provided Massive Pile of Forms in your bags. Follow the quest marker in the supply camp "
                    .. "to Jornah, hand in the completed forms, and accept Karolek.",
                { mapID = 1413, x = 0.498, y = 0.294, label = "Jornah's camp (approximate)" },
                "Finish the paperwork and bring it to the contract coordinator."),
            routeStep("Craft the signpost in Orgrimmar",
                "Find Karolek at Kodohide Leatherworkers in the Drag. Turn in the introduction and accept A Quick "
                    .. "Craft. Bring 30 Heavy Leather, 12 Mithril Bars, and 5 Goldthorn to receive the toy and choose "
                    .. "one profession sign. Use the chosen sign item to register it, then use the toy on a character "
                    .. "who knows that profession.",
                { mapID = 1454, x = 0.628, y = 0.444, label = "Karolek" },
                "A leatherworker in the Drag can make the sign."),
        },
    })
end

local function fizsprocketsNotesRoute()
    return ns.NormalizeSecretRoute({
        id = "fizsprockets-notes",
        title = "Fizsprocket's Notes",
        sourceURL = "https://www.wowhead.com/forever/quest=98424/fizsprockets-notes#comments",
        steps = {
            routeStep("Find the Mulgore Expansion Plans",
                "Horde, level 5 or higher. Search inside the Venture Co. Mine for Supervisor Fizsprocket. "
                    .. "Loot the Mulgore Expansion Plans from him and use them to start Fizsprocket's Notes. "
                    .. "The pin marks the approximate south entrance.",
                { mapID = 1412, x = 0.610, y = 0.470, label = "South mine entrance (approximate)" },
                "The supervisor at the Venture Co. Mine is carrying plans."),
            routeStep("Find Shredder Operation Instructions",
                "Pick up the Shredder Operation Instructions inside the Venture Co. Mine.",
                { mapID = 1412, x = 0.586, y = 0.473, label = "Shredder Operation Instructions (approximate)" },
                "Look for instructions left among the mining equipment."),
            routeStep("Find One \"Gerenzo\", of Stonetalon",
                "Pick up One \"Gerenzo\", of Stonetalon inside the Venture Co. Mine.",
                { mapID = 1412, x = 0.590, y = 0.464, label = "Gerenzo notes (approximate)" },
                "Look for notes about someone from Stonetalon."),
            routeStep("Find Barrens Operations Best Practices",
                "Pick up Barrens Operations Best Practices inside the Venture Co. Mine.",
                { mapID = 1412, x = 0.617, y = 0.473, label = "Barrens Operations Best Practices (approximate)" },
                "Look for the company's notes on its Barrens operations."),
            routeStep("Deliver the notes to Morin Cloudstalker",
                "Find Morin Cloudstalker patrolling the road east of Bloodhoof Village. "
                    .. "Turn in the plans and all three pages to finish Fizsprocket's Notes.",
                { mapID = 1412, x = 0.548, y = 0.643, label = "Morin Cloudstalker patrol (approximate)" },
                "Someone on the road near Bloodhoof Village can make use of the plans."),
        },
    })
end

local function condorHatchlingRoute()
    return ns.NormalizeSecretRoute({
        id = "condor-hatchling",
        title = "Condor Hatchling",
        sourceURL = "https://www.wowhead.com/forever/item=282637/shaking-egg#comments",
        steps = {
            {
                title = "Find Lord Condar",
                note = "Either faction can hunt Lord Condar, a roaming level 15–16 rare in southeastern Loch Modan. "
                    .. "Use Next Location to check the search areas near Ironband's Excavation Site. "
                    .. "Defeat Lord Condar and use the Shaking Egg if it drops to learn the Condor Hatchling.",
                clue = "A rare condor flies over the southeast of Loch Modan.",
                waypoints = {
                    { mapID = 1432, x = 0.746, y = 0.708, label = "Lord Condar search area" },
                    { mapID = 1432, x = 0.777, y = 0.749, label = "Southeast Lord Condar search area" },
                    { mapID = 1432, x = 0.747, y = 0.669, label = "Northern Lord Condar search area" },
                },
            },
        },
    })
end

local function tallstriderHatchlingRoute()
    return ns.NormalizeSecretRoute({
        id = "tallstrider-hatchling",
        title = "Tallstrider Hatchling",
        sourceURL = "https://www.wowhead.com/forever/npc=274334/tallstrider-hatchling#comments",
        steps = {
            {
                title = "Find Strider Clutchmother",
                note = "Either faction can hunt Strider Clutchmother, a level 20 rare in southern Darkshore "
                    .. "near the Ashenvale border. Check both reported search spots with Next Location. "
                    .. "Defeat her and use the bind-on-pickup Tallstrider Hatchling item if it drops.",
                clue = "Search southern Darkshore for a tallstrider near the Ashenvale border.",
                waypoints = {
                    { mapID = 1439, x = 0.348, y = 0.873, label = "Strider Clutchmother search area" },
                    { mapID = 1439, x = 0.350, y = 0.880, label = "Reported Strider Clutchmother sighting" },
                },
            },
        },
    })
end

local function babyCrocoliskRoute()
    return ns.NormalizeSecretRoute({
        id = "baby-crocolisk",
        title = "Baby Crocolisk",
        sourceURL = "https://www.wowhead.com/forever/item=282047/baby-crocolisk#comments",
        steps = {
            {
                title = "Find the Sewer Beast",
                note = "Alliance players can hunt the Sewer Beast, a roaming level 50 rare in the Stormwind canals. "
                    .. "Use Next Location to check both canal search areas. Bring a group to help defeat it and earn loot credit. "
                    .. "Use the Baby Crocolisk item if it drops to learn the companion.",
                clue = "Search the Stormwind canals for the rare beast that patrols them.",
                waypoints = {
                    { mapID = 1453, x = 0.712, y = 0.488, label = "Northern Sewer Beast search area" },
                    { mapID = 1453, x = 0.711, y = 0.680, label = "Southern Sewer Beast search area" },
                },
            },
        },
    })
end

function ns.StandaloneSecrets()
    -- Route facts cross-checked against the Forever guides from Method and Wowhead.
    local source = "https://www.wowhead.com/forever/guide/cozy-sleeping-bag-locations-rewards"
    local faction = ns.SecretFaction()
    if not faction then
        return {}
    end
    local alliance = faction == "alliance"
    local chainStart = alliance and 79008 or 79007
    local westfall = { mapID = 1436, x = 0.3714, y = 0.5013, label = "Westfall" }
    local barrens = { mapID = 1413, x = 0.4612, y = 0.7432, label = "The Barrens" }
    local wall = { mapID = 1424, x = 0.8736, y = 0.4962, label = "Thoradin's Wall" }
    local wallAccess = "On the Hillsbrad side of Thoradin's Wall, look for a broken cart where the wall is damaged."
    local remains = "Accept the quest from the Burned-Out Remains "
    local nextQuest = "Turn in the note at the other set of remains and pick up Stepping Stones."
    local start = alliance
        and routeStep("Begin at Alexston Farmstead", remains .. "beside the wrecked cart in Westfall.",
            westfall, "Look for what remains of a journey interrupted among the farm fields.", chainStart,
            "Reach Westfall from western Elwynn Forest, then head toward the farm fields.")
        or routeStep("Begin south of Camp Taurajo", remains .. "inside the scorched tower in the Barrens.",
            barrens, "An old watch post still carries signs of a fire.", chainStart,
            "In the Barrens, follow the road south past Camp Taurajo.")
    start.completionOnAccept = true
    local swap = alliance
        and routeStep("Cross to the Barrens", nextQuest .. " Look for the wooden board near the tower.",
            barrens, "The note points toward another site touched by fire.", chainStart,
            "From the Eastern Kingdoms, the Booty Bay boat lands at Ratchet in the Barrens.")
        or routeStep("Cross to Westfall", nextQuest .. " Search beside the destroyed cart at Alexston Farmstead.",
            westfall, "The note points to a traveller who never made it past the fields.", chainStart,
            "From Kalimdor, the Orgrimmar zeppelin to Grom'gol reaches the Eastern Kingdoms. Westfall lies to the north.")
    local steps = {
        start, swap,
        routeStep("Find the Stonetalon camp",
            "Follow the trail northeast of Sun Rock Retreat and check the Pocket Litter on a crate. "
                .. "Finish Stepping Stones and pick up Scramble. You can also rekindle the campfire for an optional quest.",
            { mapID = 1442, x = 0.406, y = 0.526, label = "Approximate camp location" },
            "Search for a sign that someone sheltered among the high trails.", 79192,
            alliance and "From the Barrens, take the western road into Stonetalon and look for the trail northeast of Sun Rock Retreat."
                or "From the Eastern Kingdoms, the Grom'gol zeppelin reaches Orgrimmar. The Barrens road leads west into Stonetalon."),
        routeStep("Reach the Mound of Dirt",
            "Climb north from the camp and jump across to the mound. Complete Scramble and accept Wet Job.",
            { mapID = 1442, x = 0.3961, y = 0.4988 },
            "Look above the camp for a patch of disturbed earth.", 79980,
            "Start from the camp northeast of Sun Rock Retreat and follow the uphill trail."),
        routeStep("Find the Eagle Figurine",
            "At the Loch Modan dam, use the carved heads on the Wetlands side to reach the figurine. "
                .. "Finish Wet Job and take Eagle's Fist.",
            { mapID = 1432, x = 0.4945, y = 0.1291 },
            "Look for an eagle where old stone holds back the water.", 79974,
            alliance and "Loch Modan is east of Dun Morogh. Approach the dam from the north end of the loch."
                or "From Kalimdor, the Orgrimmar zeppelin to Undercity reaches the Eastern Kingdoms. The dam is at the north end of Loch Modan."),
        routeStep("Reach the Messenger Bag",
            "Climb the cart on the Hillsbrad side of Thoradin's Wall. Go through the opening and look right "
                .. "for the hanging bag. Finish Eagle's Fist and accept This Must Be The Place.",
            wall, "A traveller's belongings hang above an old border crossing.", 79975, wallAccess),
        routeStep("Collect the Cozy Sleeping Bag",
            "Use the Hastily Rolled-Up Satchel below the Messenger Bag to finish the quest.",
            wall, "Look below the last find for one final bundle.", 79976, wallAccess),
    }
    local routes = { ns.NormalizeSecretRoute({
        id = "cozy-sleeping-bag:" .. faction,
        title = "Cozy Sleeping Bag", sourceURL = source, steps = steps,
    }), alcazRoute(faction), scarletBannerRoute(), musicalGustjumperRoute(),
        nightWatchmansTorchRoute(), lynTheIgnoredRoute(), dawnWakerRoute(faction), manualScavengerHuntRoute() }
    if faction == "horde" then
        routes[#routes + 1] = excitableSlimeRoute()
        routes[#routes + 1] = whisperingHorrorResidueRoute()
    else
        routes[#routes + 1] = silverOfTheWavesRoute()
        routes[#routes + 1] = applejackStillRoute()
    end
    routes[#routes + 1] = blessingOfKalimdorRoute()
    routes[#routes + 1] = travelersSymbolsRoute()
    if not alliance then
        routes[#routes + 1] = bloodyMapRoute()
    end
    routes[#routes + 1] = savoryWhimsyfinDelightRoute()
    if alliance then
        routes[#routes + 1] = malignantRootRoute()
        routes[#routes + 1] = dwarvenTradeskillSignpostRoute()
        routes[#routes + 1] = aTasteOfHomeRoute()
    else
        routes[#routes + 1] = orcishTradeskillSignpostRoute()
        routes[#routes + 1] = fizsprocketsNotesRoute()
    end
    routes[#routes + 1] = condorHatchlingRoute()
    routes[#routes + 1] = tallstriderHatchlingRoute()
    if alliance then
        routes[#routes + 1] = babyCrocoliskRoute()
    end
    return routes
end
