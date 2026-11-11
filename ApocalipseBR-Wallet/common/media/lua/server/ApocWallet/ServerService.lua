require "ApocWallet/Protocol"
if ApocWallet.ServerService then return ApocWallet.ServerService end

local Service = { entries = {}, count = 0, nextUpdate = 0, nextRequest = 0 }
ApocWallet.ServerService = Service
local MAX_PLAYERS, IDENTITY_TIMEOUT, RESPONSE_TIMEOUT = 256, 120000, 60000

local function live(player)
    return player and not player:isDead() and player:getOnlineID() >= 0
        and getPlayerByOnlineID(player:getOnlineID()) == player
end

local function identity(player)
    if not ApocBRModEntities or not ApocBRModEntities.character then return nil, "IDENTITY_API_UNAVAILABLE" end
    local ok, context = pcall(ApocBRModEntities.character, player)
    if not ok or type(context) ~= "table" then return nil, "IDENTITY_UNAVAILABLE" end
    if context.status == "IDENTITY_PENDING" then return nil, "IDENTITY_PENDING" end
    if context.status ~= "OK" or type(context.characterId) ~= "string"
        or not context.characterId:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
        or type(context.session) ~= "string" or #context.session > 80
        or type(context.steamId) ~= "string" or not context.steamId:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$")
        or type(context.sourceServerId) ~= "number" or context.sourceServerId < 1
        or context.sourceServerId > 9007199254740991 or context.sourceServerId % 1 ~= 0 then
        return nil, "IDENTITY_UNAVAILABLE"
    end
    return context
end

local function snapshot(player, entry)
    return { token = entry.token, onlineId = player:getOnlineID(), status = entry.status,
        balance = entry.balance, error = entry.error }
end

local function notify(player, entry)
    if Service.notify and live(player) then Service.notify(player, snapshot(player, entry)) end
end

local function fail(player, entry, error)
    entry.status, entry.error, entry.balance = "error", error, nil
    notify(player, entry)
end

function Service.login(player, token)
    if not live(player) or type(token) ~= "string" or #token < 1 or #token > 80
        or not token:match("^[%w:%-]+$") then return end
    local now = getTimestampMs()
    local entry = Service.entries[player]
    if not entry then
        if Service.count >= MAX_PLAYERS then
            return { token = token, onlineId = player:getOnlineID(), status = "error", error = "WALLET_BUSY" }
        end
        entry = { token = token, status = "loading", started = now, lastReply = now }
        Service.entries[player], Service.count = entry, Service.count + 1
    else
        -- Repeated/forged login commands never refresh a completed balance or spawn another request.
        if now - entry.lastReply < 2000 then return end
        entry.token, entry.lastReply = token, now
    end
    return snapshot(player, entry)
end

local function submit(player, entry, context, now)
    if not ApocBrApiBridge or not ApocBrApiBridge.request or not ApocBrApiBridge.isEnabled
        or ApocBrApiBridge.isEnabled() ~= true then
        fail(player, entry, "API_UNAVAILABLE"); return
    end
    -- All dynamic values were validated and come from the authoritative Java context.
    local parameters = string.format('{"runtimeUuid":"%s","sourceServerId":%.0f,"steamId":"%s"}',
        context.characterId, context.sourceServerId, context.steamId)
    entry.context = context
    Service.nextRequest = now + 2000
    local ok, requestId = pcall(ApocBrApiBridge.request, ApocBrApiBridge.CHARACTER_BALANCE, parameters, function(response)
        if Service.entries[player] ~= entry or entry.status ~= "loading" or not live(player)
            or not entry.requestId or type(response) ~= "table" or response.requestId ~= entry.requestId then return end
        local current = identity(player)
        if not current or current.characterId ~= context.characterId or current.session ~= context.session then
            fail(player, entry, "STALE_SESSION"); return
        end
        if response.ok == true and type(response.balance) == "number" and response.balance == response.balance
            and math.abs(response.balance) <= 9007199254740991 then
            entry.status, entry.balance, entry.error = "ready", response.balance, nil
            notify(player, entry)
        else
            local error = type(response.error) == "string" and #response.error <= 80 and response.error or "API_ERROR"
            fail(player, entry, error)
        end
    end)
    if not ok then fail(player, entry, "API_ERROR")
    elseif requestId then entry.requestId, entry.acceptedAt = requestId, now
    else
        local rejection = ApocBrApiBridge.getLastRejection and ApocBrApiBridge.getLastRejection() or "UNAVAILABLE"
        if rejection ~= "THROTTLED" and rejection ~= "QUEUE_FULL" and rejection ~= "BACKEND_COOLDOWN" then
            fail(player, entry, rejection)
        end
    end
end

function Service.update()
    local now = getTimestampMs()
    if now < Service.nextUpdate then return end
    Service.nextUpdate = now + 1000
    local nextPlayer, nextEntry
    for player, entry in pairs(Service.entries) do
        if not live(player) then
            Service.entries[player], Service.count = nil, Service.count - 1
        elseif entry.status == "loading" then
            if entry.requestId then
                if now - entry.acceptedAt >= RESPONSE_TIMEOUT then fail(player, entry, "API_TIMEOUT") end
            elseif now - entry.started >= IDENTITY_TIMEOUT then
                fail(player, entry, "LOGIN_TIMEOUT")
            elseif now >= Service.nextRequest and (not nextEntry or entry.started < nextEntry.started) then
                -- Resolve pending imports independently: one unready player cannot block everyone else.
                local context, error = identity(player)
                if context then nextPlayer, nextEntry = player, entry
                elseif error ~= "IDENTITY_PENDING" then fail(player, entry, error) end
            end
        end
    end
    if nextEntry then
        local context, error = identity(nextPlayer)
        if context then submit(nextPlayer, nextEntry, context, now)
        elseif error ~= "IDENTITY_PENDING" then fail(nextPlayer, nextEntry, error) end
    end
end

function Service.getState(player)
    local entry = Service.entries[player]
    if not entry or not live(player) then return { status = "idle" } end
    return { status = entry.status, balance = entry.balance, error = entry.error }
end

return Service
