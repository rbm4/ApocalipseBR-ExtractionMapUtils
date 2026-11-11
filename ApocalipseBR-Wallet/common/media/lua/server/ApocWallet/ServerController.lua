if not isServer() then return end
require "ApocWallet/ServerService"
local Service, Protocol = ApocWallet.ServerService, ApocWallet.Protocol

Service.notify = function(player, state)
    sendServerCommand(player, Protocol.MODULE, Protocol.STATE, state)
end
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= Protocol.MODULE or (command ~= Protocol.LOGIN and command ~= Protocol.REFRESH)
        or type(args) ~= "table" then return end
    -- The native command callback supplies the authenticated player. Ignore all client identity fields.
    local state = Service.login(player, args.token, command == Protocol.REFRESH)
    if state then Service.notify(player, state) end
end)
local ticking, tickEvent = false, Events.OnTick
Service.onWorkChanged = function(active)
    if active == ticking then return end
    ticking = active
    if active then tickEvent.Add(Service.update)
    else tickEvent.Remove(Service.update) end
end
Service.onWorkChanged(Service.pendingCount > 0)
Events.EveryOneMinute.Add(Service.prune)
