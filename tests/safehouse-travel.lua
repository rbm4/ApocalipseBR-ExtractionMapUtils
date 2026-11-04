package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;"
    .. "ApocalipseBR-ExtractionMapUtils/common/media/lua/server/?.lua;" .. package.path
local checks, now, ticks, state, requests = 0, 100000, {}, {}, 0
local output, logs = print, {}
print = function(message) logs[#logs + 1] = message end
local function logged(text)
    for _, line in ipairs(logs) do if line:find(text, 1, true) then return true end end
    return false
end
local function check(v, msg) checks = checks + 1; assert(v, msg) end
function isServer() return true end
function getTimestampMs() return now end
Events = { OnTick = { Add = function(fn) ticks[#ticks + 1] = fn end } }
local x, y, alive, vehicle, connected = 10, 20, true, nil, true
local player = { getOnlineID = function() return 1 end, isDead = function() return not alive end,
    getX = function() return x end, getY = function() return y end, getZ = function() return 0 end,
    getVehicle = function() return vehicle end }
function getPlayerByOnlineID() if connected then return player end end
ModData = { getOrCreate = function() error("travel must not access persisted cooldowns") end }
local safe = { getX = function() return 100 end, getY = function() return 200 end,
    getW = function() return 20 end, getH = function() return 10 end }
local freeSquare = { hasFloor = function() return true end, isFree = function() return true end }
local currentSafe, square = safe, freeSquare
SafeHouse = { hasSafehouse = function() return currentSafe end }
function getCell() return { getGridSquare = function() return square end } end
local accepted, lastDestination = true, nil
ApocBRHumanAPI = { accountIdentity = function() return "steam:76561198000000001" end,
    teleport = function(p, a, b, z) requests = requests + 1; lastDestination={a,b,z}; return accepted end }
local D = require "ApocExtractionMapUtils_HumanActions"
local T = require "ApocExtractionMapUtils_SafehouseTravel"
local function prepare() return D.executeAction(player, { key = "agente-v", id = 768, option = "teleport_safehouse", sequence = 1 },
    { id = "player.teleport_safehouse", responsePrefix = "safehouse.teleport" }) end
local function tick() now = now + 250; for _, fn in ipairs(ticks) do fn() end end
local function depart(a) a.afterResponse(); now = now + 2500; tick() end
local a = prepare()
check(a.success and requests == 0 and next(state) == nil, "preparation neither teleports nor consumes cooldown")
check(prepare().responsePool == "safehouse.teleport.unavailable", "pending trip prevents a second transfer")
a.cancel()
a = prepare(); a.afterResponse()
check(requests == 0, "NPC response gets a nonblocking reading interval before departure")
now = now + 2500; tick()
check(requests == 1 and next(state) == nil, "native packet acceptance is not arrival")
tick(); check(next(state) == nil, "no cooldown while still at NPC")
x, y = 99.5, 200.5; tick()
check(prepare().responsePool == "safehouse.teleport.unavailable", "neighbor tile does not finish travel or start cooldown")
x, y = 100.5, 200.5; tick()
local landed = now
check(prepare().responsePool == "safehouse.teleport.cooldown" and next(state) == nil, "arrival starts only an in-memory cooldown")
x, y = 10, 20
local denied = prepare()
check(not denied.success and denied.responsePool == "safehouse.teleport.cooldown" and denied.values.remainingMinutes == "360", "six-hour cooldown response contains rounded remaining minutes")
connected = false; tick(); connected = true
check(prepare().responsePool == "safehouse.teleport.cooldown", "reconnect preserves cooldown within the same process")
now = landed + T.COOLDOWN_MS - 1
check(prepare().values.remainingMinutes == "1", "last partial minute remains blocked")
now = landed + T.COOLDOWN_MS
a = prepare(); check(a.success, "six hours exactly releases travel"); a.cancel()
-- Recreating the runtime models a server restart: persisted timestamps are ignored.
package.loaded.ApocExtractionMapUtils_SafehouseTravel = nil
ApocExtractionMapUtils.SafehouseTravel = nil
D.actions["player.teleport_safehouse"] = nil
T = require "ApocExtractionMapUtils_SafehouseTravel"
now = landed + 1000
a = prepare(); check(a.success, "new server runtime has no cooldown"); a.cancel()
now = landed + T.COOLDOWN_MS + 1000
currentSafe = nil
check(prepare().responsePool == "safehouse.teleport.no_safehouse" and next(state) == nil, "no safehouse does not change cooldown")
currentSafe = safe; accepted = false
a = prepare(); depart(a)
check(next(state) == nil, "rejected packet leaves cooldown intact")
accepted = true; a = prepare(); depart(a); now = now + 21000; tick()
check(next(state) == nil, "timeout does not consume cooldown")
a = prepare(); depart(a); connected = false; tick(); connected = true
check(next(state) == nil, "disconnect does not consume cooldown")
vehicle = {}; check(prepare().responsePool == "safehouse.teleport.unavailable", "vehicle transfer refused"); vehicle = nil
alive = false; check(not prepare().success, "dead player refused"); alive = true
-- Cold/absent squares must not gate the native teleport request.
local streamingCalls = 0
getCell = function() error("safehouse travel must not query loaded squares") end
ApocBRLobbyStreaming={keepCellLoaded=function() streamingCalls=streamingCalls+1; error("must not preload") end}
local coldRequests=requests
a=prepare(); check(a.success,"unloaded safehouse is immediately eligible"); depart(a)
check(requests==coldRequests+1 and streamingCalls==0,"native teleport sent without preloading a destination chunk")
check(lastDestination[1]==100 and lastDestination[2]==200 and lastDestination[3]==0,"destination matches vanilla admin safehouse origin, not its center")
now=now+21000; tick()
a = prepare(); currentSafe = nil; local before = requests; a.afterResponse()
check(requests == before and next(state) == nil, "membership revalidated after response"); currentSafe = safe
D.registerAction("test.failure", function() error("handler failed") end)
check(not D.executeAction(player, {}, {id="test.failure",responsePrefix="safehouse.teleport"}).success, "callback error fails closed")
check(not D.executeAction(player, {}, {id="missing",responsePrefix="safehouse.teleport"}).success, "missing callback uses unavailable outcome")
check(logged("ARMED") and logged("TELEPORT_SENT") and logged("ARRIVED"), "operational stages visible with debug disabled")
check(logged("reason=bridge_rejected") and logged("reason=arrival_timeout"), "native refusal and timeout no longer disappear silently")
local teleport = ApocBRHumanAPI.teleport
ApocBRHumanAPI.teleport = function() error("native test failure") end
a = prepare(); depart(a)
check(logged("bridge_error:") and logged("native test failure"), "native exception preserved in terminal log")
ApocBRHumanAPI.teleport = teleport
local originalSafehouseLookup = SafeHouse.hasSafehouse
a = prepare(); a.afterResponse()
SafeHouse.hasSafehouse = function() error("safehouse test failure") end
tick()
check(logged("tick_error:") and logged("safehouse test failure"), "polling error releases reservation with diagnostics")
SafeHouse.hasSafehouse = originalSafehouseLookup
a = prepare(); check(a.success, "polling exception leaves account able to retry"); a.cancel()
currentSafe={getX=function() return 100 end,getY=function() return 200 end,
    getW=function() return 1 end,getH=function() return 1 end}
getCell=function() return {getGridSquare=function() return freeSquare end} end
ApocBRLobbyStreaming.keepCellLoaded=function() return 1 end
a=prepare(); check(a.success,"one-tile safehouse can provide a valid landing tile"); depart(a)
x,y=99.5,200.5; tick()
check(prepare().responsePool=="safehouse.teleport.unavailable","standing next to a one-tile safehouse cannot start cooldown")
x,y=100.5,200.5; tick()
check(prepare().responsePool=="safehouse.teleport.cooldown","entering the actual one-tile landing square starts the memory timer")
output("Passed " .. checks .. " safehouse travel and action registry checks.")
