local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
SandboxVars = { ApocExtractionMapUtils = {
    LobbyEnabled = true, RelocateOnLogin = true, LobbyX = 100, LobbyY = 200, LobbyZ = 0,
} }
local handlers, sent = {}, 0
local now = 0
function getTimestampMs() return now end
Events = {}
for _, name in ipairs({ "OnGameStart", "OnTick", "OnServerCommand", "OnCreatePlayer" }) do
    Events[name] = { Add = function(f) handlers[name] = f end }
end
function isClient() return true end
local player = { moves = 0 }
function player:isDead() return self.dead == true end
function player:getOnlineID() return 1 end
function player:teleportTo(x, y, z) self.moves = self.moves + 1; self.x, self.y, self.z = x, y, z end
function player:setForceX(x) self.x = x end
function player:setForceY(y) self.y = y end
function player:setLastZ(z) self.z = z end
function getSpecificPlayer() return player end
function getNumActivePlayers() return 1 end
function sendClientCommand(p, module, command, args)
    assert(p == player and module == "ApocExtractionMapUtils" and command == "LoginLobbyState" and args.playerNum == 0)
    sent = sent + 1
end
dofile("ApocalipseBR-ExtractionMapUtils/common/media/lua/client/ApocExtractionMapUtils_Login.lua")
local function reply(args) handlers.OnServerCommand("ApocExtractionMapUtils", "LoginLobbyState", args) end
reply({ closed = true })
assert(player.moves == 0, "unsolicited state must not teleport")
handlers.OnGameStart()
assert(sent == 0 and player.moves == 0, "login must wait until after the connect packet")
handlers.OnTick(); handlers.OnTick()
assert(sent == 1 and player.moves == 0, "request once and preserve position while state is unknown")
reply({ closed = false }); reply({ closed = true })
assert(player.moves == 0, "active operation and duplicate replies must preserve position")
handlers.OnGameStart(); handlers.OnTick(); reply({ closed = true })
assert(player.moves == 1 and player.x == 100.5 and player.y == 200.5)
reply({ closed = true })
assert(player.moves == 1, "relocation must run once per login")
handlers.OnGameStart(); handlers.OnTick(); reply(nil)
assert(player.moves == 1, "malformed state must not relocate")
handlers.OnGameStart(); handlers.OnTick()
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = false
reply({ closed = true })
assert(player.moves == 1, "settings must be checked again when the reply arrives")
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = true
handlers.OnGameStart(); handlers.OnTick(); player.dead = true; reply({ closed = true })
assert(player.moves == 1, "dead players must not relocate")
player.dead = false
handlers.OnGameStart(); handlers.OnTick(); reply({ closed = false, reset = true })
assert(player.moves == 2, "invalid position must relocate even during an operation")
reply({ reset = true })
assert(player.moves == 2, "duplicate rescue replies must not relocate twice")
handlers.OnGameStart(); handlers.OnTick(); reply({ retry = true })
local before = sent
handlers.OnTick()
assert(sent == before, "streaming retries must be paced")
now = now + 1000; handlers.OnTick()
assert(sent == before + 1)
reply({ reset = true })
assert(player.moves == 3, "water discovered after streaming must relocate")
handlers.OnGameStart(); handlers.OnTick(); reply({ retry = true })
before = sent
for i = 1, 20 do now = now + 1000; handlers.OnTick(); reply({ retry = true }) end
assert(sent == before + 14 and player.moves == 3, "unknown geometry stops after 15 attempts without teleporting")
local first = player
local second = setmetatable({ moves = 0 }, { __index = first })
function getNumActivePlayers() return 2 end
function getSpecificPlayer(index) if index == 0 then return first else return second end end
function sendClientCommand(p, module, command, args)
    assert(p == getSpecificPlayer(args.playerNum))
    sent = sent + 1
end
handlers.OnGameStart(); handlers.OnTick()
reply({ closed = false, reset = true, playerNum = 1 })
reply({ closed = false, reset = false, playerNum = 0 })
assert(first.moves == 3 and second.moves == 1, "rescue only the local player whose position is invalid")
handlers.OnGameStart(); handlers.OnTick()
reply({ reset = true, serverTeleported = true, playerNum = 0 })
reply({ closed = true, serverTeleported = true, playerNum = 1 })
assert(first.moves == 3 and second.moves == 1, "native server teleport acknowledgement must not trigger a second client teleport")
-- Login hooks may precede usable sandbox settings and connection registration.
local online = -1
function first:getOnlineID() return online end
function second:getOnlineID() return online end
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = false
handlers.OnGameStart()
before = sent
handlers.OnTick()
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = true
online = 1
handlers.OnTick()
assert(sent == before + 2, "early disabled/missing settings must not permanently discard login before online readiness")
reply({ reset = true, serverTeleported = true, playerNum = 0 })
reply({ reset = true, serverTeleported = true, playerNum = 1 })
online = -1
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = false
handlers.OnCreatePlayer(0, first)
before = sent
handlers.OnTick()
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = true
online = 1
handlers.OnTick()
assert(sent == before + 1, "OnCreatePlayer must also defer settings until online readiness")
reply({ reset = true, serverTeleported = true, playerNum = 0 })
print("PASS: deferred, one-shot login decisions; invalid-position rescue, safe reconnects and bounded streaming retries")
