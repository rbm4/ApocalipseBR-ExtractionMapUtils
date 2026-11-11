local root = "ApocalipseBR-Wallet/common/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. root .. "server/?.lua;" .. package.path
local checks, now, role, clockReads, nativeLookups = 0, 0, "server", 0, 0
local online, locals, outgoing, requests, clientCommands = {}, {}, {}, {}, {}
local uuid = "12345678-1234-4234-8234-123456789abc"
local serverEvents, clientEvents
local function check(value, message) checks = checks + 1; assert(value, message) end
function getTimestampMs() clockReads = clockReads + 1; return now end
function isServer() return role == "server" end
function isClient() return role == "client" end
function getPlayerByOnlineID(id) nativeLookups = nativeLookups + 1; return online[id] end
function getSpecificPlayer(index) return locals[index] end
function getNumActivePlayers() return 2 end
local function events()
    local result = {}
    for _, name in ipairs({"OnCreatePlayer", "OnGameStart", "OnTick", "OnServerCommand",
        "OnClientCommand", "OnPlayerDeath", "OnDisconnect", "EveryOneMinute"}) do
        local callbacks = {}
        result[name] = { Add = function(f) callbacks[#callbacks + 1] = f end,
            Remove = function(f)
                for index, registered in ipairs(callbacks) do
                    if registered == f then table.remove(callbacks,index); return end
                end
            end,
            count = function() return #callbacks end,
            fire = function(...)
                local index = 1
                while index <= #callbacks do
                    local f = callbacks[index]
                    f(...)
                    local exists = false
                    for _, registered in ipairs(callbacks) do if registered == f then exists = true; break end end
                    if exists then index = index + 1 end
                end
            end }
    end
    return result
end
local function player(id, session)
    local p = { id = id, session = session or "session-1", characterId = uuid, pending = false }
    function p:getOnlineID() return self.id end
    function p:isDead() return self.dead == true end
    return p
end
function sendServerCommand(p, module, command, args)
    outgoing[#outgoing + 1] = { player = p, module = module, command = command, args = args }
end
function sendClientCommand(p, module, command, args)
    clientCommands[#clientCommands + 1] = { player = p, module = module, command = command, args = args }
end
local reject, rejection, apiEnabled, apiThrows = false, "THROTTLED", true, false
ApocBRModEntities = { character = function(p)
    if p.pending then return { status = "IDENTITY_PENDING" } end
    return { status = "OK", characterId = p.characterId, session = p.session,
        sourceServerId = 2, steamId = "76561198000000001" }
end }
ApocBrApiBridge = { CHARACTER_BALANCE = "enum-value", isEnabled = function() return apiEnabled end,
    getLastRejection = function() return rejection end,
    request = function(endpoint, params, callback)
        if apiThrows then error("fixture transport exception") end
        if reject then return nil end
        local id = "request-" .. tostring(#requests + 1)
        requests[#requests + 1] = { id = id, endpoint = endpoint, params = params, callback = callback }
        return id
    end }
local function setup()
    now, role = 0, "server"
    online, locals, outgoing, requests, clientCommands = {}, {}, {}, {}, {}
    reject, rejection, apiEnabled, apiThrows = false, "THROTTLED", true, false
    ApocWallet = nil
    for _, name in ipairs({"Protocol", "Operation", "ServerService", "ServerController", "ClientService", "ClientController"}) do
        package.loaded["ApocWallet/" .. name] = nil
    end
    Events = events(); serverEvents = Events
    require "ApocWallet/ServerController"
end
local function login(p, token, extra)
    local args = extra or {}; args.token = token
    serverEvents.OnClientCommand.fire("ApocWallet", "LoadBalance", p, args)
end
local function complete(index, balance, error)
    local r = requests[index]
    r.callback({requestId = r.id, ok = error == nil, balance = balance, error = error, status = error and 503 or 200})
end

setup()
local p = player(1); online[1] = p
login(p, "login-1", {runtimeUuid = "attacker", steamId = "attacker", sourceServerId = 999, balance = 999999})
check(#requests == 0, "controller queues login without blocking on HTTP")
serverEvents.OnTick.fire()
check(#requests == 1 and requests[1].endpoint == "enum-value", "server service submits enum endpoint")
check(requests[1].params == '{"runtimeUuid":"' .. uuid .. '","sourceServerId":2,"steamId":"76561198000000001"}',
    "all request identity comes from server Java context")
check(ApocWallet.ServerService.getState(p).status == "loading", "wait in memory for callback")
login(p, "login-1"); check(#outgoing == 1, "command spam does not multiply replies")
now = 2000; login(p, "different-token"); serverEvents.OnTick.fire()
check(#requests == 1, "duplicate and changed login token do not multiply API calls")
complete(1, 15000)
check(ApocWallet.ServerService.getState(p).balance == 15000, "server caches response balance")
check(outgoing[#outgoing].player == p and outgoing[#outgoing].args.token == "different-token", "completion targets owning player and current token")
local n = #outgoing; complete(1, 123)
check(#outgoing == n and ApocWallet.ServerService.getState(p).balance == 15000, "duplicate callback ignored")
local copy = ApocWallet.ServerService.getState(p); copy.balance = 100
check(ApocWallet.ServerService.getState(p).balance == 15000, "server getter returns copy")
now = 4000; login(p, "again"); serverEvents.OnTick.fire()
check(#requests == 1 and outgoing[#outgoing].args.balance == 15000, "ready login reads cache without HTTP")
serverEvents.OnClientCommand.fire("other", "LoadBalance", p, {token = "x"})
login(p, string.rep("x",81)); login(p, {}); login(player(2), "not-native")
check(#requests == 1, "wrong module, malformed token, and unauthenticated player rejected")

setup(); p = player(1); local second = player(2); online[1], online[2] = p, second; p.pending = true
login(p,"p"); login(second,"second"); serverEvents.OnTick.fire()
check(#requests == 1 and ApocWallet.ServerService.getState(p).status == "loading", "pending import does not block ready players")
now = 2000; p.pending = false; serverEvents.OnTick.fire()
check(#requests == 2, "waits for trusted identity before request")
p.session = "new-session"; complete(2, 100)
check(ApocWallet.ServerService.getState(p).error == "STALE_SESSION", "changed session cannot receive stale balance")
online[2] = player(2, "reconnect"); complete(1, 777)
check(ApocWallet.ServerService.getState(second).status == "idle", "reused online ID cannot inherit stale callback")
now = 4000; serverEvents.OnTick.fire(); serverEvents.EveryOneMinute.fire()
check(ApocWallet.ServerService.entries[second] == nil, "disconnect removes server cache")

for _, code in ipairs({"THROTTLED", "QUEUE_FULL", "BACKEND_COOLDOWN"}) do
    setup(); p = player(1); online[1] = p; reject, rejection = true, code
    login(p,"retry"); serverEvents.OnTick.fire()
    check(ApocWallet.ServerService.getState(p).status == "loading", code .. " preserves bounded pending login")
    reject = false; now = 2000; serverEvents.OnTick.fire()
    check(#requests == 1, code .. " retries admission without client spam")
end
setup(); p = player(1); online[1] = p; login(p,"timeout"); serverEvents.OnTick.fire()
now = 60000; serverEvents.OnTick.fire()
check(ApocWallet.ServerService.getState(p).error == "API_TIMEOUT", "lost callback has bounded wait")
complete(1,100); check(ApocWallet.ServerService.getState(p).balance == nil, "late callback after timeout ignored")
setup(); p = player(1); online[1] = p; p.pending = true; login(p,"identity-timeout")
now = 120000; serverEvents.OnTick.fire()
check(ApocWallet.ServerService.getState(p).error == "LOGIN_TIMEOUT" and #requests == 0, "pending identity expires")
setup(); p = player(1); online[1] = p; apiEnabled = false; login(p,"missing"); serverEvents.OnTick.fire()
check(ApocWallet.ServerService.getState(p).error == "API_UNAVAILABLE", "missing bridge does not invent zero balance")
setup(); p = player(1); online[1] = p; apiThrows = true; login(p,"throws"); serverEvents.OnTick.fire()
check(ApocWallet.ServerService.getState(p).error == "API_ERROR", "throwing bridge isolated")
setup(); p = player(1); online[1] = p; login(p,"http-error"); serverEvents.OnTick.fire(); complete(1,nil,"HTTP_503")
check(ApocWallet.ServerService.getState(p).error == "HTTP_503", "HTTP error retained without a fake balance")
setup(); p = player(1); online[1] = p; login(p,"bad-response"); serverEvents.OnTick.fire(); complete(1,0/0)
check(ApocWallet.ServerService.getState(p).error == "API_ERROR", "invalid balance rejected")

-- Client and server controllers together, with separate native player objects.
setup(); local serverPlayer = player(5); online[5] = serverPlayer
role, Events = "client", events(); clientEvents = Events
require "ApocWallet/ClientController"
local localPlayer = player(-1); locals[0] = localPlayer
clientEvents.OnCreatePlayer.fire(0,localPlayer); clientEvents.OnGameStart.fire(); clientEvents.OnTick.fire()
check(#clientCommands == 0, "login waits for online registration")
localPlayer.id = 5; now = 250; clientEvents.OnTick.fire()
check(#clientCommands == 1 and clientCommands[1].args.token and clientCommands[1].args.steamId == nil, "one login intent without identity fields")
local command = clientCommands[1]; login(serverPlayer,command.args.token); serverEvents.OnTick.fire()
check(#requests == 1, "login intent reaches API bridge")
complete(1,15000)
local response = outgoing[#outgoing]
clientEvents.OnServerCommand.fire(response.module,response.command,response.args)
check(ApocWallet.ClientService.getState(0).balance == 15000, "full flow caches balance on client")
now = 20000; clientEvents.OnTick.fire()
check(#clientCommands == 1, "ready client stops polling")
copy = ApocWallet.ClientService.getState(0); copy.balance = -1
check(ApocWallet.ClientService.getState(0).balance == 15000, "client getter returns copy")
clientEvents.OnPlayerDeath.fire(localPlayer)
check(ApocWallet.ClientService.getState(0).status == "idle", "death clears client balance")
local replacement = player(5); locals[0] = replacement
clientEvents.OnCreatePlayer.fire(0,replacement)
clientEvents.OnServerCommand.fire(response.module,response.command,response.args)
check(ApocWallet.ClientService.getState(0).status == "loading", "previous life reply ignored")
clientEvents.OnTick.fire(); now = now + 5000; clientEvents.OnTick.fire()
check(#clientCommands == 2, "loading client sends one intent and waits for pushed completion")
now = now + 180000; clientEvents.OnTick.fire()
check(ApocWallet.ClientService.getState(0).error == "REQUEST_TIMEOUT", "client wait is bounded")
clientEvents.OnDisconnect.fire()
check(next(ApocWallet.ClientService.entries) == nil, "disconnect clears all local slots")

setup()
local firstServer, secondServer = player(11), player(12)
online[11], online[12] = firstServer, secondServer
role, Events = "client", events(); clientEvents = Events
require "ApocWallet/ClientController"
locals[0], locals[1] = player(11), player(12)
clientEvents.OnGameStart.fire(); clientEvents.OnTick.fire()
check(#clientCommands == 2, "split-screen login queues both local players")
login(firstServer,clientCommands[1].player == locals[0] and clientCommands[1].args.token or clientCommands[2].args.token)
login(secondServer,clientCommands[1].player == locals[1] and clientCommands[1].args.token or clientCommands[2].args.token)
serverEvents.OnTick.fire()
check(#requests == 1, "different players share global admission pacing")
now = 1000; serverEvents.OnTick.fire()
check(#requests == 1, "no per-tick backend burst")
now = 2000; serverEvents.OnTick.fire()
check(#requests == 2, "next player submits after global spacing")
complete(2,50); complete(1,40)
for _, message in ipairs(outgoing) do
    clientEvents.OnServerCommand.fire(message.module,message.command,message.args)
end
check(ApocWallet.ClientService.getState(0).status == "ready" and ApocWallet.ClientService.getState(1).status == "ready",
    "out-of-order responses route to both split-screen slots")
check(ApocWallet.ClientService.getState(0).balance + ApocWallet.ClientService.getState(1).balance == 90,
    "split-screen balances remain isolated")
setup()
for id = 1, 256 do local owned = player(id); online[id] = owned; login(owned,"capacity") end
local overflow = player(257); online[257] = overflow; login(overflow,"overflow")
check(ApocWallet.ServerService.count == 256 and outgoing[#outgoing].args.error == "WALLET_BUSY",
    "server session cache is bounded")
-- Operation callbacks are shared, cancellable and leave no permanent tick handlers.
setup()
local serverOwner = player(21); online[21] = serverOwner
role, Events = "client", events(); clientEvents = Events
require "ApocWallet/ClientController"
locals[0] = player(21)
check(clientEvents.OnTick.count() == 0 and serverEvents.OnTick.count() == 0, "idle controllers attach no tick callbacks")
local callbackOne, callbackTwo, cancelled = 0, 0, 0
local cancel = ApocWallet.ClientService.requestBalance(0,function() cancelled = cancelled + 1 end)
ApocWallet.ClientService.requestBalance(0,function(result) callbackOne = callbackOne + 1; result.balance = -999 end)
ApocWallet.ClientService.requestBalance(0,function(result) callbackTwo = callbackTwo + 1; check(result.balance == 15000,"callback snapshots isolated") end)
cancel(); cancel()
clientEvents.OnGameStart.fire()
check(clientEvents.OnTick.count() == 1, "concurrent callers and startup share one tick registration")
clientEvents.OnTick.fire()
check(#clientCommands == 1,"concurrent UI callers share one client operation")
command = clientCommands[1]; login(serverOwner,command.args.token); serverEvents.OnTick.fire()
local serverCallbacks = 0
ApocWallet.ServerService.requestBalance(serverOwner,function(result) serverCallbacks = serverCallbacks + 1; check(result.balance == 15000,"server callback gets balance") end)
complete(1,15000)
response = outgoing[#outgoing]
clientEvents.OnServerCommand.fire(response.module,response.command,response.args)
check(callbackOne == 1 and callbackTwo == 1 and cancelled == 0 and serverCallbacks == 1,"callbacks resolve once; cancelled observer never called")
check(clientEvents.OnTick.count() == 0 and serverEvents.OnTick.count() == 0,"completed operations detach both tick handlers")
local beforeClock, beforeLookups = clockReads, nativeLookups
for i = 1, 1000 do clientEvents.OnTick.fire(); serverEvents.OnTick.fire() end
ApocWallet.ClientService.update(); ApocWallet.ServerService.update()
check(clockReads == beforeClock and nativeLookups == beforeLookups,"idle tick/update paths read neither clock nor player map")
local cachedCalls = 0
ApocWallet.ClientService.requestBalance(0,function(result) cachedCalls = cachedCalls + 1; check(result.cached and result.updatedAt == 0,"cache freshness timestamp exposed") end)
check(cachedCalls == 1 and #clientCommands == 1,"cached callback resolves immediately without network")
now = 6000
local refreshCalls = 0
ApocWallet.ClientService.refreshBalance(0,function(result) refreshCalls = refreshCalls + 1; check(result.balance == 7000,"explicit refresh replaces stale display balance") end)
ApocWallet.ClientService.refreshBalance(0,function() refreshCalls = refreshCalls + 1 end)
clientEvents.OnTick.fire()
check(#clientCommands == 2 and clientCommands[2].command == "RefreshBalance","explicit refresh sends one new intent")
serverEvents.OnClientCommand.fire("ApocWallet","RefreshBalance",serverOwner,clientCommands[2].args)
serverEvents.OnTick.fire()
check(#requests == 2,"server refresh creates a new read operation after cooldown")
complete(2,7000); response = outgoing[#outgoing]
clientEvents.OnServerCommand.fire(response.module,response.command,response.args)
check(refreshCalls == 2 and ApocWallet.ClientService.getState(0).balance == 7000,"coalesced refresh callbacks see backend change")
check(clientEvents.OnTick.count() == 0 and serverEvents.OnTick.count() == 0,"refresh completion also detaches ticks")
local rapid
now = 7000
ApocWallet.ClientService.refreshBalance(0,function(result) rapid = result end)
check(rapid and rapid.cached and #clientCommands == 2,"rapid UI refresh uses cache instead of waiting on a throttled command")
now = 8000
serverEvents.OnClientCommand.fire("ApocWallet","RefreshBalance",serverOwner,{token="forged-refresh"})
serverEvents.OnTick.fire()
check(#requests == 2 and outgoing[#outgoing].args.cached and serverEvents.OnTick.count() == 0,
    "server independently prevents fresh-token refresh spam inside cooldown")
now = 12000
ApocWallet.ClientService.refreshBalance(0,function() error("fixture UI callback failure") end)
local safe = 0
ApocWallet.ClientService.requestBalance(0,function(result) safe = safe + 1; check(result.error == "HTTP_503","failure delivered through callback") end)
clientEvents.OnTick.fire()
serverEvents.OnClientCommand.fire("ApocWallet","RefreshBalance",serverOwner,clientCommands[3].args)
serverEvents.OnTick.fire(); complete(3,nil,"HTTP_503"); response = outgoing[#outgoing]
clientEvents.OnServerCommand.fire(response.module,response.command,response.args)
check(safe == 1 and clientEvents.OnTick.count() == 0,"throwing UI observer cannot interrupt another observer or cleanup")
now = 18000
local closed = 0
cancel = ApocWallet.ClientService.refreshBalance(0,function() closed = closed + 1 end)
local survivor = 0
ApocWallet.ClientService.requestBalance(0,function() survivor = survivor + 1 end)
cancel(); clientEvents.OnDisconnect.fire()
check(closed == 0 and survivor == 1 and clientEvents.OnTick.count() == 0,"disconnect cancels pending operation and notifies attached observers")
now = 24000
ApocWallet.ClientService.refreshBalance(0,function()
    ApocWallet.ClientService.refreshBalance(0)
end)
clientEvents.OnDisconnect.fire()
check(clientEvents.OnTick.count() == 0 and next(ApocWallet.ClientService.entries) == nil,
    "cancellation callback cannot resurrect a request during disconnect")

setup(); serverOwner = player(1); online[1] = serverOwner
local deliveries, limited = 0, 0
for i = 1, 33 do
    ApocWallet.ServerService.requestBalance(serverOwner,function(result)
        if result.error == "CALLBACK_LIMIT" then limited = limited + 1 else deliveries = deliveries + 1 end
    end)
end
check(limited == 1,"operation observer count bounded to 32")
serverEvents.OnTick.fire(); complete(1,50)
check(deliveries == 32 and serverEvents.OnTick.count() == 0,"bounded server observers settle and release tick")
local readyOwner = player(2); online[2] = readyOwner
now = 6000; login(readyOwner,"ready"); serverEvents.OnTick.fire(); complete(2,10)
online[2] = nil; now = 20000
beforeLookups = nativeLookups
serverEvents.OnTick.fire()
check(nativeLookups == beforeLookups,"completed player cache is not scanned by ticks")
serverEvents.EveryOneMinute.fire()
check(ApocWallet.ServerService.entries[readyOwner] == nil,"coarse maintenance removes disconnected completed cache")
beforeLookups = nativeLookups
serverEvents.EveryOneMinute.fire()
check(nativeLookups == beforeLookups,"cache cleanup has a ten-second real-time gate")

local Operation = require "ApocWallet/Operation"
local operation = Operation.new()
local delivered = 0
local cancelFirst = Operation.subscribe(operation,function() delivered = delivered + 1 end)
local cancelSecond = Operation.subscribe(operation,function() delivered = delivered + 1 end)
local firstTicket = next(operation.listeners)
operation.listeners[firstTicket] = function()
    delivered = delivered + 1
    cancelFirst(); cancelSecond()
end
Operation.resolve(operation,{status="ready",balance=1})
Operation.resolve(operation,{status="ready",balance=2})
check(delivered == 1 and operation.count == 0 and next(operation.listeners) == nil,
    "cancellation during dispatch removes not-yet-delivered observers and settlement is terminal")
print("Passed " .. checks .. " wallet assertions (production Lua, mocked engine/API boundaries).")
