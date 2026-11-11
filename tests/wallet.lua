local root = "ApocalipseBR-Wallet/common/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. root .. "server/?.lua;" .. package.path
local checks, now, role = 0, 0, "server"
local online, locals, outgoing, requests, clientCommands = {}, {}, {}, {}, {}
local uuid = "12345678-1234-4234-8234-123456789abc"
local serverEvents, clientEvents
local function check(value, message) checks = checks + 1; assert(value, message) end
function getTimestampMs() return now end
function isServer() return role == "server" end
function isClient() return role == "client" end
function getPlayerByOnlineID(id) return online[id] end
function getSpecificPlayer(index) return locals[index] end
function getNumActivePlayers() return 2 end
local function events()
    local result = {}
    for _, name in ipairs({"OnCreatePlayer", "OnGameStart", "OnTick", "OnServerCommand",
        "OnClientCommand", "OnPlayerDeath", "OnDisconnect"}) do
        local callbacks = {}
        result[name] = { Add = function(f) callbacks[#callbacks + 1] = f end,
            fire = function(...) for _, f in ipairs(callbacks) do f(...) end end }
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
    for _, name in ipairs({"Protocol", "ServerService", "ServerController", "ClientService", "ClientController"}) do
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
now = 4000; serverEvents.OnTick.fire()
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
localPlayer.id = 5; clientEvents.OnTick.fire()
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
check(#clientCommands == 3, "loading client retries intent at five-second cadence")
now = now + 180000; clientEvents.OnTick.fire()
check(ApocWallet.ClientService.getState(0).error == "LOGIN_TIMEOUT", "client wait is bounded")
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
print("Passed " .. checks .. " wallet assertions (production Lua, mocked engine/API boundaries).")
