require "ApocExtractionMapUtils"

local Utils = ApocExtractionMapUtils
if Utils.RevealServerLoaded then return end
Utils.RevealServerLoaded = true
local players = {}
local lastPump = 0

local function stateFor(player)
    local name = player:getUsername()
    local state = players[name]
    if not state or state.player ~= player then
        state = { player = player, passes = 0 }
        players[name] = state
    end
    return state
end

local function reveal(player)
    local ok = pcall(function()
        local store = WorldMapVisitedServer.getInstance()
        Utils.eachRevealBlock(function(x1, y1, x2, y2)
            store:setKnownInSquares(player, x1, y1, x2, y2)
        end)
    end)
    if ok then
        -- Native writes silently wait for PlayerVisited to load this user.
        -- Ack the attempt; the finite retry pump handles late store loading.
        sendServerCommand(player, Utils.REVEAL_MODULE, "MapRevealed", {})
    end
    return ok
end

Events.OnClientCommand.Add(function(module, command, player)
    if module ~= Utils.REVEAL_MODULE or command ~= "RevealMap" then return end
    if not isServer() or not Utils.forceMapReveal() or not player or player:isDead() then return end
    local state, now = stateFor(player), getTimestampMs()
    if state.lastRequest and now - state.lastRequest < 5000 then return end
    state.lastRequest = now
    if not state.lastWindow or now - state.lastWindow >= 120000 then
        state.passes, state.lastWindow = 0, now
    end
    reveal(player)
end)

Events.OnTick.Add(function()
    if not isServer() or not Utils.forceMapReveal() then players = {}; return end
    local now = getTimestampMs()
    if now - lastPump < 15000 then return end
    lastPump = now
    local online, present = getOnlinePlayers(), {}
    for i = 0, online:size() - 1 do
        local player = online:get(i)
        if player and not player:isDead() then
            local state = stateFor(player)
            present[player:getUsername()] = true
            if state.passes < 8 then
                state.passes = state.passes + 1
                reveal(player)
            end
        end
    end
    for name in pairs(players) do if not present[name] then players[name] = nil end end
end)
