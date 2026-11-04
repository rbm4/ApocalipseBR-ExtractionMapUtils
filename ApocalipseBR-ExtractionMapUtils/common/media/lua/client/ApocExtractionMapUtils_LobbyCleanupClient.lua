if not isClient() then return end
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
if Utils.LobbyCleanupClientLoaded then return end
Utils.LobbyCleanupClientLoaded = true

local function onServerCommand(module, command, args)
    if module ~= "ApocExtractionMapUtils" or command ~= "LobbyCleanupZombies" then return end
    local ids = {}
    for _, id in ipairs(args.ids) do ids[id] = true end
    -- Mirror only the server's removed identities on the affected loaded tiles.
    for y = args.y1, args.y2 do
        for x = args.x1, args.x2 do
            local square = getCell():getGridSquare(x, y, args.z)
            if square then
                local objects = square:getMovingObjects()
                for i = objects:size() - 1, 0, -1 do
                    local zombie = objects:get(i)
                    if instanceof(zombie, "IsoZombie") and ids[zombie:getOnlineID()] then
                        zombie:removeFromWorld()
                        zombie:removeFromSquare()
                    end
                end
            end
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)
