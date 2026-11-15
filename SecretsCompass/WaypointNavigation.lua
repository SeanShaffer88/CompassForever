local _, ns = ...

local titleFormat = "SecretsCompass Destination %d"

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function getProvider()
    local provider = TomTom
    if readable(provider) and type(provider) == "table" and type(provider.AddWaypoint) == "function"
        and type(provider.RemoveWaypoint) == "function" and type(provider.WaypointExists) == "function" then
        return provider
    end
end

local function sameTarget(record, provider, waypoint)
    return record and record.provider == provider and record.mapID == waypoint.mapID
        and record.x == waypoint.x and record.y == waypoint.y
end

local function exists(provider, waypoint, name)
    local ok, result = pcall(provider.WaypointExists, provider, waypoint.mapID, waypoint.x, waypoint.y, name)
    if ok and readable(result) and type(result) == "boolean" then
        return result
    end
end

function ns.CreateWaypointNavigation(onArrival)
    local navigation = {}
    local attempt, owned
    local waypointNumber = 0


    local function refreshOwned()
        local provider = owned.provider
        local present
        if type(provider.IsValidWaypoint) == "function" then
            local ok, result = pcall(provider.IsValidWaypoint, provider, owned.uid)
            if ok and readable(result) and type(result) == "boolean" then
                present = result
            end
        end
        if present == nil then
            present = exists(provider, owned, owned.title)
        end
        if present == true then
            attempt.status = "delegated"
        elseif present == false then
            owned = nil
            attempt.status = "cleared"
        else
            attempt.status = "failed"
        end
        return attempt.status
    end

    function navigation:Sync(waypoint, retryFailed)
        local provider
        if waypoint then
            provider = getProvider()
        end
        if owned and not (provider and sameTarget(owned, provider, waypoint)) then
            local ok, removed = pcall(owned.remove, owned.provider, owned.uid)
            if not ok or not readable(removed) then
                return "cleanupFailed"
            end
            -- Some providers return false when the UID was already removed by the player.
            owned = nil
        end

        if not waypoint then
            attempt = nil
            return
        elseif not provider then
            attempt = nil
            return "unavailable"
        elseif sameTarget(owned, provider, waypoint) then
            return refreshOwned()
        elseif sameTarget(attempt, provider, waypoint) and not (retryFailed and attempt.status == "failed") then
            return attempt.status
        end

        -- TomTom uses the title in its waypoint key. A new suffix keeps later
        -- handoffs independent of earlier points that a player may have replaced.
        waypointNumber = waypointNumber + 1
        local title = titleFormat:format(waypointNumber)
        attempt = { provider = provider, mapID = waypoint.mapID, x = waypoint.x, y = waypoint.y, title = title }
        local duplicate = exists(provider, waypoint, title)
        if duplicate == true then
            attempt.status = "collision"
        elseif duplicate == false then
            local remove = provider.RemoveWaypoint
            local options = {
                title = title, persistent = false, silent = true, crazy = true, from = "SecretsCompass",
                cleardistance = 0, arrivaldistance = 15,
            }
            -- Waypoint Tracker fires arrived before its optional auto-clear. TomTom's
            -- callbacks table replaces its standard waypoint behavior, so leave it alone.
            if onArrival and provider.isWaypointTrackerBridge == true and C_Timer and type(C_Timer.After) == "function" then
                local candidate, queued = attempt, false
                options.callbacks = { arrived = function(_, uid)
                    if queued or owned ~= candidate or not readable(uid) or uid ~= candidate.uid then
                        return
                    end
                    queued = true
                    C_Timer.After(0, function()
                        queued = false
                        if owned == candidate and getProvider() == provider then
                            onArrival(refreshOwned())
                        end
                    end)
                end }
            end
            local ok, uid = pcall(provider.AddWaypoint, provider, waypoint.mapID, waypoint.x, waypoint.y, options)
            if ok and readable(uid) and type(uid) == "table" then
                attempt.remove, attempt.uid = remove, uid
                owned = attempt
                attempt.status = "delegated"
            end
        end
        attempt.status = attempt.status or "failed"
        return attempt.status
    end

    return navigation
end
