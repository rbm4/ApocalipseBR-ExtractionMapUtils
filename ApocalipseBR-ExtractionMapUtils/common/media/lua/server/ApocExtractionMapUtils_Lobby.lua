if isClient() then return end
require "ApocExtractionMapUtils"
require "ApocExtractionMapUtils_LobbyConfig"
require "ApocBRRCON"

local Utils = ApocExtractionMapUtils
if Utils.Lobby then return end
local Lobby = {}
Utils.Lobby = Lobby

local TAG = "ApocExtractionLobby"
local MAX_HP = 2147483647 -- Java int; save and network fields use int, not short.
local edges, bySquare, doors = {}, {}, {}
local queue, queued, head, tail = {}, {}, 1, 0
local state, config, signature, token, tokenFile
local nextScan, nextDoorCheck = 0, 0
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
    for _, field in ipairs({ "X1", "Y1", "X2", "Y2", "Z", "DoorCount",
        "MaxEdgesPerTick", "MaxTickMilliseconds", "RescanMilliseconds", "DoorCheckMilliseconds" }) do
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
    assert(config.RescanMilliseconds >= 10000 and config.DoorCheckMilliseconds >= 1000, "scan intervals too small")
    for x = xmin, xmax do addEdge(x, ymin, true) end
    for y = ymin, ymax do addEdge(xmax + 1, y, false) end
    for x = xmax, xmin, -1 do addEdge(x, ymax + 1, true) end
    for y = ymax, ymin, -1 do addEdge(xmin, y, false) end
    signature = table.concat({ "v1", xmin, ymin, xmax, ymax, config.Z,
        math.max(0, math.min(6, config.DoorCount)), config.WallWest, config.WallNorth,
        config.DoorWest, config.DoorNorth, config.DoorOpenWest, config.DoorOpenNorth }, ":")

    state = ModData.getOrCreate(TAG)
    if state.signature ~= signature then
        -- Never silently rearrange an existing perimeter into a different plan.
        assert(state.signature == nil, "saved lobby layout differs from config; migrate old assets/state first")
        state.signature, state.doorKeys, state.open = signature, {}, false
        local candidates = {}
        for i, edge in ipairs(edges) do
            -- Stay away from corners, with at least two wall tiles between doors.
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
            if count >= math.max(0, math.min(6, config.DoorCount)) then break end
            local edge, separated = edges[index], true
            for _, other in ipairs(edges) do
                if state.doorKeys[edgeKey(other)] and math.abs(edge.x - other.x) + math.abs(edge.y - other.y) <= 2 then
                    separated = false
                    break
                end
            end
            if separated then
                state.doorKeys[edgeKey(edge)] = true
                count = count + 1
            end
        end
    end
    assert(type(state.doorKeys) == "table", "invalid saved lobby door plan")
    for i, edge in ipairs(edges) do
        edge.door = state.doorKeys[edgeKey(edge)] == true
        if edge.door then doors[#doors + 1] = i end
    end
end

local function markConstruction(square)
    local zone = square:getZone()
    if zone then zone:setHaveConstruction(true) end
end

local function makeObject(square, edge, open)
    local closed = edge.north and config.DoorNorth or config.DoorWest
    local object
    if edge.door then
        object = IsoThumpable.new(getCell(), square, closed,
            edge.north and config.DoorOpenNorth or config.DoorOpenWest, edge.north, {})
        -- Before release it is a door-shaped wall: keyboard/context-menu door
        -- interactions cannot bypass the event command from either side.
        object:setIsDoor(open)
        if open then object:ToggleDoorSilent() end -- before insertion; full add packet follows
    else
        object = IsoThumpable.new(getCell(), square,
            edge.north and config.WallNorth or config.WallWest, edge.north, {})
    end
    object:setMaxHealth(MAX_HP)
    object:setHealth(MAX_HP)
    object:setIsThumpable(false)
    object:setIsDismantable(false)
    object:setCanBarricade(false)
    object:setIsHoppable(false)
    object:setCanPassThrough(false)
    local data = object:getModData()
    data[TAG] = { signature = signature, key = edgeKey(edge), door = edge.door }
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
        if data and data.signature == signature and data.key == edgeKey(edge) then
            if not existing then existing = object else duplicates[#duplicates + 1] = object end
        end
    end
    local open = edge.door and state.open == true
    -- Replacement deliberately uses native remove/add paths: ordinary silent
    -- door toggles alone omit some collision/pathfinding and network updates.
    local replace = existing and (existing:getModData()[TAG].door ~= edge.door
        or existing:IsOpen() ~= open
        or existing:isDoor() ~= open or existing:getHealth() ~= MAX_HP
        or existing:getMaxHealth() ~= MAX_HP or existing:isThumpable()
        or existing:isDismantable() or existing:getCanBarricade() or existing:isCanPassThrough())
    if not existing or replace then
        -- Construct before removing anything; invalid sprites/errors leave the
        -- previous barrier in place and are retried on the next slow scan.
        local object = makeObject(square, edge, open)
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

function Lobby.openDoors(payload)
    if not started or not config.Enabled or state.open == true then return false end
    -- The RCON extension is a client relay, not an authenticated server callback.
    -- A server-only, single-use UUID authorizes this fixed operation. Never put
    -- it in ModData (clients can request GlobalModData by name) or log payloads.
    if not token or type(payload) ~= "string" or payload ~= token then
        log("Rejected OpenDoors: invalid or consumed command token")
        return false
    end
    writeToken("consumed") -- fail closed on I/O failure, before changing desired state
    token = nil
    state.open = true
    for _, index in ipairs(doors) do enqueue(index) end
    log("OpenDoors accepted; loaded doors will open through the tick queue, unloaded doors on load")
    return true
end

function Lobby.onStarted()
    if started or not Utils.LobbyConfig.Enabled then return end
    local ok, err = pcall(buildPlan)
    if not ok then log("Initialization disabled: " .. tostring(err)); return end
    -- Validate sprite availability once, not once for every missing square.
    for _, sprite in ipairs({ config.WallWest, config.WallNorth, config.DoorWest,
        config.DoorNorth, config.DoorOpenWest, config.DoorOpenNorth }) do
        if not getSprite(sprite) then log("Initialization disabled: missing sprite " .. sprite); return end
    end
    started = true
    enqueueAll()
    nextScan, nextDoorCheck = now() + config.RescanMilliseconds, now() + config.DoorCheckMilliseconds
    if not state.open then
        tokenFile = "ApocExtractionLobby-" .. string.gsub(getServerName(), "[^%w_-]", "_") .. "-open-token.txt"
        local newToken = getRandomUUID()
        local written, errorMessage = pcall(writeToken, newToken)
        if written then token = newToken; log("OpenDoors token: server Lua cache/" .. tokenFile)
        else log("OpenDoors disabled: " .. tostring(errorMessage)) end
    end
    log("Queued " .. #edges .. " edges, including " .. #doors .. " single doors; open=" .. tostring(state.open == true))
end

function Lobby.onSquareLoaded(square)
    if not started or not config.Enabled or square:getZ() ~= config.Z then return end
    local indices = bySquare[squareKey(square:getX(), square:getY())]
    if indices then for _, index in ipairs(indices) do enqueue(index) end end
end

function Lobby.onTick()
    if not started or not config.Enabled then return end
    local time = now()
    if time >= nextScan then enqueueAll(); nextScan = time + config.RescanMilliseconds end
    if time >= nextDoorCheck then
        for _, index in ipairs(doors) do enqueue(index) end
        nextDoorCheck = time + config.DoorCheckMilliseconds
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

ApocBRRCON.subscribe("ExtractionLobby", "OpenDoors", Lobby.openDoors)
Events.OnServerStarted.Add(Lobby.onStarted)
Events.LoadGridsquare.Add(Lobby.onSquareLoaded)
Events.OnTick.Add(Lobby.onTick)
