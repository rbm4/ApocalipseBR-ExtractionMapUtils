-- Reuse the real protection boundary and native-action doubles, and verify the
-- removal rules first. Construction must not weaken those existing guards.
dofile("tests/lobby-disassembly.lua")
local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
local P = ApocExtractionMapUtils.LobbyProtection
local config = ApocExtractionMapUtils.LobbyConfig
config.X1, config.X2, config.Y1, config.Y2, config.Z = 100, 110, 200, 210, 0
local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z or 0 end }
end
local inside, outside = square(105,205), square(99,205)
local function object(sq) return { getSquare = function() return sq end } end
local function entity(width, height, layers, empty)
    local face = {
        getWidth = function() return width end, getHeight = function() return height end,
        getzLayers = function() return layers end,
        getTileInfo = function(self, x, y, z)
            if empty and empty(x, y, z) then return nil end
            return { getSpriteName = function() return "wall" end, isBlocking = function() return true end }
        end,
    }
    return { getFace = function() return face end }
end

for _, realm in ipairs({ "client", "server", "singleplayer" }) do
    function isServer() return realm == "server" end
    function isClient() return realm == "client" end
    SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = true } }
    P.constructionLoaded = nil
    ISBuildingObject, ISBuildIsoEntity, ISBuildAction = nil, nil, nil
    local phase = "shared"
    local calls = {}
    local function native(name)
        return function(...)
            calls[name] = (calls[name] or 0) + 1
            calls.args = { ... }
            return true, nil, "third"
        end
    end
    local modules = {
        ["ActionManager"] = function() Actions = { build = native("build") } end,
        ["BuildingObjects/ISBuildingObject"] = function() ISBuildingObject = { tryBuild = native("tryBuild") } end,
        ["BuildingObjects/ISBuildIsoEntity"] = function()
            ISBuildIsoEntity = { isValid = native("entityValid"), create = native("create") }
        end,
        ["BuildingObjects/TimedActions/ISMultiStageBuild"] = function()
            ISMultiStageBuild = { isValid = native("stageValid"), complete = native("stageComplete"), perform = native("stageCleanup") }
        end,
        ["BuildingObjects/TimedActions/ISBuildAction"] = function()
            assert(realm ~= "server", "dedicated server must not require client-only action")
            ISBuildAction = { isValid = native("actionValid"), start = native("start"), perform = native("perform") }
        end,
    }
    for name, loader in pairs(modules) do
        package.loaded[name] = nil
        package.preload[name] = function()
            if name == "BuildingObjects/ISBuildingObject" or name == "BuildingObjects/ISBuildIsoEntity" then
                assert(phase == "server", "server building modules unavailable during shared/client loading")
            end
            return loader()
        end
    end
    -- Reproduce B42's startup boundary: a construction file in shared must not
    -- try to load the server building classes before their path is registered.
    local sharedFile = media .. "shared/ApocExtractionMapUtils_LobbyConstruction.lua"
    local sharedChunk = loadfile(sharedFile)
    if sharedChunk then sharedChunk() end
    assert(not P.constructionLoaded, "construction guards must wait for the server Lua pass")
    assert(ISBuildingObject == nil and ISBuildIsoEntity == nil)
    phase = "server"
    dofile(media .. "server/ApocExtractionMapUtils_LobbyConstruction.lua")
    local wrapped = Actions.build
    dofile(media .. "server/ApocExtractionMapUtils_LobbyConstruction.lua")
    assert(Actions.build == wrapped, "duplicate load must not stack wrappers")

    assert(ISBuildingObject.tryBuild({}, 105,205,0) == nil)
    assert(ISBuildIsoEntity.isValid({}, inside) == false)
    assert(ISBuildIsoEntity.create({}, 105,205,0) == false)
    assert(Actions.build({}, { item = {}, x = 105, y = 205, z = 0 }) == false)
    -- Coordinates must still protect a missing/unloaded grid square.
    assert(Actions.build({}, { item = {}, x = 111, y = 205, z = 0 }) == false)
    assert(Actions.build({}, { item = {}, x = 105, y = 211, z = 0 }) == false)
    assert(not calls.tryBuild and not calls.entityValid and not calls.create and not calls.build)

    local wide = entity(2,1,1)
    assert(P.isProtectedBuild(wide,99,205,0), "outside anchor must not extend into lobby")
    assert(ISBuildIsoEntity.create(wide,99,205,0) == false)
    assert(Actions.build({}, { item = wide, x = 99, y = 205, z = 0 }) == false)
    assert(P.isProtectedBuild(entity(1,1,2),105,205,-1), "upper occupied layer intersects lobby")
    assert(not P.isProtectedBuild(entity(2,1,1,function(x) return x == 1 end),99,205,0), "empty script offsets do not occupy lobby")
    assert(not P.isProtectedBuild(wide,99,205,1), "different elevation stays outside restriction")

    local stage = { item = object(inside), square = outside }
    assert(ISMultiStageBuild.isValid(stage) == false and ISMultiStageBuild.complete(stage) == false)
    assert(ISMultiStageBuild.perform(stage))
    assert(not calls.stageValid and not calls.stageComplete, "no upgrades/material consumption on blocked target")

    if realm ~= "server" then
        local action = { item = {}, x = 105, y = 205, z = 0,
            forceStop = native("forceStop"), stop = native("stop") }
        assert(ISBuildAction.isValid(action) == false)
        ISBuildAction.start(action)
        ISBuildAction.perform(action)
        assert(calls.forceStop == 1 and calls.stop == 1 and not calls.start and not calls.perform)
        action.x = 99
        assert(ISBuildAction.isValid(action))
        assert(ISBuildAction.start(action) and ISBuildAction.perform(action))
    end

    local one, two, three = ISBuildingObject.tryBuild({},99,205,0,"argument")
    assert(one == true and two == nil and three == "third" and calls.args[5] == "argument")
    assert(ISBuildIsoEntity.isValid({},outside))
    assert(ISBuildIsoEntity.create({},99,205,0))
    assert(Actions.build({}, { item = {}, x = 99, y = 205, z = 0 }))
    assert(ISMultiStageBuild.complete({ item = object(outside) }))
    assert(Actions.build({}, { item = {}, x = 111, y = 211, z = 0 }), "unused southeast diagonal remains outside")

    for _, setting in ipairs({ false, "missing" }) do
        SandboxVars.ApocExtractionMapUtils.LobbyEnabled = false
        if setting == "missing" then SandboxVars.ApocExtractionMapUtils.LobbyEnabled = nil end
        assert(ISBuildingObject.tryBuild({},105,205,0))
        assert(ISBuildIsoEntity.isValid({},inside) and ISBuildIsoEntity.create({},105,205,0))
        assert(Actions.build({}, { item = {}, x = 105, y = 205, z = 0 }))
        assert(ISMultiStageBuild.complete(stage))
    end
end
print("PASS: lobby construction client/server/SP guards; entity footprints/layers, unloaded coordinates, upgrades, cancellation, native returns, reload, outside and disabled behavior")
