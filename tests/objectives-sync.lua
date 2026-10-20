local root = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "server/?.lua;" .. root .. "client/?.lua;" .. package.path
local Schema = require "ApocExtractionMapUtils_EventSchema"
local count = 0
local function check(ok, message) count = count + 1; assert(ok, message) end
local id = "12345678-1234-1234-1234-123456789abc"
local source = [[{"schemaVersion":1,"gameType":"extraction","ruleset":"default","durationMinutes":60,"parameters":{
 "properties":{"participants":["Alice","Bob","Carol"],"objectivesUI":{"title":"Operation","visibleRows":3}},
 "regions":[{"id":"zone","bounds":{"minX":10,"minY":10,"maxX":20,"maxY":20,"minZ":0,"maxZ":0}}],
 "objectives":[
 {"id":"personal","type":"kill_zombies","scope":"player","target":3,"regionIds":["zone"],"properties":{"title":"Clear the area"}},
 {"id":"team","type":"kill_zombies","scope":"team","target":4,"regionIds":["zone"]},
 {"id":"event","type":"kill_zombies","scope":"event","target":6,"regionIds":["zone"]},
 {"id":"private","type":"kill_zombies","scope":"player","target":2,"properties":{"recipients":["Alice"]}},
 {"id":"next","type":"kill_zombies","scope":"player","target":1,"dependsOn":["personal"]},
 {"id":"future","type":"custom","scope":"player","target":1}
 ]}}]]
local function fixture()
    for name in pairs(package.loaded) do
        if name:find("ApocExtractionMapUtils_Objectives", 1, true) == 1
            or name == "ApocExtractionMapUtils_EventRuntime/Modules/Objectives" or name == "ApocExtractionMapUtils" then package.loaded[name] = nil end
    end
    ApocExtractionMapUtils, RegionManager = nil, nil
    local f = { server = true, clock = 10000, online = {}, messages = {}, stores = {} }
    function isServer() return f.server end
    function getTimestampMs() return f.clock end
    function getPlayerByOnlineID(n) return f.online[n] end
    function instanceof(p, kind) return kind == "IsoPlayer" and p.kind == "player" end
    Faction = { getPlayerFaction = function(p)
        if not p.team then return nil end
        return { getName = function() return p.team end }
    end }
    function f.player(name, onlineId, team)
        local p = { name = name, id = onlineId, team = team, kind = "player", dead = false }
        function p:getUsername() return self.name end
        function p:getOnlineID() return self.id end
        function p:isDead() return self.dead end
        f.online[onlineId] = p
        return p
    end
    f.a, f.b, f.c, f.e = f.player("Alice", 1, "Red"), f.player("Bob", 2, "Red"), f.player("Carol", 3, "Blue"), f.player("Eve", 4)
    f.C = require "ApocExtractionMapUtils_Objectives/Contract"
    f.S = require "ApocExtractionMapUtils_Objectives/Service"
    f.Sync = require "ApocExtractionMapUtils_Objectives/Sync"
    f.K = require "ApocExtractionMapUtils_Objectives/Kills"
    f.Store = require "ApocExtractionMapUtils_Objectives/Store"
    f.Plan = require "ApocExtractionMapUtils_EventRuntime/Modules/Objectives"
    f.record = assert(Schema.parseContext(id, 1, { eventId = id, revision = 1, isReplay = false, name = "Event",
        startsAtMillis = 1000, state = "scheduled", metadataJson = source }))
    function sendServerCommand(player, module, command, args)
        check(player and module == f.C.MODULE and args.recipient == player.id, "all packets explicitly target the owning player")
        check(not args.rows or #args.rows <= f.C.PAGE, "packet row budget")
        f.messages[#f.messages + 1] = { player = player, command = command, args = f.C.copy(args) }
    end
    function f.subscribe(player)
        local store = f.Store.new()
        store.requestId = "request-" .. player.id .. "-" .. f.clock
        f.stores[player.id] = store
        f.Sync.onClientCommand(f.C.MODULE, "RequestSnapshot", player, { protocol = 1, requestId = store.requestId, username = "somebody-else" })
        return store
    end
    function f.tick(n, deliver)
        for _ = 1, n do
            f.clock = f.clock + 50
            local before = #f.messages
            f.K.onTick(); f.Sync.onTick()
            check(#f.messages - before <= 4, "global network packet budget per tick")
            if deliver ~= false then
                for j = before + 1, #f.messages do
                    local msg = f.messages[j]
                    f.stores[msg.player.id]:receive(msg.command, msg.args, f.clock)
                end
            end
        end
    end
    function f.attach() f.plan = f.Plan.prepare(f.record); check(f.S.attach(f.plan), "server attaches prepared contract") end
    return f
end
local f = fixture()
local sa, sb, sc, se = f.subscribe(f.a), f.subscribe(f.b), f.subscribe(f.c), f.subscribe(f.e)
f.tick(20)
check(sa.ready and #sa.rows == 0, "login before activation installs empty subscription baseline")
f.attach(); f.tick(40)
check(sa.eventId == id and sa.definitionRevision == 1 and sa.version == 0, "activation pushes definitions to already online subscriber")
check(sa.byId.personal.title == "Clear the area" and #sa.visible == 3, "event properties produce UI contract and visible row cap")
check(sa.byId.private and not sb.byId.private and not sc.byId.private, "private definitions reach only their recipients")
check(se.ready and se.eventId == "" and #se.rows == 0, "nonparticipant receives no event definitions or counters")
check(sa.byId.next.status == "locked" and sa.byId.future.status == "unsupported", "dependencies and uninstalled providers are explicit")
check(not sa.rows[1].properties and not sa.rows[1].regions, "private gameplay properties never enter presentation DTO")
local projectionCalls, project = 0, f.S.projection
f.S.projection = function(...) projectionCalls = projectionCalls + 1; return project(...) end
f.tick(20)
check(projectionCalls == 0, "idle subscribers do not rebuild objective projections when data and audience are unchanged")
local before = #f.messages
check(f.S.increment(id, "personal", f.a, 1), "server changes personal progress")
f.tick(20)
check(sa.byId.personal.count == 1 and sb.byId.personal.count == 0 and sc.byId.personal.count == 0, "personal counts isolated")
for j = before + 1, #f.messages do check(f.messages[j].player == f.a, "unaffected recipients get no personal update") end
check(f.S.increment(id, "team", f.a, 1), "server faction credit")
f.tick(20)
check(sa.byId.team.count == 1 and sb.byId.team.count == 1 and sc.byId.team.count == 0, "faction progress reaches only faction members")
check(f.S.increment(id, "event", f.a, 1), "server event credit")
f.tick(20)
check(sa.byId.event.count == 1 and sb.byId.event.count == 1 and sc.byId.event.count == 1 and #se.rows == 0, "event participants share counters")
f.Sync.onClientCommand(f.C.MODULE, "SetProgress", f.b, { objectiveId = "personal", count = 3 })
check(f.S.projection(f.b).rows[1].count == 0, "client cannot upload counters")
check(not f.S.increment(id, "next", f.a, 1), "server enforces prerequisite")
check(f.S.setProgress(id, "personal", f.a, 3), "server completes objective")
f.tick(20)
check(sa.byId.personal.status == "complete" and sa.byId.next.status == "active" and #sa.toasts == 1, "live completion produces one notification")
local packet
for j = #f.messages, 1, -1 do if f.messages[j].player == f.a and f.messages[j].command == "Progress" then packet = f.messages[j].args; break end end
local version = sa.version
sa:receive("Progress", packet, f.clock)
check(sa.version == version and #sa.toasts == 1, "duplicate updates cannot replay completion")
local stale = f.C.copy(packet); stale.toVersion, stale.fromVersion = 1, 0
sa:receive("Progress", stale, f.clock)
check(sa.version == version and sa.byId.personal.count == 3, "stale progress cannot roll back counts")
local gap = f.C.copy(packet); gap.toVersion, gap.fromVersion = version + 2, version + 1
sa:receive("Progress", gap, f.clock)
check(sa.needsSnapshot and sa.version == version, "sequence gap requests baseline instead of applying partial state")
f.clock = f.clock + 1100
local reconnect = f.subscribe(f.a); f.tick(30)
check(reconnect.byId.personal.count == 3 and #reconnect.toasts == 0, "resync/reconnect restores progress without replaying toasts")
reconnect:receive("Progress", packet, f.clock)
check(reconnect.version == 0 and not reconnect.needsSnapshot, "old request packets ignored after reconnect")
f.online[f.a.id] = nil; f.tick(10)
local newAlice = f.player("Alice", 9, "Red")
local account = f.subscribe(newAlice); f.tick(25)
check(account.byId.personal.count == 3 and #account.toasts == 0, "online ID changes preserve server-owned username progress")

-- Scope changes invalidate an in-flight snapshot BEFORE its next packet.
f = fixture(); f.attach()
f.S.increment(id, "team", f.a, 2)
sa = f.subscribe(f.a)
f.tick(1) -- starts old-faction snapshot
f.a.team = "Blue"
f.tick(15)
check(sa.byId.team.count == 0 and sa.ready and #sa.toasts == 0, "faction change replaces in-flight old-team projection")

-- Death-time coordinates and duplicate/pool-incarnation handling use actual server handler.
local function zombie(player, x, y, z)
    return { getAttackedBy = function() return player end, getX = function() return x end,
        getY = function() return y end, getZ = function() return z end }
end
f = fixture(); f.attach(); sa = f.subscribe(f.a); f.tick(15)
local dead = zombie(f.a, 20.9, 20.2, 0)
f.K.onDead(dead); f.K.onDead(dead); f.tick(20)
check(sa.byId.personal.count == 1, "one authoritative death counted once on inclusive edge tile")
f.K.onCreate(dead); f.K.onDead(dead); f.tick(20)
check(sa.byId.personal.count == 2, "pooled zombie create permits a new incarnation")
f.K.onDead(zombie(f.a, 20, 20, 1)); f.tick(20)
check(sa.byId.personal.count == 2, "wrong Z does not count for regional kill")
f.K.onDead(zombie(f.a, 21, 20, 0)); f.tick(20)
check(sa.byId.personal.count == 2, "outside region does not count")
f.K.onDead(zombie(f.a, 15, 15, 0)); f.a.team = "Blue"; f.tick(20)
local originalTeamCount = f.S.projection(f.b).rows[2].count
check(originalTeamCount == 3 and sa.byId.team.count == 0, "queued kills retain death-time faction instead of transferring into a new faction")
check(not f.S.setProgress(id, "future", f.a, 1), "uninstalled handler cannot be completed")
f.S.registerType("custom")
check(f.S.setProgress(id, "future", f.a, 1), "server-only extension API supports installed future providers")
f.tick(20)
check(sa.byId.future.status == "complete", "custom authoritative provider feeds existing UI")
f.S.setProgress(id, "personal", f.a, 0)
f.K.onDead(zombie(f.a, 15, 15, 0)); f.online[f.a.id] = nil; f.tick(20)
local returned = f.player("Alice", 11, "Blue")
local resumed = f.subscribe(returned); f.tick(20)
check(resumed.byId.personal.count == 1 and #resumed.toasts == 0, "confirmed queued kill survives disconnect and quiet reconnect")

-- 128 objectives are paged into bounded packets and a bounded cached visible selection.
f = fixture()
local rows = f.record.definition.parameters.objectives
for i = #rows, 1, -1 do rows[i] = nil end
for i = 1, 128 do rows[i] = { id = "row" .. i, type = "kill_zombies", scope = "player", target = 1,
    required = true, properties = {}, regionIds = {}, dependsOn = {} } end
f.attach(); sa = f.subscribe(f.a); f.tick(30, false)
local snapshotMessages = f.messages
for _, msg in ipairs(snapshotMessages) do if msg.command == "SnapshotBegin" then sa:receive(msg.command, msg.args, f.clock) end end
for _, msg in ipairs(snapshotMessages) do if msg.command == "SnapshotCommit" then sa:receive(msg.command, msg.args, f.clock) end end
check(not sa.ready, "snapshot commit waits for all chunks")
for j = #snapshotMessages, 1, -1 do
    local msg = snapshotMessages[j]
    if msg.command == "SnapshotRows" then sa:receive(msg.command, msg.args, f.clock) end
end
check(sa.ready and #sa.rows == 128 and #sa.visible == 3, "out-of-order chunks install atomically with 128 rows")
sa:scroll(1000)
check(#sa.visible == 3 and sa.visible[3].id == "row128", "all rows reachable through bounded scrolling")
local generation = sa.generation
check(sa.visible == sa.visible and sa.generation == generation, "reading cached selection causes no catalogue rebuild")
f.S.detach(id); f.tick(30)
check(sa.ready and #sa.rows == 0, "event teardown removes tracker content")

-- Actual client routing and bounded initial retry, including two local players.
f = fixture()
f.server = false
function isClient() return true end
function getSpecificPlayer(index) return index == 0 and f.a or index == 1 and f.b or nil end
local requests = {}
function sendClientCommand(player, module, command, args) requests[#requests + 1] = { player = player, args = args } end
local N = require "ApocExtractionMapUtils_Objectives/Network"
local one, two = N.reset(0, f.a), N.reset(1, f.b)
N.onTick(); N.onTick()
check(#requests == 2, "each local player requests once without per-frame flooding")
f.clock = f.clock + 1001; N.onTick()
check(#requests == 4, "lost initial request retries with backoff")
local header = { protocol = 1, recipient = f.a.id, requestId = one.requestId, streamId = 1, eventId = id,
    definitionRevision = 1, title = "Operation", titleKey = "", visibleRows = 3, count = 0, parts = 0, version = 0 }
N.onServerCommand(f.C.MODULE, "SnapshotBegin", header)
N.onServerCommand(f.C.MODULE, "SnapshotCommit", header)
check(one.ready and not two.ready, "targeted packet does not populate the other local player's replica")
local badVersion = f.C.copy(header)
badVersion.eventId, badVersion.definitionRevision = id, 1
badVersion.fromVersion, badVersion.toVersion, badVersion.rows = 1, 2, {}
N.onServerCommand(f.C.MODULE, "Progress", badVersion)
N.onTick()
check(#requests == 5 and one.needsSnapshot, "real client network requests resync immediately on a sequence gap")

f = fixture(); f.attach(); sa = f.subscribe(f.a); f.tick(15)
local corrupted = { protocol = 1, requestId = sa.requestId, streamId = sa.streamId, eventId = id,
    definitionRevision = 1, fromVersion = 0, toVersion = 1,
    rows = { { id = "personal", count = 2, status = "active" }, { id = "unknown", count = 1, status = "active" } } }
sa:receive("Progress", corrupted, f.clock)
check(sa.needsSnapshot and sa.byId.personal.count == 0, "invalid multi-row delta is rejected atomically without partial progress")
local definition = f.S.getDefinition(id, "personal")
definition.target = 999
check(f.S.getDefinition(id, "personal").target == 3, "server definition API cannot mutate internal state")
f.record.definition.parameters.properties.objectivesUI.visibleRows = 129
check(not pcall(f.Plan.prepare, f.record), "prepare rejects invalid presentation limits inside extension properties")

-- Definition revisions and progress sequences are independent; changed semantics reset only affected rows.
f = fixture(); f.attach(); sa = f.subscribe(f.a); f.tick(15)
f.S.increment(id, "personal", f.a, 1); f.S.increment(id, "team", f.a, 2); f.tick(15)
f.record.revision = 2
f.record.definition.parameters.properties.objectivesUI.title = "New event heading"
f.attach(); f.tick(20)
check(sa.definitionRevision == 2 and sa.version == 0 and sa.byId.personal.count == 1 and #sa.toasts == 0,
    "definition snapshot updates heading while unchanged objective counters survive silently")
f.record.revision = 3; f.record.definition.parameters.objectives[1].target = 4
f.attach(); f.tick(20)
check(sa.byId.personal.count == 0 and sa.byId.team.count == 2, "semantic edit resets only modified objective plan")

-- A final lost delta has no later delta to reveal the gap; a tiny watermark does.
f = fixture(); f.attach(); sa = f.subscribe(f.a); f.tick(15)
f.S.increment(id, "personal", f.a, 1)
f.tick(20, false) -- intentionally lose the last change
check(sa.byId.personal.count == 0, "fixture drops final progress packet")
f.tick(220)
check(sa.needsSnapshot and sa.byId.personal.count == 0, "idle sequence watermark detects a missing final update")

f = fixture(); f.attach()
for i = 1, 2049 do f.K.onDead(zombie(f.a, 15, 15, 0)) end
check(f.K.pending() == 2048 and f.S.metrics.droppedKills == 1, "death queue has explicit bounded overload accounting")
local visits, realMatch = 0, f.S.matchesKill
f.S.matchesKill = function(...) visits = visits + 1; return realMatch(...) end
f.K.onTick()
check(visits <= 64 and f.K.pending() > 0, "burst work is spread over ticks instead of a full death/objective pass")

-- Both real loader files remain side-specific and register each engine hook once.
local registered = {}
Events = {}
for _, name in ipairs({ "OnClientCommand", "OnTick", "OnZombieDead", "OnZombieCreate" }) do
    registered[name] = {}
    Events[name] = { Add = function(fn) registered[name][#registered[name] + 1] = fn end }
end
dofile(root .. "server/ApocExtractionMapUtils_ObjectivesServer.lua")
dofile(root .. "server/ApocExtractionMapUtils_ObjectivesServer.lua")
dofile(root .. "client/ApocExtractionMapUtils_ObjectivesClient.lua")
check(#registered.OnTick == 2 and #registered.OnClientCommand == 1 and #registered.OnZombieDead == 1
    and #registered.OnZombieCreate == 1, "server loader is idempotent and client loader stays inactive on server")
print("PASS: " .. count .. " authoritative objective/protocol/scope/reconnect/kill/budget assertions")
