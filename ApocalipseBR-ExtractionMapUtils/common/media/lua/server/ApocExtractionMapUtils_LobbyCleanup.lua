if isClient() then return end
require "ApocExtractionMapUtils"
require "ApocExtractionMapUtils_LobbySettings"

local Utils = ApocExtractionMapUtils
if Utils.LobbyCleanup then return end
local Cleanup = {}
Utils.LobbyCleanup = Cleanup
local seen = {}

local function enabled()
    return Utils.lobbyEnabled() and Utils.getOptions().LobbyCleanupZombies == true
end

function Cleanup.onChunkLoaded(chunk)
    if not enabled() then return end
    local c = Utils.getLobbyConfig()
    for _, field in ipairs({ "X1", "X2", "Y1", "Y2", "Z" }) do
        if type(c[field]) ~= "number" or c[field] ~= math.floor(c[field]) then return end
    end
    local xmin, xmax = math.min(c.X1, c.X2), math.max(c.X1, c.X2)
    local ymin, ymax = math.min(c.Y1, c.Y2), math.max(c.Y1, c.Y2)
    if xmin < 0 or ymin < 0 or xmax > 1000000 or ymax > 1000000 or c.Z < -32 or c.Z > 31
        or xmax - xmin < 6 or ymax - ymin < 6 or 2 * (xmax - xmin + ymax - ymin + 2) > 4096 then return end
    -- Derive chunk coordinates through exposed methods, not Java public fields.
    -- B42 chunks contain 8x8 tiles; an empty floor has nothing to clear.
    local x, y
    for sy = 0, 7 do
        for sx = 0, 7 do
            local square = chunk:getGridSquare(sx, sy, c.Z)
            if square then x, y = square:getX() - sx, square:getY() - sy; break end
        end
        if x then break end
    end
    if not x then return end
    if x > xmax or x + 7 < xmin or y > ymax or y + 7 < ymin then return end
    local key = x .. ":" .. y
    if seen[key] then return end
    seen[key] = true -- Session-only: chunk reloads must not clear later arrivals.
    local job = { x1 = math.max(x, xmin), x2 = math.min(x + 7, xmax),
        y1 = math.max(y, ymin), y2 = math.min(y + 7, ymax), z = c.Z }
    -- One immediate pass over at most 64 loaded tiles. Never queue an area sweep
    -- that could delete zombies entering between chunk load and later ticks.
    local removed = {}
    for y = job.y1, job.y2 do
        for x = job.x1, job.x2 do
            local square = getCell():getGridSquare(x, y, job.z)
            if square then
                local objects = square:getMovingObjects()
                for i = objects:size() - 1, 0, -1 do
                    local zombie = objects:get(i)
                    if instanceof(zombie, "IsoZombie") and not zombie:isReanimatedPlayer() then
                        local id = zombie:getOnlineID()
                        if id >= 0 then removed[#removed + 1] = id end
                        zombie:removeFromWorld()
                        zombie:removeFromSquare()
                    end
                end
            end
        end
    end
    if isServer() and #removed > 0 then
        sendServerCommand("ApocExtractionMapUtils", "LobbyCleanupZombies", {
            x1 = job.x1, x2 = job.x2, y1 = job.y1, y2 = job.y2, z = job.z, ids = removed })
    end
end

Events.LoadChunk.Add(Cleanup.onChunkLoaded)
