if not isServer() then return end
local D = require "ApocExtractionMapUtils_HumanActions"
local T = ApocExtractionMapUtils.SafehouseTravel or {}
ApocExtractionMapUtils.SafehouseTravel = T
if T.loaded then return T end
T.loaded = true
T.COOLDOWN_MS = 6 * 60 * 60 * 1000
-- Account cooldowns belong only to this server process; never restore old ModData.
local cooldowns, pending, count = {}, {}, 0
local function log(event, trip, detail)
    ApocExtractionMapUtils.logOperation("[ApocSafehouseTravel] " .. event .. " player="
        .. tostring(trip and trip.player:getOnlineID() or "-") .. (detail and (" " .. detail) or ""))
end
local function finish(identity, trip, reason)
    if pending[identity] ~= trip then return end
    pending[identity], count = nil, count - 1
    log("CANCELLED", trip, "reason=" .. reason)
end
local function outcome(kind, values)
    return { success = false, close = false, responsePool = "safehouse.teleport." .. kind, values = values }
end
local function connected(player)
    return player and not player:isDead() and getPlayerByOnlineID(player:getOnlineID()) == player
end
local function atDestination(player, trip)
    return math.floor(player:getZ()) == 0 and math.floor(player:getX()) == math.floor(trip.x)
        and math.floor(player:getY()) == math.floor(trip.y)
end
local function destination(safe)
    local x, y = safe:getX() + math.floor(safe:getW() / 2), safe:getY() + math.floor(safe:getH() / 2)
    local xmin, xmax = math.max(safe:getX(), x - 8), math.min(safe:getX() + safe:getW() - 1, x + 8)
    local ymin, ymax = math.max(safe:getY(), y - 8), math.min(safe:getY() + safe:getH() - 1, y + 8)
    local loading, cells, loaded, unavailable = false, {}, 0, 0
    -- Keep every cell intersecting the bounded search alive, including border cells.
    -- Cell readiness is independent of whether its center square exists.
    if ApocBRLobbyStreaming and ApocBRLobbyStreaming.keepCellLoaded then
        for _, a in ipairs({xmin, xmax}) do
            for _, b in ipairs({ymin, ymax}) do
                local key = math.floor(a / 64) .. ":" .. math.floor(b / 64)
                if not cells[key] then
                    cells[key] = true
                    local status = ApocBRLobbyStreaming.keepCellLoaded(a, b)
                    if status == 0 then loading = true
                    elseif status == 1 then loaded = loaded + 1
                    else unavailable = unavailable + 1 end
                end
            end
        end
    end
    local examined = 0
    for radius = 0, 8 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.max(math.abs(dx), math.abs(dy)) == radius then
                    local a, b = x + dx, y + dy
                    if a >= xmin and b >= ymin and a <= xmax and b <= ymax then
                        local tile = getCell():getGridSquare(a, b, 0)
                        if tile then
                            examined = examined + 1
                            if tile:hasFloor() and tile:isFree(false) then return a + 0.5, b + 0.5, false end
                        end
                    end
                end
            end
        end
    end
    local detail = "center=" .. x .. "," .. y .. " loadedCells=" .. loaded
        .. " unavailableCells=" .. unavailable .. " existingSquares=" .. examined
    return nil, nil, loading, detail
end
function T.prepare(ctx)
    local player, api = ctx.player, ApocBRHumanAPI
    if not connected(player) or not api or not api.accountIdentity or not api.teleport then return outcome("unavailable") end
    local identity = api.accountIdentity(player)
    if not identity or pending[identity] or count >= 256 or player:getVehicle() then return outcome("unavailable") end
    local now = getTimestampMs()
    local last = cooldowns[identity]
    if type(last) == "number" and now < last + T.COOLDOWN_MS then
        return outcome("cooldown", { remainingMinutes = tostring(math.ceil((last + T.COOLDOWN_MS - now) / 60000)) })
    end
    local safe = SafeHouse.hasSafehouse(player)
    if not safe then return outcome("no_safehouse") end
    local x, y, loading, detail = destination(safe)
    if not x and not loading then
        log("DESTINATION_UNAVAILABLE", {player=player}, detail)
        return outcome("unavailable")
    end
    local trip = { player = player, x = x, y = y, safe = safe, deadline = now + 60000, started = false, loading = loading, loadingDetail = detail }
    if x and atDestination(player, trip) then return outcome("unavailable") end
    pending[identity], count = trip, count + 1
    log("PREPARED", trip, "destination=" .. tostring(x) .. "," .. tostring(y) .. " loading=" .. tostring(loading == true))
    local function cancel(reason)
        finish(identity, trip, reason or "response_not_completed")
    end
    return { success = true, responsePool = "safehouse.teleport.success", close = true,
        cancel = cancel,
        -- Called once only after a validated response has been spoken and sent.
        afterResponse = function()
            if not connected(player) then cancel("disconnected_before_arm"); return end
            if SafeHouse.hasSafehouse(player) ~= safe then cancel("safehouse_changed_before_arm"); return end
            if player:getVehicle() then cancel("in_vehicle_before_arm"); return end
            trip.armed = true
            trip.departAt = getTimestampMs() + 2500
            log("ARMED", trip, "departureDelayMs=2500")
        end }
end
D.registerAction("player.teleport_safehouse", T.prepare)
local function updateTrip(identity, trip, now)
        local player = trip.player
        if not connected(player) then finish(identity, trip, "disconnected_or_dead")
        elseif now >= trip.deadline then finish(identity, trip, trip.started and "arrival_timeout" or (not trip.armed and "response_not_armed_timeout" or (trip.loading and ("destination_loading_timeout " .. tostring(trip.loadingDetail)) or "departure_timeout")))
        elseif player:getVehicle() then finish(identity, trip, "in_vehicle")
        elseif trip.started and atDestination(player, trip) then
            -- A requested packet alone never consumes the six-hour allowance.
            cooldowns[identity] = now
            pending[identity], count = nil, count - 1
            log("ARRIVED", trip, "cooldownHours=6 storage=memory")
        elseif trip.armed and not trip.started then
            -- Cold destinations load without blocking Lua or moving into an unverified square.
            if SafeHouse.hasSafehouse(player) ~= trip.safe then
                finish(identity, trip, "safehouse_changed")
            else
                local a, b, loading, detail = destination(trip.safe)
                trip.loading, trip.loadingDetail = loading, detail
                if a and now >= trip.departAt then
                    trip.x, trip.y = a, b
                    if atDestination(player, trip) then
                        finish(identity, trip, "already_at_destination")
                    else
                        local ok, accepted = pcall(ApocBRHumanAPI.teleport, player, a, b, 0)
                        if ok and accepted == true then
                            trip.started = true
                            trip.deadline = now + 20000
                            log("TELEPORT_SENT", trip, "destination=" .. a .. "," .. b .. ",0")
                        else finish(identity, trip, ok and "bridge_rejected" or ("bridge_error: " .. tostring(accepted))) end
                    end
                elseif not a and not loading then finish(identity, trip, "no_valid_landing_tile " .. tostring(detail))
                elseif loading and not trip.loadingLogged then
                    trip.loadingLogged = true
                    log("WAITING_FOR_DESTINATION", trip, detail)
                end
            end
        end
end
local nextCheck = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < nextCheck then return end
    nextCheck = now + 250
    for identity, trip in pairs(pending) do
        local ok, errorMessage = pcall(updateTrip, identity, trip, now)
        if not ok then finish(identity, trip, "tick_error: " .. tostring(errorMessage)) end
    end
end)
log("LOADED", nil, "revision=4 cooldownStorage=memory")
return T
