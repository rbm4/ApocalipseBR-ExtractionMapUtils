local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. media .. "server/?.lua;" .. package.path
local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end
local function fixture(options)
    options = options or {}
    ApocExtractionMapUtils = nil
    ApocBREventControl = nil
    if options.noSandbox then SandboxVars = nil
    else SandboxVars = { ApocExtractionMapUtils = options.sandbox or { LobbyEnabled = true } } end
    for _, name in ipairs({ "ApocExtractionMapUtils", "ApocExtractionMapUtils_LobbyConfig", "ApocExtractionMapUtils_LobbySettings", "ApocBRRCON" }) do
        package.loaded[name] = nil
    end
    local f = { clock = 0, lookups = 0, adds = 0, removes = 0, squares = {}, store = options.store or {}, files = {}, handlers = {} }
    function isClient() return options.client == true end
    function getTimestampMs() return f.clock end
    function getServerName() return "test-server" end
    local uuid = 0
    function getRandomUUID() uuid = uuid + 1; return "private-uuid-" .. uuid end
    function ZombRand(n) f.randomCalls = (f.randomCalls or 0) + 1; return (f.randomCalls * 17) % n end
    IsoFlagType = { collideN = "collideN", collideW = "collideW", CantClimb = "CantClimb",
        HoppableN = "HoppableN", HoppableW = "HoppableW", TallHoppableN = "TallHoppableN", TallHoppableW = "TallHoppableW" }
    -- Effective vanilla flags, including WallNTrans/WallWTrans conversion in
    -- IsoWorld.LoadTileDefinitions, rather than treating every sprite as safe.
    local spriteFlags = {
        fencing_01_88 = { collideN = true, CantClimb = true },
        fencing_01_90 = { collideW = true, CantClimb = true },
        fencing_01_80 = { collideN = true, TallHoppableN = true },
        fencing_01_82 = { collideW = true, TallHoppableW = true },
        fixtures_doors_01_68 = {},
    }
    function getSprite(name)
        if options.missingSprite or not spriteFlags[name] then return nil end
        return { getName = function() return name end,
            getProperties = function() return { has = function(_, flag) return spriteFlags[name][flag] == true end } end }
    end
    ModData = { getOrCreate = function(name) assert(name == "ApocExtractionLobby"); return f.store end }
    function getFileWriter(path, create, append)
        assert(create and not append)
        if options.failWrite then return nil end
        return { write = function(_, text) f.files[path] = text end, close = function() end }
    end
    function getFileReader(path)
        return { readLine = function() return f.files[path] end, close = function() end }
    end
    local eventNames = { "OnServerStarted", "LoadGridsquare", "OnTick", "OnClientCommand" }
    Events = {}
    for _, name in ipairs(eventNames) do
        f.handlers[name] = {}
        Events[name] = { Add = function(handler) table.insert(f.handlers[name], handler) end }
    end
    local cell = {}
    function cell:getGridSquare(x, y, z)
        f.lookups = f.lookups + 1
        f.clock = f.clock + (options.lookupCost or 0)
        if options.unloaded then return nil end
        return f.square(x, y, z)
    end
    function getCell() return cell end
    function f.square(x, y, z)
        local key = x .. ":" .. y .. ":" .. z
        if f.squares[key] then return f.squares[key] end
        local s = { x = x, y = y, z = z, objects = {} }
        function s:getX() return self.x end
        function s:getY() return self.y end
        function s:getZ() return self.z end
        function s:getObjects() return list(self.objects) end
        function s:getZone() return { setHaveConstruction = function(_, flag) self.construction = flag end } end
        function s:AddSpecialObject(object)
            assert(not object.inserted)
            object.inserted = true
            self.objects[#self.objects + 1] = object
            f.adds = f.adds + 1
        end
        function s:transmitRemoveItemFromSquare(object)
            for i, candidate in ipairs(self.objects) do
                if candidate == object then table.remove(self.objects, i); f.removes = f.removes + 1; return i - 1 end
            end
            error("object not on square")
        end
        f.squares[key] = s
        return s
    end
    IsoThumpable = { new = function(_, square, closed, a, b, c)
        assert(c == nil, "lobby must never create door/open-sprite objects")
        local o = { square = square, closed = closed, openSprite = c and a or nil,
            data = {}, open = false, door = false }
        if c then o.north = b else o.north = a end
        for _, field in ipairs({ "MaxHealth", "Health", "IsThumpable", "IsDismantable", "CanBarricade", "IsHoppable", "CanPassThrough", "IsDoor" }) do
            o["set" .. field] = function(self, value) self[field] = value end
        end
        function o:getModData() return self.data end
        function o:getSprite() return { getName = function() return self.closed end } end
        function o:ToggleDoorSilent()
            assert(not self.inserted, "open state must be set before native add/network serialization")
            assert(self.openSprite)
            self.open = not self.open
        end
        function o:IsOpen() return self.open end
        function o:isDoor() return self.IsDoor == true end
        function o:getHealth() return self.Health end
        function o:getMaxHealth() return self.MaxHealth end
        function o:isThumpable() return self.IsThumpable end
        function o:isDismantable() return self.IsDismantable end
        function o:getCanBarricade() return self.CanBarricade end
        function o:isCanPassThrough() return self.CanPassThrough end
        function o:transmitCompleteItemToClients()
            assert(self.inserted and self.square.construction)
            assert(self.Health == 2147483647 and self.MaxHealth == 2147483647)
            assert(self.IsThumpable == false and self.IsDismantable == false and self.CanBarricade == false)
            assert(self.IsHoppable == false and self.CanPassThrough == false)
            self.sent = true
        end
        return o
    end }
    package.preload.ApocBRRCON = function()
        ApocBRRCON = { subscribe = function(module, command, handler)
            assert(module == "ExtractionLobby" and (command == "ReleaseExits" or command == "OpenDoors"))
            f.subscriptions = f.subscriptions or {}
            f.subscriptions[command] = handler
            f.command = handler
        end }
        return ApocBRRCON
    end
    dofile(media .. "server/ApocExtractionMapUtils_Lobby.lua")
    if options.client then assert(not f.command and #f.handlers.OnTick == 0); return f end
    f.lobby = ApocExtractionMapUtils.Lobby
    if options.configure then options.configure(ApocExtractionMapUtils.LobbyConfig) end
    function f.start() f.handlers.OnServerStarted[1]() end
    function f.tick() f.handlers.OnTick[1]() end
    function f.pump(n) for _ = 1, n do f.tick() end end
    function f.load(square) f.handlers.LoadGridsquare[1](square) end
    function f.token() for _, value in pairs(f.files) do return value end end
    function f.objects()
        local result = {}
        for _, square in pairs(f.squares) do for _, object in ipairs(square.objects) do result[#result + 1] = object end end
        return result
    end
    return f
end

fixture({ client = true })
for _, options in ipairs({ { sandbox = {} }, { sandbox = { LobbyEnabled = false } }, { noSandbox = true } }) do
    local disabled = fixture(options)
    local subscribed = false
    Events.OnApocBRLobbyEventDue = { Add = function() subscribed = true end }
    ApocBREventControl = setmetatable({}, { __index = function() error("disabled lobby must not call engine bridge") end })
    disabled.start(); disabled.pump(100)
    disabled.load(disabled.square(14260, 11812, 0))
    assert(disabled.lookups == 0 and disabled.adds == 0 and next(disabled.store) == nil)
    assert(not disabled.command and not package.loaded.ApocBRRCON and not subscribed)
    assert(next(disabled.files) == nil, "disabled lobby must not create command tokens")
    assert(not disabled.lobby.releaseExits("bad") and not disabled.lobby.releaseForEvent("event", 1))
end

local lateSettings = fixture({ noSandbox = true })
lateSettings.start()
SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = true } }
lateSettings.start(); lateSettings.pump(100)
assert(lateSettings.adds == 286 and lateSettings.command,
    "sandbox values arriving after module loading must enable normal startup")

local paused = fixture()
paused.start()
local pausedToken = paused.token()
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = false
paused.load(paused.square(14260, 11812, 0)); paused.pump(100)
assert(paused.lookups == 0 and not paused.command(pausedToken))
assert(not paused.lobby.releaseForEvent("event", 1) and not paused.store.released)
SandboxVars.ApocExtractionMapUtils.LobbyEnabled = true
paused.pump(100)
assert(paused.adds == 286, "re-enabling must resume existing bounded queue")

local unloaded = { unloaded = true }
local f = fixture(unloaded)
f.start()
assert(f.adds == 0 and f.lookups == 0, "startup must only enqueue")
f.tick(); assert(f.lookups == 4, "hard per-tick edge cap")
f.pump(100); assert(f.lookups == 286, "normalized inclusive rectangle must have 286 edges")
f.pump(1000); assert(f.lookups == 286, "missing chunks must not be polled every tick")
local count = 0
for _ in pairs(f.store.exitKeys) do count = count + 1 end
assert(count == 6)
unloaded.unloaded = false
local square = f.square(14260, 11812, 0)
for _ = 1, 100 do f.load(square) end
assert(f.adds == 0, "load hook must not mutate during chunk iteration")
f.tick(); assert(f.adds == 2 and f.lookups == 288, "corner square has north and west edges, each queued only once")
f.load(f.square(14261, 11812, 1)); f.tick(); assert(f.lookups == 288, "ignore other floors")
f.clock = 60000; f.pump(100)
assert(f.adds == 286 and #f.objects() == 286)
local doorObjects = {}
for _, object in ipairs(f.objects()) do
    assert(object.sent and not object:IsOpen() and not object:isDoor(), "closed lobby must prevent ordinary door interaction")
    local x, y = object.square.x, object.square.y
    if object.north then assert((y == 11812 or y == 11893) and x >= 14260 and x <= 14321)
    else assert((x == 14260 or x == 14322) and y >= 11812 and y <= 11892) end
    if object.data.ApocExtractionLobby.exit then doorObjects[#doorObjects + 1] = object end
end
assert(#doorObjects == 6)
for i, door in ipairs(doorObjects) do
    for j = i + 1, #doorObjects do
        local other = doorObjects[j]
        assert(math.abs(door.square.x - other.square.x) + math.abs(door.square.y - other.square.y) > 2, "doors must not form a vehicle-width opening")
    end
end
local adds = f.adds
f.clock = 120000; f.pump(100)
assert(f.adds == adds and f.removes == 0, "rescan must not respawn intact assets")
-- Duplicate owned segments are removed; arbitrary map objects are preserved.
local owned = f.objects()[1]
local unrelated = { getModData = function() return {} end }
owned.square.objects[#owned.square.objects + 1] = unrelated
owned.square.objects[#owned.square.objects + 1] = owned
f.load(owned.square); f.pump(2)
assert(#owned.square.objects >= 2 and f.removes == 1)
local foundUnrelated = false
for _, object in ipairs(owned.square.objects) do if object == unrelated then foundUnrelated = true end end
assert(foundUnrelated, "never remove unrelated map content")
-- Remove the unrelated test object before counting the perimeter again.
for i, object in ipairs(owned.square.objects) do if object == unrelated then table.remove(owned.square.objects, i); break end end
f.removes = 0
assert(not f.command("forged-token") and f.store.released == false)
assert(not f.command({ x = 0, y = 0 }) and f.store.released == false)
local token = f.token()
assert(f.command(token) and f.store.released == true)
assert(f.token() == "consumed" and not f.command(token), "consume before opening; reject replay")
assert(f.adds == adds, "command must queue, not synchronously change exits")
f.pump(2)
assert(f.adds == adds and f.removes == 6 and #f.objects() == 280, "release must remove six fences without adding doors")
for _, object in ipairs(f.objects()) do
    assert(not object.data.ApocExtractionLobby.exit and not object:IsOpen() and not object:isDoor())
end
-- Released gaps must stay empty after both maintenance and chunk-load callbacks.
for _, object in ipairs(doorObjects) do f.load(object.square) end
f.clock = 180000; f.pump(100)
assert(f.adds == adds and #f.objects() == 280, "maintenance must not rebuild released fences")
-- Real object absence, rather than a global built flag, drives repair.
local victim = f.objects()[1]
victim.square:transmitRemoveItemFromSquare(victim)
f.load(victim.square); f.pump(2)
assert(#f.objects() == 280)
local saved = f.store
local persistedKeys = {}
for key in pairs(saved.exitKeys) do persistedKeys[key] = true end
local restarted = fixture({ store = saved })
restarted.start(); restarted.pump(100)
assert(not restarted.randomCalls and saved.released == true, "save reload must retain door layout and release state")
assert(restarted.token() == nil, "already-open save needs no new authorization token")
assert(#restarted.objects() == 280, "restart must retain released gaps")
for key in pairs(saved.exitKeys) do assert(persistedKeys[key]) end
-- Release while unloaded is remembered and applied when those chunks arrive.
local waiting = { unloaded = true }
local late = fixture(waiting)
late.start(); late.pump(100)
assert(late.command(late.token()))
late.pump(2); assert(late.adds == 0)
waiting.unloaded = false
late.clock = 60000; late.pump(100)
for _, object in ipairs(late.objects()) do
    assert(not object.data.ApocExtractionLobby.exit, "late-loaded released exits must not spawn")
end
assert(#late.objects() == 280)
-- Wall-clock budget stops a tick after an expensive edge even below count cap.
local timed = fixture({ lookupCost = 3 })
timed.start(); timed.tick(); assert(timed.lookups == 1)
local io = { failWrite = true }
local fail = fixture(io)
fail.start(); fail.pump(100)
assert(not fail.command("private-uuid-1") and fail.store.released == false)
local consumeIO = {}
local consume = fixture(consumeIO)
consume.start(); local private = consume.token(); consumeIO.failWrite = true
assert(not pcall(consume.command, private) and consume.store.released == false, "consumption I/O must fail closed")
local invalid = fixture({ configure = function(c) c.MaxEdgesPerTick = 100000 end })
invalid.start(); invalid.pump(100); assert(invalid.lookups == 0)
local mismatch = fixture({ store = saved, configure = function(c) c.X1 = c.X1 - 1 end })
mismatch.start(); mismatch.pump(100); assert(mismatch.lookups == 0, "never silently migrate a saved perimeter")
local missing = fixture({ missingSprite = true })
missing.start(); missing.pump(100); assert(missing.lookups == 0)
for _, bad in ipairs({ "fencing_01_80", "fencing_01_82", "fixtures_doors_01_68", "fencing_01_90" }) do
    local unsafe = fixture({ configure = function(c) c.FenceNorth = bad end })
    unsafe.start(); unsafe.pump(100)
    assert(unsafe.lookups == 0, "climbable/passable/wrong-direction sprites must disable initialization")
    assert(unsafe.store.signature == nil, "bad sprites must not mutate the saved layout")
end
-- Upgrade a v0.2.0 save, including old assets that load only AFTER another restart.
local legacySignature = "v1:14260:11812:14321:11892:0:6:constructedobjects_01_48:constructedobjects_01_49:fixtures_doors_01_68:fixtures_doors_01_69:fixtures_doors_01_70:fixtures_doors_01_71"
for _, released in ipairs({ false, true }) do
    local legacyKeys = {}
    for key in pairs(persistedKeys) do legacyKeys[key] = true end
    local legacyStore = { signature = legacySignature, doorKeys = legacyKeys, open = released }
    local deferred = { unloaded = true, store = legacyStore }
    local migrate = fixture(deferred)
    migrate.start(); migrate.pump(100)
    assert(not migrate.randomCalls and legacyStore.released == released and legacyStore.exitKeys == legacyKeys)
    assert(legacyStore.legacySignatures[legacySignature], "retain legacy ownership for unloaded chunks")
    local afterRestart = fixture({ store = legacyStore })
    afterRestart.start()
    for _, point in ipairs({ {14260,11812,true}, {14321,11893,true} }) do
        local s = afterRestart.square(point[1], point[2], 0)
        local key = point[1] .. ":" .. point[2] .. ":N"
        s.objects[#s.objects + 1] = {
            getModData = function() return { ApocExtractionLobby = { signature = legacySignature, key = key, door = false } } end,
        }
    end
    local exitKey = next(legacyKeys)
    local x, y = string.match(exitKey, "^(%d+):(%d+):")
    local s = afterRestart.square(tonumber(x), tonumber(y), 0)
    s.objects[#s.objects + 1] = {
        getModData = function() return { ApocExtractionLobby = { signature = legacySignature, key = exitKey, door = true } } end,
    }
    afterRestart.pump(100)
    assert(afterRestart.removes == 3, "migrate owned walls/doors that load after restart")
    assert(#afterRestart.objects() == (released and 280 or 286))
    for _, object in ipairs(afterRestart.objects()) do
        assert(object.data.ApocExtractionLobby.signature == legacyStore.signature)
        assert(object.closed == (object.north and "fencing_01_88" or "fencing_01_90"))
    end
end
-- Autoload/reload must not multiply subscribers or tick/load hooks.
local reload = fixture()
dofile(media .. "server/ApocExtractionMapUtils_Lobby.lua")
assert(#reload.handlers.OnTick == 1 and #reload.handlers.LoadGridsquare == 1 and #reload.handlers.OnServerStarted == 1)
-- Scheduled activation removes the ENTIRE perimeter, independently of a client
-- relay/token file, and leaves all edges absent through repair/reload/restart.
local event = fixture()
local due, acknowledge, acknowledgements = false, false, 0
local runtimeConfirmations = 0
ApocExtractionMapUtils.EventRuntime = { confirmRelease = function(id, revision)
    assert(id == "scheduled-event" and revision == 3)
    runtimeConfirmations = runtimeConfirmations + 1
end }
ApocBREventControl = {
    getEventId = function() return "scheduled-event" end,
    getRevision = function() return 3 end,
    isReleaseAuthorized = function(id, revision) return due and id == "scheduled-event" and revision == 3 end,
    acknowledgeRelease = function() acknowledgements = acknowledgements + 1; return acknowledge end,
}
local callback
Events.OnApocBRLobbyEventDue = { Add = function(f) callback = f end }
event.start(); event.pump(100)
assert(callback and #event.objects() == 286)
assert(not callback("scheduled-event", 3) and not event.store.removedAll)
due = true
assert(not callback("forged-event", 3) and not callback("scheduled-event", 4))
assert(not callback("scheduled-event", 3) and event.store.removedAll, "failed acknowledgement must permit safe retry")
assert(runtimeConfirmations == 0, "runtime cannot activate before successful acknowledgement")
assert(event.removes == 0, "activation only queues work")
acknowledge = true
assert(callback("scheduled-event", 3) and acknowledgements == 2)
assert(runtimeConfirmations == 1, "successful acknowledgement notifies runtime")
event.pump(100)
assert(#event.objects() == 0 and event.removes == 286 and event.adds == 286)
event.clock = 60000; event.pump(100)
assert(#event.objects() == 0 and event.adds == 286, "full release must suppress all reconstruction")
local releasedState = event.store
local eventReload = fixture({ store = releasedState })
eventReload.start(); eventReload.pump(100)
assert(eventReload.adds == 0 and releasedState.eventId == "scheduled-event")
local unloadedEvent = { unloaded = true }
local empty = fixture(unloadedEvent)
empty.start(); empty.pump(100)
ApocBREventControl = { isReleaseAuthorized = function() return true end, acknowledgeRelease = function() return true end }
assert(empty.lobby.releaseForEvent("no-clients-event", 1))
unloadedEvent.unloaded = false
empty.clock = 60000; empty.pump(100)
assert(empty.adds == 0, "entire perimeter must remain absent when chunks load after activation")
if arg and arg[1] then
    -- Optional local integration against the actual required extension, without
    -- copying its dispatcher into this repository or mocking its grace/dedup API.
    local integration = fixture()
    integration.start(); integration.pump(100)
    ApocBRRCON = {}
    dofile(arg[1] .. "/Apocalipse-RCON-extension/common/media/lua/shared/ApocBRRCON.lua")
    package.loaded.ApocBRRCON = ApocBRRCON
    dofile(arg[1] .. "/Apocalipse-RCON-extension/common/media/lua/server/ApocBRRCONServer.lua")
    ApocBRRCON.subscribe("ExtractionLobby", "ReleaseExits", integration.lobby.releaseExits)
    ApocBRRCON.subscribe("ExtractionLobby", "OpenDoors", integration.lobby.openDoors)
    assert(integration.lobby.openDoors == integration.lobby.releaseExits, "legacy command must use the same release latch")
    local message = ApocBRRCON.buildServermsg("ExtractionLobby", "ReleaseExits", "integration-open", integration.token())
    local parsed = assert(ApocBRRCON.parseMessage(message))
    local dispatcher = ApocBRRCON.Server
    dispatcher.onClientCommand("ApocBRRCON", "Relay", nil,
        { module = "ExtractionLobby", command = "OpenDoors", requestId = "forgery", payload = "bad" })
    integration.clock = 2001; dispatcher.onTick()
    assert(integration.store.released == false)
    dispatcher.onClientCommand("ApocBRRCON", "Relay", nil, parsed)
    dispatcher.onClientCommand("ApocBRRCON", "Relay", nil, parsed)
    dispatcher.onTick(); assert(integration.store.released == false, "extension grace period must be respected")
    integration.clock = 4002; dispatcher.onTick()
    assert(integration.store.released == true)
    integration.pump(2)
    assert(integration.removes == 6, "duplicate client relays must dispatch only once")
    dispatcher.onClientCommand("ApocBRRCON", "Relay", nil, parsed)
    integration.clock = 7000; dispatcher.onTick(); integration.pump(2)
    assert(integration.removes == 6)
    print("PASS: real RCON extension message parsing, relay dispatch, grace period, deduplication and lobby token validation")
end
print("PASS: military fence flags/collision, saved exit spacing, bounded work, unloaded chunks, despawn without rebuilding, v0.2.0 migration across restart, protection, release/replay, config and I/O failures")
