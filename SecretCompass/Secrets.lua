local _, ns = ...
local maxSteps, maxLocations = 128, 24

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function finite(value)
    return readable(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
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
    if finite(mapID) and mapID >= 1 and mapID <= 2147483647 and mapID == math.floor(mapID)
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
                steps[#steps + 1] = { title = title or ("Step %d"):format(#steps + 1), note = note, waypoints = waypoints }
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

function ns.CreateSecretTracker(savedState, onChanged)
    local tracker = {}
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

    function tracker:Track(route)
        local clean = ns.NormalizeSecretRoute(route)
        if not clean then
            return false
        end
        local previous, index, locationIndex = self:GetRoute()
        if previous and clean.id == previous.id and clean.sourceURL == previous.sourceURL then
            select(clean, index, locationIndex)
        else
            select(clean)
        end
        onChanged()
        return true
    end

    function tracker:Step(delta)
        local route, index = self:GetRoute()
        if not route or (delta ~= -1 and delta ~= 1) or not route.steps[index + delta] then
            return false
        end
        select(route, index + delta)
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
        if not savedState.route then
            return false
        end
        select(nil)
        onChanged()
        return true
    end

    return tracker
end

local function routeStep(title, note, mapID, x, y, label)
    return { title = title, note = note, waypoints = { { mapID = mapID, x = x, y = y, label = label } } }
end

function ns.StandaloneSecrets()
    -- Route facts cross-checked against the Forever guides from Method and Wowhead.
    local source = "https://www.wowhead.com/forever/guide/cozy-sleeping-bag-locations-rewards"
    local faction = ns.SecretFaction()
    if not faction then
        return {}
    end
    local westfall = faction == "alliance"
    local remains = "Accept the quest from the Burned-Out Remains "
    local nextQuest = "Turn in the note at the other set of remains and pick up Stepping Stones."
    local start = westfall
        and routeStep("Begin at Alexston Farmstead", remains .. "beside the wrecked cart in Westfall.",
            1436, 0.3714, 0.5013, "Westfall")
        or routeStep("Begin south of Camp Taurajo", remains .. "inside the scorched tower in the Barrens.",
            1413, 0.4612, 0.7432, "The Barrens")
    local swap = westfall
        and routeStep("Cross to the Barrens", nextQuest .. " Look for the wooden board near the tower.",
            1413, 0.4612, 0.7432, "The Barrens")
        or routeStep("Cross to Westfall", nextQuest .. " Search beside the destroyed cart at Alexston Farmstead.",
            1436, 0.3714, 0.5013, "Westfall")
    local steps = {
        start, swap,
        routeStep("Find the Stonetalon camp",
            "Follow the trail northeast of Sun Rock Retreat and check the Pocket Litter on a crate. "
                .. "Finish Stepping Stones and pick up Scramble. You can also rekindle the campfire for an optional quest.",
            1442, 0.406, 0.526, "Approximate camp location"),
        routeStep("Reach the Mound of Dirt",
            "Climb north from the camp and jump across to the mound. Complete Scramble and accept Wet Job.",
            1442, 0.3961, 0.4988, "Stonetalon Mountains"),
        routeStep("Find the Eagle Figurine",
            "At the Loch Modan dam, use the carved heads on the Wetlands side to reach the figurine. "
                .. "Finish Wet Job and take Eagle's Fist.",
            1432, 0.4945, 0.1291, "Loch Modan"),
        routeStep("Reach the Messenger Bag",
            "Climb the cart on the Hillsbrad side of Thoradin's Wall. Go through the opening and look right "
                .. "for the hanging bag. Finish Eagle's Fist and accept This Must Be The Place.",
            1424, 0.8736, 0.4962, "Thoradin's Wall"),
        routeStep("Collect the Cozy Sleeping Bag",
            "Use the Hastily Rolled-Up Satchel below the Messenger Bag to finish the quest.",
            1424, 0.8736, 0.4962, "Thoradin's Wall"),
    }
    return { ns.NormalizeSecretRoute({
        id = "cozy-sleeping-bag:" .. faction,
        title = "Cozy Sleeping Bag", sourceURL = source, steps = steps,
    }) }
end
