if isServer() then return end
local C = require "ApocExtractionMapUtils_Objectives/Contract"
local Store = require "ApocExtractionMapUtils_Objectives/Store"
local N = { slots = {} }
local serial = 0
function N.reset(index, player)
    local s = Store.new()
    s.player = player
    N.slots[index] = s
    return s
end
function N.onTick()
    for index = 0, 3 do
        local s, player = N.slots[index], getSpecificPlayer(index)
        if s and player == s.player and not player:isDead() and isClient() then
            local time = getTimestampMs()
            if s.incoming and time >= s.incoming.deadline then s:resync() end
            if s.needsSnapshot and time >= (s.nextRequestAt or 0) then
                serial = serial + 1
                s.requestId = tostring(time) .. ":" .. index .. ":" .. serial
                s.incoming = nil
                sendClientCommand(player, C.MODULE, "RequestSnapshot", { protocol = C.VERSION, requestId = s.requestId })
                s.backoff = math.min(30000, (s.backoff or 500) * 2)
                s.nextRequestAt = time + s.backoff
            end
        end
    end
end
function N.onServerCommand(module, command, args)
    if module ~= C.MODULE or type(args) ~= "table" then return end
    for index = 0, 3 do
        local s = N.slots[index]
        if s and s.player == getSpecificPlayer(index) and s.player:getOnlineID() == args.recipient then
            s:receive(command, args, getTimestampMs())
        end
    end
end
return N
