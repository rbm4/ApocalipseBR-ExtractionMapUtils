-- Extraction owns login relocation and NPC dialogue discovery.
require "ApocExtractionMapUtils"

local Utils = ApocExtractionMapUtils
local pending = {}
local pendingNPC = {}
local RETRY_MS, MAX_ATTEMPTS = 1000, 15

local function enabled()
    return Utils.lobbyEnabled() and Utils.getOptions().RelocateOnLogin == true
end

local function relocate(player)
    if not enabled() or not player or player:isDead() then return end
    local x, y, z = Utils.getLobbyPosition()
    if not x then
        Utils.debugLog("[ApocExtractionMapUtils] Login relocation skipped: configure LobbyX and LobbyY in sandbox settings.")
        return
    end
    -- Client placement still requires dedicated-server movement/anti-cheat validation.
    player:teleportTo(x, y, z)
    player:setForceX(x + 0.5)
    player:setForceY(y + 0.5)
    player:setLastZ(z)
    Utils.debugLog("[ApocExtractionMapUtils] Login lobby position: " .. x .. "," .. y .. "," .. z)
end

local function localDecision(player)
    local state = ModData.get("ApocExtractionLobby")
    if state and state.released == false and state.removedAll ~= true then return true end
    return Utils.loginPositionNeedsReset(player)
end

local function onGameStart()
    pending = {}
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            pendingNPC[playerNum] = player
            if enabled() then pending[playerNum] = { player = player, attempts = 0 } end
            if enabled() and not isClient() then
                local reset = localDecision(player)
                if reset ~= nil then
                    pending[playerNum] = nil
                    if reset then relocate(player) end
                end
            end
        end
    end
end

Events.OnTick.Add(function()
    for index, player in pairs(pendingNPC) do
        if getSpecificPlayer(index) ~= player or player:isDead() then pendingNPC[index] = nil
        elseif isClient() and player:getOnlineID() >= 0 then
            local client = Utils.HumanDialogs and Utils.HumanDialogs.client
            if client then client.requestRoster(player); pendingNPC[index] = nil end
        elseif not isClient() then pendingNPC[index] = nil end
    end
    for playerNum, entry in pairs(pending) do
        if not enabled() or getSpecificPlayer(playerNum) ~= entry.player or entry.player:isDead() then
            pending[playerNum] = nil
        elseif isClient() and entry.player:getOnlineID() < 0 then
            -- OnCreatePlayer can precede connection registration. Wait without
            -- spending the bounded geometry retry budget.
        elseif not entry.nextTry or getTimestampMs() >= entry.nextTry then
            if entry.attempts >= MAX_ATTEMPTS then
                Utils.debugLog("[ApocExtractionMapUtils][Login] retries_exhausted; playerNum=" .. tostring(playerNum))
                pending[playerNum] = nil -- Unknown geometry preserves the saved position.
            else
                entry.attempts = entry.attempts + 1
                entry.nextTry = getTimestampMs() + RETRY_MS
                if isClient() then
                    -- OnGameStart precedes sendPlayerConnect; request on the next tick.
                    sendClientCommand(entry.player, "ApocExtractionMapUtils", "LoginLobbyState", { playerNum = playerNum })
                else
                    local reset = localDecision(entry.player)
                    if reset ~= nil then
                        pending[playerNum] = nil
                        if reset then relocate(entry.player) end
                    end
                end
            end
        end
    end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "ApocExtractionMapUtils" or command ~= "LoginLobbyState" or type(args) ~= "table" then return end
    local playerNum = args.playerNum or 0
    local entry = pending[playerNum]
    if not entry or entry.attempts == 0 then return end
    if getSpecificPlayer(playerNum) ~= entry.player then pending[playerNum] = nil; return end
    if args.retry == true and args.closed ~= true and args.reset ~= true then return end
    pending[playerNum] = nil
    if args.serverTeleported ~= true and (args.closed == true or args.reset == true) then relocate(entry.player) end
end)

Events.OnGameStart.Add(onGameStart)
Events.OnCreatePlayer.Add(function(index, player)
    if not player then return end
    pendingNPC[index] = player
    if enabled() then pending[index] = { player = player, attempts = 0 } end
end)
