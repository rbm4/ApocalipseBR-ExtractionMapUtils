require "ApocWallet/Protocol"
local Operation = require "ApocWallet/Operation"
local Diagnostics = require "ApocWallet/Diagnostics"
if ApocWallet.ClientService then return ApocWallet.ClientService end

local Protocol = ApocWallet.Protocol
local Service = { entries = {}, sequence = 0, pending = 0, nextCheck = 0 }
ApocWallet.ClientService = Service

local function workChanged()
    if Service.onWorkChanged then Service.onWorkChanged(Service.pending > 0) end
end

local function state(entry)
    return { status = entry.status, balance = entry.balance, error = entry.error,
        updatedAt = entry.updatedAt, cached = entry.cached }
end

local function finish(entry, status, balance, error, updatedAt, cached)
    if entry.status ~= "loading" then return end
    entry.status, entry.balance, entry.error = status, balance, error
    entry.updatedAt, entry.cached = updatedAt, cached
    entry.completedAt = getTimestampMs()
    Diagnostics.log("client","COMPLETE",entry.token,error or "OK")
    Service.pending = Service.pending - 1
    workChanged()
    Operation.resolve(entry.operation, state(entry))
end

local function request(index, callback, refresh)
    assert(callback == nil or type(callback) == "function", "Wallet callback must be a function")
    index = index or 0
    local player = getSpecificPlayer(index)
    if Service.clearing or not player or player:isDead() then
        Operation.deliver(callback, { status = "error", error = Service.clearing and "CANCELLED" or "PLAYER_UNAVAILABLE" })
        return function() end
    end
    local entry = Service.entries[index]
    if entry and entry.player ~= player then
        Service.entries[index] = nil
        finish(entry, "error", nil, "CANCELLED")
        entry = Service.entries[index]
    end
    if refresh and entry and entry.completedAt
        and getTimestampMs() - entry.completedAt < Protocol.MIN_REFRESH_MS then refresh = false end
    if refresh and entry and entry.status == "loading" and entry.sent
        and getTimestampMs() - entry.lastSentAt >= Protocol.MIN_REFRESH_MS then
        -- Explicit user action may retry delivery of the same intent. This is
        -- not a polling loop and never changes the correlation token/deadline.
        entry.sent = false
        Service.nextCheck = 0
        Diagnostics.log("client","MANUAL_RETRY",entry.token,"PENDING")
    end
    if not entry or (refresh and entry.status ~= "loading") then
        Service.sequence = Service.sequence + 1
        local now = getTimestampMs()
        entry = { player = player, status = "loading", started = now, refresh = refresh,
            token = string.format("%.0f:%.0f", now, Service.sequence), operation = Operation.new() }
        Service.entries[index], Service.pending = entry, Service.pending + 1
        Diagnostics.log("client","QUEUED",entry.token,refresh and "REFRESH" or "LOGIN")
        Service.nextCheck = 0
        workChanged()
    end
    if entry.status == "loading" then return Operation.subscribe(entry.operation, callback) end
    local result = state(entry); result.cached = result.status == "ready"
    Operation.deliver(callback, result)
    return function() end
end

-- Cached read or join/start one operation. Cached callbacks may run immediately.
function Service.requestBalance(index, callback) return request(index, callback, false) end
-- Explicit operation for opening/reopening a UI; never starts a polling loop.
function Service.refreshBalance(index, callback) return request(index, callback, true) end

function Service.begin(index, player)
    if player and getSpecificPlayer(index) == player and not player:isDead() then Service.requestBalance(index) end
end

function Service.update()
    if Service.pending == 0 then return end
    local now = getTimestampMs()
    if now < Service.nextCheck then return end
    Service.nextCheck = now + 250
    for index, entry in pairs(Service.entries) do
        if entry.status == "loading" then
            if getSpecificPlayer(index) ~= entry.player or entry.player:isDead() then
                Service.entries[index] = nil
                finish(entry, "error", nil, "CANCELLED")
            elseif now - entry.started >= Protocol.CLIENT_TIMEOUT_MS then
                finish(entry, "error", nil, "REQUEST_TIMEOUT")
            elseif not entry.sent and entry.player:getOnlineID() >= 0 then
                entry.sent = true
                entry.lastSentAt = now
                Diagnostics.log("client","SEND",entry.token,entry.refresh and "REFRESH" or "LOGIN")
                sendClientCommand(entry.player, Protocol.MODULE,
                    entry.refresh and Protocol.REFRESH or Protocol.LOGIN, { token = entry.token })
            end
        end
    end
end

function Service.receive(args)
    if type(args) ~= "table" or type(args.token) ~= "string" then return end
    for index, entry in pairs(Service.entries) do
        if entry.status == "loading" and args.token == entry.token
            and getSpecificPlayer(index) == entry.player and not entry.player:isDead()
            and args.onlineId == entry.player:getOnlineID() then
            if entry.lastResponseStatus ~= args.status then
                entry.lastResponseStatus = args.status
                Diagnostics.log("client","RECEIVE",entry.token,args.status == "loading" and "PENDING"
                    or args.status == "ready" and "OK" or args.error)
            end
            if args.status == "ready" and type(args.balance) == "number"
                and args.balance == args.balance and math.abs(args.balance) <= 9007199254740991
                and type(args.updatedAt) == "number" and args.updatedAt == args.updatedAt
                and args.updatedAt >= 0 and args.updatedAt <= 9007199254740991 then
                finish(entry, "ready", args.balance, nil, args.updatedAt, args.cached == true)
            elseif args.status == "error" and type(args.error) == "string" and #args.error <= 80 then
                finish(entry, "error", nil, args.error)
            end
            return
        end
    end
end

function Service.getState(index)
    index = index or 0
    local entry = Service.entries[index]
    if not entry or getSpecificPlayer(index) ~= entry.player or entry.player:isDead() then
        return { status = "idle" }
    end
    return state(entry)
end

function Service.clear(player)
    Service.clearing = (Service.clearing or 0) + 1
    local removed = {}
    for index, entry in pairs(Service.entries) do
        if not player or entry.player == player then
            Service.entries[index] = nil
            removed[#removed + 1] = entry
        end
    end
    for _, entry in ipairs(removed) do finish(entry, "error", nil, "CANCELLED") end
    Service.clearing = Service.clearing - 1
    if Service.clearing == 0 then Service.clearing = nil end
end

return Service
