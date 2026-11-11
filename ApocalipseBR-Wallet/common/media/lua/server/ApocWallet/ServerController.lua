if not isServer() then return end
require "ApocWallet/ServerService"
local Service, Protocol = ApocWallet.ServerService, ApocWallet.Protocol

Service.notify = function(player, state)
    sendServerCommand(player, Protocol.MODULE, Protocol.STATE, state)
end
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= Protocol.MODULE or command ~= Protocol.LOGIN or type(args) ~= "table" then return end
    -- The native command callback supplies the authenticated player. Ignore all client identity fields.
    local state = Service.login(player, args.token)
    if state then Service.notify(player, state) end
end)
Events.OnTick.Add(Service.update)
