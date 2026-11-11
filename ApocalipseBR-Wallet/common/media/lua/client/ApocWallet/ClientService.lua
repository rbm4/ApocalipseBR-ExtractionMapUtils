require "ApocWallet/Protocol"
if ApocWallet.ClientService then return ApocWallet.ClientService end

local Protocol = ApocWallet.Protocol
local Service = { entries = {}, sequence = 0 }
ApocWallet.ClientService = Service

function Service.begin(index, player)
    if not player or player:isDead() then return end
    local old = Service.entries[index]
    if old and old.player == player then return end
    Service.sequence = Service.sequence + 1
    local now = getTimestampMs()
    Service.entries[index] = { player = player, status = "loading", started = now,
        token = string.format("%.0f:%.0f", now, Service.sequence), nextSend = now }
end

function Service.update()
    local now = getTimestampMs()
    for index, entry in pairs(Service.entries) do
        if getSpecificPlayer(index) ~= entry.player or entry.player:isDead() then
            Service.entries[index] = nil
        elseif entry.status == "loading" then
            if now - entry.started >= Protocol.CLIENT_TIMEOUT_MS then
                entry.status, entry.error = "error", "LOGIN_TIMEOUT"
            elseif now >= entry.nextSend and entry.player:getOnlineID() >= 0 then
                entry.nextSend = now + Protocol.POLL_MS
                -- Identity and URLs are deliberately absent from the client command.
                sendClientCommand(entry.player, Protocol.MODULE, Protocol.LOGIN, { token = entry.token })
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
            if args.status == "ready" and type(args.balance) == "number"
                and args.balance == args.balance and math.abs(args.balance) <= 9007199254740991 then
                entry.status, entry.balance, entry.error = "ready", args.balance, nil
            elseif args.status == "error" and type(args.error) == "string" and #args.error <= 80 then
                entry.status, entry.balance, entry.error = "error", nil, args.error
            end
            return
        end
    end
end

-- Copy snapshots so future UI code cannot mutate the internal cache accidentally.
function Service.getState(index)
    local entry = Service.entries[index or 0]
    if not entry or getSpecificPlayer(index or 0) ~= entry.player or entry.player:isDead() then
        return { status = "idle" }
    end
    return { status = entry.status, balance = entry.balance, error = entry.error }
end

function Service.clear(player)
    for index, entry in pairs(Service.entries) do
        if not player or entry.player == player then Service.entries[index] = nil end
    end
end

return Service
