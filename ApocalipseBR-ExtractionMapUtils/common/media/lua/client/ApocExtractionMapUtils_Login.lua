-- Extraction owns login relocation and NPC dialogue discovery.
require "ApocExtractionMapUtils"

local Utils = ApocExtractionMapUtils
local pending = {}
local pendingNPC = {}
local deaths = {}
local RETRY_MS, MAX_ATTEMPTS = 1000, 15

local function enabled(respawn)
    if not Utils.lobbyEnabled() then return false end
    local options = Utils.getOptions()
    if respawn == nil then return options.RelocateOnLogin == true or options.RelocateOnRespawn == true end
    return options[respawn and "RelocateOnRespawn" or "RelocateOnLogin"] == true
end

local function relocate(player, respawn)
    if not enabled(respawn == true) or not player or player:isDead() then return end
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

local function localDecision(player, respawn)
    if not enabled(respawn == true) then return false end
    if respawn then return true end
    local state = ModData.get("ApocExtractionLobby")
    if state and state.released == false and state.removedAll ~= true then return true end
    return Utils.loginPositionNeedsReset(player)
end

local function onGameStart()
    local previous = pending
    pending = {}
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            pendingNPC[playerNum] = player
            -- Hooks can run before replicated settings/online registration.
            -- Queue first; evaluate the options once this player can send.
            local prior = previous[playerNum]
            local respawn = deaths[playerNum] ~= nil or (prior and prior.player == player and prior.respawn == true)
            pending[playerNum] = { player = player, attempts = 0, respawn = respawn == true }
            Utils.debugLog("[ApocExtractionMapUtils][Login][client] queued; protocol=2; source=OnGameStart; playerNum="
                .. tostring(playerNum) .. "; lobbyEnabled=" .. tostring(Utils.lobbyEnabled())
                .. "; relocateOnLogin=" .. tostring(Utils.getOptions().RelocateOnLogin))
            if enabled() and not isClient() then
                local reset = localDecision(player, respawn)
                if reset ~= nil then
                    pending[playerNum] = nil
                    if reset then relocate(player, respawn) end
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
        if getSpecificPlayer(playerNum) ~= entry.player or entry.player:isDead() then
            pending[playerNum] = nil
        elseif isClient() and entry.player:getOnlineID() < 0 then
            -- OnCreatePlayer can precede connection registration. Wait without
            -- spending the bounded geometry retry budget.
        elseif not enabled() then
            Utils.debugLog("[ApocExtractionMapUtils][Login][client] skipped; reason=settings_disabled; playerNum="
                .. tostring(playerNum) .. "; lobbyEnabled=" .. tostring(Utils.lobbyEnabled())
                .. "; relocateOnLogin=" .. tostring(Utils.getOptions().RelocateOnLogin))
            pending[playerNum] = nil
        elseif not entry.nextTry or getTimestampMs() >= entry.nextTry then
            if entry.attempts >= MAX_ATTEMPTS then
                Utils.debugLog("[ApocExtractionMapUtils][Login] retries_exhausted; playerNum=" .. tostring(playerNum))
                pending[playerNum] = nil -- Unknown history/geometry preserves the saved position.
            else
                entry.attempts = entry.attempts + 1
                entry.nextTry = getTimestampMs() + RETRY_MS
                if isClient() then
                    -- OnGameStart precedes sendPlayerConnect; request on the next tick.
                    Utils.debugLog("[ApocExtractionMapUtils][Login][client] request; playerNum=" .. tostring(playerNum)
                        .. "; onlineID=" .. tostring(entry.player:getOnlineID()) .. "; attempt=" .. tostring(entry.attempts))
                    sendClientCommand(entry.player, "ApocExtractionMapUtils", "LoginLobbyState", { playerNum = playerNum })
                else
                    local reset = localDecision(entry.player, entry.respawn)
                    if reset ~= nil then
                        pending[playerNum] = nil
                        if reset then relocate(entry.player, entry.respawn) end
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
    Utils.debugLog("[ApocExtractionMapUtils][Login][client] response; playerNum=" .. tostring(playerNum)
        .. "; retry=" .. tostring(args.retry == true) .. "; reset=" .. tostring(args.reset == true)
        .. "; closed=" .. tostring(args.closed == true) .. "; serverTeleported=" .. tostring(args.serverTeleported == true))
    if args.retry == true and args.closed ~= true and args.reset ~= true then return end
    pending[playerNum] = nil
    if args.serverTeleported ~= true and (args.closed == true or args.reset == true) then
        local respawn = args.respawn
        if respawn == nil then respawn = entry.respawn end
        relocate(entry.player, respawn)
    end
end)

Events.OnGameStart.Add(onGameStart)
Events.OnCreatePlayer.Add(function(index, player)
    if not player then return end
    pendingNPC[index] = player
    pending[index] = { player = player, attempts = 0, respawn = deaths[index] ~= nil }
end)

-- Vanilla emits this before a replacement character's OnCreatePlayer hook.
-- Multiplayer authority comes from ApocBRPlayerLogin.isRespawn on the server.
if Events.OnPlayerDeath then
    Events.OnPlayerDeath.Add(function(player)
        for index = 0, getNumActivePlayers() - 1 do
            if getSpecificPlayer(index) == player then deaths[index] = player end
        end
    end)
end
