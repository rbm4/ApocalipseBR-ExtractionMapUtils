local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. media .. "server/?.lua;" .. package.path
SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = true, RelocateOnLogin = true, LobbyX = 100, LobbyY = 200 } }
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
IsoFlagType = { water = "water", solidfloor = "solidfloor" }
local function object(flags, material)
    return { getProperties = function() return {
        has = function(_, key) return flags[key] == true end,
        get = function(_, key) if key == "FloorMaterial" then return material end end,
    } end }
end
local square = { objects = {}, water = false, floor = true }
function square:getFloor() return self.floor or nil end
function square:isWaterSquare() return self.water end
function square:getObjects() return { size = function() return #self.objects end, get = function(_, i) return self.objects[i + 1] end } end
local loaded = true
function getCell() return { getGridSquare = function() if loaded then return square end end } end
local grid = {}
function grid:getMinX() return -1 end
function grid:getMinY() return 0 end
function grid:getMaxX() return 1 end
function grid:getMaxY() return 1 end
function grid:isValidSquare(x, y) return x >= -256 and x < 512 and y >= 0 and y < 512 end
function getWorld() return { getMetaGrid = function() return grid end } end
local player = { x = 10, y = 20, z = 0 }
function player:getX() return self.x end
function player:getY() return self.y end
function player:getZ() return self.z end
function player:getVehicle() return self.vehicle end
function player:isDead() return false end
function player:getOnlineID() return 1 end
assert(Utils.loginPositionNeedsReset(player) == false, "valid land reconnect stays")
player.x = 512
assert(Utils.loginPositionNeedsReset(player) == false, "east boundary no longer triggers rescue")
player.x = -256
assert(Utils.loginPositionNeedsReset(player) == false, "negative map cells are supported")
player.x = -256.1
assert(Utils.loginPositionNeedsReset(player) == false, "negative out-of-map positions no longer trigger rescue")
player.x, player.y = 10, 512
assert(Utils.loginPositionNeedsReset(player) == false, "south boundary no longer triggers rescue")
player.y = -0.1
assert(Utils.loginPositionNeedsReset(player) == false, "north boundary no longer triggers rescue")
player.y = 20
square.water = true
assert(Utils.loginPositionNeedsReset(player) == true, "water floor requires rescue")
square.water = false
square.objects = { object({ water = true, solidfloor = true }) }
assert(Utils.loginPositionNeedsReset(player) == true, "water flag is sufficient even without FloorMaterial")
square.objects = { object({ solidfloor = true }, "Water") }
assert(Utils.loginPositionNeedsReset(player) == true, "water material must not count as a safe floor")
square.objects[2] = object({ solidfloor = true }, "Wood")
assert(Utils.loginPositionNeedsReset(player) == false, "bridge or built floor over water is safe")
square.objects = { object({ water = true }) }
player.vehicle = {}
assert(Utils.loginPositionNeedsReset(player) == false, "offshore passenger stays")
player.x = 9999
assert(Utils.loginPositionNeedsReset(player) == false, "out-of-map vehicle position is preserved")
player.x, player.vehicle, loaded = 10, nil, false
assert(Utils.loginPositionNeedsReset(player) == nil, "unloaded tile is unknown")
loaded, square.floor = true, false
assert(Utils.loginPositionNeedsReset(player) == nil, "floor not streamed yet is unknown")
square.floor = true
-- Exercise the real server request handler, without perimeter startup.
local handler, response
Events = {}
for _, name in ipairs({ "OnClientCommand", "OnServerStarted", "LoadGridsquare", "OnTick" }) do
    Events[name] = { Add = function(f) if name == "OnClientCommand" then handler = f end end }
end
function isClient() return false end
function sendServerCommand(target, module, command, args)
    assert(target == player and module == "ApocExtractionMapUtils" and command == "LoginLobbyState")
    response = args
end
dofile(media .. "server/ApocExtractionMapUtils_Lobby.lua")
dofile("ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_LoginServer.lua")
handler("ApocExtractionMapUtils", "LoginLobbyState", player, { reset = false, x = 100, y = 200, playerNum = 1 })
assert(response.reset and not response.closed and response.playerNum == 1, "server uses its own water square, ignoring forged coordinates")
loaded = false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(response.retry and not response.reset, "server requests retry for unknown geometry")
player.x = 9999
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(not response.reset and not response.retry, "out-of-map login stays even without a loaded tile")
SandboxVars.ApocExtractionMapUtils.RelocateOnLogin = false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(not response.reset and not response.retry, "disabled relocation skips geometry validation")
SandboxVars.ApocExtractionMapUtils.RelocateOnLogin = true
-- Closed-lobby policy is independently configurable and doors always override it.
local savedIsClosed = Utils.Lobby.isClosed
Utils.Lobby.isClosed = function() return true end
player.x, loaded, square.water, square.objects = 10, true, false, {}
local options = SandboxVars.ApocExtractionMapUtils
for _, switch in ipairs({true, false}) do
    options.RelocateOnClosedLobby = switch
    for count = 0, 6 do
        options.LobbyDoorCount = count
        handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
        assert(response.closed == (switch and count == 0) and not response.reset,
            "only enabled zero-door closed lobbies may request login relocation")
    end
end
options.RelocateOnClosedLobby, options.LobbyDoorCount = nil, nil
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(not response.closed, "missing door option uses the shared default of three")
options.LobbyDoorCount = 0
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(response.closed, "missing switch preserves zero-door closed-lobby behavior")
Utils.Lobby.isClosed = savedIsClosed
options.LobbyDoorCount = nil
local changed, accepted, teleports, historyReady = true, true, 0, false
ApocBRPlayerLogin = {
    isReady = function(p) assert(p == player); return historyReady end,
    hasChangedServer = function(p) assert(p == player); return changed end,
    teleportToLobby = function(p, x, y, z)
        assert(p == player and x == 100.5 and y == 200.5 and z == 0)
        teleports = teleports + 1
        return accepted
    end,
}
player.x, loaded, square.objects = 10, true, {}
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(response.retry and not response.reset and teleports == 0,
    "pending login audit must not become a completed safe-land decision")
historyReady = true
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(response.reset and response.serverTeleported and teleports == 1,
    "server change rescues even safe land during an operation using native movement")
changed = false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, { changedServer = true })
assert(not response.reset and not response.serverTeleported and teleports == 1,
    "client cannot forge server history; same-server safe reconnect stays")
player.x, loaded = 9999, false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(not response.reset and not response.retry and teleports == 1,
    "same-server out-of-map reconnect must not invoke native teleport or retry terrain")
changed, accepted = true, false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(response.retry and not response.reset and not response.closed,
    "native teleport not ready must retry without instructing client placement")
-- Death respawns use an independent option before history/geometry/closed-lobby decisions.
ApocBRPlayerLogin.isRespawn = function() return true end
accepted = true
local beforeRespawn = teleports
local originalIsClosed = Utils.Lobby.isClosed
Utils.Lobby.isClosed = function() return true end
SandboxVars.ApocExtractionMapUtils.RelocateOnRespawn = false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, { respawn = false, changedServer = true })
assert(not response.reset and not response.closed and response.respawn and teleports == beforeRespawn,
    "disabled respawn must preserve the native spawn even when origin says changed server")
SandboxVars.ApocExtractionMapUtils.RelocateOnLogin = false
SandboxVars.ApocExtractionMapUtils.RelocateOnRespawn = true
historyReady = false
handler("ApocExtractionMapUtils", "LoginLobbyState", player, {})
assert(response.reset and response.respawn and response.serverTeleported and teleports == beforeRespawn + 1,
    "enabled respawn works independently of login relocation and pending audit")
ApocBRPlayerLogin.isRespawn = function() return false end
handler("ApocExtractionMapUtils", "LoginLobbyState", player, { respawn = true })
assert(not response.reset and not response.closed and not response.respawn and teleports == beforeRespawn + 1,
    "client cannot forge respawn classification to bypass the disabled login option")
SandboxVars.ApocExtractionMapUtils.RelocateOnRespawn = false
Utils.Lobby.isClosed = originalIsClosed
ApocBRPlayerLogin = nil
-- The single-player hook uses the same geometry rules after release.
SandboxVars.ApocExtractionMapUtils.RelocateOnLogin = true
local callbacks, clock = {}, 0
for _, name in ipairs({ "OnGameStart", "OnTick", "OnServerCommand", "OnCreatePlayer" }) do
    Events[name] = { Add = function(f) callbacks[name] = f end }
end
ModData = { get = function() return { released = true } end }
function getNumActivePlayers() return 1 end
function getSpecificPlayer() return player end
function getTimestampMs() return clock end
player.moves = 0
function player:teleportTo(x, y, z) self.moves = self.moves + 1; self.x, self.y, self.z = x, y, z end
function player:setForceX(x) self.x = x end
function player:setForceY(y) self.y = y end
function player:setLastZ(z) self.z = z end
dofile("ApocalipseBR-ExtractionMapUtils/common/media/lua/client/ApocExtractionMapUtils_Login.lua")
player.x, loaded = 9999, false
callbacks.OnGameStart()
assert(player.moves == 0 and player.x == 9999, "single player preserves out-of-map login after release")
player.x = 10
loaded, square.objects = true, {}
callbacks.OnGameStart()
assert(player.moves == 0, "safe single-player reconnect stays")
loaded = false
callbacks.OnGameStart(); callbacks.OnTick()
assert(player.moves == 0)
loaded, square.objects, clock = true, { object({ water = true }) }, 1000
callbacks.OnTick()
assert(player.moves == 1, "single-player water rescue waits for terrain streaming")
-- Single-player uses the same switch and door override.
ModData = { get = function() return { released = false } end }
square.water, square.objects, loaded = false, {}, true
for _, switch in ipairs({true, false}) do
    options.RelocateOnClosedLobby = switch
    for count = 0, 6 do
        options.LobbyDoorCount = count
        local before = player.moves
        callbacks.OnGameStart(); callbacks.OnTick()
        assert(player.moves == before + ((switch and count == 0) and 1 or 0),
            "single-player closed-lobby placement must respect switch and doors")
    end
end
print("PASS: disabled out-of-map rescue, water rescue, land/boat/bridge reconnects, unknown geometry and server-owned login decisions")
