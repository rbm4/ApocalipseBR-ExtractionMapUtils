local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
local function fixture(opts)
    opts = opts or {}
    ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils_LobbySettings = nil
    SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = opts.lobby ~= false,
        LobbyCleanupZombies = opts.enabled, LobbyX1 = 14, LobbyX2 = 7,
        LobbyY1 = 14, LobbyY2 = 7, LobbyFenceZ = 1 } }
    function isClient() return opts.client == true end
    function isServer() return not opts.client and not opts.singleplayer end
    function instanceof(obj, kind) return obj.kind == kind end
    local f = { squares = {}, removed = 0, lookups = 0, packets = {}, hooks = {} }
    Events = {}
    for _, event in ipairs({ "LoadChunk", "OnTick", "OnServerCommand" }) do
        f.hooks[event] = {}
        Events[event] = { Add = function(fn) table.insert(f.hooks[event], fn) end }
    end
    function f.fire(event, ...)
        if event == "LoadChunk" and not (...).getGridSquare then
            local chunk = ...
            function chunk:getGridSquare(sx, sy, z)
                return { getX = function() return self.wx * 8 + sx end,
                    getY = function() return self.wy * 8 + sy end }
            end
        end
        for _, fn in ipairs(f.hooks[event]) do fn(...) end
    end
    local cell = {}
    function cell:getGridSquare(x, y, z)
        f.lookups = f.lookups + 1
        return f.squares[x .. ":" .. y .. ":" .. z]
    end
    function getCell() return cell end
    function sendServerCommand(module, command, args)
        f.packets[#f.packets + 1] = { module, command, args }
    end
    function f.add(x, y, z, id, kind, reanimated)
        local key = x .. ":" .. y .. ":" .. z
        local square = f.squares[key]
        if not square then
            square = { objects = {} }
            function square:getMovingObjects()
                return { size = function() return #self.objects end, get = function(_, i) return self.objects[i + 1] end }
            end
            f.squares[key] = square
        end
        local obj = { kind = kind or "IsoZombie", removed = false }
        function obj:getOnlineID() return id end
        function obj:isReanimatedPlayer() return reanimated == true end
        function obj:removeFromWorld() self.worldRemoved = true end
        function obj:removeFromSquare()
            assert(self.worldRemoved)
            self.removed = true
            f.removed = f.removed + 1
            for i, item in ipairs(square.objects) do
                if item == self then table.remove(square.objects, i); break end
            end
        end
        table.insert(square.objects, obj)
        return obj
    end
    dofile(media .. "server/ApocExtractionMapUtils_LobbyCleanup.lua")
    return f
end
for _, opts in ipairs({ {}, { enabled = false }, { enabled = true, lobby = false }, { enabled = true, client = true } }) do
    local f = fixture(opts)
    local z = f.add(8, 8, 1, 1)
    f.fire("LoadChunk", { wx = 1, wy = 1 }); f.fire("OnTick")
    assert(not z.removed and f.lookups == 0 and #f.packets == 0, "cleanup must require server authority and both options")
end
local f = fixture({ enabled = true })
dofile(media .. "server/ApocExtractionMapUtils_LobbyCleanup.lua")
assert(#f.hooks.LoadChunk == 1 and #f.hooks.OnTick == 0, "reloads must not duplicate handlers or add periodic sweeps")
local inside = f.add(8, 8, 1, 1)
local inside2 = f.add(8, 8, 1, 2)
local corner = f.add(14, 14, 1, 3)
local border = f.add(7, 7, 1, 4)
local outside = f.add(15, 8, 1, 5)
local below = f.add(8, 8, 0, 6)
local player = f.add(8, 8, 1, 7, "IsoPlayer")
local reanimated = f.add(8, 8, 1, 8, nil, true)
f.fire("LoadChunk", { wx = 50, wy = 50 }); f.fire("OnTick")
assert(f.lookups == 0, "outside chunks must do no world lookups")
f.fire("LoadChunk", { wx = 1, wy = 1 })
local beforeTick = f.add(8, 8, 1, 20)
f.fire("LoadChunk", { wx = 1, wy = 1 })
f.fire("OnTick")
assert(inside.removed and inside2.removed and corner.removed and not border.removed and not beforeTick.removed)
assert(not outside.removed and not below.removed and not player.removed and not reanimated.removed)
assert(f.lookups == 49 and #f.packets == 1 and #f.packets[1][3].ids == 3)
local entrant = f.add(8, 8, 1, 9)
for i = 1, 200 do f.fire("OnTick") end
f.fire("LoadChunk", { wx = 1, wy = 1 }); f.fire("OnTick")
assert(not entrant.removed and f.lookups == 49, "later spawns/entrants and chunk reloads must remain untouched")
f.fire("LoadChunk", { wx = 0, wy = 0 }); f.fire("OnTick")
assert(border.removed, "late natural loading must clear only the newly loaded portion")
local empty = fixture({ enabled = true })
empty.fire("LoadChunk", { getGridSquare = function() return nil end })
assert(empty.lookups == 0, "an absent floor must not force world loading")
empty.fire("LoadChunk", { wx = 1, wy = 1 }); empty.fire("OnTick")
local late = empty.add(8, 8, 1, 10)
empty.fire("LoadChunk", { wx = 1, wy = 1 }); empty.fire("OnTick")
assert(not late.removed and #empty.packets == 0, "empty initial chunks are still consumed; no waiting for spawns")
local invalid = fixture({ enabled = true })
SandboxVars.ApocExtractionMapUtils.LobbyFenceZ = 100
invalid.fire("LoadChunk", { wx = 1, wy = 1 })
assert(invalid.lookups == 0 and #invalid.packets == 0, "invalid geometry must not mutate the world")
local sp = fixture({ enabled = true, singleplayer = true })
local spZed = sp.add(8, 8, 1, -1)
sp.fire("LoadChunk", { wx = 1, wy = 1 }); sp.fire("OnTick")
assert(spZed.removed and #sp.packets == 0)
local restart = fixture({ enabled = true })
local restarted = restart.add(8, 8, 1, 1)
restart.fire("LoadChunk", { wx = 1, wy = 1 }); restart.fire("OnTick")
assert(restarted.removed, "server restart must reset session-only chunk history")
-- Client mirrors only server-selected identities, never a local area sweep.
local client = fixture({ client = true })
local mirrored = client.add(8, 8, 1, 1)
local survivor = client.add(8, 8, 1, 99)
dofile(media .. "client/ApocExtractionMapUtils_LobbyCleanupClient.lua")
dofile(media .. "client/ApocExtractionMapUtils_LobbyCleanupClient.lua")
assert(#client.hooks.OnServerCommand == 1)
client.fire("OnServerCommand", "Other", "LobbyCleanupZombies", {})
client.fire("OnServerCommand", table.unpack(f.packets[1]))
assert(mirrored.removed and not survivor.removed)
print("PASS: opt-in initial chunk cleanup, bounds/floor, natural loading, no recurring deletion, restart, SP and server-selected client sync")
