if not isClient() then return end
require "ApocWallet/ClientService"
local Service, Protocol = ApocWallet.ClientService, ApocWallet.Protocol

Events.OnCreatePlayer.Add(Service.begin)
Events.OnGameStart.Add(function()
    for index = 0, getNumActivePlayers() - 1 do Service.begin(index, getSpecificPlayer(index)) end
end)
local ticking, tickEvent = false, Events.OnTick
Service.onWorkChanged = function(active)
    if active == ticking then return end
    ticking = active
    if active then tickEvent.Add(Service.update)
    else tickEvent.Remove(Service.update) end
end
Service.onWorkChanged(Service.pending > 0)
Events.OnServerCommand.Add(function(module, command, args)
    if module == Protocol.MODULE and command == Protocol.STATE then Service.receive(args) end
end)
Events.OnPlayerDeath.Add(Service.clear)
Events.OnDisconnect.Add(function() Service.clear() end)
