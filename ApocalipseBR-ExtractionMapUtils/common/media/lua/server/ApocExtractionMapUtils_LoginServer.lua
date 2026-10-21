if isClient() then return end
require "ApocExtractionMapUtils_Lobby"
local Utils = ApocExtractionMapUtils
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ApocExtractionMapUtils" or command ~= "LoginLobbyState"
        or not player or player:isDead() then return end
    local closed = Utils.Lobby.isClosed()
    local reset = false
    local x, y, z = Utils.getLobbyPosition()
    -- Successful-login history is recorded independently by GameServer. Wait
    -- for its worker result rather than consuming "pending" as "same server".
    if x and ApocBRPlayerLogin and ApocBRPlayerLogin.isReady
        and ApocBRPlayerLogin.isReady(player) ~= true then
        Utils.debugLog("[ApocExtractionMapUtils][Login] history_pending; player=" .. tostring(player:getOnlineID()))
        sendServerCommand(player, module, command, { retry = true,
            playerNum = type(args) == "table" and args.playerNum or 0 })
        return
    end
    local changedServer = x and ApocBRPlayerLogin and ApocBRPlayerLogin.hasChangedServer(player) == true
    Utils.debugLog("[ApocExtractionMapUtils][Login] decision; changedServer=" .. tostring(changedServer == true)
        .. "; closed=" .. tostring(closed) .. "; destinationConfigured=" .. tostring(x ~= nil))
    if changedServer then reset = true
    elseif not closed and x then reset = Utils.loginPositionNeedsReset(player) end
    local serverTeleported = false
    if x and (closed or reset == true) and ApocBRPlayerLogin then
        serverTeleported = ApocBRPlayerLogin.teleportToLobby(player, x + 0.5, y + 0.5, z) == true
        if not serverTeleported then
            sendServerCommand(player, module, command, { retry = true,
                playerNum = type(args) == "table" and args.playerNum or 0 })
            return
        end
    end
    sendServerCommand(player, module, command, { closed = closed, reset = reset == true, retry = reset == nil,
        serverTeleported = serverTeleported, playerNum = type(args) == "table" and args.playerNum or 0 })
end)
