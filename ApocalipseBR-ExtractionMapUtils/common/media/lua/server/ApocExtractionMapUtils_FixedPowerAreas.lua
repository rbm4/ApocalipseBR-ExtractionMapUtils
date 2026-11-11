-- Backend-owned configuration, loaded once per dedicated-server startup.
if not isServer() then return end
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
if Utils.FixedPowerAreas then return end
local Areas = {}
Utils.FixedPowerAreas = Areas
local repository, started, finished, pending, deadline, nextAttempt, attempts
local function log(message) print("[ApocExtractionFixedPower] " .. message) end
local function label(value) return tostring(value):gsub("%c", "_") end
local function bounds(p) return "tile=" .. p.x .. "," .. p.y .. "," .. p.z end
local function finish()
    if finished then return end
    finished = true
    if ApocBRManagedGenerators and ApocBRManagedGenerators.finishStartup then
        local ok = pcall(ApocBRManagedGenerators.finishStartup)
        if not ok then log("FAILED: engine startup finalization rejected") end
    end
end
local function integer(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end
local function apply(result)
    if type(result.entities) ~= "table" then return false, "invalid collection" end
    local plans, seen, tiles, disabled = {}, {}, {}, 0
    for _, entity in ipairs(result.entities) do
        if entity:get("enabled") == true then
            local id = entity:get("area_id")
            if type(id) ~= "string" or #id < 1 or #id > 96 or seen[id] or #plans >= 255 then
                return false, "invalid, duplicate or excessive area IDs"
            end
            seen[id] = true
            local p = { id = "persisted-generator:" .. id }
            for _, key in ipairs({ "x", "y", "z" }) do
                local value = entity:get(key)
                if not integer(value, key == "z" and -32 or 0, key == "z" and 31 or 1000000) then
                    return false, "invalid coordinates"
                end
                p[key] = value
            end
            local tile = bounds(p)
            if tiles[tile] then return false, "duplicate source tile" end
            tiles[tile] = true
            plans[#plans + 1] = p
        else
            disabled = disabled + 1
        end
    end
    log("CATALOG_VALIDATED rows=" .. #result.entities .. " enabled=" .. #plans .. " disabled=" .. disabled)
    local applied = {}
    for _, p in ipairs(plans) do
        log("REGISTER_BEGIN id=" .. label(p.id) .. " " .. bounds(p))
        local ok, accepted = pcall(ApocBRManagedGenerators.registerGenerator, p.id, p.x, p.y, p.z)
        if not ok or accepted ~= true then
            log("REGISTER_FAILED id=" .. label(p.id) .. " rollback_count=" .. #applied)
            for _, id in ipairs(applied) do
                local ok, removed = pcall(ApocBRManagedGenerators.unregisterGenerator, id)
                log("ROLLBACK id=" .. label(id) .. " removed=" .. tostring(ok and removed == true))
            end
            return false, "generator registration rejected; startup batch removed"
        end
        applied[#applied + 1] = p.id
        log("REGISTERED id=" .. label(p.id) .. " " .. bounds(p) .. " mode=managed_native_generator")
    end
    return true, tostring(#applied) .. " persisted generator definitions registered; READY is reported by Java when instantiated"
end
local function attempt()
    attempts, pending = attempts + 1, true
    log("QUERY_BEGIN attempt=" .. attempts .. "/5 elapsed_ms=" .. (getTimestampMs() - (deadline - 120000)))
    local ok = pcall(function()
        if not repository then
            require "ApocBR/Entities"
            repository = ApocBREntities.define("Extraction.ManagedGenerator", {
                table = "fixed_power_area",
                fields = {
                    server_id = { type = "integer", id = true }, world = { type = "string", id = true },
                    area_id = { type = "string", id = true }, enabled = { type = "boolean" },
                    x = { type = "integer" }, y = { type = "integer" }, z = { type = "integer" },
                },
            })
        end
        repository:listForServer(function(result)
            if finished then log("QUERY_IGNORED reason=startup_finished status=" .. label(result.status)); return end
            log("QUERY_RESULT attempt=" .. attempts .. " status=" .. label(result.status))
            pending = false
            if getTimestampMs() >= deadline then finish(); log("FAILED: startup load timed out"); return end
            if result.status == "OK" then
                local valid, applied, message = pcall(apply, result)
                finish()
                if valid then log((applied and "REGISTERED: " or "FAILED: ") .. message)
                else log("FAILED: invalid catalog or application error") end
            elseif result.status == "BUSY" or result.status == "UNAVAILABLE" or result.status == "DATABASE_ERROR" then
                nextAttempt = getTimestampMs() + 5000
                log("Startup read deferred: " .. result.status)
            else
                finish()
                log("FAILED: startup read " .. tostring(result.status))
            end
        end)
    end)
    if not ok then pending = false; finish(); log("FAILED: entity/fixed-power bridge unavailable or incompatible") end
end
function Areas.start()
    if started then return end
    started, attempts = true, 0
    log("START table=mod_data.fixed_power_area scope=engine_server_and_world mode=managed_native_generator")
    if not ApocBRManagedGenerators or not ApocBRManagedGenerators.registerGenerator or not ApocBRManagedGenerators.unregisterGenerator or not ApocBRManagedGenerators.finishStartup then
        finish(); log("FAILED: managed-generator server bridge unavailable"); return
    end
    deadline = getTimestampMs() + 120000
    attempt()
end
function Areas.tick()
    if not started or finished then return end
    if getTimestampMs() >= deadline then finish(); log("FAILED: startup load timed out"); return end
    if not pending and getTimestampMs() >= nextAttempt then
        if attempts >= 5 then finish(); log("FAILED: startup read retry limit"); return end
        attempt()
    end
end
Events.OnServerStarted.Add(Areas.start)
Events.OnTickEvenPaused.Add(Areas.tick)
