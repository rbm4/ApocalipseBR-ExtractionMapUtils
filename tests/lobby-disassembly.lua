local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path

local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z or 0 end }
end
local function object(sq) return { getSquare = function() return sq end } end
local function props(sq) return { object = object(sq) } end
local inside = square(14280, 11840)
local outside = square(14259, 11840)

-- Shared hooks must load and reject work without any client-only startup event.
for _, realm in ipairs({ "client", "server" }) do
    ApocExtractionMapUtils = nil
    SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = true } }
    for _, name in ipairs({ "ApocExtractionMapUtils", "ApocExtractionMapUtils_LobbySettings" }) do package.loaded[name] = nil end
    function isClient() return realm == "client" end
    function isServer() return realm == "server" end
    local calls = {}
    local function native(name, result)
        return function(self, ...)
            calls[name] = (calls[name] or 0) + 1
            calls.args = { self, ... }
            return result, nil, "native-third-result"
        end
    end
    package.preload["Moveables/ISMoveablesAction"] = function()
        ISMoveablesAction = { isValid = native("valid", true), complete = native("complete", true), perform = native("cleanup", true) }
    end
    package.preload["TimedActions/ISDismantleAction"] = function()
        ISDismantleAction = { isValid = native("dismantleValid", true), complete = native("dismantleComplete", true), perform = native("dismantleCleanup", true) }
    end
    package.preload["TimedActions/ISDestroyStuffAction"] = function()
        ISDestroyStuffAction = { isValid = native("destroyValid", true), complete = native("destroyComplete", true), perform = native("destroyCleanup", true) }
    end
    package.preload["BuildingObjects/TimedActions/ISShovelGround"] = function()
        ISShovelGround = { isValid = native("shovelValid", true), complete = native("shovelComplete", true),
            perform = native("shovelCleanup", true), shovelGround = native("shovelGround", true) }
    end
    package.preload["Moveables/ISMoveableSpriteProps"] = function()
        ISMoveableSpriteProps = {
            canPickUpMoveable = native("canPickup", true),
            pickUpMoveableViaCursor = native("pickupCursor", true),
            pickUpMoveableInternal = native("pickupInternal", true),
            canScrapObjectInternal = native("canInternal", true),
            scrapObjectInternal = native("scrapInternal", 7),
            canScrapObject = native("canBase", { canScrap = true }),
            scrapObjectViaCursor = native("cursorBase", 7),
            startScrapAction = native("startBase", true),
        }
        ISThumpableSpriteProps = {
            canScrapObject = native("canThump", { canScrap = true }),
            scrapObjectViaCursor = native("cursorThump", 7),
            startScrapAction = native("startThump", true),
        }
    end
    for _, name in ipairs({ "Moveables/ISMoveablesAction", "Moveables/ISMoveableSpriteProps", "TimedActions/ISDismantleAction",
        "TimedActions/ISDestroyStuffAction", "BuildingObjects/TimedActions/ISShovelGround" }) do package.loaded[name] = nil end
    dofile(media .. "shared/ApocExtractionMapUtils_LobbyProtection.lua")
    local protection = ApocExtractionMapUtils.LobbyProtection
    local config = ApocExtractionMapUtils.LobbyConfig
    assert(protection.isProtectedSquare(inside))
    for _, position in ipairs({ {14260,11812}, {14321,11892}, {14322,11812}, {14322,11892}, {14260,11893}, {14321,11893} }) do
        assert(protection.isProtectedSquare(square(position[1], position[2])), "all fence squares must be protected")
    end
    for _, sq in ipairs({ outside, square(14322,11893), square(14323,11840), square(14280,11811), square(14280,11894), square(14280,11840,1) }) do
        assert(not protection.isProtectedSquare(sq), "do not expand protection beyond the configured footprint/floor")
    end
    assert(not protection.isProtectedSquare(nil))
    local originalValid = ISMoveablesAction.isValid
    dofile(media .. "shared/ApocExtractionMapUtils_LobbyProtection.lua")
    assert(originalValid == ISMoveablesAction.isValid, "reload must not stack guards")

    for _, mode in ipairs({ "scrap", "dismantle", "disassemble" }) do
        local action = { square = inside, mode = mode, moveProps = props(inside) }
        assert(ISMoveablesAction.isValid(action) == false)
        assert(ISMoveablesAction.complete(action) == false)
        -- B42 perform owns queue/sound/highlight cleanup, not world deletion.
        assert(ISMoveablesAction.perform(action) == true)
    end
    assert(not calls.valid and not calls.complete, "blocked work must never reach native mutation")
    assert(calls.cleanup == 3)
    -- Trusted target position wins even when caller supplies an outside square.
    local forged = { square = outside, mode = "scrap", moveProps = props(inside) }
    assert(ISMoveablesAction.complete(forged) == false)
    local old = { thumpable = object(inside), square = outside }
    assert(ISDismantleAction.isValid(old) == false and ISDismantleAction.complete(old) == false)
    assert(ISDismantleAction.perform(old))
    assert(not calls.dismantleValid and not calls.dismantleComplete)

    -- Chairs and floor tiles can disappear through pickup, not just scrap.
    local pickup = { square = outside, mode = "pickup", moveProps = props(inside) }
    assert(ISMoveablesAction.isValid(pickup) == false and ISMoveablesAction.complete(pickup) == false)
    assert(ISMoveableSpriteProps.canPickUpMoveable(props(outside), {}, outside, object(inside)) == false)
    assert(ISMoveableSpriteProps.pickUpMoveableViaCursor(props(inside), {}, outside) == nil)
    assert(ISMoveableSpriteProps.pickUpMoveableInternal(props(outside), {}, outside, object(inside), nil, "chair", true, false) == nil)
    assert(not calls.canPickup and not calls.pickupCursor and not calls.pickupInternal)
    assert(ISMoveablesAction.complete({ square = outside, mode = "pickup", moveProps = props(outside) }))
    assert(ISMoveableSpriteProps.canPickUpMoveable(props(outside), {}, outside, object(outside)))
    assert(ISMoveableSpriteProps.pickUpMoveableViaCursor(props(outside), {}, outside))
    assert(ISMoveableSpriteProps.pickUpMoveableInternal(props(outside), {}, outside, object(outside), nil, "chair", true, false))
    assert(ISMoveableSpriteProps.pickUpMoveableInternal(props(inside), {}, inside, object(inside), nil, "chair", false, true), "rotation's internal pickup stays available")

    local destroy = { item = object(inside), square = outside }
    local shovel = { sandTile = object(inside), item = true, square = outside }
    for _, case in ipairs({ { ISDestroyStuffAction, destroy }, { ISShovelGround, shovel } }) do
        assert(case[1].isValid(case[2]) == false and case[1].complete(case[2]) == false)
        assert(case[1].perform(case[2]), "preserve native queue and sound cleanup")
    end
    assert(ISShovelGround.shovelGround(shovel, outside) == false)
    assert(ISShovelGround.shovelGround({ sandTile = object(outside) }, inside) == false)
    assert(not calls.destroyComplete and not calls.shovelComplete and not calls.shovelGround)
    assert(ISDestroyStuffAction.complete({ item = object(outside) }))
    assert(ISShovelGround.complete({ sandTile = object(outside), item = true }))
    assert(ISShovelGround.shovelGround({ sandTile = object(outside) }, outside))

    for _, class in ipairs({ ISMoveableSpriteProps, ISThumpableSpriteProps }) do
        local p = props(inside)
        local result, chance = class.canScrapObject(p, {})
        assert(result.canScrap == false and chance == 0, "disassembly menu must see no permitted scrap action")
        assert(class.scrapObjectViaCursor(p, {}, outside) == nil)
        assert(class.startScrapAction(p, forged) == false)
    end
    local result = { canScrap = true }
    assert(ISMoveableSpriteProps.canScrapObjectInternal(props(outside), result, object(inside)) == false)
    assert(result.canScrap == false)
    assert(ISMoveableSpriteProps.scrapObjectInternal(props(outside), {}, {}, outside, object(inside), {}, 100, "MetalWelding") == 0)
    assert(not calls.scrapInternal, "direct welding completion must give no scrap, XP, fuel consumption or object removal")
    -- A multi-tile target selected outside must not dismantle its member inside.
    local multi = props(outside)
    multi.isMultiSprite = true
    multi.getSpriteGridInfo = function() return { { object = object(inside), square = inside } } end
    assert(ISMoveablesAction.complete({ mode = "scrap", square = outside, moveProps = multi }) == false)
    assert(ISMoveablesAction.complete({ mode = "pickup", square = outside, moveProps = multi }) == false)
    assert(ISMoveableSpriteProps.scrapObjectInternal(multi, {}, {}, outside, object(outside)) == 0)

    -- Outside target remains valid even when the character stands in the lobby.
    local allowed = { square = outside, mode = "scrap", moveProps = props(outside), character = object(inside) }
    local one, two, three = ISMoveablesAction.complete(allowed, "keep-argument")
    assert(one == true and two == nil and three == "native-third-result")
    assert(calls.args[1] == allowed and calls.args[2] == "keep-argument")
    assert(ISMoveablesAction.isValid(allowed))
    assert(ISDismantleAction.complete({ thumpable = object(outside) }))
    assert(ISMoveableSpriteProps.scrapObjectInternal(props(outside), {}, {}, outside, object(outside)) == 7)
    for _, class in ipairs({ ISMoveableSpriteProps, ISThumpableSpriteProps }) do
        assert(class.canScrapObject(props(outside), {}).canScrap)
        assert(class.scrapObjectViaCursor(props(outside), {}, outside) == 7)
        assert(class.startScrapAction(props(outside), allowed))
    end
    -- Protect only disassembly: ordinary interior activities still delegate.
    for _, mode in ipairs({ "repair", "place", "rotate" }) do
        assert(ISMoveablesAction.complete({ square = inside, mode = mode, moveProps = props(inside) }))
    end
    -- Each switch delegates its native paths independently, including queued completion.
    local options = SandboxVars.ApocExtractionMapUtils
    options.LobbyBlockDisassembly = false
    assert(ISMoveablesAction.complete(forged) and ISDismantleAction.complete(old))
    assert(ISMoveableSpriteProps.canScrapObject(props(inside), {}).canScrap)
    assert(ISMoveableSpriteProps.canScrapObjectInternal(props(inside), {}, object(inside)))
    assert(ISMoveableSpriteProps.scrapObjectInternal(props(inside), {}, {}, inside, object(inside)) == 7)
    for _, class in ipairs({ ISMoveableSpriteProps, ISThumpableSpriteProps }) do
        assert(class.canScrapObject(props(inside), {}).canScrap)
        assert(class.scrapObjectViaCursor(props(inside), {}, inside) == 7)
        assert(class.startScrapAction(props(inside), old))
    end
    assert(ISMoveablesAction.complete(pickup) == false and ISDestroyStuffAction.complete(destroy) == false)
    options.LobbyBlockDisassembly = true
    assert(ISMoveablesAction.complete(forged) == false and ISDismantleAction.complete(old) == false)
    options.LobbyBlockPickup = false
    assert(ISMoveablesAction.complete(pickup))
    assert(ISMoveableSpriteProps.canPickUpMoveable(props(inside), {}, inside, object(inside)))
    assert(ISMoveableSpriteProps.pickUpMoveableViaCursor(props(inside), {}, inside))
    assert(ISMoveableSpriteProps.pickUpMoveableInternal(props(inside), {}, inside, object(inside), nil, "chair", true, false))
    assert(ISMoveablesAction.complete(forged) == false)
    options.LobbyBlockPickup = true
    options.LobbyBlockDestruction = false
    assert(ISDestroyStuffAction.complete(destroy) and ISDestroyStuffAction.isValid(destroy))
    assert(ISShovelGround.complete(shovel) == false)
    options.LobbyBlockDestruction = true
    options.LobbyBlockDigging = false
    assert(ISShovelGround.complete(shovel) and ISShovelGround.isValid(shovel))
    assert(ISShovelGround.shovelGround(shovel, inside))
    assert(ISDestroyStuffAction.complete(destroy) == false)
    options.LobbyBlockDigging = true
    options.LobbyX1, options.LobbyX2, options.LobbyY1, options.LobbyY2, options.LobbyFenceZ = 210, 200, 310, 300, 2
    assert(not protection.isProtectedSquare(inside))
    assert(protection.isProtectedSquare(square(205,305,2)))
    assert(not protection.isProtectedSquare(square(205,305,0)))
    options.LobbyX1, options.LobbyX2, options.LobbyY1, options.LobbyY2, options.LobbyFenceZ = nil, nil, nil, nil, nil
    -- Configuration is read dynamically on both sides, including custom bounds.
    SandboxVars.ApocExtractionMapUtils.LobbyEnabled = false
    assert(ISMoveablesAction.complete(forged))
    assert(ISDismantleAction.complete(old))
    assert(ISMoveablesAction.complete(pickup))
    assert(ISDestroyStuffAction.complete(destroy) and ISShovelGround.complete(shovel))
    assert(ISShovelGround.shovelGround(shovel, inside))
    assert(ISMoveableSpriteProps.canPickUpMoveable(props(inside), {}, inside, object(inside)))
    assert(ISMoveableSpriteProps.pickUpMoveableViaCursor(props(inside), {}, inside))
    assert(ISMoveableSpriteProps.pickUpMoveableInternal(props(inside), {}, inside, object(inside), nil, "chair", true, false))
    SandboxVars.ApocExtractionMapUtils.LobbyEnabled = nil
    assert(ISMoveablesAction.complete(forged) and ISDismantleAction.complete(old), "missing sandbox option must leave native actions available")
    SandboxVars = nil
    assert(ISMoveablesAction.complete(forged) and ISDismantleAction.complete(old), "load before SandboxVars must be safe")
    SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = true } }
    config.X1, config.X2, config.Y1, config.Y2 = 210, 200, 310, 300
    assert(not protection.isProtectedSquare(inside) and protection.isProtectedSquare(square(205,305)))
    assert(ISMoveablesAction.complete(forged))
end
print("PASS: lobby client/server guards for disassembly, furniture/floor pickup, sledgehammer and ground shoveling; boundaries, helpers, queued completion, multi-tile targets, native cleanup, rotation, reload and disabled/outside behavior")
