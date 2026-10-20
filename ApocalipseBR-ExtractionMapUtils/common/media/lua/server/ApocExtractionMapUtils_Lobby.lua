if isClient() then return end
require "ApocExtractionMapUtils"
require "ApocExtractionMapUtils_LobbyConfig"

local Utils = ApocExtractionMapUtils
if Utils.Lobby then return end
local Lobby = {}
Utils.Lobby = Lobby

local TAG = "ApocExtractionLobby"
local MAX_HP = 2147483647 -- Java int; save and network fields use int, not short.
local edges, bySquare, exits = {}, {}, {}
local queue, queued, head, tail = {}, {}, 1, 0
local state, config, signature, token, tokenFile
local nextScan, nextExitCheck = 0, 0
local started = false

local function log(message) print("[ApocExtractionLobby] " .. message) end
local function now() return getTimestampMs() end
local function squareKey(x, y) return x .. ":" .. y end
local function edgeKey(edge) return squareKey(edge.x, edge.y) .. (edge.north and ":N" or ":W") end

local function enqueue(index)
    if not queued[index] then
        tail = tail + 1
        queue[tail], queued[index] = index, true
    end
end

local function enqueueAll()
    for i = 1, #edges do enqueue(i) end
end

local function addEdge(x, y, north)
    local edge = { x = x, y = y, north = north }
    edges[#edges + 1] = edge
    local key = squareKey(x, y)
    bySquare[key] = bySquare[key] or {}
    table.insert(bySquare[key], #edges)
end

local function validInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function buildPlan()
    config = Utils.LobbyConfig
    for _, field in ipairs({ "X1", "Y1", "X2", "Y2", "Z", "ExitCount",
        "MaxEdgesPerTick", "MaxTickMilliseconds", "RescanMilliseconds", "ExitCheckMilliseconds" }) do
        assert(validInteger(config[field]), "invalid integer config: " .. field)
    end
    local xmin, xmax = math.min(config.X1, config.X2), math.max(config.X1, config.X2)
    local ymin, ymax = math.min(config.Y1, config.Y2), math.max(config.Y1, config.Y2)
    assert(xmin >= 0 and ymin >= 0 and xmax <= 1000000 and ymax <= 1000000, "invalid lobby coordinates")
    assert(xmax - xmin >= 6 and ymax - ymin >= 6, "lobby must be at least seven tiles wide/high")
    assert(2 * (xmax - xmin + ymax - ymin + 2) <= 4096, "lobby exceeds 4096-edge safety limit")
    assert(config.Z >= -32 and config.Z <= 31, "invalid lobby floor")
    assert(config.MaxEdgesPerTick >= 1 and config.MaxEdgesPerTick <= 16, "tick edge budget must be 1..16")
    assert(config.MaxTickMilliseconds >= 1 and config.MaxTickMilliseconds <= 10, "tick time budget must be 1..10ms")
    assert(config.RescanMilliseconds >= 10000 and config.ExitCheckMilliseconds >= 1000, "scan intervals too small")
    for x = xmin, xmax do addEdge(x, ymin, true) end
    for y = ymin, ymax do addEdge(xmax + 1, y, false) end
    for x = xmax, xmin, -1 do addEdge(x, ymax + 1, true) end
    for y = ymax, ymin, -1 do addEdge(xmin, y, false) end
    local exitCount = math.max(0, math.min(6, config.ExitCount))
    signature = table.concat({ "v2", xmin, ymin, xmax, ymax, config.Z,
        exitCount, config.FenceWest, config.FenceNorth }, ":")

    state = ModData.getOrCreate(TAG)
    -- Upgrade only the known v0.2.0 assets at identical bounds/count. Retain
    -- legacy ownership signatures across saves so unloaded old chunks migrate
    -- later too; never match unrelated map objects by sprite alone.
    local legacySignature = table.concat({ "v1", xmin, ymin, xmax, ymax, config.Z,
        exitCount, "constructedobjects_01_48", "constructedobjects_01_49",
        "fixtures_doors_01_68", "fixtures_doors_01_69",
        "fixtures_doors_01_70", "fixtures_doors_01_71" }, ":")
    if state.signature == legacySignature then
        assert(type(state.doorKeys) == "table", "invalid legacy lobby exit plan")
        state.legacySignatures = state.legacySignatures or {}
        state.legacySignatures[legacySignature] = true
        state.signature, state.exitKeys, state.released = signature, state.doorKeys, state.open == true
        state.doorKeys, state.open = nil, nil
        log("Migrating saved perimeter to military fences; exit positions/release state preserved")
    end
    if state.signature ~= signature then
        -- Never silently rearrange an existing perimeter into a different plan.
        assert(state.signature == nil, "saved lobby layout differs from config; migrate old assets/state first")
        state.signature, state.exitKeys, state.released = signature, {}, false
        local candidates = {}
        for i, edge in ipairs(edges) do
            -- Stay away from corners, with at least two fence tiles between exits.
            if (edge.north and edge.x > xmin + 1 and edge.x < xmax - 1)
                or (not edge.north and edge.y > ymin + 1 and edge.y < ymax - 1) then
                candidates[#candidates + 1] = i
            end
        end
        for i = #candidates, 2, -1 do
            local j = ZombRand(i) + 1
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local count = 0
        for _, index in ipairs(candidates) do
            if count >= exitCount then break end
            local edge, separated = edges[index], true
            for _, other in ipairs(edges) do
                if state.exitKeys[edgeKey(other)] and math.abs(edge.x - other.x) + math.abs(edge.y - other.y) <= 2 then
                    separated = false
                    break
                end
            end
            if separated then
                state.exitKeys[edgeKey(edge)] = true
                count = count + 1
            end
        end
    end
    assert(type(state.exitKeys) == "table", "invalid saved lobby exit plan")
    for i, edge in ipairs(edges) do
        edge.exit = state.exitKeys[edgeKey(edge)] == true
        if edge.exit then exits[#exits + 1] = i end
    end
end

local function markConstruction(square)
    local zone = square:getZone()
    if zone then zone:setHaveConstruction(true) end
end

local function makeObject(square, edge)
    local object = IsoThumpable.new(getCell(), square,
        edge.north and config.FenceNorth or config.FenceWest, edge.north, {})
    object:setIsDoor(false)
    object:setMaxHealth(MAX_HP)
    object:setHealth(MAX_HP)
    object:setIsThumpable(false)
    object:setIsDismantable(false)
    object:setCanBarricade(false)
    object:setIsHoppable(false)
    object:setCanPassThrough(false)
    local data = object:getModData()
    data[TAG] = { signature = signature, key = edgeKey(edge), exit = edge.exit }
    return object
end

local function applyEdge(index)
    local edge = edges[index]
    local square = getCell():getGridSquare(edge.x, edge.y, config.Z)
    if not square then return end -- never force chunks or keep retrying every tick
    local objects, existing, duplicates = square:getObjects(), nil, {}
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local data = object:getModData()[TAG]
        local owned = data and (data.signature == signature
            or (state.legacySignatures and state.legacySignatures[data.signature] == true))
        if owned and data.key == edgeKey(edge) then
            if not existing then existing = object else duplicates[#duplicates + 1] = object end
        end
    end
    if state.removedAll == true or (edge.exit and state.released == true) then
        if existing then
            assert(square:transmitRemoveItemFromSquare(existing) >= 0, "native exit removal failed; deferred")
        end
        for _, object in ipairs(duplicates) do
            assert(square:transmitRemoveItemFromSquare(object) >= 0, "native duplicate removal failed; deferred")
        end
        if existing then markConstruction(square) end
        edge.errorLogged = nil
        return -- released exits remain empty, including after reload/repair scans
    end
    local spriteName = edge.north and config.FenceNorth or config.FenceWest
    local replace = existing and (existing:getModData()[TAG].signature ~= signature
        or existing:getModData()[TAG].exit ~= edge.exit
        or existing:getSprite():getName() ~= spriteName
        or existing:IsOpen() or existing:isDoor() or existing:getHealth() ~= MAX_HP
        or existing:getMaxHealth() ~= MAX_HP or existing:isThumpable()
        or existing:isDismantable() or existing:getCanBarricade() or existing:isCanPassThrough())
    if not existing or replace then
        -- Construct before removing anything; invalid sprites/errors leave the
        -- previous barrier in place and are retried on the next slow scan.
        local object = makeObject(square, edge)
        if existing then
            assert(square:transmitRemoveItemFromSquare(existing) >= 0, "native removal failed; replacement deferred")
        end
        square:AddSpecialObject(object)
        markConstruction(square)
        object:transmitCompleteItemToClients()
    end
    for _, object in ipairs(duplicates) do square:transmitRemoveItemFromSquare(object) end
    edge.errorLogged = nil
end

local function writeToken(value)
    local writer = assert(getFileWriter(tokenFile, true, false), "cannot write lobby command token file")
    writer:write(value)
    writer:close()
    local reader = assert(getFileReader(tokenFile, false), "cannot verify lobby command token file")
    local actual = reader:readLine()
    reader:close()
    assert(actual == value, "lobby command token file verification failed")
end

-- Trusted engine entry point. It is deliberately not a client/RCON command.
-- The bridge confirms a fresh due schedule or a durable prior release receipt.
function Lobby.releaseForEvent(eventId, revision)
    if not Utils.lobbyEnabled() or not started or not ApocBREventControl
        or type(eventId) ~= "string" or type(revision) ~= "number"
        or not ApocBREventControl.isReleaseAuthorized(eventId, revision) then return false end
    if state.removedAll ~= true then
        state.removedAll, state.released = true, true
        token = nil
        enqueueAll()
        log("Scheduled event accepted; entire perimeter removal queued")
    end
    state.eventId, state.eventRevision = eventId, revision
    -- This acknowledges desired-state acceptance, not completion of unloaded
    -- world edits. Repeating after a crash/save gap safely reapplies removal.
    return ApocBREventControl.acknowledgeRelease(eventId, revision)
end

function Lobby.releaseExits(payload)
    if not Utils.lobbyEnabled() or not started or state.released == true then return false end
    -- The RCON extension is a client relay, not an authenticated server callback.
    -- A server-only, single-use UUID authorizes this fixed operation. Never put
    -- it in ModData (clients can request GlobalModData by name) or log payloads.
    if not token or type(payload) ~= "string" or payload ~= token then
        log("Rejected ReleaseExits: invalid or consumed command token")
        return false
    end
    writeToken("consumed") -- fail closed on I/O failure, before changing desired state
    token = nil
    state.released = true
    for _, index in ipairs(exits) do enqueue(index) end
    log("ReleaseExits accepted; exit fences will despawn through the tick queue or on later chunk load")
    return true
end

function Lobby.onStarted()
    if not Utils.lobbyEnabled() or started then return end
    require "ApocBRRCON"
    config = Utils.LobbyConfig
    -- Validate sprite availability once, not once for every missing square.
    for _, entry in ipairs({ { config.FenceNorth, IsoFlagType.collideN }, { config.FenceWest, IsoFlagType.collideW } }) do
        local sprite = type(entry[1]) == "string" and getSprite(entry[1])
        local props = sprite and sprite:getProperties()
        if not props or not props:has(entry[2]) or not props:has(IsoFlagType.CantClimb)
            or props:has(IsoFlagType.HoppableN) or props:has(IsoFlagType.HoppableW)
            or props:has(IsoFlagType.TallHoppableN) or props:has(IsoFlagType.TallHoppableW) then
            log("Initialization disabled: fence needs directional collision + CantClimb, without climb flags: " .. tostring(entry[1]))
            return
        end
    end
    -- Validate assets BEFORE changing the saved signature/migration state.
    local ok, err = pcall(buildPlan)
    if not ok then log("Initialization disabled: " .. tostring(err)); return end
    started = true
    enqueueAll()
    nextScan, nextExitCheck = now() + config.RescanMilliseconds, now() + config.ExitCheckMilliseconds
    if not state.released then
        tokenFile = "ApocExtractionLobby-" .. string.gsub(getServerName(), "[^%w_-]", "_") .. "-open-token.txt"
        local newToken = getRandomUUID()
        local written, errorMessage = pcall(writeToken, newToken)
        if written then token = newToken; log("ReleaseExits token: server Lua cache/" .. tokenFile)
        else log("ReleaseExits disabled: " .. tostring(errorMessage)) end
    end
    log("Queued " .. #edges .. " fence edges, including " .. #exits .. " removable exits; released=" .. tostring(state.released == true))
    ApocBRRCON.subscribe("ExtractionLobby", "ReleaseExits", Lobby.releaseExits)
    ApocBRRCON.subscribe("ExtractionLobby", "OpenDoors", Lobby.releaseExits)
    -- The patched engine registers this event before OnServerStarted; the mod
    -- also remains usable on an unpatched server with its manual RCON transport.
    if ApocBREventControl and Events.OnApocBRLobbyEventDue then
        Events.OnApocBRLobbyEventDue.Add(Lobby.releaseForEvent)
        local id = ApocBREventControl.getEventId()
        if id then Lobby.releaseForEvent(id, ApocBREventControl.getRevision()) end
    end
end

function Lobby.onSquareLoaded(square)
    if not Utils.lobbyEnabled() or not started or square:getZ() ~= config.Z then return end
    local indices = bySquare[squareKey(square:getX(), square:getY())]
    if indices then for _, index in ipairs(indices) do enqueue(index) end end
end

function Lobby.onTick()
    if not Utils.lobbyEnabled() or not started then return end
    local time = now()
    if time >= nextScan then enqueueAll(); nextScan = time + config.RescanMilliseconds end
    if time >= nextExitCheck then
        for _, index in ipairs(exits) do enqueue(index) end
        nextExitCheck = time + config.ExitCheckMilliseconds
    end
    local done = 0
    while head <= tail and done < config.MaxEdgesPerTick do
        if done > 0 and now() - time >= config.MaxTickMilliseconds then break end
        local index = queue[head]
        queue[head], queued[index], head = nil, nil, head + 1
        local ok, err = pcall(applyEdge, index)
        if not ok and not edges[index].errorLogged then
            edges[index].errorLogged = true
            log("Edge " .. edgeKey(edges[index]) .. " deferred after error: " .. tostring(err))
        end
        done = done + 1
    end
    if tail > 0 and head > tail then queue, head, tail = {}, 1, 0 end
end

Lobby.openDoors = Lobby.releaseExits -- compatibility for existing server integrations
Events.OnServerStarted.Add(Lobby.onStarted)
Events.LoadGridsquare.Add(Lobby.onSquareLoaded)
Events.OnTick.Add(Lobby.onTick)
