-- B42 registers require paths one Lua directory at a time. Building cursors
-- live in server Lua, so install here rather than during the shared pass.
-- GameLoadingState also loads this directory on clients and in single-player.
require "ApocExtractionMapUtils_LobbyProtection"
require "ActionManager"
require "BuildingObjects/ISBuildingObject"
require "BuildingObjects/ISBuildIsoEntity"
require "BuildingObjects/TimedActions/ISMultiStageBuild"

local P = ApocExtractionMapUtils.LobbyProtection
if P.constructionLoaded then return end
P.constructionLoaded = true

function P.isProtectedBuild(item, x, y, z)
    if not ApocExtractionMapUtils.lobbyRuleEnabled("LobbyBlockConstruction") then return false end
    if P.isProtectedPosition(x, y, z) then return true end
    -- B42 entities (stairs, double doors, etc.) include offsets and Z layers.
    -- Inspect script tiles directly: getOccupiedTiles omits unloaded squares.
    local face = item and item.getFace and item:getFace()
    if face then
        for zz = 0, face:getzLayers() - 1 do
            for xx = 0, face:getWidth() - 1 do
                for yy = 0, face:getHeight() - 1 do
                    local tile = face:getTileInfo(xx, yy, zz)
                    if tile and (tile:getSpriteName() or tile:isBlocking())
                        and P.isProtectedPosition(x + xx, y + yy, z + zz) then return true end
                end
            end
        end
    end
    return false
end

local oldTryBuild = ISBuildingObject.tryBuild
ISBuildingObject.tryBuild = function(self, x, y, z, ...)
    -- Reject before the build panel starts reserving/processing ingredients.
    if P.isProtectedBuild(self, x, y, z) then return end
    return oldTryBuild(self, x, y, z, ...)
end

local oldValid = ISBuildIsoEntity.isValid
ISBuildIsoEntity.isValid = function(self, square, ...)
    if square and P.isProtectedBuild(self, square:getX(), square:getY(), square:getZ()) then return false end
    return oldValid(self, square, ...)
end

local oldCreate = ISBuildIsoEntity.create
ISBuildIsoEntity.create = function(self, x, y, z, ...)
    if P.isProtectedBuild(self, x, y, z) then return false end
    return oldCreate(self, x, y, z, ...)
end

local oldBuild = Actions.build
Actions.build = function(character, args, ...)
    -- Java BuildAction.perform dispatches here on the server, including legacy
    -- building classes that override ISBuildingObject:isValid().
    if args and P.isProtectedBuild(args.item, args.x, args.y, args.z) then return false end
    return oldBuild(character, args, ...)
end

local oldStageValid, oldStageComplete = ISMultiStageBuild.isValid, ISMultiStageBuild.complete
local function protectedStage(action)
    return ApocExtractionMapUtils.lobbyRuleEnabled("LobbyBlockUpgrades")
        and action.item and P.isProtectedSquare(action.item:getSquare())
end
ISMultiStageBuild.isValid = function(self, ...)
    if protectedStage(self) then return false end
    return oldStageValid(self, ...)
end
ISMultiStageBuild.complete = function(self, ...)
    if protectedStage(self) then return false end
    return oldStageComplete(self, ...)
end

-- ISBuildAction lives in client Lua, unlike the shared upgrade action. SP also
-- creates the object in perform(), so preserve cleanup by cancelling via stop.
if not isServer() then
    require "BuildingObjects/TimedActions/ISBuildAction"
    local oldActionValid, oldStart, oldPerform = ISBuildAction.isValid, ISBuildAction.start, ISBuildAction.perform
    local function blocked(action)
        return P.isProtectedBuild(action.item, action.x, action.y, action.z)
    end
    ISBuildAction.isValid = function(self, ...)
        if blocked(self) then return false end
        return oldActionValid(self, ...)
    end
    ISBuildAction.start = function(self, ...)
        if blocked(self) then self:forceStop(); return end
        return oldStart(self, ...)
    end
    ISBuildAction.perform = function(self, ...)
        if blocked(self) then return self:stop() end
        return oldPerform(self, ...)
    end
end
