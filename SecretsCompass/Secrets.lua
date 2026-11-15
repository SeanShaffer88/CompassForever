local _, ns = ...
local maxSteps, maxLocations, maxRevealRoutes, maxCheckpoints = 128, 24, 256, 256
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
        return { id = id, title = title, steps = steps, sourceURL = safeURL(route.sourceURL) }
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

    function tracker:GetResumeStep(route)
        local clean = ns.NormalizeSecretRoute(route)
        if clean then
            return matchingCheckpoint(clean, checkpoints[clean.id])
        end
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
        local checkpointIndex, checkpointLocation = matchingCheckpoint(clean, checkpoint)
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
        local route = self:GetRoute()
        if not route then
            return false
        end
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
    return { ns.NormalizeSecretRoute({
        id = "cozy-sleeping-bag:" .. faction,
        title = "Cozy Sleeping Bag", sourceURL = source, steps = steps,
    }), alcazRoute(faction) }
end
