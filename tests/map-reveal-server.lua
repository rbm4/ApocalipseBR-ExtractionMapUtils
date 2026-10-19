local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
SandboxVars = { ApocExtractionMapUtils = { ForceMapReveal = true } }
local clock, server, loaded = 0, true, false
function getTimestampMs() return clock end
function isServer() return server end
local grid = {}
function grid:getMinX() return 0 end
function grid:getMinY() return 0 end
function grid:getMaxX() return 2 end
function grid:getMaxY() return 2 end
function getWorld() return { getMetaGrid = function() return grid end } end
local commands, ticks = {}, {}
Events = {
    OnClientCommand = { Add = function(f) commands[#commands + 1] = f end },
    OnTick = { Add = function(f) ticks[#ticks + 1] = f end },
}
local function player(name)
    return { getUsername = function() return name end, isDead = function(self) return self.dead end }
end
local p = player("test")
local online = { p }
function getOnlinePlayers()
    return { size = function() return #online end, get = function(_, index) return online[index + 1] end }
end
local attempts, writes, acks, bounds = 0, 0, 0
WorldMapVisitedServer = { getInstance = function()
    return { setKnownInSquares = function(_, who, x1, y1, x2, y2)
        assert(who == p, "server must use the authenticated player")
        attempts = attempts + 1
        bounds = { x1, y1, x2, y2 }
        if loaded then writes = writes + 1 end
    end }
end }
function sendServerCommand(who, module, command)
    assert(who == p and module == "ApocExtractionMapUtils" and command == "MapRevealed")
    acks = acks + 1
end
dofile(media .. "server/ApocExtractionMapUtils_RevealServer.lua")
local function request(args) commands[1]("ApocExtractionMapUtils", "RevealMap", p, args) end
local function pump(ms) clock = clock + ms; ticks[1]() end
request({ x1 = -999999, x2 = 999999, spawn = true })
assert(attempts == 1 and writes == 0 and acks == 1)
assert(bounds[1] == 0 and bounds[3] == 767, "client-supplied bounds must be ignored")
for i = 1, 20 do request({ spawn = true }) end
assert(attempts == 1, "command spam must be rate limited")
loaded = true
pump(15000)
assert(writes == 1 and acks == 2, "retry must repair a store loaded after the initial request")
for i = 1, 7 do pump(15000) end
local finished = attempts
pump(15000)
assert(attempts == finished, "server retries must stop after eight passes")
-- Native store can disappear/reload later; a map-open command starts a new window.
request()
assert(attempts == finished + 1)
pump(15000)
assert(attempts == finished + 2, "a later map-open request must restart a bounded retry window")
local previous = attempts
commands[1]("Unrelated", "RevealMap", p, {})
commands[1]("ApocExtractionMapUtils", "Other", p, {})
assert(attempts == previous)
p.dead = true
pump(15000)
request()
assert(attempts == previous, "dead players must not request reveal")
p = player("test")
online = { p }
pump(15000)
assert(attempts == previous + 1, "new respawn instance must get its own retry budget")
online = {}
pump(15000)
online = { p }
pump(15000)
assert(attempts == previous + 2, "offline cleanup must allow a new session")
SandboxVars.ApocExtractionMapUtils.ForceMapReveal = false
previous = attempts
request()
pump(15000)
assert(attempts == previous, "disabled sandbox option must stop server writes")
SandboxVars.ApocExtractionMapUtils.ForceMapReveal = true
server = false
request()
pump(15000)
assert(attempts == previous, "client/SP must never run server-only writes")
dofile(media .. "server/ApocExtractionMapUtils_RevealServer.lua")
assert(#commands == 1 and #ticks == 1, "autoload must not duplicate server callbacks")
print("PASS: server known-map store; late store loading; finite retries; command throttling; trusted bounds; respawn; offline cleanup; realm/sandbox guards")
