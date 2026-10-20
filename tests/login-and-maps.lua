-- Run from the repository root with Lua, or:
-- npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. media .. "client/?.lua;" .. package.path
SandboxVars = { ApocExtractionMapUtils = {} }

local callbacks, tickCallbacks, createCallbacks = {}, {}, {}
Events = {
    OnGameStart = { Add = function(callback) callbacks[#callbacks + 1] = callback end },
    OnTick = { Add = function(callback) tickCallbacks[#tickCallbacks + 1] = callback end },
    OnCreatePlayer = { Add = function(callback) createCallbacks[#createCallbacks + 1] = callback end },
}
local player = { moves = 0 }
function player:isDead() return self.dead == true end
function player:teleportTo(x, y, z)
    self.moves = self.moves + 1
    self.x, self.y, self.z = x, y, z
end
function player:setForceX(x) self.x = x end
function player:setForceY(y) self.y = y end
function player:setLastZ(z) self.lastZ = z end
function getNumActivePlayers() return 1 end
function getSpecificPlayer(index) assert(index == 0); return player end

dofile(media .. "client/ApocExtractionMapUtils_Login.lua")
assert(#callbacks == 1)
callbacks[1]()
assert(player.moves == 0, "unconfigured lobby must preserve the saved spawn")
local options = SandboxVars.ApocExtractionMapUtils
options.LobbyX, options.LobbyY, options.LobbyZ = 100, 200, 2
callbacks[1]()
assert(player.moves == 0, "coordinates alone must not enable lobby relocation")
options.RelocateOnLogin = true
callbacks[1]()
assert(player.moves == 0, "master lobby option must override existing relocation settings")
options.LobbyEnabled = true
options.RelocateOnLogin = nil
callbacks[1]()
assert(player.moves == 0, "relocation must require its own explicit opt-in")
options.RelocateOnLogin = true
callbacks[1]()
assert(player.moves == 1 and player.x == 100.5 and player.y == 200.5)
assert(player.z == 2 and player.lastZ == 2)
-- Simulate moving away and entering another session with the same character.
player.x, player.y = 500, 600
callbacks[1]()
assert(player.moves == 2 and player.x == 100.5 and player.y == 200.5)
options.RelocateOnLogin = false
callbacks[1]()
assert(player.moves == 2, "disabled relocation must preserve the saved position")
options.RelocateOnLogin = true
options.LobbyY = -1
callbacks[1]()
assert(player.moves == 2, "both lobby axes must be configured")
options.LobbyY, options.LobbyZ = 200, 32
callbacks[1]()
assert(player.moves == 2, "invalid floors must not relocate")
options.LobbyZ = -1
player.dead = true
callbacks[1]()
assert(player.moves == 2, "dead players must not relocate")
player.dead = false
callbacks[1]()
assert(player.moves == 3 and player.z == -1, "basement floors are supported")

-- Match the reference mod: known flags only, with no minimap API mutations.
local now, multiplayer = 0, true
function getTimestampMs() return now end
function isClient() return multiplayer end
local grid = { minX = 0, minY = 0, maxX = 2, maxY = 2 }
function grid:getMinX() return self.minX end
function grid:getMinY() return self.minY end
function grid:getMaxX() return self.maxX end
function grid:getMaxY() return self.maxY end
local world = { getMetaGrid = function() return grid end }
function getWorld() return world end
local native = { writes = 0 }
function native:setKnownInSquares(x1, y1, x2, y2)
    self.writes = self.writes + 1
    self.bounds = { x1, y1, x2, y2 }
    self.known = true
end
WorldMapVisited = { getInstance = function() return native end }
local requests, serverCallbacks = {}, {}
function sendClientCommand(p, module, command, args)
    requests[#requests + 1] = { player = p, module = module, command = command, args = args }
end
Events.OnServerCommand = { Add = function(f) serverCallbacks[#serverCallbacks + 1] = f end }
ISWorldMap = {
    IsAllowed = function() return false end,
    NeedsLight = function() return true end,
    initDataAndStyle = function() return 'init' end,
    setHideUnvisitedAreas = function() return 'fog' end,
    ShowWorldMap = function(...) return 'show', ... end,
}
local miniVisible = false
function getPlayerMiniMap()
    return { isReallyVisible = function() return miniVisible end }
end
ISMiniMap = {
    IsAllowed = function() return false end,
    NeedsLight = function() return true end,
    InitPlayer = function() return 'native minimap' end,
    ToggleMiniMap = function() miniVisible = not miniVisible; return 'toggle' end,
}
local miniInit = ISMiniMap.InitPlayer
local worldInit, setFog = ISWorldMap.initDataAndStyle, ISWorldMap.setHideUnvisitedAreas
package.loaded['ISUI/Maps/ISWorldMap'] = true
package.loaded['ISUI/Maps/ISMiniMap'] = true
-- Cartography has its own regression harness; this one exercises reveal/login.
package.loaded['ApocExtractionMapUtils_Cartography'] = true
dofile(media .. 'client/ApocExtractionMapUtils_Maps.lua')
assert(ISMiniMap.InitPlayer == miniInit, 'minimap loading must be untouched')
assert(ISWorldMap.initDataAndStyle == worldInit and ISWorldMap.setHideUnvisitedAreas == setFog,
    'reveal must not replace cartography setup or fog settings')
assert(ISWorldMap.IsAllowed() and ISMiniMap.IsAllowed())
assert(not ISWorldMap.NeedsLight() and not ISMiniMap.NeedsLight())
local function create()
    for _, callback in ipairs(createCallbacks) do callback(0, player) end
end
local function advance(ms)
    now = now + ms
    for _, callback in ipairs(tickCallbacks) do callback() end
end
create()
assert(native.known and native.writes == 1 and native.bounds[3] == 767)
assert(#requests == 1 and requests[1].player == player and requests[1].command == 'RevealMap')
assert(next(requests[1].args) == nil, 'requests must not supply world coordinates')
local oldMoves = player.moves
options.LobbyEnabled = false
callbacks[2]()
create()
assert(native.writes == 1, 'UI reset / game-start must not duplicate the same session')
assert(player.moves == oldMoves, 'reveal must not relocate players')
native.known = false
serverCallbacks[1]('ApocExtractionMapUtils', 'MapRevealed', {})
assert(native.known and #requests == 1, 'server ack repairs client without an ack loop')
assert(ISWorldMap.ShowWorldMap(0, 100, 200, 15) == 'show')
local before = native.writes
advance(999)
assert(native.writes == before, 'map-open retries must wait for the server reply')
advance(1)
assert(native.writes == before + 1 and #requests == 2)
native.known = false
advance(3000)
assert(native.known, 'late PlayerVisited replacement must be repaired')
advance(86000)
local finished = native.writes
advance(900000)
assert(native.writes == finished, 'finite retries must stop')
for i = 1, 100 do ISWorldMap.ShowWorldMap(0) end
advance(1000)
assert(native.writes == finished + 1, 'repeated map opens must coalesce')
advance(3000)
assert(native.writes == finished + 2)
assert(ISMiniMap.ToggleMiniMap(0) == 'toggle' and miniVisible)
local beforeMiniOpen = native.writes
native.known = false
advance(1000)
assert(native.known and native.writes == beforeMiniOpen + 1,
    'opening the minimap after login retries finish must repair late server data')
assert(ISMiniMap.ToggleMiniMap(0) == 'toggle' and not miniVisible)

-- Missing metagrid at initialization remains retryable.
world = nil
assert(ApocExtractionMapUtils.Reveal.localReveal() == false)
world = { getMetaGrid = function() return grid end }
assert(ApocExtractionMapUtils.Reveal.localReveal() == true)
local callbackCount = #tickCallbacks
dofile(media .. 'client/ApocExtractionMapUtils_Reveal.lua')
assert(#tickCallbacks == callbackCount, 'autoload must not register a second scheduler')

-- Blocks retain negative coordinates and clip the last partial block.
grid.minX, grid.maxX, grid.maxY = -1, 32, 0
local blocks = {}
ApocExtractionMapUtils.eachRevealBlock(function(...) blocks[#blocks + 1] = { ... } end)
assert(#blocks == 2 and blocks[1][1] == -256 and blocks[1][3] == 7935)
assert(blocks[2][1] == 7936 and blocks[2][3] == 8447 and blocks[2][4] == 255)
grid.minX, grid.maxX, grid.maxY = 0, 2, 2

local prior = player
player = setmetatable({ moves = 0 }, { __index = prior })
create()
assert(requests[#requests].player == player, 'respawn must use the new player instance')
multiplayer = false
player = setmetatable({ moves = 0 }, { __index = prior })
local sent = #requests
create()
assert(#requests == sent, 'singleplayer must reveal without server commands')
advance(90000)
local spWrites = native.writes
advance(90000)
assert(native.writes == spWrites, 'singleplayer needs no MP retry pump')

options.ForceMapReveal = false
local disabledWrites = native.writes
advance(30000)
create()
serverCallbacks[1]('ApocExtractionMapUtils', 'MapRevealed', {})
assert(native.writes == disabledWrites, 'disabled option must not reveal')
assert(not ISWorldMap.IsAllowed() and not ISMiniMap.IsAllowed())
assert(ISWorldMap.NeedsLight() and ISMiniMap.NeedsLight())
print('PASS: login relocation; known-only reveal; native minimap hooks preserved; bounded MP retries; ack repair; respawn; SP; disabled behavior')
