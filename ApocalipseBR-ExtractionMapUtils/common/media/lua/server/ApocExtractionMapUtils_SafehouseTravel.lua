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
    -- Match vanilla ISSafehousesList TELEPORT: registered claim origin, floor zero.
    -- Native teleport initiates destination streaming; no preloaded square is required.
    return safe:getX(), safe:getY()
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
    local x, y = destination(safe)
    local trip = { player = player, x = x, y = y, safe = safe, deadline = now + 20000, started = false }
    if x and atDestination(player, trip) then return outcome("unavailable") end
    pending[identity], count = trip, count + 1
    log("PREPARED", trip, "destination=" .. tostring(x) .. "," .. tostring(y))
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
        elseif now >= trip.deadline then finish(identity, trip, trip.started and "arrival_timeout" or (not trip.armed and "response_not_armed_timeout" or "departure_timeout"))
        elseif player:getVehicle() then finish(identity, trip, "in_vehicle")
        elseif trip.started and atDestination(player, trip) then
            -- A requested packet alone never consumes the six-hour allowance.
            cooldowns[identity] = now
            pending[identity], count = nil, count - 1
            log("ARRIVED", trip, "cooldownHours=6 storage=memory")
        elseif trip.armed and not trip.started then
            if SafeHouse.hasSafehouse(player) ~= trip.safe then
                finish(identity, trip, "safehouse_changed")
            elseif now >= trip.departAt then
                local a, b = destination(trip.safe)
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
log("LOADED", nil, "revision=5 cooldownStorage=memory destination=claim_origin")
return T
