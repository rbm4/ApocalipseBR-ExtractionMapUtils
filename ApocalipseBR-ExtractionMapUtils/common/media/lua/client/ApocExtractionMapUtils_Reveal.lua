require "ApocExtractionMapUtils"

local Utils = ApocExtractionMapUtils
-- require/autoload must not install two independent schedulers.
if Utils.Reveal then return Utils.Reveal end
local Reveal = {}
Utils.Reveal = Reveal
ApocExtractionMapUtils.debugLog("[ApocExtractionMapUtils] Known-map reveal loaded; native minimap rendering.")

local sessions = {}
local spawnOffsets = { 3000, 10000, 30000, 90000 }
local mapOffsets = { 1000, 4000 }
local reportedFailure = false

function Reveal.localReveal()
    if not Utils.forceMapReveal() then return false end
    local ok = pcall(function()
        local store = WorldMapVisited.getInstance()
        Utils.eachRevealBlock(function(x1, y1, x2, y2)
            store:setKnownInSquares(x1, y1, x2, y2)
        end)
    end)
    if not ok and not reportedFailure then
        ApocExtractionMapUtils.debugLog("[ApocExtractionMapUtils] Local known-map reveal unavailable; scheduled passes will retry.")
    end
    reportedFailure = not ok
    return ok
end

local function apply(player)
    if not player or player:isDead() or not Utils.forceMapReveal() then return end
    Reveal.localReveal()
    if isClient() then
        sendClientCommand(player, Utils.REVEAL_MODULE, "RevealMap", {})
    end
end

local function schedule(offsets)
    local due, now = {}, getTimestampMs()
    for i = 1, #offsets do due[i] = now + offsets[i] end
    return due
end

local function onCreatePlayer(index, player)
    if not player or not Utils.forceMapReveal() then return end
    local session = sessions[index]
    if session and session.player == player then return end
    sessions[index] = { player = player, spawn = isClient() and schedule(spawnOffsets) or {}, map = {} }
    apply(player)
end

function Reveal.mapOpened(index)
    if not isClient() or not Utils.forceMapReveal() then return end
    local player = getSpecificPlayer(index)
    if not player then return end
    onCreatePlayer(index, player)
    sessions[index].map = schedule(mapOffsets)
end

local function consumeDue(due, now)
    local ready = false
    for i = #due, 1, -1 do
        if due[i] <= now then table.remove(due, i); ready = true end
    end
    return ready
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnGameStart.Add(function()
    for index = 0, getNumActivePlayers() - 1 do onCreatePlayer(index, getSpecificPlayer(index)) end
end)
Events.OnTick.Add(function()
    if not Utils.forceMapReveal() then sessions = {}; return end
    local now = getTimestampMs()
    for index, session in pairs(sessions) do
        if getSpecificPlayer(index) ~= session.player or session.player:isDead() then
            sessions[index] = nil
        else
            local spawnDue = consumeDue(session.spawn, now)
            local mapDue = consumeDue(session.map, now)
            if spawnDue or mapDue then apply(session.player) end
        end
    end
end)
Events.OnServerCommand.Add(function(module, command)
    if module == Utils.REVEAL_MODULE and command == "MapRevealed" then
        -- Repair a late PlayerVisited overwrite, without an acknowledgement loop.
        Reveal.localReveal()
    end
end)

return Reveal
