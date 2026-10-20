require "ApocExtractionMapUtils"

local function onGameStart()
    if not ApocExtractionMapUtils.lobbyEnabled()
        or ApocExtractionMapUtils.getOptions().RelocateOnLogin ~= true then return end
    local x, y, z = ApocExtractionMapUtils.getLobbyPosition()
    if not x then
        print("[ApocExtractionMapUtils] Login relocation skipped: configure LobbyX and LobbyY in sandbox settings.")
        return
    end

    -- B42 IngameState.enter fires OnGameStart before sendPlayerConnect.
    -- Place the local player before normal movement updates begin. The
    -- server still loads its own character position from the database:
    -- this Lua placement needs validation with server movement anti-cheat.
    -- Do not use OnCreatePlayer: initUISystem also fires that event.
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            player:teleportTo(x, y, z)
            player:setForceX(x + 0.5)
            player:setForceY(y + 0.5)
            player:setLastZ(z)
            print("[ApocExtractionMapUtils] Login lobby position: " .. x .. "," .. y .. "," .. z)
        end
    end
end

Events.OnGameStart.Add(onGameStart)
