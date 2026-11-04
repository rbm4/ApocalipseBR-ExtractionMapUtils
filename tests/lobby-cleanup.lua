local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
local output = print
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
    local f = { squares = {}, removed = 0, lookups = 0, packets = {}, hooks = {}, clock = 0, logs = {}, requests = {} }
    function getTimestampMs() return f.clock end
    function print(message) f.logs[#f.logs + 1] = message end
    ApocBRLobbyStreaming = { keepCellLoaded = function(x, y)
        f.requests[#f.requests + 1] = { x, y }
        if opts.bridgeError then error("loader fault") end
        return opts.ready == nil and 1 or opts.ready
    end }
    if opts.noBridge then ApocBRLobbyStreaming = nil end
    function f.pump(n)
        for _ = 1, n do f.clock = f.clock + 1000; f.fire("OnTickEvenPaused") end
    end
    function f.logged(text)
        for _, message in ipairs(f.logs) do if message:find(text, 1, true) then return true end end
        return false
    end
    Events = {}
    for _, event in ipairs({ "LoadChunk", "OnTick", "OnServerCommand", "OnServerStarted", "OnTickEvenPaused" }) do
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
    f.fire("OnServerStarted"); f.pump(10)
    assert(not z.removed and f.lookups == 0 and #f.requests == 0)
end
local f = fixture({ enabled = true })
dofile(media .. "server/ApocExtractionMapUtils_LobbyCleanup.lua")
assert(#f.hooks.OnServerStarted == 1 and #f.hooks.OnTickEvenPaused == 1 and #f.hooks.LoadChunk == 0)
local inside = f.add(8, 8, 1, 1)
local inside2 = f.add(8, 8, 1, 2)
local corner = f.add(14, 14, 1, 3)
local border = f.add(7, 7, 1, 4)
local outside = f.add(15, 8, 1, 5)
local below = f.add(8, 8, 0, 6)
local player = f.add(8, 8, 1, 7, "IsoPlayer")
local reanimated = f.add(8, 8, 1, 8, nil, true)
f.fire("OnServerStarted")
assert(f.lookups == 0 and #f.requests == 0 and f.logged("START:"), "startup must enqueue without blocking")
f.pump(1)
assert(#f.requests == 1 and not inside.removed, "force loading precedes settling and deletion")
local duringLoad = f.add(8, 8, 1, 9)
f.pump(5)
assert(inside.removed and inside2.removed and corner.removed and border.removed and duringLoad.removed)
assert(not outside.removed and not below.removed and not player.removed and not reanimated.removed)
assert(f.lookups == 64 and f.logged("COMPLETE: chunks=4/4, removed=5"))
assert(f.logged("PROGRESS:") and f.logged("CLEANED cell") and f.logged("loading requests released"))
local entrant = f.add(8, 8, 1, 20)
local requested = #f.requests
f.fire("OnServerStarted"); f.fire("LoadChunk", { wx = 1, wy = 1 }); f.pump(200)
assert(not entrant.removed and #f.requests == requested, "completion must release requests and never rerun in-session")
local packets = f.packets
local multi = fixture({ enabled = true })
SandboxVars.ApocExtractionMapUtils.LobbyX1 = 70
SandboxVars.ApocExtractionMapUtils.LobbyX2 = 60
SandboxVars.ApocExtractionMapUtils.LobbyY1 = 70
SandboxVars.ApocExtractionMapUtils.LobbyY2 = 60
local edge = multi.add(70, 70, 1, 4)
multi.fire("OnServerStarted"); multi.pump(30)
assert(edge.removed and multi.logged("COMPLETE: chunks=4/4"))
local sequence = { "0:0", "64:0", "0:64", "64:64" }
local previous, index = nil, 0
for _, request in ipairs(multi.requests) do
    local key = request[1] .. ":" .. request[2]
    if key ~= previous then index = index + 1; assert(key == sequence[index]); previous = key end
end
assert(index == 4, "one cell at a time, no later renewal of released cells")
local waiting = fixture({ enabled = true, ready = 0 })
local waitingZombie = waiting.add(8, 8, 1, 1)
waiting.fire("OnServerStarted"); waiting.pump(3)
assert(not waitingZombie.removed and waiting.lookups == 0)
ApocBRLobbyStreaming.keepCellLoaded = function() return 1 end
waiting.pump(6)
assert(waitingZombie.removed and waiting.logged("COMPLETE:"))
for _, opts in ipairs({ { enabled = true, ready = 0 }, { enabled = true, ready = -1 },
    { enabled = true, bridgeError = true }, { enabled = true, noBridge = true } }) do
    local failed = fixture(opts)
    failed.fire("OnServerStarted"); failed.pump(122)
    assert(failed.logged("FAILED:") and not failed.logged("COMPLETE:"))
    local count = #failed.requests
    failed.pump(10)
    assert(#failed.requests == count and failed.lookups == 0, "failure must stop streaming")
end
local cancel = fixture({ enabled = true })
cancel.fire("OnServerStarted"); cancel.pump(1)
SandboxVars.ApocExtractionMapUtils.LobbyCleanupZombies = false
cancel.pump(10)
assert(cancel.logged("CANCELLED:") and #cancel.requests == 1)
local budget = fixture({ enabled = true })
SandboxVars.ApocExtractionMapUtils.LobbyX1 = 0
SandboxVars.ApocExtractionMapUtils.LobbyX2 = 63
SandboxVars.ApocExtractionMapUtils.LobbyY1 = 0
SandboxVars.ApocExtractionMapUtils.LobbyY2 = 63
budget.fire("OnServerStarted"); budget.pump(6)
assert(budget.lookups == 256 and not budget.logged("COMPLETE:"), "at most four chunks per callback")
budget.pump(15)
assert(budget.lookups == 4096 and budget.logged("COMPLETE: chunks=64/64"))
local invalid = fixture({ enabled = true })
SandboxVars.ApocExtractionMapUtils.LobbyFenceZ = 100
invalid.fire("OnServerStarted"); invalid.pump(10)
assert(invalid.logged("FAILED:") and #invalid.requests == 0)
local empty = fixture({ enabled = true })
empty.fire("OnServerStarted"); empty.pump(10)
assert(empty.logged("COMPLETE: chunks=4/4, removed=0"))
local restart = fixture({ enabled = true })
local restarted = restart.add(8, 8, 1, 1)
restart.fire("OnServerStarted"); restart.pump(10)
assert(restarted.removed, "every new process must run cleanup without persisted completion")
local sp = fixture({ enabled = true, singleplayer = true })
sp.fire("OnServerStarted"); sp.pump(10)
assert(#sp.requests == 0 and sp.logged("SKIPPED:"))
-- Client mirrors only server-selected identities, never a local area sweep.
local client = fixture({ client = true })
local mirrored = client.add(8, 8, 1, 1)
local survivor = client.add(8, 8, 1, 99)
dofile(media .. "client/ApocExtractionMapUtils_LobbyCleanupClient.lua")
dofile(media .. "client/ApocExtractionMapUtils_LobbyCleanupClient.lua")
assert(#client.hooks.OnServerCommand == 1)
client.fire("OnServerCommand", "Other", "LobbyCleanupZombies", {})
for _, packet in ipairs(packets) do client.fire("OnServerCommand", table.unpack(packet)) end
assert(mirrored.removed and not survivor.removed)
output("PASS: startup forced streaming, paused ticks, bounds/floor/exclusions, settling, cell release, logs, timeout/failure/cancellation, restart and client sync")
