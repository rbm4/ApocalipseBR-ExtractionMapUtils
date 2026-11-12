if not isServer() then return end
require "ApocWallet/ServerService"
local Diagnostics = require "ApocWallet/Diagnostics"
if ApocWallet.serverControllerInstalled then return end
ApocWallet.serverControllerInstalled = true
Diagnostics.log("server","LOADED",nil,"READY")
local Service, Protocol = ApocWallet.ServerService, ApocWallet.Protocol

Service.notify = function(player, state)
    sendServerCommand(player, Protocol.MODULE, Protocol.STATE, state)
end
local lastIgnored
local function ignored(token,code)
    if not Diagnostics.enabled then return end
    local now = getTimestampMs()
    if not lastIgnored or now-lastIgnored>=10000 then
        lastIgnored=now
        Diagnostics.log("server","COMMAND_IGNORED",token,code)
    end
end
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= Protocol.MODULE or (command ~= Protocol.LOGIN and command ~= Protocol.REFRESH) then return end
    if type(args) ~= "table" then ignored(nil,"INVALID_PAYLOAD"); return end
    -- The native command callback supplies the authenticated player. Ignore all client identity fields.
    local state,reason = Service.login(player, args.token, command == Protocol.REFRESH)
    if state then
        Service.notify(player, state)
        -- Make the first attempt in the native command callback. OnTick remains
        -- only for bounded identity/admission waits and completion deadlines.
        Service.kick(player)
    else
        ignored(args.token,reason or "REJECTED")
    end
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
