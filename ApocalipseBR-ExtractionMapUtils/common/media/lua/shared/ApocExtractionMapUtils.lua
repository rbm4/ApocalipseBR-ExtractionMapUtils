ApocExtractionMapUtils = ApocExtractionMapUtils or {}

local Utils = ApocExtractionMapUtils

function Utils.getOptions()
    return (SandboxVars and SandboxVars.ApocExtractionMapUtils) or {}
end

-- Read at emission time: SandboxVars may not exist during Lua autoload.
function Utils.debugLogEnabled()
    return Utils.getOptions().debugLog == true
end

function Utils.debugLog(message)
    if not Utils.debugLogEnabled() then return end
    print(tostring(message):gsub("[%c]", " "):sub(1, 2048))
end

function Utils.forceMapReveal()
    return Utils.getOptions().ForceMapReveal ~= false
end

function Utils.lobbyEnabled()
    return Utils.getOptions().LobbyEnabled == true
end

function Utils.zombieMoneyEnabled()
    return Utils.getOptions().ZombieMoneyDrops == true
end

Utils.REVEAL_MODULE = "ApocExtractionMapUtils"

-- Both sides derive bounds from their own world, never from a client command.
function Utils.eachRevealBlock(callback)
    local grid = getWorld():getMetaGrid()
    if not grid then error("Map metagrid is not ready") end
    local x1, y1 = grid:getMinX() * 256, grid:getMinY() * 256
    local x2, y2 = (grid:getMaxX() + 1) * 256 - 1, (grid:getMaxY() + 1) * 256 - 1
    if x2 < x1 or y2 < y1 then error("Map metagrid bounds are not ready") end
    for x = x1, x2, 8192 do
        for y = y1, y2, 8192 do
            callback(x, y, math.min(x + 8191, x2), math.min(y + 8191, y2))
        end
    end
end

function Utils.getLobbyPosition()
    local options = Utils.getOptions()
    if not Utils.lobbyEnabled() or (options.RelocateOnLogin ~= true and options.RelocateOnRespawn ~= true) then return nil end

    local x = tonumber(options.LobbyX) or -1
    local y = tonumber(options.LobbyY) or -1
    local z = tonumber(options.LobbyZ) or 0
    -- -1 means the lobby has not been configured. Never pick an arbitrary spawn.
    if x < 0 or y < 0 or z < -32 or z > 31 then return nil end
    return math.floor(x), math.floor(y), math.floor(z)
end

-- nil means geometry is not loaded yet, never proof of an invalid spawn.
-- Multiplayer callers must pass the server's player, not client coordinates.
function Utils.loginPositionNeedsReset(player)
    local world = getWorld()
    local grid = world and world:getMetaGrid()
    if not grid or grid:getMaxX() < grid:getMinX() or grid:getMaxY() < grid:getMinY() then return nil end
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    if not grid:isValidSquare(x, y) then return true end
    -- A passenger reconnecting offshore is valid; being outside the map is not.
    if player:getVehicle() then return false end
    local square = getCell():getGridSquare(x, y, z)
    if not square or not square:getFloor() then return nil end
    local water = square:isWaterSquare()
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local props = objects:get(i):getProperties()
        if props then
            local objectWater = props:has(IsoFlagType.water) or props:get("FloorMaterial") == "Water"
            -- Match the bundled boats' treatment of bridges/floors over water.
            if props:has(IsoFlagType.solidfloor) and not objectWater then return false end
            if objectWater then water = true end
        end
    end
    return water
end
