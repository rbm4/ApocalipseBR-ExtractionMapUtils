require "ApocWallet/Protocol"
local Operation = require "ApocWallet/Operation"
local Diagnostics = require "ApocWallet/Diagnostics"
if ApocWallet.ServerService then return ApocWallet.ServerService end

local Service = { entries = {}, pending = {}, pendingCount = 0, count = 0,
    nextUpdate = 0, nextRequest = 0, nextPrune = 0 }
ApocWallet.ServerService = Service
local MAX_PLAYERS, IDENTITY_TIMEOUT, RESPONSE_TIMEOUT = 256, 120000, 60000

local function workChanged()
    if Service.onWorkChanged then Service.onWorkChanged(Service.pendingCount > 0) end
end

local function live(player)
    return player and not player:isDead() and player:getOnlineID() >= 0
        and getPlayerByOnlineID(player:getOnlineID()) == player
end

local function identity(player)
    if not ApocBRModEntities or not ApocBRModEntities.character then return nil, "IDENTITY_API_UNAVAILABLE" end
    local ok, context = pcall(ApocBRModEntities.character, player)
    if not ok or type(context) ~= "table" then return nil, "IDENTITY_UNAVAILABLE" end
    if context.status == "IDENTITY_PENDING" then return nil, "IDENTITY_PENDING" end
    if context.status == "OK" and (context.steamId == nil or context.sourceServerId == nil) then
        return nil,"IDENTITY_API_OUTDATED"
    end
    if context.status == "OK" and (type(context.steamId) ~= "string"
        or not context.steamId:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$")) then
        return nil,"INVALID_STEAM_ID"
    end
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

local function snapshot(player, entry, cached)
    return { token = entry.token, onlineId = player:getOnlineID(), status = entry.status,
        balance = entry.balance, error = entry.error, updatedAt = entry.updatedAt, cached = cached == true }
end

local function notify(player, entry)
    if Service.notify and entry.token and live(player) then Service.notify(player, snapshot(player, entry)) end
end

local function finish(player, entry, status, balance, error)
    if entry.status ~= "loading" then return end
    entry.status, entry.balance, entry.error = status, balance, error
    Diagnostics.stage(entry,"COMPLETE",error or "OK")
    if status == "ready" then entry.updatedAt = getTimestampMs() end
    if Service.pending[player] == entry then
        Service.pending[player], Service.pendingCount = nil, Service.pendingCount - 1
    end
    workChanged()
    notify(player, entry)
    Operation.resolve(entry.operation, { status = status, balance = balance, error = error,
        updatedAt = entry.updatedAt, cached = false })
end

local function fail(player, entry, error) finish(player, entry, "error", nil, error) end

local function drop(player, entry)
    if Service.entries[player] ~= entry then return end
    Service.entries[player], Service.count = nil, Service.count - 1
    fail(player, entry, "CANCELLED")
end

local function load(player, refresh, now)
    local entry = Service.entries[player]
    if entry and entry.status ~= "loading" and entry.context then
        local current = identity(player)
        if not current or current.characterId ~= entry.context.characterId or current.session ~= entry.context.session then
            drop(player, entry)
            entry = Service.entries[player]
        end
    end
    if entry and (entry.status == "loading" or not refresh
        or now - entry.started < ApocWallet.Protocol.MIN_REFRESH_MS) then return entry end
    if not entry and Service.count >= MAX_PLAYERS then return nil end
    local nextEntry = { status = "loading", started = now, lastReply = entry and entry.lastReply,
        operation = Operation.new() }
    if not entry then Service.count = Service.count + 1 end
    Service.entries[player], Service.pending[player] = nextEntry, nextEntry
    Service.pendingCount = Service.pendingCount + 1
    Service.nextUpdate = 0
    workChanged()
    return nextEntry
end

local function requestBalance(player, callback, refresh)
    assert(callback == nil or type(callback) == "function", "Wallet callback must be a function")
    if not live(player) then
        Operation.deliver(callback, { status = "error", error = "PLAYER_UNAVAILABLE" })
        return function() end
    end
    local entry = load(player, refresh, getTimestampMs())
    if not entry then
        Operation.deliver(callback, { status = "error", error = "WALLET_BUSY" })
        return function() end
    end
    if entry.status == "loading" then return Operation.subscribe(entry.operation, callback) end
    Operation.deliver(callback, { status = entry.status, balance = entry.balance, error = entry.error,
        updatedAt = entry.updatedAt, cached = entry.status == "ready" })
    return function() end
end

function Service.requestBalance(player, callback) return requestBalance(player, callback, false) end
function Service.refreshBalance(player, callback) return requestBalance(player, callback, true) end

function Service.login(player, token, refresh)
    if not live(player) or type(token) ~= "string" or #token < 1 or #token > 80
        or not token:match("^[%w:%-]+$") then return end
    local now = getTimestampMs()
    local old = Service.entries[player]
    if old and old.lastReply and now - old.lastReply < 2000 then return end
    local entry = load(player, refresh == true, now)
    if not entry then
        return { token = token, onlineId = player:getOnlineID(), status = "error", error = "WALLET_BUSY" }
    end
    entry.token, entry.lastReply = token, now
    Diagnostics.log("server","COMMAND_ACCEPTED",token,refresh and "REFRESH" or "LOGIN")
    return snapshot(player, entry, entry.status == "ready")
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
            finish(player, entry, "ready", response.balance)
        else
            local error = type(response.error) == "string" and #response.error <= 80 and response.error or "API_ERROR"
            fail(player, entry, error)
        end
    end)
    if not ok then fail(player, entry, "API_ERROR")
    elseif requestId then
        entry.requestId, entry.acceptedAt = requestId, now
        Diagnostics.stage(entry,"API_ACCEPTED","QUEUED")
    else
        local rejection = ApocBrApiBridge.getLastRejection and ApocBrApiBridge.getLastRejection() or "UNAVAILABLE"
        Diagnostics.stage(entry,"API_WAIT",rejection)
        if rejection ~= "THROTTLED" and rejection ~= "QUEUE_FULL" and rejection ~= "BACKEND_COOLDOWN" then
            fail(player, entry, rejection)
        end
    end
end

function Service.update()
    if Service.pendingCount == 0 then return end
    local now = getTimestampMs()
    if now < Service.nextUpdate then return end
    Service.nextUpdate = now + 1000
    local nextPlayer, nextEntry, nextContext
    for player, entry in pairs(Service.pending) do
        if not live(player) then
            drop(player, entry)
        elseif entry.status == "loading" then
            if entry.requestId then
                if now - entry.acceptedAt >= RESPONSE_TIMEOUT then fail(player, entry, "API_TIMEOUT") end
            elseif now - entry.started >= IDENTITY_TIMEOUT then
                fail(player, entry, "LOGIN_TIMEOUT")
            elseif now >= Service.nextRequest and (not nextEntry or entry.started < nextEntry.started) then
                -- Resolve pending imports independently: one unready player cannot block everyone else.
                local context, error = identity(player)
                if context then nextPlayer, nextEntry, nextContext = player, entry, context
                elseif error ~= "IDENTITY_PENDING" then fail(player, entry, error)
                else Diagnostics.stage(entry,"IDENTITY_WAIT","IDENTITY_PENDING") end
            end
        end
    end
    if nextEntry and Service.pending[nextPlayer] == nextEntry and live(nextPlayer) then
        submit(nextPlayer, nextEntry, nextContext, now)
    end
end

function Service.getState(player)
    local entry = Service.entries[player]
    if not entry or not live(player) then return { status = "idle" } end
    return { status = entry.status, balance = entry.balance, error = entry.error, updatedAt = entry.updatedAt }
end

-- Cache cleanup is independent of request scheduling. Never refreshes a balance.
function Service.prune()
    if Service.count == 0 then return end
    local now = getTimestampMs()
    if now < Service.nextPrune then return end
    Service.nextPrune = now + 10000
    for player, entry in pairs(Service.entries) do
        if not live(player) then drop(player, entry) end
    end
end

return Service
