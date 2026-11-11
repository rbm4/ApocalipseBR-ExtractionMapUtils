if isClient() then return end
require "ApocExtractionMapUtils"
require "ApocExtractionMapUtils_LobbySettings"

local Utils = ApocExtractionMapUtils
if Utils.LobbyCleanup then return end
local Cleanup = {}
Utils.LobbyCleanup = Cleanup
local run, attempted
local SETTLE_MS, TIMEOUT_MS, LOG_MS = 5000, 120000, 5000
local CHUNKS_PER_TICK = 4
local MIN_CLEANUP_Z, MAX_CLEANUP_Z = 0, 5

local function log(message)
    -- Operational output is independent of DebugLogging.
    print("[ApocExtractionLobbyCleanup] " .. message)
end

local function enabled()
    return Utils.lobbyEnabled() and Utils.getOptions().LobbyCleanupZombies == true
end

local function geometry()
    local c = Utils.getLobbyConfig()
    for _, field in ipairs({ "X1", "X2", "Y1", "Y2", "Z" }) do
        if type(c[field]) ~= "number" or c[field] ~= math.floor(c[field]) then return end
    end
    local xmin, xmax = math.min(c.X1, c.X2), math.max(c.X1, c.X2)
    local ymin, ymax = math.min(c.Y1, c.Y2), math.max(c.Y1, c.Y2)
    if xmin < 0 or ymin < 0 or xmax > 1000000 or ymax > 1000000 or c.Z < -32 or c.Z > 31
        or xmax - xmin < 6 or ymax - ymin < 6 or 2 * (xmax - xmin + ymax - ymin + 2) > 4096 then return end
    local margin = Utils.getOptions().LobbyCleanupMargin
    if margin == nil then margin = 10 end
    if type(margin) ~= "number" or margin ~= math.floor(margin) or margin < 0 or margin > 100 then return end
    return { x1 = math.max(0, xmin - margin), x2 = math.min(1000000, xmax + margin),
        y1 = math.max(0, ymin - margin), y2 = math.min(1000000, ymax + margin), margin = margin }
end

local function finish(status)
    local released, releaseError = pcall(ApocBRLobbyStreaming.releasePopulation)
    if not released then status = "FAILED: population release: " .. tostring(releaseError) end
    log(status .. ": chunks=" .. run.done .. "/" .. run.total .. ", removed=" .. run.removed
        .. ", loadedTiles=" .. run.loadedTiles .. ", missingTiles=" .. run.missingTiles
        .. ", elapsedMs=" .. (getTimestampMs() - run.started)
        .. "; all cleanup loading requests released; normal server save/unload resumes (player areas stay loaded)")
    run = nil
end

function Cleanup.start()
    if attempted or not enabled() then return end
    attempted = true
    if not isServer() then log("SKIPPED: forced startup streaming requires a dedicated server"); return end
    local bounds = geometry()
    if not bounds then log("FAILED: invalid lobby bounds/floor/cleanup margin; no chunks requested"); return end
    if not ApocBRLobbyStreaming or not ApocBRLobbyStreaming.keepCellLoaded
        or not ApocBRLobbyStreaming.activatePopulation or not ApocBRLobbyStreaming.releasePopulation then
        log("FAILED: ApocBRLobbyStreaming bridge unavailable; install the updated 42.22.1 server patch; no cleanup performed")
        return
    end
    local cells, total = {}, 0
    for cy = math.floor(bounds.y1 / 64), math.floor(bounds.y2 / 64) do
        for cx = math.floor(bounds.x1 / 64), math.floor(bounds.x2 / 64) do
            local chunks = {}
            for y = math.max(cy * 8, math.floor(bounds.y1 / 8)), math.min(cy * 8 + 7, math.floor(bounds.y2 / 8)) do
                for x = math.max(cx * 8, math.floor(bounds.x1 / 8)), math.min(cx * 8 + 7, math.floor(bounds.x2 / 8)) do
                    chunks[#chunks + 1] = { x = x * 8, y = y * 8 }
                    total = total + 1
                end
            end
            cells[#cells + 1] = { x = cx * 64, y = cy * 64, chunks = chunks }
        end
    end
    local now = getTimestampMs()
    run = { bounds = bounds, cells = cells, index = 1, chunkIndex = 1,
        total = total, done = 0, removed = 0, loadedTiles = 0, missingTiles = 0,
        started = now, nextLog = now + LOG_MS }
    log("START: bounds=" .. bounds.x1 .. "," .. bounds.y1 .. ".." .. bounds.x2 .. "," .. bounds.y2
        .. ", z=" .. MIN_CLEANUP_Z .. ".." .. MAX_CLEANUP_Z .. ", margin=" .. bounds.margin .. ", cells=" .. #cells .. ", chunks=" .. total
        .. "; populationActivation=true; loading one 64x64 server cell at a time")
end

local function clearChunk(chunk)
    local b = run.bounds
    for z = MIN_CLEANUP_Z, MAX_CLEANUP_Z do
        local job = { x1 = math.max(chunk.x, b.x1), x2 = math.min(chunk.x + 7, b.x2),
            y1 = math.max(chunk.y, b.y1), y2 = math.min(chunk.y + 7, b.y2), z = z, ids = {} }
        for y = job.y1, job.y2 do
            for x = job.x1, job.x2 do
                local square = getCell():getGridSquare(x, y, job.z)
                if not run.cells[run.index].firstPassDone then
                    local field = square and "loadedTiles" or "missingTiles"
                    run[field] = run[field] + 1
                end
                if square then
                    local objects = square:getMovingObjects()
                    for i = objects:size() - 1, 0, -1 do
                        local zombie = objects:get(i)
                        if instanceof(zombie, "IsoZombie") and not zombie:isReanimatedPlayer() then
                            local id = zombie:getOnlineID()
                            if id >= 0 then job.ids[#job.ids + 1] = id end
                            zombie:removeFromWorld()
                            zombie:removeFromSquare()
                            run.removed = run.removed + 1
                        end
                    end
                end
            end
        end
        if #job.ids > 0 then sendServerCommand("ApocExtractionMapUtils", "LobbyCleanupZombies", job) end
    end
end

local function step()
    if not enabled() then finish("CANCELLED: cleanup disabled"); return end
    local now = getTimestampMs()
    local cell = run.cells[run.index]
    if not cell.started then
        cell.started = now
        log("LOADING cell " .. run.index .. "/" .. #run.cells .. " at " .. cell.x .. "," .. cell.y)
    end
    local ready = ApocBRLobbyStreaming.keepCellLoaded(cell.x, cell.y)
    if ready == -1 then finish("FAILED: cell outside server map"); return end
    if now - cell.started >= TIMEOUT_MS then finish("FAILED: cell load/cleanup timed out"); return end
    local populationReady = ready == 1 and ApocBRLobbyStreaming.activatePopulation(cell.x, cell.y)
    if now >= run.nextLog then
        log("PROGRESS: cell=" .. run.index .. "/" .. #run.cells .. ", chunks=" .. run.done .. "/" .. run.total
            .. ", removed=" .. run.removed .. ", phase=" .. (ready == 1 and "activating/verifying population" or "loading")
            .. ", populationReady=" .. tostring(populationReady))
        run.nextLog = now + LOG_MS
    end
    if ready ~= 1 then return end
    cell.readyAt = cell.readyAt or now
    cell.quietSince = cell.quietSince or now
    -- Loaded map geometry alone does not activate virtual population. The
    -- bridge registers a temporary population area and drains paused updates.
    if now - cell.readyAt < SETTLE_MS then return end
    for _ = 1, CHUNKS_PER_TICK do
        local chunk = cell.chunks[run.chunkIndex]
        if not chunk then break end
        local before = run.removed
        clearChunk(chunk)
        if run.removed > before then cell.quietSince = now end
        if not cell.firstPassDone then run.done = run.done + 1 end
        run.chunkIndex = run.chunkIndex + 1
    end
    if run.chunkIndex > #cell.chunks then
        cell.firstPassDone = true
        cell.passes = (cell.passes or 0) + 1
        if not populationReady or now - cell.quietSince < SETTLE_MS or cell.passes < 2 then
            run.chunkIndex = 1
            return -- Recheck after pending native work and late materialization.
        end
        ApocBRLobbyStreaming.releasePopulation()
        log("CLEANED cell " .. run.index .. "/" .. #run.cells .. ": chunks=" .. run.done .. "/" .. run.total
            .. ", removed=" .. run.removed .. ", verificationPasses=" .. cell.passes
            .. ", populationReady=" .. tostring(populationReady) .. "; releasing cell loading request")
        run.index, run.chunkIndex = run.index + 1, 1
        if run.index > #run.cells then finish("COMPLETE") end
    end
end

function Cleanup.tick()
    if not run then return end
    local ok, err = pcall(step)
    if not ok and run then finish("FAILED: " .. tostring(err)) end
end

Events.OnServerStarted.Add(Cleanup.start)
-- Also runs with PauseEmpty=true. Loader integration needs subsequent frames;
-- blocking OnServerStarted would prevent those frames from loading the cells.
Events.OnTickEvenPaused.Add(Cleanup.tick)
